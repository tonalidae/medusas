int gridW = 160;
int gridH = 100;
float[][] wake;
float[][] wakeNext;

// Core wake parameters
float wakeDecay = 0.995;         // Slower fade -> thicker, longer-lived ripples
float wakeDiffuse = 0.20;
float wakeDeposit = 1.0;
float userDeposit = 3.0;
float wakeClamp = 16.0;          // Higher cap so dense wakes can accumulate before clipping
float wakeTension = 0.06;       // Surface-tension style curvature feedback (0 = off)
float wakeCurlStrength = 0.12;  // Small rotational kick to keep ripples swirling
float wakeBlobRadiusScale = 1.5; // Enlarge deposits to feel more viscous

// Flow shaping
float swirlStrength = 0.6;
float pushStrength = 0.4;
float maxFlow = 1.2;

// Advection + ambient current
boolean useWakeAdvection = true;
float wakeAdvectStrength = 0.65; // Lower transport so blobs linger and smear slowly
int wakeAdvectSteps = 1;        // 1 = cheap, 2 = smoother midpoint
boolean useAmbientCurrent = true;
float ambientCurrentStrength = 0.18; // Small bias current magnitude (grid units/frame)
float ambientCurrentScale = 0.06;    // Noise spatial scale in grid space
float ambientCurrentTime = 0.10;     // Noise time scale

// Scratch buffers
PVector flowScratch = new PVector(0, 0);
PVector flowMeanScratch = new PVector(0, 0);
int lastFlowMeanSample = 0;

// User flow feedback (no on-screen cursor)
PVector userTouchPos = new PVector(-1000, -1000);
PVector userFlowVec = new PVector(0, 0);
float userTouchStrength = 0;
float USER_TOUCH_DECAY = 0.97;   // Slower decay so interaction trails last longer
float USER_FLOW_SMOOTH = 0.18;

// Water particle connection system
class WaterParticle {
  float x, y;
  float vx, vy;
  float lifespan;
  float maxLife;
  float size;
  float cpx, cpy; // Cached bezier control point
  int gridCellX, gridCellY; // Spatial partitioning cell
  
  WaterParticle(float x_, float y_) {
    x = x_;
    y = y_;
    vx = random(-0.5, 0.5);
    vy = random(-0.5, 0.5);
    maxLife = random(60, 90);
    lifespan = maxLife;
    size = 1.0;
    // Pre-calculate control point for bezier curve
    cpx = x + random(-15, 15);
    cpy = y + random(-15, 15);
  }
  
  void update(float flowX, float flowY) {
    // Respond to wake flow
    vx += flowX * 0.05;
    vy += flowY * 0.05;
    
    // Add drag
    vx *= 0.98;
    vy *= 0.98;
    
    // Move
    x += vx;
    y += vy;
    
    // Wrap edges
    if (x < 0 || x > width) vx *= -1;
    if (y < 0 || y > height) vy *= -1;
    x = constrain(x, 0, width);
    y = constrain(y, 0, height);
    
    // Update spatial grid cell
    gridCellX = int(x / PARTICLE_GRID_CELL_SIZE);
    gridCellY = int(y / PARTICLE_GRID_CELL_SIZE);
    gridCellX = constrain(gridCellX, 0, PARTICLE_GRID_WIDTH - 1);
    gridCellY = constrain(gridCellY, 0, PARTICLE_GRID_HEIGHT - 1);
    
    // Update control point slightly for subtle animation
    cpx += random(-2, 2);
    cpy += random(-2, 2);
    
    // Fade over time
    lifespan -= 1.0;
    
    // Expand as fading (inverse of lifespan)
    float lifeFraction = lifespan / maxLife;
    size = map(lifeFraction, 1.0, 0.0, 1.0, 3.5);
  }
  
  boolean isDead() {
    return lifespan <= 0;
  }
  
  float getAlpha() {
    return constrain(lifespan, 0, 255);
  }
}

ArrayList<WaterParticle> waterParticles = new ArrayList<WaterParticle>();
int MAX_WATER_PARTICLES = 0;
float WATER_PARTICLE_CONNECT_DIST = 120;
float WATER_PARTICLE_MAX_RADIUS = 60;
// Performance optimization: spatial partitioning grid
int PARTICLE_GRID_CELL_SIZE = 150; // Size of each grid cell
int PARTICLE_GRID_WIDTH = 0;
int PARTICLE_GRID_HEIGHT = 0;
ArrayList<WaterParticle>[][] particleGrid; // Spatial grid for fast neighbor lookup
float PARTICLE_ALPHA_LOD_THRESHOLD = 30; // Skip rendering particles fainter than this

