# Kinect v1 to Processing OSC Integration Guide

## Overview
This setup allows you to control the jellyfish simulation using a Kinect v1 sensor instead of mouse input. Hand positions and gestures are captured in C# and sent via OSC to Processing.

## Architecture
```
Kinect v1 Sensor
    ↓
[C# KinectOSCBridge]
    ↓ OSC Messages (127.0.0.1:12000)
[Processing Receiver - KinectOSCHandler.pde]
    ↓
Jellyfish Simulation (muchas_medusas_nadando.pde)
```

## OSC Messages Sent

### `/kinect/hand x y hand_id`
- **x, y**: Screen coordinates (0 to screen width/height)
- **hand_id**: 0 = left hand, 1 = right hand
- **Frequency**: ~30 Hz (Kinect frame rate)
- **Effect**: Replaces mouse position for wake interaction

### `/kinect/tap x y hand_id`
- **x, y**: Position where tap occurred
- **hand_id**: Which hand performed the tap
- **Triggered by**: Sudden hand movement/gesture
- **Effect**: Triggers mood changes (fear/aggression), deposits wake blob, spawns particles

### `/kinect/proximity value`
- **value**: 0.0 to 1.0 (0 = far, 1 = very close to sensor)
- **Effect**: Amplifies interaction intensity based on distance

## C# Setup Instructions

### Prerequisites
1. **Kinect v1 SDK**: Install Microsoft Kinect SDK v1.8
2. **OSC.NET Library**: Download from https://github.com/joreg/vvvv/tree/develop/vvvv45/lib/osc.net
3. **Visual Studio**: 2015 or later

### Project Configuration
1. Create new C# Console Application
2. Add references:
   - `Microsoft.Kinect.dll` (from Kinect SDK)
   - `OSC.NET.dll` (copy to project)

3. Replace `Program.cs` with `KinectOSCBridge.cs`

### Compilation
```csharp
// From Visual Studio or command line:
csc.exe /target:exe /out:KinectOSCBridge.exe /reference:Microsoft.Kinect.dll,OSC.NET.dll KinectOSCBridge.cs
```

### Running
```bash
KinectOSCBridge.exe
```

## Processing Setup

### 1. Update `Config.pde`
Add after existing `oscP5` initialization:
```processing
void setupKinect() {
  initKinectOSC();
}
```

### 2. Update `muchas_medusas_nadando.pde` main sketch
Add to `setup()`:
```processing
void setup() {
  // ... existing setup code ...
  initKinectOSC(); // Initialize Kinect OSC receiver
}
```

Add to `draw()` loop:
```processing
void draw() {
  // ... existing draw code ...
  
  updateKinectInteraction(); // Update Kinect state
  
  if (showKinectIndicator) {
    drawKinectHandIndicator(); // Visual feedback (optional)
  }
}
```

### 3. Add to `Config.pde`
```processing
boolean showKinectIndicator = true; // Visual feedback for hand position
```

## Behavior Mapping

| Mouse Behavior | Kinect Equivalent |
|---|---|
| Mouse position | Right hand position (preferred) or left hand |
| Mouse click | Hand tap gesture (sudden movement) |
| Drag motion | Smooth hand tracking |
| Click intensity | Hand proximity to camera |
| Repeated clicks | Rapid tap gestures |

## Interaction Examples

### Fear Trigger
- Rapidly tap (high gesture frequency)
- ≥10 taps accumulate fear
- Cooldown: 2.5 seconds

### Aggression Trigger
- Sustained hand movement
- ≥18 taps accumulate aggression
- Jellyfish respond with intense bloom

### Wake Deposition
- Hand position continuously affects water
- Proximity modulates interaction strength
- Taps spawn particles and create ripples

## Performance Notes

- **Kinect FPS**: 30 Hz (matches OSC update rate)
- **Processing receives**: OSC messages at ~30 Hz
- **Latency**: ~100-150ms (Kinect capture + OSC network)
- **Max taps detected**: 2-3 per second (tap cooldown prevents false triggers)

## Troubleshooting

### "No Kinect v1 sensor found!"
- Ensure Kinect v1 is plugged into USB 3.0 port
- Check Device Manager for "Kinect Sensor v1 (device)" or similar
- Reinstall Kinect SDK if not detected

### OSC messages not arriving in Processing
- Verify firewall allows localhost:12000
- Check that C# app prints "OSC Transmitter initialized"
- Use OSC debugging tool to verify messages are sent

### Jerky hand tracking
- Increase `smoothingAlpha` in C# (0.3-0.5 for more smoothing)
- Ensure Kinect is 1-3 meters from user
- Avoid reflective surfaces behind Kinect

### Taps not triggering moods
- Check `TAP_FEAR_THR` and `TAP_AGG_THR` values in `Config.pde`
- Verify tap cooldown isn't preventing detection
- Increase `tapThreshold` in C# for more sensitive detection

## Optional Customizations

### Adjust Hand Smoothing
In `KinectOSCBridge.cs`:
```csharp
private float smoothingAlpha = 0.2f; // Lower = more smoothing, Higher = more responsive
```

### Adjust Tap Sensitivity
In `KinectOSCBridge.cs`:
```csharp
private float tapThreshold = 0.3f; // Screen width fraction that triggers tap
```

### Visual Hand Indicator
In `Config.pde`:
```processing
boolean showKinectIndicator = true;
```

Shows circle at hand position with proximity indicator ring.

## Advanced: Multi-Hand Tracking

Currently uses primary hand (right preferred). To use both hands:

In `KinectOSCHandler.pde`, modify `handleKinectHandPosition()`:
```processing
void handleKinectHandPosition(int x, int y, int handId) {
  if (handId == 0) {
    // Left hand: smaller interaction area
    userTouchStrength *= 0.7;
  } else {
    // Right hand: primary interaction
    userTouchStrength = 1.0;
  }
  // ... rest of function
}
```

## Performance Optimization Tips

1. **Reduce OSC message frequency**: Modify Kinect loop timing
2. **Larger tap cooldown**: Increase `TAP_COOLDOWN_FRAMES` (30 default)
3. **Skip hand indicator drawing**: Set `showKinectIndicator = false`
4. **Increase spatial grid cell size**: In `WakeField.pde`, raise `PARTICLE_GRID_CELL_SIZE`

---

**Status**: Ready for deployment
**Last Updated**: February 2, 2026
**Kinect SDK Version**: v1.8
**OSC Port**: 12000
