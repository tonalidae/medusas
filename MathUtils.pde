float lerpAngle(float a, float b, float t) {
  float diff = b - a;
  if (diff > PI) diff -= TWO_PI;
  if (diff < -PI) diff += TWO_PI;
  return a + diff * t;
}

// Convert a per-60fps smoothing factor into a dt-scaled alpha.
float dtAlpha(float baseAlpha, float dt) {
  float a = constrain(baseAlpha, 0.0, 1.0);
  return 1.0 - pow(1.0 - a, dt * 60.0);
}

float wrap01(float v) {
  v = v % 1.0;
  if (v < 0) v += 1.0;
  return v;
}
