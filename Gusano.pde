// ============================================================
// Gusano.pde
// ============================================================

class Gusano {
  ArrayList<Segmento> segmentos;
  color colorCabeza;
  color colorCola;

  float objetivoX, objetivoY;
  float cambioObjetivo;
  float frecuenciaCambio;
  int id;

  // --- Social fields ---
  float humor = 0;
  float temperamento = 0;
  float faseHumor = 0;
  float rangoSocial = 260;
  float rangoRepulsion = 120;
  float rangoChoque = 70;

  // --- Pulse oscillator + arousal (burst/coast + smooth state) ---
  float phase = 0;
  float baseFreq = 0.045;   // radians per frame (will be modulated by arousal)
  float pulseAmp = 1.6;     // how much extra head travel during contraction
  float pulseK = 2.6;       // higher = snappier contraction

  float arousal = 0;        // 0..1 (fast attack, slow decay)
  float arousalAttack = 0.12;
  float arousalDecay  = 0.982;
  float wUser = 0.75;
  float wSocial = 0.55;


  // --- Rhythm switching (user-dominant vs social-dominant) ---
  float userMode = 0;        // 0..1 (0 = schooling, 1 = interactive)
  float modeFollow = 0.10;   // smoothing for mode switching
  float domK = 1.35;         // userDominant if S_user > S_social * domK
  float domSoft = 0.30;      // softness for smooth dominance


  // --- User attitude (curious <-> fearful) ---
  // userAttitude in [-1, +1]
  //  +1 = curious (approach mouse)
  //  -1 = fearful (flee mouse)
  float userAttitude = 0;       // current attitude
  float userAttTarget = 0;      // slowly drifting target
  float attFollow = 0.03;       // smoothing toward target
  float attDrift  = 0.004;      // random walk strength

  // --- Main knobs (behavioral) ---
  float userPushBase = 140;     // higher = more reactive to mouse steering
  float wallRange = 130;        // px: how far wall repulsion reaches
  float wallPush  = 0.85;       // strength of soft wall repulsion
  float fleeKick  = 3.2;        // tiny extra kick when fearful + high user stimulus
  float flipBase  = 0.008;      // base flip chance per frame
  float flipGain  = 0.10;       // additional flip chance scaled by S_user

  // --- Phase sync (Kuramoto-lite) ---
  float syncStrength = 0.016;   // base coupling per frame (very small)
  float syncMaxStep  = 0.035;   // max radians/frame correction

  // --- Body cohesion (prevents unnatural stretching) ---
  float longitudSegmento = 12;   // desired distance between segments (pixels)
  int   constraintIters  = 5;    // constraint relaxation iterations (higher = stiffer)
  float constraintStiff  = 0.85; // 0..1 how strongly we correct per iteration
  float bendSmooth       = 0.12; // 0..1 soft spine smoothing (keeps it organic)

  // --- Render scale (size) ---
  // Scale the whole gusano shape. 0.6 = 40% smaller.
  float shapeScale = 0.60;

  // --- Life cycle (morir / renacer / crecer) ---
  // estado: 0 = viva, 1 = muriendo (pierde puntos/cuerpo), 2 = creciendo (renace)
  int estado = 0;
  float vidaMax = 100;
  float vida = 100;
  int segActivos;           // cuántos segmentos están "vivos" (afecta dibujo y update)
  int tickCambioCuerpo = 0; // controla velocidad de perder/ganar segmentos

  // --- Fluid sample cache (PER SEGMENT) ---
  // Avoid sampling the fluid per drawn point (very expensive).
  float[] cacheVx;
  float[] cacheVy;
  float[] cacheH;

  // Age since spawn/respawn (frames) used to avoid initial additive oversaturation
  int ageFrames = 0;

  Gusano(float x, float y, color cHead, color cTail, int id_) {
    segmentos = new ArrayList<Segmento>();
    colorCabeza = cHead;
    colorCola = cTail;
    id = id_;

    for (int i = 0; i < numSegmentos; i++) {
      segmentos.add(new Segmento(x, y));
    }
    // Spread initial segments a bit to avoid huge additive bloom at spawn
    distribuirSegmentos(x, y);

    objetivoX = random(boundsInset, width - boundsInset);
    objetivoY = random(boundsInset, height - boundsInset);
    cambioObjetivo = 0;
    frecuenciaCambio = random(80, 120);

    // Random personality per jellyfish
    temperamento = random(-1, 1);
    faseHumor = random(TWO_PI);

    // Life init
    vidaMax = 100;
    vida = vidaMax;
    estado = 0;
    segActivos = numSegmentos;
    tickCambioCuerpo = 0;

    // Cache init
    cacheVx = new float[numSegmentos];
    cacheVy = new float[numSegmentos];
    cacheH  = new float[numSegmentos];

    // Oscillator/arousal init (per jellyfish personality)
    phase = random(TWO_PI);
    baseFreq = random(0.025, 0.050);
    pulseAmp = random(1.1, 1.9);
    pulseK   = random(1.8, 2.3);
    arousal = 0;

    // User attitude init
    userAttitude = random(-1, 1);
    userAttTarget = userAttitude;
  }

