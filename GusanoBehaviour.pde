// ============================================================
// GusanoBehaviour.pde
// 
// AI & MOVEMENT SYSTEM
// Handles target selection, pulse swimming, social forces, and user interaction
// 
// BEHAVIOR ARCHITECTURE:
// 1. TARGET WANDERING: Biased random walk with brownian micro-jitter
//    - objetivoX/Y: Current waypoint in world space
//    - frecuenciaCambio: How often to pick new targets (personality-driven)
//    - Brownian jitter: 3% chance per frame of small random nudge (organic unpredictability)
//
// 2. PULSE SWIMMING: Jellyfish thrust in pulses, not continuously
//    - arousal: 0=calm, 1=excited (affects pulse frequency & amplitude)
//    - phase: Sine wave oscillator for thrust timing
//    - Inspired by real jellyfish bell contractions
//
// 3. USER INTERACTION: Mouse position affects target bias
//    - userAttitude: -1=scared, 0=neutral, +1=curious
//    - userMode: Blend between social-dominant (0) and user-dominant (1)
//    - Hysteresis: Prevents rapid mode switching
//
// 4. SOCIAL FORCES: Boid-style flocking (separation, alignment, cohesion)
//    - Separation: Avoid crowding (personal space)
//    - Alignment: Match neighbors' direction
//    - Cohesion: Steer toward group center
//    - Spatial grid enables O(N) queries instead of O(N²)
//
// 5. STRESS & LIFE: Social crowding and user harassment reduce health
//    - vida: Current health (0 = death/respawn)
//    - stressSocial: Accumulates when personal space violated
//    - Dying jellyfish lose segments and shrink
//
// EXECUTION FLOW (each frame):
//   1. Update spawn ease-in (prevents spawn bloom)
//   2. Check if target reached or timer expired → nuevoObjetivo()
//   3. Apply brownian jitter to target (if triggered)
//   4. Sample fluid velocity/height at head (cached for rendering)
//   5. Apply user interaction bias (toward/away from mouse)
//   6. Pulse swimming thrust (arousal-modulated)
//   7. Calculate social forces (spatial grid query)
//   8. Blend user force vs social force (based on userMode)
//   9. Move head toward final target
//   10. Update stress and life
// ============================================================

class GusanoBehavior {
  Gusano g;
  GusanoBehavior(Gusano g_) { g = g_; }

  // Hysteresis for mode switching - prevents rapid flip-flopping
  float modeHysteresis = 0.15;  // buffer zone around threshold
  boolean wasInUserMode = false; // track previous state
  
  // Reusable PVector objects to avoid allocation every frame (performance)
  PVector sep = new PVector(0, 0);
  PVector ali = new PVector(0, 0);
  PVector coh = new PVector(0, 0);
  PVector social = new PVector(0, 0);

