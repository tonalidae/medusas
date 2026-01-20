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

  void actualizar() {
    // ============================================================
    // AUTOPOIETIC LIFE SYSTEM - Energy, Circadian, Population
    // ============================================================
    
    // --- Energy consumption (metabolism) ---
    // Base consumption varies with activity
    float movementCost = g.speedMul * g.metabolism * 0.012;
    float arousalCost = g.arousal * 0.008;  // excitement drains energy
    float sizeCost = g.shapeScale * 0.005;  // larger organisms need more energy
    g.energy -= (movementCost + arousalCost + sizeCost);
    
    // --- Circadian rhythm (natural activity cycles) ---
    g.circadianPhase += g.circadianFreq;
    if (g.circadianPhase > TWO_PI) g.circadianPhase -= TWO_PI;
    
    // Activity oscillates between 0.65 (rest) and 1.35 (active)
    g.activityLevel = 1.0 + sin(g.circadianPhase) * g.circadianAmp;
    
    // Circadian affects arousal baseline (less excitable during rest phase)
    float circadianMod = map(g.activityLevel, 0.65, 1.35, 0.7, 1.0);
    
    // --- Hunger calculation ---
    g.hunger = constrain(map(g.energy, 60, 20, 0, 1), 0, 1);
    
    // Low energy affects health
    if (g.energy < 20) {
      g.vida -= 0.15;  // starvation damage
    }
    
    // Clamp energy
    g.energy = constrain(g.energy, 0, g.energyMax);
    
    // --- Life Stage Update ---
    updateLifeStage(g);
    applyStageModifiers(g);
    
    // --- Spawn easing: smooth fade-in over 180 frames (~6 seconds) ---
    // Much longer, gentler fade for subtle appearance
    float spawnEase = constrain(g.ageFrames / 180.0, 0, 1);
    spawnEase = spawnEase * spawnEase * (3.0 - 2.0 * spawnEase); // smoothstep
    g.spawnEaseNow = spawnEase;

    g.cambioObjetivo++;
    Segmento cabeza = g.segmentos.get(0);
    
    // === DEATH STATE GATE ===
    // During death (estado==1), suppress all normal steering/behavior
    boolean isDying = (g.estado == 1);
    
    // DEBUG: Log dying state for first jellyfish (every second)
    if (frameCount % 60 == 0 && g.id == 0) {
      println("[J0] isDying: " + isDying + 
              " | vida: " + nf(g.vida, 1, 1) + "/" + nf(g.vidaMax, 1, 1) +
              " | estado: " + g.estado + 
              " | Y-pos: " + int(cabeza.y));
    }

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

    // ============================================================
    // SIMULATED INTERACTION (DEMO MODE - 3 Behavior Cycling)
    // ============================================================
    // Ghost cursor cycles through 3 behaviors for 1 minute each:
    // 0: Gentle floating (infinity/lemniscate pattern)
    // 1: Scare mode (aggressive, fast movements, wide arcs)
    // 2: Approach mode (slow drift toward nearby jellies)
    
    // Add slow vertical drift to prevent horizontal line clustering
    g.simCursorVerticalOffset += random(-0.5, 0.5);
    g.simCursorVerticalOffset = constrain(g.simCursorVerticalOffset, -120, 120);
    
    float simTime = frameCount * 0.005;  // slow time progression
    int behaviorPhase = getCurrentBehaviorPhase();
    
    float simMouseX, simMouseY;
    
    if (behaviorPhase == 0) {
      // ===== GENTLE: Infinity symbol (∞) lemniscate pattern =====
      float simRadius = 200;  // Wider for infinity loops
      float simCenterX = width / 2;
      float simCenterY = height * 0.45 + g.simCursorVerticalOffset;
      
      // Lemniscate of Bernoulli (infinity symbol)
      // x = a * cos(t) / (1 + sin²(t)) + g.simCursorVerticalOffset
      // y = a * sin(t) * cos(t) / (1 + sin²(t))
      float t = simTime;
      float denom = 1.0 + sin(t) * sin(t);
      simMouseX = simCenterX + (simRadius * cos(t)) / denom;
      simMouseY = simCenterY + (simRadius * sin(t) * cos(t)) / denom;
    } else if (behaviorPhase == 1) {
      // ===== SCARE: Aggressive, erratic movements =====
      float scareCenterX = width / 2;
      float scareCenterY = height * 0.45;
      float scareRadius = 200;  // Much larger radius
      float scareSpeed = 0.015; // Faster movement
      
      // Aggressive circular + random jitter
      simMouseX = scareCenterX + cos(simTime * scareSpeed) * scareRadius + random(-40, 40);
      simMouseY = scareCenterY + sin(simTime * scareSpeed * 0.7) * scareRadius * 0.4 + random(-40, 40);
      
      // Add aggressive stabbing motions at jellies
      if (gusanos.size() > 0) {
        int targetIdx = frameCount % gusanos.size();
        Gusano target = gusanos.get(targetIdx);
        if (target.segmentos.size() > 0) {
          simMouseX = lerp(simMouseX, target.segmentos.get(0).x, 0.15);
          simMouseY = lerp(simMouseY, target.segmentos.get(0).y, 0.15);
        }
      }
    } else {
      // ===== APPROACH: Slow, gentle drift toward nearest jelly =====
      float approachSpeed = 0.003;
      float approachRadius = 150;
      
      // Slow circular motion with vertical drift
      simMouseX = width / 2 + cos(simTime * approachSpeed) * approachRadius;
      simMouseY = height * 0.45 + g.simCursorVerticalOffset + sin(simTime * approachSpeed * 0.5) * approachRadius * 0.4;
      
      // Gently approach nearest jellyfish
      if (gusanos.size() > 0) {
        int nearest = 0;
        float nearestDist = 10000;
        for (int i = 0; i < gusanos.size(); i++) {
          if (gusanos.get(i).segmentos.size() > 0) {
            float d = dist(simMouseX, simMouseY, gusanos.get(i).segmentos.get(0).x, gusanos.get(i).segmentos.get(0).y);
            if (d < nearestDist) {
              nearestDist = d;
              nearest = i;
            }
          }
        }
        // Very slow, gentle approach
        if (gusanos.get(nearest).segmentos.size() > 0) {
          Segmento targetHead = gusanos.get(nearest).segmentos.get(0);
          simMouseX = lerp(simMouseX, targetHead.x, 0.02);
          simMouseY = lerp(simMouseY, targetHead.y, 0.02);
        }
      }
    }
    
    // Use simulated position instead of real mouse
    float mouseV = dist(simMouseX, simMouseY, pmouseX, pmouseY);
    float dMouse = dist(cabeza.x, cabeza.y, simMouseX, simMouseY);
    float userNear = 1.0 - constrain(dMouse / 200.0, 0, 1);
    userNear = g.smoothstep(userNear);

    float userMove = constrain(mouseV / 30.0, 0, 1);
    float S_user = userNear * userMove;
    // Simulated hovering behavior (adjusted for behavior type)
    if (behaviorPhase == 1) {
      // Scare: more aggressive, higher base activity
      S_user = max(S_user, userNear * 0.7);
    } else {
      // Gentle & approach: gentle hovering
      S_user = max(S_user, userNear * 0.4);
    }
    
    // Minimal internal state dampening - stay interactive for installation visitors
    S_user *= lerp(1.0, 0.92, g.hunger * 0.3);  // hungry = barely less interactive
    S_user *= lerp(0.9, 1.0, (circadianMod - 0.7) / 0.3);  // less dampening during rest
    
    g.S_userNow = S_user;

    // ============================================================
    // USER ATTITUDE UPDATE (simplified for demo - mostly personality-driven)
    // ============================================================
    // Jellyfish maintain curiosity/fear based on personality, with behavior phase influence
    
    // Adjust attitude target based on behavior phase
    float behaviorInfluence = 0.0;
    if (behaviorPhase == 0) {
      behaviorInfluence = 0.3;  // Gentle: slightly positive (curious)
    } else if (behaviorPhase == 1) {
      behaviorInfluence = -0.4; // Scare: strongly negative (fearful)
    } else {
      behaviorInfluence = 0.2;  // Approach: mildly positive (curious)
    }
    
    // Gentle random drift creates naturalistic attitude variations
    g.userAttTarget = constrain(g.userAttTarget + random(-1, 1) * 0.001 + behaviorInfluence * 0.001, -1, 1);
    
    // Very slow attitude changes (personality is stable)
    g.userAttitude += (g.userAttTarget - g.userAttitude) * 0.015;
    g.userAttitude = constrain(g.userAttitude, -1, 1);

    // Social stimulus is computed later
    float S_social = 0;

    // ------------------------------------------------------------
    // Target switching modulation (includes hunger-driven seeking)
    // ------------------------------------------------------------
    float distanciaAlObjetivo = dist(cabeza.x, cabeza.y, g.objetivoX, g.objetivoY);

    float calm = (1.0 - g.arousal) * (1.0 - 0.7 * g.userMode);
    g.frecuenciaCambio = lerp(90, 160, calm);
    g.frecuenciaCambio = lerp(220, g.frecuenciaCambio, spawnEase);
    
    // Hunger increases target switching (active foraging)
    g.frecuenciaCambio *= lerp(1.0, 0.65, g.hunger);  // hungry = faster searching

    if (g.cambioObjetivo > g.frecuenciaCambio || distanciaAlObjetivo < 20) {
      g.nuevoObjetivo();
      g.cambioObjetivo = 0;
      
      // DEBUG: Log new target position for first jellyfish
      if (g.id == 0) {
        println("[J0] New target - X: " + int(g.objetivoX) + " Y: " + int(g.objetivoY) + 
                " | Current Y: " + int(cabeza.y));
      }
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
    // Head fluid sample (cached) + FEEDING
    // ------------------------------------------------------------
    PVector velocidadFluido = fluido.obtenerVelocidad(cabeza.x, cabeza.y);
    float alturaFluido = fluido.obtenerAltura(cabeza.x, cabeza.y);
    g.cacheVx[0] = velocidadFluido.x;
    g.cacheVy[0] = velocidadFluido.y;
    g.cacheH[0]  = alturaFluido;
    
    // --- FEEDING: Extract energy from optimal fluid conditions ---
    // Gentle waves (not too still, not too turbulent) = food-rich zones
    float fluidSpeed = velocidadFluido.mag();
    float fluidHeight = abs(alturaFluido);
    
    // Optimal feeding: gentle motion (0.5-2.0 speed, 2-8 height)
    float speedFitness = 1.0 - abs(fluidSpeed - 1.25) / 2.0;  // peaks at 1.25
    float heightFitness = 1.0 - abs(fluidHeight - 5.0) / 8.0; // peaks at 5.0
    speedFitness = constrain(speedFitness, 0, 1);
    heightFitness = constrain(heightFitness, 0, 1);
    
    float foodQuality = (speedFitness * 0.6 + heightFitness * 0.4);
    
    // Energy gain (only when hungry)
    if (g.hunger > 0.2) {
      float energyGain = foodQuality * g.feedingEfficiency * 0.25;
      g.energy = min(g.energy + energyGain, g.energyMax);
    }
    
    // --- ACTIVE FORAGING: Steer toward food when hungry ---
    if (g.hunger > 0.4) {  // Moderately hungry triggers foraging
      // Sample fluid quality in 8 directions (performance: 8 samples vs continuous)
      float bestAngle = 0;
      float bestQuality = 0;
      float sampleRadius = 60;  // Look ahead distance
      
      for (int i = 0; i < 8; i++) {
        float angle = i * TWO_PI / 8;
        float testX = cabeza.x + cos(angle) * sampleRadius;
        float testY = cabeza.y + sin(angle) * sampleRadius;
        
        PVector vTest = fluido.obtenerVelocidad(testX, testY);
        float hTest = fluido.obtenerAltura(testX, testY);
        
        float speedFit = 1.0 - abs(vTest.mag() - 1.25) / 2.0;
        float heightFit = 1.0 - abs(abs(hTest) - 5.0) / 8.0;
        float quality = constrain((speedFit * 0.6 + heightFit * 0.4), 0, 1);
        
        if (quality > bestQuality) {
          bestQuality = quality;
          bestAngle = angle;
        }
      }
      
      // Bias target toward best food direction (stronger when hungrier)
      if (bestQuality > 0.3) {
        float forageBias = g.hunger * 80;  // 32-80px pull when hungry
        g.objetivoX += cos(bestAngle) * forageBias;
        g.objetivoY += sin(bestAngle) * forageBias;
        g.objetivoX = constrain(g.objetivoX, boundsInset, width - boundsInset);
        g.objetivoY = constrain(g.objetivoY, boundsInset, height - boundsInset);
      }
    }

    float objetivoConFluidoX = g.objetivoX + velocidadFluido.x * 8;
    float objetivoConFluidoY = g.objetivoY + velocidadFluido.y * 8;
    objetivoConFluidoY -= alturaFluido * 0.3;

    // User-target bias: simulated cursor steers the *target* toward/away
    float att = g.userAttitude;
    float attMag = abs(att);
    float attSign = (att >= 0) ? 1.0 : -1.0;

    float md = max(1e-6, dMouse);
    float dmX = (simMouseX - cabeza.x) / md;  // Use simulated cursor position
    float dmY = (simMouseY - cabeza.y) / md;

    float steerGate = userNear;
    float steerA = 0.35 + 0.65 * g.arousal;
    float steerM = 0.45 + 0.55 * g.userMode;

    float userPush = g.userPushBase * attMag * steerGate * steerA * steerM * spawnEase;

    // Strong multiplier for decisive user interaction response
    objetivoConFluidoX += dmX * userPush * attSign * 2.5;
    objetivoConFluidoY += dmY * userPush * attSign * 2.5;

    // Ease the effective target during first frames
    float tgtX = lerp(cabeza.x, objetivoConFluidoX, spawnEase);
    float tgtY = lerp(cabeza.y, objetivoConFluidoY, spawnEase);
    
    // === SUPPRESS MOVEMENT DURING DEATH ===
    if (isDying) {
      // Dead jellyfish don't steer - just gravity and tumbling
      tgtX = cabeza.x;
      tgtY = cabeza.y;
    }
    
    // Activity and energy affect movement speed (with reasonable minimum)
    float speedMod = g.activityLevel * lerp(0.85, 1.0, g.energy / g.energyMax);
    speedMod = max(speedMod, 0.70);  // ensure minimum responsiveness
    
    // Apply life stage speed modifier
    speedMod *= g.stageSpeedMul;
    
    // No steering during death
    if (!isDying) {
      cabeza.seguir(tgtX, tgtY + velocidad * g.speedMul * speedMod);
    }
    
    // DIRECT USER FORCE: Very subtle - simulated gentle presence
    // Suppressed during death - user cannot interact with dying jellyfish
    // Reduced significantly for demo mode (simulated interaction is subtle)
    if (!isDying && S_user > 0.15) {  // Only when engagement is high
      float directStrength = g.userPushBase * 0.04 * attMag * attSign;  // Reduced from 0.12 to 0.04
      float directGate = steerGate * steerA * spawnEase;
      float directForce = directStrength * directGate;
      
      // Apply subtle force in direction of attitude
      cabeza.x += dmX * directForce;
      cabeza.y += dmY * directForce;
    }

    // ------------------------------------------------------------
    // Pulse oscillator (modulated by circadian and energy)
    // ------------------------------------------------------------
    float modeBoost = lerp(0.90, 1.15, g.userMode);  // Reduced range for steadier rhythm
    float energyMod = lerp(0.75, 1.0, g.energy / g.energyMax);  // low energy = slower pulse
    float freq = g.baseFreq * lerp(0.90, 1.40, g.arousal) * modeBoost * g.activityLevel * energyMod;
    g.phase += freq;
    if (g.phase > TWO_PI) g.phase -= TWO_PI;

    float raw = max(0, sin(g.phase));
    float pulse = pow(raw, g.pulseK);
    float relax = 1.0 - pulse;
    g.pulseNow = pulse;
    g.relaxNow = relax;

    // Burst push during contraction
    // Suppressed during death - no pulse activity
    if (!isDying) {
      float burst = pulse * g.pulseAmp * lerp(0.85, 1.25, g.arousal) * lerp(0.95, 1.20, g.userMode) * spawnEase;  // Gentler bursts
      cabeza.x += cos(cabeza.angulo) * burst;
      cabeza.y += sin(cabeza.angulo) * burst;
    }

    // Minimal flee response for fearful jellyfish (demo mode is gentle)
    // Suppressed during death - dying jellyfish don't flee
    if (!isDying && g.userAttitude < -0.3) {  // Only very fearful jellyfish flee
      float danger = constrain(0.3 * (S_user + g.userMode), 0, 1);  // Reduced from 0.5 to 0.3
      if (danger > 0.45) {  // Higher threshold (was 0.35)
        float awayX = (cabeza.x - simMouseX);  // Use simulated cursor
        float awayY = (cabeza.y - simMouseY);
        float am = sqrt(awayX*awayX + awayY*awayY);
        if (am > 1e-6) {
          awayX /= am;
          awayY /= am;
          float kick = g.fleeKick * danger * (-g.userAttitude) * (0.35 + 0.65 * g.arousal) * spawnEase * 0.5;  // Reduced from 1.5 to 0.5
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

      // Enhanced head wake: jellyfish bell creates visible propulsion ripples
      int framesSinceSpawn = frameCount - g.spawnFrame;
      if (sp > 0.08 && framesSinceSpawn > 45) {  // Lowered from 0.15 to show more wake
        float radio = 24;  // Increased from 18 for larger visible wake
        float fuerza = constrain(sp * 2.5 * (1.0 + 1.2 * pulse + 0.8 * g.arousal) * lerp(1.0, 1.40, g.userMode) * spawnEase, 0, 10.0);  // Increased from 7.2
        fluido.perturbarDir(cabeza.x, cabeza.y, radio, mvx, mvy, fuerza);
        
        // Add bell pulsation ripples when breathing (tentacle wave active)
        if (!g.tentaclePaused && pulse > 0.3) {
          // Create radial ripple from bell pulsation
          float pulseStrength = pulse * 2.5;  // Strength based on breathing intensity
          fluido.perturbar(cabeza.x, cabeza.y, 35, pulseStrength);
        }
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
    
    // Update stress and population tracking
    g.stress = stress;
    g.nearbyCount = nSoc;
    
    // Crowding stress affects health (population pressure)
    g.crowdingStress = constrain(map(nSoc, 3, 8, 0, 1), 0, 1);
    if (g.crowdingStress > 0.5) {
      // Apply life stage mortality modifier (ephyra/senescent take more damage)
      // REDUCED from 0.08 to 0.02 (75% reduction) to prevent rapid death
      g.vida -= g.crowdingStress * 0.02 * g.stageMortalityMul;
    }
    
    // Reproduction eligibility: good energy, low crowding, mature age
    int ageInFrames = frameCount - g.spawnFrame;
    g.canReproduce = (g.energy > 75 && g.crowdingStress < 0.4 && ageInFrames > 1800);  // ~60s maturity

    float crowd = constrain(nSoc / 4.0, 0, 1);
    S_social = constrain(0.55 * constrain(stress, 0, 1) + 0.45 * crowd, 0, 1);
    g.S_socialNow = S_social;

    float targetArousal = constrain(S_user * g.wUser + S_social * g.wSocial, 0, 1);
    
    // Circadian rhythm modulates arousal (less excitable during rest phase)
    targetArousal *= circadianMod;
    
    // Low energy reduces arousal (fatigue)
    targetArousal *= lerp(0.5, 1.0, g.energy / g.energyMax);
    
    g.arousal += (targetArousal - g.arousal) * g.arousalAttack;
    g.arousal *= g.arousalDecay;
    g.arousal = constrain(g.arousal, 0, 1);

    // CONTINUOUS MODE BLENDING: Smooth social<->user balance (no binary switch)
    float dom = (S_user - S_social * g.domK) / g.domSoft;
    float domValue = 0.5 + 0.5 * constrain(dom, -1, 1);  // 0-1 range
    
    // Continuous target with hysteresis smoothing (prevents jitter)
    float userTarget = constrain(domValue, 0, 1);  // NO binary threshold
    
    // Smoother follow rate for gradual transitions
    g.userMode += (userTarget - g.userMode) * g.modeFollow * 0.6;  // Slower blend
    g.userMode = constrain(g.userMode, 0, 1);
    
    // Update tracking for potential future features
    wasInUserMode = (g.userMode > 0.5);

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

    PVector social = new PVector(0, 0);

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
      
      // === NATURAL DEATH ANIMATION ===
      // Stage-aware timing: ephyra collapse fast, adults slower, senescent much slower
      float deathDuration = 220;  // Default adult (slower)
      if (g.lifeStage == LifeStage.EPHYRA) {
        deathDuration = 160;  // Newborns collapse quickly (fragile)
      } else if (g.lifeStage == LifeStage.SENESCENT) {
        deathDuration = 280;  // Elderly linger longer (gradual decline)
      }
      
      float deathProgress = constrain(g.tickCambioCuerpo / deathDuration, 0, 1);
      
      // Exponential easing: smooth deceleration (fast start, slow end)
      float eased = 1.0 - pow(1.0 - deathProgress, 3.0);
      
      // Segment collapse (shrinking body)
      int targetSegs = int(lerp(numSegmentos, 1, eased));
      g.segActivos = max(1, targetSegs);
      
      // Alpha fade-out (keep 30% visibility for ghostly effect)
      g.deathFade = 1.0 - (deathProgress * 0.7);
      
      // === DISABLE ACTIVE STEERING ===
      // Zero out all normal locomotion forces during death
      // (User steering, social forces, target seeking all suppressed)
      
      // === PASSIVE SINK BEHAVIOR ===
      // Gentle downward drift that accelerates then plateaus
      float sinkSpeed = eased * 1.2;  // Max 1.2 px/frame downward
      float sinkDamping = 0.98;  // Resistance to acceleration
      g.deathSinkAccel = g.deathSinkAccel * sinkDamping + sinkSpeed * (1.0 - sinkDamping);
      cabeza.y += g.deathSinkAccel;
      
      // === GENTLE TUMBLING/ROTATION ===
      // Helical spiral mimics limp organism drifting
      float tumblePhase = deathProgress * TWO_PI * 3.0;  // 3 full rotations during collapse
      float tumbleRadius = 15 * (1.0 - eased);  // Tumble radius decreases as body compresses
      float tumbleX = cos(tumblePhase * g.deathTumbleDirection) * tumbleRadius;
      
      cabeza.x += tumbleX * 0.3;  // Gentle horizontal spiral (30% of calculated radius)
      // Vertical component adds to sink for helical effect
      
      // === SUPPRESS AROUSAL/RESPONSE ===
      g.arousal = 0;  // Lock at zero - dead jellyfish don't react
      
      // === PULSE FADE-OUT ===
      // Gradually silence the pulse as organism dies
      float pulseFadeout = 1.0 - eased;  // Inverted: pulses stop as death progresses
      g.pulseNow *= pulseFadeout;  // Silent heartbeat
      
      // === SMOOTH HEAD VELOCITY ===
      // Heavy damping makes head glide smoothly instead of jerking
      float headVelX = cabeza.x - cabeza.prevX;
      float headVelY = cabeza.y - cabeza.prevY;
      float heavyDamp = 0.3;  // 70% damping during death
      cabeza.x = cabeza.prevX + headVelX * heavyDamp;
      cabeza.y = cabeza.prevY + headVelY * heavyDamp;
      
      if (g.tickCambioCuerpo >= deathDuration) {
        g.renacer();
        g.estado = 2;
        g.tickCambioCuerpo = 0;
        g.deathSinkAccel = 0;  // Reset sink accumulator for rebirth
      }
    }

    if (g.estado == 2) {
      g.tickCambioCuerpo++;
      
      // Smooth exponential growth: slow start, accelerates, then slows at end
      float growthProgress = g.tickCambioCuerpo / 90.0;  // 90 frames (~1.5s)
      growthProgress = constrain(growthProgress, 0, 1);
      // Smoothstep easing (S-curve for natural organic growth)
      float eased = growthProgress * growthProgress * (3.0 - 2.0 * growthProgress);
      
      // Head-first growth: start with only head, progressively add tail segments
      // eased goes 0->1, so we go from 1 segment to full
      int targetSegs = int(lerp(1, numSegmentos, eased));
      g.segActivos = constrain(targetSegs, 1, numSegmentos);
      
      // Health regenerates smoothly
      g.vida = lerp(0, g.vidaMax, eased);
      
      // Fade in during growth
      g.deathFade = 0.3 + eased * 0.7;  // Start at 30% alpha, grow to 100%
      
      if (g.tickCambioCuerpo >= 90) {
        g.estado = 0;
        g.vida = g.vidaMax;
        g.deathFade = 1.0;
      }
    }

    // Apply social steering to the head (BODY will handle wall repulsion + segment updates)
    if (!isDying) {
      cabeza.x += social.x;
      cabeza.y += social.y;
    }
    
    // ============================================================
    // INTERACTION VISUALIZATION: Tiny directional arrows
    // ============================================================
    // Show movement direction towards/away from cursor during active interaction
    // Only visible when jellyfish actively reacting to user (|attitude| > 0.2)
    // Green arrow = approaching cursor, Red arrow = fleeing cursor
    
    if (Math.abs(g.userAttitude) > 0.2) {  // Only show during active interaction
      pushMatrix();
      
      // Determine direction: approaching vs fleeing
      boolean approachingCursor = g.userAttitude > 0.2;  // Positive attitude = curious = approach
      
      // Calculate movement direction from head towards/away from cursor
      float dirX = mouseX - cabeza.x;
      float dirY = mouseY - cabeza.y;
      float dirDist = sqrt(dirX*dirX + dirY*dirY);
      
      if (dirDist > 1) {
        // Normalize direction
        dirX /= dirDist;
        dirY /= dirDist;
        
        // If fleeing, reverse direction
        if (!approachingCursor) {
          dirX *= -1;
          dirY *= -1;
        }
        
        // Draw tiny arrow (8px total)
        float arrowLength = 8;
        float arrowX = cabeza.x + dirX * 12;  // Position slightly offset from head
        float arrowY = cabeza.y + dirY * 12;
        
        // Color: green=approach, red=flee
        color arrowColor = approachingCursor ? color(100, 255, 100, 150) : color(255, 100, 100, 150);
        fill(arrowColor);
        noStroke();
        
        // Draw tiny arrow as small triangle
        float angle = atan2(dirY, dirX);
        float arrowHead = 2.5;  // Size of arrowhead
        
        pushMatrix();
        translate(arrowX, arrowY);
        rotate(angle);
        
        // Triangle pointing in direction
        triangle(0, 0, -arrowHead, -arrowHead*0.7, -arrowHead, arrowHead*0.7);
        
        // Small line for shaft
        stroke(arrowColor);
        strokeWeight(1);
        line(0, 0, -arrowLength*0.6, 0);
        
        popMatrix();
      }
      
      popMatrix();
    }
  }
  
  // ============================================================
  // Life Stage Management
  // ============================================================
  
  // Update life stage based on age
  void updateLifeStage(Gusano g) {
    // Update age in seconds
    g.ageSeconds = g.ageFrames / 60.0;  // Assuming 60 FPS
    
    // Determine life stage based on age thresholds
    if (g.ageSeconds < 60) {
      g.lifeStage = LifeStage.EPHYRA;
    } else if (g.ageSeconds < 360) {  // 6 minutes
      g.lifeStage = LifeStage.JUVENILE;
    } else if (g.ageSeconds < 1800) {  // 30 minutes
      g.lifeStage = LifeStage.ADULT;
    } else {
      g.lifeStage = LifeStage.SENESCENT;
    }
  }
  
  // Apply stage-specific behavioral and physical modifiers
  void applyStageModifiers(Gusano g) {
    switch(g.lifeStage) {
      case EPHYRA:
        // Newborn: small (60%), fast (130%), fragile (150% damage), very curious
        g.stageScaleMul = 0.60;
        g.stageSpeedMul = 1.30;
        g.stageMortalityMul = 1.50;
        g.stageCuriosityMul = 1.40;
        break;
        
      case JUVENILE:
        // Growing: medium (80%), normal speed (105%), learning (120% damage), curious
        g.stageScaleMul = 0.80;
        g.stageSpeedMul = 1.05;
        g.stageMortalityMul = 1.20;
        g.stageCuriosityMul = 1.20;
        break;
        
      case ADULT:
        // Mature: full size (100%), normal (100%), resilient (100% damage), balanced
        g.stageScaleMul = 1.00;
        g.stageSpeedMul = 1.00;
        g.stageMortalityMul = 1.00;
        g.stageCuriosityMul = 1.00;
        break;
        
      case SENESCENT:
        // Aging: slightly smaller (90%), slower (75%), very fragile (180% damage), less curious
        g.stageScaleMul = 0.90;
        g.stageSpeedMul = 0.75;
        g.stageMortalityMul = 1.80;
        g.stageCuriosityMul = 0.70;
        break;
    }
  }
}