"""
Multi-person upper-limb tracker using MediaPipe Pose Landmarker (Tasks API) that
feeds the Processing sketch via OSC:
  /hands: [present, x, y, z] * MAX_SLOTS   (x,y normalized; z = -bbox_height depth proxy)
  /hand_size: [size] * MAX_SLOTS
  /arm_energy: [energy] * MAX_SLOTS

Why this is better:
- Uses MediaPipe's Pose Landmarker (multi-person) instead of HOG proposals, reducing false positives.
- Confidence + size gating to drop tiny/low-score hits.
- Smoothing and longer grace period to avoid flicker when tracks momentarily drop.
"""

import cv2
import mediapipe as mp
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python import vision
from pythonosc import udp_client
from pathlib import Path

# --- CONFIGURATION ---
IP = "127.0.0.1"      # Destination IP for OSC (Processing host)
PORT = 12000          # Destination port for OSC (Processing port)
MAX_SLOTS = 4         # Up to 4 simultaneous people
CAM_INDEX = 0
CAM_WIDTH = 1280
CAM_HEIGHT = 720
MODEL_PATH = Path("pose_landmarker_full.task")  # supply your task file here
MIN_SCORE = 0.55      # landmark presence/confidence threshold
MIN_SIZE = 0.03       # normalized height; filter out tiny ghosts
SMOOTH_ALPHA = 0.30   # smoothing for centers/energy to reduce jitter
MISS_FORGET = 14      # frames to keep a slot alive after missed detection
# Anchor choice for OSC position: "wrists" tracks arm tips; "shoulders" is steadier
ANCHOR = "wrists"
# ---------------------

USE_CLAHE_NORMALIZATION = True
CLAHE_BRIGHTNESS_THRESHOLD = 95.0
CLAHE_CLIP_LIMIT = 3.0
CLAHE_TILE_GRID = (8, 8)
CONFIDENCE_ALPHA_MIN = 0.18
CONFIDENCE_ALPHA_MAX = 0.9
CONFIDENCE_SIZE_SCALE = 0.6

MODEL_URL = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task"

def ensure_model(path: Path, url: str):
    if path.exists():
        return
    print(f"[INFO] Downloading model to {path} ...")
    path.parent.mkdir(parents=True, exist_ok=True)
    import urllib.request
    urllib.request.urlretrieve(url, path)
    print("[INFO] Model download complete.")

# Auto-download model if missing
try:
    ensure_model(MODEL_PATH, MODEL_URL)
except Exception as e:
    print(f"[WARN] Could not download model automatically ({e}). "
          f"Download manually from:\n  {MODEL_URL}\n"
          f"and place it as {MODEL_PATH}")

client = udp_client.SimpleUDPClient(IP, PORT)

cap = cv2.VideoCapture(CAM_INDEX)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAM_WIDTH)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAM_HEIGHT)
cap.set(cv2.CAP_PROP_FPS, 30)

BaseOptions = mp_tasks.BaseOptions
PoseLandmarker = vision.PoseLandmarker
PoseLandmarkerOptions = vision.PoseLandmarkerOptions
VisionRunningMode = vision.RunningMode

options = PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=str(MODEL_PATH)),
    running_mode=VisionRunningMode.VIDEO,
    num_poses=MAX_SLOTS,
    min_pose_detection_confidence=MIN_SCORE,
    min_pose_presence_confidence=MIN_SCORE,
    min_tracking_confidence=MIN_SCORE,
    output_segmentation_masks=False,
)

landmarker = PoseLandmarker.create_from_options(options)
timestamp_ms = 0

slots = [{
    "active": False,
    "center": (0.0, 0.0),
    "size": 0.0,
    "miss": 0,
    "energy": 0.0,
} for _ in range(MAX_SLOTS)]

def smooth(old, new, alpha):
    return (1 - alpha) * old + alpha * new

def detection_alpha(size):
    norm = max(0.0, min(1.0, size * CONFIDENCE_SIZE_SCALE))
    return CONFIDENCE_ALPHA_MIN + (CONFIDENCE_ALPHA_MAX - CONFIDENCE_ALPHA_MIN) * norm

def blended_alpha(size):
    det_alpha = detection_alpha(size)
    return SMOOTH_ALPHA + (det_alpha - SMOOTH_ALPHA) * det_alpha

def preprocess_for_detection(frame, processor):
    if processor is None or not USE_CLAHE_NORMALIZATION:
        return frame
    if frame.mean() >= CLAHE_BRIGHTNESS_THRESHOLD:
        return frame
    lab = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    l = processor.apply(l)
    lab = cv2.merge((l, a, b))
    return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

def compute_energy(lms, w, h):
    idx = mp.solutions.pose.PoseLandmark
    pairs = [
        (idx.LEFT_SHOULDER, idx.LEFT_ELBOW),
        (idx.LEFT_ELBOW, idx.LEFT_WRIST),
        (idx.RIGHT_SHOULDER, idx.RIGHT_ELBOW),
        (idx.RIGHT_ELBOW, idx.RIGHT_WRIST),
    ]
    total = 0.0
    for a, b in pairs:
        pa, pb = lms[a.value], lms[b.value]
        dx = (pa.x - pb.x) * w
        dy = (pa.y - pb.y) * h
        total += (dx * dx + dy * dy) ** 0.5
    return total / len(pairs)

