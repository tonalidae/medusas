# Demo Mode Implementation Guide

## Overview
The jellyfish fluid simulation has been configured for **interview/demo mode** where the installation appears interactive without requiring real user input. This allows the artwork to showcase its full aesthetic potential during development and presentations.

---

## Key Changes Made

### 1. **Simulated Interaction System** 
**File:** `GusanoBehaviour.pde` (lines 147-195)

A **"ghost cursor"** moves in a figure-8 (Lissajous) pattern that:
- Continuously moves in an elegant mathematical pattern
- Periodically focuses on nearby jellyfish, creating the appearance of "following" them
- Maintains a subtle, non-intrusive presence that doesn't overwhelm the jellyfish

```processing
// Figure-8 lissajous curve: smooth, elegant motion
float simMouseX = simCenterX + cos(simTime) * simRadius;
float simMouseY = simCenterY + sin(simTime * 2.0) * simRadius * 0.5;
```

**Why this approach:**
- Creates the appearance of gentle visitor interaction without actually needing input
- The figure-8 pattern is mathematically elegant and naturalistic
- Jellyfish respond to the simulated cursor just as they would to real input

---

### 2. **Breathing Cycle: Rest-Dominant Behavior**
**File:** `Gusano.pde` (lines 105-115)

The jellyfish now operate in a **meditative breathing rhythm**:

| Phase | Duration | Activity |
|-------|----------|----------|
| **Rest** | 30-40 seconds | Complete stillness, floating |
| **Active** | 5-6 seconds | Subtle undulation (0.08-0.22 pixels) |

**Pause Settings:**
- `tentaclePauseChance = 0.95` → 95% chance to rest after cycle
- `tentaclePauseMin = 1800` frames → ~30 seconds minimum rest
- `tentaclePauseMax = 2400` frames → ~40 seconds maximum rest

**Wave Amplitude:**
- Reduced to **0.15 pixels** baseline (was 2.5)
- Per-variant: 0.08-0.22 pixels range
- Creates minimal body deformation—just fluid drift

---

### 3. **Debug Visualization**
**File:** `GusanoBehaviour.pde` (lines 762-780)

A **small colored indicator** appears above each jellyfish's head:
- 🔵 **Blue** = Resting phase (meditative stillness)
- 🟠 **Orange** = Active phase (gentle movement)

```processing
// Visual indicator at jellyfish head showing breathing state
fill(isResting ? color(100, 200, 255) : color(255, 150, 100));
ellipse(cabeza.x, cabeza.y - 25, 8, 8);
```

**Enable Console Logging:**
Uncomment line 778 in GusanoBehaviour.pde to see state changes logged:
```processing
println("Jellyfish " + g.id + ": " + state);
```

---

### 4. **Simplified User Interaction**
**File:** `GusanoBehaviour.pde` (lines 158-177)

User attitude and interaction now:
- Based primarily on **personality** (randomized per jellyfish)
- Slow, stable attitude changes (no reactive peaks)
- Minimal direct force application (0.04x vs 0.12x)
- Gentler flee responses (requires -0.3 attitude, 0.5x kick force)

```processing
// Very slow attitude changes (personality is stable)
g.userAttitude += (g.userAttTarget - g.userAttitude) * 0.015;
```

---

### 5. **Real Mouse Input Disabled**
**File:** `jellyfish_fluid.pde` (lines 593-704)

All real mouse interaction code has been **commented out**:
- `mouseDragged()` → Empty placeholder
- `mousePressed()` → Empty placeholder  
- `mouseMoved()` → Empty placeholder

To re-enable real user interaction for the full installation, uncomment the code block and remove the placeholder functions.

---

## How to Switch Modes

### **Enable Demo Mode (Current):**
Already active. The jellyfish respond to the simulated cursor.

### **Enable Real User Input:**

1. **Uncomment the mouse handlers** in `jellyfish_fluid.pde` (lines 593-704)
2. **Comment out the placeholder functions** (lines 700-703)
3. **In GusanoBehaviour.pde**, replace `simMouseX/simMouseY` with `mouseX/mouseY` (lines ~320-325)
4. **Re-enable attitude-based interaction** by uncommenting lines 164-177 and adjusting the gain values

