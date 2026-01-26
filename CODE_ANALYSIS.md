# Code Analysis: muchas_medusas_nadando

This document describes how the Processing sketch works right now, with an emphasis on how jellyfish are spawned and how their dynamics are modeled.

## Big Picture

The sketch simulates a small swarm of jellyfish-like agents ("gusanos") using:

- Pulse-driven propulsion (contract/hold/release) with glide phases and recovery thrust.
- A soft-body chain of segments that trails the head with turbulence and undulation.
- Personality-locked archetypes (DOM/SHY) that set baseline behavior and colors.
- A blended steering system (mouse interaction, neighbors, walls, wake, flow, wander, sway).
- A wake field grid that diffuses and generates a flow field, plus visual water interaction.
- A parametric point-cloud renderer that maps a jellyfish form onto the moving body.

Every frame:
1. The wake field is updated and optionally rendered.
2. The spatial grid is rebuilt for neighbor queries.
3. Each gusano enforces its base personality, updates steering/dynamics/body, then renders.

## File Map and Responsibilities

- `muchas_medusas_nadando.pde`: Entry file with notes about where main code lives.
- `SketchLifecycle.pde`: `setup()`/`draw()` and spawn/reset logic.
- `Config.pde`: Global parameters, toggles, and tuning values.
- `Input.pde`: Key bindings for toggles and respawning.
- `SpatialGrid.pde`: Spatial hash grid for nearby neighbor queries.
- `WakeField.pde`: Wake grid, diffusion/decay, flow vectors, and water-interaction rendering.
- `Gusano.pde`: Main agent class (state, update pipeline, wake deposit).
- `GusanoSteering.pde`: Steering composition and aggressive pursuit behavior.
- `GusanoDynamics.pde`: Thrust, buoyancy, drag, wall response, integration.
- `GusanoPulse.pde`: Pulse phase timing and contraction curves.
- `GusanoBody.pde`: Segment follow and undulation logic.
- `Segmento.pde`: Per-segment follow and screen clamping.
- `GusanoMood.pde`: Mood logic, parameter blending, and color mapping.
- `GusanoRender.pde`: Jellyfish rendering as a point-cloud parametric shape.
- `DebugOverlay.pde`: On-screen debug overlays and helper rendering.
- `MathUtils.pde`: Small math helpers (e.g., angle interpolation).

## Jellyfish Spawn and Reset

### Initial spawn (setup)
- `setup()` in `SketchLifecycle.pde` initializes the wake grid and creates `numGusanos` jellyfish.
- Each jellyfish starts at a random position inside a 200 px margin from the window edges.
- Spawn call: `new Gusano(x, y, c, i)` with id `i` and a dark base color.

### Respawn (runtime reset)
- `reiniciarGusanos()` clears the list and re-creates all agents with the same random-position logic.
- `Input.pde` binds `+` and `-` to adjust `numGusanos` and then call `reiniciarGusanos()`.

## Main Loop (`SketchLifecycle.pde`)

### `draw()` pipeline
- Clear with `drawDeepOceanBackground()` (dark ocean tone).
- Update `t = millis() * timeScale`.
- Track mouse speed; deposit wake if the mouse is pressed or moving fast.
- Update the wake grid and rebuild the spatial grid.
- Render optional water-interaction layers and debug overlays.
- For each gusano: `actualizar()` then `dibujarForma()`.

### Frame-level sketch

```text
draw():
  drawDeepOceanBackground()
  t = millis * timeScale
  mouseSpeed = distance(mouse, lastMouse)

  if useWake/useFlow/debugWake: updateWakeGrid()
  rebuildSpatialGrid()

  if (useWake/useFlow/debugWake) and (mousePressed or mouseSpeed > 12):
    depositWakeBlob(mouseX, mouseY, 70, userDeposit)

  if showWaterInteraction: drawWaterInteraction()
  if debugWake: drawWakeGrid()
  if debugWakeVectors: drawWakeFlowVectors()

  for each gusano:
    gusano.actualizar()
    gusano.dibujarForma()

  draw optional debug overlays
```

## Agent Initialization (`Gusano` constructor)

