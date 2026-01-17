# Jellyfish Fluid Simulation

An interactive ecosystem of bioluminescent jellyfish with personalities, social behaviors, and fluid dynamics.

## Quick Start

1. Open `jellyfish_fluid.pde` in Processing
2. Run the sketch (requires P2D renderer)
3. Move your mouse to summon the jellyfish
4. Interact gently to see curious behavior, or harshly to scare them away

## Keyboard Controls

| Key | Action |
|-----|--------|
| `+` / `=` | Add jellyfish (max 24) |
| `-` / `_` | Remove jellyfish (min 1) |
| `SPACE` | Full reset (calm water + respawn all) |
| `R` | Randomize all personalities |
| `D` | Toggle debug overlay |
| `P` | Print current parameters to console |

## System Architecture

### Core Files

```
jellyfish_fluid.pde        # Main loop, spawn/exit state machine, mouse tracking
├── Gusano.pde              # Jellyfish entity (lifecycle, state, respawn)
├── GusanoBehaviour.pde     # Movement AI (social, user interaction, pulse swimming)
├── GusanoBody.pde          # Physics (rope constraints, fluid drag, tentacle waves)
├── GusanoRender.pde        # Rendering (6 parametric shapes, bioluminescence)
├── GusanoPersonality.pde   # 6 personality presets + trait system
├── Segmento.pde            # Body segment (position, velocity, angle)
├── Fluido.pde              # Fluid simulation orchestrator
├── FluidosSim.pde          # Spring-mass wave propagation
├── FluidoPerturb.pde       # Perturbation from mouse/jellyfish
├── FluidoRender.pde        # Fluid visualization (depth shading, ripples)
├── FluidosIsoclines.pde    # Isoline tracing (alternative rendering mode)
├── Particula.pde           # Fluid grid particle
├── Resorte.pde             # Spring connector between particles
├── SpatialGrid.pde         # O(N) spatial partitioning for neighbor queries
└── SimulationParams.pde    # Centralized parameter configuration
```

## Key Systems

### 1. Personality System

6 preset personalities with ~40 parameters each:

- **Curious Dancer** – Approaches user, highly social
- **Shy Drifter** – Avoids user, dreamy wanderer  
- **Bold Leader** – Fast, confident, leads groups
- **Nervous Follower** – Tight schooling, easily stressed
- **Calm Observer** – Slow, solitary, unbothered
- **Playful Explorer** – Quick, curious, erratic

Each personality controls:
- Movement (speed, agility, wander intensity)
- Social behavior (cohesion, personal space, following)
- Reactions (curiosity, sensitivity, bravery)
- Appearance (size, tentacle length, glow intensity)

### 2. Behavior System

#### A. User Interaction
- **Curiosity vs Fear**: Gentle movement attracts, harsh movement scares
- **Attitude tracking**: Each jellyfish tracks its relationship with the user (-1 to +1)
- **Scare accumulation**: Intense interaction builds threat, triggering mass exodus
- **Two-stage idle**: Lonely mode (wandering away) → Full exit (fade out)

#### B. Social Forces
- **Separation**: Avoid crowding (personal space)
- **Alignment**: Match neighbors' direction
- **Cohesion**: Stay near the group center
- **Bravery boost**: Groups feel safer together

#### C. Swimming Mechanics
- **Pulse-based**: Arousal modulates thrust frequency and amplitude
- **Target wandering**: Biased random walk with brownian jitter
- **Fluid coupling**: Jellyfish push water and drift with currents

### 3. Physics System

#### A. Rope-Like Body
- **Distance constraints**: Iterative solver maintains segment spacing (5 passes)
- **Bend smoothing**: Prevents sharp angles (organic spine)
- **Verlet integration**: Stable, simple velocity-less physics

#### B. Tentacle Waves
- **Layered oscillations**: 3 sine waves at different frequencies
- **Spiral motion**: Radial offset creates swirling tentacles
- **Arousal modulation**: Faster swimming = more intense waves

#### C. Fluid Drag
- **Per-segment sampling**: Cached fluid velocity/height (performance)
- **Bidirectional coupling**: Jellyfish displace water, water pushes jellyfish

### 4. Rendering System

#### A. Parametric Shapes
6 variants based on polar/parametric equations:
```processing
// Example (Variant 0 - Original)
k = 5 * cos(x / 14) * cos(y / 30);
e = y / 8 - 13;
d = (k² + e²) / 59 + 4;
q = -3 * sin(atan2(k, e) * e) + k * (3 + 4/d * sin(d² - t*2));
px = q + 0.9;
py = d * 45;
```

