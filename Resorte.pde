// ============================================================
// Resorte.pde
// ============================================================

class Resorte {
  Particula a, b;
  float longitudReposo;
  float rigidez;

  Resorte(Particula a_, Particula b_, float rigidez_) {
    a = a_;
    b = b_;
    rigidez = rigidez_;
    longitudReposo = dist(a.x, a.y, b.x, b.y);
  }

  void actualizar() {
    float dx = b.x - a.x;
    float dy = b.y - a.y;
    float distancia = sqrt(dx*dx + dy*dy);

    if (distancia > 0) {
      float fuerza = rigidez * (distancia - longitudReposo);

      dx /= distancia;
      dy /= distancia;

      a.vx += dx * fuerza * 0.5;
      a.vy += dy * fuerza * 0.5;
      b.vx -= dx * fuerza * 0.5;
      b.vy -= dy * fuerza * 0.5;
    }
  }
}