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
    // Backward-compatible: default uses the global velocidad
    seguir(targetX, targetY, velocidad);
  }

  void seguir(float targetX, float targetY, float speed) {
    // ===== TEST MODE: No segment movement =====
    /*
    // Track previous position for motion-based coupling
    prevX = x;
    prevY = y;
    float dx = targetX - x;
    float dy = targetY - y;
    angulo = atan2(dy, dx);

    float distancia = dist(x, y, targetX, targetY);

    float fuerza = speed;
    if (distancia < 50) {
      // less slowdown near the target so the head doesn't "crawl"
      fuerza = map(distancia, 0, 50, speed * 0.5, speed);
    }

    x += cos(angulo) * fuerza;
    y += sin(angulo) * fuerza;
    */
    // ===========================================
  }

  void actualizar() {
    // ===== TEST MODE: No bounds enforcement (segments stay put) =====
    /*
    // Larger margins so the *drawn* jellyfish (not just its segment points) stays on-screen.
    // Tune these if your shape constants change.

  x = constrain(x, boundsInset, width - boundsInset);
  y = constrain(y, boundsInset, height - boundsInset);

    // Keep previous position inside bounds too (avoids huge spikes when clamped)
    prevX = constrain(prevX, boundsInset, width - boundsInset);
    prevY = constrain(prevY, boundsInset, height - boundsInset);
    */
    // ================================================================
  }
}