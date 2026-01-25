int gridW = 160;
int gridH = 100;
float[][] wake;
float[][] wakeNext;
float wakeDecay = 0.985;
float wakeDiffuse = 0.20;
float wakeDeposit = 1.0;
float userDeposit = 2.0;
float swirlStrength = 0.6;
float pushStrength = 0.4;
float maxFlow = 1.2;
int lastFlowMeanSample = 0;

void initWakeGrid() {
  wake = new float[gridW][gridH];
  wakeNext = new float[gridW][gridH];
}

int gridX(float x) {
  return constrain((int)map(x, 0, width, 0, gridW - 1), 0, gridW - 1);
}

int gridY(float y) {
  return constrain((int)map(y, 0, height, 0, gridH - 1), 0, gridH - 1);
}

void depositWakePoint(float x, float y, float amount) {
  int gx = gridX(x);
  int gy = gridY(y);
  wake[gx][gy] += amount;
}

void depositWakeBlob(float x, float y, float radius, float amount) {
  int gx = gridX(x);
  int gy = gridY(y);
  float cellW = width / (float)gridW;
  float cellH = height / (float)gridH;
  int rx = max(1, (int)(radius / cellW));
  int ry = max(1, (int)(radius / cellH));
  for (int ix = -rx; ix <= rx; ix++) {
    int cx = gx + ix;
    if (cx < 0 || cx >= gridW) continue;
    for (int iy = -ry; iy <= ry; iy++) {
      int cy = gy + iy;
      if (cy < 0 || cy >= gridH) continue;
      float dx = ix * cellW;
      float dy = iy * cellH;
      float d = sqrt(dx * dx + dy * dy);
      if (d > radius) continue;
      float falloff = 1.0 - (d / radius);
      wake[cx][cy] += amount * falloff;
    }
  }
}

void updateWakeGrid() {
  for (int x = 0; x < gridW; x++) {
    for (int y = 0; y < gridH; y++) {
      float c = wake[x][y];
      float l = wake[max(0, x - 1)][y];
      float r = wake[min(gridW - 1, x + 1)][y];
      float u = wake[x][max(0, y - 1)];
      float d = wake[x][min(gridH - 1, y + 1)];
      float avg = (l + r + u + d) * 0.25;
      float v = c * (1.0 - wakeDiffuse) + avg * wakeDiffuse;
      wakeNext[x][y] = v * wakeDecay;
    }
  }
  float[][] tmp = wake;
  wake = wakeNext;
  wakeNext = tmp;
}

PVector sampleWakeGradient(float x, float y) {
  int gx = gridX(x);
  int gy = gridY(y);
  int x1 = max(0, gx - 1);
  int x2 = min(gridW - 1, gx + 1);
  int y1 = max(0, gy - 1);
  int y2 = min(gridH - 1, gy + 1);
  float gradX = wake[x2][gy] - wake[x1][gy];
  float gradY = wake[gx][y2] - wake[gx][y1];
  return new PVector(gradX, gradY);
}

PVector sampleFlow(float x, float y) {
  PVector g = sampleWakeGradient(x, y);
  PVector flow = new PVector(-g.y, g.x);
  flow.mult(swirlStrength);
  flow.add(PVector.mult(g, pushStrength));
  float m2 = flow.magSq();
  if (m2 > maxFlow * maxFlow) {
    flow.normalize();
    flow.mult(maxFlow);
  }
  return flow;
}

void drawWakeGrid() {
  noStroke();
  float cellW = width / (float)gridW;
  float cellH = height / (float)gridH;
  for (int x = 0; x < gridW; x++) {
    for (int y = 0; y < gridH; y++) {
      float v = wake[x][y];
      if (v <= 0.01) continue;
      float a = constrain(v * 20, 0, 120);
      fill(50, 80, 120, a);
      rect(x * cellW, y * cellH, cellW + 1, cellH + 1);
    }
  }
}

void debugMeasureFlowMean() {
  int now = millis();
  if (now - lastFlowMeanSample < 1000) return;
  lastFlowMeanSample = now;

  int cols = 12;
  int rows = 8;
  PVector sum = new PVector(0, 0);
  int count = 0;
  for (int ix = 0; ix < cols; ix++) {
    float x = (ix + 0.5) * width / (float)cols;
    for (int iy = 0; iy < rows; iy++) {
      float y = (iy + 0.5) * height / (float)rows;
      PVector f = sampleFlow(x, y);
      sum.add(f);
      count++;
    }
  }
  if (count > 0) {
    sum.div(count);
  }
  println("mean flow = (" + nf(sum.x, 1, 3) + ", " + nf(sum.y, 1, 3) + ")");
}
