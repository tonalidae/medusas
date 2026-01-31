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
      float steerPhaseGate = lerp(0.35, 1.0, contractCurve);

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
    // Adaptive sensing: faster -> shorter range to reduce over-reactive clustering
    float speedScale = constrain(g.vel.mag() / max(1.0, g.maxSpeed), 0, 1);
    neighborSenseRadius = lerp(180, 110, speedScale);
    float sepRadius = 55;
    
    // === BIOLOGICAL CONSTRAINT: Pulsed Steering ===
    // Jellyfish primarily steer during propulsion phase, not while coasting.
    // Calculate phase gate early so all steering forces can use it.
    float contractCurve = g.pulseContractCurve(g.pulsePhase);
    float steerPhaseGate = lerp(0.35, 1.0, contractCurve); // Minimal steering during coast
    // Extra drag in heavy water: timid states hesitate more
    if (g.state == Gusano.FEAR || g.state == Gusano.SHY) {
      steerPhaseGate *= 0.65; // damp steering strength so turns feel sluggish
    }
    
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

      // Remember user presence for lingering curiosity
      if (mouseSpeed < 6) {
        g.lastUserSeenMs = millis();
        g.userInterest = 1.0;
      }
      float affinity = g.userAffinity;
      float fearMem = g.fearMemory * exp(-(millis() - g.lastFearUserMs) / FEAR_MEMORY_MS);
      float globalFear = fearIntensity; // average swarm fear (0..1)
      float effectiveFear = max(fearMem, globalFear * 0.8);

      // Fear gets partial phase bypass (survival)
      float fearPhaseGate = (g.state == Gusano.FEAR) ? lerp(0.6, 1.0, contractCurve) : steerPhaseGate;
      
      if (g.state == Gusano.FEAR || effectiveFear > 0.05 || (mousePressed && dMouse < 100)) {
        float fleeScale = 6.0 * fearPhaseGate;
        if (effectiveFear > 0.05) fleeScale *= lerp(1.0, FEAR_AVOID_BOOST, effectiveFear);
        fleeScale *= (1.0 + globalFear * 1.5); // swarm-wide fear -> stronger avoidance
        boolean userChasing = (dMouse < 260 && mouseSpeed > 6) || (handPresent && mouseSpeed > 4);
        if (g.state == Gusano.FEAR && userChasing) {
          fleeScale *= 1.4;
          PVector dodge = new PVector(-toMouse.y, toMouse.x);
          float dodgeScale = (1.0 + globalFear) * 0.35;
          desired.add(PVector.mult(dodge, dodgeScale)); // sideways drift to evade
        }
        if (affinity < -0.1) fleeScale *= (1.1 + -affinity * 0.5); // resentful flees more
        PVector m = PVector.mult(toMouse, -fleeScale);
        desired.add(m); // Flee from predator
        g.debugSteerMouse.set(m);
        g.adjustAffinity(-0.0015); // being scared nudges resentment
      } else {
        float mem = g.userInterest * exp(-(millis() - g.lastUserSeenMs) / CURIOUS_STICK_MS);
        if ((g.state == Gusano.CURIOUS || mem > 0.1) && mouseSpeed < 6) {
          // Gentle approach plus sideways orbit so it feels exploratory
          float friendlyBoost = (affinity > 0) ? (1.0 + affinity * 0.6) : (1.0 + affinity * 0.2);
          float fearDampen = 1.0 - min(0.8, globalFear * 0.8); // reduce attraction when swarm is scared
          float attract = (CURIOUS_ATTRACT + 0.6 * mem) * steerPhaseGate * friendlyBoost * fearDampen;
          PVector orbit = new PVector(-toMouse.y, toMouse.x).mult(CURIOUS_ORBIT * mem);
          PVector m = PVector.mult(toMouse, attract).add(orbit);
          // Friendly "dance" around the user to avoid static hovering
          if (affinity > USER_DANCE_AFFINITY_THR || mem > USER_DANCE_MEM_THR) {
            g.maybeUpdateDanceRandomness(true);
            float danceGate = lerp(USER_DANCE_PHASE_MIN, 1.0, contractCurve);
            float danceRadius = USER_DANCE_RADIUS * g.danceRadiusScale;
            float danceWeight = constrain(map(dMouse, danceRadius * 0.6, danceRadius * 2.0, 1.0, 0.0), 0, 1);
            float radial = (dMouse - danceRadius) / max(1.0, danceRadius);
            PVector radialVec = PVector.mult(toMouse, radial * USER_DANCE_ATTRACT);
            float spin = (g.id % 2 == 0) ? 1.0 : -1.0;
            PVector tangent = new PVector(-toMouse.y, toMouse.x);
            tangent.rotate(g.danceAxisAngle);
            tangent.mult(USER_DANCE_ORBIT * g.danceOrbitScale * spin);
            PVector danceOrbit = PVector.add(radialVec, tangent);
            float danceImpulse = USER_DANCE_IMPULSE * g.danceImpulseScale;
            danceOrbit.mult(danceGate * danceWeight * (1.0 - USER_DANCE_FIG8_BLEND) * danceImpulse);
            float phase = t * TWO_PI * USER_DANCE_FIG8_FREQ + g.noiseOffset * 0.6;
            phase *= spin;
            PVector danceFig8 = fig8Steer(cabeza.x, cabeza.y, mouseX, mouseY,
                                          danceRadius, phase, USER_DANCE_FIG8_Y_SCALE,
                                          danceGate * danceWeight * USER_DANCE_FIG8_BLEND * danceImpulse,
                                          g.danceAxisAngle);
            m.add(danceOrbit);
            m.add(danceFig8);
          }
          desired.add(m);
          g.debugSteerMouse.set(m);
          g.adjustAffinity(0.0015); // calm proximity builds friendliness
        }
      }
    }

    // --- 3. NEIGHBOR FILTERING (FOV & Attention) ---
    // Prevents network instability by limiting focus to immediate vicinity
    ArrayList<Gusano> neighbors = queryNeighbors(cabeza.x, cabeza.y);
    // Pair-buddy selection
    if (g.buddyId < 0 || millis() - g.buddyLockMs > BUDDY_DURATION_MS) {
      if (g.social > BUDDY_SOCIAL_THR && random(1) < BUDDY_PICK_CHANCE && neighbors.size() > 1) {
        Gusano pick = null;
        float best = 1e9;
        for (Gusano other : neighbors) {
          if (other == g) continue;
          float d2 = sq(other.segmentos.get(0).x - cabeza.x) + sq(other.segmentos.get(0).y - cabeza.y);
          if (d2 < best) {
            best = d2;
            pick = other;
          }
        }
        if (pick != null) {
          g.buddyId = pick.id;
          g.buddyLockMs = millis();
        }
      }
    }
    int processed = 0;
    float fleeRadius = 220;
    float fleeRadiusSq = fleeRadius * fleeRadius;
    Gusano nearestDominant = null;
    float bestDominantD2 = 1e9;
    
    PVector sep = new PVector(0, 0);
    PVector coh = new PVector(0, 0);
    Gusano buddy = (g.buddyId >= 0) ? findGusanoById(g.buddyId) : null;
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
        float cohW = 0.4;
        if (buddy != null && other == buddy) {
          cohW = BUDDY_COH_WEIGHT;
          processed = attentionBudget; // focus
        }
        PVector toward = PVector.mult(toOther, cohW * steerPhaseGate);
        coh.add(toward);
        processed++; 
      }
    }
    desired.add(sep);
    desired.add(coh);
    g.debugSteerSep.set(sep);
    g.debugSteerCoh.set(coh);
    g.debugSteerNeighbors.set(sep.x + coh.x, sep.y + coh.y);

    // --- Buddy dance: orbit and approach to keep pairs moving together ---
    if (buddy != null) {
      Segmento bHead = buddy.segmentos.get(0);
      if (bHead != null) {
        PVector toBuddy = new PVector(bHead.x - cabeza.x, bHead.y - cabeza.y);
        float dBuddy = toBuddy.mag();
        if (dBuddy > 0.0001) {
          toBuddy.normalize();
          float danceGate = lerp(BUDDY_DANCE_PHASE_MIN, 1.0, contractCurve);
          g.maybeUpdateDanceRandomness(true);
          float danceRadius = BUDDY_DANCE_RADIUS * g.danceRadiusScale;
          float danceWeight = constrain(map(dBuddy, danceRadius * 0.6, danceRadius * 2.2, 1.0, 0.0), 0, 1);
          float radial = (dBuddy - danceRadius) / max(1.0, danceRadius);
          PVector radialVec = PVector.mult(toBuddy, radial * BUDDY_DANCE_ATTRACT);
          float spin = (g.id % 2 == 0) ? 1.0 : -1.0;
          PVector tangent = new PVector(-toBuddy.y, toBuddy.x);
          tangent.rotate(g.danceAxisAngle);
          tangent.mult(BUDDY_DANCE_ORBIT * g.danceOrbitScale * spin);
          PVector danceOrbit = PVector.add(radialVec, tangent);
          float danceImpulse = BUDDY_DANCE_IMPULSE * g.danceImpulseScale;
          danceOrbit.mult(danceGate * danceWeight * (1.0 - BUDDY_DANCE_FIG8_BLEND) * danceImpulse * BUDDY_LOOP_LEGACY_BLEND);
          float phase = t * TWO_PI * BUDDY_DANCE_FIG8_FREQ + g.noiseOffset * 0.8;
          phase *= spin;
          PVector danceFig8 = fig8Steer(cabeza.x, cabeza.y, bHead.x, bHead.y,
                                        danceRadius, phase, BUDDY_DANCE_FIG8_Y_SCALE,
                                        danceGate * danceWeight * BUDDY_DANCE_FIG8_BLEND * danceImpulse * BUDDY_LOOP_LEGACY_BLEND,
                                        g.danceAxisAngle);
          desired.add(danceOrbit);
          desired.add(danceFig8);
        }
      }
      PVector buddyLoop = computeBuddyLoopSteer(cabeza, g, buddy, contractCurve, steerPhaseGate);
      desired.add(buddyLoop);
      g.debugSteerBuddyLoop.set(buddyLoop);
    }

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
    if (g.state == Gusano.FEAR || g.state == Gusano.SHY) {
      wallPhaseGate *= 0.7; // more hesitation near walls when scared/shy
    }
    PVector wallForce = new PVector(0, 0);
    if (cabeza.x < wallMarginX) wallForce.x += sq(1.0 - cabeza.x / wallMarginX);
    if (cabeza.x > width - wallMarginX) wallForce.x -= sq(1.0 - (width - cabeza.x) / wallMarginX);
    if (cabeza.y < wallMarginTop) wallForce.y += sq(1.0 - cabeza.y / wallMarginTop);
    if (cabeza.y > height - wallMarginBottom) wallForce.y -= sq(1.0 - (height - cabeza.y) / wallMarginBottom);

    // Gently turn away from walls instead of jittering against clamps
    float wallMag = wallForce.mag();
    if (wallMag > 0.0001) {
      wallForce.normalize();
      float frusBoost = 1.0 + g.frustration * FRUSTRATION_WALL_PUSH;
      PVector w = PVector.mult(wallForce, avoidW * 3.5 * wallPhaseGate * frusBoost);
      desired.add(w);
      g.debugSteerWall.set(w);
      // Reduce wander near walls so turn is decisive
      wanderW *= 0.6;
    }

    float glide01 = 1.0 - contractCurve;
    float glideSteerScale = lerp(1.0, GLIDE_STEER_SCALE, glide01);
    g.debugWanderScale = glideSteerScale;

    // --- 4b. ROAMING PATH (koi-like loops when idle) ---
    if (useRoamingPaths && g.state != Gusano.AGGRESSIVE) {
      PVector roam = g.computeRoamSteer(cabeza, glideSteerScale, steerPhaseGate);
      desired.add(roam);
      g.debugSteerRoam.set(roam);
      // When following a path, ease off random wander so arcs stay smooth
      if (roam.magSq() > 0.0004) {
        wanderW *= 0.65;
      }
    }

    PVector spread = computeSpreadSteer(cabeza, g);
    desired.add(spread);
    g.debugSteerSpread.set(spread);

    PVector biome = computeBiomeSteer(cabeza, g, steerPhaseGate);
    desired.add(biome);
    g.debugSteerBiome.set(biome);

    // --- 5. WANDER (Organic Drift) --- phase-gated via glideSteerScale + steerPhaseGate
    PVector exploreBias = computeExplorationSteer(cabeza, g);
    desired.add(exploreBias);
    g.debugSteerExplore.set(exploreBias);

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

    // Frustration turn bias: encourage turning away from last clamp direction by adding noise-perp
    if (g.frustration > 0.1) {
      float bias = g.frustration * FRUSTRATION_TURN_BOOST;
      PVector biasVec = new PVector(-forward.y, forward.x).mult(bias * steerPhaseGate);
      desired.add(biasVec);
    }

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
    g.debugSteerExplore.set(0, 0);
    g.debugSteerAggro.set(0, 0);
    g.debugSteerRoam.set(0, 0);
    g.debugSteerSpread.set(0, 0);
    g.debugSteerBiome.set(0, 0);
    g.debugSteerBuddyLoop.set(0, 0);
  }

  PVector fig8Offset(float radius, float phase, float yScale, float axisAngle) {
    float ox = cos(phase) * radius;
    float oy = sin(phase) * cos(phase) * radius * yScale;
    float cosA = cos(axisAngle);
    float sinA = sin(axisAngle);
    float rx = ox * cosA - oy * sinA;
    float ry = ox * sinA + oy * cosA;
    return new PVector(rx, ry);
  }

  PVector fig8Steer(float headX, float headY, float centerX, float centerY,
                    float radius, float phase, float yScale, float weight, float axisAngle) {
    PVector offset = fig8Offset(radius, phase, yScale, axisAngle);
    float tx = centerX + offset.x;
    float ty = centerY + offset.y;
    PVector toTarget = new PVector(tx - headX, ty - headY);
    float d = toTarget.mag();
    if (d < 0.0001) return new PVector(0, 0);
    toTarget.normalize();
    float falloff = constrain(map(d, radius * 0.4, radius * 2.5, 1.0, 0.0), 0, 1);
    toTarget.mult(weight * falloff);
    return toTarget;
  }

  PVector computeBuddyLoopSteer(Segmento cabeza, Gusano g, Gusano buddy, float contractCurve, float steerPhaseGate) {
    if (buddy == null) return new PVector(0, 0);
    Segmento bHead = buddy.segmentos.get(0);
    if (bHead == null) return new PVector(0, 0);
    float centerX = (cabeza.x + bHead.x) * 0.5;
    float centerY = (cabeza.y + bHead.y) * 0.5;
    float radiusScale = (g.danceRadiusScale + buddy.danceRadiusScale) * 0.5;
    float radius = BUDDY_LOOP_RADIUS * radiusScale;
    if (radius <= 0) return new PVector(0, 0);
    float basePhase = t * TWO_PI * BUDDY_LOOP_FREQ + g.noiseOffset * BUDDY_LOOP_NOISE_FREQ;
    float phaseOffset = (g.id % 2 == 0) ? 0 : PI;
    float phase = basePhase + phaseOffset;
    float axis = (g.danceAxisAngle + buddy.danceAxisAngle) * 0.5;
    PVector offset = fig8Offset(radius, phase, BUDDY_LOOP_Y_SCALE, axis);
    float tx = centerX + offset.x;
    float ty = centerY + offset.y;
    PVector toTarget = new PVector(tx - cabeza.x, ty - cabeza.y);
    float dist = toTarget.mag();
    if (dist < 0.0001) return new PVector(0, 0);
    toTarget.normalize();
    float falloff = constrain(map(dist, radius * 0.2, radius * 1.8, 0.6, 1.0), 0.35, 1.0);
    float strength = BUDDY_LOOP_STRENGTH * falloff * steerPhaseGate * lerp(0.65, 1.0, contractCurve);
    toTarget.mult(strength);
    return toTarget;
  }

  PVector computeExplorationSteer(Segmento cabeza, Gusano g) {
    int cx = floor(cabeza.x / gridCellSize);
    int cy = floor(cabeza.y / gridCellSize);
    long homeKey = cellKey(cx, cy);
    int homeCount = 0;
    ArrayList<Gusano> homeBucket = spatialGrid.get(homeKey);
    if (homeBucket != null) {
      homeCount = max(0, homeBucket.size() - 1);
    }

    float bestCount = 1e6;
    PVector bestCenter = null;
    for (int oy = -1; oy <= 1; oy++) {
      for (int ox = -1; ox <= 1; ox++) {
        long key = cellKey(cx + ox, cy + oy);
        ArrayList<Gusano> bucket = spatialGrid.get(key);
        int count = (bucket == null) ? 0 : bucket.size();
        if (bucket != null && bucket.contains(g)) count = max(0, count - 1);
        if (bestCenter == null || count < bestCount) {
          bestCount = count;
          float tx = (cx + ox + 0.5) * gridCellSize;
          float ty = (cy + oy + 0.5) * gridCellSize;
          tx = constrain(tx, clampMarginX, width - clampMarginX);
          ty = constrain(ty, clampMarginTop, height - clampMarginBottom);
          bestCenter = new PVector(tx, ty);
        }
      }
    }

    if (bestCenter == null) return new PVector(0, 0);
    PVector toTarget = new PVector(bestCenter.x - cabeza.x, bestCenter.y - cabeza.y);
    float distSq = toTarget.magSq();
    if (distSq < 1e-4) return new PVector(0, 0);

    float emptiness = max(0.1, 1.0 - min(bestCount, EXPLORATION_OCCUPANCY_SCALE) / EXPLORATION_OCCUPANCY_SCALE);
    float crowd = min(1.0, homeCount / EXPLORATION_OCCUPANCY_SCALE);
    float intensity = EXPLORATION_WEIGHT * (0.35 + crowd * 0.65) * emptiness;

    toTarget.normalize();
    toTarget.mult(intensity);
    return toTarget;
  }

  PVector computeSpreadSteer(Segmento cabeza, Gusano g) {
    float dx = cabeza.x - swarmCentroidX;
    float dy = cabeza.y - swarmCentroidY;
    float dist = sqrt(dx * dx + dy * dy);
    float radius = max(1.0, SWARM_SPREAD_RADIUS);
    if (dist > radius || radius <= 0) return new PVector(0, 0);
    float strength = (1.0 - dist / radius) * SWARM_SPREAD_STRENGTH;
    PVector out = new PVector(dx, dy);
    if (dist > 0.0001) out.normalize();
    out.mult(strength);
    return out;
  }

  PVector computeBiomeSteer(Segmento cabeza, Gusano g, float steerPhaseGate) {
    if (g.biomeTarget == null) return new PVector(0, 0);
    PVector toTarget = new PVector(g.biomeTarget.x - cabeza.x, g.biomeTarget.y - cabeza.y);
    float d = toTarget.mag();
    if (d < 1e-4) return new PVector(0, 0);
    toTarget.normalize();
    float fearDampen = (g.state == Gusano.FEAR) ? BIOME_AVOID_FEAR_SCALE : 1.0;
    float w = BIOME_STEER_WEIGHT * steerPhaseGate * fearDampen;
    toTarget.mult(w);
    return toTarget;
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
