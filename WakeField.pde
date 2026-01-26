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
PVector flowScratch = new PVector(0, 0);
PVector flowMeanScratch = new PVector(0, 0);

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
  float v = wake[gx][gy] + amount;
  if (wakeClamp > 0) v = min(wakeClamp, v);
  wake[gx][gy] = v;
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
      float v = wake[cx][cy] + amount * falloff;
      if (wakeClamp > 0) v = min(wakeClamp, v);
      wake[cx][cy] = v;
    }
  }
}

void sampleWakeGradient(float x, float y, PVector out) {
  int gx = gridX(x);
  int gy = gridY(y);
  int x1 = max(0, gx - 1);
  int x2 = min(gridW - 1, gx + 1);
  int y1 = max(0, gy - 1);
  int y2 = min(gridH - 1, gy + 1);
  float gradX = wake[x2][gy] - wake[x1][gy];
  float gradY = wake[gx][y2] - wake[gx][y1];
  out.set(gradX, gradY);
}

float sampleWakeAt(float x, float y) {
  int gx = gridX(x);
  int gy = gridY(y);
  return wake[gx][gy];
}

// --- Grid-space sampling helpers (for cheap advection) ---
float sampleWakeBilinearGrid(float gx, float gy) {
  gx = constrain(gx, 0, gridW - 1);
  gy = constrain(gy, 0, gridH - 1);

  int x0 = (int)floor(gx);
  int y0 = (int)floor(gy);
  int x1 = min(gridW - 1, x0 + 1);
  int y1 = min(gridH - 1, y0 + 1);

  float fx = gx - x0;
  float fy = gy - y0;

  float v00 = wake[x0][y0];
  float v10 = wake[x1][y0];
  float v01 = wake[x0][y1];
  float v11 = wake[x1][y1];

  float vx0 = lerp(v00, v10, fx);
  float vx1 = lerp(v01, v11, fx);
  return lerp(vx0, vx1, fy);
}

void sampleWakeGradientGrid(float gx, float gy, PVector out) {
  int ix = constrain((int)round(gx), 0, gridW - 1);
  int iy = constrain((int)round(gy), 0, gridH - 1);
  int x1 = max(0, ix - 1);
  int x2 = min(gridW - 1, ix + 1);
  int y1 = max(0, iy - 1);
  int y2 = min(gridH - 1, iy + 1);
  float gradX = wake[x2][iy] - wake[x1][iy];
  float gradY = wake[ix][y2] - wake[ix][y1];
  out.set(gradX, gradY);
}

void sampleAmbientCurrentGrid(float gx, float gy, PVector out) {
  if (!useAmbientCurrent) {
    out.set(0, 0);
    return;
  }
  float nx = noise(gx * ambientCurrentScale, gy * ambientCurrentScale, t * ambientCurrentTime) - 0.5;
  float ny = noise(gx * ambientCurrentScale + 100.0, gy * ambientCurrentScale + 100.0, t * ambientCurrentTime) - 0.5;
  float m2 = nx * nx + ny * ny;
  if (m2 > 0.000001) {
    float inv = 1.0 / sqrt(m2);
    nx *= inv;
    ny *= inv;
  } else {
    nx = 0;
    ny = 0;
  }
  out.set(nx * ambientCurrentStrength, ny * ambientCurrentStrength);
}

void sampleFlowGridAt(float gx, float gy, PVector out) {
  int ix = constrain((int)round(gx), 0, gridW - 1);
  int iy = constrain((int)round(gy), 0, gridH - 1);
  int x1 = max(0, ix - 1);
  int x2 = min(gridW - 1, ix + 1);
  int y1 = max(0, iy - 1);
  int y2 = min(gridH - 1, iy + 1);
  float gradX = wake[x2][iy] - wake[x1][iy];
  float gradY = wake[ix][y2] - wake[ix][y1];

  float flowX = (-gradY * swirlStrength) + (gradX * pushStrength);
  float flowY = (gradX * swirlStrength) + (gradY * pushStrength);

  if (useAmbientCurrent) {
    float nx = noise(gx * ambientCurrentScale, gy * ambientCurrentScale, t * ambientCurrentTime) - 0.5;
    float ny = noise(gx * ambientCurrentScale + 100.0, gy * ambientCurrentScale + 100.0, t * ambientCurrentTime) - 0.5;
    float m2 = nx * nx + ny * ny;
    if (m2 > 0.000001) {
      float inv = 1.0 / sqrt(m2);
      nx *= inv;
      ny *= inv;
    } else {
      nx = 0;
      ny = 0;
    }
    flowX += nx * ambientCurrentStrength;
    flowY += ny * ambientCurrentStrength;
  }

  float m2 = flowX * flowX + flowY * flowY;
  float maxFlowSq = maxFlow * maxFlow;
  if (m2 > maxFlowSq) {
    float inv = maxFlow / sqrt(m2);
    flowX *= inv;
    flowY *= inv;
  }
  out.set(flowX, flowY);
}