  void actualizar() {
    ageFrames++;
    // --- Spawn easing: reduce harsh initial motion after spawn/respawn ---
    // 0..1 ramp over first ~60 frames
    float spawnEase = constrain(ageFrames / 60.0, 0, 1);
    spawnEase = spawnEase * spawnEase * (3.0 - 2.0 * spawnEase); // smoothstep
    cambioObjetivo++;
    Segmento cabeza = segmentos.get(0);
    if (exitArmed) {
 


  float dL = cabeza.x;
  float dR = width - cabeza.x;
  float dT = cabeza.y;
  float dB = height - cabeza.y;

  if (dL < dR && dL < dT && dL < dB) {
    objetivoX = -300;
    objetivoY = cabeza.y;
  } else if (dR < dT && dR < dB) {
    objetivoX = width + 300;
    objetivoY = cabeza.y;
  } else if (dT < dB) {
    objetivoX = cabeza.x;
    objetivoY = -300;
  } else {
    objetivoX = cabeza.x;
    objetivoY = height + 300;
  }


  // Puedes sumar un pequeño empujón en la dirección del objetivo:
  float dx = objetivoX - cabeza.x;
  float dy = objetivoY - cabeza.y;
  float m = sqrt(dx*dx + dy*dy);
  if (m > 1e-6) {
    dx /= m; dy /= m;
    cabeza.x += dx * 1.2;
    cabeza.y += dy * 1.2;
  }
}

    // ------------------------------------------------------------
    // AROUSAL (fast attack, slow decay) + PULSE OSCILLATOR
    // Stimuli:
    //  - user: nearby mouse movement (and pressed)
    //  - social: proximity stress + local neighbor count
    // ------------------------------------------------------------
    float mouseV = dist(mouseX, mouseY, pmouseX, pmouseY);
    float dMouse = dist(cabeza.x, cabeza.y, mouseX, mouseY);
    float userNear = 1.0 - constrain(dMouse / 200.0, 0, 1);
    userNear = smoothstep(userNear);

    float userMove = constrain(mouseV / 30.0, 0, 1);
    float S_user = userNear * userMove;
    if (mousePressed) S_user = max(S_user, userNear * 0.85);

    // ------------------------------------------------------------
    // USER ATTITUDE UPDATE (curious <-> fearful)
    // - Smooth drift so it doesn't freeze
    // - Occasionally flips when user stimulus is strong
    // - Very rarely flips when calm
    // Main knob: (flipBase + flipGain * S_user)
    // ------------------------------------------------------------
    float flipP = flipBase + flipGain * S_user;
    if (random(1) < flipP) {
      // flip target, keep it strong enough to read
      userAttTarget = -userAttTarget;
      if (abs(userAttTarget) < 0.35) userAttTarget = (userAttTarget >= 0 ? 0.75 : -0.75);
      // tiny randomness so it doesn't bounce between two exact values
      userAttTarget = constrain(userAttTarget + random(-0.15, 0.15), -1, 1);
    } else {
      // slow random-walk drift (keeps personalities alive)
      userAttTarget = constrain(userAttTarget + random(-1, 1) * attDrift, -1, 1);
    }
    userAttitude += (userAttTarget - userAttitude) * attFollow;
    userAttitude = constrain(userAttitude, -1, 1);

    // Social stimulus will be filled later (after we compute stress + neighbor counts)
    float S_social = 0;

    // We'll finish arousal update after social loop, but we can advance phase now with last arousal
    // (phase step gets refined once arousal is updated)
    float distanciaAlObjetivo = dist(cabeza.x, cabeza.y, objetivoX, objetivoY);

    // Target switching modulation: calm = dreamy long arcs, aroused/user = twitchy retarget
    float calm = (1.0 - arousal) * (1.0 - 0.7 * userMode);
    frecuenciaCambio = lerp(90, 160, calm);
    // Early on, avoid twitchy retargeting while everything is still "waking up"
    frecuenciaCambio = lerp(220, frecuenciaCambio, spawnEase);

    if (cambioObjetivo > frecuenciaCambio || distanciaAlObjetivo < 20) {
      nuevoObjetivo();
      cambioObjetivo = 0;
    }

    // --- Sample fluid ONCE for the head this frame (and cache it for drawing) ---
    PVector velocidadFluido = fluido.obtenerVelocidad(cabeza.x, cabeza.y);
    float alturaFluido = fluido.obtenerAltura(cabeza.x, cabeza.y);
    cacheVx[0] = velocidadFluido.x;
    cacheVy[0] = velocidadFluido.y;
    cacheH[0]  = alturaFluido;

    float objetivoConFluidoX = objetivoX + velocidadFluido.x * 15;
    float objetivoConFluidoY = objetivoY + velocidadFluido.y * 15;
    objetivoConFluidoY -= alturaFluido * 0.5;

    // ------------------------------------------------------------
    // User-target bias: mouse steers the *target* toward/away
    // Strength depends on attitude + proximity + arousal (+ a bit of userMode)
    // Main knob: userPushBase
    // ------------------------------------------------------------
    float att = userAttitude;                // [-1..1]
    float attMag = abs(att);
    float attSign = (att >= 0) ? 1.0 : -1.0; // +1 curious, -1 fearful

    // Direction from head to mouse (if very close, skip)
    float md = max(1e-6, dMouse);
    float dmX = (mouseX - cabeza.x) / md;
    float dmY = (mouseY - cabeza.y) / md;

    float steerGate = userNear; // already smoothstepped
    float steerA = 0.35 + 0.65 * arousal;
    float steerM = 0.45 + 0.55 * userMode;

    float userPush = userPushBase * attMag * steerGate * steerA * steerM * spawnEase;

    // Curious: pull target toward mouse, Fearful: push it away
    objetivoConFluidoX += dmX * userPush * attSign;
    objetivoConFluidoY += dmY * userPush * attSign;

    // Ease the effective target during the first frames so the head doesn't "snap"
    float tgtX = lerp(cabeza.x, objetivoConFluidoX, spawnEase);
    float tgtY = lerp(cabeza.y, objetivoConFluidoY, spawnEase);
    cabeza.seguir(tgtX, tgtY);

    // Pulse step (use current arousal from previous frame; refined below)
    float modeBoost = lerp(0.86, 1.20, userMode); // softer user-dominant boost
    float freq = baseFreq * lerp(0.85, 1.65, arousal) * modeBoost;
    phase += freq;
    if (phase > TWO_PI) phase -= TWO_PI;

    float raw = max(0, sin(phase));
    float pulse = pow(raw, pulseK);          // contraction: 0..1
    float relax = 1.0 - pulse;               // relaxation: 0..1

    // During contraction: tiny jet push forward (alive motion even with same target logic)
    // Use cabeza.angulo from seguir() as the current steering direction.
    float burst = pulse * pulseAmp * lerp(0.9, 1.45, arousal) * lerp(0.95, 1.35, userMode) * spawnEase;
    cabeza.x += cos(cabeza.angulo) * burst;
    cabeza.y += sin(cabeza.angulo) * burst;

    // Tiny flee kick: when user stimulus is high, userMode is high, and attitude is fearful
    // so "run away" reads clearly.
    if (userAttitude < -0.15) {
      float danger = constrain(0.5 * (S_user + userMode), 0, 1);
      if (danger > 0.55) {
        float awayX = (cabeza.x - mouseX);
        float awayY = (cabeza.y - mouseY);
        float am = sqrt(awayX*awayX + awayY*awayY);
        if (am > 1e-6) {
          awayX /= am;
          awayY /= am;
          float kick = fleeKick * danger * (-userAttitude) * (0.35 + 0.65 * arousal) * spawnEase;
          cabeza.x += awayX * kick;
          cabeza.y += awayY * kick;
        }
      }
    }

    // --- Fluid drag: nudge the segment motion toward local fluid velocity ---
    // (Head has the weakest drag; tail will be stronger below)
    {
      PVector vF = velocidadFluido;
      // More floaty during relaxation, more self-driven during contraction
      float drag = 0.05 + 0.12 * (1.0 - pulse) + 0.05 * (1.0 - arousal) - 0.03 * userMode;

      float mvx = cabeza.x - cabeza.prevX;
      float mvy = cabeza.y - cabeza.prevY;

      mvx = lerp(mvx, vF.x, drag);
      mvy = lerp(mvy, vF.y, drag);

      // Tiny momentum loss when pushing the medium
      float sp = sqrt(mvx*mvx + mvy*mvy);
      float slow = 1.0 - 0.02 * constrain(sp / 6.0, 0, 1);
      mvx *= slow;
      mvy *= slow;

      cabeza.x = cabeza.prevX + mvx;
      cabeza.y = cabeza.prevY + mvy;

      // --- Continuous wake injection (directional) ---
      if (sp > 0.15) {
        float radio = 18;
        float fuerza = constrain(sp * 1.8 * (1.0 + 0.8 * pulse + 0.6 * arousal) * lerp(1.0, 1.30, userMode) * spawnEase, 0, 7.2);
        fluido.perturbarDir(cabeza.x, cabeza.y, radio, mvx, mvy, fuerza);
      }
    }

    cabeza.actualizar();

    if (random(1) < 0.03) {
      objetivoX += random(-30, 30);
      objetivoY += random(-30, 30);
      objetivoX = constrain(objetivoX, boundsInset, width - boundsInset);
      objetivoY = constrain(objetivoY, boundsInset, height - boundsInset);
    }

    // Social forces and life cycle
    // Upgrade: boids-like mix (stable):
    // - Separation (strong, short range)
    // - Alignment (mild, within social range)
    // - Cohesion (occasional, within social range)
    PVector sep = new PVector(0, 0);
    PVector ali = new PVector(0, 0);
    PVector coh = new PVector(0, 0);

    int nAli = 0;
    int nCoh = 0;
    int nSoc = 0;

    // Stress accumulates when too close to others (used to drain vida)
    float stress = 0;

    // Own head velocity (approx) for alignment steering
    float myVx = cabeza.x - cabeza.prevX;
    float myVy = cabeza.y - cabeza.prevY;

    // Occasional cohesion to avoid constant clumping
    int cohPeriod = max(6, int(lerp(8, 18, userMode))); // social: often, user: rarely
    boolean doCohesion = (frameCount % cohPeriod == (id % cohPeriod));

    for (Gusano otro : gusanos) {
      if (otro == this) continue;
      Segmento cabezaOtro = otro.segmentos.get(0);

      float dx = cabezaOtro.x - cabeza.x;
      float dy = cabezaOtro.y - cabeza.y;
      float d2 = dx*dx + dy*dy;
      if (d2 < 1e-6) continue;
      float d = sqrt(d2);

      // --- Separation (short range, strong) ---
      if (d < rangoRepulsion) {
        float w = (rangoRepulsion - d) / rangoRepulsion;
        // Push away from neighbor (stronger when closer)
        sep.x -= (dx / d) * (w * 1.8);
        sep.y -= (dy / d) * (w * 1.8);

        // closeness costs energy (non-violent: just "fatigue")
        stress += w;
      }

      // --- Alignment + Cohesion (social range, mild) ---
      if (d < rangoSocial) {
        nSoc++;
        // Alignment: steer toward neighbors' average heading
        float ovx = cabezaOtro.x - cabezaOtro.prevX;
        float ovy = cabezaOtro.y - cabezaOtro.prevY;
        float om = sqrt(ovx*ovx + ovy*ovy);
        if (om > 1e-6) {
          ali.x += ovx / om;
          ali.y += ovy / om;
          nAli++;
        }

        // Cohesion: steer toward neighbors' center (applied occasionally)
        if (doCohesion) {
          coh.x += cabezaOtro.x;
          coh.y += cabezaOtro.y;
          nCoh++;
        }
      }
    }

    // Social stimulus: stress + local crowding (both 0..1-ish)
    float crowd = constrain(nSoc / 4.0, 0, 1);
    S_social = constrain(0.55 * constrain(stress, 0, 1) + 0.45 * crowd, 0, 1);

    // Arousal update: fast attack to stimulus, slow decay otherwise
    float targetArousal = constrain(S_user * wUser + S_social * wSocial, 0, 1);
    arousal += (targetArousal - arousal) * arousalAttack;
    arousal *= arousalDecay;
    arousal = constrain(arousal, 0, 1);

    // ------------------------------------------------------------
    // Rhythm switching: which stimulus dominates?
    // userMode -> 1 when user dominates, 0 when social dominates
    // (smoothly morph parameters; no hard if/else)
    // ------------------------------------------------------------
    float dom = (S_user - S_social * domK) / max(1e-6, domSoft);
    float userTarget = smoothstep(0.5 + 0.5 * constrain(dom, -1, 1));
    userMode += (userTarget - userMode) * modeFollow;
    userMode = constrain(userMode, 0, 1);

    // ------------------------------------------------------------
    // Phase synchronization (Kuramoto-lite)
    // - Only meaningful when social-dominant (userMode low)
    // - Strength increases with S_social (grouped)
    // - Uses circular mean via (cos, sin) averaging
    // ------------------------------------------------------------
    float syncGate = (1.0 - userMode) * S_social;   // 0..1
    if (syncGate > 1e-4) {
      float sumC = 0;
      float sumS = 0;
      int nPh = 0;

      for (Gusano otro : gusanos) {
        if (otro == this) continue;
        Segmento h2 = otro.segmentos.get(0);
        float d = dist(cabeza.x, cabeza.y, h2.x, h2.y);
        if (d < rangoSocial) {
          float w = 1.0 - (d / rangoSocial);
          w = w * w; // emphasize close neighbors
          sumC += cos(otro.phase) * w;
          sumS += sin(otro.phase) * w;
          nPh++;
        }
      }

      if (nPh > 0 && (sumC*sumC + sumS*sumS) > 1e-8) {
        float mean = atan2(sumS, sumC);
        float dphi = atan2(sin(mean - phase), cos(mean - phase)); // shortest signed angle

        float k = syncStrength * syncGate;
        float step = constrain(dphi * k, -syncMaxStep, syncMaxStep);
        phase += step;

        // Keep phase in [0, TWO_PI)
        if (phase < 0) phase += TWO_PI;
        else if (phase >= TWO_PI) phase -= TWO_PI;
      }
    }

    // Build the final social steering vector
    PVector social = new PVector(0, 0);

    // Weights tuned for stability (avoid spiraling / clumping)
    float wSep = 1.35 * lerp(1.18, 0.92, relax) * lerp(1.00, 1.18, userMode); // dart away a bit more
    float wAli = 0.55 * lerp(0.85, 1.35, relax) * lerp(1.25, 0.62, userMode); // stop caring when user-dominant
    float wCoh = 0.30 * lerp(0.80, 1.75, relax) * lerp(1.40, 0.55, userMode); // more schooling when social-dominant

    // Separation
    social.add(sep.x * wSep, sep.y * wSep);

    // Alignment: (avg heading - my heading) to reduce jitter
    if (nAli > 0) {
      ali.x /= nAli;
      ali.y /= nAli;

      float myM = sqrt(myVx*myVx + myVy*myVy);
      float myHx = (myM > 1e-6) ? (myVx / myM) : 0;
      float myHy = (myM > 1e-6) ? (myVy / myM) : 0;

      social.x += (ali.x - myHx) * wAli;
      social.y += (ali.y - myHy) * wAli;
    }

    // Cohesion: steer gently toward the neighborhood center (only sometimes)
    if (doCohesion && nCoh > 0) {
      coh.x /= nCoh;
      coh.y /= nCoh;
      float toCx = coh.x - cabeza.x;
      float toCy = coh.y - cabeza.y;
      float cm = sqrt(toCx*toCx + toCy*toCy);
      if (cm > 1e-6) {
        toCx /= cm;
        toCy /= cm;
        social.x += toCx * wCoh;
        social.y += toCy * wCoh;
      }
    }

    // Soft clamp to keep motion stable
    float sMag = sqrt(social.x*social.x + social.y*social.y);
    if (sMag > 1e-6) {
      float maxSocial = 1.2 + 0.4 * temperamento; // softer steering cap
      if (sMag > maxSocial) {
        social.x = (social.x / sMag) * maxSocial;
        social.y = (social.y / sMag) * maxSocial;
      }
    }

    // ------------------------------------------------------------
    // Life drain / death / rebirth / growth
    // - baseline drain + extra drain from social stress
    // - when dying: loses body segments (points disappear)
    // - when reborn: starts small and grows back
    // ------------------------------------------------------------
    // Baseline drain
    vida -= 0.015;

    // Stress drain (aggressive mood spends more)
    float gasto = (0.06 + 0.06 * max(0, -humor));
    vida -= stress * gasto;

    vida = constrain(vida, 0, vidaMax);

    // State transitions
    if (estado == 0 && vida <= 0.001) {
      estado = 1; // dying
      tickCambioCuerpo = 0;
    }

    // Dying: gradually lose segments
    if (estado == 1) {
      tickCambioCuerpo++;
      if (tickCambioCuerpo % 6 == 0) {
        segActivos = max(1, segActivos - 1);
      }
      if (segActivos <= 1) {
        renacer();
        estado = 2; // growing
        tickCambioCuerpo = 0;
      }
    }

    // Growing: gradually regain segments and vida
    if (estado == 2) {
      tickCambioCuerpo++;
      vida = min(vidaMax, vida + 0.22);
      if (tickCambioCuerpo % 5 == 0) {
        segActivos = min(numSegmentos, segActivos + 1);
      }
      if (segActivos >= numSegmentos && vida >= vidaMax * 0.98) {
        estado = 0; // alive again
        vida = vidaMax;
      }
    }


    // Apply social steering to the head
    cabeza.x += social.x;
    cabeza.y += social.y;

    // Soft wall repulsion (pre-clamp), prevents "cornered = frozen" feel
    aplicarRepulsionParedes();

    // Update body segments (only active ones)
    for (int i = 1; i < min(segActivos, segmentos.size()); i++) {
      Segmento seg = segmentos.get(i);
      Segmento segAnterior = segmentos.get(i - 1);

      PVector velFluidoSeg = fluido.obtenerVelocidad(seg.x, seg.y);
      float alturaFluidoSeg = fluido.obtenerAltura(seg.x, seg.y);
      // Cache this segment's fluid sample for drawing (single sample per segment per frame)
      cacheVx[i] = velFluidoSeg.x;
      cacheVy[i] = velFluidoSeg.y;
      cacheH[i]  = alturaFluidoSeg;

      float targetX = segAnterior.x + velFluidoSeg.x * 10;
      float targetY = segAnterior.y + velFluidoSeg.y * 10 - alturaFluidoSeg * 0.3;

      seg.seguir(targetX, targetY);

      // --- Fluid drag + wake (stronger toward the tail) ---
      {
        float tailT = (segmentos.size() <= 1) ? 1.0 : (i / (float)(segmentos.size() - 1));

        PVector vF = velFluidoSeg;
        float drag = lerp(0.08, 0.22, tailT) + 0.10 * (1.0 - pulse) + 0.04 * (1.0 - arousal) - 0.02 * userMode;

        float mvx = seg.x - seg.prevX;
        float mvy = seg.y - seg.prevY;

        mvx = lerp(mvx, vF.x, drag);
        mvy = lerp(mvy, vF.y, drag);

        float sp = sqrt(mvx*mvx + mvy*mvy);

        // Tiny momentum loss when pushing the medium (a bit stronger on tail)
        float slow = 1.0 - (0.02 + 0.02 * tailT) * constrain(sp / 6.0, 0, 1);
        mvx *= slow;
        mvy *= slow;

        seg.x = seg.prevX + mvx;
        seg.y = seg.prevY + mvy;

        // Directional wake: radius and strength grow slightly toward the tail
        if (sp > 0.10) {
          float radio = lerp(14, 30, tailT);
          float fuerza = constrain(sp * lerp(1.2, 2.2, tailT) * (1.0 + 0.8 * pulse + 0.6 * arousal) * lerp(1.0, 1.28, userMode) * spawnEase, 0, 7.0);
          fluido.perturbarDir(seg.x, seg.y, radio, mvx, mvy, fuerza);
        }
      }

      seg.actualizar();
    }

    // Enforce rope-like length constraints so the body can't "stretch" unnaturally
    aplicarRestriccionesCuerpo();
    // Keep inactive segments collapsed to the last active segment (avoids stray drawing)
    int nAct = constrain(segActivos, 1, segmentos.size());
    Segmento ancla = segmentos.get(nAct - 1);
    for (int i = nAct; i < segmentos.size(); i++) {
      Segmento s = segmentos.get(i);
      s.x = ancla.x;
      s.y = ancla.y;
      s.prevX = ancla.x;
      s.prevY = ancla.y;
      s.actualizar();
    }

    // Keep cached fluid values valid for inactive segments (match the last active segment)
    int last = max(0, nAct - 1);
    for (int i = nAct; i < numSegmentos; i++) {
      cacheVx[i] = cacheVx[last];
      cacheVy[i] = cacheVy[last];
      cacheH[i]  = cacheH[last];
    }
  }

