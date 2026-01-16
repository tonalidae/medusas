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

  // --- Body cohesion (prevents unnatural stretching) ---
  float longitudSegmento = 12;   // desired distance between segments (pixels)
  int   constraintIters  = 5;    // constraint relaxation iterations (higher = stiffer)
  float constraintStiff  = 0.85; // 0..1 how strongly we correct per iteration
  float bendSmooth       = 0.12; // 0..1 soft spine smoothing (keeps it organic)

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

    objetivoX = random(100, width-100);
    objetivoY = random(100, height-100);
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
  }

  void actualizar() {
    ageFrames++;
    cambioObjetivo++;
    Segmento cabeza = segmentos.get(0);
    float distanciaAlObjetivo = dist(cabeza.x, cabeza.y, objetivoX, objetivoY);

    if (cambioObjetivo > frecuenciaCambio || distanciaAlObjetivo < 20) {
      nuevoObjetivo();
      cambioObjetivo = 0;
    }

    PVector velocidadFluido = fluido.obtenerVelocidad(cabeza.x, cabeza.y);
    float alturaFluido =
      fluido.obtenerAltura(cabeza.x, cabeza.y);

    float objetivoConFluidoX = objetivoX + velocidadFluido.x * 15;
    float objetivoConFluidoY = objetivoY + velocidadFluido.y * 15;
    objetivoConFluidoY -= alturaFluido * 0.5;

    cabeza.seguir(objetivoConFluidoX, objetivoConFluidoY);

    // --- Fluid drag: nudge the segment motion toward local fluid velocity ---
    // (Head has the weakest drag; tail will be stronger below)
    {
      PVector vF = fluido.obtenerVelocidad(cabeza.x, cabeza.y);
      float drag = 0.06;

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
        float fuerza = constrain(sp * 1.8, 0, 6.0);
        fluido.perturbarDir(cabeza.x, cabeza.y, radio, mvx, mvy, fuerza);
      }
    }

    cabeza.actualizar();

    if (random(1) < 0.03) {
      objetivoX += random(-30, 30);
      objetivoY += random(-30, 30);
      objetivoX = constrain(objetivoX, 220, width - 220);
      objetivoY = constrain(objetivoY, 240, height - 280);
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

    // Stress accumulates when too close to others (used to drain vida)
    float stress = 0;

    // Own head velocity (approx) for alignment steering
    float myVx = cabeza.x - cabeza.prevX;
    float myVy = cabeza.y - cabeza.prevY;

    // Occasional cohesion to avoid constant clumping
    boolean doCohesion = (frameCount % 12 == (id % 12));

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
        sep.x -= (dx / d) * (w * 2.2);
        sep.y -= (dy / d) * (w * 2.2);

        // closeness costs energy (non-violent: just "fatigue")
        stress += w;
      }

      // --- Alignment + Cohesion (social range, mild) ---
      if (d < rangoSocial) {
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

    // Build the final social steering vector
    PVector social = new PVector(0, 0);

    // Weights tuned for stability (avoid spiraling / clumping)
    float wSep = 1.35;
    float wAli = 0.55;
    float wCoh = 0.30;

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
      float maxSocial = 1.6 + 0.7 * temperamento; // temperamento slightly affects boldness
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

    // Update body segments (only active ones)
    for (int i = 1; i < min(segActivos, segmentos.size()); i++) {
      Segmento seg = segmentos.get(i);
      Segmento segAnterior = segmentos.get(i - 1);

      PVector velFluidoSeg = fluido.obtenerVelocidad(seg.x, seg.y);
      float alturaFluidoSeg = fluido.obtenerAltura(seg.x, seg.y);

      float targetX = segAnterior.x + velFluidoSeg.x * 10;
      float targetY = segAnterior.y + velFluidoSeg.y * 10 - alturaFluidoSeg * 0.3;

      seg.seguir(targetX, targetY);

      // --- Fluid drag + wake (stronger toward the tail) ---
      {
        float tailT = (segmentos.size() <= 1) ? 1.0 : (i / (float)(segmentos.size() - 1));

        PVector vF = fluido.obtenerVelocidad(seg.x, seg.y);
        float drag = lerp(0.08, 0.22, tailT);

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
          float fuerza = constrain(sp * lerp(1.2, 2.2, tailT), 0, 5.5);
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

    // ---- Update fluid cache ONCE per frame (per segment) ----
    actualizarCacheFluido();
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

    // Match Segmento margins so the full jellyfish stays visible
    objetivoX = constrain(objetivoX, 220, width - 220);
    objetivoY = constrain(objetivoY, 240, height - 280);
  }

  void dibujarForma() {
    strokeWeight(1);

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
      float d = sq(mag(k, e)) / 59 + 4;
      float py = d * 45;

      float minPY = 100;
      float maxPY = 400;
      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);

      color cPoint = lerpColor(colorCabeza, colorCola, verticalProgression);
      stroke(cPoint, 120 * fade);

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
        h  = lerp(cacheH[segmentIndex],  cacheH[segmentIndex + 1],  segmentProgression);
      } else {
        vx = cacheVx[segmentIndex];
        vy = cacheVy[segmentIndex];
        h  = cacheH[segmentIndex];
      }

      x += vx * 0.5;
      y += vy * 0.5 - h * 0.2;

      dibujarPuntoForma(x_param, y_param, x, y);
    }

    // Head fades slightly when low life
    float life01 = constrain(vida / vidaMax, 0, 1);
    stroke(colorCabeza, (120 + 100 * life01) * fade);
    strokeWeight(4);
    point(segmentos.get(0).x, segmentos.get(0).y);
    strokeWeight(1);
  }

  void dibujarPuntoForma(float x, float y, float cx, float cy) {
    float k, e, d, q, px, py;
    float headOffset = 184;

    switch(id) {
    case 0:
      k = 5 * cos(x / 14) * cos(y / 30);
      e = y / 8 - 13;
      d = sq(mag(k, e)) / 59 + 4;
      q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
      px = q + 0.9;
      py = d * 45;
      break;

    case 1:
      k = 6 * cos(x / 12) * cos(y / 25);
      e = y / 7 - 15;
      d = sq(mag(k, e)) / 50 + 3;
      q = - 2 * sin(atan2(k, e) * e) + k * (2 + 5 / d * sin(d * d - t * 1.5));
      px = q + 1.2;
      py = d * 40;
      break;

    case 2:
      k = 4 * cos(x / 16) * cos(y / 35);
      e = y / 9 - 11;
      d = sq(mag(k, e)) / 65 + 5;
      q = - 4 * sin(atan2(k, e) * e) + k * (4 + 3 / d * sin(d * d - t * 2.5));
      px = q + 0.6;
      py = d * 50;
      break;

    case 3:
      k = 7 * cos(x / 10) * cos(y / 20);
      e = y / 6 - 17;
      d = sq(mag(k, e)) / 45 + 2;
      q = - 5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
      px = q + 1.5;
      py = d * 35;
      break;

    case 4:
      k = 7 * cos(x / 10) * cos(y / 3);
      e = y / 5 - 17;
      d = sq(mag(k, e)) / 45 + 2;
      q = - 5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
      px = q + 1.5;
      py = d * 35;
      break;

    default:
      k = 5 * cos(x / 14) * cos(y / 30);
      e = y / 8 - 13;
      d = sq(mag(k, e)) / 59 + 4;
      q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
      px = q + 1.6;
      py = d * 45;
      break;
    }

    point(px + cx, py - headOffset + cy);
  }

  // Respawn / reset body to a newborn that grows back
  void renacer() {
    float x = random(220, width - 220);
    float y = random(240, height - 280);
    ageFrames = 0;

    distribuirSegmentos(x, y);

    objetivoX = random(220, width - 220);
    objetivoY = random(240, height - 280);
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
}