import paho.mqtt.client as mqtt
import firebase_admin
from firebase_admin import credentials, db
import json
import time
import RPi.GPIO as GPIO
import threading

# Hardware Configuration
SERVO_PIN = 18       # GPIO pin for servo motor
LED_RED_PIN = 23     # GPIO pin for red LED

# MQTT Configuration
broker = '192.168.137.86'
port = 8000
qr_topic = "parking/paymentQR"

# Firebase Configuration
firebase_credentials_path = '/home/pi/Desktop/test/smartparking-4025c-firebase-adminsdk-fbsvc-020fd53803.json'
database_url = 'https://smartparking-4025c-default-rtdb.europe-west1.firebasedatabase.app/'

# This Raspberry Pi's Assigned Parking
ASSIGNED_PARKING_ID = "GnNyv7AD32nUPqtp9tvR"

# Gate access control
gate_access_lock = threading.Lock()
is_gate_processing = False

# Initialize GPIO
GPIO.setmode(GPIO.BCM)
GPIO.setup(SERVO_PIN, GPIO.OUT)
GPIO.setup(LED_RED_PIN, GPIO.OUT)
servo = GPIO.PWM(SERVO_PIN, 50)  # 50Hz PWM frequency
servo.start(0)

# Initialize Firebase
cred = credentials.Certificate(firebase_credentials_path)
firebase_admin.initialize_app(cred, {'databaseURL': database_url})

def move_servo(angle):
    duty = 2 + (angle / 18)
    servo.ChangeDutyCycle(duty)
    time.sleep(1)
    servo.ChangeDutyCycle(0)

def blink_led(pin, duration):
    GPIO.output(pin, GPIO.HIGH)
    time.sleep(duration)
    GPIO.output(pin, GPIO.LOW)
    
def gate_access_sequence():
    """Handle the complete gate access sequence with 10-second blocking"""
    global is_gate_processing
    
    with gate_access_lock:
        is_gate_processing = True
        print("Gate access sequence started - blocking new requests for 10 seconds")
        
        try:
            # Open gate
            print("Opening gate...")
            move_servo(90)
            
            # Wait 10 seconds (gate stays open and blocks new requests)
            print("Gate open - waiting 10 seconds...")
            time.sleep(10)
            
            # Close gate
            print("Closing gate...")
            move_servo(0)
            
        except Exception as e:
            print(f"Error in gate sequence: {e}")
            # Ensure gate closes even if there's an error
            move_servo(0)
        
        finally:
            is_gate_processing = False
            print("Gate access sequence completed - ready for new requests")
 
def validate_parking_spot(parking_id, spot_number, user_id):
    """Validate spot directly in parking structure"""
    try:
        # Check if this is the correct parking
        if parking_id != ASSIGNED_PARKING_ID:
            print(f"Wrong parking ID. Expected {ASSIGNED_PARKING_ID}, got {parking_id}")
            return False
            
        # Get spot data from Firebase
        spot_ref = db.reference(f"qrcode/{parking_id}/{spot_number}")
        spot_data = spot_ref.get()
        
        if not spot_data:
            print(f"Spot {spot_number} not found in parking {parking_id}")
            return False
            
        # Check if user matches
        if spot_data.get('userId') != user_id:
            print("User ID doesn't match spot reservation")
            return False
            
        # Check if spot is active
        if spot_data.get('status') != 'active':
            print("Spot is not active")
            return False
            
        # Check expiry time
        current_time = int(time.time() * 1000)
        if current_time > spot_data.get('expiryTime', current_time + 10000):
            print("Reservation has expired")
            return False
            
        return True
        
    except Exception as e:
        print(f"Validation error: {e}")
        return False

def handle_qr_message(msg):
    global is_gate_processing
    
    # Check if gate is currently processing
    if is_gate_processing:
        print("Gate is currently processing - ignoring new QR scan")
        return
    
    try:
        payload = json.loads(msg.payload.decode())
        print(f"Received QR data: {payload}")
        
        # Extract required fields
        parking_id = payload.get('parkingId')
        spot_number = payload.get('spotNumber')
        user_id = payload.get('userId')
        
        if validate_parking_spot(parking_id, spot_number, user_id):
            print("Valid spot - initiating gate access sequence")
            
            # Update spot access time before starting gate sequence
            try:
                db.reference(f"qrcode/{parking_id}/{spot_number}").update({
                    'lastAccess': int(time.time() * 1000),
                    'accessCount': firebase_admin.db.Increment(1)
                })
            except Exception as e:
                print(f"Error updating Firebase: {e}")
            
            # Start gate access sequence in a separate thread to avoid blocking MQTT
            gate_thread = threading.Thread(target=gate_access_sequence)
            gate_thread.daemon = True
            gate_thread.start()
            
        else:
            print("Invalid spot - showing error")
            blink_led(LED_RED_PIN, 3)
            
    except Exception as e:
        print(f"Error processing QR: {e}")
        blink_led(LED_RED_PIN, 3)

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT Broker!")
        client.subscribe(qr_topic)
        print(f"Subscribed to topic: {qr_topic}")
    else:
        print(f"Failed to connect, return code {rc}")

def on_message(client, userdata, msg):
    if msg.topic == qr_topic:
        handle_qr_message(msg)

def main():
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    
    try:
        print(f"Parking Controller for: {ASSIGNED_PARKING_ID}")
        print("Starting MQTT client...")
        client.connect(broker, port, 60)
        client.loop_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        servo.stop()
        GPIO.cleanup()
    except Exception as e:
        print(f"Error: {e}")
        servo.stop()
        GPIO.cleanup()

if __name__ == "__main__":
    main()