---

## Visual Appearance in Demo Mode

### What's Visible:
✅ Jellyfish float naturally with minimal motion  
✅ 95% of time: complete rest (meditative stillness)  
✅ 5% of time: subtle breathing (barely noticeable undulation)  
✅ Color indicators show breathing state  
✅ Gentle figure-8 "ghost cursor" occasionally draws attention  
✅ Social interactions (schooling, avoidance) remain active  

### What's Disabled:
❌ No response to real mouse movement  
❌ No water ripples from user dragging  
❌ No scare states from aggressive input  
❌ No flee responses to fast mouse movements  

---

## Parameters to Adjust for Interview Demo

### **Adjust Breathing Cycle Intensity:**
In `Gusano.pde` (~line 107):
```processing
float tentacleWaveAmp = 0.15;  // 0.08-0.22 range per variant
```
- Increase for more visible motion during interview
- Decrease for maximum meditation effect

### **Adjust Rest Duration:**
In `Gusano.pde` (~lines 113-114):
```processing
int tentaclePauseMin = 1800;    // 30 seconds
int tentaclePauseMax = 2400;    // 40 seconds
```
- Reduce for more frequent activity bursts (e.g., 900-1200 for 15-20s rest)
- Increase for more meditative presence (e.g., 2700-3600 for 45-60s rest)

### **Adjust Simulated Cursor Behavior:**
In `GusanoBehaviour.pde` (~lines 157-165):
```processing
float simRadius = 120;      // Size of figure-8 pattern
float simCenterX = width / 2;
float simCenterY = height * 0.45;  // Vertical bias
```
- Larger radius = more active appearance
- Adjust center position to draw attention to specific areas

---

## Technical Notes

### Breathing Cycle Logic:
The `tentaclePaused` flag controls the active/rest state. When `tentaclePaused = true`:
- Wave generation stops → body becomes perfectly still
- Segment drag continues normally → gentle fluid drift
- Duration randomized between `tentaclePauseMin` and `tentaclePauseMax`

### Why 95% Rest?
This creates a **Keynesian beauty contest** effect:
- Most time: meditative, contemplative stillness
- Rare moments of activity stand out and catch attention
- Visitors focus on the peaceful state, not constant motion
- Perfect for installation interviews (beautiful, not distracting)

### Simulated Cursor Focus Logic:
Every ~5 seconds, the ghost cursor:
1. Finds the nearest jellyfish
2. Gently drifts toward it (~5% per frame)
3. Resumes figure-8 pattern

This creates a sense of "following" without being intrusive.

---

## Future: Returning to Full Interaction

When the installation is ready for public interaction, simply:
1. Uncomment the original `mouseDragged/mousePressed/mouseMoved` functions
2. Use real `mouseX/mouseY` instead of simulated positions
3. Adjust interaction intensity gains (currently reduced 67% for demo)
4. Re-enable aggressive scare states if desired

The system is fully backward-compatible. No other code changes needed.

---

## Debug Checklist

- [ ] Blue/orange indicator circles visible above jellyfish heads
- [ ] Indicator changes every 30-40 seconds (rest cycle)
- [ ] Console logging works when uncommented (line 778)
- [ ] Ghost cursor appears to move in smooth pattern
- [ ] No mouse ripples appear when dragging
- [ ] Jellyfish remain calm and meditative

---

## Video Demo Mode - 3 Minute Looping Interview System

**Complete autonomous setup for continuous background video loops during interviews.** Jellyfish spawn every 3 minutes with dramatic water effects, cycle through 3 interaction behaviors (gentle → scare → approach), and automatically fade and restart.

### How It Works

```
TIMELINE (per 3-minute cycle):
0:00 - 0:02s    Water ripples build (pre-spawn interaction)
0:02 - 1:02s    Behavior Phase 0: GENTLE (soft figure-8 floating, 3.0 water strength)
1:02 - 2:02s    Behavior Phase 1: SCARE (aggressive erratic movements, 7.0 water strength, fast waves)
2:02 - 3:00s    Behavior Phase 2: APPROACH (slow drift toward jellies, 4.5 water strength)
3:00 - 3:02s    Smooth fade-out (2 seconds)
3:02s           Restart immediately
```

