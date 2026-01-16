// ============================================================
// Segmento.pde
// ============================================================

class Segmento {
  float x, y;
  float prevX, prevY;
  float angulo;

  Segmento(float x_, float y_) {
    x = x_;
    y = y_;
    prevX = x;
    prevY = y;
    angulo = 0;
  }

  void seguir(float targetX, float targetY) {
    // Track previous position for motion-based coupling
    prevX = x;
    prevY = y;
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
    // Larger margins so the *drawn* jellyfish (not just its segment points) stays on-screen.
    // Tune these if your shape constants change.
    float mx = 220;
    float myTop = 240;
    float myBot = 280;

    x = constrain(x, mx, width - mx);
    y = constrain(y, myTop, height - myBot);

    // Keep previous position inside bounds too (avoids huge spikes when clamped)
    prevX = constrain(prevX, mx, width - mx);
    prevY = constrain(prevY, myTop, height - myBot);
  }
}