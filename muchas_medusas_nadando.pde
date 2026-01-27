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

// Simple controls
boolean useWaterFrames = true;
boolean showWaterTex = true;
// Blend mode choice: false -> BLEND (subtle), true -> SCREEN (gentle brighten)
boolean useScreenBlend = false;
float waterAlpha = 25; // tint alpha when drawing overlay (0-255) — lowered for greater transparency
float waterFPS = 12.0;

ArrayList<Gusano> gusanos;
int numGusanos = 7;
int numSegmentos = 30;

float timeScale = 0.001;
float t = 0;
boolean debugSteering = false;
boolean debugWake = false;
boolean debugFlow = false;
boolean debugObjetivos = true;
boolean debugStateChanges = false;
boolean debugFlowMean = false;
boolean debugNeighborStats = false;
boolean debugMoodStats = false;
boolean debugSteeringNeighbors = false;
boolean debugHelp = true;
boolean showHead = false;
boolean debugJellyMotion = false;
boolean debugJumps = false;
boolean AUTO_HEAL_NANS = false;
boolean debugCycles = false;
boolean debugBiologicalVectors = false;






// --- Jelly motion tuning (minimal, reversible knobs) ---
// Tuning notes:
// UNDULATION_MAX: overall lateral drift amount; lower = less snake-wiggle.
// UNDULATION_SPEED_EXP: higher exponent keeps drift at low speed, fades later at high speed.
// GLIDE_STEER_SCALE: wander/sway multiplier during glide; lower = calmer coast.
// GLIDE_HEAD_NOISE_SCALE: head turbulence during glide; lower = steadier bell lead.
// GLIDE_BODY_TURB_SCALE: body turbulence during glide; lower = less body shimmer.
// FOLLOW_CONTRACTION_BOOST / FOLLOW_GLIDE_REDUCE: body pull-in vs lag through pulse.
float UNDULATION_MAX = 0.15;
float UNDULATION_SPEED_EXP = 2.0;
float GLIDE_STEER_SCALE = 0.25;
float GLIDE_HEAD_NOISE_SCALE = 0.4;
float GLIDE_BODY_TURB_SCALE = 0.55;
float FOLLOW_CONTRACTION_BOOST = 1.15;
float FOLLOW_GLIDE_REDUCE = 0.7;
float SIDE_SLIP_DAMP = 0.05; // Lower = less sideways slip (more diagonal motion)
float THRUST_SMOOTH_ALPHA = 0.18; // Lower = smoother, slower response
float RECOVERY_THRUST_SCALE = 0.18; // Small tail force during relaxation
float DRAG_RELAX_SCALE = 1.03; // Slightly higher drag during relaxation
float DRAG_CONTRACT_SCALE = 0.96; // Slightly lower drag during contraction
float CYCLE_EMA_ALPHA = 0.2; // Rolling average smoothing for cycle debug
float STEER_SMOOTH_ALPHA = 0.18; // Lower = smoother turns, higher = snappier
float STEER_FLIP_DOT = -0.2; // If desired steer points opposite, damp the flip
float STEER_FLIP_SLOW = 0.15; // Extra damping factor on flips
float MAX_TURN_RAD = 0.25; // Max turn per frame (~14 deg)

boolean LOCK_MOOD_TO_PERSONALITY = true;

// --- Stability tuning (multi-agent robustness) ---
int ATTN_MIN = 2;
int ATTN_MAX = 6;
float ATTN_FACTOR = 0.25;
int COHESION_HYST_MS = 300;

float MAX_STEER_MOUSE = 6.0;
float MAX_STEER_WALL = 6.0;
float MAX_STEER_SEP = 4.0;
float MAX_STEER_COH = 2.0;
float MAX_STEER_WANDER = 1.8;
float MAX_STEER_SWAY = 1.2;
float MAX_STEER_AGGRO = 8.0;
float MAX_TOTAL_STEER = 8.0;