  // Cache fluid velocity/height per segment (cheap: ~numSegmentos samples)
  void actualizarCacheFluido() {
    int n = min(segmentos.size(), numSegmentos);
    for (int i = 0; i < n; i++) {
      Segmento s = segmentos.get(i);
      PVector v = fluido.obtenerVelocidad(s.x, s.y);
      cacheVx[i] = v.x;
      cacheVy[i] = v.y;
      cacheH[i]  = fluido.obtenerAltura(s.x, s.y);
    }
  }

  // ------------------------------------------------------------
  // Body cohesion solver
  // - Keeps each segment ~longitudSegmento away from the previous one
  // - Applies small bend smoothing so the chain stays organic
  // - Also moves prevX/prevY by the same correction to avoid fake "teleport" wakes
  // ------------------------------------------------------------
  void aplicarRestriccionesCuerpo() {
    int nAct = constrain(segActivos, 1, segmentos.size());
    if (nAct <= 1) return;

    float rest = max(1, longitudSegmento);

    // A few relaxation passes = stable, cheap "rope" constraints
    for (int it = 0; it < constraintIters; it++) {
      for (int i = 1; i < nAct; i++) {
        Segmento a = segmentos.get(i - 1);
        Segmento b = segmentos.get(i);

        float dx = b.x - a.x;
        float dy = b.y - a.y;
        float d2 = dx*dx + dy*dy;
        if (d2 < 1e-6) continue;
        float d = sqrt(d2);

        float err = d - rest;
        float corr = (err / d) * constraintStiff;

        // Keep the head as the anchor; distribute correction for others
        float wa = (i == 1) ? 0.0 : 0.25;
        float wb = 1.0 - wa;

        float cx = dx * corr;
        float cy = dy * corr;

        // Move A slightly (except right behind head), and B more
        a.x += cx * wa;
        a.y += cy * wa;
        b.x -= cx * wb;
        b.y -= cy * wb;

        // Move previous positions too so velocity doesn't include the constraint correction
        a.prevX += cx * wa;
        a.prevY += cy * wa;
        b.prevX -= cx * wb;
        b.prevY -= cy * wb;
      }

      // Gentle bend smoothing pass (skips head + tail)
      if (bendSmooth > 1e-6 && nAct > 2) {
        for (int i = 1; i < nAct - 1; i++) {
          Segmento p = segmentos.get(i - 1);
          Segmento s = segmentos.get(i);
          Segmento n = segmentos.get(i + 1);

          float tx = (p.x + n.x) * 0.5;
          float ty = (p.y + n.y) * 0.5;

          float nxp = lerp(s.x, tx, bendSmooth);
          float nyp = lerp(s.y, ty, bendSmooth);

          float dxp = nxp - s.x;
          float dyp = nyp - s.y;

          s.x = nxp;
          s.y = nyp;
          s.prevX += dxp;
          s.prevY += dyp;
        }
      }
    }

    // Re-apply bounds after constraint corrections
    for (int i = 0; i < nAct; i++) {
      segmentos.get(i).actualizar();
    }
  }

