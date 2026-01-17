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
  // Variant/type (shape) separate from unique id
  int variant = 0;           // 0..4

  // Per-gusano variation knobs (ecosystem diversity)
  float speedMul = 1.0;      // movement speed multiplier
  float wanderMul = 1.0;     // how wide/long their wandering arcs are
  float socialMul = 1.0;     // scales social ranges/weights
  float densityMul = 1.0;    // scales rendered point density

  // --- Social fields ---
  float humor = 0;
  float temperamento = 0;
  float faseHumor = 0;
  float rangoSocial = 260;
  float rangoRepulsion = 120;
  float rangoChoque = 70;

  // --- User interaction attitude ---
  float userAttitude = 0;         // -1 (fearful) to 1 (curious)
  float userAttTarget = 0;        // NEW: target attitude pulled by interaction style

  // --- Pulse oscillator + arousal (burst/coast + smooth state) ---
  float phase = 0;
  float baseFreq = 0.045;   // radians per frame (will be modulated by arousal)
  float pulseAmp = 1.6;     // how much extra head travel during contraction
  float pulseK = 2.6;       // higher = snappier contraction

  float arousal = 0;        // 0..1 (fast attack, slow decay)
  float arousalAttack = 0.12;
  float arousalDecay  = 0.982;
  float arousalFollow = 0.15;   // sensitivity parameter (set by personality)
  float wUser = 0.75;
  float wSocial = 0.55;


  // --- Rhythm switching (user-dominant vs social-dominant) ---
  float userMode = 0;        // 0..1 (0 = schooling, 1 = interactive)
  float modeFollow = 0.10;   // smoothing for mode switching
  float domK = 1.35;         // userDominant if S_user > S_social * domK
  float domSoft = 0.30;      // softness for smooth dominance

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
  float syncRange = 180;        // range for phase sync (set by personality)
  
  // --- Social behavior weights (set by personality) ---
  float pesoSeparacion = 1.5;
  float pesoAlineacion = 1.0;
  float pesoCohesion = 0.6;
  
  // --- Body/movement smoothness (set by personality) ---
  float suavidadCuerpo = 0.25;
  float suavidadGiro = 0.15;

  // --- Body cohesion (prevents unnatural stretching) ---
  float longitudSegmento = 12;   // desired distance between segments (pixels)
  int   constraintIters  = 5;    // constraint relaxation iterations (higher = stiffer)
  float constraintStiff  = 0.85; // 0..1 how strongly we correct per iteration
  float bendSmooth       = 0.12; // 0..1 soft spine smoothing (keeps it organic)
  GusanoBehavior behavior;
  GusanoBody body;
  GusanoRender render;
  // --- Render scale (size) ---
  // Scale the whole gusano shape. 0.6 = 40% smaller.
  float shapeScale = 0.50;

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

  // --- Per-frame values produced by GusanoBehavior (used by body update) ---
  float spawnEaseNow = 1.0;
  float pulseNow = 0.0;
  float relaxNow = 1.0;
  float S_userNow = 0.0;
  float S_socialNow = 0.0;

  // Lonely mode transition tracking
  float rangoSocialOriginal;
  float wanderMulOriginal;
  float frecuenciaCambioOriginal;
  int lonelyTransitionStart = 0;
  float lonelyBlend = 0.0;
  
  // Scare resistance from personality
  float scareResistance = 0.5;
  
  // Social stress tracking
  float stress = 0.0;
  
  // Spawn tracking for grace period
  int spawnFrame = 0;
  
  // Personality name for debugging/visualization
  String personalityName = "Unknown";
  
  Gusano(float x, float y, color cHead, color cTail, int id_) {
    segmentos = new ArrayList<Segmento>();
    colorCabeza = cHead;
    colorCola = cTail;
    id = id_;
    // Shape variant distribution:
    // - Mostly 0..3 (classic shapes)
    // - Exactly one special "digital organism" (id == 4)
    variant = (id_ % 4);
    if (id_ == 4) variant = 4;

    // Size + behavior diversity (ecosystem feel)
    shapeScale = random(0.46, 0.70);
    speedMul   = random(0.78, 1.28);
    wanderMul  = random(0.75, 1.35);
    socialMul  = random(0.80, 1.35);
    densityMul = random(0.80, 1.15);

    // Make the special one a bit smaller and a tad more "nervous"
    if (variant == 4) {
      shapeScale = random(0.44, 0.60);
      speedMul   = random(0.92, 1.20);
      wanderMul  = random(0.90, 1.25);
      socialMul  = random(0.85, 1.20);
      densityMul = random(0.85, 1.10);
    }

    // Apply social scaling
    rangoSocial    *= socialMul;
    rangoRepulsion *= lerp(0.85, 1.20, socialMul);
    rangoChoque    *= lerp(0.85, 1.15, socialMul);

    // Let some be more/less reactive to the user
    userPushBase *= lerp(0.80, 1.25, random(1));
    flipGain     *= lerp(0.75, 1.35, random(1));

    // Slightly vary wall behavior
    wallRange *= lerp(0.85, 1.20, random(1));
    wallPush  *= lerp(0.80, 1.15, random(1));

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
    
    // Set spawn frame for grace period
    spawnFrame = frameCount;
    
    behavior = new GusanoBehavior(this);
    body = new GusanoBody(this);
    render = new GusanoRender(this);
  }

  void actualizar() {
    // Age for spawn/respawn ramps
    ageFrames++;

    // 1) Head + behavior + social/lifecycle (sets spawnEaseNow, pulseNow, etc.)
    behavior.actualizar();

    // 2) Body: segments + constraints + cache
    body.actualizar();
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
    float nuevoAngulo = anguloActual + random(-PI/3, PI/3) * wanderMul;
    float distancia = random(90, 260) * wanderMul;
    objetivoX = cabeza.x + cos(nuevoAngulo) * distancia;
    objetivoY = cabeza.y + sin(nuevoAngulo) * distancia;

    // Use boundsInset to keep objectives within movement area
    objetivoX = constrain(objetivoX, boundsInset, width - boundsInset);
    objetivoY = constrain(objetivoY, boundsInset, height - boundsInset);
  }

  void dibujarForma() {
    render.dibujarForma();
  }


  // Respawn / reset body to a newborn that grows back
  void renacer() {
    float x = random(boundsInset, width - boundsInset);
    float y = random(boundsInset, height - boundsInset);
    ageFrames = 0;
    
    // Reset spawn frame for grace period
    spawnFrame = frameCount;

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

  // Visual feedback helpers
  color getStateTint() {
    // Combine arousal, attitude, and stress into visual feedback
    float r = 255;
    float g = 255;
    float b = 255;
    
    // Curious (positive attitude) = warmer tint (more yellow/orange)
    if (userAttitude > 0) {
      r = 255;
      g = lerp(255, 200, userAttitude * 0.6);
      b = lerp(255, 150, userAttitude * 0.8);
    }
    // Fearful (negative attitude) = cooler tint (more blue/purple)
    else if (userAttitude < 0) {
      r = lerp(255, 180, abs(userAttitude) * 0.7);
      g = lerp(255, 180, abs(userAttitude) * 0.5);
      b = 255;
    }
    
    // Stressed = desaturate slightly (more gray)
    float stressFade = stress * 0.4;
    r = lerp(r, 200, stressFade);
    g = lerp(g, 200, stressFade);
    b = lerp(b, 200, stressFade);
    
    return color(r, g, b, 255);
  }
  
  float getGlowIntensity() {
    // More glow when aroused or curious
    float baseGlow = 1.0;
    baseGlow += arousal * 0.4;
    baseGlow += max(0, userAttitude) * 0.3;
    return baseGlow;
  }
}

