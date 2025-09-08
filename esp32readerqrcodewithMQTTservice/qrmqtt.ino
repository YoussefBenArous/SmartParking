/*
 * ESP32-CAM QR Parking System with MQTT
 * Modified to send ALL QR code data via MQTT to Raspberry Pi
 * MQTT Broker: 192.168.137.86:8000
 */

#include "esp_camera.h"
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "quirc.h"
#include <WiFi.h>
#include "esp_http_server.h"
#include <driver/ledc.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// Camera model selection
#define CAMERA_MODEL_AI_THINKER

// Stream constants
static const char *_STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=123456789000000000000987654321";
static const char *_STREAM_BOUNDARY = "\r\n--123456789000000000000987654321\r\n";
static const char *_STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

// GPIO configuration for AI Thinker ESP32-CAM
#if defined(CAMERA_MODEL_AI_THINKER)
#define PWDN_GPIO_NUM 32
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 0
#define SIOD_GPIO_NUM 26
#define SIOC_GPIO_NUM 27
#define Y9_GPIO_NUM 35
#define Y8_GPIO_NUM 34
#define Y7_GPIO_NUM 39
#define Y6_GPIO_NUM 36
#define Y5_GPIO_NUM 21
#define Y4_GPIO_NUM 19
#define Y3_GPIO_NUM 18
#define Y2_GPIO_NUM 5
#define VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM 23
#define PCLK_GPIO_NUM 22
#endif

// LEDs GPIO
#define LED_ONBOARD 4
#define LED_GREEN 12
#define LED_BLUE 13

// WiFi credentials
const char *ssid = "Your ssid";
const char *password = "Your password";

// MQTT Configuration
const char* mqtt_server = "Your mqtt server";
const int mqtt_port = 8000;
const char* mqtt_client_id = "ESP32CAM_Parking";
const char* mqtt_topic = "Your topic";

// Parking configuration
const char* parkingId = "Your parking id";

// MQTT and WiFi clients
WiFiClient espClient;
PubSubClient mqttClient(espClient);

// QR Code variables
struct quirc *q = NULL;
uint8_t *image = NULL;
struct quirc_code code;
struct quirc_data data;
quirc_decode_error_t err;
String QRCodeResult = "";
String lastValidQR = "";
String rawQRData = "";  // Store raw QR data
unsigned long lastQRScanTime = 0;
unsigned long lastMqttReconnect = 0;
unsigned long qrScanCooldown = 0;  // Prevent duplicate scans

// Web server variables
httpd_handle_t index_httpd = NULL;
httpd_handle_t stream_httpd = NULL;

// LED feedback variables
unsigned long ledFlashStartTime = 0;
bool ledFlashActive = false;
int flashCount = 0;
const int SUCCESS_FLASHES = 3;
const int ERROR_FLASHES = 2;

