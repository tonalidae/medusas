import cv2
import mediapipe as mp
from pythonosc import udp_client

# --- CONFIGURATION ---
IP = "127.0.0.1"    # Localhost
PORT = 12000        # Processing Port
# ---------------------

client = udp_client.SimpleUDPClient(IP, PORT)

mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    max_num_hands=1,
    model_complexity=1,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5
)

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FPS, 30)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

print(f"--- Volumetric Hand Tracker Running ---")
print(f"--- Sending to {IP}:{PORT} ---")
print("--- Press 'q' to quit ---")

try:
    while cap.isOpened():
        success, image = cap.read()
        if not success: continue

        # 1. Flip for mirror effect
        image = cv2.flip(image, 1)

        # 2. Process Hands
        image.flags.writeable = False
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = hands.process(image_rgb)
        image.flags.writeable = True

        # 3. Extract & Send Data
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                # Key Points: Thumb(4), Index(8), Middle(12), Ring(16), Pinky(20), Palm(9)
                key_indices = [4, 8, 12, 16, 20, 9]
                osc_data = []
                
                for idx in key_indices:
                    lm = hand_landmarks.landmark[idx]
                    osc_data.append(lm.x)
                    osc_data.append(lm.y)
                    
                    # Debug Draw
                    h, w, c = image.shape
                    cx, cy = int(lm.x * w), int(lm.y * h)
                    color = (0, 255, 0) if idx == 9 else (255, 0, 255) # Green for palm
                    cv2.circle(image, (cx, cy), 8, color, cv2.FILLED)

                # Send flat list: [x1, y1, x2, y2, ...]
                client.send_message("/hand", osc_data)

        cv2.imshow('Hand Tracker Debug', image)
        if cv2.waitKey(5) & 0xFF == ord('q'):
            break

except KeyboardInterrupt:
    pass

cap.release()
cv2.destroyAllWindows()