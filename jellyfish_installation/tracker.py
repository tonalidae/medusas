import cv2
import mediapipe as mp
from pythonosc import udp_client
import math

# --- CONFIGURATION ---
IP = "127.0.0.1"    # Localhost
PORT = 12000        # Processing Port

MAX_HANDS = 6
DIST_THRESHOLD = 0.12   # normalized xy distance for matching
MISS_FORGET = 8         # frames until a track is dropped
SMOOTH_ALPHA = 0.55     # blend factor toward new detection
# ---------------------

client = udp_client.SimpleUDPClient(IP, PORT)

mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    max_num_hands=MAX_HANDS,
    model_complexity=1,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5
)

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FPS, 30)
# Higher res helps small distant hands; 1280x720 still lightweight.
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

tracks = [{
    "active": False,
    "x": 0.0, "y": 0.0, "z": 0.0,
    "vx": 0.0, "vy": 0.0, "vz": 0.0,
    "miss": 0,
    "size": 0.0
} for _ in range(MAX_HANDS)]

print(f"--- Volumetric Hand Tracker Running ---")
print(f"--- Sending to {IP}:{PORT} ---")
print("--- Press 'q' to quit ---")

try:
    while cap.isOpened():
        success, image = cap.read()
        if not success:
            continue

        # 1. Flip for mirror effect
        image = cv2.flip(image, 1)

        # Mild blur helps ignore projector pixel noise.
        image = cv2.GaussianBlur(image, (3, 3), 0)

        # 2. Process Hands
        image.flags.writeable = False
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = hands.process(image_rgb)
        image.flags.writeable = True

        detections = []
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                lm = hand_landmarks.landmark[8]  # index fingertip
                xs = [p.x for p in hand_landmarks.landmark]
                ys = [p.y for p in hand_landmarks.landmark]
                diag = math.hypot(max(xs) - min(xs), max(ys) - min(ys))
                detections.append((lm.x, lm.y, lm.z, diag, hand_landmarks))

        # 3. Simple multi-target tracker (nearest-neighbor per slot)
        assigned_det = set()
        for t in tracks:
            if t["active"] and t["miss"] > 0:
                t["x"] += t["vx"]
                t["y"] += t["vy"]
                t["z"] += t["vz"]

        for t in tracks:
            if not t["active"]:
                continue
            best_idx = -1
            best_d = 1e9
            for di, det in enumerate(detections):
                if di in assigned_det:
                    continue
                d = math.hypot(det[0] - t["x"], det[1] - t["y"])
                if d < best_d:
                    best_d = d
                    best_idx = di
            if best_idx >= 0 and best_d <= DIST_THRESHOLD:
                dx = detections[best_idx][0] - t["x"]
                dy = detections[best_idx][1] - t["y"]
                dz = detections[best_idx][2] - t["z"]
                t["x"] += SMOOTH_ALPHA * dx
                t["y"] += SMOOTH_ALPHA * dy
                t["z"] += SMOOTH_ALPHA * dz
                t["vx"], t["vy"], t["vz"] = dx, dy, dz
                t["size"] = detections[best_idx][3]
                t["miss"] = 0
                t["active"] = True
                assigned_det.add(best_idx)
            else:
                t["miss"] += 1
                if t["miss"] > MISS_FORGET:
                    t["active"] = False

        for di, det in enumerate(detections):
            if di in assigned_det:
                continue
            for t in tracks:
                if not t["active"]:
                    t["x"], t["y"], t["z"] = det[0], det[1], det[2]
                    t["vx"] = t["vy"] = t["vz"] = 0.0
                    t["size"] = det[3]
                    t["miss"] = 0
                    t["active"] = True
                    assigned_det.add(di)
                    break

        # 4. OSC payloads
        osc_hands = []
        size_payload = []
        legacy_hand = []
        h, w, c = image.shape
        for idx, t in enumerate(tracks):
            present = 1.0 if t["active"] and t["miss"] <= MISS_FORGET else 0.0
            osc_hands.extend([present, t["x"], t["y"], t["z"]])
            size_payload.append(t["size"] if present else 0.0)

            if present:
                legacy_hand.extend([t["x"], t["y"], t["z"]])
                cx, cy = int(t["x"] * w), int(t["y"] * h)
                color = (50 + idx * 30 % 200, 255 - idx * 20 % 200, 120 + idx * 25 % 130)
                cv2.circle(image, (cx, cy), 8, color, cv2.FILLED)

        client.send_message("/hands", osc_hands)
        client.send_message("/hand_size", size_payload)
        if legacy_hand:
            client.send_message("/hand", legacy_hand)

        cv2.imshow('Hand Tracker Debug', image)
        if cv2.waitKey(5) & 0xFF == ord('q'):
            break

except KeyboardInterrupt:
    pass

cap.release()
cv2.destroyAllWindows()
