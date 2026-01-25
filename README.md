# muchas_medusas_nadando

This sketch models a small swarm of jellyfish-like "gusanos" using an agent-based loop. The primary design pattern used is a **finite state machine (FSM)** for mood/behavior, paired with **steering-behavior blending** to compute motion.

## Design Pattern: Finite State Machine (FSM)

Each `Gusano` is a stateful agent with five discrete moods:
`CALM`, `CURIOUS`, `SHY`, `FEAR`, `AGGRESSIVE`.

The FSM is implemented in `Gusano.pde`:

- **State storage**: `state`, `stateTimer`, `stateDuration`, `stateCooldown`.
- **Transitions**: `updateState()` decides when to switch moods (timers, startle spikes, random fear, cooldowns).
- **Entry actions**: `setState()` logs transitions and resets timers and blend targets.
- **State-driven parameters**: `applyMood()` blends target swim parameters (pulse, drag, turn, turbulence) based on the current mood.
- **State-driven visuals**: `paletteForState()` and `updateColor()` map mood to color.

This keeps high-level behavior changes isolated from low-level physics and rendering, making it easy to add new moods or tune existing ones.

## Design Pattern: Steering Behavior Blending

Movement is computed by combining multiple "steering vectors" (wander, wall avoidance, wake sensing, flow following, separation, cohesion, pursuit). Each behavior is weighted and summed in `computeSteering()` (`Gusano.pde`), then smoothed with the head angle.

This acts like a **strategy bundle**: each steering rule is an independent strategy whose influence is blended based on the current mood and debug toggles. It gives the agents organic motion without hard-coded paths.

## Supporting Systems

- **Spatial hash grid** (`muchas_medusas_nadando.pde`): speeds up neighbor queries used by separation/cohesion and pursuit.
- **Wake field** (`WakeField.pde`): a simple diffusion/decay grid that the agents sense to react to disturbances.
- **Segment chain** (`Segmento.pde`): a follow-the-leader body, updated after the head moves to create flowing, elastic motion.

## Flow of Each Frame

1. Update global wake grid and spatial grid.
2. For each `Gusano`:
   - Update state (FSM).
   - Blend mood parameters.
   - Compute steering and apply physics.
   - Update body segments.
   - Render points for the shape.

## Why This Pattern

The FSM provides clear, discrete "emotional" modes, while steering blending lets each mode express a different mix of forces. Together they keep the code readable and make the agents feel alive without complex pathfinding or scripted motion.
