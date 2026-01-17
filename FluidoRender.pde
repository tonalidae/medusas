// ============================================================
// FluidoRender.pde
// Render delegate for Fluido (draw + per-frame render caches)
// ============================================================

class FluidoRender {
  final Fluido f;
  FluidoRender(Fluido f_) { f = f_; }

  void dibujar() {
    float w = f.cols * f.espaciado;
    float h = f.filas * f.espaciado;

    // Precompute height/gradients/slope once per frame for rendering
    actualizarCamposRender();

    pushStyle();
    clip((int)f.offsetX, (int)f.offsetY, (int)w, (int)h);

    // Simple, renderer-safe draw path:
    // - NO textures
    // - NO beginShape()/vertex()

    noStroke();

    // Base water tint (very subtle so background still dominates)
    fill(10, 14, 30, 55);
    rect(f.offsetX, f.offsetY, w, h);

    // Lighting / ripple visibility: additive micro-highlights per cell
    blendMode(ADD);

    // Tunables (safe defaults)
    float slopeGain = 520;  // higher = brighter crests
    float crestPow  = 1.45; // higher = tighter bands, lower = softer
    float flowGain  = 70;   // higher = moving water stands out more

    // Draw one rect per grid cell (fast enough at 60x50)
    for (int j = 0; j < f.filas; j++) {
      for (int i = 0; i < f.cols; i++) {
        Particula p = f.particulas[i][j];

        float s = f.slopeCache[i][j];
        float v = sqrt(p.vx*p.vx + p.vy*p.vy);

        // highlight intensity from slope (lighting) + speed (motion)
        float hl = pow(constrain(s * 0.16, 0, 1), crestPow) * slopeGain + constrain(v * flowGain, 0, 180);

        // Map intensity to an ocean-ish gradient
        float u = constrain(hl / 240.0, 0, 1);
        color deep  = color(12, 45, 115);
        color light = color(210, 245, 255);
        color c = lerpColor(deep, light, pow(u, 0.85));

        float a = constrain(hl * 0.55, 0, 170);
        fill(c, a);

        // Cell rect centered on the particle's rest grid position
        rect(p.ox - f.espaciado * 0.5, p.oy - f.espaciado * 0.5, f.espaciado, f.espaciado);
      }
    }

    blendMode(BLEND);
    noClip();
    popStyle();
  }

  // Compute render-only field caches once per frame (used by dibujar())
  void actualizarCamposRender() {
    // 1) Height cache
    for (int i = 0; i < f.cols; i++) {
      for (int j = 0; j < f.filas; j++) {
        Particula p = f.particulas[i][j];
        f.hCache[i][j] = p.y - p.oy;
      }
    }

    // 2) Gradients + slope (central differences with clamped edges)
    float inv2dx = 1.0 / (2.0 * f.espaciado);
    for (int i = 0; i < f.cols; i++) {
      int iL = (i > 0) ? (i - 1) : 0;
      int iR = (i < f.cols - 1) ? (i + 1) : (f.cols - 1);
      for (int j = 0; j < f.filas; j++) {
        int jU = (j > 0) ? (j - 1) : 0;
        int jD = (j < f.filas - 1) ? (j + 1) : (f.filas - 1);

        float hL = f.hCache[iL][j];
        float hR = f.hCache[iR][j];
        float hU = f.hCache[i][jU];
        float hD = f.hCache[i][jD];

        float gx = (hR - hL) * inv2dx;
        float gy = (hD - hU) * inv2dx;

        f.gxCache[i][j] = gx;
        f.gyCache[i][j] = gy;
        f.slopeCache[i][j] = sqrt(gx * gx + gy * gy);
      }
    }
  }

  // --- field sampling helpers for shading / refraction (render-only) ---
  float heightAt(int i, int j) {
    i = constrain(i, 0, f.cols - 1);
    j = constrain(j, 0, f.filas - 1);
    return f.hCache[i][j];
  }

  float gradX(int i, int j) {
    i = constrain(i, 0, f.cols - 1);
    j = constrain(j, 0, f.filas - 1);
    return f.gxCache[i][j];
  }

  float gradY(int i, int j) {
    i = constrain(i, 0, f.cols - 1);
    j = constrain(j, 0, f.filas - 1);
    return f.gyCache[i][j];
  }

  float slopeMag(int i, int j) {
    i = constrain(i, 0, f.cols - 1);
    j = constrain(j, 0, f.filas - 1);
    return f.slopeCache[i][j];
  }
}
