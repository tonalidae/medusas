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
    max_num_hands=2,
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

        # 3. Extract & Send Data (support up to 2 hands, sent in left->right order)
        if results.multi_hand_landmarks:
            hands_list = []
            # Only send the index-finger tip (landmark 8) per hand
            # Send x, y, z so Processing can be depth-sensitive
            key_indices = [8]
            # Collect per-hand data and a sort key (avg x)
            for hand_landmarks in results.multi_hand_landmarks:
                osc_data_hand = []
                # use the index fingertip (x,y,z) as the representative point and sort key
                lm = hand_landmarks.landmark[key_indices[0]]
                osc_data_hand.append(lm.x)
                osc_data_hand.append(lm.y)
                osc_data_hand.append(lm.z)
                avg_x = lm.x
                hands_list.append((avg_x, osc_data_hand, hand_landmarks))

            # Sort left-to-right (image coords), then flatten
            hands_list.sort(key=lambda item: item[0])
            osc_data = []
            for _, hand_pair_list, hand_landmarks in hands_list:
                osc_data.extend(hand_pair_list)
                # Debug draw for this hand
                h, w, c = image.shape
                for idx in key_indices:
                    lm = hand_landmarks.landmark[idx]
                    cx, cy = int(lm.x * w), int(lm.y * h)
                    color = (0, 255, 0)
                    cv2.circle(image, (cx, cy), 8, color, cv2.FILLED)

            # Send single flat list: [hand1_x1,hand1_y1,...,handN_x6,handN_y6]
            client.send_message("/hand", osc_data)

        cv2.imshow('Hand Tracker Debug', image)
        if cv2.waitKey(5) & 0xFF == ord('q'):
            break

except KeyboardInterrupt:
    pass

cap.release()
cv2.destroyAllWindows()