void initWakeGrid() {
  wake = new float[gridW][gridH];
  wakeNext = new float[gridW][gridH];
  
  // Initialize particle spatial grid
  PARTICLE_GRID_WIDTH = max(1, int(width / PARTICLE_GRID_CELL_SIZE) + 1);
  PARTICLE_GRID_HEIGHT = max(1, int(height / PARTICLE_GRID_CELL_SIZE) + 1);
  particleGrid = new ArrayList[PARTICLE_GRID_WIDTH][PARTICLE_GRID_HEIGHT];
  for (int x = 0; x < PARTICLE_GRID_WIDTH; x++) {
    for (int y = 0; y < PARTICLE_GRID_HEIGHT; y++) {
      particleGrid[x][y] = new ArrayList<WaterParticle>();
    }
  }
}

void updateWaterParticles() {
  // Clear spatial grid
  for (int x = 0; x < PARTICLE_GRID_WIDTH; x++) {
    for (int y = 0; y < PARTICLE_GRID_HEIGHT; y++) {
      particleGrid[x][y].clear();
    }
  }
  
  // Remove dead particles and update grid
  synchronized (waterParticles) {
    for (int i = waterParticles.size() - 1; i >= 0; i--) {
      WaterParticle p = waterParticles.get(i);
      if (p.isDead()) {
        waterParticles.remove(i);
      } else {
        float gx = map(p.x, 0, width, 0, gridW - 1);
        float gy = map(p.y, 0, height, 0, gridH - 1);
        sampleFlowGridAt(gx, gy, flowScratch);
        p.update(flowScratch.x, flowScratch.y);
        
        // Add to spatial grid
        if (p.gridCellX >= 0 && p.gridCellX < PARTICLE_GRID_WIDTH &&
            p.gridCellY >= 0 && p.gridCellY < PARTICLE_GRID_HEIGHT) {
          particleGrid[p.gridCellX][p.gridCellY].add(p);
        }
      }
    }
  }
}

void spawnWaterParticles(float x, float y, int count) {
  synchronized (waterParticles) {
    for (int i = 0; i < count; i++) {
      if (waterParticles.size() >= MAX_WATER_PARTICLES) break;
      float px = x + random(-30, 30);
      float py = y + random(-30, 30);
      waterParticles.add(new WaterParticle(px, py));
    }
  }
}

