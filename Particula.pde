// ============================================================
// Particula.pde
// ============================================================

class Particula {
  float x, y;      // Posición actual
  float vx, vy;    // Velocidad
  float ox, oy;    // Posición original (reposo)

  // Soft displacement limit (prevents "frozen" regions caused by hard constrain())
    float maxMov = 10;        // max displacement from (ox, oy)
    float limitK = 0.55;      // how much overshoot becomes a corrective velocity impulse
    float limitDamp = 0.35;   // damp outward velocity when hitting the limit

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

    // Slightly stronger damping for a calmer medium
    vx *= 0.970;
    vy *= 0.980;

    // --- Soft limit instead of hard clamp ---
    // Hard constrain() can create stuck/flat areas when many particles saturate.
    // Here we convert overshoot into a small corrective velocity impulse, so energy
    // can still propagate through the field.

    float dx = x - ox;
    if (dx > maxMov) {
      float over = dx - maxMov;
      x = ox + maxMov;
      // push back toward rest; remove outward component
      vx -= over * limitK;
      if (vx > 0) vx *= limitDamp;
    } else if (dx < -maxMov) {
      float over = (-maxMov) - dx;
      x = ox - maxMov;
      vx += over * limitK;
      if (vx < 0) vx *= limitDamp;
    }

    float dy = y - oy;
    if (dy > maxMov) {
      float over = dy - maxMov;
      y = oy + maxMov;
      vy -= over * limitK;
      if (vy > 0) vy *= limitDamp;
    } else if (dy < -maxMov) {
      float over = (-maxMov) - dy;
      y = oy - maxMov;
      vy += over * limitK;
      if (vy < 0) vy *= limitDamp;
    }
  }
}