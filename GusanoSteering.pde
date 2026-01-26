// --- Pulse-locked steering tuning ---
// Lower = less steering during glide (relaxation). Higher = more constant steering.
// Values mirror the previous commit for more natural coasting control.
final float STEER_GLIDE_MIN = 0.06;
// Exponent shaping for how quickly steering ramps up during contraction.
// Higher = steering concentrated near peak contraction; small increase biases
// steering to contraction phase for clearer head-led turns.
final float STEER_GLIDE_EXP = 3.0;

class GusanoSteering {
  Gusano g;
  ArrayList<Gusano> neighborsScratch = new ArrayList<Gusano>();
  final PVector desired = new PVector(0, 0);
  final PVector forward = new PVector(0, 0);
  final PVector toMouse = new PVector(0, 0);
  final PVector sep = new PVector(0, 0);
  final PVector coh = new PVector(0, 0);
  final PVector align = new PVector(0, 0);
  final PVector orbit = new PVector(0, 0);
  final PVector toOther = new PVector(0, 0);
  final PVector away = new PVector(0, 0);
  final PVector perp = new PVector(0, 0);
  final PVector wallForce = new PVector(0, 0);
  final PVector tmp = new PVector(0, 0);
  final PVector flow = new PVector(0, 0);
  final PVector grad = new PVector(0, 0);
  final PVector toTarget = new PVector(0, 0);
  final PVector heading = new PVector(0, 0);
  final PVector aggro = new PVector(0, 0);

  GusanoSteering(Gusano g) {
    this.g = g;
  }

