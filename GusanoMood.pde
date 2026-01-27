class GusanoMood {
  Gusano g;
  ArrayList<Gusano> neighborsScratch = new ArrayList<Gusano>();

  GusanoMood(Gusano g) {
    this.g = g;
  }

  void setState(int newState, float duration) {
    int oldState = g.state;
    if (newState == Gusano.AGGRESSIVE && oldState != Gusano.AGGRESSIVE) {
      if (debugStateChanges) {
        Segmento head = g.segmentos.get(0);
        float minDist = minDistToWall(head);
        float wallProx = wallProximity(head, 100);
        int now = millis();
        boolean recentClampX = (now - g.lastClampMsX) < 500;
        boolean recentClampY = (now - g.lastClampMsY) < 500;
        logAggressiveEntry(oldState, minDist, wallProx, g.debugVmagNow, g.debugSpeedDelta, recentClampX, recentClampY);
      }
    }
    boolean changed = (newState != g.state);
    if (!changed && newState != g.lastState) {
      changed = true;
    }
    if (changed) {
      g.moodChangeCount++;
      int now = millis();
      if (debugMoodStats && now - g.lastMoodChangeMs >= 200) {
        println("Gusano " + g.id + " mood " + stateLabelFor(oldState) + " -> " + stateLabelFor(newState));
      }
      g.lastMoodChangeMs = now;
      g.lastState = newState;
    }
    g.prevMood = oldState;
    g.lastMoodChangeFrame = frameCount;
    g.moodCandidate = newState;
    g.moodCandidateFrames = 0;
    g.state = newState;
    g.stateTimer = 0;
    g.stateDuration = duration;
    g.moodBlend = 0;
  }

  void updateState(float dt, boolean speedSpike) {
    // Mood switching disabled: lock each jellyfish to its base personality state.
    if (g.state != g.baseMood) {
      g.state = g.baseMood;
      g.stateTimer = 0;
      g.moodBlend = 1.0;
    }
    // If there's a sudden speed spike, push the mood blend towards fully applied
    // so the visual/behavioral response is immediate.
    if (speedSpike) {
      g.moodBlend = max(g.moodBlend, 0.8);
    }

    g.stateTimer += dt;
  }

  void applyMood(float dt) {
    float blendRate = 1.0 - pow(0.92, dt * 60.0);
    g.moodBlend = lerp(g.moodBlend, 1.0, blendRate);

    float moodStrength = 1.0;
    switch(g.state) {
      case Gusano.SHY:
        moodStrength = lerp(0.85, 1.15, g.timidity);
        break;
      case Gusano.AGGRESSIVE:
        moodStrength = lerp(0.85, 1.15, g.aggression);
        break;
    }

    float targetPulseRate = g.basePulseRate;
    float targetPulseStrength = g.basePulseStrength;
    float targetDrag = g.baseDrag;
    float targetSink = g.baseSinkStrength;
    float targetTurn = g.baseTurnRate;
    float targetFollowScale = 1.0;
    float targetTurbScale = 1.0;
    float targetHeadNoise = 1.0;

    switch(g.state) {
      case Gusano.SHY:
        targetPulseRate = g.basePulseRate * 0.85;
        targetPulseStrength = g.basePulseStrength * 0.7;
        targetDrag = g.baseDrag * 1.01;
        targetSink = g.baseSinkStrength * 1.25;
        targetTurn = g.baseTurnRate * 1.4;
        targetFollowScale = 1.1;
        targetTurbScale = 0.7;
        targetHeadNoise = 1.3;
        break;
      case Gusano.AGGRESSIVE:
        targetPulseRate = g.basePulseRate * 1.35; // Faster rhythm = more attack bursts
        targetPulseStrength = g.basePulseStrength * 1.3; // Stronger contractions
        targetDrag = g.baseDrag * 0.96; // Lower drag for momentum-based pursuit
        targetTurn = g.baseTurnRate * 1.5;
        targetFollowScale = 1.1;
        targetTurbScale = 1.2;
        targetHeadNoise = 0.8;
        break;
    }

    targetPulseRate = g.basePulseRate + (targetPulseRate - g.basePulseRate) * moodStrength;
    targetPulseStrength = g.basePulseStrength + (targetPulseStrength - g.basePulseStrength) * moodStrength;
    targetDrag = g.baseDrag + (targetDrag - g.baseDrag) * moodStrength;
    targetSink = g.baseSinkStrength + (targetSink - g.baseSinkStrength) * moodStrength;
    targetTurn = g.baseTurnRate + (targetTurn - g.baseTurnRate) * moodStrength;
    targetFollowScale = 1.0 + (targetFollowScale - 1.0) * moodStrength;
    targetTurbScale = 1.0 + (targetTurbScale - 1.0) * moodStrength;
    targetHeadNoise = 1.0 + (targetHeadNoise - 1.0) * moodStrength;

    targetPulseRate = lerp(g.basePulseRate, targetPulseRate, g.moodBlend);
    targetPulseStrength = lerp(g.basePulseStrength, targetPulseStrength, g.moodBlend);
    targetDrag = lerp(g.baseDrag, targetDrag, g.moodBlend);
    targetSink = lerp(g.baseSinkStrength, targetSink, g.moodBlend);
    targetTurn = lerp(g.baseTurnRate, targetTurn, g.moodBlend);
    targetFollowScale = lerp(1.0, targetFollowScale, g.moodBlend);
    targetTurbScale = lerp(1.0, targetTurbScale, g.moodBlend);
    targetHeadNoise = lerp(1.0, targetHeadNoise, g.moodBlend);

    float smooth = 1.0 - pow(0.98, dt * 60.0);
    smooth = constrain(smooth, 0.01, 0.2);

    g.pulseRate = lerp(g.pulseRate, targetPulseRate, smooth);
    g.pulseStrength = lerp(g.pulseStrength, targetPulseStrength, smooth);
    g.drag = constrain(lerp(g.drag, targetDrag, smooth), 0.85, 0.99);
    g.sinkStrength = max(0.0, lerp(g.sinkStrength, targetSink, smooth));
    g.buoyancyLift = g.sinkStrength * 0.3;
    g.turnRate = constrain(lerp(g.turnRate, targetTurn, smooth), 0.015, 0.22);  // Increased from 0.15
    g.followMoodScale = lerp(g.followMoodScale, targetFollowScale, smooth);
    g.turbulenceMoodScale = lerp(g.turbulenceMoodScale, targetTurbScale, smooth);
    g.headNoiseScale = lerp(g.headNoiseScale, targetHeadNoise, smooth);
  }

  void updateColor() {
    g.targetColor = paletteForState(g.state);
    g.currentColor = lerpColor(g.currentColor, g.targetColor, g.colorLerpSpeed);
  }

  color paletteForState(int s) {
    float a = JELLY_ALPHA;
    switch(s) {
      case Gusano.SHY:
        return color(red(JELLY_SHY), green(JELLY_SHY), blue(JELLY_SHY), a);
      case Gusano.AGGRESSIVE:
        return color(red(JELLY_AGGRO), green(JELLY_AGGRO), blue(JELLY_AGGRO), a);
      default:
        return color(0, 66);
    }
  }

  String stateLabel() {
    switch(g.state) {
      case Gusano.SHY: return "SHY";
      case Gusano.AGGRESSIVE: return "AGGRESSIVE";
      default: return "UNKNOWN";
    }
  }

  String stateLabelFor(int s) {
    switch(s) {
      case Gusano.SHY: return "SHY";
      case Gusano.AGGRESSIVE: return "AGGRESSIVE";
      default: return "UNKNOWN";
    }
  }

  float minDistToWall(Segmento head) {
    return min(min(head.x, width - head.x), min(head.y, height - head.y));
  }

  float wallProximity(Segmento head, float margin) {
    float minDist = minDistToWall(head);
    return constrain(1.0 - (minDist / max(1.0, margin)), 0, 1);
  }

  void logAggressiveEntry(int prevState, float minDist, float wallProx,
                          float vmagNow, float speedDelta,
                          boolean recentClampX, boolean recentClampY) {
    int now = millis();
    if (now == g.lastAggressiveEntryMs) return;
    g.lastAggressiveEntryMs = now;
    println("[AGG] id=" + g.id +
            " state=" + stateLabelFor(Gusano.AGGRESSIVE) +
            " prev=" + stateLabelFor(prevState) +
            " minWall=" + nf(minDist, 0, 1) +
            " prox=" + nf(wallProx, 0, 2) +
            " v=" + nf(vmagNow, 0, 2) +
            " d=" + nf(speedDelta, 0, 2) +
            " clampX=" + (recentClampX ? "1" : "0") +
            " clampY=" + (recentClampY ? "1" : "0"));
  }
}
