ArrayList<Gusano> debugNeighborsScratch = new ArrayList<Gusano>();
PVector debugFlowScratch = new PVector(0, 0);
PVector debugGradScratch = new PVector(0, 0);
PVector debugAvgVel = new PVector(0, 0);
PVector debugSteerScratch = new PVector(0, 0);
PVector debugVelScratch = new PVector(0, 0);
PVector debugHeadingScratch = new PVector(0, 0);

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
    stroke(255, 40);
    ellipse(cabeza.x, cabeza.y, mouseSenseRadius * 2, mouseSenseRadius * 2);

    // Neighbor sensing range
    stroke(255, 60);
    ellipse(cabeza.x, cabeza.y, neighborSenseRadius * 2, neighborSenseRadius * 2);

    // Tactile separation range
    stroke(255, 90);
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
        stroke(255, 120);
        line(cabeza.x, cabeza.y, targetHead.x, targetHead.y);
        fill(255, 120);
        float mx = (cabeza.x + targetHead.x) * 0.5;
        float my = (cabeza.y + targetHead.y) * 0.5;
        text(g.id + " -> " + target.id, mx + 4, my - 4);
      }
    }

    // Label near head
    fill(255, 200);
    String persona = (g.personalityLabel != null) ? g.personalityLabel : g.stateLabel();
    text(g.id + " " + persona, cabeza.x + 6, cabeza.y - 6);
    if (debugJellyMotion) {
      fill(255, 170);
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
  debugAvgVel.set(0, 0);
  for (Gusano g : gusanos) {
    debugAvgVel.add(g.vel);
  }
  debugAvgVel.div(max(1, gusanos.size()));

  float cx = width * 0.5;
  float cy = height * 0.5;
  float scale = 60;

  pushStyle();
  stroke(255, 140);
  line(cx, cy, cx + debugAvgVel.x * scale, cy + debugAvgVel.y * scale);
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
    queryNeighbors(head.x, head.y, debugNeighborsScratch);
    int scanned = debugNeighborsScratch.size();
    for (Gusano other : debugNeighborsScratch) {
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
  int shyCount = 0;
  int aggressiveCount = 0;
  for (Gusano g : gusanos) {
    if (g == null) continue;
    changesTotal += g.moodChangeCount;
    switch (g.state) {
      case Gusano.SHY:
        shyCount++;
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
                " states: SHY=" + shyCount +
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
  stroke(255, alpha);
  line(x, y, ex, ey);
  float ah = 4;
  line(ex, ey, ex - cos(ang + PI * 0.75) * ah, ey - sin(ang + PI * 0.75) * ah);
  line(ex, ey, ex - cos(ang - PI * 0.75) * ah, ey - sin(ang - PI * 0.75) * ah);
  if (label != null && label.length() > 0) {
    fill(255, alpha);
    textSize(10);
    text(label, ex + 3, ey - 3);
  }
  popStyle();
}

void drawVecArrowColor(float x, float y, PVector v, float scale, int r, int g, int b, int a, String label) {
  if (v == null) return;
  if (v.magSq() < 0.0001) return;
  float vx = v.x * scale;
  float vy = v.y * scale;
  float ex = x + vx;
  float ey = y + vy;
  float ang = atan2(vy, vx);

  pushStyle();
  stroke(r, g, b, a);
  line(x, y, ex, ey);
  float ah = 4;
  line(ex, ey, ex - cos(ang + PI * 0.75) * ah, ey - sin(ang + PI * 0.75) * ah);
  line(ex, ey, ex - cos(ang - PI * 0.75) * ah, ey - sin(ang - PI * 0.75) * ah);
  if (label != null && label.length() > 0) {
    fill(r, g, b, a);
    textSize(9);
    text(label, ex + 3, ey - 3);
  }
  popStyle();
}

void drawWakeFlowVectors() {
  int cols = 22;
  int rows = 14;
  float cellW = width / (float)cols;
  float cellH = height / (float)rows;
  float flowScale = 28;
  float gradScale = 22;

  for (int ix = 0; ix < cols; ix++) {
    float x = (ix + 0.5) * cellW;
    for (int iy = 0; iy < rows; iy++) {
      float y = (iy + 0.5) * cellH;

      if (useFlow) {
        sampleFlow(x, y, debugFlowScratch);
        if (debugFlowScratch.magSq() > 0.0001) {
          drawVecArrowColor(x, y, debugFlowScratch, flowScale, 30, 120, 255, 140, "");
        }
      }

      if (useWake) {
        sampleWakeGradient(x, y, debugGradScratch);
        if (debugGradScratch.magSq() > 0.0001) {
          drawVecArrowColor(x, y, debugGradScratch, gradScale, 255, 80, 80, 140, "");
        }
      }
    }
  }

  pushStyle();
  textSize(10);
  fill(255, 200);
  float lx = width - 140;
  float ly = height - 22;
  text("blue=flow", lx, ly);
  fill(255, 200);
  text("red=grad", lx, ly + 12);
  popStyle();
}

void drawDebugHelp() {
  pushStyle();
  textSize(12);
  fill(255, 170);
  float x = 12;
  float y = 18;
  float lh = 14;
  text("Debug toggles:", x, y); y += lh;
  text("S: steering overlay " + (debugSteering ? "ON" : "off"), x, y); y += lh;
  text("O: objectives " + (debugObjetivos ? "ON" : "off"), x, y); y += lh;
  text("M: mean flow log " + (debugFlowMean ? "ON" : "off") + " (console)", x, y); y += lh;
  text("B: neighbor stats log " + (debugNeighborStats ? "ON" : "off") + " (console)", x, y); y += lh;
  text("U: mood stats log " + (debugMoodStats ? "ON" : "off") + " (console)", x, y); y += lh;
  text("P: state logs " + (debugStateChanges ? "ON" : "off") + " (console)", x, y); y += lh;
  text("N: steering neighbors " + (debugSteeringNeighbors ? "ON" : "off"), x, y); y += lh;
  text("D: mood debug " + (DEBUG_MOOD ? "ON" : "off"), x, y); y += lh;
  text("J: jelly motion debug " + (debugJellyMotion ? "ON" : "off"), x, y); y += lh;
  text("C: cycle debug " + (debugCycles ? "ON" : "off"), x, y); y += lh;
  text("L: biological vectors " + (debugBiologicalVectors ? "ON" : "off"), x, y); y += lh;
  text("W: wake heatmap " + (debugWake ? "ON" : "off"), x, y); y += lh;
  text("F: wake/flow vectors " + (debugWakeVectors ? "ON" : "off"), x, y); y += lh;
  text("I: water interaction " + (showWaterInteraction ? "ON" : "off"), x, y); y += lh;
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
    debugSteerScratch.set(g.steerSmoothed);
    if (debugSteerScratch.magSq() > 0.0001) {
      debugSteerScratch.normalize().mult(scale * 0.8);
      stroke(0, 100, 255, 180);
      line(head.x, head.y, head.x + debugSteerScratch.x, head.y + debugSteerScratch.y);
    }
    
    // 4. ALIGNMENT INDICATOR - Dot product between heading and velocity
    debugHeadingScratch.set(cos(g.headAngle), sin(g.headAngle));
    debugVelScratch.set(g.vel);
    float velMag = debugVelScratch.mag();
    if (velMag > 0.1) {
      debugVelScratch.normalize();
      float alignment = PVector.dot(debugHeadingScratch, debugVelScratch);
      
      // Color: Green = aligned, Yellow = perpendicular, Red = backwards
      int r = (int)map(alignment, -1, 1, 255, 0);
      int gr = (int)map(abs(alignment), 0, 1, 255, 200);
      fill(r, gr, 0, 180);
      noStroke();
      ellipse(head.x, head.y - 20, 12, 12);
      
      // Label
      fill(255, 200);
      textSize(9);
      text("align:" + nf(alignment, 0, 2), head.x + 8, head.y - 18);
    }
    
    // 5. PHASE INDICATOR (propulsion vs coast)
    float contractCurve = g.pulseContractCurve(g.pulsePhase);
    String phaseLabel = contractCurve > 0.1 ? "THRUST" : "COAST";
    fill(255, 200);
    textSize(10);
    text(phaseLabel, head.x - 15, head.y + 30);
  }
  
  // Legend (top-right)
  fill(255, 150);
  textSize(11);
  float lx = width - 160;
  float ly = 20;
  text("Bio Vectors (L):", lx, ly);
  strokeWeight(2);
  stroke(0, 200, 0); line(lx, ly + 12, lx + 20, ly + 12); 
  fill(255, 150); noStroke(); text("Heading", lx + 25, ly + 16);
  stroke(200, 0, 0); line(lx, ly + 26, lx + 20, ly + 26);
  fill(255, 150); text("Velocity", lx + 25, ly + 30);
  stroke(0, 100, 255); line(lx, ly + 40, lx + 20, ly + 40);
  fill(255, 150); text("Steer Desire", lx + 25, ly + 44);
  fill(255, 150); text("● = alignment", lx, ly + 58);
  
  popStyle();
}