  void nuevoObjetivo() {
    Segmento cabeza = segmentos.get(0);
    float anguloActual = atan2(objetivoY - cabeza.y, objetivoX - cabeza.x);
    float nuevoAngulo = anguloActual + random(-PI/3, PI/3);

    float distancia = random(100, 250);

    objetivoX = cabeza.x + cos(nuevoAngulo) * distancia;
    objetivoY = cabeza.y + sin(nuevoAngulo) * distancia;

    // Use boundsInset to keep objectives within movement area
    objetivoX = constrain(objetivoX, boundsInset, width - boundsInset);
    objetivoY = constrain(objetivoY, boundsInset, height - boundsInset);
  }

  void dibujarForma() {
    strokeWeight(1);

    // Precompute once per draw call (avoids per-point allocations/branch work)
    boolean isFire = (id == 4);
    // Fire gradient colors (white head -> orange/red tail)
    color fireC0 = color(255, 255, 255);
    color fireC1 = color(255, 230, 120);
    color fireC2 = color(255, 120, 0);
    color fireC3 = color(180, 20, 0);

    // As the jellyfish dies, it loses points (density) and segments (length)
    int nAct = constrain(segActivos, 1, numSegmentos);
    int puntosMaxBase = int(map(nAct, 1, numSegmentos, 1200, 10000));

    // Fade-in to prevent initial oversaturation (ADD blend + collapsed geometry)
    float fade = constrain(ageFrames / 45.0, 0, 1);
    // smoothstep for nicer ramp
    fade = fade * fade * (3.0 - 2.0 * fade);

    int puntosMax = max(80, int(puntosMaxBase * fade));

    for (int i = puntosMax; i > 0; i--) {
      float x_param = i % 200;
      float y_param = i / 43.0;

      float k = 5 * cos(x_param / 14) * cos(y_param / 30);
      float e = y_param / 8 - 13;
      float d = (k*k + e*e) / 59.0 + 4.0;
      float py = d * 45;

      float minPY = 100;
      float maxPY = 400;
      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);

      color cPoint;

      if (isFire) {
        float u = verticalProgression;
        if (u < 0.33)       cPoint = lerpColor(fireC0, fireC1, u / 0.33);
        else if (u < 0.66)  cPoint = lerpColor(fireC1, fireC2, (u - 0.33) / 0.33);
        else                cPoint = lerpColor(fireC2, fireC3, (u - 0.66) / 0.34);
      } else {
        cPoint = lerpColor(colorCabeza, colorCola, verticalProgression);
      }
      stroke(cPoint, 120 * fade * gusanosAlpha);

      // Map points only onto the currently active body
      int maxIdx = max(0, nAct - 1);
      int segmentIndex = int(verticalProgression * maxIdx);
      segmentIndex = constrain(segmentIndex, 0, maxIdx);
      Segmento seg = segmentos.get(segmentIndex);

      float segmentProgression = (verticalProgression * maxIdx) - segmentIndex;
      float x, y;

      if (segmentIndex < nAct - 1) {
        Segmento nextSeg = segmentos.get(segmentIndex + 1);
        x = lerp(seg.x, nextSeg.x, segmentProgression);
        y = lerp(seg.y, nextSeg.y, segmentProgression);
      } else {
        x = seg.x;
        y = seg.y;
      }

      // ---- FAST: use cached fluid samples (per segment) ----
      float vx, vy, h;
      if (segmentIndex < nAct - 1) {
        vx = lerp(cacheVx[segmentIndex], cacheVx[segmentIndex + 1], segmentProgression);
        vy = lerp(cacheVy[segmentIndex], cacheVy[segmentIndex + 1], segmentProgression);
        h  = lerp(cacheH[segmentIndex], cacheH[segmentIndex + 1], segmentProgression);
      } else {
        vx = cacheVx[segmentIndex];
        vy = cacheVy[segmentIndex];
        h  = cacheH[segmentIndex];
      }

      x += vx * 0.5;
      y += vy * 0.5 - h * 0.2;

      // For the "digital organism" variant (id == 4), use the original web-style
      // parametrization x=i, y=i/235 so the pattern reads correctly.
      float xIn = x_param;
      float yIn = y_param;
      if (id == 4) {
        xIn = i;
        yIn = i / 235.0;
      }

      dibujarPuntoForma(xIn, yIn, x, y);
    }

