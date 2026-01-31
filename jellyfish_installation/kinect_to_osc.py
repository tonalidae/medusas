"""
Kinect → OSC bridge for the jellyfish installation.

Tested with Azure Kinect + pyk4a Body Tracking SDK.
Sends the same OSC bundles the Processing sketch already consumes:
  /hands: [present, x, y, z] * MAX_SLOTS   (x,y normalized 0..1; z = -bbox_height proxy)
  /hand_size: [size] * MAX_SLOTS          (normalized body height)
  /arm_energy: [energy] * MAX_SLOTS       (per-frame arm motion magnitude)

Install system deps: Azure Kinect SDK + Body Tracking SDK.
Python deps (requirements.txt): pyk4a, python-osc.
Run: python kinect_to_osc.py
"""

import time
from collections import deque
from pathlib import Path

from pythonosc import udp_client
from pyk4a import Config, PyK4A, BodyTrackingModule, K4ABT_JOINT_WRIST_LEFT, K4ABT_JOINT_WRIST_RIGHT, K4ABT_JOINT_SHOULDER_LEFT, K4ABT_JOINT_SHOULDER_RIGHT

# --- CONFIG ---
IP = "127.0.0.1"
PORT = 12000
MAX_SLOTS = 4
FPS_LIMIT = 30
SMOOTH_ALPHA = 0.35       # position smoothing to reduce jitter
ENERGY_HISTORY = 3        # frames to average for energy
CONFIDENCE_MIN = 0.35
MIRROR = True             # mirror X for screen-facing setup
# ----------------

client = udp_client.SimpleUDPClient(IP, PORT)

# Helpers
def smooth(prev, new, alpha):
    return prev * (1 - alpha) + new * alpha

def clamp01(v):
    return max(0.0, min(1.0, v))

class Slot:
    def __init__(self):
        self.active = False
        self.cx = 0.0
        self.cy = 0.0
        self.size = 0.0
        self.energy_hist = deque(maxlen=ENERGY_HISTORY)
        self.energy = 0.0
        self.z_proxy = 0.0

slots = [Slot() for _ in range(MAX_SLOTS)]

def joint_xy(j, width, height):
    x = j.position.v[0] / width
    y = j.position.v[1] / height
    return x, y, j.confidence_level

def update_slots(bodies, width, height):
    # Sort bodies by x to keep stable ordering
    ordered = sorted(bodies, key=lambda b: b.skeleton.joints[K4ABT_JOINT_SHOULDER_LEFT].position.v[0])
    for i, slot in enumerate(slots):
        if i < len(ordered):
            sk = ordered[i].skeleton
            wl = sk.joints[K4ABT_JOINT_WRIST_LEFT]
            wr = sk.joints[K4ABT_JOINT_WRIST_RIGHT]
            sl = sk.joints[K4ABT_JOINT_SHOULDER_LEFT]
            sr = sk.joints[K4ABT_JOINT_SHOULDER_RIGHT]
            conf = min(wl.confidence_level, wr.confidence_level, sl.confidence_level, sr.confidence_level)
            if conf < CONFIDENCE_MIN:
                slot.active = False
                continue
            xL, yL, _ = joint_xy(wl, width, height)
            xR, yR, _ = joint_xy(wr, width, height)
            if MIRROR:
                xL = 1.0 - xL
                xR = 1.0 - xR
            cx = (xL + xR) * 0.5
            cy = (yL + yR) * 0.5
            size = clamp01((max(yL, yR, joint_xy(sl, width, height)[1], joint_xy(sr, width, height)[1]) -
                            min(yL, yR, joint_xy(sl, width, height)[1], joint_xy(sr, width, height)[1])))

            # Smooth positions
            slot.cx = smooth(slot.cx, cx, SMOOTH_ALPHA)
            slot.cy = smooth(slot.cy, cy, SMOOTH_ALPHA)
            slot.size = smooth(slot.size, size, SMOOTH_ALPHA)
            # Energy: wrist span + frame-to-frame change
            span = ((xL - xR) ** 2 + (yL - yR) ** 2) ** 0.5
            slot.energy_hist.append(span)
            slot.energy = sum(slot.energy_hist) / max(1, len(slot.energy_hist))
            slot.z_proxy = -slot.size
            slot.active = True
        else:
            slot.active = False
            slot.energy_hist.clear()

def send_osc():
    hands = []
    sizes = []
    energies = []
    for s in slots:
        if s.active:
            hands.extend([1, s.cx, s.cy, s.z_proxy])
            sizes.append(s.size)
            energies.append(s.energy)
        else:
            hands.extend([0, 0, 0, 0])
            sizes.append(0)
            energies.append(0)
    client.send_message("/hands", hands)
    client.send_message("/hand_size", sizes)
    client.send_message("/arm_energy", energies)

def main():
    device = PyK4A(Config(color_resolution=pyk4a.ColorResolution.OFF,
                          depth_mode=pyk4a.DepthMode.NFOV_UNBINNED,
                          camera_fps=pyk4a.FPS.FPS30,
                          synchronized_images_only=True))
    device.start()
    tracker = BodyTrackingModule(device)
    last_send = 0
    print(f"[Kinect→OSC] sending to {IP}:{PORT} — press Ctrl+C to quit")
    try:
        while True:
            capture = device.get_capture()
            bodies = tracker.update()
            update_slots(bodies, tracker.body_tracker_calibration.color_camera_calibration.resolution_width,
                         tracker.body_tracker_calibration.color_camera_calibration.resolution_height)
            now = time.time()
            if now - last_send >= 1.0 / FPS_LIMIT:
                send_osc()
                last_send = now
    except KeyboardInterrupt:
        pass
    finally:
        tracker.destroy()
        device.stop()

if __name__ == "__main__":
    main()