int POST_CLAMP_CALM_MS = 450;
float POST_CLAMP_STEER_SCALE = 0.4;

float JUMP_STEP_THR = 80;
float SEG_SNAP_THR = 80;

// --- Mood stabilization toggles (A/B) ---
boolean STABILIZE_MOOD = true;
boolean DEBUG_MOOD = true;

// --- Mood stabilization config (conservative defaults) ---
int MOOD_COOLDOWN_FRAMES = 30;   // ~0.5s at 60fps
int MOOD_DWELL_FRAMES = 10;      // condition must persist
float MOOD_EMA_ALPHA = 0.08;     // smoothing for noisy inputs
float AGG_ENTER_THR = 0.6;
float AGG_EXIT_THR = 0.4;
float SHY_ENTER_THR = 0.6;
float SHY_EXIT_THR = 0.4;
float MOOD_PROX_RADIUS = 180;

boolean useWander = true;
boolean useWallAvoid = true;
boolean useWake = true;
boolean useFlow = true;
boolean useSeparation = true;
boolean useCohesion = true;
boolean usePursuit = true;

float lastMouseX = 0;
float lastMouseY = 0;
float mouseSpeed = 0;

float followThreshold = 80;
int lastNeighborStatsLogMs = 0;
int lastMoodStatsLogMs = 0;
int lastMoodStatsTotal = 0;
int lastMoodSummaryFrame = 0;

// --- Render-safe clamp margins (keep full body on screen) ---
float clampMarginX = 120;
float clampMarginTop = 80;
float clampMarginBottom = 260;

// --- Spatial hash grid (local interactions: Rain World vibe) ---
HashMap<Long, ArrayList<Gusano>> spatialGrid = new HashMap<Long, ArrayList<Gusano>>();
// Cell size should be >= max interaction radius (cohesion/pursuit). Adjust as needed.
float gridCellSize = 260;

