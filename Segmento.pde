// ============================================================
// Segmento.pde
// ============================================================

class Segmento {
  float x, y;
  float angulo;

  Segmento(float x_, float y_) {
    x = x_;
    y = y_;
    angulo = 0;
  }

  void seguir(float targetX, float targetY) {
    float dx = targetX - x;
    float dy = targetY - y;
    angulo = atan2(dy, dx);

    float distancia = dist(x, y, targetX, targetY);

    float fuerza = velocidad;
    if (distancia < 50) {
      fuerza = map(distancia, 0, 50, velocidad * 0.3, velocidad);
    }

    x += cos(angulo) * fuerza;
    y += sin(angulo) * fuerza;
  }

  void actualizar() {
    x = constrain(x, 50, width - 50);
    y = constrain(y, 50, height - 50);
  }
}