// HTML page
static const char PROGMEM INDEX_HTML[] = R"rawliteral(
<html>
  <head>
    <title>ESP32-CAM QR Parking System</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      body { font-family: Arial; text-align: center; margin: 0 auto; padding-top: 20px; background-color: #f5f5f5; }
      .container { max-width: 800px; margin: 0 auto; padding: 20px; background: white; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
      #stream-container { margin: 20px auto; width: 640px; max-width: 100%; }
      #stream { width: 100%; height: auto; border: 2px solid #ddd; border-radius: 5px; }
      #qr-data { 
        padding: 15px; 
        border: 2px solid #075264;
        border-radius: 8px;
        width: 80%;
        margin: 20px auto;
        text-align: left;
        background: #f0f8ff;
      }
      .data-row { margin: 8px 0; padding: 8px; border-bottom: 1px solid #ddd; }
      .data-label { font-weight: bold; display: inline-block; width: 120px; color: #075264; }
      .status { margin: 15px 0; padding: 10px; border-radius: 5px; }
      .scanning { background-color: #fff3cd; color: #856404; }
      .success { background-color: #d4edda; color: #155724; }
      .error { background-color: #f8d7da; color: #721c24; }
      .mqtt-status { margin: 10px 0; padding: 8px; border-radius: 5px; font-size: 14px; }
      .mqtt-connected { background-color: #d4edda; color: #155724; }
      .mqtt-disconnected { background-color: #f8d7da; color: #721c24; }
      #raw-data { 
        margin: 10px 0; 
        padding: 10px; 
        background: #f8f9fa; 
        border: 1px solid #dee2e6; 
        border-radius: 5px; 
        font-family: monospace; 
        font-size: 12px; 
        max-height: 200px; 
        overflow-y: auto; 
        text-align: left;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h2>Parking QR Code Scanner</h2>
      
      <div id="status" class="status scanning">Status: Ready to scan</div>
      <div id="mqtt-status" class="mqtt-status mqtt-disconnected">MQTT: Disconnected</div>
      
      <div id="stream-container">
        <img id="stream" src="">
      </div>

      <div id="qr-data">
        <div class="data-row"><span class="data-label">User ID:</span> <span id="userId">-</span></div>
        <div class="data-row"><span class="data-label">Spot Number:</span> <span id="spotNumber">-</span></div>
        <div class="data-row"><span class="data-label">Parking ID:</span> <span id="parkingId">-</span></div>
        <div class="data-row"><span class="data-label">Type:</span> <span id="type">-</span></div>
        <div class="data-row"><span class="data-label">Expired Time:</span> <span id="expiredTime">-</span></div>
        <div class="data-row"><span class="data-label">Raw QR Data:</span></div>
        <div id="raw-data">-</div>
      </div>
    </div>

    <script>
      document.getElementById("stream").src = window.location.href.slice(0, -1) + ":81/stream";

      function updateQRData() {
        fetch('/getqrcodeval')
          .then(response => response.text())
          .then(data => {
            try {
              const qrData = JSON.parse(data);
              const statusDiv = document.getElementById("status");
              
              if (qrData.error) {
                statusDiv.className = "status error";
                statusDiv.textContent = "Status: " + qrData.error;
              } 
              else if (qrData.userId || qrData.rawData) {
                statusDiv.className = "status success";
                statusDiv.textContent = "Status: QR Code Scanned & Sent via MQTT";
                
                document.getElementById("userId").textContent = qrData.userId || "-";
                document.getElementById("spotNumber").textContent = qrData.spotNumber || "-";
                document.getElementById("parkingId").textContent = qrData.parkingId || "-";
                document.getElementById("type").textContent = qrData.type || "-";
                document.getElementById("expiredTime").textContent = qrData.expiredTime || "-";
                document.getElementById("raw-data").textContent = qrData.rawData || "-";
              }
              else {
                statusDiv.className = "status scanning";
                statusDiv.textContent = "Status: Ready to scan";
              }
            } catch(e) {
              console.log("Error parsing QR data:", e);
            }
          });
        
        // Check MQTT status
        fetch('/getmqttstatus')
          .then(response => response.text())
          .then(status => {
            const mqttDiv = document.getElementById("mqtt-status");
            if (status === "connected") {
              mqttDiv.className = "mqtt-status mqtt-connected";
              mqttDiv.textContent = "MQTT: Connected to " + window.location.hostname;
            } else {
              mqttDiv.className = "mqtt-status mqtt-disconnected";
              mqttDiv.textContent = "MQTT: Disconnected";
            }
          });
      }
      
      updateQRData();
      setInterval(updateQRData, 500);
    </script>
  </body>
</html>
)rawliteral";

// Function prototypes
void startCameraWebServer();
void flashLED(int pin, int flashes, int duration);
void handleQRResult(bool success);
void setupMQTT();
void reconnectMQTT();
void sendAllQRData(String rawData, String userId = "", String spotNumber = "", String type = "", String expiredTime = "", String parkingIdScanned = "");
String extractJsonValue(String json, String key);
bool isValidJson(String str);

// MQTT Status handler
static esp_err_t mqtt_status_handler(httpd_req_t *req) {
  String status = mqttClient.connected() ? "connected" : "disconnected";
  httpd_resp_set_type(req, "text/plain");
  return httpd_resp_send(req, status.c_str(), HTTPD_RESP_USE_STRLEN);
}

// HTTP Handlers
static esp_err_t index_handler(httpd_req_t *req) {
  httpd_resp_set_type(req, "text/html");
  return httpd_resp_send(req, (const char *)INDEX_HTML, strlen(INDEX_HTML));
}

static esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t *fb = NULL;
  esp_err_t res = ESP_OK;
  size_t _jpg_buf_len = 0;
  uint8_t *_jpg_buf = NULL;
  char *part_buf[64];

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if(res != ESP_OK) return res;

  while(true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      res = ESP_FAIL;
      break;
    }

    // QR Code scanning with cooldown to prevent duplicates
    if (millis() - qrScanCooldown > 2000) {  // 2 second cooldown
      q = quirc_new();
      if (q) {
        quirc_resize(q, fb->width, fb->height);
        image = quirc_begin(q, NULL, NULL);
        if (image) {
          memcpy(image, fb->buf, fb->len);
          quirc_end(q);
          
          int count = quirc_count(q);
          if (count > 0) {
            quirc_extract(q, 0, &code);
            err = quirc_decode(&code, &data);
            if (!err) {
              // Successfully decoded QR code
              String payload = (const char *)data.payload;
              rawQRData = payload;  // Store raw data
              
              Serial.println("=== QR CODE DETECTED ===");
              Serial.println("Raw QR Data: " + payload);
              Serial.println("Data Length: " + String(payload.length()));
              
              // Initialize variables
              String userId = "";
              String spotNumber = "";
              String parkingIdScanned = "";
              String type = "";
              String expiredTime = "";
              
              // Try to parse as JSON first
              if (isValidJson(payload)) {
                Serial.println("QR contains valid JSON");
                userId = extractJsonValue(payload, "userId");
                spotNumber = extractJsonValue(payload, "spotNumber");
                parkingIdScanned = extractJsonValue(payload, "parkingId");
                type = extractJsonValue(payload, "type");
                expiredTime = extractJsonValue(payload, "expiredTime");
              } else {
                // Try manual parsing for non-standard JSON
                Serial.println("Attempting manual JSON parsing");
                
                int userIdStart = payload.indexOf("\"userId\":\"") + 10;
                if (userIdStart > 9) {
                    int userIdEnd = payload.indexOf("\"", userIdStart);
                    if (userIdEnd > userIdStart) {
                        userId = payload.substring(userIdStart, userIdEnd);
                    }
                }

                int parkingIdStart = payload.indexOf("\"parkingId\":\"") + 13;
                if (parkingIdStart > 12) {
                    int parkingIdEnd = payload.indexOf("\"", parkingIdStart);
                    if (parkingIdEnd > parkingIdStart) {
                        parkingIdScanned = payload.substring(parkingIdStart, parkingIdEnd);
                    }
                }

                int spotNumberStart = payload.indexOf("\"spotNumber\":") + 13;
                if (spotNumberStart > 12) {
                    int spotNumberEnd = payload.indexOf(",", spotNumberStart);
                    if (spotNumberEnd == -1) spotNumberEnd = payload.indexOf("}", spotNumberStart);
                    if (spotNumberEnd > spotNumberStart) {
                        spotNumber = payload.substring(spotNumberStart, spotNumberEnd);
                        spotNumber.replace("\"", "");
                        spotNumber.trim();
                    }
                }

                int typeStart = payload.indexOf("\"type\":\"") + 8;
                if (typeStart > 7) {
                    int typeEnd = payload.indexOf("\"", typeStart);
                    if (typeEnd > typeStart) {
                        type = payload.substring(typeStart, typeEnd);
                    }
                }

                int expiredTimeStart = payload.indexOf("\"expiredTime\":\"") + 15;
                if (expiredTimeStart > 14) {
                    int expiredTimeEnd = payload.indexOf("\"", expiredTimeStart);
                    if (expiredTimeEnd > expiredTimeStart) {
                        expiredTime = payload.substring(expiredTimeStart, expiredTimeEnd);
                    }
                }
              }
              
              // Create JSON response for web interface
              QRCodeResult = "{";
              QRCodeResult += "\"userId\":\"" + userId + "\",";
              QRCodeResult += "\"spotNumber\":\"" + spotNumber + "\",";
              QRCodeResult += "\"parkingId\":\"" + parkingIdScanned + "\",";
              QRCodeResult += "\"type\":\"" + type + "\",";
              QRCodeResult += "\"expiredTime\":\"" + expiredTime + "\",";
              QRCodeResult += "\"rawData\":\"" + payload + "\"";
              QRCodeResult += "}";
              
              Serial.println("=== EXTRACTED DATA ===");
              Serial.println("User ID: " + userId);
              Serial.println("Spot Number: " + spotNumber);
              Serial.println("Parking ID: " + parkingIdScanned);
              Serial.println("Type: " + type);
              Serial.println("Expired Time: " + expiredTime);
              Serial.println("=====================");
              
              // Send ALL data via MQTT (both parsed and raw)
              sendAllQRData(payload, userId, spotNumber, type, expiredTime, parkingIdScanned);
              
              lastValidQR = QRCodeResult;
              lastQRScanTime = millis();
              qrScanCooldown = millis();  // Set cooldown
              handleQRResult(true);
            } else {
              QRCodeResult = "{\"error\":\"Decoding failed: " + String(quirc_strerror(err)) + "\"}";
              Serial.println("QR decode error: " + String(quirc_strerror(err)));
              handleQRResult(false);
            }
          }
        }
        quirc_destroy(q);
      }
    }

    // Convert frame to JPEG if needed
    if(fb->format != PIXFORMAT_JPEG) {
      bool jpeg_converted = frame2jpg(fb, 80, &_jpg_buf, &_jpg_buf_len);
      if(!jpeg_converted) {
        Serial.println("JPEG compression failed");
        res = ESP_FAIL;
      }
    } else {
      _jpg_buf_len = fb->len;
      _jpg_buf = fb->buf;
    }

    // Send frame
    if(res == ESP_OK) {
      size_t hlen = snprintf((char *)part_buf, 64, _STREAM_PART, _jpg_buf_len);
      res = httpd_resp_send_chunk(req, (const char *)part_buf, hlen);
    }
    if(res == ESP_OK) {
      res = httpd_resp_send_chunk(req, (const char *)_jpg_buf, _jpg_buf_len);
    }
    if(res == ESP_OK) {
      res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
    }
    
    if(fb) {
      esp_camera_fb_return(fb);
      fb = NULL;
    }
    if(_jpg_buf) {
      free(_jpg_buf);
      _jpg_buf = NULL;
    }
    if(res != ESP_OK) break;
  }
  
  return res;
}

static esp_err_t qrcoderslt_handler(httpd_req_t *req) {
  if (QRCodeResult.length() == 0 || millis() - lastQRScanTime > 15000) {
    QRCodeResult = "{}";
  }
  httpd_resp_set_type(req, "application/json");
  return httpd_resp_send(req, QRCodeResult.c_str(), HTTPD_RESP_USE_STRLEN);
}

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);  // Disable brownout detector

  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println("\n=== ESP32-CAM QR Parking System with Enhanced MQTT ===");

  // Initialize LEDs
  pinMode(LED_ONBOARD, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_BLUE, OUTPUT);
  digitalWrite(LED_ONBOARD, LOW);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_BLUE, LOW);

  // Initialize camera
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 10000000;
  config.pixel_format = PIXFORMAT_GRAYSCALE;
  config.frame_size = FRAMESIZE_QVGA;
  config.jpeg_quality = 15;
  config.fb_count = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    flashLED(LED_ONBOARD, 5, 200);
    ESP.restart();
  }

  // Connect to WiFi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");

  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startTime < 20000) {
    Serial.print(".");
    digitalWrite(LED_ONBOARD, !digitalRead(LED_ONBOARD));
    delay(500);
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nFailed to connect to WiFi!");
    flashLED(LED_ONBOARD, 10, 100);
    ESP.restart();
  }

  Serial.println("\nWiFi connected");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  digitalWrite(LED_ONBOARD, HIGH);

  // Setup MQTT
  setupMQTT();

  // Start web server
  startCameraWebServer();

  // Initial LED flash to indicate ready state
  flashLED(LED_BLUE, 2, 200);
  
  Serial.println("=== System Ready ===");
}