    // Head fades slightly when low life
    float life01 = constrain(vida / vidaMax, 0, 1);
    stroke(colorCabeza, (120 + 100 * life01) * fade);
    strokeWeight(max(1, 4 * shapeScale));
    point(segmentos.get(0).x, segmentos.get(0).y);
    strokeWeight(1);
  }

  void dibujarPuntoForma(float x, float y, float cx, float cy) {
    float k, e, d, q, px, py;
    float headOffset = 184; // may be overridden per-shape

    switch(id) {
    case 0:
      k = 5 * cos(x / 14) * cos(y / 30);
      e = y / 8 - 13;
      d = (k*k + e*e) / 59.0 + 4.0;
      q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
      px = q + 0.9;
      py = d * 45;
      break;

    case 1:
      k = 6 * cos(x / 12) * cos(y / 25);
      e = y / 7 - 15;
      d = (k*k + e*e) / 50.0 + 3.0;
      q = - 2 * sin(atan2(k, e) * e) + k * (2 + 5 / d * sin(d * d - t * 1.5));
      px = q + 1.2;
      py = d * 40;
      break;

    case 2:
      k = 4 * cos(x / 16) * cos(y / 35);
      e = y / 9 - 11;
      d = (k*k + e*e) / 65.0 + 5.0;
      q = - 4 * sin(atan2(k, e) * e) + k * (4 + 3 / d * sin(d * d - t * 2.5));
      px = q + 0.6;
      py = d * 50;
      break;

    case 3:
      k = 7 * cos(x / 10) * cos(y / 20);
      e = y / 6 - 17;
      d = (k*k + e*e) / 45.0 + 2.0;
      q = - 5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
      px = q + 1.5;
      py = d * 35;
      break;

    case 4:
      {
        // Digital organism (ported from the Processing web/p5 snippet)
        // a=(x,y,d=mag(k=(4+sin(y*2-t)*3)*cos(x/29),e=y/8-13))=>
        // point((q=3*sin(k*2)+.3/k+sin(y/25)*k*(9+4*sin(e*9-d*3+t*2)))+30*cos(c=d-t)+200,
        //       q*sin(c)+d*39-220)

        float k0 = (4.0 + sin(y * 2.0 - t) * 3.0) * cos(x / 29.0);
        float e0 = y / 8.0 - 13.0;
        float d0 = mag(k0, e0);

        // Safe reciprocal for 0.3/k
        float kk = (abs(k0) < 1e-3) ? ((k0 < 0) ? -1e-3 : 1e-3) : k0;

        float q0 = 3.0 * sin(k0 * 2.0)
          + 0.3 / kk
          + sin(y / 25.0) * k0 * (9.0 + 4.0 * sin(e0 * 9.0 - d0 * 3.0 + t * 2.0));

        float c0 = d0 - t;

        // Remove the original +200 / -220 screen centering constants;
        // we place this shape around (cx, cy) like the other variants.
        px = q0 + 30.0 * cos(c0);
        py = q0 * sin(c0) + d0 * 39.0;

        // Slightly different head offset so it sits nicely on the body
        headOffset = 220;
        break;
      }

    default:
      k = 5 * cos(x / 14) * cos(y / 30);
      e = y / 8 - 13;
      d = (k*k + e*e) / 59.0 + 4.0;
      q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
      px = q + 1.6;
      py = d * 45;
      break;
    }

    float s = shapeScale;
    point(px * s + cx, (py - headOffset) * s + cy);
  }

  // Respawn / reset body to a newborn that grows back
  void renacer() {
    float x = random(boundsInset, width - boundsInset);
    float y = random(boundsInset, height - boundsInset);
    ageFrames = 0;

    distribuirSegmentos(x, y);

    objetivoX = random(boundsInset, width - boundsInset);
    objetivoY = random(boundsInset, height - boundsInset);
    cambioObjetivo = 0;
    frecuenciaCambio = random(80, 120);


    // New personality each life
    temperamento = random(-1, 1);
    faseHumor = random(TWO_PI);

    // Start tiny and grow
    segActivos = 1;
    vida = vidaMax * 0.25;

    // Refresh cache right away (avoids one-frame mismatch after respawn)
    actualizarCacheFluido();
  }

  // Spread segments slightly along a random direction so the body is not fully collapsed at spawn/respawn.
  // This prevents huge localized over-bright regions when using blendMode(ADD).
  void distribuirSegmentos(float x, float y) {
    float ang = random(TWO_PI);
    float step = 4.0;
    for (int i = 0; i < segmentos.size(); i++) {
      Segmento s = segmentos.get(i);
      float px = x - cos(ang) * i * step;
      float py = y - sin(ang) * i * step;
      s.x = px;
      s.y = py;
      s.prevX = px;
      s.prevY = py;
    }
  }
  // ------------------------------------------------------------
  // Soft wall repulsion using the same margins as Segmento.actualizar()
  // Nudges segments inward BEFORE the clamp happens.
  // Main knobs: wallRange, wallPush
  // Also moves prevX/prevY to avoid fake "teleport" wakes.
  // ------------------------------------------------------------
  void aplicarRepulsionParedes() {
    int nAct = constrain(segActivos, 1, segmentos.size());

    float left   = boundsInset;
    float right  = width - boundsInset;
    float top    = boundsInset;
    float bottom = height - boundsInset;

    float r = max(1, wallRange);

    for (int i = 0; i < nAct; i++) {
      Segmento s = segmentos.get(i);

      // Stronger on head, softer on tail
      float tSeg = (nAct <= 1) ? 0 : (i / (float)(nAct - 1));
      float wSeg = lerp(1.0, 0.35, tSeg);

      float pushX = 0;
      float pushY = 0;

      float dL = s.x - left;
      float dR = right - s.x;
      float dT = s.y - top;
      float dB = bottom - s.y;

      if (dL < r) {
        float w = 1.0 - dL / r;
        w = w * w;
        pushX += w;
      }
      if (dR < r) {
        float w = 1.0 - dR / r;
        w = w * w;
        pushX -= w;
      }
      if (dT < r) {
        float w = 1.0 - dT / r;
        w = w * w;
        pushY += w;
      }
      if (dB < r) {
        float w = 1.0 - dB / r;
        w = w * w;
        pushY -= w;
      }

      float pm = sqrt(pushX*pushX + pushY*pushY);
      if (pm > 1e-6) {
        pushX /= pm;
        pushY /= pm;

        float strength = wallPush * wSeg;
        // Slightly stronger when relaxed so they don't lazily stick
        strength *= (0.85 + 0.35 * (1.0 - arousal));

        float dx = pushX * strength;
        float dy = pushY * strength;

        s.x += dx;
        s.y += dy;
        s.prevX += dx;
        s.prevY += dy;
      }
    }
  }

  // smoothstep 0..1 -> 0..1
  float smoothstep(float x) {
    x = constrain(x, 0, 1);
    return x * x * (3.0 - 2.0 * x);
  }
}
