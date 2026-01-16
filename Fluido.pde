// ============================================================
// Fluido.pde
// - class Fluido (physics + render helpers + isolines)
// ============================================================

class Fluido {
  int cols, filas;
  float espaciado;
  Particula[][] particulas;
  ArrayList<Resorte> resortes;

  float offsetX, offsetY;

  float rigidez = 0.1;
  float propagacion = 0.04;
  float waveDrag = 0.015;

  float[][] tmpVx;
  float[][] tmpVy;

  // --- render-only helpers (no physics changes) ---
  PGraphics floorTex;      // subtle "pond bottom" texture (procedural)
  float floorScroll = 0;   // tiny drift (purely visual)
  // ----------------------------------------------

  Fluido(int c, int f, float esp) {
    cols = c;
    filas = f;
    espaciado = esp;

    float anchoMalla = cols * espaciado;
    float altoMalla  = filas * espaciado;

    offsetX = (width  - anchoMalla) / 2.0;
    offsetY = (height - altoMalla)  / 2.0;

    tmpVx = new float[cols][filas];
    tmpVy = new float[cols][filas];

    particulas = new Particula[cols][filas];
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < filas; j++) {
        float x = offsetX + i * espaciado;
        float y = offsetY + j * espaciado;
        particulas[i][j] = new Particula(x, y);
      }
    }

    resortes = new ArrayList<Resorte>();
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < filas; j++) {
        if (i < cols - 1) {
          resortes.add(new Resorte(particulas[i][j], particulas[i + 1][j], rigidez));
        }
        if (j < filas - 1) {
          resortes.add(new Resorte(particulas[i][j], particulas[i][j + 1], rigidez));
        }
        if (i < cols - 1 && j < filas - 1) {
          float kd = rigidez * 0.7;
          resortes.add(new Resorte(particulas[i][j],     particulas[i + 1][j + 1], kd));
          resortes.add(new Resorte(particulas[i + 1][j], particulas[i][j + 1],     kd));
        }
      }
    }

    // Procedural "pond bottom" texture (optional; no external assets)
    floorTex = createGraphics((int)(cols * espaciado), (int)(filas * espaciado));
    generarTexturaFondo();
  }

  void generarTexturaFondo() {
    floorTex.beginDraw();
    floorTex.noStroke();
    floorTex.background(245);

    floorTex.loadPixels();
    int w = floorTex.width;
    int h = floorTex.height;
    float ns = 0.018;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        float n  = noise(x * ns, y * ns);
        float n2 = noise(1000 + x * ns * 2.2, 2000 + y * ns * 2.2);
        float v  = 0.65 * n + 0.35 * n2;

        int r = (int)lerp(232, 248, v);
        int g = (int)lerp(228, 246, v);
        int b = (int)lerp(224, 244, v);
        floorTex.pixels[y * w + x] = color(r, g, b);
      }
    }
    floorTex.updatePixels();

    for (int k = 0; k < 140; k++) {
      float x = random(w);
      float y = random(h);
      float rr = random(6, 18);
      floorTex.fill(0, 10);
      floorTex.ellipse(x, y, rr, rr);
    }

    floorTex.endDraw();
  }

  void actualizar() {
    int sub = 2;
    for (int s = 0; s < sub; s++) {
      for (Resorte r : resortes) r.actualizar();
      for (int i = 0; i < cols; i++) {
        for (int j = 0; j < filas; j++) {
          particulas[i][j].actualizar();
        }
      }
      propagarOndas();
    }
  }

  void propagarOndas() {
    // Smooth/propagate BOTH vx and vy so wakes actually move through the medium.
    // This is still a cheap "diffusion" step, not a full fluid solver.
    for (int i = 1; i < cols - 1; i++) {
      for (int j = 1; j < filas - 1; j++) {
        Particula p = particulas[i][j];

        float vx = p.vx;
        float vy = p.vy;

        float avx = (particulas[i - 1][j].vx + particulas[i + 1][j].vx +
                     particulas[i][j - 1].vx + particulas[i][j + 1].vx) * 0.25;
        float avy = (particulas[i - 1][j].vy + particulas[i + 1][j].vy +
                     particulas[i][j - 1].vy + particulas[i][j + 1].vy) * 0.25;

        float nvx = vx + (avx - vx) * propagacion;
        float nvy = vy + (avy - vy) * propagacion;

        // keep the old damping behavior but apply it to both components
        float damp = (1.0 - waveDrag);
        nvx *= damp;
        nvy *= damp;

        tmpVx[i][j] = nvx;
        tmpVy[i][j] = nvy;
      }
    }

    for (int i = 1; i < cols - 1; i++) {
      for (int j = 1; j < filas - 1; j++) {
        particulas[i][j].vx = tmpVx[i][j];
        particulas[i][j].vy = tmpVy[i][j];
      }
    }
  }

  void perturbar(float x, float y, float radio, float fuerza) {
    float gx = (x - offsetX) / espaciado;
    float gy = (y - offsetY) / espaciado;
    float gr = radio / espaciado;

    int iMin = constrain(floor(gx - gr) - 1, 0, cols - 1);
    int iMax = constrain(ceil (gx + gr) + 1, 0, cols - 1);
    int jMin = constrain(floor(gy - gr) - 1, 0, filas - 1);
    int jMax = constrain(ceil (gy + gr) + 1, 0, filas - 1);

    float r2 = radio * radio;

    for (int i = iMin; i <= iMax; i++) {
      for (int j = jMin; j <= jMax; j++) {
        Particula p = particulas[i][j];
        float dx = x - p.x;
        float dy = y - p.y;
        float d2 = dx * dx + dy * dy;

        if (d2 < r2) {
          float d = sqrt(d2);
          float intensidad = fuerza * (1.0 - d / radio);

          p.vy += intensidad;
          float angulo = atan2(y - p.y, x - p.x);
          p.vx += cos(angulo) * intensidad * 0.3;
        }
      }
    }
  }

  // Directional wake perturbation (in addition to perturbar)
  void perturbarDir(float x, float y, float radio, float dirX, float dirY, float fuerza) {
    float m = sqrt(dirX*dirX + dirY*dirY);
    if (m < 1e-6) return;
    dirX /= m;
    dirY /= m;

    float f = constrain(fuerza, -25, 25);
    float r = max(1, radio);

    float gx = (x - offsetX) / espaciado;
    float gy = (y - offsetY) / espaciado;
    float gr = r / espaciado;

    int iMin = constrain(floor(gx - gr) - 1, 0, cols - 1);
    int iMax = constrain(ceil (gx + gr) + 1, 0, cols - 1);
    int jMin = constrain(floor(gy - gr) - 1, 0, filas - 1);
    int jMax = constrain(ceil (gy + gr) + 1, 0, filas - 1);

    float r2 = r * r;

    for (int i = iMin; i <= iMax; i++) {
      for (int j = jMin; j <= jMax; j++) {
        Particula p = particulas[i][j];
        float dx = x - p.x;
        float dy = y - p.y;
        float d2 = dx*dx + dy*dy;
        if (d2 < r2) {
          float d = sqrt(d2);
          float w = 1.0 - d / r;
          w *= w;

          // Anisotropy: stronger wake behind the motion direction (capsule-ish feel)
          float rx = p.x - x;
          float ry = p.y - y;
          float dot = rx * dirX + ry * dirY;
          // dot < 0 means "behind" (opposite the direction of motion)
          float behind = constrain((-dot) / (r * 0.75), 0, 1);
          float anis = 0.25 + 0.75 * behind;
          w *= anis;

          float push = f * w;

          // Main directional push
          p.vx += dirX * push;
          p.vy += dirY * push;

          // Tiny trailing swirl (adds life without full fluid sim)
          float perpX = -dirY;
          float perpY =  dirX;
          float swirl = push * 0.08 * behind;
          p.vx += perpX * swirl;
          p.vy += perpY * swirl;

          // Slight vertical pressure component (kept subtle)
          p.vy += push * 0.08;
        }
      }
    }
  }

  void dibujar() {
    float w = cols * espaciado;
    float h = filas * espaciado;

    pushStyle();
    clip((int)offsetX, (int)offsetY, (int)w, (int)h);

    floorScroll += 0.15;

    // Render-only subdivision: increases apparent fluid resolution without increasing physics cost.
    // 1 = current behavior, 2 = smoother (recommended), 3 = even smoother but more vertices.
    int renderSub = 2;

    // ------------------------------------------------------------
    // Combo:
    // 1) Caustics-style bottom texture with UV distortion driven by the field
    // 2) Slope-based highlight shading so waves read as lighting
    // (Physics unchanged)
    // ------------------------------------------------------------

    // 1) Distorted bottom texture (caustics / refraction feel)
    // Use original grid UVs (stable) + distortion from velocity + height gradient
    pushStyle();
    noStroke();
    textureMode(IMAGE);
    // Slightly brighter so distortion reads on dark backgrounds
    tint(255, 232);

    float scrollU = sin(floorScroll * 0.010) * 8;
    float scrollV = cos(floorScroll * 0.008) * 8;

    for (int j = 0; j < filas - 1; j++) {
      beginShape(TRIANGLE_STRIP);
      texture(floorTex);

      for (int i = 0; i < cols - 1; i++) {
        Particula a0 = particulas[i][j];
        Particula b0 = particulas[i + 1][j];
        Particula a1 = particulas[i][j + 1];
        Particula b1 = particulas[i + 1][j + 1];

        // Height gradient (for refraction direction)
        float gx_a0 = gradX(i,     j);
        float gy_a0 = gradY(i,     j);
        float gx_b0 = gradX(i + 1, j);
        float gy_b0 = gradY(i + 1, j);
        float gx_a1 = gradX(i,     j + 1);
        float gy_a1 = gradY(i,     j + 1);
        float gx_b1 = gradX(i + 1, j + 1);
        float gy_b1 = gradY(i + 1, j + 1);

        // Distortion drivers (flow + slope)
        float du_a0 = a0.vx * 34 + gx_a0 * 110;
        float dv_a0 = a0.vy * 34 + gy_a0 * 110;
        float du_b0 = b0.vx * 34 + gx_b0 * 110;
        float dv_b0 = b0.vy * 34 + gy_b0 * 110;

        float du_a1 = a1.vx * 34 + gx_a1 * 110;
        float dv_a1 = a1.vy * 34 + gy_a1 * 110;
        float du_b1 = b1.vx * 34 + gx_b1 * 110;
        float dv_b1 = b1.vy * 34 + gy_b1 * 110;

        int s0 = (i == 0) ? 0 : 1; // avoid duplicating the seam vertex
        for (int s = s0; s <= renderSub; s++) {
          float tt = s / (float)renderSub;

          // Interpolate positions along the top/bottom edges
          float x0 = lerp(a0.x, b0.x, tt);
          float y0 = lerp(a0.y, b0.y, tt);
          float x1 = lerp(a1.x, b1.x, tt);
          float y1 = lerp(a1.y, b1.y, tt);

          // Stable UV base from sub-cell coordinate
          float baseU = (i + tt) * espaciado;
          float baseV0 = j * espaciado;
          float baseV1 = (j + 1) * espaciado;

          // Interpolate distortion
          float du0 = lerp(du_a0, du_b0, tt);
          float dv0 = lerp(dv_a0, dv_b0, tt);
          float du1 = lerp(du_a1, du_b1, tt);
          float dv1 = lerp(dv_a1, dv_b1, tt);

          vertex(x0, y0, baseU + scrollU + du0, baseV0 + scrollV + dv0);
          vertex(x1, y1, baseU + scrollU + du1, baseV1 + scrollV + dv1);
        }
      }

      endShape();
    }

    noTint();
    popStyle();

    // 2) Subtle water veil (keeps the scene cohesive)
    noStroke();
    // Keep it subtle so highlights remain visible
    fill(18, 24, 44, 8);
    rect(offsetX, offsetY, w, h);

    // 3) Slope-based highlights (waves show as lighting, not contour lines)
    pushStyle();
    blendMode(ADD);
    noStroke();

    float hScale = 1.0;
    float slopeGain = 430;   // stronger highlights so waves read as light
    float crestPow  = 1.7;   // slightly softer = smoother light bands
    float flowGain  = 55;    // makes moving water stand out (speed-based)

    for (int j = 0; j < filas - 1; j++) {
      beginShape(TRIANGLE_STRIP);
      for (int i = 0; i < cols - 1; i++) {
        Particula a0 = particulas[i][j];
        Particula b0 = particulas[i + 1][j];
        Particula a1 = particulas[i][j + 1];
        Particula b1 = particulas[i + 1][j + 1];

        float s_a0 = slopeMag(i,     j) * hScale;
        float s_b0 = slopeMag(i + 1, j) * hScale;
        float s_a1 = slopeMag(i,     j + 1) * hScale;
        float s_b1 = slopeMag(i + 1, j + 1) * hScale;

        float v_a0 = sqrt(a0.vx*a0.vx + a0.vy*a0.vy);
        float v_b0 = sqrt(b0.vx*b0.vx + b0.vy*b0.vy);
        float v_a1 = sqrt(a1.vx*a1.vx + a1.vy*a1.vy);
        float v_b1 = sqrt(b1.vx*b1.vx + b1.vy*b1.vy);

        int s0 = (i == 0) ? 0 : 1; // avoid duplicating the seam vertex
        for (int s = s0; s <= renderSub; s++) {
          float tt = s / (float)renderSub;

          // Interpolated positions along edges
          float x0 = lerp(a0.x, b0.x, tt);
          float y0 = lerp(a0.y, b0.y, tt);
          float x1 = lerp(a1.x, b1.x, tt);
          float y1 = lerp(a1.y, b1.y, tt);

          // Interpolated slope + speed
          float sTop = lerp(s_a0, s_b0, tt);
          float sBot = lerp(s_a1, s_b1, tt);
          float vTop = lerp(v_a0, v_b0, tt);
          float vBot = lerp(v_a1, v_b1, tt);

          float hl0 = pow(constrain(sTop * 0.14, 0, 1), crestPow) * slopeGain + constrain(vTop * flowGain, 0, 120);
          float hl1 = pow(constrain(sBot * 0.14, 0, 1), crestPow) * slopeGain + constrain(vBot * flowGain, 0, 120);

          fill(80 + hl0 * 0.25, 140 + hl0 * 0.35, 220 + hl0 * 0.55, constrain(hl0 * 0.98, 0, 200));
          vertex(x0, y0);

          fill(80 + hl1 * 0.25, 140 + hl1 * 0.35, 220 + hl1 * 0.55, constrain(hl1 * 0.98, 0, 200));
          vertex(x1, y1);
        }
      }
      endShape();
    }

    blendMode(BLEND);
    popStyle();

    noClip();
    popStyle();
  }

  // ============================================================
  // OPTION 3: traced isolines + curveVertex (smooth rings)
  // (kept in file; not used by current dibujar() shading)
  // ============================================================
  void dibujarIsolinea(float lvl, float hScale) {
    ArrayList<Seg> segs = new ArrayList<Seg>();

    // Build segments via marching squares
    for (int i = 0; i < cols - 1; i++) {
      for (int j = 0; j < filas - 1; j++) {
        Particula p00 = particulas[i][j];
        Particula p10 = particulas[i + 1][j];
        Particula p11 = particulas[i + 1][j + 1];
        Particula p01 = particulas[i][j + 1];

        float a = (p00.y - p00.oy) * hScale;
        float b = (p10.y - p10.oy) * hScale;
        float c = (p11.y - p11.oy) * hScale;
        float d = (p01.y - p01.oy) * hScale;

        int idx = 0;
        if (a > lvl) idx |= 1;
        if (b > lvl) idx |= 2;
        if (c > lvl) idx |= 4;
        if (d > lvl) idx |= 8;

        if (idx == 0 || idx == 15) continue;

        float center = (a + b + c + d) * 0.25;

        // Edge intersections
        PVector AB = null, BC = null, CD = null, DA = null;

        if (edgeCross(a, b, lvl)) {
          float t = safeT((lvl - a) / (b - a));
          AB = new PVector(lerp(p00.x, p10.x, t), lerp(p00.y, p10.y, t));
        }
        if (edgeCross(b, c, lvl)) {
          float t = safeT((lvl - b) / (c - b));
          BC = new PVector(lerp(p10.x, p11.x, t), lerp(p10.y, p11.y, t));
        }
        if (edgeCross(c, d, lvl)) {
          float t = safeT((lvl - c) / (d - c));
          CD = new PVector(lerp(p11.x, p01.x, t), lerp(p11.y, p01.y, t));
        }
        if (edgeCross(d, a, lvl)) {
          float t = safeT((lvl - d) / (a - d));
          DA = new PVector(lerp(p01.x, p00.x, t), lerp(p01.y, p00.y, t));
        }

        switch (idx) {
        case 1:
        case 14:
          addSeg(segs, DA, AB);
          break;

        case 2:
        case 13:
          addSeg(segs, AB, BC);
          break;

        case 3:
        case 12:
          addSeg(segs, DA, BC);
          break;

        case 4:
        case 11:
          addSeg(segs, BC, CD);
          break;

        case 6:
        case 9:
          addSeg(segs, AB, CD);
          break;

        case 7:
        case 8:
          addSeg(segs, DA, CD);
          break;

        case 5:
        case 10:
          if (center > lvl) {
            addSeg(segs, DA, AB);
            addSeg(segs, BC, CD);
          } else {
            addSeg(segs, DA, CD);
            addSeg(segs, AB, BC);
          }
          break;

        default:
          break;
        }
      }
    }

    // Stitch into paths
    ArrayList<ArrayList<PVector>> paths = stitchSegmentsToPaths(segs);

    // Render with curveVertex (smooth)
    for (ArrayList<PVector> path : paths) {
      if (path.size() < 3) continue;

      boolean closed = isClosed(path);

      beginShape();
      noFill();

      if (closed) {
        PVector last = path.get(path.size() - 1);
        PVector first = path.get(0);
        PVector second = path.get(1);

        curveVertex(last.x, last.y);
        for (PVector p : path) curveVertex(p.x, p.y);
        curveVertex(first.x, first.y);
        curveVertex(second.x, second.y);
      } else {
        PVector first = path.get(0);
        PVector last  = path.get(path.size() - 1);

        curveVertex(first.x, first.y);
        for (PVector p : path) curveVertex(p.x, p.y);
        curveVertex(last.x, last.y);
      }

      endShape();
    }
  }

  // --- helpers for smooth contour tracing ---
  class Seg {
    PVector a, b;
    Seg(PVector a_, PVector b_) { a = a_; b = b_; }
  }

  boolean edgeCross(float v0, float v1, float lvl) {
    return (v0 > lvl) != (v1 > lvl);
  }

  float safeT(float t) {
    if (Float.isNaN(t)) return 0.5;
    return constrain(t, 0, 1);
  }

  void addSeg(ArrayList<Seg> segs, PVector p, PVector q) {
    if (p == null || q == null) return;
    if (p.dist(q) < 1e-6) return;
    segs.add(new Seg(p, q));
  }

  String keyOf(PVector p) {
    int qx = round(p.x * 1000.0);
    int qy = round(p.y * 1000.0);
    return qx + "," + qy;
  }

  ArrayList<ArrayList<PVector>> stitchSegmentsToPaths(ArrayList<Seg> segs) {
    ArrayList<ArrayList<PVector>> paths = new ArrayList<ArrayList<PVector>>();
    if (segs.isEmpty()) return paths;

    HashMap<String, ArrayList<Seg>> bucket = new HashMap<String, ArrayList<Seg>>();
    for (Seg s : segs) {
      String ka = keyOf(s.a);
      String kb = keyOf(s.b);
      if (!bucket.containsKey(ka)) bucket.put(ka, new ArrayList<Seg>());
      if (!bucket.containsKey(kb)) bucket.put(kb, new ArrayList<Seg>());
      bucket.get(ka).add(s);
      bucket.get(kb).add(s);
    }

    HashSet<Seg> used = new HashSet<Seg>();

    for (Seg start : segs) {
      if (used.contains(start)) continue;

      ArrayList<PVector> path = new ArrayList<PVector>();
      used.add(start);

      path.add(start.a.copy());
      path.add(start.b.copy());

      growPathForward(path, bucket, used);

      reverseList(path);
      growPathForward(path, bucket, used);
      reverseList(path);

      for (int i = path.size() - 2; i >= 0; i--) {
        if (path.get(i).dist(path.get(i + 1)) < 1e-6) path.remove(i + 1);
      }

      paths.add(path);
    }

    return paths;
  }

  void growPathForward(ArrayList<PVector> path,
    HashMap<String, ArrayList<Seg>> bucket,
    HashSet<Seg> used) {

    while (true) {
      PVector end = path.get(path.size() - 1);
      String kEnd = keyOf(end);
      ArrayList<Seg> candidates = bucket.get(kEnd);
      if (candidates == null) break;

      Seg next = null;
      boolean endIsA = false;

      for (Seg s : candidates) {
        if (used.contains(s)) continue;
        if (keyOf(s.a).equals(kEnd)) { next = s; endIsA = true; break; }
        if (keyOf(s.b).equals(kEnd)) { next = s; endIsA = false; break; }
      }

      if (next == null) break;

      used.add(next);

      PVector other = endIsA ? next.b : next.a;
      path.add(other.copy());

      if (path.size() > 3 && keyOf(path.get(0)).equals(keyOf(path.get(path.size() - 1)))) {
        path.remove(path.size() - 1);
        break;
      }
    }
  }

  boolean isClosed(ArrayList<PVector> path) {
    if (path.size() < 4) return false;
    return path.get(0).dist(path.get(path.size() - 1)) < 0.75;
  }

  void reverseList(ArrayList<PVector> list) {
    for (int i = 0, j = list.size() - 1; i < j; i++, j--) {
      PVector tmp = list.get(i);
      list.set(i, list.get(j));
      list.set(j, tmp);
    }
  }

  // --- field sampling helpers for shading / refraction (render-only) ---
  float heightAt(int i, int j) {
    i = constrain(i, 0, cols - 1);
    j = constrain(j, 0, filas - 1);
    return particulas[i][j].y - particulas[i][j].oy;
  }

  // Height gradient components (central differences)
  float gradX(int i, int j) {
    float hL = heightAt(i - 1, j);
    float hR = heightAt(i + 1, j);
    return (hR - hL) / (2.0 * espaciado);
  }

  float gradY(int i, int j) {
    float hU = heightAt(i, j - 1);
    float hD = heightAt(i, j + 1);
    return (hD - hU) / (2.0 * espaciado);
  }

  // Gradient magnitude (slope) used for highlights
  float slopeMag(int i, int j) {
    float gx = gradX(i, j);
    float gy = gradY(i, j);
    return sqrt(gx*gx + gy*gy);
  }

  // API methods (unchanged)
  PVector obtenerVelocidad(float x, float y) {
    float gx = (x - offsetX) / espaciado;
    float gy = (y - offsetY) / espaciado;

    int i0 = constrain(floor(gx), 0, cols - 1);
    int j0 = constrain(floor(gy), 0, filas - 1);
    int i1 = constrain(i0 + 1, 0, cols - 1);
    int j1 = constrain(j0 + 1, 0, filas - 1);

    float sx = gx - i0;
    float sy = gy - j0;

    Particula p00 = particulas[i0][j0];
    Particula p10 = particulas[i1][j0];
    Particula p01 = particulas[i0][j1];
    Particula p11 = particulas[i1][j1];

    float vx0 = lerp(p00.vx, p10.vx, sx);
    float vx1 = lerp(p01.vx, p11.vx, sx);
    float vy0 = lerp(p00.vy, p10.vy, sx);
    float vy1 = lerp(p01.vy, p11.vy, sx);

    return new PVector(lerp(vx0, vx1, sy), lerp(vy0, vy1, sy));
  }

  float obtenerAltura(float x, float y) {
    float gx = (x - offsetX) / espaciado;
    float gy = (y - offsetY) / espaciado;

    int i0 = constrain(floor(gx), 0, cols - 1);
    int j0 = constrain(floor(gy), 0, filas - 1);
    int i1 = constrain(i0 + 1, 0, cols - 1);
    int j1 = constrain(j0 + 1, 0, filas - 1);

    float sx = gx - i0;
    float sy = gy - j0;

    float h00 = particulas[i0][j0].y - particulas[i0][j0].oy;
    float h10 = particulas[i1][j0].y - particulas[i1][j0].oy;
    float h01 = particulas[i0][j1].y - particulas[i0][j1].oy;
    float h11 = particulas[i1][j1].y - particulas[i1][j1].oy;

    float h0 = lerp(h00, h10, sx);
    float h1 = lerp(h01, h11, sx);
    return lerp(h0, h1, sy);
  }
}