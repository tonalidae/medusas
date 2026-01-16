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

  // --- Social interaction (medusa-medusa) ---
  // temperamento: -1 = agresiva (tiende a repeler), +1 = empática (tiende a acercarse)
  float temperamento;
  float faseHumor;

  // Social tuning (pure steering, no physics API changes)
  float rangoSocial = 260;
  float rangoRepulsion = 120;
  float rangoChoque = 70;

  Gusano(float x, float y, color cHead, color cTail, int id_) {
    segmentos = new ArrayList<Segmento>();
    colorCabeza = cHead;
    colorCola = cTail;
    id = id_;

    for (int i = 0; i < numSegmentos; i++) {
      segmentos.add(new Segmento(x, y));
    }

    objetivoX = random(100, width-100);
    objetivoY = random(100, height-100);
    cambioObjetivo = 0;
    frecuenciaCambio = random(80, 120);

    // Random personality per jellyfish
    temperamento = random(-1, 1);
    faseHumor = random(TWO_PI);
  }

  void actualizar() {
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

    // ------------------------------------------------------------
    // Social interaction: medusas se atraen/evitan según temperamento
    // - Siempre hay separación a corta distancia (evita solaparse)
    // - En rango medio: empáticas tienden a acercarse, agresivas a apartarse
    // - En choque muy cercano: si es agresiva, hace un "golpe" (splash) leve
    // ------------------------------------------------------------
    float humor = temperamento + 0.35 * sin(t * 0.35 + faseHumor);
    humor = constrain(humor, -1, 1);

    PVector social = new PVector(0, 0);

    // O(n^2) pero n es pequeño (numGusanos)
    for (Gusano otro : gusanos) {
      if (otro == this) continue;

      Segmento cOtro = otro.segmentos.get(0);
      float dx = cOtro.x - cabeza.x;
      float dy = cOtro.y - cabeza.y;
      float d = sqrt(dx*dx + dy*dy);
      if (d < 1e-3) continue;

      // Unit direction toward the other head
      float ux = dx / d;
      float uy = dy / d;

      // 1) Strong separation when too close
      if (d < rangoRepulsion) {
        float w = (rangoRepulsion - d) / rangoRepulsion;
        // push away (stronger when closer)
        social.x -= ux * (w * 1.8);
        social.y -= uy * (w * 1.8);
      }

      // 2) Mid-range interaction (depends on mood)
      if (d >= rangoRepulsion && d < rangoSocial) {
        float t01 = (d - rangoRepulsion) / max(1.0, (rangoSocial - rangoRepulsion));
        // Empathy: gentle cohesion; Aggression: gentle repulsion
        if (humor >= 0) {
          float coh = (0.55 + 0.45 * (1.0 - t01)) * humor; // a bit stronger when closer
          social.x += ux * coh;
          social.y += uy * coh;
        } else {
          float rep = (0.35 + 0.65 * (1.0 - t01)) * (-humor);
          social.x -= ux * rep;
          social.y -= uy * rep;
        }
      }

      // 3) "Choque" cercano: agresivas provocan un pequeño splash direccional
      if (humor < -0.35 && d < rangoChoque && frameCount % 8 == 0) {
        // push water away from the other (non-violent, just more energetic)
        fluido.perturbarDir(cabeza.x, cabeza.y, 26, -dx, -dy, 4.2);
      }
    }

    // Limit and scale the social steering
    float sm = sqrt(social.x*social.x + social.y*social.y);
    if (sm > 1e-6) {
      float maxS = 1.65;
      float k = min(1.0, maxS / sm);
      social.x *= k;
      social.y *= k;
    }

    // Convert steering into a target offset (pixels)
    float socialPix = 34;
    objetivoConFluidoX += social.x * socialPix;
    objetivoConFluidoY += social.y * socialPix;

    // Keep within same margins used elsewhere
    objetivoConFluidoX = constrain(objetivoConFluidoX, 220, width - 220);
    objetivoConFluidoY = constrain(objetivoConFluidoY, 240, height - 280);

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

    for (int i = 1; i < segmentos.size(); i++) {
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

    for (int i = 10000; i > 0; i--) {
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
      stroke(cPoint, 120);

      int segmentIndex = int(verticalProgression * (segmentos.size() - 1));
      Segmento seg = segmentos.get(segmentIndex);

      float segmentProgression = (verticalProgression * (segmentos.size() - 1)) - segmentIndex;
      float x, y;

      if (segmentIndex < segmentos.size() - 1) {
        Segmento nextSeg = segmentos.get(segmentIndex + 1);
        x = lerp(seg.x, nextSeg.x, segmentProgression);
        y = lerp(seg.y, nextSeg.y, segmentProgression);
      } else {
        x = seg.x;
        y = seg.y;
      }

      PVector velFluidoPunto = fluido.obtenerVelocidad(x, y);
      float alturaFluidoPunto = fluido.obtenerAltura(x, y);

      x += velFluidoPunto.x * 0.5;
      y += velFluidoPunto.y * 0.5 - alturaFluidoPunto * 0.2;

      dibujarPuntoForma(x_param, y_param, x, y);
    }

    stroke(colorCabeza, 220);
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
}