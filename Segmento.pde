class Segmento {
  float x, y;
  float angulo;

  Segmento(float x_, float y_) {
    x = x_;
    y = y_;
    angulo = 0;
  }

  void seguir(float targetX, float targetY, float speed) {
    float dx = targetX - x;
    float dy = targetY - y;
    angulo = atan2(dy, dx);

    float distancia = dist(x, y, targetX, targetY);
    if (distancia < 0.5) return;

    float fuerza = speed;
    if (distancia < 50) {
      fuerza = map(distancia, 0, 50, speed * 0.3, speed);
    }
    // Clamp step to avoid overshoot + add smoothing to reduce jitter
    float step = min(distancia, fuerza);
    float stepScale = step / max(distancia, 0.0001);
    float smooth = 0.7;
    x += dx * stepScale * smooth;
    y += dy * stepScale * smooth;
  }

  void actualizar() {
    float left = clampMarginX;
    float right = width - clampMarginX;
    float top = clampMarginTop;
    float bottom = height - clampMarginBottom;
    x = constrain(x, left, right);
    y = constrain(y, top, bottom);
  }
}
