import cv2
from pyzbar import pyzbar
import firebase_admin
from firebase_admin import credentials, db
import json
import time
import RPi.GPIO as GPIO
import threading
import numpy as np
import sys

# Hardware Configuration
SERVO_PIN = 18       # GPIO pin for servo motor
LED_RED_PIN = 23     # GPIO pin for red LED
LED_BLUE_PIN = 24    # GPIO pin for blue LED (add this pin)

# Firebase Configuration
firebase_credentials_path = 'Your Firebase Admin SDK JSON file path here'
database_url = 'Your Firebase Realtime Database URL here'

# This Raspberry Pi's Assigned Parking
ASSIGNED_PARKING_ID = "Your_Assigned_Parking_ID_Here"

# Gate access control
gate_access_lock = threading.Lock()
is_gate_processing = False

# QR Code scanning control
last_qr_data = None
last_detection_time = 0

# LED status control
led_status_lock = threading.Lock()
led_status_thread = None
stop_led_thread = False

# Initialize GPIO
GPIO.setmode(GPIO.BCM)
GPIO.setup(SERVO_PIN, GPIO.OUT)
GPIO.setup(LED_RED_PIN, GPIO.OUT)
GPIO.setup(LED_BLUE_PIN, GPIO.OUT)
servo = GPIO.PWM(SERVO_PIN, 50)  # 50Hz PWM frequency
servo.start(0)

# Initialize Firebase
cred = credentials.Certificate(firebase_credentials_path)
firebase_admin.initialize_app(cred, {'databaseURL': database_url})

def led_status_controller():
    """Control LED status - red by default, blue for 10 seconds on access"""
    global stop_led_thread, is_gate_processing
    
    print("🔴 Starting LED status controller - Red LED active")
    
    while not stop_led_thread:
        with led_status_lock:
            if is_gate_processing:
                # Turn on blue LED, turn off red LED
                GPIO.output(LED_BLUE_PIN, GPIO.HIGH)
                GPIO.output(LED_RED_PIN, GPIO.LOW)
            else:
                # Turn on red LED, turn off blue LED
                GPIO.output(LED_RED_PIN, GPIO.HIGH)
                GPIO.output(LED_BLUE_PIN, GPIO.LOW)
        
        time.sleep(0.1)  # Check status every 100ms
    
    # Turn off both LEDs when stopping
    GPIO.output(LED_RED_PIN, GPIO.LOW)
    GPIO.output(LED_BLUE_PIN, GPIO.LOW)
    print("🔴 LED status controller stopped")

def start_led_controller():
    """Start the LED status controller thread"""
    global led_status_thread, stop_led_thread
    
    stop_led_thread = False
    led_status_thread = threading.Thread(target=led_status_controller)
    led_status_thread.daemon = True
    led_status_thread.start()

def stop_led_controller():
    """Stop the LED status controller thread"""
    global stop_led_thread, led_status_thread
    
    stop_led_thread = True
    if led_status_thread and led_status_thread.is_alive():
        led_status_thread.join(timeout=1.0)

def move_servo(angle):
    """Move servo to specified angle"""
    duty = 2 + (angle / 18)
    servo.ChangeDutyCycle(duty)
    time.sleep(1)
    servo.ChangeDutyCycle(0)

def blink_led(pin, duration):
    """Blink LED for specified duration (for error indication)"""
    # Temporarily override LED controller for error indication
    with led_status_lock:
        GPIO.output(LED_RED_PIN, GPIO.LOW)
        GPIO.output(LED_BLUE_PIN, GPIO.LOW)
        
        # Blink the specified LED
        for _ in range(int(duration)):
            GPIO.output(pin, GPIO.HIGH)
            time.sleep(0.5)
            GPIO.output(pin, GPIO.LOW)
            time.sleep(0.5)
    
def gate_access_sequence():
    """Handle the complete gate access sequence with 10-second blocking"""
    global is_gate_processing
    
    with gate_access_lock:
        is_gate_processing = True
        print("🚪 Exit gate access sequence started - LED changing to BLUE")
        print("🔵 Blue LED active - blocking new requests for 10 seconds")
        
        try:
            # Open gate
            print("🔓 Opening exit gate...")
            move_servo(90)
            
            # Wait 10 seconds (gate stays open, LED stays blue)
            print("⏳ Exit gate open - waiting 10 seconds...")
            time.sleep(10)
            
            # Close gate
            print("🔒 Closing exit gate...")
            move_servo(0)
            
        except Exception as e:
            print(f"❌ Error in exit gate sequence: {e}")
            # Ensure gate closes even if there's an error
            move_servo(0)
        
        finally:
            is_gate_processing = False
            print("✅ Exit gate access sequence completed - LED returning to RED")
            print("🔴 Red LED active - ready for new requests")
 