void loop() {
  // Handle MQTT connection
  if (!mqttClient.connected()) {
    if (millis() - lastMqttReconnect > 5000) {
      reconnectMQTT();
      lastMqttReconnect = millis();
    }
  } else {
    mqttClient.loop();
  }

  // Handle LED flashing if active
  if (ledFlashActive) {
    unsigned long currentMillis = millis();
    if (currentMillis - ledFlashStartTime > 200) {
      ledFlashStartTime = currentMillis;
      flashCount--;

      if (flashCount > 0) {
        digitalWrite(LED_GREEN, !digitalRead(LED_GREEN));
      } else {
        digitalWrite(LED_GREEN, LOW);
        ledFlashActive = false;
      }
    }
  }
}

void setupMQTT() {
  mqttClient.setServer(mqtt_server, mqtt_port);
  mqttClient.setBufferSize(2048);  // Increase buffer size for larger payloads
  Serial.println("MQTT configured with enlarged buffer");
}

void reconnectMQTT() {
  Serial.print("Attempting MQTT connection...");
  if (mqttClient.connect(mqtt_client_id)) {
    Serial.println(" connected!");
    digitalWrite(LED_BLUE, HIGH);
  } else {
    Serial.print(" failed, rc=");
    Serial.println(mqttClient.state());
    digitalWrite(LED_BLUE, LOW);
  }
}

