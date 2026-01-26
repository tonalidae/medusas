# Jellyfish Spawn and Dynamics

This document explains how jellyfish ("gusanos") are spawned and how their movement dynamics are modeled in this sketch. It focuses on the creation path, per-agent initialization, and the runtime dynamics pipeline.

## Where jellyfish are spawned

### Initial spawn (sketch setup)
- `setup()` in `SketchLifecycle.pde` creates the jellyfish list and spawns `numGusanos` agents.
- Each agent starts at a random position inside a 200 px margin from the window edges.
- The constructor is called as `new Gusano(x, y, c, i)` where `c` is currently a dark color and `i` is the id.

Relevant code:
- `SketchLifecycle.pde` (functions `setup()` and `reiniciarGusanos()`)
- `Config.pde` (global counts `numGusanos`, `numSegmentos`)

### Respawn (runtime reset)
- `reiniciarGusanos()` clears the list and re-creates all agents with the same random-position logic.
- `Input.pde` binds `+` / `-` keys to change `numGusanos` and then call `reiniciarGusanos()`.

## Per-agent initialization (constructor)

When a `Gusano` is created (`Gusano.pde`):

1. **Body segments**
   - `segmentos` is filled with `numSegmentos` instances of `Segmento`, all starting at the head position.

2. **Pulse timing and shape**
   - `pulsePhase` is seeded using the id plus a random offset.
   - `contractPortion` and `holdPortion` are randomized per jellyfish, giving each a slightly different contraction cycle.

3. **Personality archetype**
   - Each jellyfish is randomly labeled `DOM` or `SHY`.
   - This sets base parameters for pulse rate, pulse strength, drag, and behavioral traits (aggression/timidity/curiosity/social).

4. **Base physical parameters**
   - Base turn rate, sink strength, turbulence, and size factor are randomized within bounded ranges.

5. **Mood / systems wiring**
   - The mood system, steering system, dynamics, pulse model, body model, and renderer are instantiated.
   - The initial state is set to the personality base mood (aggressive for `DOM`, shy for `SHY`).

## Dynamics overview (per-frame)

Each frame, `draw()` calls `gusano.actualizar()` for every jellyfish (`SketchLifecycle.pde`). The update path is a pipeline in `Gusano.pde` and helper classes.

High-level pipeline:

1. **Time step + anti-spike guard**
   - `dt = 1 / frameRate`, clamped to avoid huge impulses at low FPS.

2. **Speed spike detection**
   - A speed EMA is tracked for diagnostics; mood switching is disabled.

3. **Personality update and parameter blending**
   - `GusanoMood.updateState()` enforces the base personality (DOM/SHY).
   - `GusanoMood.applyMood()` blends pulse rate/strength, drag, turn rate, turbulence, etc.

4. **Steering + head turbulence**
   - `GusanoSteering.computeSteering()` returns the desired steering force.
   - Head noise is added (reduced when the jellyfish is nearly still).
   - The head angle is smoothly rotated toward the desired direction.

5. **Pulse propulsion and physics**
   - `GusanoPulse.updatePhase()` advances the pulse cycle.
   - Contraction drives thrust; relaxation drives glide.
   - `GusanoDynamics.applyThrust()` adds forward impulse, gated by alignment to the steer direction.
   - `applyBuoyancy()` adds a gentle sink while relaxed and lift while contracting.
   - `applyDrag()` damps velocity (phase-dependent).

6. **Wall interaction + stabilization**
   - Soft wall response rotates the head away and damps perpendicular velocity.
   - Side-slip damping reduces lateral "stepping".
   - Deadband zeroes tiny velocities to prevent jitter.
   - Head position is integrated and softly clamped.

7. **Body segments follow the head**
   - `GusanoBody.updateSegments()` propagates a wave down the segments.
   - Each segment follows the previous one with speed- and phase-dependent smoothing and turbulence.

8. **Wake deposition**
   - The head deposits into the wake grid proportional to velocity (affects flow and neighbor behavior).

## Steering forces (how direction is chosen)

`GusanoSteering.pde` composes the steering vector from multiple forces. Most forces are **phase-gated** so steering is stronger during contraction and weaker during glide.

Key components:

- **Mouse interaction**
  - Mouse press causes a push impulse; steering adds a short-range repulsion when pressed.

- **Neighbor interactions (spatial grid)**
  - Separation (short-range) and cohesion (front-cone) are computed from nearby neighbors.
  - Aggressive and shy personalities also respond to dominant neighbors (flee/yield logic).

- **Wall avoidance**
  - Quadratic wall steering pushes the agent away from edges without hard jitter.

- **Wake / flow fields**
  - `sampleWakeGradient()` and `sampleFlow()` are used as environmental steering.
  - SHY agents avoid wake gradients; DOM (aggressive) agents are attracted.

- **Wander + lateral sway**
  - Noise-driven drift adds organic motion; sway adds sideways variation.

Special case:
- If the jellyfish is in the AGGRESSIVE state, it uses **pursuit** (`computeAggroPursuit`) instead of the normal blend.

## Wake field and flow dynamics

The environment is a grid-based wake field (`WakeField.pde`):

- Jellyfish deposit wake at their head position every frame.
- The field diffuses and decays over time.
- A flow vector is computed from the wake gradient (swirl + push).
- Steering can sample both wake gradient and flow to influence movement.

This makes the environment self-influencing: movement produces wake; wake influences future movement.

## Key tuning knobs

Most motion behavior is configured in `Config.pde`. Important values include:

- Agent counts: `numGusanos`, `numSegmentos`
- Motion: `MAX_TURN_RAD`, `THRUST_SMOOTH_ALPHA`, `SIDE_SLIP_DAMP`
- Pulse: `UNDULATION_MAX`, `GLIDE_*`, `FOLLOW_*`
- Steering caps: `MAX_STEER_*`
- Wake/flow: `FLOW_STEER_SCALE`, `WAKE_STEER_SCALE`, `wakeDecay`, `wakeDiffuse`

## File map (relevant to spawn and dynamics)

- `SketchLifecycle.pde`: setup/draw + spawn/reset
- `Config.pde`: global parameters and toggles
- `Gusano.pde`: per-agent update and state
- `GusanoDynamics.pde`: thrust, buoyancy, drag, wall response, integration
- `GusanoSteering.pde`: steering composition
- `GusanoPulse.pde`: pulse timing and contraction curve
- `GusanoBody.pde`: segment follow + undulation
- `Segmento.pde`: segment follow + clamp
- `WakeField.pde`: wake grid, diffusion, flow
- `SpatialGrid.pde`: neighbor indexing
- `Input.pde`: runtime spawn count changes