  PVector computeSteering(Segmento cabeza) {
    desired.set(0, 0);

    resetDebugSteer();
    g.debugWanderScale = 1.0;
    if (g.state != Gusano.AGGRESSIVE) {
      g.aggroTargetId = -1;
      g.aggroLastSeenMs = -9999;
    }
    
    // --- 1. SENSORY PARAMETERS (Rain World Style) ---
    float viewAngle = cos(radians(70)); // 140-degree field of vision
    int attentionBudget = 2;           // Only focus on the 2 closest neighbors (will grow when busy)
    float wallMarginX = clampMarginX;  // Soft cushion margin
    float wallMarginTop = clampMarginTop;
    float wallMarginBottom = clampMarginBottom;
    float neighborSenseRadius = 180;
    float sepRadius = 55;
    float alignRadius = ALIGN_RADIUS;
    
    // === BIOLOGICAL CONSTRAINT: Pulsed Steering ===
    // Jellyfish primarily steer during propulsion phase, not while coasting.
    // Calculate phase gate early so all steering forces can use it.
    float contractCurve = g.pulseContractCurve(g.pulsePhase);
    // Jellyfish steer primarily during propulsion (contraction), not while coasting.
    // Use a steep gate: near-zero steering in glide, strong steering in contraction.
    float cc = constrain(contractCurve, 0, 1);
    float steerPhaseGate = STEER_GLIDE_MIN + (1.0 - STEER_GLIDE_MIN) * pow(cc, STEER_GLIDE_EXP);

    // --- 0. INTERACTION ARCS (readable events) ---
    // This sits *on top* of continuous forces. When an arc is active, we bias or override
    // steering so encounters become legible: spot -> react -> cool down.
    updateInteractionArc(cabeza);

    // Arc overrides: flee/chase return early so the event reads clearly.
    if (g.arcState == Gusano.ARC_FLEE) {
      PVector flee = computeFleeArc(cabeza, cc);
      // Still keep wall avoidance so fleeing doesn't slam into borders.
      addWallAvoidInto(flee, cabeza, cc);
      return flee;
    }

    if (g.arcState == Gusano.ARC_CHASE) {
      // Drive existing pursuit system using the arc target.
      if (g.arcTargetId >= 0) {
        g.aggroTargetId = g.arcTargetId;
        g.aggroLastSeenMs = millis();
      }
      PVector chase = computeAggroPursuit(cabeza);
      addWallAvoidInto(chase, cabeza, cc);
      g.debugSteerAggro.set(chase);
      return chase;
    }
    
    // Weights based on archetype (SHY vs AGGRESSIVE)
    float wanderW = 0.9;
    float avoidW = 1.8;
    float sepW = (g.state == Gusano.SHY) ? 2.4 : 1.2;
    float mouseSenseDist = 350;

    forward.set(cos(g.headAngle), sin(g.headAngle));

    // --- 2. USER AS ORGANISM ---
    // The user is no longer a "hack"—the medusa "sees" the mouse
    float dMouse = dist(cabeza.x, cabeza.y, mouseX, mouseY);
    if (dMouse < mouseSenseDist) {
      toMouse.set(mouseX - cabeza.x, mouseY - cabeza.y);
      toMouse.normalize();

      if (mousePressed && dMouse < 100) {
        tmp.set(toMouse).mult(-6.0 * steerPhaseGate);
        desired.add(tmp); // Flee from predator (direct interaction only)
        g.debugSteerMouse.set(tmp);
      }
    }

    // --- 3. NEIGHBOR FILTERING (FOV & Attention) ---
    // Prevents network instability by limiting focus to immediate vicinity
    queryNeighbors(cabeza.x, cabeza.y, neighborsScratch);
    int processed = 0;
    // Dynamic attention: increase budget when crowding is high
    float crowd = min(1.0, neighborsScratch.size() / (float)ATTN_MAX);
    attentionBudget = (int)ceil(lerp(ATTN_MIN, ATTN_MAX, pow(crowd, 0.6)));
    float fleeRadius = 220;
    float fleeRadiusSq = fleeRadius * fleeRadius;
    Gusano nearestDominant = null;
    float bestDominantD2 = 1e9;
    
    sep.set(0, 0);
    coh.set(0, 0);
    align.set(0, 0);
    for (Gusano other : neighborsScratch) {
      if (other == g || processed >= attentionBudget) continue;
      
      Segmento oHead = other.segmentos.get(0);
      // Dominant vs dominant: assign a stable winner to avoid dead-lock
      if (g.baseMood == Gusano.AGGRESSIVE && other.baseMood == Gusano.AGGRESSIVE) {
        float dxT = oHead.x - cabeza.x;
        float dyT = oHead.y - cabeza.y;
        float d2T = dxT * dxT + dyT * dyT;
        if (d2T < bestDominantD2 && d2T < fleeRadiusSq) {
          bestDominantD2 = d2T;
          nearestDominant = other;
        }
      }
      if (g.baseMood == Gusano.SHY && other.baseMood == Gusano.AGGRESSIVE) {
        float dxT = oHead.x - cabeza.x;
        float dyT = oHead.y - cabeza.y;
        float d2T = dxT * dxT + dyT * dyT;
        if (d2T < bestDominantD2 && d2T < fleeRadiusSq) {
          bestDominantD2 = d2T;
          nearestDominant = other;
        }
      }
      toOther.set(oHead.x - cabeza.x, oHead.y - cabeza.y);
      float d = toOther.mag();
      if (d > neighborSenseRadius || d < 0.1) continue;
      toOther.normalize();

      // Separation: Tactile sense (360 degrees) - phase-gated
      if (d < sepRadius) {
        tmp.set(toOther).mult(-sepW * (1.0 - d / sepRadius) * steerPhaseGate);
        sep.add(tmp);
      } 
      // Cohesion: Visual sense (Frontal Cone Only) - phase-gated
      else if (forward.dot(toOther) > viewAngle) {
        tmp.set(toOther).mult(0.4 * steerPhaseGate);
        coh.add(tmp);
        processed++; 
      }
      // Alignment: match heading with nearby visible neighbors (weighted by distance)
      if (d < alignRadius && forward.dot(toOther) > -0.2) { // allow slightly behind
        PVector oVel = other.vel;
        if (oVel != null && oVel.magSq() > 0.0001) {
          float w = pow(constrain(1.0 - d / alignRadius, 0, 1), ALIGN_FALLOFF_EXP);
          tmp.set(oVel).normalize().mult(w * steerPhaseGate);
          align.add(tmp);
        }
      }
    }
    desired.add(sep);
    desired.add(coh);
    align.mult(ALIGN_WEIGHT);
    desired.add(align);
    g.debugSteerSep.set(sep);
    g.debugSteerCoh.set(coh);
    g.debugSteerAlign.set(align);
    g.debugSteerNeighbors.set(sep.x + coh.x + align.x, sep.y + coh.y + align.y);

    // --- 3b. Shy flee boost when a dominant is nearby ---
    // Flee gets partial phase bypass (survival instinct)
    float fleePhaseGate = lerp(0.5, 1.0, cc);
    if (g.baseMood == Gusano.SHY && nearestDominant != null) {
      Segmento threatHead = nearestDominant.segmentos.get(0);
      away.set(cabeza.x - threatHead.x, cabeza.y - threatHead.y);
      float d2 = away.magSq();
      if (d2 > 0.0001) {
        float d = sqrt(d2);
        float tFlee = constrain(1.0 - (d / fleeRadius), 0, 1);
        away.normalize();
        float fleeStrength = lerp(0.8, 2.2, tFlee);
        tmp.set(away).mult(fleeStrength * 2.0 * fleePhaseGate);
        desired.add(tmp);
      }
    }

    // --- 3c. Dominant vs dominant: stable winner, loser yields ---
    if (g.baseMood == Gusano.AGGRESSIVE && nearestDominant != null) {
      Segmento threatHead = nearestDominant.segmentos.get(0);
      boolean gIsSmaller = g.sizeFactor < nearestDominant.sizeFactor;
      boolean equalSize = abs(g.sizeFactor - nearestDominant.sizeFactor) < 0.0001;
      boolean gLoses = gIsSmaller || (equalSize && g.id < nearestDominant.id);
      if (gLoses) {
        // Loser yields: step away + small lateral sidestep (phase-gated)
        away.set(cabeza.x - threatHead.x, cabeza.y - threatHead.y);
        float d2 = away.magSq();
        if (d2 > 0.0001) {
          float d = sqrt(d2);
          float tYield = constrain(1.0 - (d / fleeRadius), 0, 1);
          away.normalize();
          perp.set(-away.y, away.x);
          tmp.set(away).mult(lerp(0.6, 1.6, tYield));
          tmp.add(perp.mult(lerp(0.2, 0.8, tYield)));
          tmp.mult(2.0 * fleePhaseGate);
          desired.add(tmp);
        }
      }
      // Winner continues without extra force.
    }

    // --- 4. QUADRATIC WALL STEERING ---
    // Replaces hard-coded "vel.x += 0.2" with smooth arcing avoidance
    // Wall avoidance gets partial phase bypass (survival)
    float wallPhaseGate = lerp(0.5, 1.0, cc);
    wallForce.set(0, 0);
    if (cabeza.x < wallMarginX) wallForce.x += sq(1.0 - cabeza.x / wallMarginX);
    if (cabeza.x > width - wallMarginX) wallForce.x -= sq(1.0 - (width - cabeza.x) / wallMarginX);
    if (cabeza.y < wallMarginTop) wallForce.y += sq(1.0 - cabeza.y / wallMarginTop);
    if (cabeza.y > height - wallMarginBottom) wallForce.y -= sq(1.0 - (height - cabeza.y) / wallMarginBottom);

    // Gently turn away from walls instead of jittering against clamps
    float wallMag = wallForce.mag();
    if (wallMag > 0.0001) {
      wallForce.normalize();
      tmp.set(wallForce).mult(avoidW * 3.5 * wallPhaseGate);
      desired.add(tmp);
      g.debugSteerWall.set(tmp);
      // Reduce wander near walls so turn is decisive
      wanderW *= 0.6;
    }

    // --- 4b. WAKE/FLOW ENVIRONMENT ---
    // Flow: ambient current field.
    if (useFlow) {
      sampleFlow(cabeza.x, cabeza.y, flow);
      float flowMagSq = flow.magSq();
      if (flowMagSq > 0.0001) {
        if (flowMagSq > FLOW_MAX_FORCE * FLOW_MAX_FORCE) {
          flow.normalize();
          flow.mult(FLOW_MAX_FORCE);
        }
        if (FLOW_PERP_SCALE < 0.999) {
          float along = PVector.dot(flow, forward);
          tmp.set(forward).mult(along);
          perp.set(flow).sub(tmp);
          perp.mult(FLOW_PERP_SCALE);
          flow.set(tmp).add(perp);
        }
        flow.mult(FLOW_STEER_SCALE * steerPhaseGate);
        desired.add(flow);
      }
    }

    // Wake gradient: SHY avoids, DOM (AGGRESSIVE) follows.
    if (useWake) {
      float wakeSign = 0.0;
      if (g.baseMood == Gusano.SHY) {
        wakeSign = -1.0;
      } else if (g.baseMood == Gusano.AGGRESSIVE) {
        wakeSign = 1.0;
      }
      if (abs(wakeSign) > 0.0001) {
        sampleWakeGradient(cabeza.x, cabeza.y, grad);
        float gradMagSq = grad.magSq();
        if (gradMagSq > 0.0001) {
          if (gradMagSq > WAKE_MAX_FORCE * WAKE_MAX_FORCE) {
            grad.normalize();
            grad.mult(WAKE_MAX_FORCE);
          }
          grad.mult(WAKE_STEER_SCALE * wakeSign * steerPhaseGate);
          desired.add(grad);
        }
      }
    }

    float glide01 = 1.0 - contractCurve;
    float glideSteerScale = lerp(1.0, GLIDE_STEER_SCALE, glide01);
    g.debugWanderScale = glideSteerScale;

    // --- 5. WANDER (Organic Drift) --- phase-gated via glideSteerScale + steerPhaseGate
    float nx = noise(g.noiseOffset, t * 0.06) - 0.5;
    float ny = noise(g.noiseOffset + 500, t * 0.06) - 0.5;
    tmp.set(nx, ny).mult(wanderW * glideSteerScale * steerPhaseGate);
    desired.add(tmp);
    g.debugSteerWander.set(tmp);

    // --- 6. LATERAL SWAY (Natural horizontal variation) --- phase-gated
    // Adds gentle sideways drift so motion isn't synchronized or strictly forward.
    float sway = (noise(g.noiseOffset + 2000, t * 0.15) - 0.5) * 2.0;
    perp.set(-forward.y, forward.x);
    tmp.set(perp).mult(sway * 0.18 * glideSteerScale * steerPhaseGate);
    desired.add(tmp);
    g.debugSteerSway.set(tmp);

    return desired;
  }

