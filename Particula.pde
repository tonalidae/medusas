// ============================================================
// Particula.pde
// ============================================================

class Particula {
  float x, y;      // Posición actual
  float vx, vy;    // Velocidad
  float ox, oy;    // Posición original (reposo)

  Particula(float x_, float y_) {
    x = ox = x_;
    y = oy = y_;
    vx = vy = 0;
  }

  void actualizar() {
    x += vx;
    y += vy;

    float fx = (ox - x) * 0.08;
    float fy = (oy - y) * 0.05;

    vx += fx;
    vy += fy;

    vx *= 0.975;
    vy *= 0.985;

    float maxMov = 10;
    x = constrain(x, ox - maxMov, ox + maxMov);
    y = constrain(y, oy - maxMov, oy + maxMov);
  }
}