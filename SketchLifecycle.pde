// --- Water ripple texture (Option A: animated overlay) ---
PGraphics waterTex;
float waterT = 0;
final float WATER_TEX_SCALE = 0.5; // render at half res for speed
PImage[] waterFrames;
int waterFrameCount = 0;
int waterFrameIndex = 0;
float waterFrameAccum = 0;
int waterLastMs = 0;
boolean waterFramesAvailable = false;
boolean waterFramesWarned = false;

void settings() {
  size(w, h, P2D);
  if (useSmooth) {
    smooth(smoothLevel);
  } else {
    noSmooth();
  }
}

void setup() {
  stroke(180, 180, 220, 80);

  // Init water texture buffer (half-res, scaled up)
  int tw = max(1, int(width * WATER_TEX_SCALE));
  int th = max(1, int(height * WATER_TEX_SCALE));
  waterTex = createGraphics(tw, th, P2D);
  waterTex.noSmooth();

  loadWaterFrames();
  waterLastMs = millis();

  initWakeGrid();

  gusanos = new ArrayList<Gusano>();

  for (int i = 0; i < numGusanos; i++) {
    float x = random(200, width-200);
    float y = random(200, height-200);
    color c = color(0, 66);
    gusanos.add(new Gusano(x, y, c, i));
  }
}

void draw() {
  drawDeepOceanBackground();
  // Sync sim time to scaled dt so noise/pulses track physics time.
  float dt = 1.0 / max(1, frameRate);
  dt = min(dt, 1.0/20.0);
  dt *= SIM_TIME_SCALE;
  dt = max(dt, 0.000001);
  simDt = dt;
  simT += dt;
  t = simT;
  if (showWaterTex) {
    blendMode(ADD); // bright caustic-y highlights
    tint(255, waterAlpha);
    if (useWaterFrames && waterFramesAvailable && waterFrameCount > 0) {
      int idx = advanceWaterFrame();
      PImage frame = waterFrames[idx];
      if (frame != null) {
        image(frame, 0, 0, width, height);
      }
    } else {
      if (useWaterFrames && !waterFramesAvailable) {
        useWaterFrames = false;
        warnMissingWaterFrames();
      }
      updateWaterTexture();
      if (waterTex != null) {
        image(waterTex, 0, 0, width, height);
      }
    }
    noTint();
    blendMode(BLEND);
  }
  mouseSpeed = dist(mouseX, mouseY, lastMouseX, lastMouseY);
  lastMouseX = mouseX;
  lastMouseY = mouseY;

  if (useWake || useFlow || debugWake) {
    updateWakeGrid();
  }
  rebuildSpatialGrid();
  // --- User interaction: ghost waves (soft) + impact (sharp) ---
  if (useWake || useFlow || debugWake) {
    // Soft disturbance whenever the pointer is moving ("shadow waves")
    if (mouseSpeed > USER_WAKE_SOFT_SPEED_THR) {
      float speed01 = constrain(mouseSpeed / 12.0, 0, 1);
      float amt = userDeposit * USER_WAKE_SOFT_AMOUNT * speed01;
      depositWakeBlob(mouseX, mouseY, USER_WAKE_SOFT_RADIUS, amt);
    }
    // Sharp impulse on touch / click
    if (mousePressed) {
      float amt = userDeposit * USER_WAKE_HIT_AMOUNT;
      depositWakeBlob(mouseX, mouseY, USER_WAKE_HIT_RADIUS, amt);
    }
  }
  if (showWaterInteraction) {
    drawWaterInteraction();
  }
  if (debugWake) {
    drawWakeGrid();
  }
  if (debugWakeVectors) {
    drawWakeFlowVectors();
  }

  for (Gusano gusano : gusanos) {
    gusano.actualizar();
    gusano.prepararRender();
  }

  blendMode(ADD);
  for (Gusano gusano : gusanos) {
    gusano.dibujarGlow();
  }
  blendMode(BLEND);

  for (Gusano gusano : gusanos) {
    gusano.dibujarCore();
  }

  if (debugSteering) {
    drawAverageVelocity();
  }

  if (debugObjetivos) {
    drawDebugObjectives();
  }

  if (debugFlowMean) {
    debugMeasureFlowMean();
  }
  if (debugNeighborStats) {
    debugNeighborStatsTick();
  }
  if (debugMoodStats) {
    debugMoodStatsTick();
  }
  if (DEBUG_MOOD) {
    debugMoodSummaryTick();
  }

  if (debugHelp) {
    drawDebugHelp();
  }
  
  if (debugBiologicalVectors) {
    drawBiologicalVectorDebug();
  }
}