  void resetDebugSteer() {
    g.debugSteerMouse.set(0, 0);
    g.debugSteerWall.set(0, 0);
    g.debugSteerSep.set(0, 0);
    g.debugSteerCoh.set(0, 0);
    g.debugSteerNeighbors.set(0, 0);
    g.debugSteerWander.set(0, 0);
    g.debugSteerSway.set(0, 0);
    g.debugSteerAggro.set(0, 0);
  }

  PVector computeAggroPursuit(Segmento cabeza) {
    Gusano target = resolveAggroTarget(cabeza);
    if (target == null) {
      g.aggroLockMs = -9999;
      g.aggroPounceReady = false;
      aggro.set(0, 0);
      return aggro;
    }

    float dtNorm = ((simDt > 0) ? simDt : (1.0 / max(1, frameRate))) * 60.0;
    
    Segmento targetHead = target.segmentos.get(0);
    toTarget.set(targetHead.x - cabeza.x, targetHead.y - cabeza.y);
    if (toTarget.magSq() < 0.0001) {
      aggro.set(0, 0);
      return aggro;
    }
    toTarget.normalize();
    
    // Pause-and-pounce: when first spotting target, pause briefly before attacking
    int now = millis();
    if (g.aggroLockMs < 0) {
      g.aggroLockMs = now; // Just spotted target
      g.aggroPounceReady = false;
    }
    
    float timeSinceLock = (now - g.aggroLockMs) / 1000.0;
    
    // During pause: minimal movement, sizing up target
    if (timeSinceLock < g.aggroPauseTime) {
      g.aggroPounceReady = false;
      // Slight drift toward target during pause
      aggro.set(toTarget).mult(0.3);
      return aggro;
    }
    
    // After pause: sudden acceleration burst
    if (!g.aggroPounceReady) {
      g.aggroPounceReady = true;
      // Add extra impulse on first pounce frame, aligned to heading
      heading.set(cos(g.headAngle), sin(g.headAngle));
      float align = max(0.0, PVector.dot(heading, toTarget));
      tmp.set(heading).mult(2.5 * align * dtNorm);
      g.vel.add(tmp);
    }
    
    // Pulse-synchronized chase: only thrust during contraction phase
    float contraction = g.pulseContractCurve(g.pulsePhase);
    float rhythmGate = contraction; // 0 during relaxation, 1 during contraction
    
    // Distance-based attack intensity
    float dist = dist(cabeza.x, cabeza.y, targetHead.x, targetHead.y);
    float attackIntensity = constrain(map(dist, 20, 120, 2.5, 1.0), 1.0, 2.5);
    
    // Rhythmic burst: stronger during pulse peak, extra boost while pouncing
    float pounceBoost = timeSinceLock < (g.aggroPauseTime + 1.0) ? 1.3 : 1.0;
    float chaseMagnitude = rhythmGate * attackIntensity * 2.8 * pounceBoost;
    
    aggro.set(toTarget).mult(chaseMagnitude);
    return aggro;
  }