def validate_exit_payment(parking_id, spot_id, user_id, payment_type):
    """Validate exit payment in payment_qrcodes structure"""
    try:
        # Check if this is the correct parking
        if parking_id != ASSIGNED_PARKING_ID:
            print(f"❌ Wrong parking ID. Expected {ASSIGNED_PARKING_ID}, got {parking_id}")
            return False
        
        # Check if this is an exit payment
        if payment_type != "payment_exit":
            print(f"❌ Wrong payment type. Expected 'payment_exit', got '{payment_type}'")
            return False
            
        # Get payment data from Firebase using the new path structure
        payment_ref = db.reference(f"payment_qrcodes/{parking_id}/{spot_id}")
        payment_data = payment_ref.get()
        
        if not payment_data:
            print(f"❌ Payment data not found for spot {spot_id} in parking {parking_id}")
            return False
            
        # Check if user matches
        if payment_data.get('userId') != user_id:
            print(f"❌ User ID doesn't match. Expected {payment_data.get('userId')}, got {user_id}")
            return False
            
        # Check if payment is active
        if payment_data.get('status') != 'active':
            print(f"❌ Payment status is not active: {payment_data.get('status')}")
            return False
        
        # Check if payment type matches
        if payment_data.get('type') != 'payment_exit':
            print(f"❌ Payment type mismatch. Expected 'payment_exit', got {payment_data.get('type')}")
            return False
            
        # Check expiry time
        current_time = int(time.time() * 1000)
        expiry_time = payment_data.get('expiryTime', 0)
        
        if current_time > expiry_time:
            print(f"❌ Payment has expired. Current: {current_time}, Expiry: {expiry_time}")
            return False
        
        print(f"✅ Valid exit payment found:")
        print(f"  - Payment ID: {payment_data.get('paymentId')}")
        print(f"  - Money Paid: {payment_data.get('moneyPaid')}")
        print(f"  - Expiry Time: {expiry_time}")
        print(f"  - Time remaining: {(expiry_time - current_time) / 1000 / 60:.1f} minutes")
        
        return True
        
    except Exception as e:
        print(f"❌ Exit validation error: {e}")
        return False

def handle_qr_data(qr_data):
    """Process QR code data and execute gate control"""
    global is_gate_processing, last_qr_data, last_detection_time
    
    current_time = time.time()
    
    # Check if gate is currently processing
    if is_gate_processing:
        print("🚪 Exit gate is currently processing - ignoring new QR scan")
        return
    
    # Check if this is the same QR code scanned recently (within 5 seconds)
    if (qr_data == last_qr_data and 
        current_time - last_detection_time < 5.0):
        return  # Ignore duplicate scans
    
    try:
        # Try to parse QR data as JSON
        payload = json.loads(qr_data)
        print(f"🎯 Received exit QR data: {payload}")
        
        # Extract required fields for exit
        parking_id = payload.get('parkingId')
        spot_id = payload.get('spotId')  # Note: spotId instead of spotNumber
        user_id = payload.get('userId')
        payment_type = payload.get('type')
        
        # Validate required fields
        if not all([parking_id, spot_id, user_id, payment_type]):
            print("❌ Missing required fields in QR data")
            blink_led(LED_RED_PIN, 3)
            return
        
        if validate_exit_payment(parking_id, spot_id, user_id, payment_type):
            print("✅ Valid exit payment - initiating gate access sequence")
            
            # Update payment access time before starting gate sequence
            try:
                db.reference(f"payment_qrcodes/{parking_id}/{spot_id}").update({
                    'lastExitAccess': int(time.time() * 1000),
                    'exitAccessCount': firebase_admin.db.Increment(1)
                })
                print("📝 Updated exit access timestamp in Firebase")
            except Exception as e:
                print(f"❌ Error updating Firebase: {e}")
            
            # Update last detection time and data
            last_qr_data = qr_data
            last_detection_time = current_time
            
            # Start gate access sequence in a separate thread to avoid blocking camera
            gate_thread = threading.Thread(target=gate_access_sequence)
            gate_thread.daemon = True
            gate_thread.start()
            
        else:
            print("❌ Invalid exit payment - showing error")
            blink_led(LED_RED_PIN, 3)
            last_qr_data = qr_data
            last_detection_time = current_time
            
    except json.JSONDecodeError as e:
        print(f"❌ QR data is not valid JSON: {qr_data}")
        print(f"❌ JSON decode error: {e}")
        blink_led(LED_RED_PIN, 3)
    except Exception as e:
        print(f"❌ Error processing QR code: {e}")
        blink_led(LED_RED_PIN, 3)

