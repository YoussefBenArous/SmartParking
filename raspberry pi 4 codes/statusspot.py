import paho.mqtt.client as mqtt
import firebase_admin
from firebase_admin import credentials, db
import json

# MQTT Configuration
broker = '192.168.137.86'
port = 8000
status_topic = "Your status topic here"  # Replace with your actual status topic
access_topic = "Your access topic here"  # Replace with your actual access topic

# Firebase Configuration
firebase_credentials_path = 'Your Firebase Admin SDK JSON file path here'  # Replace with your actual path
database_url = 'Your Firebase Realtime Database URL here'  # Replace with your actual database URL

# Initialize Firebase
cred = credentials.Certificate(firebase_credentials_path)
firebase_admin.initialize_app(cred, {
    'databaseURL': database_url
})

def handle_status_message(payload):
    try:
        spot_id = payload.get('spotId')
        status = payload.get('status')
        distance = payload.get('distance')
        parking_id = payload.get('parkingId')

        if spot_id and status and parking_id:
            ref_path = f"spots/{parking_id}/{spot_id}"
            ref = db.reference(ref_path)
            ref.update({
                'status': status,
                'distance': distance
            })
            print(f"[STATUS] Updated Firebase at {ref_path}")
    except Exception as e:
        print(f"[STATUS] Error: {e}")

def handle_access_message(payload):
    try:
        qrcode_id = payload.get('qrcode_id')
        parking_id = payload.get('parking_id')
        spot_id = payload.get('spot_id')

        if qrcode_id and parking_id and spot_id:
            ref_path = f"access_control/{parking_id}/{spot_id}"
            ref = db.reference(ref_path)
            data = ref.get()

            if data:
                stored_qr = data.get('qrcode_id')
                is_granted = data.get('is_access_granted', False)

                if stored_qr == qrcode_id and is_granted:
                    print(f"[ACCESS] Access granted for QR ID {qrcode_id}")
                    # Optionally, trigger GPIO or other hardware here
                else:
                    print(f"[ACCESS] Access denied for QR ID {qrcode_id}")
            else:
                print(f"[ACCESS] No access data found for {ref_path}")
    except Exception as e:
        print(f"[ACCESS] Error: {e}")

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT Broker!")
        client.subscribe(status_topic)
        client.subscribe(access_topic)
    else:
        print(f"Failed to connect, return code {rc}")

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
        print(f"\nReceived message on topic {msg.topic}: {payload}")

        if msg.topic == status_topic:
            handle_status_message(payload)
        elif msg.topic == access_topic:
            handle_access_message(payload)
    except Exception as e:
        print(f"[MQTT] Message error: {e}")

def main():
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(broker, port, 60)
    client.loop_forever()

if __name__ == "__main__":
    main()