  Gusano resolveAggroTarget(Segmento cabeza) {
    float maxDist = 180;
    float maxDistSq = maxDist * maxDist;
    float fovCos = cos(radians(60));
    forward.set(cos(g.headAngle), sin(g.headAngle));

    if (g.aggroTargetId >= 0) {
      Gusano current = findGusanoById(g.aggroTargetId);
      if (current != null && isAggroTargetValid(cabeza, current, maxDistSq, fovCos, forward)) {
        g.aggroLastSeenMs = millis();
        return current;
      }
    }

    Gusano best = null;
    float bestD2 = 1e9;
    queryNeighbors(cabeza.x, cabeza.y, neighborsScratch);
    for (Gusano other : neighborsScratch) {
      if (other == g) continue;
      if (!isAggroTargetValid(cabeza, other, maxDistSq, fovCos, forward)) continue;
      Segmento otherHead = other.segmentos.get(0);
      float dx = otherHead.x - cabeza.x;
      float dy = otherHead.y - cabeza.y;
      float d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = other;
      }
    }

    if (best != null) {
      // If target changed, reset lock timer
      if (g.aggroTargetId != best.id) {
        g.aggroLockMs = -9999;
        g.aggroPounceReady = false;
      }
      g.aggroTargetId = best.id;
      g.aggroLastSeenMs = millis();
    } else {
      g.aggroTargetId = -1;
      g.aggroLockMs = -9999;
      g.aggroPounceReady = false;
    }
    return best;
  }

  boolean isAggroTargetValid(Segmento cabeza, Gusano other, float maxDistSq, float fovCos, PVector forward) {
    if (other == null || other.segmentos == null || other.segmentos.size() == 0) return false;
    Segmento otherHead = other.segmentos.get(0);
    float dx = otherHead.x - cabeza.x;
    float dy = otherHead.y - cabeza.y;
    float d2 = dx * dx + dy * dy;
    if (d2 <= 0.0001 || d2 > maxDistSq) return false;
    float d = sqrt(d2);
    float dot = (dx * forward.x + dy * forward.y) / d;
    return dot > fovCos;
  }

  Gusano findGusanoById(int id) {
    if (gusanos == null) return null;
    for (Gusano other : gusanos) {
      if (other != null && other.id == id) return other;
    }
    return null;
  }

  void setArcState(int newState, int targetId) {
    int now = millis();
    if (g.arcState == newState && g.arcTargetId == targetId) return;
    g.arcState = newState;
    g.arcTargetId = targetId;
    g.arcStateStartMs = now;
    if (newState == Gusano.ARC_FLEE || newState == Gusano.ARC_CHASE) {
      g.arcLastTriggerMs = now;
    }
  }

  void updateInteractionArc(Segmento cabeza) {
    int now = millis();

    // Cooldown expires back to calm.
    if (g.arcState == Gusano.ARC_COOLDOWN) {
      if (now - g.arcStateStartMs >= g.arcCooldownMs) {
        setArcState(Gusano.ARC_CALM, -1);
      }
      return;
    }

    // If we're in an active event, validate the target and decide whether to end.
    if (g.arcState == Gusano.ARC_FLEE || g.arcState == Gusano.ARC_CHASE) {
      Gusano target = findGusanoById(g.arcTargetId);
      if (target == null || target.segmentos == null || target.segmentos.size() == 0) {
        setArcState(Gusano.ARC_COOLDOWN, -1);
        return;
      }
      Segmento th = target.segmentos.get(0);
      float dx = th.x - cabeza.x;
      float dy = th.y - cabeza.y;
      float d2 = dx * dx + dy * dy;
      float loseR2 = g.arcLoseRadius * g.arcLoseRadius;

      // Hold the reaction at least arcMinHoldMs so it reads on screen.
      boolean minHoldPassed = (now - g.arcStateStartMs) >= g.arcMinHoldMs;

      // End condition: target is far enough away (flee succeeded / prey escaped)
      if (minHoldPassed && d2 > loseR2) {
        setArcState(Gusano.ARC_COOLDOWN, -1);
      }
      return;
    }

    // From calm: decide whether to start a new event.
    // Small throttle so events don't re-trigger every frame.
    if (now - g.arcLastTriggerMs < g.arcCooldownMs) return;

    float spotR2 = g.arcSpotRadius * g.arcSpotRadius;

    // Scan nearby neighbors (cheap). Prefer immediate vicinity.
    queryNeighbors(cabeza.x, cabeza.y, neighborsScratch);

    Gusano best = null;
    float bestD2 = 1e18;

    if (g.baseMood == Gusano.SHY) {
      // SHY: start FLEE if an aggressive/dominant comes close.
      for (Gusano other : neighborsScratch) {
        if (other == null || other == g) continue;
        if (other.baseMood != Gusano.AGGRESSIVE) continue;
        Segmento oh = other.segmentos.get(0);
        float dx = oh.x - cabeza.x;
        float dy = oh.y - cabeza.y;
        float d2 = dx * dx + dy * dy;
        if (d2 < spotR2 && d2 < bestD2) {
          bestD2 = d2;
          best = other;
        }
      }
      if (best != null) {
        setArcState(Gusano.ARC_FLEE, best.id);
      }

    } else {
      // AGGRESSIVE: start CHASE if a smaller/softer target is close.
      for (Gusano other : neighborsScratch) {
        if (other == null || other == g) continue;
        // Don't endlessly chase other dominants; keep it legible.
        if (other.baseMood == Gusano.AGGRESSIVE) continue;
        // Prefer not chasing bigger targets.
        if (other.sizeFactor > g.sizeFactor * 1.05) continue;

        Segmento oh = other.segmentos.get(0);
        float dx = oh.x - cabeza.x;
        float dy = oh.y - cabeza.y;
        float d2 = dx * dx + dy * dy;
        if (d2 < spotR2 && d2 < bestD2) {
          bestD2 = d2;
          best = other;
        }
      }
      if (best != null) {
        setArcState(Gusano.ARC_CHASE, best.id);
      }
    }
  }

  PVector computeFleeArc(Segmento cabeza, float cc) {
    Gusano threat = findGusanoById(g.arcTargetId);
    if (threat == null || threat.segmentos == null || threat.segmentos.size() == 0) {
      setArcState(Gusano.ARC_COOLDOWN, -1);
      aggro.set(0, 0);
      return aggro;
    }
    Segmento th = threat.segmentos.get(0);
    away.set(cabeza.x - th.x, cabeza.y - th.y);
    float m2 = away.magSq();
    if (m2 < 0.0001) {
      aggro.set(0, 0);
      return aggro;
    }
    away.normalize();

    // Survival instinct: partial phase bypass so flee still happens in glide.
    float fleePhaseGate = lerp(0.55, 1.0, cc);

    // Stronger flee when closer.
    float d = dist(cabeza.x, cabeza.y, th.x, th.y);
    float tClose = constrain(1.0 - (d / max(1.0, g.arcSpotRadius)), 0, 1);
    float strength = lerp(1.2, 3.2, pow(tClose, 0.7));

    aggro.set(away).mult(strength * fleePhaseGate);
    return aggro;
  }

  void addWallAvoidInto(PVector v, Segmento cabeza, float cc) {
    // Copy of the wall-avoid logic but additive into an existing vector.
    float wallPhaseGate = lerp(0.5, 1.0, cc);
    wallForce.set(0, 0);
    float wallMarginX = clampMarginX;
    float wallMarginTop = clampMarginTop;
    float wallMarginBottom = clampMarginBottom;

    if (cabeza.x < wallMarginX) wallForce.x += sq(1.0 - cabeza.x / wallMarginX);
    if (cabeza.x > width - wallMarginX) wallForce.x -= sq(1.0 - (width - cabeza.x) / wallMarginX);
    if (cabeza.y < wallMarginTop) wallForce.y += sq(1.0 - cabeza.y / wallMarginTop);
    if (cabeza.y > height - wallMarginBottom) wallForce.y -= sq(1.0 - (height - cabeza.y) / wallMarginBottom);

    float wallMag = wallForce.mag();
    if (wallMag > 0.0001) {
      wallForce.normalize();
      tmp.set(wallForce).mult(1.8 * 3.0 * wallPhaseGate);
      v.add(tmp);
    }
  }
}