void advectWakeOnce() {
  // Semi-Lagrangian (backtrace) advection in grid space.
  for (int x = 0; x < gridW; x++) {
    for (int y = 0; y < gridH; y++) {
      float gx = x + 0.5;
      float gy = y + 0.5;
      sampleFlowGridAt(gx, gy, flowScratch);

      float px = gx - flowScratch.x * wakeAdvectStrength;
      float py = gy - flowScratch.y * wakeAdvectStrength;

      float d = sampleWakeBilinearGrid(px, py);
      wakeNext[x][y] = d;
    }
  }
  float[][] tmp = wake;
  wake = wakeNext;
  wakeNext = tmp;
}

void advectWakeRK2() {
  // Midpoint / RK2 advection for smoother curls (costs ~2x flow samples).
  float s = wakeAdvectStrength;
  for (int x = 0; x < gridW; x++) {
    for (int y = 0; y < gridH; y++) {
      float gx = x + 0.5;
      float gy = y + 0.5;

      sampleFlowGridAt(gx, gy, flowScratch);
      float mx = gx - flowScratch.x * (0.5 * s);
      float my = gy - flowScratch.y * (0.5 * s);

      sampleFlowGridAt(mx, my, flowScratch);
      float px = gx - flowScratch.x * s;
      float py = gy - flowScratch.y * s;

      float d = sampleWakeBilinearGrid(px, py);
      wakeNext[x][y] = d;
    }
  }
  float[][] tmp = wake;
  wake = wakeNext;
  wakeNext = tmp;
}

void updateWakeGrid() {
  // 1) Advection: carry wake along the flow field (streaks/curls instead of foggy blur)
  if (useWakeAdvection) {
    if (wakeAdvectSteps >= 2) {
      advectWakeRK2();
    } else {
      advectWakeOnce();
    }
  }

  // 2) Diffusion + decay: smooth + fade (keeps it stable and calm over time)
  for (int x = 0; x < gridW; x++) {
    for (int y = 0; y < gridH; y++) {
      float c = wake[x][y];
      float l = wake[max(0, x - 1)][y];
      float r = wake[min(gridW - 1, x + 1)][y];
      float u = wake[x][max(0, y - 1)];
      float d = wake[x][min(gridH - 1, y + 1)];
      float avg = (l + r + u + d) * 0.25;
      float v = c * (1.0 - wakeDiffuse) + avg * wakeDiffuse;
      v *= wakeDecay;
      if (wakeClamp > 0) v = min(wakeClamp, v);
      wakeNext[x][y] = v;
    }
  }

  float[][] tmp = wake;
  wake = wakeNext;
  wakeNext = tmp;
}

