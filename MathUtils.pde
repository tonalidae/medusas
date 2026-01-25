float lerpAngle(float a, float b, float t) {
  float diff = b - a;
  if (diff > PI) diff -= TWO_PI;
  if (diff < -PI) diff += TWO_PI;
  return a + diff * t;
}

float wrap01(float v) {
  v = v % 1.0;
  if (v < 0) v += 1.0;
  return v;
}