void setup() {
  size(1280, 800, P2D);
  stroke(0, 66);

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
  background(#050008);
  t = millis() * timeScale;

  // Draw water overlay (either frames or procedural half-res buffer)
  if (showWaterTex) {
    // Choose blend: BLEND for subtle alpha compositing, SCREEN for gentle brightening
      blendMode(BLEND);
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

  updateWakeGrid();
  rebuildSpatialGrid();
  if (mousePressed || mouseSpeed > 12) {
    depositWakeBlob(mouseX, mouseY, 70, userDeposit);
  }
  if (debugWake) {
    drawWakeGrid();
  }

  for (Gusano gusano : gusanos) {
    gusano.actualizar();
    gusano.dibujarForma();
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

// Controles para ajustar parametros
//void keyPressed() {
//  if (key == '+' || key == '=') {
//    numGusanos = min(8, numGusanos + 1);
//    reiniciarGusanos();
//  } else if (key == '-' || key == '_') {
//    numGusanos = max(1, numGusanos - 1);
//    reiniciarGusanos();
//  } else if (key == ' ') {
//    // Espacio para reiniciar
//    reiniciarGusanos();
//  }
//}

void keyPressed() {
  if (key == 'o' || key == 'O') {
    debugObjetivos = !debugObjetivos;
  } else if (key == 'p' || key == 'P') {
    debugStateChanges = !debugStateChanges;
  } else if (key == 's' || key == 'S') {
    debugSteering = !debugSteering;
  } else if (key == 'm' || key == 'M') {
    debugFlowMean = !debugFlowMean;
  } else if (key == 'b' || key == 'B') {
    debugNeighborStats = !debugNeighborStats;
  } else if (key == 'u' || key == 'U') {
    debugMoodStats = !debugMoodStats;
  } else if (key == 'n' || key == 'N') {
    debugSteeringNeighbors = !debugSteeringNeighbors;
  } else if (key == 'd' || key == 'D') {
    DEBUG_MOOD = !DEBUG_MOOD;
  } else if (key == 'v' || key == 'V') {
    STABILIZE_MOOD = !STABILIZE_MOOD;
  } else if (key == 'h' || key == 'H') {
    debugHelp = !debugHelp;
  } else if (key == 'j' || key == 'J') {
    debugJellyMotion = !debugJellyMotion;
  } else if (key == 'c' || key == 'C') {
    debugCycles = !debugCycles;
    println("[DEBUG] debugCycles=" + debugCycles);
  } else if (key == 'k' || key == 'K') {
    LOCK_MOOD_TO_PERSONALITY = !LOCK_MOOD_TO_PERSONALITY;
    println("[MOOD] LOCK_MOOD_TO_PERSONALITY=" + LOCK_MOOD_TO_PERSONALITY);
  } else if (key == 'g' || key == 'G') {
    debugJumps = !debugJumps;
    println("[DEBUG] debugJumps=" + debugJumps);
  } else if (key == 'x' || key == 'X') {
    AUTO_HEAL_NANS = !AUTO_HEAL_NANS;
    println("[DEBUG] AUTO_HEAL_NANS=" + AUTO_HEAL_NANS);
  } else if (key == '+' || key == '=') {
    numGusanos = min(32, numGusanos + 1);
    reiniciarGusanos();
  } else if (key == '-' || key == '_') {
    numGusanos = max(1, numGusanos - 1);
    reiniciarGusanos();
  } else if (key == 'q' || key == 'Q') {
    showHead = !showHead;
  } else if (key == '1') {
    useFlow = !useFlow;
  } else if (key == '2') {
    useWake = !useWake;
  } else if (key == '3') {
    useCohesion = !useCohesion;
  } else if (key == '4') {
    useSeparation = !useSeparation;
  } else if (key == '5') {
    useWander = !useWander;
  } else if (key == '6') {
    useWallAvoid = !useWallAvoid;
  } else if (key == 'l' || key == 'L') {
    debugBiologicalVectors = !debugBiologicalVectors;
    println("[DEBUG] debugBiologicalVectors=" + debugBiologicalVectors);
  }
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




// --- Water texture helpers ---
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

      // Subtle caustics: render as grayscale so overlay doesn't tint scene
      int a = int(10 + 35 * v);
      int gray = int(constrain(10 + 220.0 * v, 0, 255));
      waterTex.pixels[y * wT + x] = color(gray, gray, gray, a);
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
    // convert loaded frame to grayscale in-memory so overlay remains neutral
    img.filter(GRAY);
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

// --- Spatial grid helpers ---
long cellKey(int cx, int cy) {
  return (((long)cx) << 32) ^ (cy & 0xffffffffL);
}

void rebuildSpatialGrid() {
  spatialGrid.clear();
  if (gusanos == null) return;
  for (Gusano g : gusanos) {
    if (g == null || g.segmentos == null || g.segmentos.size() == 0) continue;
    Segmento h = g.segmentos.get(0);
    int cx = floor(h.x / gridCellSize);
    int cy = floor(h.y / gridCellSize);
    long key = cellKey(cx, cy);
    ArrayList<Gusano> bucket = spatialGrid.get(key);
    if (bucket == null) {
      bucket = new ArrayList<Gusano>();
      spatialGrid.put(key, bucket);
    }
    bucket.add(g);
  }
}

ArrayList<Gusano> queryNeighbors(float x, float y) {
  ArrayList<Gusano> out = new ArrayList<Gusano>();
  int cx = floor(x / gridCellSize);
  int cy = floor(y / gridCellSize);
  for (int oy = -1; oy <= 1; oy++) {
    for (int ox = -1; ox <= 1; ox++) {
      long key = cellKey(cx + ox, cy + oy);
      ArrayList<Gusano> bucket = spatialGrid.get(key);
      if (bucket != null) out.addAll(bucket);
    }
  }
  return out;
}

void drawDebugObjectives() {
  pushStyle();
  strokeWeight(1);
  textSize(12);

  for (Gusano g : gusanos) {
    Segmento cabeza = g.segmentos.get(0);

    float mouseSenseRadius = 350;
    float neighborSenseRadius = 180;
    float sepRadius = 55;

    // Sensory radius (mouse influence)
    noFill();
    stroke(0, 40);
    ellipse(cabeza.x, cabeza.y, mouseSenseRadius * 2, mouseSenseRadius * 2);

    // Neighbor sensing range
    stroke(0, 60);
    ellipse(cabeza.x, cabeza.y, neighborSenseRadius * 2, neighborSenseRadius * 2);

    // Tactile separation range
    stroke(0, 90);
    ellipse(cabeza.x, cabeza.y, sepRadius * 2, sepRadius * 2);

    // Aggro lock (1-to-1)
    if (g.state == Gusano.AGGRESSIVE && g.aggroTargetId >= 0) {
      Gusano target = null;
      for (Gusano other : gusanos) {
        if (other != null && other.id == g.aggroTargetId) {
          target = other;
          break;
        }
      }
      if (target != null && target.segmentos != null && target.segmentos.size() > 0) {
        Segmento targetHead = target.segmentos.get(0);
        stroke(0, 120);
        line(cabeza.x, cabeza.y, targetHead.x, targetHead.y);
        fill(0, 120);
        float mx = (cabeza.x + targetHead.x) * 0.5;
        float my = (cabeza.y + targetHead.y) * 0.5;
        text(g.id + " -> " + target.id, mx + 4, my - 4);
      }
    }

    // Label near head
    fill(0, 160);
    String persona = (g.personalityLabel != null) ? g.personalityLabel : g.stateLabel();
    text(g.id + " " + persona, cabeza.x + 6, cabeza.y - 6);
    if (millis() - g.lastFearTime < 1000) {
      fill(0, 120);
      text(g.lastFearReason, cabeza.x + 6, cabeza.y - 18);
    }
    if (debugJellyMotion) {
      fill(0, 120);
      text("c " + nf(g.debugContraction, 0, 2) + " glide " + nf(g.debugGlideScale, 0, 2),
           cabeza.x + 6, cabeza.y + 12);
      text("undu " + nf(g.debugUndulationGate, 0, 2) +
           " steer " + nf(g.debugWanderScale, 0, 2),
           cabeza.x + 6, cabeza.y + 24);
      text("head " + nf(g.debugHeadGlideScale, 0, 2) +
           " body " + nf(g.debugBodyGlideScale, 0, 2),
           cabeza.x + 6, cabeza.y + 36);
      text("hz " + nf(g.lastCycleHz, 0, 2) +
           " dist " + nf(g.lastCycleDist, 0, 2) +
           " spd " + nf(g.lastCycleSpeed, 0, 2),
           cabeza.x + 6, cabeza.y + 48);
      text("avgHz " + nf(g.avgCycleHz, 0, 2) +
           " avgDist " + nf(g.avgCycleDist, 0, 2) +
           " avgSpd " + nf(g.avgCycleSpeed, 0, 2),
           cabeza.x + 6, cabeza.y + 60);
    }

    if (debugSteeringNeighbors) {
      drawVecArrow(cabeza.x, cabeza.y, g.debugSteerMouse, 30, 140, "M");
      drawVecArrow(cabeza.x, cabeza.y, g.debugSteerWall, 30, 140, "W");
      drawVecArrow(cabeza.x, cabeza.y, g.debugSteerSep, 30, 160, "S");
      drawVecArrow(cabeza.x, cabeza.y, g.debugSteerCoh, 30, 160, "C");
      drawVecArrow(cabeza.x, cabeza.y, g.debugSteerWander, 30, 120, "R");
      drawVecArrow(cabeza.x, cabeza.y, g.debugSteerSway, 30, 120, "Y");
      drawVecArrow(cabeza.x, cabeza.y, g.debugSteerAggro, 30, 180, "A");
    }
  }

  popStyle();
}

void drawAverageVelocity() {
  if (gusanos == null || gusanos.size() == 0) return;
  PVector avg = new PVector(0, 0);
  for (Gusano g : gusanos) {
    avg.add(g.vel);
  }
  avg.div(max(1, gusanos.size()));

  float cx = width * 0.5;
  float cy = height * 0.5;
  float scale = 60;

  pushStyle();
  stroke(0, 120);
  line(cx, cy, cx + avg.x * scale, cy + avg.y * scale);
  noFill();
  ellipse(cx, cy, 8, 8);
  popStyle();
}

void debugNeighborStatsTick() {
  if (gusanos == null || gusanos.size() == 0) return;
  int now = millis();
  if (now - lastNeighborStatsLogMs < 1000) return;
  lastNeighborStatsLogMs = now;

  int totalScanned = 0;
  int maxScanned = 0;
  int counted = 0;
  for (Gusano g : gusanos) {
    if (g == null || g.segmentos == null || g.segmentos.size() == 0) continue;
    Segmento head = g.segmentos.get(0);
    ArrayList<Gusano> neighbors = queryNeighbors(head.x, head.y);
    int scanned = neighbors.size();
    for (Gusano other : neighbors) {
      if (other == g) {
        scanned = max(0, scanned - 1);
        break;
      }
    }
    totalScanned += scanned;
    if (scanned > maxScanned) maxScanned = scanned;
    counted++;
  }
  if (counted == 0) return;
  float avgScanned = totalScanned / (float)counted;
  int globalScan = max(0, gusanos.size() - 1);
  println("[NEIGH] avgScanned=" + nf(avgScanned, 0, 1) +
          " maxScanned=" + maxScanned +
          " global=" + globalScan +
          " gridCellSize=" + nf(gridCellSize, 0, 0));
}

void debugMoodStatsTick() {
  if (gusanos == null || gusanos.size() == 0) return;
  int now = millis();
  if (now - lastMoodStatsLogMs < 1000) return;

  int changesTotal = 0;
  int calmCount = 0;
  int curiousCount = 0;
  int shyCount = 0;
  int fearCount = 0;
  int aggressiveCount = 0;
  for (Gusano g : gusanos) {
    if (g == null) continue;
    changesTotal += g.moodChangeCount;
    switch (g.state) {
      case Gusano.CALM:
        calmCount++;
        break;
      case Gusano.CURIOUS:
        curiousCount++;
        break;
      case Gusano.SHY:
        shyCount++;
        break;
      case Gusano.FEAR:
        fearCount++;
        break;
      case Gusano.AGGRESSIVE:
        aggressiveCount++;
        break;
    }
  }
  float avgPer = changesTotal / (float)max(1, gusanos.size());
  float perMin = -1;
  if (lastMoodStatsLogMs > 0) {
    float elapsedMin = (now - lastMoodStatsLogMs) / 60000.0;
    if (elapsedMin > 0) {
      int delta = changesTotal - lastMoodStatsTotal;
      perMin = delta / elapsedMin;
    }
  }
  String line = "[MOOD] changesTotal=" + changesTotal +
                " avgPer=" + nf(avgPer, 0, 1) +
                " states: CALM=" + calmCount +
                " CUR=" + curiousCount +
                " SHY=" + shyCount +
                " FEAR=" + fearCount +
                " AGG=" + aggressiveCount;
  if (perMin >= 0) {
    line += " perMin=" + nf(perMin, 0, 1);
  }
  println(line);
  lastMoodStatsLogMs = now;
  lastMoodStatsTotal = changesTotal;
}

void debugMoodSummaryTick() {
  if (gusanos == null || gusanos.size() == 0) return;
  if (frameCount - lastMoodSummaryFrame < 60) return;
  lastMoodSummaryFrame = frameCount;

  int changesTotal = 0;
  int calmCount = 0;
  int curiousCount = 0;
  int shyCount = 0;
  int fearCount = 0;
  int aggressiveCount = 0;
  for (Gusano g : gusanos) {
    if (g == null) continue;
    changesTotal += g.moodChangeCount;
    switch (g.state) {
      case Gusano.CALM:
        calmCount++;
        break;
      case Gusano.CURIOUS:
        curiousCount++;
        break;
      case Gusano.SHY:
        shyCount++;
        break;
      case Gusano.FEAR:
        fearCount++;
        break;
      case Gusano.AGGRESSIVE:
        aggressiveCount++;
        break;
    }
  }
  float avgPer = changesTotal / (float)max(1, gusanos.size());

}

void drawVecArrow(float x, float y, PVector v, float scale, int alpha, String label) {
  if (v == null) return;
  if (v.magSq() < 0.0001) return;
  float vx = v.x * scale;
  float vy = v.y * scale;
  float ex = x + vx;
  float ey = y + vy;
  float ang = atan2(vy, vx);

  pushStyle();
  stroke(0, alpha);
  line(x, y, ex, ey);
  float ah = 4;
  line(ex, ey, ex - cos(ang + PI * 0.75) * ah, ey - sin(ang + PI * 0.75) * ah);
  line(ex, ey, ex - cos(ang - PI * 0.75) * ah, ey - sin(ang - PI * 0.75) * ah);
  if (label != null && label.length() > 0) {
    fill(0, alpha);
    textSize(10);
    text(label, ex + 3, ey - 3);
  }
  popStyle();
}

void drawDebugHelp() {
  pushStyle();
  textSize(12);
  fill(0, 170);
  float x = 12;
  float y = 18;
  float lh = 14;
  text("Debug toggles:", x, y); y += lh;
  text("S: steering overlay " + (debugSteering ? "ON" : "off"), x, y); y += lh;
  text("O: objectives " + (debugObjetivos ? "ON" : "off"), x, y); y += lh;
  text("M: mean flow log " + (debugFlowMean ? "ON" : "off") + " (console)", x, y); y += lh;
  text("B: neighbor stats log " + (debugNeighborStats ? "ON" : "off") + " (console)", x, y); y += lh;
  text("U: mood stats log " + (debugMoodStats ? "ON" : "off") + " (console)", x, y); y += lh;
  text("P: FEAR logs " + (debugStateChanges ? "ON" : "off") + " (console)", x, y); y += lh;
  text("N: steering neighbors " + (debugSteeringNeighbors ? "ON" : "off"), x, y); y += lh;
  text("D: mood debug " + (DEBUG_MOOD ? "ON" : "off"), x, y); y += lh;
  text("V: stabilize mood " + (STABILIZE_MOOD ? "ON" : "off"), x, y); y += lh;
  text("J: jelly motion debug " + (debugJellyMotion ? "ON" : "off"), x, y); y += lh;
  text("C: cycle debug " + (debugCycles ? "ON" : "off"), x, y); y += lh;
  text("K: lock mood to personality " + (LOCK_MOOD_TO_PERSONALITY ? "ON" : "off"), x, y); y += lh;
  text("G: jump/snap debug " + (debugJumps ? "ON" : "off"), x, y); y += lh;
  text("X: auto-heal NaNs " + (AUTO_HEAL_NANS ? "ON" : "off"), x, y); y += lh;
  text("L: biological vectors " + (debugBiologicalVectors ? "ON" : "off"), x, y); y += lh;
  text("+/-: jelly count (" + numGusanos + ")", x, y); y += lh;
  text("Q: show head " + (showHead ? "ON" : "off"), x, y); y += lh;
  text("H: help " + (debugHelp ? "ON" : "off"), x, y); y += lh;
  y += 4;
  text("Ablation toggles:", x, y); y += lh;
  text("1 flow " + (useFlow ? "ON" : "off") +
       "  2 wake " + (useWake ? "ON" : "off") +
       "  3 cohesion " + (useCohesion ? "ON" : "off"), x, y); y += lh;
  text("4 separation " + (useSeparation ? "ON" : "off") +
       "  5 wander " + (useWander ? "ON" : "off") +
       "  6 wall avoid " + (useWallAvoid ? "ON" : "off"), x, y);
  popStyle();
}

// --- Biological Vector Debug Visualization ---
// Shows heading vs velocity vs steering to diagnose "rigid sliding" issues
void drawBiologicalVectorDebug() {
  pushStyle();
  strokeWeight(2);
  
  for (Gusano g : gusanos) {
    Segmento head = g.segmentos.get(0);
    float scale = 40;
    
    // 1. HEADING (where the bell faces) - GREEN
    float hx = cos(g.headAngle) * scale;
    float hy = sin(g.headAngle) * scale;
    stroke(0, 200, 0, 200);
    line(head.x, head.y, head.x + hx, head.y + hy);
    fill(0, 200, 0);
    noStroke();
    ellipse(head.x + hx, head.y + hy, 6, 6);
    
    // 2. VELOCITY (actual movement) - RED
    float vScale = 8;
    stroke(200, 0, 0, 200);
    strokeWeight(2);
    line(head.x, head.y, head.x + g.vel.x * vScale, head.y + g.vel.y * vScale);
    
    // 3. STEERING DESIRE (where it wants to go) - BLUE
    PVector steer = g.steerSmoothed.copy();
    if (steer.magSq() > 0.0001) {
      steer.normalize().mult(scale * 0.8);
      stroke(0, 100, 255, 180);
      line(head.x, head.y, head.x + steer.x, head.y + steer.y);
    }
    
    // 4. ALIGNMENT INDICATOR - Dot product between heading and velocity
    PVector headingVec = new PVector(cos(g.headAngle), sin(g.headAngle));
    PVector velNorm = g.vel.copy();
    float velMag = velNorm.mag();
    if (velMag > 0.1) {
      velNorm.normalize();
      float alignment = PVector.dot(headingVec, velNorm);
      
      // Color: Green = aligned, Yellow = perpendicular, Red = backwards
      int r = (int)map(alignment, -1, 1, 255, 0);
      int gr = (int)map(abs(alignment), 0, 1, 255, 200);
      fill(r, gr, 0, 180);
      noStroke();
      ellipse(head.x, head.y - 20, 12, 12);
      
      // Label
      fill(0, 180);
      textSize(9);
      text("align:" + nf(alignment, 0, 2), head.x + 8, head.y - 18);
    }
    
    // 5. PHASE INDICATOR (propulsion vs coast)
    float contractCurve = g.pulseContractCurve(g.pulsePhase);
    String phaseLabel = contractCurve > 0.1 ? "THRUST" : "COAST";
    fill(contractCurve > 0.1 ? color(255, 150, 0) : color(100, 100, 200));
    textSize(10);
    text(phaseLabel, head.x - 15, head.y + 30);
  }
  
  // Legend (top-right)
  fill(0, 150);
  textSize(11);
  float lx = width - 160;
  float ly = 20;
  text("Bio Vectors (L):", lx, ly);
  strokeWeight(2);
  stroke(0, 200, 0); line(lx, ly + 12, lx + 20, ly + 12); 
  fill(0, 150); noStroke(); text("Heading", lx + 25, ly + 16);
  stroke(200, 0, 0); line(lx, ly + 26, lx + 20, ly + 26);
  fill(0, 150); text("Velocity", lx + 25, ly + 30);
  stroke(0, 100, 255); line(lx, ly + 40, lx + 20, ly + 40);
  fill(0, 150); text("Steer Desire", lx + 25, ly + 44);
  fill(0, 150); text("● = alignment", lx, ly + 58);
  
  popStyle();
}