void drawWaterParticleConnections() {
  if (waterParticles.size() == 0) return;
  
  pushStyle();
  noFill();

  ArrayList<WaterParticle> snapshot;
  synchronized (waterParticles) {
    snapshot = new ArrayList<WaterParticle>(waterParticles);
  }

  // Draw curved organic connections using spatial grid (only check nearby particles)
  for (WaterParticle p : snapshot) {
    float alpha = p.getAlpha();
    if (alpha < PARTICLE_ALPHA_LOD_THRESHOLD) continue;

    int cellX = p.gridCellX;
    int cellY = p.gridCellY;

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        int nx = cellX + dx;
        int ny = cellY + dy;

        if (nx >= 0 && nx < PARTICLE_GRID_WIDTH && ny >= 0 && ny < PARTICLE_GRID_HEIGHT) {
          for (WaterParticle other : particleGrid[nx][ny]) {
            if (p == other) continue;

            float d = dist(p.x, p.y, other.x, other.y);
            if (d < WATER_PARTICLE_CONNECT_DIST) {
              float particleAlpha = min(alpha, other.getAlpha()) / 255.0;
              float wakeValue = sampleWakeAt(p.x, p.y);
              float hue = map(wakeValue, 0, 1, 200, 240);

              float connectionAlpha = map(d, 0, WATER_PARTICLE_CONNECT_DIST, 40, 5);
              connectionAlpha *= constrain(wakeValue * 2, 0.5, 1.5);
              connectionAlpha *= particleAlpha * 0.6;

              stroke(hue, 210, 255, connectionAlpha);
              strokeWeight(1.2);
              bezier(p.x, p.y, p.cpx, p.cpy, p.cpx, p.cpy, other.x, other.y);
            }
          }
        }
      }
    }
  }

  // Draw expanding ripple rings with color gradients
  for (WaterParticle p : snapshot) {
    float alpha = p.getAlpha();
    if (alpha < PARTICLE_ALPHA_LOD_THRESHOLD) continue;

    float lifeFraction = p.lifespan / p.maxLife;
    float expansionRadius = map(lifeFraction, 1.0, 0.0, 5, 80);
    float adjustedAlpha = alpha * 0.6;

    if (lifeFraction > 0.5) {
      float coreAlpha = adjustedAlpha * map(lifeFraction, 0.5, 1.0, 0, 1.4);
      fill(220, 240, 255, coreAlpha * 1.2);
      noStroke();
      ellipse(p.x, p.y, expansionRadius * 0.3, expansionRadius * 0.3);
    }

    noFill();
    float innerHue = map(lifeFraction, 1.0, 0.0, 180, 210);
    stroke(innerHue, 220, 255, adjustedAlpha * 0.8);
    strokeWeight(2.5);
    ellipse(p.x, p.y, expansionRadius * 2, expansionRadius * 2);

    float midHue = map(lifeFraction, 1.0, 0.0, 200, 240);
    stroke(midHue, 200, 255, adjustedAlpha * 0.5);
    strokeWeight(2);
    ellipse(p.x, p.y, expansionRadius * 2.3, expansionRadius * 2.3);

    float outerHue = map(lifeFraction, 1.0, 0.0, 220, 280);
    stroke(outerHue, 180, 240, adjustedAlpha * 0.25);
    strokeWeight(1.2);
    ellipse(p.x, p.y, expansionRadius * 2.6, expansionRadius * 2.6);

    if (enableBloom && adjustedAlpha > 50) {
      stroke(innerHue + 10, 255, 255, adjustedAlpha * 0.15);
      strokeWeight(3);
      ellipse(p.x, p.y, expansionRadius * 1.8, expansionRadius * 1.8);
    }
  }
  
  popStyle();
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
  recordUserImpact(x, y, amount);
  
  // Spawn particles proportional to disturbance
  if (useWaterParticles && amount > 1.0) {
    int count = int(map(amount, 1, 3, 1, 3));
    spawnWaterParticles(x, y, count);
  }
  
  radius *= wakeBlobRadiusScale; // globally enlarge deposits for a heavier fluid feel
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

// --- Grid-space sampling helpers (for advection) ---
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