void sampleFlow(float x, float y, PVector out) {
  int gx = gridX(x);
  int gy = gridY(y);
  int x1 = max(0, gx - 1);
  int x2 = min(gridW - 1, gx + 1);
  int y1 = max(0, gy - 1);
  int y2 = min(gridH - 1, gy + 1);
  float gradX = wake[x2][gy] - wake[x1][gy];
  float gradY = wake[gx][y2] - wake[gx][y1];

  float flowX = (-gradY * swirlStrength) + (gradX * pushStrength);
  float flowY = (gradX * swirlStrength) + (gradY * pushStrength);

  // Keep steering + render flow consistent with advection's ambient current
  if (useAmbientCurrent) {
    float gxf = map(x, 0, width, 0, gridW - 1);
    float gyf = map(y, 0, height, 0, gridH - 1);
    float nx = noise(gxf * ambientCurrentScale, gyf * ambientCurrentScale, t * ambientCurrentTime) - 0.5;
    float ny = noise(gxf * ambientCurrentScale + 100.0, gyf * ambientCurrentScale + 100.0, t * ambientCurrentTime) - 0.5;
    float m2 = nx * nx + ny * ny;
    if (m2 > 0.000001) {
      float inv = 1.0 / sqrt(m2);
      nx *= inv;
      ny *= inv;
    } else {
      nx = 0;
      ny = 0;
    }
    flowX += nx * ambientCurrentStrength;
    flowY += ny * ambientCurrentStrength;
  }

  float m2 = flowX * flowX + flowY * flowY;
  float maxFlowSq = maxFlow * maxFlow;
  if (m2 > maxFlowSq) {
    float inv = maxFlow / sqrt(m2);
    flowX *= inv;
    flowY *= inv;
  }
  out.set(flowX, flowY);
}

void drawWaterInteraction() {
  if (wake == null) return;
  float cellW = width / (float)gridW;
  float cellH = height / (float)gridH;

  // --- Ink/Dye wash (dominant mass layer) ---
  noStroke();
  for (int x = 0; x < gridW; x++) {
    for (int y = 0; y < gridH; y++) {
      float v = wake[x][y];
      if (v <= 0.01) continue;
      float a = constrain(v * WATER_INK_ALPHA_SCALE, 0, 90);
      fill(40, 90, 140, a);
      rect(x * cellW, y * cellH, cellW + 1, cellH + 1);
    }
  }

  // --- Flow-aligned strokes (direction layer) ---
  int cols = 48;
  int rows = 30;
  float stepW = width / (float)cols;
  float stepH = height / (float)rows;
  for (int ix = 0; ix < cols; ix++) {
    float x = (ix + 0.5) * stepW;
    for (int iy = 0; iy < rows; iy++) {
      float y = (iy + 0.5) * stepH;
      float w = sampleWakeAt(x, y);
      if (w <= 0.02) continue;
      sampleFlow(x, y, flowScratch);
      float m2 = flowScratch.magSq();
      if (m2 < 0.0001) continue;
      flowScratch.normalize();
      float len = lerp(3, 12, constrain(w * 0.6, 0, 1));
      float a = constrain(w * WATER_STROKE_ALPHA_SCALE * 10.0, 0, 80);
      stroke(60, 130, 190, a);
      strokeWeight(1);
      line(x - flowScratch.x * len * 0.5, y - flowScratch.y * len * 0.5,
           x + flowScratch.x * len * 0.5, y + flowScratch.y * len * 0.5);
    }
  }

  // --- Caustic sparkles (light touch) ---
  int cCols = 36;
  int cRows = 22;
  float cStepW = width / (float)cCols;
  float cStepH = height / (float)cRows;
  for (int ix = 0; ix < cCols; ix++) {
    float x = (ix + 0.5) * cStepW;
    for (int iy = 0; iy < cRows; iy++) {
      float y = (iy + 0.5) * cStepH;
      float w = sampleWakeAt(x, y);
      if (w <= 0.03) continue;
      float sparkle = noise(x * 0.01, y * 0.01, t * 0.4);
      if (sparkle < 0.72) continue;
      float a = constrain(w * WATER_CAUSTIC_ALPHA_SCALE * 12.0, 0, 70);
      stroke(200, 220, 255, a);
      strokeWeight(1);
      point(x + (sparkle - 0.5) * 6, y + (sparkle - 0.5) * 6);
    }
  }
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
  flowMeanScratch.set(0, 0);
  int count = 0;
  for (int ix = 0; ix < cols; ix++) {
    float x = (ix + 0.5) * width / (float)cols;
    for (int iy = 0; iy < rows; iy++) {
      float y = (iy + 0.5) * height / (float)rows;
      sampleFlow(x, y, flowScratch);
      flowMeanScratch.add(flowScratch);
      count++;
    }
  }
  if (count > 0) {
    flowMeanScratch.div(count);
  }
  println("mean flow = (" + nf(flowMeanScratch.x, 1, 3) + ", " + nf(flowMeanScratch.y, 1, 3) + ")");
}