  void actualizar() {
    // ===== TEST MODE: All behavior disabled for shape verification =====
    /*
    // ------------------------------------------------------------
    // Rest/Active Cycle Management
    // ------------------------------------------------------------
    // Check if it's time to switch states
    if (frameCount >= g.nextCycleChangeFrame) {
      g.scheduleNextCycle();
    }
    
    // Calculate rest multiplier (smooth transitions)
    float cycleProgress = float(frameCount - g.restCycleStart) / float(g.restCycleDuration);
    float restMul = 1.0;
    if (g.isResting) {
      // Ease into rest at start, ease out at end
      float easeWindow = 0.15; // 15% of cycle for easing
      if (cycleProgress < easeWindow) {
        float t = cycleProgress / easeWindow;
        restMul = lerp(1.0, g.restMovementMul, t);
      } else if (cycleProgress > (1.0 - easeWindow)) {
        float t = (cycleProgress - (1.0 - easeWindow)) / easeWindow;
        restMul = lerp(g.restMovementMul, 1.0, t);
      } else {
        restMul = g.restMovementMul;
      }
    }
    
    // --- Spawn easing: reduce harsh initial motion after spawn/respawn ---
    // 0..1 ramp over first ~60 frames
    float spawnEase = constrain(g.ageFrames / 60.0, 0, 1);
    spawnEase = spawnEase * spawnEase * (3.0 - 2.0 * spawnEase); // smoothstep
    g.spawnEaseNow = spawnEase;

    g.cambioObjetivo++;
    Segmento cabeza = g.segmentos.get(0);

    // ------------------------------------------------------------
    // Exit steer (global)
    // ------------------------------------------------------------
    if (exitArmed) {
      float dL = cabeza.x;
      float dR = width - cabeza.x;
      float dT = cabeza.y;
      float dB = height - cabeza.y;

      if (dL < dR && dL < dT && dL < dB) {
        g.objetivoX = -300;
        g.objetivoY = cabeza.y;
      } else if (dR < dT && dR < dB) {
        g.objetivoX = width + 300;
        g.objetivoY = cabeza.y;
      } else if (dT < dB) {
        g.objetivoX = cabeza.x;
        g.objetivoY = -300;
      } else {
        g.objetivoX = cabeza.x;
        g.objetivoY = height + 300;
      }

      // Small push in the goal direction
      float dx = g.objetivoX - cabeza.x;
      float dy = g.objetivoY - cabeza.y;
      float m = sqrt(dx*dx + dy*dy);
      if (m > 1e-6) {
        dx /= m;
        dy /= m;
        cabeza.x += dx * 1.2;
        cabeza.y += dy * 1.2;
      }
    }

    // ------------------------------------------------------------
    // USER STIMULUS
    // ------------------------------------------------------------
    float mouseV = dist(mouseX, mouseY, pmouseX, pmouseY);
    float dMouse = dist(cabeza.x, cabeza.y, mouseX, mouseY);
    float userNear = 1.0 - constrain(dMouse / 200.0, 0, 1);
    userNear = g.smoothstep(userNear);

    float userMove = constrain(mouseV / 30.0, 0, 1);
    float S_user = userNear * userMove;
    if (mousePressed) S_user = max(S_user, userNear * 0.85);
    g.S_userNow = S_user;

    // ------------------------------------------------------------
    // USER ATTITUDE UPDATE (curious <-> fearful)
    // NEW: Gradual attitude shifts based on interaction style
    // ------------------------------------------------------------
    // Gentle sustained presence → curious
    // Sudden intense bursts → fearful
    float gentleScore = userNear * (1.0 - userMove) * 0.5;
    float intenseScore = userMove * userMove * userNear;
    
    float attitudePull = gentleScore - intenseScore * 1.5;
    g.userAttTarget += attitudePull * 0.015;
    
    // Random drift (smaller now that we have intentional pulling)
    g.userAttTarget = constrain(g.userAttTarget + random(-1, 1) * 0.002, -1, 1);
    
    // Smooth follow (replaces instant flips) - slower for gradual transitions
    g.userAttitude += (g.userAttTarget - g.userAttitude) * 0.018; // was 0.04
    g.userAttitude = constrain(g.userAttitude, -1, 1);

    // Social stimulus is computed later
    float S_social = 0;

    // ------------------------------------------------------------
    // Target switching modulation
    // ------------------------------------------------------------
    float distanciaAlObjetivo = dist(cabeza.x, cabeza.y, g.objetivoX, g.objetivoY);

    float calm = (1.0 - g.arousal) * (1.0 - 0.7 * g.userMode);
    g.frecuenciaCambio = lerp(90, 160, calm);
    g.frecuenciaCambio = lerp(220, g.frecuenciaCambio, spawnEase);

    if (g.cambioObjetivo > g.frecuenciaCambio || distanciaAlObjetivo < 20) {
      g.nuevoObjetivo();
      g.cambioObjetivo = 0;
    }
    
    // Brownian micro-jitter: subtle random nudges for organic unpredictability
    // (inspired by original simple code's target adjustments)
    // Personality affects jitter intensity: nervous jellyfish wander more
    float jitterChance = 0.03;  // 3% chance per frame
    if (random(1) < jitterChance) {
      // Use wanderMul (0.5-1.8) as proxy for wander intensity
      float jitterRange = map(g.wanderMul, 0.5, 1.8, 15, 45);
      g.objetivoX += random(-jitterRange, jitterRange);
      g.objetivoY += random(-jitterRange, jitterRange);
      g.objetivoX = constrain(g.objetivoX, boundsInset, width - boundsInset);
      g.objetivoY = constrain(g.objetivoY, boundsInset, height - boundsInset);
    }

    // ------------------------------------------------------------
    // Head fluid sample (cached)
    // ------------------------------------------------------------
    PVector velocidadFluido = fluido.obtenerVelocidad(cabeza.x, cabeza.y);
    float alturaFluido = fluido.obtenerAltura(cabeza.x, cabeza.y);
    g.cacheVx[0] = velocidadFluido.x;
    g.cacheVy[0] = velocidadFluido.y;
    g.cacheH[0]  = alturaFluido;

    float objetivoConFluidoX = g.objetivoX + velocidadFluido.x * 8;
    float objetivoConFluidoY = g.objetivoY + velocidadFluido.y * 8;
    objetivoConFluidoY -= alturaFluido * 0.3;

    // ------------------------------------------------------------
    // User-target bias: mouse steers the *target* toward/away
    // ------------------------------------------------------------
    float att = g.userAttitude;
    float attMag = abs(att);
    float attSign = (att >= 0) ? 1.0 : -1.0;

    float md = max(1e-6, dMouse);
    float dmX = (mouseX - cabeza.x) / md;
    float dmY = (mouseY - cabeza.y) / md;

    float steerGate = userNear;
    float steerA = 0.35 + 0.65 * g.arousal;
    float steerM = 0.45 + 0.55 * g.userMode;

    float userPush = g.userPushBase * attMag * steerGate * steerA * steerM * spawnEase;

    objetivoConFluidoX += dmX * userPush * attSign;
    objetivoConFluidoY += dmY * userPush * attSign;

    // Ease the effective target during first frames
    float tgtX = lerp(cabeza.x, objetivoConFluidoX, spawnEase);
    float tgtY = lerp(cabeza.y, objetivoConFluidoY, spawnEase);
    cabeza.seguir(tgtX, tgtY + velocidad * g.speedMul * restMul); // Apply rest multiplier to movement

    // ------------------------------------------------------------
    // Pulse oscillator (continues during rest but with modified parameters)
    // ------------------------------------------------------------
    float modeBoost = lerp(0.90, 1.15, g.userMode);  // Reduced range for steadier rhythm
    
    // During rest: slower, calmer pulse (animation continues)
    float arousalMod = g.isResting ? g.arousal * 0.35 : g.arousal; // Reduce arousal effect during rest
    float freq = g.baseFreq * lerp(0.90, 1.40, arousalMod) * modeBoost;
    if (g.isResting) freq *= 0.65; // Slower pulse frequency when resting
    
    g.phase += freq;
    if (g.phase > TWO_PI) g.phase -= TWO_PI;

    float raw = max(0, sin(g.phase));
    float pulse = pow(raw, g.pulseK);
    float relax = 1.0 - pulse;
    g.pulseNow = pulse;
    g.relaxNow = relax;

    // Burst push during contraction (reduced during rest)
    float burstMul = g.isResting ? 0.25 : 1.0; // Gentler bursts when resting
    float burst = pulse * g.pulseAmp * lerp(0.85, 1.25, g.arousal) * lerp(0.95, 1.20, g.userMode) * spawnEase * burstMul;
    cabeza.x += cos(cabeza.angulo) * burst;
    cabeza.y += sin(cabeza.angulo) * burst;

    // Tiny flee kick (fearful + high user stimulus)
    if (g.userAttitude < -0.15) {
      float danger = constrain(0.5 * (S_user + g.userMode), 0, 1);
      if (danger > 0.55) {
        float awayX = (cabeza.x - mouseX);
        float awayY = (cabeza.y - mouseY);
        float am = sqrt(awayX*awayX + awayY*awayY);
        if (am > 1e-6) {
          awayX /= am;
          awayY /= am;
          float kick = g.fleeKick * danger * (-g.userAttitude) * (0.35 + 0.65 * g.arousal) * spawnEase;
          cabeza.x += awayX * kick;
          cabeza.y += awayY * kick;
        }
      }
    }

    // ------------------------------------------------------------
    // Head fluid drag + wake injection
    // ------------------------------------------------------------
    {
      PVector vF = velocidadFluido;
      float drag = 0.03 + 0.12 * (1.0 - pulse) + 0.05 * (1.0 - g.arousal) - 0.05 * g.userMode;

      float mvx = cabeza.x - cabeza.prevX;
      float mvy = cabeza.y - cabeza.prevY;

      mvx = lerp(mvx, vF.x, drag);
      mvy = lerp(mvy, vF.y, drag);

      float sp = sqrt(mvx*mvx + mvy*mvy);
      float slow = 1.0 - 0.02 * constrain(sp / 6.0, 0, 1);
      mvx *= slow;
      mvy *= slow;

      cabeza.x = cabeza.prevX + mvx;
      cabeza.y = cabeza.prevY + mvy;

      // Grace period: skip head wake for first 45 frames after spawn
      int framesSinceSpawn = frameCount - g.spawnFrame;
      if (sp > 0.15 && framesSinceSpawn > 45) {
        float radio = 18;
        float fuerza = constrain(sp * 1.8 * (1.0 + 0.8 * pulse + 0.6 * g.arousal) * lerp(1.0, 1.30, g.userMode) * spawnEase, 0, 7.2);
        fluido.perturbarDir(cabeza.x, cabeza.y, radio, mvx, mvy, fuerza);
      }
    }

    cabeza.actualizar();

    // Small wander drift
    if (random(1) < 0.03) {
      g.objetivoX += random(-30, 30);
      g.objetivoY += random(-30, 30);
      g.objetivoX = constrain(g.objetivoX, boundsInset, width - boundsInset);
      g.objetivoY = constrain(g.objetivoY, boundsInset, height - boundsInset);
    }

    // ------------------------------------------------------------
    // SOCIAL FORCES + AROUSAL + MODE SWITCHING + LIFE CYCLE
    // (computes the social steering vector applied to the head)
    // ------------------------------------------------------------
    
    // Initialize social force accumulators
    PVector sep = new PVector(0, 0);
    PVector ali = new PVector(0, 0);
    PVector coh = new PVector(0, 0);
    int nSoc = 0;
    int nAli = 0;
    int nCoh = 0;
    float stress = 0;
    boolean doCohesion = true;
    
    // Cache my velocity
    float myVx = cabeza.x - cabeza.prevX;
    float myVy = cabeza.y - cabeza.prevY;
    
    if (g.socialMul > 0.01) {
      // Get nearby neighbors using spatial grid (O(N) instead of O(N²))
      ArrayList<Gusano> candidates = spatialGrid.getNeighbors(g, g.rangoSocial);
      
      for (Gusano otro : candidates) {
        if (otro == g) continue;
        if (otro.segmentos == null || otro.segmentos.size() == 0) continue;

        Segmento cabezaOtro = otro.segmentos.get(0);

        float dx = cabezaOtro.x - cabeza.x;
        float dy = cabezaOtro.y - cabeza.y;
        float d2 = dx*dx + dy*dy;
        if (d2 < 1e-6) continue;
        float d = sqrt(d2);

        if (d < g.rangoRepulsion) {
          float w = (g.rangoRepulsion - d) / g.rangoRepulsion;
          w = pow(w, 1.8);  // Steeper falloff (inspired by mag(k,e)**4/5 in parametric code)
          sep.x -= (dx / d) * (w * 1.8);
          sep.y -= (dy / d) * (w * 1.8);
          stress += w;
        }

        if (d < g.rangoSocial) {
          nSoc++;
          float ovx = cabezaOtro.x - cabezaOtro.prevX;
          float ovy = cabezaOtro.y - cabezaOtro.prevY;
          float om = sqrt(ovx*ovx + ovy*ovy);
          if (om > 1e-6) {
            ali.x += ovx / om;
            ali.y += ovy / om;
            nAli++;
          }

          if (doCohesion) {
            coh.x += cabezaOtro.x;
            coh.y += cabezaOtro.y;
            nCoh++;
          }
        }
      }
    }
    
    // Update stress tracking
    g.stress = stress;

    float crowd = constrain(nSoc / 4.0, 0, 1);
    S_social = constrain(0.55 * constrain(stress, 0, 1) + 0.45 * crowd, 0, 1);
    g.S_socialNow = S_social;

    float targetArousal = constrain(S_user * g.wUser + S_social * g.wSocial, 0, 1);
    g.arousal += (targetArousal - g.arousal) * g.arousalAttack;
    g.arousal *= g.arousalDecay;
    g.arousal = constrain(g.arousal, 0, 1);

    // Mode dominance with hysteresis
    float dom = (S_user - S_social * g.domK) / g.domSoft;

    // Apply hysteresis: different thresholds depending on current mode
    float threshold = wasInUserMode ? (0.5 - modeHysteresis) : (0.5 + modeHysteresis);
    float domValue = 0.5 + 0.5 * constrain(dom, -1, 1);
    float userTarget = (domValue > threshold) ? 1.0 : 0.0;

    // Update tracking
    wasInUserMode = (userTarget > 0.5);

    // Smoother follow rate
    g.userMode += (userTarget - g.userMode) * g.modeFollow;
    g.userMode = constrain(g.userMode, 0, 1);

    // Phase sync (only meaningful when social-dominant)
    float syncGate = (1.0 - g.userMode) * S_social;
    if (syncGate > 1e-4) {
      float sumC = 0;
      float sumS = 0;
      int nPh = 0;

      for (Gusano otro : gusanos) {
        if (otro == g) continue;
        Segmento h2 = otro.segmentos.get(0);
        float dd = dist(cabeza.x, cabeza.y, h2.x, h2.y);
        if (dd < g.rangoSocial) {
          float w = 1.0 - (dd / g.rangoSocial);
          w = w * w;
          sumC += cos(otro.phase) * w;
          sumS += sin(otro.phase) * w;
          nPh++;
        }
      }

      if (nPh > 0 && (sumC*sumC + sumS*sumS) > 1e-8) {
        float mean = atan2(sumS, sumC);
        float dphi = atan2(sin(mean - g.phase), cos(mean - g.phase));

        float k = g.syncStrength * syncGate;
        float step = constrain(dphi * k, -g.syncMaxStep, g.syncMaxStep);
        g.phase += step;

        if (g.phase < 0) g.phase += TWO_PI;
        else if (g.phase >= TWO_PI) g.phase -= TWO_PI;
      }
    }

    social.set(0, 0);

    float wSep = 1.35 * lerp(1.18, 0.92, relax) * lerp(1.00, 1.18, g.userMode);
    float wAli = 0.55 * lerp(0.85, 1.35, relax) * lerp(1.25, 0.62, g.userMode);
    float wCoh = 0.30 * lerp(0.80, 1.75, relax) * lerp(1.40, 0.55, g.userMode);

    social.add(sep.x * wSep, sep.y * wSep);

    if (nAli > 0) {
      ali.x /= nAli;
      ali.y /= nAli;

      float myM = sqrt(myVx*myVx + myVy*myVy);
      float myHx = (myM > 1e-6) ? (myVx / myM) : 0;
      float myHy = (myM > 1e-6) ? (myVy / myM) : 0;

      social.x += (ali.x - myHx) * wAli;
      social.y += (ali.y - myHy) * wAli;
    }

    if (doCohesion && nCoh > 0) {
      coh.x /= nCoh;
      coh.y /= nCoh;
      float toCx = coh.x - cabeza.x;
      float toCy = coh.y - cabeza.y;
      
      // Add subtle circular orbiting tendency (inspired by parametric code's orbital motion)
      float orbitPhase = g.phase * 0.5 + g.id * TWO_PI / numGusanos;
      float orbitRadius = 25 * g.socialMul;
      toCx += cos(orbitPhase) * orbitRadius * 0.15;  // gentle circular bias
      toCy += sin(orbitPhase) * orbitRadius * 0.15;
      
      float cm = sqrt(toCx*toCx + toCy*toCy);
      if (cm > 1e-6) {
        toCx /= cm;
        toCy /= cm;
        social.x += toCx * wCoh;
        social.y += toCy * wCoh;
      }
    }

    float sMag = sqrt(social.x*social.x + social.y*social.y);
    if (sMag > 1e-6) {
      float maxSocial = 1.2 + 0.4 * g.temperamento;
      if (sMag > maxSocial) {
        social.x = (social.x / sMag) * maxSocial;
        social.y = (social.y / sMag) * maxSocial;
      }
    }

    // Life drain
    g.vida -= 0.015;
    float gasto = (0.06 + 0.06 * max(0, -g.humor));
    g.vida -= stress * gasto;
    g.vida = constrain(g.vida, 0, g.vidaMax);

    if (g.estado == 0 && g.vida <= 0.001) {
      g.estado = 1;
      g.tickCambioCuerpo = 0;
    }

    if (g.estado == 1) {
      g.tickCambioCuerpo++;
      if (g.tickCambioCuerpo % 6 == 0) {
        g.segActivos = max(1, g.segActivos - 1);
      }
      if (g.segActivos <= 1) {
        g.renacer();
        g.estado = 2;
        g.tickCambioCuerpo = 0;
      }
    }

    if (g.estado == 2) {
      g.tickCambioCuerpo++;
      g.vida = min(g.vidaMax, g.vida + 0.22);
      if (g.tickCambioCuerpo % 5 == 0) {
        g.segActivos = min(numSegmentos, g.segActivos + 1);
      }
      if (g.segActivos >= numSegmentos && g.vida >= g.vidaMax * 0.98) {
        g.estado = 0;
        g.vida = g.vidaMax;
      }
    }

    // Apply social steering to the head (BODY will handle wall repulsion + segment updates)
    cabeza.x += social.x;
    cabeza.y += social.y;
    */
    
    // Keep essential spawn tracking for rendering
    g.ageFrames++;
    g.spawnEaseNow = 1.0;
    g.pulseNow = 0.0;
    g.relaxNow = 1.0;
    // ==================================================================
  }
}