// Track interaction so flow feedback can push back (non-visual)
void recordUserImpact(float x, float y, float amount) {
  if (!useUserFlowFeedback) return;
  userTouchPos.set(x, y);
  userTouchStrength = min(1.2, userTouchStrength + abs(amount) * 0.35);
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

  // Lightweight curl: difference of opposing gradients injects a gentle spin
  float curl = (wake[x2][iy] - wake[x1][iy]) - (wake[ix][y2] - wake[ix][y1]);
  flowX += -curl * wakeCurlStrength;
  flowY +=  curl * wakeCurlStrength;

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
  // 3) Surface-tension feedback: shallow curvature pull that keeps ripples tight
  if (wakeTension > 0.0) {
    // Write tension-corrected result into wake (reuse old buffer as output)
    for (int x = 0; x < gridW; x++) {
      for (int y = 0; y < gridH; y++) {
        float c = wakeNext[x][y];
        float l = wakeNext[max(0, x - 1)][y];
        float r = wakeNext[min(gridW - 1, x + 1)][y];
        float u = wakeNext[x][max(0, y - 1)];
        float d = wakeNext[x][min(gridH - 1, y + 1)];
        float laplacian = (l + r + u + d) - (4.0 * c);
        float v = c + laplacian * wakeTension;
        if (wakeClamp > 0) v = min(wakeClamp, v);
        wake[x][y] = v;
      }
    }
    // Keep wakeNext as scratch (diffused data is no longer needed)
  } else {
    // No tension pass: promote diffused data to wake
    float[][] tmp = wake;
    wake = wakeNext;
    wakeNext = tmp;
  }
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

float sampleWakeAt(float x, float y) {
  int gx = gridX(x);
  int gy = gridY(y);
  return wake[gx][gy];
}

PVector sampleFlow(float x, float y) {
  PVector g = sampleWakeGradient(x, y);
  PVector flow = new PVector(-g.y, g.x);
  flow.mult(swirlStrength);
  flow.add(PVector.mult(g, pushStrength));

  // Keep steering flow consistent with advection's ambient current
  if (useAmbientCurrent) {
    float gxf = map(x, 0, width, 0, gridW - 1);
    float gyf = map(y, 0, height, 0, gridH - 1);
    float nx = noise(gxf * ambientCurrentScale, gyf * ambientCurrentScale, t * ambientCurrentTime) - 0.5;
    float ny = noise(gxf * ambientCurrentScale + 100.0, gyf * ambientCurrentScale + 100.0, t * ambientCurrentTime) - 0.5;
    float m2n = nx * nx + ny * ny;
    if (m2n > 0.000001) {
      float inv = 1.0 / sqrt(m2n);
      nx *= inv;
      ny *= inv;
    } else {
      nx = 0;
      ny = 0;
    }
    flow.x += nx * ambientCurrentStrength;
    flow.y += ny * ambientCurrentStrength;
  }

  float m2 = flow.magSq();
  if (m2 > maxFlow * maxFlow) {
    flow.normalize();
    flow.mult(maxFlow);
  }
  return flow;
}

void sampleFlow(float x, float y, PVector out) {
  PVector f = sampleFlow(x, y);
  out.set(f);
}

void drawWaterInteraction() {
  if (wake == null) return;
  float cellW = width / (float)gridW;
  float cellH = height / (float)gridH;
  int pressCount = 0;
  float[] pressXs = new float[MAX_HANDS];
  float[] pressYs = new float[MAX_HANDS];
  float[] pressR = new float[MAX_HANDS];
  float[] pressRSq = new float[MAX_HANDS];
  float[] pressStrengths = new float[MAX_HANDS];
  for (int h = 0; h < MAX_HANDS; h++) {
    float p = handSlotPress[h];
    float px = handSlotX[h];
    float py = handSlotY[h];
    if (p <= 0.02 || px <= -900 || py <= -900) continue;
    float r = HAND_DEPTH_LAYER_RADIUS * lerp(0.7, 1.2, p);
    pressXs[pressCount] = px;
    pressYs[pressCount] = py;
    pressR[pressCount] = r;
    pressRSq[pressCount] = r * r;
    pressStrengths[pressCount] = p * HAND_DEPTH_LAYER_STRENGTH;
    pressCount++;
  }

  // --- Layer 1: Depth-mapped fluid base with iridescence ---
  noStroke();
  for (int x = 0; x < gridW; x++) {
    for (int y = 0; y < gridH; y++) {
      float v = wake[x][y];
      if (v <= 0.01) continue;
      
      float dx = wake[min(gridW - 1, x + 1)][y] - wake[max(0, x - 1)][y];
      float dy = wake[x][min(gridH - 1, y + 1)] - wake[x][max(0, y - 1)];
      float edge = constrain(sqrt(dx * dx + dy * dy) * 0.5, 0, 1);
      
      // Depth-based color gradient: deeper areas get richer blues
      float depth = constrain(v * 0.8, 0, 1);
      float iridescence = noise(x * 0.3, y * 0.3, t * 0.15) * 0.3;
      
      // Multi-tone blue-cyan-teal gradient
      float r = lerp(20, 60, depth) + iridescence * 30;
      float g = lerp(60, 140, depth * (1 + edge * 0.5)) + iridescence * 40;
      float b = lerp(120, 200, depth + edge * 0.3) + iridescence * 20;
      
      float a = constrain(v * WATER_INK_ALPHA_SCALE * (0.7 + edge * 1.2), 0, 120);
      if (pressCount > 0) {
        float cx = (x + 0.5) * cellW;
        float cy = (y + 0.5) * cellH;
        for (int i = 0; i < pressCount; i++) {
          float pdx = cx - pressXs[i];
          float pdy = cy - pressYs[i];
          float d2 = pdx * pdx + pdy * pdy;
          if (d2 < pressRSq[i]) {
            float falloff = 1.0 - (sqrt(d2) / pressR[i]);
            float press = falloff * pressStrengths[i];
            r = constrain(r + 35 * press, 0, 255);
            g = constrain(g + 55 * press, 0, 255);
            b = constrain(b + 85 * press, 0, 255);
            a *= (1.0 + press);
          }
        }
      }
      fill(r, g, b, a);
      rect(x * cellW, y * cellH, cellW + 1, cellH + 1);
    }
  }

  // --- Layer 2: Flow-aligned strokes with organic trails ---
  if (showFlowTrails) {
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
        
        // Variable stroke length based on flow intensity
        float flowMag = sqrt(m2);
        float len = lerp(4, 18, constrain(w * 0.7 + flowMag * 0.3, 0, 1));
        float edge = sampleWakeGradient(x, y).mag();
        
        // Elongated, organic strokes with varying thickness
        float thickness = lerp(0.5, 2.5, constrain(w * 0.5, 0, 1));
        float a = constrain(w * WATER_STROKE_ALPHA_SCALE * 12.0 * (0.6 + edge * 0.8), 0, 100);
        
        // Color varies with direction and intensity
        float hueShift = noise(x * 0.02, y * 0.02, t * 0.1) * 60;
        stroke(50 + hueShift, 140 + hueShift * 0.5, 210, a);
        strokeWeight(thickness);
        
        // Draw elongated stroke with slight curve
        float curvature = (noise(x * 0.03, y * 0.03, t * 0.2) - 0.5) * 0.3;
        line(x - flowScratch.x * len * 0.6, y - flowScratch.y * len * 0.6,
             x + flowScratch.x * len * 0.6 + flowScratch.y * curvature * 2, 
             y + flowScratch.y * len * 0.6 - flowScratch.x * curvature * 2);
      }
    }
  }

  // --- Layer 3: Enhanced caustic network with organic patterns ---
  int cCols = 25;
  int cRows = 16;
  float cStepW = width / (float)cCols;
  float cStepH = height / (float)cRows;
  for (int ix = 0; ix < cCols; ix++) {
    float x = (ix + 0.5) * cStepW;
    for (int iy = 0; iy < cRows; iy++) {
      float y = (iy + 0.5) * cStepH;
      float w = sampleWakeAt(x, y);
      if (w <= 0.025) continue;
      
      // Multi-layer caustic noise for organic, light-ray feel
      float n1 = noise(x * 0.015, y * 0.015, t * 0.5);
      float n2 = noise(x * 0.025 + 100, y * 0.025 + 100, t * 0.35);
      float causticPattern = (n1 * 0.6 + n2 * 0.4);
      
      // Threshold creates concentrated light patches
      if (causticPattern < 0.65) continue;
      
      float edge = sampleWakeGradient(x, y).mag();
      float intensity = (causticPattern - 0.65) / 0.35; // 0..1 above threshold
      
      // Brighter, more saturated caustics
      float a = constrain(w * WATER_CAUSTIC_ALPHA_SCALE * 18.0 * intensity * (0.5 + edge * 1.2), 0, 140);
      
      // Draw small caustic cluster
      noStroke();
      fill(180, 220, 255, a * 0.8);
      float size = lerp(2, 8, intensity);
      ellipse(x + (n1 - 0.5) * 8, y + (n2 - 0.5) * 8, size, size);
      
      // Add bright core
      if (intensity > 0.7) {
        fill(230, 245, 255, a);
        ellipse(x + (n1 - 0.5) * 8, y + (n2 - 0.5) * 8, size * 0.4, size * 0.4);
      }
    }
  }
  
  // --- Layer 4: Particle-like flow elements (flowing debris) ---
  int pCols = 12;
  int pRows = 8;
  float pStepW = width / (float)pCols;
  float pStepH = height / (float)pRows;
  for (int ix = 0; ix < pCols; ix++) {
    float x = (ix + 0.5) * pStepW;
    for (int iy = 0; iy < pRows; iy++) {
      float y = (iy + 0.5) * pStepH;
      float w = sampleWakeAt(x, y);
      if (w <= 0.04) continue;
      
      sampleFlow(x, y, flowScratch);
      float flowMag = flowScratch.mag();
      if (flowMag < 0.05) continue;
      
      // Animated offset following flow
      float offset = (t * 0.8 + ix * 0.3 + iy * 0.7) % 1.0;
      float particleX = x + flowScratch.x * offset * 15;
      float particleY = y + flowScratch.y * offset * 15;
      
      // Fade in/out along path
      float fade = sin(offset * PI);
      float a = constrain(w * fade * 60, 0, 80);
      
      noStroke();
      fill(90, 160, 220, a);
      ellipse(particleX, particleY, 2.5, 2.5);
    }
  }
}

// Update flow feedback so the fluid "pushes back" without drawing a cursor
void updateUserFlowFeedback() {
  if (!useUserFlowFeedback) return;
  // decay interaction influence
  userTouchStrength *= USER_TOUCH_DECAY;
  if (userTouchStrength < 0.01) {
    userTouchStrength = 0;
    return;
  }
  sampleFlow(userTouchPos.x, userTouchPos.y, flowScratch);
  userFlowVec.lerp(flowScratch, USER_FLOW_SMOOTH);
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