def draw_qr_overlay(frame, qr_codes):
    """Draw bounding boxes and data on detected QR codes"""
    for qr_code in qr_codes:
        # Get the bounding box coordinates
        points = qr_code.polygon
        
        # If we have 4 points, draw the polygon
        if len(points) == 4:
            # Convert points to numpy array for OpenCV
            pts = np.array([[point.x, point.y] for point in points], np.int32)
            pts = pts.reshape((-1, 1, 2))
            
            # Draw the bounding polygon
            cv2.polylines(frame, [pts], True, (0, 255, 0), 3)
        else:
            # Fallback to rectangle if polygon is not available
            x, y, w, h = qr_code.rect
            cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 3)
        
        # Decode the QR code data
        qr_data = qr_code.data.decode('utf-8')
        
        # Position for text (top-left of bounding box)
        x, y, w, h = qr_code.rect
        text_y = max(y - 10, 20)  # Ensure text doesn't go off screen
        
        # Draw background rectangle for text (shorter preview)
        preview_text = qr_data[:30] + "..." if len(qr_data) > 30 else qr_data
        text_size = cv2.getTextSize(preview_text, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)[0]
        cv2.rectangle(frame, (x, text_y - text_size[1] - 10), 
                     (x + text_size[0] + 10, text_y + 5), (0, 255, 0), -1)
        
        # Draw the QR code data preview as text
        cv2.putText(frame, preview_text, (x + 5, text_y), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)

def list_cameras():
    """List available cameras"""
    print("🔍 Scanning for available cameras...")
    available_cameras = []
    
    # Test camera indices 0-9
    for i in range(10):
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            # Try to read a frame to confirm camera works
            ret, frame = cap.read()
            if ret:
                # Get camera properties
                width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
                height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
                fps = int(cap.get(cv2.CAP_PROP_FPS))
                
                available_cameras.append({
                    'index': i,
                    'width': width,
                    'height': height,
                    'fps': fps
                })
                print(f"📷 Camera {i}: {width}x{height} @ {fps}fps")
        cap.release()
    
    return available_cameras