### Configuration

**File:** `jellyfish_fluid.pde` (lines 40-45)

```processing
final boolean DEMO_MODE = true;              // Master toggle
final int DEMO_SPAWN_DELAY_MS = 2000;        // 2 seconds before spawn
final int DEMO_COHORT_LIFETIME_MS = 180000;  // 3 minutes (180 seconds)
final int DEMO_COHORT_FADE_MS = 2000;        // 2-second fade-out before respawn
```

### Three Behavior Phases (60 seconds each)

#### **Phase 0: GENTLE (0-60 seconds)**
- **Cursor Pattern:** Smooth figure-8 (Lissajous) motion
- **Movement:** Slow, circular, predictable
- **Water Strength:** 3.0 (moderate ripples)
- **Wave Frequency:** Every 30 frames (~2 waves/second)
- **Jellyfish Response:** Curious, gently following, positive attitude bias
- **Visual:** Blue indicator circles show calm, meditative state

#### **Phase 1: SCARE (60-120 seconds)**
- **Cursor Pattern:** Aggressive, erratic circular motion with jitter
- **Movement:** Fast, wide arcs, unpredictable
- **Water Strength:** 7.0 (intense ripples)
- **Wave Frequency:** Every 20 frames (~3 waves/second, most aggressive)
- **Jellyfish Response:** Fearful, fleeing, negative attitude bias
- **Visualization:** Stabbing motions toward individual jellies; orange indicators show stress

#### **Phase 2: APPROACH (120-180 seconds)**
- **Cursor Pattern:** Slow circular drift with gentle targeting
- **Movement:** Smooth, toward nearest jellyfish, deliberate approach
- **Water Strength:** 4.5 (medium-strong ripples)
- **Wave Frequency:** Every 25 frames (~2.4 waves/second)
- **Jellyfish Response:** Cautiously curious, slow approach to cursor
- **Visual:** Gentle targeting behavior; blue indicators return as stress decreases

### Screen-Wide Water Ripple System

**Pre-Spawn (0-1.5 seconds):**
- Building intensity ripples: 2.0 → 5.0 over 1.5 seconds
- Figure-8 cursor position creates main perturbation
- 3 random screen-scattered secondary ripples every 3 frames
- Concentric wave from screen center every 30 frames
- Creates visual narrative: "water is being touched"

**Active Phase (2-180 seconds):**
- 5-6 random screen-scattered perturbation points every 4 frames
- Strength varies by behavior (gentle=3.0, scare=7.0, approach=4.5)
- Concentric waves from screen center at variable frequency
- Scare phase: waves every 20 frames (3/second, intense)
- Gentle/approach: waves every 25-30 frames (calmer)

### Tiny Directional Arrow Indicators

**Purpose:** Show jellyfish movement direction towards/away from cursor during active interaction

**Appearance:**
- **Location:** Small arrows appear above jellyfish heads
- **Size:** 8px total arrow length (very small, non-distracting)
- **Color:** 
  - 🟢 Green = Approaching cursor (curious, positive attitude)
  - 🔴 Red = Fleeing cursor (fearful, negative attitude)
- **Opacity:** 150/255 (~60%) for subtle appearance
- **Visibility:** Only shown when `|userAttitude| > 0.2` (active interaction)

**What It Shows:**
- Direction of movement relative to cursor position
- Reversed when fleeing (away from cursor)
- Small triangle + line shaft for clear directionality

### Quick Start for Interview Loop

1. Hit Play in Processing
2. System automatically:
   - Waits 2 seconds with building water effects
   - Spawns jellyfish group at 2-second mark
   - Cycles through 3 behavior phases (1 minute each)
   - Smooth fade-out at 3-minute mark
   - **Automatically restarts from step 1** (infinite loop)
3. Record screen as needed; each cycle is identical and repeatable

**Perfect for:** Background videos for interviews, installation demos, presentations—runs completely unattended.

### Customization Options

**Adjust cycle length:**
```processing
final int DEMO_COHORT_LIFETIME_MS = 120000;  // 2 minutes instead of 3
```

**Adjust phase duration:**
In `jellyfish_fluid.pde`, function `getCurrentBehaviorPhase()`:
```processing
int phaseMs = 45000;  // 45 seconds per phase instead of 60
```

