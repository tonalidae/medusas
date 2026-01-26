class Segmento {
  float x, y;
  float angulo;

  Segmento(float x_, float y_) {
    x = x_;
    y = y_;
    angulo = 0;
  }

  void seguir(float targetX, float targetY, float speed) {
    // Backward-compatible default smoothing
    seguir(targetX, targetY, speed, 0.7);
  }

  void seguir(float targetX, float targetY, float speed, float smooth) {
    float dx = targetX - x;
    float dy = targetY - y;
    angulo = atan2(dy, dx);

    float distancia = dist(x, y, targetX, targetY);
    if (distancia < 0.5) return;

    float fuerza = speed;
    if (distancia < 50) {
      fuerza = map(distancia, 0, 50, speed * 0.3, speed);
    }

    float step = min(distancia, fuerza);
    float stepScale = step / max(distancia, 0.0001);
    float s = constrain(smooth, 0.15, 0.95);

    x += dx * stepScale * s;
    y += dy * stepScale * s;
  }

  void actualizar() {
    actualizar(true);
  }

  void actualizar(boolean hard) {
    float left = clampMarginX;
    float right = width - clampMarginX;
    float top = clampMarginTop;
    float bottom = height - clampMarginBottom;
    if (hard) {
      x = constrain(x, left, right);
      y = constrain(y, top, bottom);
      return;
    }

    float softK = 0.25;
    float maxOvershoot = 60;
    if (x < left) x = lerp(x, left, softK);
    else if (x > right) x = lerp(x, right, softK);
    if (y < top) y = lerp(y, top, softK);
    else if (y > bottom) y = lerp(y, bottom, softK);

    // Last resort clamp if far outside (prevents runaway tails)
    if (x < left - maxOvershoot || x > right + maxOvershoot) {
      x = constrain(x, left, right);
    }
    if (y < top - maxOvershoot || y > bottom + maxOvershoot) {
      y = constrain(y, top, bottom);
    }
  }
}