When a `Gusano` is created:

1. **Segments**: `numSegmentos` `Segmento` instances, all placed at the starting head position.
2. **Pulse seed**: `pulsePhase` uses the id plus a random offset; each jelly gets unique timing.
3. **Pulse shape**: `contractPortion` and `holdPortion` are randomized per jellyfish.
4. **Personality**: random label `DOM` or `SHY`, which sets aggression/timidity/social/curiosity and base pulse/drag.
5. **Base physicals**: turn rate, sink strength, turbulence, and size factor are randomized.
6. **Mood + systems**: mood, steering, pulse, dynamics, body, and render systems are created.
7. **Initial state**: set to the base mood for the personality (AGGRESSIVE for DOM, SHY for SHY).

## Agent Update Pipeline (`Gusano.actualizar()`)

1. **Time step clamp**
   - `dt = 1 / frameRate`, clamped to avoid huge impulses at low FPS.

2. **Speed spike detection**
   - An EMA tracks speed for diagnostics; mood switching is disabled.

3. **Personality blend**
   - `mood.updateState()` locks to base personality.
   - `mood.applyMood()` blends pulse rate/strength, drag, turn rate, turbulence for SHY/AGGRESSIVE.
   - `mood.updateColor()` lerps the jellyfish color.

4. **Direct mouse hit**
   - If mouse is pressed and within 50 px, apply a push impulse and possibly trigger AGGRESSIVE.

5. **Steering + head turbulence**
   - `GusanoSteering.computeSteering()` returns a desired vector.
   - Head turbulence is noise-driven and gated down when nearly still.
   - `headAngle` smoothly interpolates toward the desired direction with `lerpAngle`.

6. **Pulse phase update**
   - `GusanoPulse.updatePhase()` advances the cycle with slow jitter.

7. **Thrust + buoyancy + drag**
   - Thrust is applied only during contraction and is gated by alignment to the steer direction.
   - A small recovery thrust runs during relaxation.
   - Buoyancy lifts during contraction and sinks slightly during relaxation.
   - Drag is stronger during relaxation and weaker during contraction.

8. **Wall response + stabilization**
   - Soft wall response rotates away from edges, damps perpendicular velocity, and adds a gentle push.
   - Side-slip damping reduces lateral stepping.
   - Deadband zeroes tiny velocities to prevent twitching.

9. **Integration + clamping**
   - The head integrates velocity, then is softly clamped to screen bounds with damping.

10. **Body propagation**
   - `GusanoBody.updateSegments()` trails the body with phase- and speed-dependent follow and turbulence.
   - A lateral undulation wave propagates down the body.

11. **Wake deposit**
   - Each jellyfish deposits into the wake grid proportionally to its speed.

## Steering System (`GusanoSteering.pde`)

### Phase-gated steering
- Most steering forces are gated by contraction (`steerPhaseGate`), meaning steering is strongest during propulsion and weaker during glide.
- Wall avoidance gets partial bypass of phase gating (survival behavior).

### User interaction
- Mouse press + proximity produces a physical push in `Gusano.actualizar()`.
- Steering adds a short-range repulsion when the mouse is pressed.

### Neighbor interactions (spatial grid)
- Uses a 3x3 cell neighborhood around the head.
- FOV-based cohesion and 360-degree separation.
- Attention budget is limited (2 neighbors) for stability.
- SHY jellies flee dominant ones; DOM vs DOM uses a stable winner/loser rule to avoid deadlock.

### Aggressive pursuit
- If in AGGRESSIVE state, steering switches to `computeAggroPursuit()`:
  - Target selection uses distance + FOV checks.
  - A pause-and-pounce sequence adds a brief hesitation before an attack burst.
  - Pursuit thrust is pulse-synchronized.

### Walls, wake, flow, wander, sway
- **Wall avoidance** uses quadratic falloff near margins with partial phase bypass.
- **Wake gradient**: SHY avoids; DOM follows. (Only if `useWake` is true.)
- **Flow field**: swirl + push derived from wake gradient. (Only if `useFlow` is true.)
- **Wander** and **lateral sway** add organic drift and sideways variation.

