# Code Analysis: muchas_medusas_nadando

This document describes how the current Processing sketch works, its main systems, and how the files collaborate each frame.

## Big Picture

The sketch simulates a small swarm of jellyfish-like agents ("gusanos") using:

- A finite state machine (FSM) per agent to model mood (CALM, CURIOUS, SHY, FEAR, AGGRESSIVE).
- A blended steering system (wander, wall avoidance, wake sensing, flow, separation, cohesion, pursuit).
- A wake field grid that diffuses disturbances and provides a flow field.
- A segmented body that follows the head to create a soft, elastic motion.
- A parametric point-cloud renderer that maps the animated body to a stylized jellyfish shape.

Every frame:
1. The wake field is diffused/decayed and optionally drawn.
2. A spatial grid is rebuilt for fast neighbor queries.
3. Each gusano updates mood, steering, physics, body segments, and rendering.

## File Map and Responsibilities

- `muchas_medusas_nadando.pde`: Main sketch, global settings, setup/draw, debug toggles, spatial grid, and debug overlays.
- `Gusano.pde`: The main agent class (state, physics, pulse propulsion, body update, wake deposit).
- `GusanoMood.pde`: FSM logic (state transitions, mood parameter blending, mood colors, logging).
- `GusanoSteering.pde`: Steering behaviors and how they are weighted by mood.
- `GusanoRender.pde`: Visual geometry for the jellyfish body (point-based parametric shape).
- `Segmento.pde`: A body segment with follow-the-leader behavior and screen constraints.
- `WakeField.pde`: Disturbance grid, diffusion/decay, wake gradient, and derived flow vector.
- `MathUtils.pde`: Small math helpers (angle interpolation, wrapping).

## Main Loop (muchas_medusas_nadando.pde)

### Global state and toggles
The sketch defines:
- Agent counts (`numGusanos`, `numSegmentos`).
- Debug flags to draw overlays or log stats.
- Feature toggles to enable/disable steering components (wander, wall avoidance, wake, flow, separation, cohesion, pursuit).
- Mouse input tracking for wake deposition.
- Spatial grid parameters for neighbor lookups.

### `setup()`
- Initializes the window, background, and wake grid.
- Creates `numGusanos` agents, each starting at a random position.

### `draw()`
- Clears the background and updates time `t`.
- Computes mouse speed and deposits wake when the mouse is pressed or moving quickly.
- Updates the wake grid (diffusion/decay) and rebuilds the spatial grid.
- Updates each gusano (`actualizar()`), then renders it.
- Draws optional debug overlays and logs.

### Algorithm sketch (frame-level)
Pseudocode of the top-level loop:

```text
draw():
  background(white)
  t = millis * timeScale
  mouseSpeed = distance(mouse, lastMouse)
  updateWakeGrid()
  rebuildSpatialGrid()
  if mousePressed or mouseSpeed > threshold:
    depositWakeBlob(mouseX, mouseY, radius, amount)
  for each gusano:
    gusano.actualizar()
    gusano.dibujarForma()
  draw optional debug overlays/logs
```

### Spatial grid
`rebuildSpatialGrid()` hashes each gusano’s head into a grid cell (`gridCellSize`), which allows `queryNeighbors()` to return only nearby agents for separation/cohesion/pursuit. This is a fast alternative to all-pairs scanning.

## Agent Update (Gusano.pde)

The main update method is `actualizar()`. It can be read as a pipeline:

1. **Time step and anti-spike guard**
   - `dt` is derived from `frameRate` and clamped to avoid huge impulses when the frame rate is low.

2. **Speed spike detection**
   - The agent tracks an EMA of its speed.
   - If the instantaneous speed deviates enough from the EMA, a spike counter increments.
   - Sustained spikes can trigger the FEAR state in the mood system.

3. **Mood update**
   - `mood.updateState()` may transition mood or startle into FEAR.
   - `mood.applyMood()` blends pulse/drag/turn/turbulence parameters toward mood targets.
   - `mood.updateColor()` smoothly updates the jellyfish color.

4. **Mouse interaction (direct hit)**
   - If the mouse is pressed and the head is within 50 px, the agent is pushed away.
   - This can force FEAR with a cooldown.

5. **Head steering and turbulence**
   - The steering system returns a desired direction.
   - Head noise adds small procedural turbulence, gated by motion to avoid jitter at rest.
   - The head angle is smoothed toward the desired steering direction via `lerpAngle`.

6. **Pulse propulsion**
   - A rhythmic pulse phase drives contraction and impulse thrust.
   - The contraction curve biases thrust to occur during the contraction phase.

7. **Buoyancy + drag**
   - While not contracting, the agent slowly sinks (reduced near the bottom).
   - Buoyancy counteracts sinking during contraction.
   - Drag is applied, with a deadband to remove tiny jitter velocities.

8. **Wall response**
   - Mild velocity nudges push away from margins.
   - Head position is clamped to screen, with additional velocity damping if clamped.

9. **Body segments follow**
   - Each segment follows the previous one with noise-based turbulence.
   - Follow speed and turbulence scale depend on speed and contraction.

