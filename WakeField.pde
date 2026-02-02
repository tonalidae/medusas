int baseGridW = 160;
int baseGridH = 100;
float wakeResolutionScale = 1.0; // 1.0 = full detail; lowered when flow trails are off
int gridW = baseGridW;
int gridH = baseGridH;
float[][] wake;
float[][] wakeNext;

// Core wake parameters
float wakeDecay = 0.992;         // Slower fade -> thicker, longer-lived ripples
float wakeDiffuse = 0.20;
float wakeDeposit = 1.0;
float userDeposit = 2.0;
float wakeClamp = 12.0;          // Higher cap so dense wakes can accumulate before clipping
float wakeTension = 0.06;       // Surface-tension style curvature feedback (0 = off)
float wakeCurlStrength = 0.12;  // Small rotational kick to keep ripples swirling
float wakeBlobRadiusScale = 1.25; // Enlarge deposits to feel more viscous

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
PVector wakeGradientScratch = new PVector(0, 0);

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
  
  WaterParticle(float x_, float y_) {
    x = x_;
    y = y_;
    vx = random(-0.5, 0.5);
    vy = random(-0.5, 0.5);
    maxLife = random(60, 90);
    lifespan = maxLife;
    size = 1.0;
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
int MAX_WATER_PARTICLES = 60;
float WATER_PARTICLE_CONNECT_DIST = 120;
float WATER_PARTICLE_MAX_RADIUS = 60;

void initWakeGrid() {
  // Coarsen the wake grid when flow trails are off; finer when on.
  wakeResolutionScale = showFlowTrails ? 1.0 : 0.7;
  gridW = max(48, int(baseGridW * wakeResolutionScale));
  gridH = max(32, int(baseGridH * wakeResolutionScale));
  wake = new float[gridW][gridH];
  wakeNext = new float[gridW][gridH];
}

void updateWaterParticles() {
  // Remove dead particles
  for (int i = waterParticles.size() - 1; i >= 0; i--) {
    if (waterParticles.get(i).isDead()) {
      waterParticles.remove(i);
    }
  }
  
  // Update existing particles with flow influence
  for (WaterParticle p : waterParticles) {
    float gx = map(p.x, 0, width, 0, gridW - 1);
    float gy = map(p.y, 0, height, 0, gridH - 1);
    sampleFlowGridAt(gx, gy, flowScratch);
    p.update(flowScratch.x, flowScratch.y);
  }
}

void spawnWaterParticles(float x, float y, int count) {
  for (int i = 0; i < count; i++) {
    if (waterParticles.size() >= MAX_WATER_PARTICLES) break;
    float px = x + random(-30, 30);
    float py = y + random(-30, 30);
    waterParticles.add(new WaterParticle(px, py));
  }
}

void drawWaterParticleConnections() {
  if (waterParticles.size() == 0) return;
  
  pushStyle();
  noFill();
  
  // Draw connection web between nearby particles (fades with particles)
  for (int i = 0; i < waterParticles.size(); i++) {
    WaterParticle pi = waterParticles.get(i);
    
    for (int j = i + 1; j < waterParticles.size(); j++) {
      WaterParticle pj = waterParticles.get(j);
      
      float d = dist(pi.x, pi.y, pj.x, pj.y);
      if (d < WATER_PARTICLE_CONNECT_DIST) {
        float mx = (pi.x + pj.x) * 0.5;
        float my = (pi.y + pj.y) * 0.5;
        float radius = map(d, 0, WATER_PARTICLE_CONNECT_DIST, 0, WATER_PARTICLE_MAX_RADIUS);
        
        // Sample wake at connection point for brightness
        float wakeValue = sampleWakeAt(mx, my);
        float baseAlpha = map(d, 0, WATER_PARTICLE_CONNECT_DIST, 30, 3);
        baseAlpha *= constrain(wakeValue * 2, 0.5, 1.5);
        
        // Use minimum alpha from both particles for natural fade
        float particleAlpha = min(pi.getAlpha(), pj.getAlpha()) / 255.0;
        float alpha = baseAlpha * particleAlpha * 0.5;
        
        // Color shifts based on wake intensity
        float hue = map(wakeValue, 0, 1, 180, 220);
        stroke(hue, 200, 255, alpha);
        strokeWeight(0.8);
        ellipse(mx, my, radius * 2, radius * 2);
      }
    }
  }
  
  // Draw expanding ripple rings from each particle
  for (WaterParticle p : waterParticles) {
    float lifeFraction = p.lifespan / p.maxLife;
    
    // Expand outward as particle ages (inverse of lifespan)
    float expansionRadius = map(lifeFraction, 1.0, 0.0, 5, 80);
    
    // Fade out as it expands
    float alpha = p.getAlpha() * 0.6;
    
    // Sample wake for color variation
    float wakeValue = sampleWakeAt(p.x, p.y);
    float hue = map(wakeValue, 0, 1, 180, 220);
    
    // Bright core when young
    if (lifeFraction > 0.5) {
      float coreAlpha = alpha * map(lifeFraction, 0.5, 1.0, 0, 1.2);
      fill(240, 250, 255, coreAlpha);
      noStroke();
      ellipse(p.x, p.y, expansionRadius * 0.4, expansionRadius * 0.4);
    }
    
    // Inner bright ring
    noFill();
    stroke(hue + 20, 220, 255, alpha * 0.7);
    strokeWeight(2);
    ellipse(p.x, p.y, expansionRadius * 2, expansionRadius * 2);
    
    // Mid ring
    stroke(hue, 200, 255, alpha * 0.4);
    strokeWeight(1.5);
    ellipse(p.x, p.y, expansionRadius * 2.3, expansionRadius * 2.3);
    
    // Outer faint ring
    stroke(hue, 180, 255, alpha * 0.2);
    strokeWeight(1);
    ellipse(p.x, p.y, expansionRadius * 2.6, expansionRadius * 2.6);
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

void sampleFlow(float x, float y, PVector out) {
  sampleWakeGradient(x, y, wakeGradientScratch);
  float gx = wakeGradientScratch.x;
  float gy = wakeGradientScratch.y;
  float flowX = (-gy * swirlStrength) + (gx * pushStrength);
  float flowY = (gx * swirlStrength) + (gy * pushStrength);

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
    flowX += nx * ambientCurrentStrength;
    flowY += ny * ambientCurrentStrength;
  }

  float m2 = flowX * flowX + flowY * flowY;
  float maxFlowSq = maxFlow * maxFlow;
  if (m2 > maxFlowSq && m2 > 0) {
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
      fill(r, g, b, a);
      rect(x * cellW, y * cellH, cellW + 1, cellH + 1);
    }
  }

  if (showFlowTrails) {
    // --- Layer 2: Flow-aligned strokes with organic trails ---
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
        sampleWakeGradient(x, y, wakeGradientScratch);
        float edge = wakeGradientScratch.mag();
        
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
  
    // --- Layer 3: Enhanced caustic network with organic patterns ---
    int cCols = 50;
    int cRows = 32;
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
        
        sampleWakeGradient(x, y, wakeGradientScratch);
        float edge = wakeGradientScratch.mag();
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
    int pCols = 24;
    int pRows = 16;
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
      sampleFlow(x, y, flowMeanScratch);
      sum.add(flowMeanScratch);
      count++;
    }
  }
  if (count > 0) {
    sum.div(count);
  }
  println("mean flow = (" + nf(sum.x, 1, 3) + ", " + nf(sum.y, 1, 3) + ")");
}