def start_qr_scanning(camera_index=0):
    """Start QR code scanning with live camera stream"""
    global last_qr_data, last_detection_time
    
    print(f"🎥 Starting QR scanner with camera {camera_index}...")
    print(f"🏢 Monitoring parking: {ASSIGNED_PARKING_ID}")
    
    # Start LED controller
    start_led_controller()
    
    # Initialize camera
    cap = cv2.VideoCapture(camera_index)
    
    if not cap.isOpened():
        print(f"❌ Error: Could not open camera {camera_index}")
        stop_led_controller()
        return False
    
    # Set camera properties for better performance
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)
    
    # Get actual camera properties
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    
    print(f"✅ Camera initialized: {width}x{height} @ {fps}fps")
    print("🎯 Point camera at exit payment QR codes")
    print("🔑 Press 'q' to quit, 's' to save screenshot")
    print("🔴 Red LED: Standby | 🔵 Blue LED: Access Granted")
    print("-" * 60)
    
    frame_count = 0
    start_time = time.time()
    
    try:
        while True:
            # Read frame from camera
            ret, frame = cap.read()
            if not ret:
                print("❌ Error: Could not read frame from camera")
                break
            
            frame_count += 1
            
            # Convert BGR to RGB for pyzbar
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Decode QR codes
            qr_codes = pyzbar.decode(frame_rgb)
            
            # Process detected QR codes
            current_time = time.time()
            if qr_codes:
                # Draw overlays
                draw_qr_overlay(frame, qr_codes)
                
                # Process QR code data
                for qr_code in qr_codes:
                    qr_data = qr_code.data.decode('utf-8')
                    qr_type = qr_code.type
                    
                    # Only process if it's a new QR code or enough time has passed
                    if (qr_data != last_qr_data or 
                        current_time - last_detection_time > 5.0):
                        
                        print(f"\n🎯 QR Code Detected!")
                        print(f"Type: {qr_type}")
                        print(f"Data: {qr_data}")
                        print(f"Time: {time.strftime('%H:%M:%S')}")
                        print("-" * 50)
                        
                        # Process the QR code for gate control
                        handle_qr_data(qr_data)
            
            # Add status text to frame
            status_text = f"Exit Gate Controller | Camera {camera_index} | Frame: {frame_count}"
            if is_gate_processing:
                status_text += " | GATE ACTIVE - BLUE LED"
            elif qr_codes:
                status_text += f" | QR Codes: {len(qr_codes)} - RED LED"
            else:
                status_text += " | Scanning... - RED LED"
            
            # Calculate FPS
            if frame_count % 30 == 0:  # Update every 30 frames
                elapsed = time.time() - start_time
                actual_fps = frame_count / elapsed
                status_text += f" | FPS: {actual_fps:.1f}"
            
            # Draw status text
            cv2.putText(frame, status_text, (10, 30), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)
            cv2.putText(frame, "Press 'q' to quit, 's' to save screenshot", 
                       (10, height - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
            
            # Add gate and LED status indicator
            if is_gate_processing:
                gate_status = "GATE: ACTIVE | LED: BLUE"
                gate_color = (255, 255, 0)  # Cyan for blue LED indication
            else:
                gate_status = "GATE: READY | LED: RED"
                gate_color = (0, 0, 255)  # Red for red LED indication
                
            cv2.putText(frame, gate_status, (10, 60), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, gate_color, 2)
            
            # Display the frame
            cv2.imshow('Exit Gate QR Scanner', frame)
            
            # Check for key presses
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord('s'):
                # Save screenshot
                timestamp = time.strftime('%Y%m%d_%H%M%S')
                filename = f"gate_screenshot_{timestamp}.jpg"
                cv2.imwrite(filename, frame)
                print(f"📸 Screenshot saved: {filename}")
            
    except KeyboardInterrupt:
        print("\n⏹️  Stopping QR scanner...")
    
    finally:
        # Clean up
        cap.release()
        cv2.destroyAllWindows()
        stop_led_controller()
        
        # Print statistics
        elapsed = time.time() - start_time
        avg_fps = frame_count / elapsed if elapsed > 0 else 0
        print(f"\n📊 Session Statistics:")
        print(f"   Frames processed: {frame_count}")
        print(f"   Duration: {elapsed:.1f} seconds")
        print(f"   Average FPS: {avg_fps:.1f}")
        print("Thanks for using the Exit Gate Controller!")
    
    return True

def main():
    print("🚪 Exit Gate Controller with QR Scanner & LED Status")
    print("=" * 50)
    print(f"🏢 Assigned Parking ID: {ASSIGNED_PARKING_ID}")
    print("🎯 Scanning for exit payment QR codes...")
    print("🔴 Red LED: Standby mode")
    print("🔵 Blue LED: Access granted (10 seconds)")
    
    try:
        # List available cameras
        cameras = list_cameras()
        
        if not cameras:
            print("❌ No cameras found!")
            print("Make sure a camera is connected and try again.")
            return
        
        # Select camera
        if len(cameras) == 1:
            camera_index = cameras[0]['index']
            print(f"📷 Using camera {camera_index}")
        else:
            print(f"\nFound {len(cameras)} camera(s):")
            for cam in cameras:
                print(f"  {cam['index']}: {cam['width']}x{cam['height']} @ {cam['fps']}fps")
            
            while True:
                try:
                    camera_index = int(input("Enter camera index to use: ").strip())
                    if any(cam['index'] == camera_index for cam in cameras):
                        break
                    else:
                        print(f"❌ Invalid camera index: {camera_index}")
                except ValueError:
                    print("❌ Please enter a valid number!")
        
        # Start QR scanning
        start_qr_scanning(camera_index)
        
    except KeyboardInterrupt:
        print("\n⏹️  Shutting down exit gate controller...")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        # Clean up GPIO
        try:
            stop_led_controller()
            servo.stop()
            GPIO.cleanup()
            print("🧹 GPIO cleanup completed")
        except:
            pass

if __name__ == "__main__":
    # Handle command line arguments
    if len(sys.argv) > 1:
        if sys.argv[1] in ['-h', '--help']:
            print("Exit Gate Controller with QR Scanner & LED Status")
            print("Usage: python3 gate_controller.py [camera_index]")
            print("Example: python3 gate_controller.py 0")
            print("\nLED Status:")
            print("🔴 Red LED: Continuous operation (standby/ready)")
            print("🔵 Blue LED: Access granted (10 seconds)")
            sys.exit(0)
        else:
            try:
                camera_index = int(sys.argv[1])
                print(f"🎥 Using specified camera: {camera_index}")
                start_qr_scanning(camera_index)
            except ValueError:
                print("❌ Invalid camera index!")
                sys.exit(1)
    else:
        main()