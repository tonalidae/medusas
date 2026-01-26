# muchas_medusas_nadando

This sketch models a small swarm of jellyfish-like "gusanos" using an agent-based loop. The primary design pattern used is **personality-locked archetypes** (DOM or SHY) paired with **steering-behavior blending** to compute motion.

## Design Pattern: Personality-Locked Archetypes

Each `Gusano` is born as either `DOM` (aggressive) or `SHY`, and stays in that base state for the entire run. Mood switching is disabled, which keeps behavior consistent and avoids state churn.

This still uses the same blending pipeline:

- **State storage**: `state`, `stateTimer` (locked to base mood).
- **State-driven parameters**: `applyMood()` blends target swim parameters (pulse, drag, turn, turbulence) based on the base personality.
- **State-driven visuals**: `paletteForState()` and `updateColor()` map personality to color.

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
   - Enforce base personality state.
   - Blend mood parameters.
   - Compute steering and apply physics.
   - Update body segments.
   - Render points for the shape.

## Why This Pattern

The locked archetypes provide stable, contrasting behaviors, while steering blending lets each archetype express a different mix of forces. Together they keep the code readable and make the agents feel alive without complex pathfinding or scripted motion.