10. **Wake deposit**
   - The agent deposits wake strength proportional to its current speed.

### Algorithm sketch (agent-level)
Pseudocode of the per-agent update with the main numeric steps:

```text
actualizar():
  dt = clamp(1 / frameRate, 1/120, 1/20)
  dtNorm = dt * 60

  vmag = |vel|
  speedEMA = lerp(speedEMA, vmag, speedEMAFactor)
  speedDelta = |vmag - speedEMA|
  speedSpike = speedDelta > spikeThreshold
  spikeFrames = speedSpike ? spikeFrames+1 : max(0, spikeFrames-1)
  sustainedSpike = spikeFrames >= spikeFramesRequired

  mood.updateState(dt, sustainedSpike)
  mood.applyMood(dt)
  mood.updateColor()

  if mousePressed and distance(head, mouse) < 50:
    vel += normalize(head - mouse) * 3.5
    if not FEAR and cooldown <= 0: enter FEAR

  headTurb = noise(...) * headNoiseScale * baseTurbulence * jitterGate
  steer = normalize(steering.computeSteering(head) + headTurb)
  headAngle = lerpAngle(headAngle, atan2(steer.y, steer.x), turnRate)

  pulsePhase = (pulsePhase + pulseRate * dt) mod 1
  contraction = pulseShape(pulsePhase)
  impulse = pulseStrength * pulseContractCurve(pulsePhase) * dtNorm * thrustScale
  vel += dir(headAngle) * impulse

  vel.y += sinkStrength * (1 - contraction) * dtNorm
  vel.y -= buoyancyLift * contraction * dtNorm
  vel *= drag
  if |vel|^2 < deadband: vel = 0

  apply wall nudges, clamp head position, damp velocity on clamp
  vel = limit(vel, maxSpeed)

  for each segment i > 0:
    seg.follow(prevSeg + turbulence, followSpeed)
    seg.clamp()

  depositWakePoint(head, wakeDeposit * (0.5 + vmag * 0.2))
```

### Key formulas and curves

- **Speed EMA**: `speedEMA = lerp(speedEMA, vmag, speedEMAFactor)`
- **Spike detect**: `speedDelta = |vmag - speedEMA|`
- **Turn smoothing**: `headAngle = lerpAngle(headAngle, desiredAngle, turnRate)`
- **Pulse phase**: `pulsePhase = (pulsePhase + pulseRate * dt) mod 1`
- **Pulse contraction shape** (piecewise): fast ease-out into contraction, hold, slow release.
- **Impulse**: `pulseStrength * pulseContractCurve(phase) * dtNorm * thrustScale`

These are the core elements that create smooth, organic motion while keeping the control logic predictable.

## Mood / FSM (GusanoMood.pde)

### State transitions
- States: CALM, CURIOUS, SHY, FEAR, AGGRESSIVE.
- `pickState()` uses weighted random choice with personality biases.
- Wall proximity dampens AGGRESSIVE and boosts CALM when close to edges.
- FEAR is triggered by sustained speed spikes or rare random startle events.
- FEAR automatically exits to CALM after a short duration, with cooldowns.

#### Algorithm sketch (state update)

```text
updateState(dt, speedSpike):
  stateTimer += dt
  stateCooldown -= dt (if > 0)
  postFearTimer -= dt (if > 0)
  fearCooldownFrames-- (if > 0)

  if speedSpike or rareRandomFear:
    if not FEAR and cooldowns allow:
      enter FEAR for random(1.4..2.4)s
      set cooldown timers
      return

  if state == FEAR and stateTimer >= stateDuration:
    enter CALM for random(2..4)s
    set cooldowns, start postFearTimer
    return

  if stateTimer >= stateDuration and stateCooldown <= 0:
    next = pickState()
    enter next for random duration
```

#### Random fear condition

Random fear is rare and gated by multiple checks:
- Not near a wall (`wallProx < 0.5`)
- Not moving fast (`debugVmagNow < 0.6 * maxSpeed`)
- Past the first 3 seconds (`millis() > 3000`)
- Not in post-fear freeze (`postFearTimer <= 0`)
- Then `random(1) < 0.00005`

### Mood blending
`applyMood()` computes target values for:
- Pulse rate/strength
- Drag
- Sink strength
- Turn rate
- Follow speed and turbulence
- Head turbulence scale

Each mood modifies these in a characteristic way (e.g., FEAR increases pulse rate and turn rate, SHY increases sink strength and reduces turbulence). The targets are blended toward current values using smooth interpolation so that mood changes feel gradual.

#### Blending algorithm

- Compute per-mood target values (multipliers on base parameters).
- Scale by a **mood strength** factor derived from personality (curiosity/timidity/aggression).
- Apply a **post-fear freeze** (temporary dampening of turn/noise/turbulence).
- Lerp from base values toward targets using `moodBlend`.
- Smooth toward targets with an exponential smoothing factor:
  `smooth = clamp(1 - pow(0.98, dt * 60), 0.01, 0.2)`.

### Colors
`paletteForState()` maps mood to a specific RGBA color. `updateColor()` lerps between colors for smooth transitions.

### Debugging
When enabled, mood transitions print detailed logs, including speed spike metrics and wall proximity when entering AGGRESSIVE.

