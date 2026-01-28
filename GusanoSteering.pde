class GusanoSteering {
  Gusano g;

  GusanoSteering(Gusano g) {
    this.g = g;
  }

  PVector computeSteering(Segmento cabeza) {
    PVector desired = new PVector(0, 0);

    resetDebugSteer();
    g.debugWanderScale = 1.0;
    if (g.state != Gusano.AGGRESSIVE) {
      g.aggroTargetId = -1;
      g.aggroLastSeenMs = -9999;
    }

    if (g.state == Gusano.AGGRESSIVE) {
      // Allow AGGRESSIVE agents to sometimes approach a nearby/still user
      float contractCurve = g.pulseContractCurve(g.pulsePhase);
      float steerPhaseGate = lerp(0.2, 1.0, contractCurve);

      float dMouse = dist(cabeza.x, cabeza.y, mouseX, mouseY);
      // If mouse is nearby, mostly still, and this agent has high curiosity, approach
      if (dMouse < 350 && g.curiosity > 0.45 && mouseSpeed < 4) {
        PVector toMouse = new PVector(mouseX - cabeza.x, mouseY - cabeza.y);
        if (toMouse.magSq() > 0.0001) {
          toMouse.normalize();
          PVector m = PVector.mult(toMouse, 2.0 * steerPhaseGate * g.curiosity);
          g.debugSteerMouse.set(m);
          return m;
        }
      }

      PVector aggro = computeAggroPursuit(cabeza);
      g.debugSteerAggro.set(aggro);
      return aggro;
    }
    
    // --- 1. SENSORY PARAMETERS (Rain World Style) ---
    float viewAngle = cos(radians(70)); // 140-degree field of vision
    int attentionBudget = 2;           // Only focus on the 2 closest neighbors
    float wallMarginX = clampMarginX;  // Soft cushion margin
    float wallMarginTop = clampMarginTop;
    float wallMarginBottom = clampMarginBottom;
    float neighborSenseRadius = 180;
    float sepRadius = 55;
    
    // === BIOLOGICAL CONSTRAINT: Pulsed Steering ===
    // Jellyfish primarily steer during propulsion phase, not while coasting.
    // Calculate phase gate early so all steering forces can use it.
    float contractCurve = g.pulseContractCurve(g.pulsePhase);
    float steerPhaseGate = lerp(0.2, 1.0, contractCurve); // Minimal steering during coast
    
    // Weights based on Mood
    float wanderW = (g.state == Gusano.CALM) ? 2.4 : 1.2;
    float avoidW = (g.state == Gusano.FEAR) ? 5.0 : 1.8;
    float sepW = (g.state == Gusano.SHY || g.state == Gusano.FEAR) ? 2.8 : 1.2;
    float mouseSenseDist = 350;

    PVector forward = new PVector(cos(g.headAngle), sin(g.headAngle));

    // --- 2. USER AS ORGANISM (Fear/Curiosity) ---
    // The user is no longer a "hack"—the medusa "sees" the mouse
    // Fear can partially override phase gating (survival instinct)
    float dMouse = dist(cabeza.x, cabeza.y, mouseX, mouseY);
    if (dMouse < mouseSenseDist) {
      PVector toMouse = new PVector(mouseX - cabeza.x, mouseY - cabeza.y);
      toMouse.normalize();

      // Fear gets partial phase bypass (survival)
      float fearPhaseGate = (g.state == Gusano.FEAR) ? lerp(0.6, 1.0, contractCurve) : steerPhaseGate;
      
      if (g.state == Gusano.FEAR || (mousePressed && dMouse < 100)) {
        PVector m = PVector.mult(toMouse, -6.0 * fearPhaseGate);
        desired.add(m); // Flee from predator
        g.debugSteerMouse.set(m);
      } else if (g.state == Gusano.CURIOUS && mouseSpeed < 4) {
        PVector m = PVector.mult(toMouse, 0.7 * steerPhaseGate);
        desired.add(m);  // Approach strange still object
        g.debugSteerMouse.set(m);
      }
    }

    // --- 3. NEIGHBOR FILTERING (FOV & Attention) ---
    // Prevents network instability by limiting focus to immediate vicinity
    ArrayList<Gusano> neighbors = queryNeighbors(cabeza.x, cabeza.y);
    int processed = 0;
    float fleeRadius = 220;
    float fleeRadiusSq = fleeRadius * fleeRadius;
    Gusano nearestDominant = null;
    float bestDominantD2 = 1e9;
    
    PVector sep = new PVector(0, 0);
    PVector coh = new PVector(0, 0);
    for (Gusano other : neighbors) {
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
      PVector toOther = new PVector(oHead.x - cabeza.x, oHead.y - cabeza.y);
      float d = toOther.mag();
      if (d > neighborSenseRadius || d < 0.1) continue;
      toOther.normalize();

      // Separation: Tactile sense (360 degrees) - phase-gated
      if (d < sepRadius) {
        PVector away = PVector.mult(toOther, -sepW * (1.0 - d / sepRadius) * steerPhaseGate);
        sep.add(away);
      } 
      // Cohesion: Visual sense (Frontal Cone Only) - phase-gated
      else if (forward.dot(toOther) > viewAngle) {
        PVector toward = PVector.mult(toOther, 0.4 * steerPhaseGate);
        coh.add(toward);
        processed++; 
      }
    }
    desired.add(sep);
    desired.add(coh);
    g.debugSteerSep.set(sep);
    g.debugSteerCoh.set(coh);
    g.debugSteerNeighbors.set(sep.x + coh.x, sep.y + coh.y);

    // --- 3b. Shy flee boost when a dominant is nearby ---
    // Flee gets partial phase bypass (survival instinct)
    float fleePhaseGate = lerp(0.5, 1.0, contractCurve);
    if (g.baseMood == Gusano.SHY && nearestDominant != null) {
      Segmento threatHead = nearestDominant.segmentos.get(0);
      PVector away = new PVector(cabeza.x - threatHead.x, cabeza.y - threatHead.y);
      float d2 = away.magSq();
      if (d2 > 0.0001) {
        float d = sqrt(d2);
        float tFlee = constrain(1.0 - (d / fleeRadius), 0, 1);
        away.normalize();
        float fleeStrength = lerp(0.8, 2.2, tFlee);
        PVector flee = PVector.mult(away, fleeStrength * 2.0 * fleePhaseGate);
        desired.add(flee);
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
        PVector away = new PVector(cabeza.x - threatHead.x, cabeza.y - threatHead.y);
        float d2 = away.magSq();
        if (d2 > 0.0001) {
          float d = sqrt(d2);
          float tYield = constrain(1.0 - (d / fleeRadius), 0, 1);
          away.normalize();
          PVector perp = new PVector(-away.y, away.x);
          PVector yieldVec = PVector.mult(away, lerp(0.6, 1.6, tYield));
          yieldVec.add(PVector.mult(perp, lerp(0.2, 0.8, tYield)));
          desired.add(PVector.mult(yieldVec, 2.0 * fleePhaseGate));
        }
      }
      // Winner continues without extra force.
    }

    // --- 4. QUADRATIC WALL STEERING ---
    // Replaces hard-coded "vel.x += 0.2" with smooth arcing avoidance
    // Wall avoidance gets partial phase bypass (survival)
    float wallPhaseGate = lerp(0.5, 1.0, contractCurve);
    PVector wallForce = new PVector(0, 0);
    if (cabeza.x < wallMarginX) wallForce.x += sq(1.0 - cabeza.x / wallMarginX);
    if (cabeza.x > width - wallMarginX) wallForce.x -= sq(1.0 - (width - cabeza.x) / wallMarginX);
    if (cabeza.y < wallMarginTop) wallForce.y += sq(1.0 - cabeza.y / wallMarginTop);
    if (cabeza.y > height - wallMarginBottom) wallForce.y -= sq(1.0 - (height - cabeza.y) / wallMarginBottom);

    // Gently turn away from walls instead of jittering against clamps
    float wallMag = wallForce.mag();
    if (wallMag > 0.0001) {
      wallForce.normalize();
      PVector w = PVector.mult(wallForce, avoidW * 3.5 * wallPhaseGate);
      desired.add(w);
      g.debugSteerWall.set(w);
      // Reduce wander near walls so turn is decisive
      wanderW *= 0.6;
    }

    float glide01 = 1.0 - contractCurve;
    float glideSteerScale = lerp(1.0, GLIDE_STEER_SCALE, glide01);
    g.debugWanderScale = glideSteerScale;

    // --- 5. WANDER (Organic Drift) --- phase-gated via glideSteerScale + steerPhaseGate
    float nx = noise(g.noiseOffset, t * 0.06) - 0.5;
    float ny = noise(g.noiseOffset + 500, t * 0.06) - 0.5;
    PVector wander = new PVector(nx, ny).mult(wanderW * glideSteerScale * steerPhaseGate);
    desired.add(wander);
    g.debugSteerWander.set(wander);

    // --- 6. LATERAL SWAY (Natural horizontal variation) --- phase-gated
    // Adds gentle sideways drift so motion isn't synchronized or strictly forward.
    float sway = (noise(g.noiseOffset + 2000, t * 0.15) - 0.5) * 2.0;
    PVector perp = new PVector(-forward.y, forward.x);
    PVector swayVec = PVector.mult(perp, sway * 0.35 * glideSteerScale * steerPhaseGate);
    desired.add(swayVec);
    g.debugSteerSway.set(swayVec);

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
      return new PVector(0, 0);
    }
    
    Segmento targetHead = target.segmentos.get(0);
    PVector toTarget = new PVector(targetHead.x - cabeza.x, targetHead.y - cabeza.y);
    if (toTarget.magSq() < 0.0001) return new PVector(0, 0);
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
      return PVector.mult(toTarget, 0.3);
    }
    
    // After pause: sudden acceleration burst
    if (!g.aggroPounceReady) {
      g.aggroPounceReady = true;
      // Add extra impulse on first pounce frame, aligned to heading
      PVector heading = new PVector(cos(g.headAngle), sin(g.headAngle));
      float align = max(0.0, PVector.dot(heading, toTarget));
      g.vel.add(PVector.mult(heading, 2.5 * align));
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
    
    return PVector.mult(toTarget, chaseMagnitude);
  }

  Gusano resolveAggroTarget(Segmento cabeza) {
    float maxDist = 180;
    float maxDistSq = maxDist * maxDist;
    float fovCos = cos(radians(60));
    PVector forward = new PVector(cos(g.headAngle), sin(g.headAngle));

    if (g.aggroTargetId >= 0) {
      Gusano current = findGusanoById(g.aggroTargetId);
      if (current != null && isAggroTargetValid(cabeza, current, maxDistSq, fovCos, forward)) {
        g.aggroLastSeenMs = millis();
        return current;
      }
    }

    Gusano best = null;
    float bestD2 = 1e9;
    ArrayList<Gusano> neighbors = queryNeighbors(cabeza.x, cabeza.y);
    for (Gusano other : neighbors) {
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
}