Note: `useCohesion`, `useSeparation`, `useWander`, `useWallAvoid`, `usePursuit` are toggled via input/UI, but currently only `useWake` and `useFlow` are checked in steering code.

## Dynamics System (`GusanoDynamics.pde`)

- **Orientation-gated thrust**: thrust strength is reduced if the head is turned away from the desired direction.
- **Breathing variation**: slow noise modulates thrust for organic rhythm.
- **Recovery thrust**: small push during relaxation (helps glide feel alive).
- **Buoyancy**: sinks when relaxed, lifts during contraction; bottom margin reduces sink.
- **Drag**: higher drag during relaxation, lower during contraction.
- **Walls**: rotational deflection plus sliding friction and soft push.
- **Side-slip damping**: reduces lateral velocity components.
- **Deadband**: kills very small residual velocities.

## Pulse Model (`GusanoPulse.pde`)

- Pulse phase advances with per-jelly jitter (noise-based) to avoid metronomic motion.
- Contraction shape:
  - Fast ease-out into contraction, optional hold, slow ease-in release.
- Thrust curve:
  - Only nonzero during contraction; peaks early/mid contraction (sine of sqrt).

## Body and Segments (`GusanoBody.pde`, `Segmento.pde`)

- **Follow speed** increases with motion/streamline; boosted during contraction, reduced in glide.
- **Turbulence** decreases at high speed and during contraction; gated by motion to avoid jitter.
- **Undulation**: a lateral wave travels down the body, stronger when moving slowly.
- **Segment follow**: each segment follows its parent with smoothed step and clamps to bounds.

## Wake Field and Flow (`WakeField.pde`)

- A `gridW x gridH` scalar field stores wake density.
- Each frame diffuses and decays the field.
- Gradient sampling provides wake direction; flow is computed as swirl + push.
- Jellyfish deposit wake each frame; mouse deposits wake blobs when moving or pressed.

### Water interaction rendering
- Ink wash (dominant mass layer).
- Flow-aligned strokes (direction layer).
- Caustic sparkles (light shimmer layer).

## Personality (`GusanoMood.pde`)

- Mood switching is disabled; each jellyfish stays in its base personality (DOM/SHY).
- `applyMood()` blends pulse, drag, turn rate, turbulence, and noise for SHY vs AGGRESSIVE.
- Colors are mapped per personality and lerped for smooth transitions.

## Debug Controls and Toggles (`Input.pde` / `DebugOverlay.pde`)

Key bindings (subset):

- `+` / `-`: increase or decrease `numGusanos` and respawn.
- `1` / `2`: toggle flow / wake (used in steering).
- `3` / `4` / `5` / `6`: toggle cohesion, separation, wander, wall avoid (UI only right now).
- `S`: steering vectors; `O`: objectives; `H`: help overlay.
- `W`: wake grid; `F`: wake vectors; `I`: water interaction.
- `K`: lock/unlock mood to personality; `D`: mood debug; `V`: stabilizer.

## Key Tuning Knobs (`Config.pde`)

- Counts: `numGusanos`, `numSegmentos`.
- Pulse + motion: `UNDULATION_MAX`, `GLIDE_*`, `FOLLOW_*`, `THRUST_SMOOTH_ALPHA`.
- Steering caps: `MAX_STEER_*`, `MAX_TOTAL_STEER`.
- Walls: `clampMarginX`, `clampMarginTop`, `clampMarginBottom`.
- Wake/flow: `wakeDecay`, `wakeDiffuse`, `FLOW_STEER_SCALE`, `WAKE_STEER_SCALE`.
- Mood: `LOCK_MOOD_TO_PERSONALITY`, `MOOD_*` hysteresis, `AGG_*`, `SHY_*`.

## Extension Points

- Add new steering forces in `GusanoSteering` (e.g., light attraction).
- Adjust pulse shape in `GusanoPulse` for different swim styles.
- Change body undulation in `GusanoBody` for different silhouettes.
- Swap or add rendering patterns in `GusanoRender`.
- Wire the unused steering toggles into `computeSteering()` if you want live control.