void drawDeepOceanBackground() {
  background(#050008);
}



void reiniciarGusanos() {
  gusanos.clear();
  for (int i = 0; i < numGusanos; i++) {
    float x = random(200, width-200);
    float y = random(200, height-200);
    color c = color(0, 66); // Todos los gusanos son negros
    gusanos.add(new Gusano(x, y, c, i));
  }
}


void updateWaterTexture() {
  if (waterTex == null) return;
  waterT += 0.01;

  waterTex.beginDraw();
  waterTex.noStroke();
  // Transparent background (keeps overlay subtle)
  waterTex.background(0, 0);

  waterTex.loadPixels();
  int wT = waterTex.width;
  int hT = waterTex.height;

  // Tune these for different ripple scales
  float s = 0.012; // spatial scale
  float t1 = waterT * 1.20;
  float t2 = waterT * 1.00;
  float t3 = waterT * 0.70;
  float tn = waterT * 0.40;

  for (int y = 0; y < hT; y++) {
    float ny = y * s;
    for (int x = 0; x < wT; x++) {
      float nx = x * s;

      float w1 = sin(nx * 3.0 + t1);
      float w2 = sin(ny * 2.5 - t2);
      float w3 = sin((nx + ny) * 2.0 + t3);
      float n  = noise(nx, ny, tn);

      float v = (w1 + w2 + w3) * 0.25 + (n - 0.5) * 0.6; // ~[-1..1]
      v = constrain(v * 0.5 + 0.5, 0, 1); // -> [0..1]

      // Subtle bluish caustics (keep alpha low)
      int a = int(10 + 35 * v);
      int r = int(4 + 14 * v);
      int g = int(6 + 18 * v);
      int b = int(12 + 38 * v);

      waterTex.pixels[y * wT + x] = color(r, g, b, a);
    }
  }

  waterTex.updatePixels();
  waterTex.endDraw();
}

void loadWaterFrames() {
  ArrayList<PImage> frames = new ArrayList<PImage>();
  int i = 0;
  while (true) {
    String filename = "water_texture/" + nf(i, 4) + ".png";
    PImage img = loadImage(filename);
    if (img == null) break;
    frames.add(img);
    i++;
  }
  if (frames.size() == 0) {
    waterFramesAvailable = false;
    waterFrames = null;
    if (useWaterFrames) {
      useWaterFrames = false;
    }
    warnMissingWaterFrames();
    return;
  }
  waterFrames = frames.toArray(new PImage[frames.size()]);
  waterFrameCount = waterFrames.length;
  waterFramesAvailable = true;
}

int advanceWaterFrame() {
  if (waterFrameCount == 0) return 0;
  int now = millis();
  if (waterLastMs == 0) {
    waterLastMs = now;
    return waterFrameIndex;
  }
  float dt = (now - waterLastMs) / 1000.0;
  waterLastMs = now;
  if (waterFPS <= 0) return waterFrameIndex;
  waterFrameAccum += dt * waterFPS;
  int advance = int(waterFrameAccum);
  if (advance > 0) {
    waterFrameIndex = (waterFrameIndex + advance) % waterFrameCount;
    waterFrameAccum -= advance;
  }
  return waterFrameIndex;
}

void warnMissingWaterFrames() {
  if (waterFramesWarned) return;
  println("[WARN] Missing water texture frames in data/water_texture; falling back to procedural water.");
  waterFramesWarned = true;
}