def bbox_height(lms):
    ys = [p.y for p in lms]
    return max(0.0, max(ys) - min(ys))

print(f"[Pose→OSC] sending to {IP}:{PORT} — press 'q' to quit")

try:
    clahe_processor = None
    if USE_CLAHE_NORMALIZATION:
        clahe_processor = cv2.createCLAHE(clipLimit=CLAHE_CLIP_LIMIT, tileGridSize=CLAHE_TILE_GRID)

    while cap.isOpened():
        ok, frame = cap.read()
        if not ok:
            continue

        frame = cv2.flip(frame, 1)  # mirror for screen-facing setups
        processed_frame = preprocess_for_detection(frame, clahe_processor)
        rgb = cv2.cvtColor(processed_frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

        timestamp_ms += 33  # approx 30 FPS; MediaPipe VIDEO mode requires timestamps
        result = landmarker.detect_for_video(mp_image, timestamp_ms)

        detections = []
        if result.pose_landmarks:
            # pose_landmarks is a list per detected person
            for lms in result.pose_landmarks:
                bh = bbox_height(lms)
                if bh < MIN_SIZE:
                    continue
                idx = mp.solutions.pose.PoseLandmark
                sh_l = lms[idx.LEFT_SHOULDER.value]
                sh_r = lms[idx.RIGHT_SHOULDER.value]
                wr_l = lms[idx.LEFT_WRIST.value]
                wr_r = lms[idx.RIGHT_WRIST.value]

                if ANCHOR == "wrists":
                    # Use wrists to better follow arm motion; fall back to shoulders if wrists are invalid
                    cx = (wr_l.x + wr_r.x) * 0.5
                    cy = (wr_l.y + wr_r.y) * 0.5
                    if not (0 <= cx <= 1 and 0 <= cy <= 1):
                        cx = (sh_l.x + sh_r.x) * 0.5
                        cy = (sh_l.y + sh_r.y) * 0.5
                else:
                    cx = (sh_l.x + sh_r.x) * 0.5
                    cy = (sh_l.y + sh_r.y) * 0.5

                energy = compute_energy(lms, frame.shape[1], frame.shape[0])
                detections.append({
                    "center": (cx, cy),
                    "size": bh,
                    "energy": energy,
                })

        # Sort left→right for stable slot assignment
        detections.sort(key=lambda d: d["center"][0])

        # 1) Update active slots
        assigned = set()
        for s in slots:
            if not s["active"]:
                continue
            best = -1
            best_d = 1e9
            for i, det in enumerate(detections):
                if i in assigned:
                    continue
                dx = det["center"][0] - s["center"][0]
                dy = det["center"][1] - s["center"][1]
                d = dx * dx + dy * dy
                if d < best_d:
                    best_d = d
                    best = i
            if best >= 0:
                det = detections[best]
                alpha = blended_alpha(det["size"])
                s["center"] = (smooth(s["center"][0], det["center"][0], alpha),
                               smooth(s["center"][1], det["center"][1], alpha))
                s["size"] = smooth(s["size"], det["size"], alpha)
                s["energy"] = smooth(s["energy"], det["energy"], alpha)
                s["miss"] = 0
                s["active"] = True
                assigned.add(best)
            else:
                s["miss"] += 1
                if s["miss"] > MISS_FORGET:
                    s["active"] = False

        # 2) Fill empty slots
        for i, det in enumerate(detections):
            if i in assigned:
                continue
            for s in slots:
                if not s["active"]:
                    s["center"] = det["center"]
                    s["size"] = det["size"]
                    s["energy"] = det["energy"]
                    s["miss"] = 0
                    s["active"] = True
                    assigned.add(i)
                    break

        # 3) Build OSC payloads
        osc_hands = []
        osc_sizes = []
        osc_energy = []
        h, w = frame.shape[:2]
        for s in slots:
            present = 1.0 if s["active"] and s["miss"] <= MISS_FORGET else 0.0
            x, y = s["center"] if present else (0.0, 0.0)
            z = -s["size"] if present else 0.0  # negative depth proxy (bigger → nearer)
            osc_hands.extend([present, x, y, z])
            osc_sizes.append(s["size"] if present else 0.0)
            osc_energy.append(s["energy"] if present else 0.0)

            # Debug overlay
            if present:
                cx_i, cy_i = int(x * w), int(y * h)
                cv2.circle(frame, (cx_i, cy_i), int(12 + s["energy"] * 0.04), (0, 200, 255), 2)
                cv2.putText(frame, f"{s['energy']:.1f}", (cx_i + 10, cy_i - 10),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 200, 255), 1, cv2.LINE_AA)

        client.send_message("/hands", osc_hands)
        client.send_message("/hand_size", osc_sizes)
        client.send_message("/arm_energy", osc_energy)

        cv2.imshow("Pose to OSC (upper-limb)", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

except KeyboardInterrupt:
    pass
finally:
    cap.release()
    landmarker.close()
    cv2.destroyAllWindows()
