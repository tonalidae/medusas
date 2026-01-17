

// ============================================================
// FluidoPerturb.pde
// Perturbation delegate for Fluido (mouse/jellyfish impulses)
// ============================================================

class FluidoPerturb {
  final Fluido f;
  FluidoPerturb(Fluido f_) { f = f_; }

  void perturbar(float x, float y, float radio, float fuerza) {
    float gx = (x - f.offsetX) / f.espaciado;
    float gy = (y - f.offsetY) / f.espaciado;
    float gr = radio / f.espaciado;

    int iMin = constrain(floor(gx - gr) - 1, 0, f.cols - 1);
    int iMax = constrain(ceil (gx + gr) + 1, 0, f.cols - 1);
    int jMin = constrain(floor(gy - gr) - 1, 0, f.filas - 1);
    int jMax = constrain(ceil (gy + gr) + 1, 0, f.filas - 1);

    float r2 = radio * radio;

    for (int i = iMin; i <= iMax; i++) {
      for (int j = jMin; j <= jMax; j++) {
        Particula p = f.particulas[i][j];
        float dx = p.x - x;
        float dy = p.y - y;
        float d2 = dx * dx + dy * dy;

        if (d2 < r2) {
          float d = sqrt(max(d2, 1e-6));
          float w = 1.0 - d / radio;
          w = w * w; // smoother falloff

          float intensidad = fuerza * w;

          // radial push (water-like)
          float nx = dx / d;
          float ny = dy / d;
          p.vx += nx * intensidad * 0.40;
          p.vy += ny * intensidad * 0.40;

          // tiny upward pressure bias (subtle)
          p.vy += intensidad * 0.06;
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

    float ff = constrain(fuerza, -25, 25);
    float r = max(1, radio);

    float gx = (x - f.offsetX) / f.espaciado;
    float gy = (y - f.offsetY) / f.espaciado;
    float gr = r / f.espaciado;

    int iMin = constrain(floor(gx - gr) - 1, 0, f.cols - 1);
    int iMax = constrain(ceil (gx + gr) + 1, 0, f.cols - 1);
    int jMin = constrain(floor(gy - gr) - 1, 0, f.filas - 1);
    int jMax = constrain(ceil (gy + gr) + 1, 0, f.filas - 1);

    float r2 = r * r;

    for (int i = iMin; i <= iMax; i++) {
      for (int j = jMin; j <= jMax; j++) {
        Particula p = f.particulas[i][j];
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

          float push = ff * w * 0.85; // slightly weaker coupling so gusanos feel less "blocked"

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
}