**Adjust water strength:**
In `jellyfish_fluid.pde`, function `getWaterStrengthForBehavior()`:
```processing
case 0: return 4.0;    // Increase gentle ripple strength
case 1: return 9.0;    // Increase scare intensity
case 2: return 5.5;    // Adjust approach phase
```

**Adjust arrow visibility:**
In `GusanoBehaviour.pde`, line ~818:
```processing
if (Math.abs(g.userAttitude) > 0.1) {  // Show arrows at lower interaction threshold
```

**Disable certain phases:**
In `GusanoBehaviour.pde`, `behaveUser()` function, replace phase selection:
```processing
// Force always gentle: behaviorPhase = 0;
// Skip scare: if (behaviorPhase == 1) behaviorPhase = 0;
```

### What Interviewees See

**Perfect interview narrative:**
1. **First 30 seconds:** "The water seems to be responding to something invisible..."
2. **At 2 seconds:** "Look—creatures appear from the water!"
3. **0-60 seconds:** Jellyfish float gracefully, gently curious
4. **60-120 seconds:** Sudden change—jellies become startled, retreat rapidly
5. **120-180 seconds:** Cautious approach—jellies slowly come back toward invisible visitor
6. **At 3 minutes:** Graceful fade-out and restart

Creates a narrative of **gentle interaction → sudden disruption → reconciliation** that repeats hypnotically.

### Parameters Summary

| Parameter | Value | Effect |
|-----------|-------|--------|
| `DEMO_MODE` | `true` | Master toggle for auto-spawn system |
| `DEMO_SPAWN_DELAY_MS` | `2000` | Delay before first spawn (2 seconds) |
| `DEMO_COHORT_LIFETIME_MS` | `180000` | Total group lifetime (3 minutes) |
| `DEMO_COHORT_FADE_MS` | `2000` | Fade-out duration before respawn |
| Phase duration | `60000` ms each | 1 minute per behavior |
| Gentle water strength | `3.0` | Moderate ripple intensity |
| Scare water strength | `7.0` | Maximum ripple intensity |
| Approach water strength | `4.5` | Medium-strong ripple intensity |
| Gentle wave frequency | `30` frames | ~2 waves/second |
| Scare wave frequency | `20` frames | ~3 waves/second |
| Approach wave frequency | `25` frames | ~2.4 waves/second |
| Arrow visibility threshold | `0.2` | Show when `|attitude| > 0.2` |

### Troubleshooting

**No water ripples before spawn?**
- Check `DEMO_SPAWN_DELAY_MS > 0`
- Check `DEMO_INTERACTION_DURATION > 0` (set to 1500)
- Verify `DEMO_MODE = true`

**Jellyfish don't change behavior?**
- Open `jellyfish_fluid.pde` and call `initBehaviorPhases()` exists
- Check behavior phase advances: each should last ~60 seconds

**Arrows not showing?**
- Increase arrow visibility threshold in `GusanoBehaviour.pde` line 818
- Check if `|userAttitude|` exceeds 0.2 during interaction

**Can't see water ripples during active phase?**
- Increase water strength values (3.0 → 5.0, 7.0 → 10.0, etc.)
- Check if `fluido.perturbar()` is being called (should see in `draw()` water updates)

**Despawn timing off?**
- Verify `DEMO_COHORT_LIFETIME_MS = 180000` (exactly 180,000ms for 3 minutes)
- Check fade-out duration: `DEMO_COHORT_FADE_MS = 2000`

### Video Recording Tips

**Best practice:**
1. Start recording at any point in the cycle
2. Let run for 3-5 complete cycles (9-15 minutes total)
3. Edit in post to show 2-3 cycles for your video
4. No audio needed (hypnotic silence works) or add ambient ocean sounds

**Beautiful segments to capture:**
- Full gentle phase (60s of meditative floating)
- Scare transition moment (aggressive water effects + jelly retreat)
- Approach phase reunion (slow approach + water calming)

**Quality:**
- 1920×1080 or higher
- 60 FPS if possible (smooth water simulation)
- Dark background theme for maximum contrast

---

**Installation Status:** Ready for Continuous Interview Loop ✓