## Steering (GusanoSteering.pde)

### Forces blended into the desired direction
- **Wander**: Perlin-noise drift, scaled by mood.
- **Wall avoidance**: Quadratic force pushing away from boundaries.
- **Wake gradient**: The agent samples wake gradients and is attracted or repelled depending on mood.
- **Flow**: A derived flow field from the wake grid (swirl + push).
- **Separation**: Repulsive force from nearby agents within a short radius.
- **Cohesion**: Gentle attraction to mid-range neighbors.
- **Pursuit**: Only in AGGRESSIVE mood; targets the nearest neighbor.

Each vector is optionally drawn in debug mode for visual tuning.

### Mood-dependent weights
Each mood changes how these behaviors compete:
- CURIOUS increases wake attraction.
- SHY and FEAR invert wake response (avoidance), increase separation, reduce cohesion.
- AGGRESSIVE enables pursuit.

This gives each state a distinct motion signature without rewriting the physics.

### Algorithm sketch (steering blend)

```text
computeSteering(head):
  desired = 0
  set weights based on mood
  if useWander: desired += normalize(noise) * wanderW
  if useWallAvoid: desired += wallForce(head) * avoidW
  if useWake: desired += normalize(wakeGradient) * stimSign * stimW
  if useFlow: desired += flowVector(head) * 0.9
  if useSeparation/cohesion:
    for neighbor in queryNeighbors(head):
      if d < sepRadius: sep += normalizedAway * falloff
      else if d < cohRadius: coh += normalizedToward * falloff
    desired += sep * sepW (if enabled)
    desired += coh * cohW (if enabled)
  if usePursuit and AGGRESSIVE: desired += pursuitVector * pursuitW
  return desired
```

### Separation / cohesion falloff
- Separation falloff: `1 - d / sepRadius`
- Cohesion falloff: `1 - (d - sepRadius) / (cohRadius - sepRadius)`
These make forces stronger when neighbors are closer.

## Wake and Flow Field (WakeField.pde)

The wake system is a 2D grid of scalar values (density-like):

- **Deposit**: Agents and mouse input add to nearby grid cells.
- **Diffuse + decay**: Each frame blends neighbors and decays the result.
- **Gradient sampling**: `sampleWakeGradient()` computes a local gradient.
- **Flow vector**: `sampleFlow()` converts the gradient into a swirl + push vector.

This produces a soft, shared environmental field that agents can sense.

### Algorithm sketch (grid update)

For each grid cell `(x, y)`:
```text
avg = (left + right + up + down) * 0.25
v = center * (1 - wakeDiffuse) + avg * wakeDiffuse
wakeNext[x][y] = v * wakeDecay
```

### Flow computation
- Gradient: `grad = (d/dx, d/dy)` using neighbor differences.
- Flow vector: `flow = swirlStrength * perp(grad) + pushStrength * grad`
- Clamped to `maxFlow`.

## Rendering (GusanoRender.pde)

The rendering is a point-cloud parametric form:

- 5000 points are generated per gusano.
- Four base parameterizations provide visual variety (based on `id % 4`).
- Each point is mapped onto the current body chain:
  - The vertical progression of the parametric shape selects two adjacent body segments.
  - The point position is interpolated between those segments to follow the body.
- Pulse contraction offsets shift the shape, giving a breathing/throbbing effect.

The head is additionally drawn as a bright point for debugging and emphasis.

### Algorithm sketch (point mapping)

```text
for i in 0..5000:
  compute (k, e, d, q, py) from chosen param set
  verticalProgress = map(py, minPY..maxPY -> 0..1)
  segmentIndex = floor(verticalProgress * (segmentCount-1))
  interpolate body position between segmentIndex and segmentIndex+1
  apply local pulse offsets to px/py
  vertex(px + bodyX, py + bodyY)
```

## Body Segments (Segmento.pde)

Each segment:
- Follows a target position with a speed that ramps down at close distance.
- Clamps to screen bounds.
- Stores its angle for direction continuity.

This creates a soft, trailing body with gentle lag.

## Debug Controls and Observability

Key toggles (see `drawDebugHelp()`):
- `S` steering vectors
- `O` objectives and mood labels
- `P` FEAR state logging
- `U` mood statistics
- `B` neighbor stats
- `M` flow mean logging
- `N` neighbor debugging for steering
- `H` help overlay
- `1-6` enable/disable steering components

These make it easy to tune behavioral weights and see which forces dominate.

## Notes on Behavior Feel

- The combination of pulse propulsion and drag creates a natural, cyclic swim.
- Mood blending avoids abrupt changes in speed, turning, and turbulence.
- Anti-jitter gates reduce noisy motion when nearly stopped.
- Wall proximity softens aggressiveness to prevent edge thrashing.

## Extension Points

If you want to extend the system, the cleanest hooks are:
- Add new mood states in `GusanoMood` (plus weights in `GusanoSteering`).
- Add a new steering vector (e.g., attraction to targets or light).
- Alter wake field resolution or diffusion parameters for a different feel.
- Swap or add rendering patterns in `GusanoRender`.
