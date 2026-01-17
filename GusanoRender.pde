

// ============================================================
// GusanoRender.pde
// ============================================================

class GusanoRender {
  Gusano g;
  GusanoRender(Gusano g_) { g = g_; }

  void dibujarForma() {
    strokeWeight(1);

    // Precompute once per draw call
    boolean isFire = (g.variant == 4);

    // Fire gradient colors (white head -> orange/red tail)
    color fireC0 = color(255, 255, 255);
    color fireC1 = color(255, 230, 120);
    color fireC2 = color(255, 120, 0);
    color fireC3 = color(180, 20, 0);

    // As the jellyfish dies, it loses points (density) and segments (length)
    int nAct = constrain(g.segActivos, 1, numSegmentos);

    int puntosMaxBase = int(map(nAct, 1, numSegmentos, 1200, 10000));

    // More gusanos => scale density down a bit for performance + ecosystem balance
    puntosMaxBase = int(puntosMaxBase * pointDensityMul * g.densityMul * (g.shapeScale * g.shapeScale) / (0.60 * 0.60));

    // Fade-in to prevent initial oversaturation (ADD blend + collapsed geometry)
    float fade = constrain(g.ageFrames / 45.0, 0, 1);
    fade = fade * fade * (3.0 - 2.0 * fade); // smoothstep

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
        cPoint = lerpColor(g.colorCabeza, g.colorCola, verticalProgression);
      }

      stroke(cPoint, 120 * fade * gusanosAlpha);

      // Map points only onto the currently active body
      int maxIdx = max(0, nAct - 1);
      int segmentIndex = int(verticalProgression * maxIdx);
      segmentIndex = constrain(segmentIndex, 0, maxIdx);
      Segmento seg = g.segmentos.get(segmentIndex);

      float segmentProgression = (verticalProgression * maxIdx) - segmentIndex;
      float x, y;

      if (segmentIndex < nAct - 1) {
        Segmento nextSeg = g.segmentos.get(segmentIndex + 1);
        x = lerp(seg.x, nextSeg.x, segmentProgression);
        y = lerp(seg.y, nextSeg.y, segmentProgression);
      } else {
        x = seg.x;
        y = seg.y;
      }

      // ---- FAST: use cached fluid samples (per segment) ----
      float vx, vy, h;
      if (segmentIndex < nAct - 1) {
        vx = lerp(g.cacheVx[segmentIndex], g.cacheVx[segmentIndex + 1], segmentProgression);
        vy = lerp(g.cacheVy[segmentIndex], g.cacheVy[segmentIndex + 1], segmentProgression);
        h  = lerp(g.cacheH[segmentIndex],  g.cacheH[segmentIndex + 1],  segmentProgression);
      } else {
        vx = g.cacheVx[segmentIndex];
        vy = g.cacheVy[segmentIndex];
        h  = g.cacheH[segmentIndex];
      }

      x += vx * 0.5;
      y += vy * 0.5 - h * 0.2;

      // For the "digital organism" variant (id == 4), use the original web-style
      // parametrization x=i, y=i/235 so the pattern reads correctly.
      float xIn = x_param;
      float yIn = y_param;
      if (g.variant == 4) {
        xIn = i;
        yIn = i / 235.0;
      }

      dibujarPuntoForma(xIn, yIn, x, y);
    }

    // Head fades slightly when low life
    float life01 = constrain(g.vida / g.vidaMax, 0, 1);
    stroke(g.colorCabeza, (120 + 100 * life01) * fade);
    strokeWeight(max(1, 4 * g.shapeScale));
    point(g.segmentos.get(0).x, g.segmentos.get(0).y);
    strokeWeight(1);
  }

  void dibujarPuntoForma(float x, float y, float cx, float cy) {
    float k, e, d, q, px, py;
    float headOffset = 184; // may be overridden per-shape

    switch(g.variant) {
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
        float k0 = (4.0 + sin(y * 2.0 - t) * 3.0) * cos(x / 29.0);
        float e0 = y / 8.0 - 13.0;
        float d0 = mag(k0, e0);

        // Safe reciprocal for 0.3/k
        float kk = (abs(k0) < 1e-3) ? ((k0 < 0) ? -1e-3 : 1e-3) : k0;

        float q0 = 3.0 * sin(k0 * 2.0)
          + 0.3 / kk
          + sin(y / 25.0) * k0 * (9.0 + 4.0 * sin(e0 * 9.0 - d0 * 3.0 + t * 2.0));

        float c0 = d0 - t;

        // Place around (cx, cy) like the other variants
        px = q0 + 30.0 * cos(c0);
        py = q0 * sin(c0) + d0 * 39.0;

        // Different head offset so it sits nicely on the body
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

    float s = g.shapeScale;
    point(px * s + cx, (py - headOffset) * s + cy);
  }
}