- Cases 0-3: Original jellyfish equations (from simple prototype)
- Case 4: "Digital organism" (processing.org example)
- Case 5: Spiral jellyfish (new)

#### B. Bioluminescence
```processing
bioGlow = 1.0 
  + arousal * 0.8           // Excited = brighter
  + max(0, userAttitude) * 0.6  // Curious = extra glow
  * personalityGlowIntensity      // Shy vs bold
```

- **ADD blend mode**: Critical for glow effect
- **Depth simulation**: 3D ocean effect via size/alpha scaling
- **Fade-in**: Prevents spawn bloom
- **Pulsing head**: Heartbeat-like visual feedback

### 5. Fluid Simulation

Spring-mass particle grid (40×35):
- **Tension**: Restoring force toward equilibrium
- **Damping**: Energy dissipation
- **Wave propagation**: 4-neighbor diffusion
- **Mouse/jellyfish perturbation**: Directional water pushing

Rendering:
- **Depth-based shading**: Higher = lighter
- **Velocity-based intensity**: Moving water = brighter streaks
- **Smooth interpolation**: Bilinear sampling between grid points

### 6. Performance Optimizations

- **Spatial grid**: O(N) neighbor queries instead of O(N²)
- **Cached fluid samples**: 1 sample per segment, not per render point
- **Dynamic point density**: Fewer points when many jellyfish (auto-scales)
- **P2D renderer**: GPU acceleration
- **Constraint iteration limit**: Fixed 5 passes (predictable frame time)

## State Machines

### Spawn/Exit Lifecycle

```
HIDDEN (empty array)
  ↓ [mouse interaction]
SPAWN_ARMED (1s delay timer)
  ↓ [timer expires]
SPAWNED (fade-in, active)
  ↓ [user idle 4.5s] OR [scare > threshold]
LONELY/SCARED (wandering away or fleeing)
  ↓ [idle 8s total] OR [scare exit]
EXIT_ARMED (fade-out begins)
  ↓ [fade complete]
HIDDEN
```

### Jellyfish Individual Lifecycle

```
BORN (all segments, full health)
  ↓ [stress accumulation]
DYING (losing segments, shrinking)
  ↓ [health = 0]
DEAD (marked for respawn)
  ↓ [respawn triggered]
REBORN (grows back gradually)
```

## Parameter Tuning

See `SimulationParams.pde` for centralized configuration:

```processing
SimulationParams params;  // Global instance

params.scareThreshold = 1.25;   // Lower = easier to scare
params.scareGain = 0.12;        // Higher = faster accumulation  
params.brownianJitterChance = 0.03;  // Probability of target nudge
params.spatialCellSize = 150;   // Affects neighbor query performance
// ... and 30+ more parameters
```

Press `P` at runtime to print all current values.

## Code Style Notes

### Variable Naming
- **Mixed language**: Spanish for domain logic (`objetivoX`, `segmentos`), English for technical/framework terms (`velocity`, `constraint`)
- **Descriptive**: `frecuenciaCambio` not `fc`, `userAttitude` not `uAtt`

### Physics Comments
- **WHY not WHAT**: Explain the rationale, not the syntax
- **Equations**: Document the source (e.g., "from original prototype", "inspired by boid steering")

## Credits & Evolution

**Original prototype** (200 lines):
- Simple parametric jellyfish shapes
- Basic random walk movement
- 4 jellyfish variants
- Clean, educational code structure

**Current system** (3000+ lines):
- Full ecosystem simulation
- Personality-driven AI
- Bidirectional fluid coupling
- Performance optimizations
- Interactive spawn/exit choreography

Key additions inspired by original:
- ✅ Keyboard population controls (+/-)
- ✅ Spacebar reset
- ✅ Brownian target micro-jitter
- ✅ Parameter centralization
- ✅ Progressive disclosure philosophy

## Performance Tips

- **Low FPS?** Press `-` to reduce population
- **Laggy mouse?** Reduce `params.mouseHistorySize` to 4
- **Too dense?** Adjust `params.pointDensityBase` down to 2.5
- **Jerky motion?** Increase `params.constraintIterations` to 7 (costs CPU)

## Future Enhancements

- [ ] JSON config file loading
- [ ] ControlP5 GUI for runtime parameter tweaking
- [ ] Food sources (attractors)
- [ ] Predator avoidance
- [ ] Reproduction (splitting when healthy)
- [ ] OSC/MIDI control for live performance
- [ ] Export personality presets
- [ ] Multi-monitor swarm (cross-window communication)

## License

Educational/artistic project. Feel free to learn from, remix, and build upon!

---