void sendAllQRData(String rawData, String userId, String spotNumber, String type, String expiredTime, String parkingIdScanned) {
  if (!mqttClient.connected()) {
    Serial.println("MQTT not connected, attempting reconnection...");
    reconnectMQTT();
    if (!mqttClient.connected()) {
      Serial.println("MQTT reconnection failed, cannot send data");
      return;
    }
  }

  // Create comprehensive JSON payload for MQTT
  DynamicJsonDocument doc(2048);  // Increased size for more data
  
  // Add parsed data
  doc["userId"] = userId;
  doc["spotNumber"] = spotNumber.length() > 0 ? spotNumber.toInt() : 0;
  doc["type"] = type;
  doc["expiredTime"] = expiredTime;
  doc["parkingId"] = parkingIdScanned.length() > 0 ? parkingIdScanned : parkingId;
  
  // Add raw QR data (this ensures ALL data is sent)
  doc["rawQRData"] = rawData;
  
  // Add system information
  doc["timestamp"] = millis();
  doc["deviceId"] = mqtt_client_id;
  doc["wifiSignal"] = WiFi.RSSI();
  doc["freeHeap"] = ESP.getFreeHeap();
  
  // Add parsing status
  doc["parsingStatus"] = (userId.length() > 0) ? "success" : "partial";
  doc["dataLength"] = rawData.length();

  String jsonString;
  serializeJson(doc, jsonString);

  Serial.println("=== SENDING MQTT DATA ===");
  Serial.println("Topic: " + String(mqtt_topic));
  Serial.println("Payload size: " + String(jsonString.length()) + " bytes");
  Serial.println("Payload: " + jsonString);

  // Publish to MQTT topic
  bool publishResult = mqttClient.publish(mqtt_topic, jsonString.c_str(), true);  // Retain message
  
  if (publishResult) {
    Serial.println("✓ MQTT data sent successfully!");
    flashLED(LED_BLUE, 2, 100); // Double blue flash for MQTT success
  } else {
    Serial.println("✗ Failed to send MQTT data");
    Serial.println("MQTT State: " + String(mqttClient.state()));
    flashLED(LED_ONBOARD, 3, 100); // Triple red flash for MQTT failure
  }
  Serial.println("========================");
}

void startCameraWebServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;

  httpd_uri_t index_uri = {
    .uri = "/",
    .method = HTTP_GET,
    .handler = index_handler,
    .user_ctx = NULL
  };

  httpd_uri_t qrcoderslt_uri = {
    .uri = "/getqrcodeval",
    .method = HTTP_GET,
    .handler = qrcoderslt_handler,
    .user_ctx = NULL
  };

  httpd_uri_t mqtt_status_uri = {
    .uri = "/getmqttstatus",
    .method = HTTP_GET,
    .handler = mqtt_status_handler,
    .user_ctx = NULL
  };

  httpd_uri_t stream_uri = {
    .uri = "/stream",
    .method = HTTP_GET,
    .handler = stream_handler,
    .user_ctx = NULL
  };

  if (httpd_start(&index_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(index_httpd, &index_uri);
    httpd_register_uri_handler(index_httpd, &qrcoderslt_uri);
    httpd_register_uri_handler(index_httpd, &mqtt_status_uri);
  }

  config.server_port += 1;
  config.ctrl_port += 1;
  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &stream_uri);
  }

  Serial.println("HTTP server started");
}

void handleQRResult(bool success) {
  if (success) {
    flashLED(LED_GREEN, SUCCESS_FLASHES, 200);
  } else {
    flashLED(LED_ONBOARD, ERROR_FLASHES, 200);
  }
}

void flashLED(int pin, int flashes, int duration) {
  ledFlashActive = true;
  flashCount = flashes * 2;
  ledFlashStartTime = millis();
}

// Helper function to extract JSON values
String extractJsonValue(String json, String key) {
  String searchKey = "\"" + key + "\":";
  int startIndex = json.indexOf(searchKey);
  if (startIndex == -1) return "";
  
  startIndex += searchKey.length();
  
  // Skip whitespace
  while (startIndex < json.length() && (json.charAt(startIndex) == ' ' || json.charAt(startIndex) == '\t')) {
    startIndex++;
  }
  
  // Check if value is quoted
  bool isQuoted = (startIndex < json.length() && json.charAt(startIndex) == '"');
  if (isQuoted) startIndex++; // Skip opening quote
  
  int endIndex = startIndex;
  if (isQuoted) {
    // Find closing quote
    while (endIndex < json.length() && json.charAt(endIndex) != '"') {
      endIndex++;
    }
  } else {
    // Find comma or closing brace
    while (endIndex < json.length() && json.charAt(endIndex) != ',' && json.charAt(endIndex) != '}') {
      endIndex++;
    }
  }
  
  return json.substring(startIndex, endIndex);
}

// Helper function to check if string is valid JSON
bool isValidJson(String str) {
  str.trim();
  return (str.startsWith("{") && str.endsWith("}")) || (str.startsWith("[") && str.endsWith("]"));
}