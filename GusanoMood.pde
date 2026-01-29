class GusanoMood {
  Gusano g;

  GusanoMood(Gusano g) {
    this.g = g;
  }

  void setState(int newState, float duration) {
    int oldState = g.state;
    if (newState == Gusano.FEAR && oldState != Gusano.FEAR) {
      if (debugStateChanges) {
        String reason = (g.lastFearReason != null && g.lastFearReason.length() > 0) ? g.lastFearReason : "UNKNOWN";
        logFearEntry(oldState, reason,
                     g.debugVmagNow, g.debugSpeedEMA, g.debugSpeedDelta, g.debugSpikeThreshold,
                     g.debugSpikeFrames, g.debugSpikeFramesRequired,
                     g.debugDt, g.debugDtNorm, g.debugFrameRate,
                     g.stateCooldown, g.fearCooldownFrames);
      }
    }
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
      if (newState == Gusano.FEAR) {
        g.lastFearUserMs = millis();
        g.fearMemory = 1.0;
      }
      if (newState == Gusano.FEAR || newState == Gusano.CALM) {
        Segmento head = g.segmentos.get(0);
        if (head != null) {
          float fearAmt = (newState == Gusano.FEAR) ? MOOD_FIELD_SPLAT : 0;
          float calmAmt = (newState == Gusano.CALM) ? MOOD_FIELD_SPLAT : 0;
          splatMoodField(head.x, head.y, fearAmt, calmAmt);
        }
      }
      g.moodChangeCount++;
      int now = millis();
      if (debugMoodStats && newState != Gusano.FEAR && now - g.lastMoodChangeMs >= 200) {
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

  int pickState() {
    float wCalm = 1.2;
    float wCurious = 0.4 + g.curiosity * 1.2;
    float wShy = 0.3 + g.timidity * 1.0;
    float wAggressive = 0.3 + g.aggression * 1.2;
    float userMem = g.userInterest * exp(-(millis() - g.lastUserSeenMs) / CURIOUS_STICK_MS);
    wCurious += 1.2 * userMem;
    wCurious += g.fieldCalm * (0.6 + 0.4 * g.social);
    wCalm += g.fieldCalm * (0.6 + g.social);
    wShy += g.fieldFear * (0.5 + 0.5 * g.timidity);
    wAggressive *= (1.0 - min(0.4, g.fieldFear * 0.25));

    Segmento head = g.segmentos.get(0);
    float margin = 100;

    float wallProximity = wallProximity(head, margin);
    wAggressive *= (1.0 - 0.8 * wallProximity);
    wCalm *= (1.0 + 0.6 * wallProximity);

    // Personality bias: keep states aligned with nature
    wAggressive *= lerp(0.6, 2.0, g.aggression);
    wShy *= lerp(0.6, 2.0, g.timidity);
    wCurious *= lerp(0.7, 1.7, g.curiosity);
    wCalm *= lerp(0.8, 1.6, g.social);

    float total = wCalm + wCurious + wShy + wAggressive;

    float r = random(total);
    if (r < wCalm) return Gusano.CALM;
    r -= wCalm;
    if (r < wCurious) return Gusano.CURIOUS;
    r -= wCurious;
    if (r < wShy) return Gusano.SHY;
    return Gusano.AGGRESSIVE;
  }

  void updateState(float dt, boolean speedSpike) {
    // Personality lock: disable FSM mood changes and keep the base mood.
    // This makes each jellyfish stay in its birth personality (shy stays shy, etc.).
    if (LOCK_MOOD_TO_PERSONALITY) {
      if (g.state != g.baseMood) {
        g.state = g.baseMood;
        g.stateTimer = 0;
        g.moodBlend = 1.0;
      }
      return;
    }

    g.stateTimer += dt;
    if (g.stateCooldown > 0) g.stateCooldown -= dt;
    if (g.postFearTimer > 0) g.postFearTimer -= dt;
    if (g.fearCooldownFrames > 0) g.fearCooldownFrames--;

    // Lingering curiosity: slow down timer when user was recently seen
    float userMem = g.userInterest * exp(-(millis() - g.lastUserSeenMs) / CURIOUS_STICK_MS);
    if (g.state == Gusano.CURIOUS && userMem > 0.05) {
      g.stateTimer = max(0, g.stateTimer - dt * 0.8 * userMem);
      g.stateDuration = max(g.stateDuration, 5.5 + 2.5 * userMem);
    }
    // Fear memory decays smoothly
    g.fearMemory = g.fearMemory * exp(-dt * 1000.0 / FEAR_MEMORY_MS);
    
    Segmento head = g.segmentos.get(0);
    MoodField mf = sampleMoodField(head.x, head.y);
    if (mf != null) {
      g.fieldFear = mf.fear;
      g.fieldCalm = mf.calm;
    } else {
      g.fieldFear = 0;
      g.fieldCalm = 0;
    }
    float fieldFear = g.fieldFear;
    float wallProx = wallProximity(head, 100);

    // --- Mood Stabilizer (isolated; does not change core logic) ---
    int neighborCount = 0;
    boolean proxValid = false;
    float proxRaw = 0;
    if (STABILIZE_MOOD || DEBUG_MOOD) {
      ArrayList<Gusano> neigh = queryNeighbors(head.x, head.y);
      neighborCount = max(0, neigh.size() - 1);
      if (neighborCount > 0) {
        float best = 1e9;
        for (Gusano other : neigh) {
          if (other == g) continue;
          Segmento oh = other.segmentos.get(0);
          float d = dist(head.x, head.y, oh.x, oh.y);
          if (d < best) best = d;
        }
        proxRaw = constrain(1.0 - (best / max(1.0, MOOD_PROX_RADIUS)), 0, 1);
        proxValid = true;
      }
    }
    float threatRaw = 0;
    if (g.debugSpikeThreshold > 0.0001) {
      threatRaw = constrain(g.debugSpeedDelta / g.debugSpikeThreshold, 0, 2);
    }
    threatRaw += fieldFear * 0.6;
    float curiosityRaw = g.curiosity;

    g.smoothedThreat = lerp(g.smoothedThreat, threatRaw, MOOD_EMA_ALPHA);
    g.smoothedProx = lerp(g.smoothedProx, proxRaw, MOOD_EMA_ALPHA);
    g.smoothedCuriosity = lerp(g.smoothedCuriosity, curiosityRaw, MOOD_EMA_ALPHA);
    // --- End Mood Stabilizer ---
    float threatScore = max(threatRaw, g.smoothedThreat);
    if (fieldFear > FIELD_FEAR_STARTLE_THRESHOLD && threatScore > FIELD_FEAR_THREAT_MIN) {
      g.fieldFearHoldFrames++;
    } else {
      g.fieldFearHoldFrames = 0;
    }
    boolean fieldFearStartle = g.fieldFearHoldFrames >= FIELD_FEAR_HOLD_FRAMES;
    boolean randomEligible = wallProx < 0.5 &&
                             g.debugVmagNow < 0.6 * g.maxSpeed &&
                             millis() > 3000 &&
                             g.postFearTimer <= 0;
    boolean randomFear = randomEligible && random(1) < 0.00005;
    boolean startle = speedSpike || randomFear;
    if (fieldFearStartle) startle = true;
    if (startle && g.state != Gusano.FEAR && g.stateCooldown <= 0 && g.fearCooldownFrames <= 0) {
      g.lastFearReason = speedSpike ? "SPIKE" : (randomFear ? "RANDOM" : "FIELD");
      if (!speedSpike && randomFear) g.lastFearReason = "RANDOM";
      g.lastFearTime = millis();
      g.stateCooldown = random(3.0, 6.0);
      g.fearCooldownFrames = int(random(180, 360));
      g.fieldFearHoldFrames = 0;
      if (shouldTransition(Gusano.FEAR, "startle:" + g.lastFearReason, true,
                           neighborCount, proxValid, proxRaw, threatRaw, wallProx)) {
        setState(Gusano.FEAR, random(1.4, 2.4));
      }
      return;
    }
    
    if (g.state == Gusano.FEAR && g.stateTimer >= g.stateDuration) {
      if (shouldTransition(Gusano.CALM, "fear_timeout", false,
                           neighborCount, proxValid, proxRaw, threatRaw, wallProx)) {
        setState(Gusano.CALM, random(2.0, 4.0));
        g.stateCooldown = random(3.0, 6.0);
        g.postFearTimer = 1.2;
      }
      return;
    }

    if (g.stateTimer >= g.stateDuration && g.stateCooldown <= 0) {
      int next = pickState();
      float dur = (next == Gusano.CALM) ? random(4.0, 8.0) : random(2.5, 6.0);
      dur *= stateAffinity(next);
      if (shouldTransition(next, "pick_state", false,
                           neighborCount, proxValid, proxRaw, threatRaw, wallProx)) {
        setState(next, dur);
        g.stateCooldown = 1.0;
      }
    } else if (g.stateTimer < g.stateDuration || g.stateCooldown > 0) {
      g.moodCandidate = g.state;
      g.moodCandidateFrames = 0;
    }
  }

  boolean shouldTransition(int proposed, String reason, boolean force,
                           int neighborCount, boolean proxValid, float proxRaw,
                           float threatRaw, float wallProx) {
    if (proposed == g.state) {
      g.moodCandidate = g.state;
      g.moodCandidateFrames = 0;
      return false;
    }

    boolean allowed = true;
    String blockReason = "";
    int cooldownLeft = 0;

    if (STABILIZE_MOOD && !force) {
      int since = frameCount - g.lastMoodChangeFrame;
      if (since < MOOD_COOLDOWN_FRAMES) {
        allowed = false;
        blockReason = "cooldown";
        cooldownLeft = MOOD_COOLDOWN_FRAMES - since;
      }

      if (g.moodCandidate != proposed) {
        g.moodCandidate = proposed;
        g.moodCandidateFrames = 1;
      } else {
        g.moodCandidateFrames++;
      }
      if (allowed && g.moodCandidateFrames < MOOD_DWELL_FRAMES) {
        allowed = false;
        blockReason = "dwell";
      }

      if (allowed && (proposed == Gusano.AGGRESSIVE || g.state == Gusano.AGGRESSIVE)) {
        float aggScore = g.aggression;
        if (g.state != Gusano.AGGRESSIVE && aggScore < AGG_ENTER_THR) {
          allowed = false;
          blockReason = "agg_hyst_enter";
        } else if (g.state == Gusano.AGGRESSIVE && aggScore > AGG_EXIT_THR) {
          allowed = false;
          blockReason = "agg_hyst_exit";
        }
      }

      if (allowed && (proposed == Gusano.SHY || g.state == Gusano.SHY)) {
        float shyScore = g.timidity;
        if (g.state != Gusano.SHY && shyScore < SHY_ENTER_THR) {
          allowed = false;
          blockReason = "shy_hyst_enter";
        } else if (g.state == Gusano.SHY && shyScore > SHY_EXIT_THR) {
          allowed = false;
          blockReason = "shy_hyst_exit";
        }
      }

      // Soft personality gate: discourage contradictory moods unless strong trigger
      if (allowed) {
        float gateThreat = max(threatRaw, g.smoothedThreat);
        if (g.baseMood == Gusano.SHY && proposed == Gusano.AGGRESSIVE) {
          if (gateThreat < 0.8) {
            allowed = false;
            blockReason = "persona_gate_shy";
          }
        } else if (g.baseMood == Gusano.AGGRESSIVE && proposed == Gusano.SHY) {
          if (gateThreat > 0.2) {
            allowed = false;
            blockReason = "persona_gate_agg";
          }
        }
      }
    } else {
      g.moodCandidate = proposed;
      g.moodCandidateFrames = 0;
    }

    if (DEBUG_MOOD && allowed) {
      float minWall = minDistToWall(g.segmentos.get(0));
      logMoodDecision(proposed, true, reason,
                      cooldownLeft, g.moodCandidateFrames, neighborCount,
                      proxRaw, g.smoothedProx, proxValid,
                      threatRaw, g.smoothedThreat,
                      minWall, wallProx,
                      g.debugVmagNow, g.debugSpeedDelta);
      if (proposed == Gusano.AGGRESSIVE && !proxValid) {
        println("[MOOD_WARN] id=" + g.id + " AGG proxValid=0 reason=" + reason);
      }
    }

    return allowed;
  }

  void logMoodDecision(int proposed, boolean allowed, String reason,
                       int cooldownLeft, int candFrames, int neighborCount,
                       float proxRaw, float proxSm, boolean proxValid,
                       float threatRaw, float threatSm,
                       float minWall, float wallProx,
                       float vmagNow, float speedDelta) {
    println("[MOOD] id=" + g.id +
            " from=" + stateLabelFor(g.state) +
            " to=" + stateLabelFor(proposed) +
            " allowed=" + (allowed ? "1" : "0") +
            " reason=" + reason +
            " cooldownLeft=" + cooldownLeft +
            " candFrames=" + candFrames +
            " neighCount=" + neighborCount +
            " proxRaw=" + nf(proxRaw, 0, 2) +
            " proxSm=" + nf(proxSm, 0, 2) +
            " proxValid=" + (proxValid ? "1" : "0") +
            " threatRaw=" + nf(threatRaw, 0, 2) +
            " threatSm=" + nf(threatSm, 0, 2) +
            " minWall=" + nf(minWall, 0, 1) +
            " wallProx=" + nf(wallProx, 0, 2) +
            " v=" + nf(vmagNow, 0, 2) +
            " d=" + nf(speedDelta, 0, 2));
  }

  float stateAffinity(int s) {
    switch(s) {
      case Gusano.CALM:
        return lerp(0.8, 1.4, g.social);
      case Gusano.CURIOUS:
        return lerp(0.8, 1.4, g.curiosity);
      case Gusano.SHY:
        return lerp(0.8, 1.4, g.timidity);
      case Gusano.AGGRESSIVE:
        return lerp(0.8, 1.4, g.aggression);
      default:
        return 1.0;
    }
  }

  void applyMood(float dt) {
    float blendRate = 1.0 - pow(0.92, dt * 60.0);
    g.moodBlend = lerp(g.moodBlend, 1.0, blendRate);

    float moodStrength = 1.0;
    switch(g.state) {
      case Gusano.CURIOUS:
        moodStrength = lerp(0.7, 1.3, g.curiosity);
        break;
      case Gusano.SHY:
        moodStrength = lerp(0.7, 1.3, g.timidity);
        break;
      case Gusano.AGGRESSIVE:
        moodStrength = lerp(0.7, 1.3, g.aggression);
        break;
      case Gusano.FEAR:
        moodStrength = lerp(0.8, 1.4, g.timidity);
        break;
    }
    // Expose to renderer so color can reflect intensity
    g.moodHeat = moodStrength;

    float targetPulseRate = g.basePulseRate;
    float targetPulseStrength = g.basePulseStrength;
    float targetDrag = g.baseDrag;
    float targetSink = g.baseSinkStrength;
    float targetTurn = g.baseTurnRate;
    float targetFollowScale = 1.0;
    float targetTurbScale = 1.0;
    float targetHeadNoise = 1.0;

    switch(g.state) {
      case Gusano.CALM:
        targetPulseRate = g.basePulseRate * 0.9;
        targetPulseStrength = g.basePulseStrength * 0.95;
        targetDrag = g.baseDrag * 1.01;
        targetTurn = g.baseTurnRate * 1.3;
        targetTurbScale = 0.9;
        targetHeadNoise = 1.1;
        break;
      case Gusano.CURIOUS:
        targetPulseRate = g.basePulseRate * 1.1;
        targetPulseStrength = g.basePulseStrength * 0.9;
        targetTurn = g.baseTurnRate * 1.8;
        targetTurbScale = 1.05;
        targetHeadNoise = 1.5;
        break;
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
      case Gusano.FEAR:
        targetPulseRate = g.basePulseRate * 1.8;
        targetPulseStrength = g.basePulseStrength * 1.8;
        targetDrag = g.baseDrag * 0.94;
        targetTurn = g.baseTurnRate * 1.5;
        targetFollowScale = 1.2;
        targetTurbScale = 0.6;
        targetHeadNoise = 1.4;
        break;
      case Gusano.AGGRESSIVE:
        targetPulseRate = g.basePulseRate * 1.8; // Faster rhythm = more attack bursts
        targetPulseStrength = g.basePulseStrength * 1.6; // Stronger contractions
        targetDrag = g.baseDrag * 0.94; // Lower drag for momentum-based pursuit
        targetTurn = g.baseTurnRate * 1.7;
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

    // Fatigue influence
    targetPulseStrength *= g.energy;
    targetDrag *= (1.0 + (1.0 - g.energy) * ENERGY_LOW_DRAG_BOOST);

    if (g.postFearTimer > 0) {
      float freeze = constrain(g.postFearTimer / 1.2, 0, 1);
      targetTurbScale = lerp(targetTurbScale, 0.4, freeze);
      targetHeadNoise = lerp(targetHeadNoise, 0.4, freeze);
      targetTurn = lerp(targetTurn, g.baseTurnRate * 0.6, freeze);
    }

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
    g.turnRate = constrain(lerp(g.turnRate, targetTurn, smooth), 0.015, 0.15);
    g.followMoodScale = lerp(g.followMoodScale, targetFollowScale, smooth);
    g.turbulenceMoodScale = lerp(g.turbulenceMoodScale, targetTurbScale, smooth);
    g.headNoiseScale = lerp(g.headNoiseScale, targetHeadNoise, smooth);
  }

  void updateColor() {
    g.targetColor = paletteForState(g.state, g.moodHeat);
    g.currentColor = lerpColor(g.currentColor, g.targetColor, g.colorLerpSpeed);
  }

  color paletteForState(int s, float intensity) {
    // Base mood hues (RGB) chosen for quick readability
    color base;
    switch(s) {
      case Gusano.CALM:
        base = color(70, 150, 205);   // aqua blue
        break;
      case Gusano.CURIOUS:
        base = color(80, 210, 150);   // jade green
        break;
      case Gusano.SHY:
        base = color(185, 160, 220);  // lilac
        break;
      case Gusano.FEAR:
        base = color(245, 185, 80);   // amber
        break;
      case Gusano.AGGRESSIVE:
        base = color(230, 60, 135);   // hot magenta
        break;
      default:
        base = color(120);
        break;
    }
    // Intensity drives brightness/saturation bump
    float boost = constrain(intensity, 0.6, 1.5);
    boost *= (1.0 + g.fieldFear * 0.25 + g.fieldCalm * 0.15); // visualize local waves
    float r = constrain(red(base) * boost, 0, 255);
    float gC = constrain(green(base) * boost, 0, 255);
    float b = constrain(blue(base) * boost, 0, 255);
    // Alpha subtly scales with intensity for glow variation
    float a = constrain(60 * boost, 40, 110);
    return color(r, gC, b, a);
  }

  String stateLabel() {
    switch(g.state) {
      case Gusano.CALM: return "CALM";
      case Gusano.CURIOUS: return "CURIOUS";
      case Gusano.SHY: return "SHY";
      case Gusano.FEAR: return "FEAR";
      case Gusano.AGGRESSIVE: return "AGGRESSIVE";
      default: return "UNKNOWN";
    }
  }

  String stateLabelFor(int s) {
    switch(s) {
      case Gusano.CALM: return "CALM";
      case Gusano.CURIOUS: return "CURIOUS";
      case Gusano.SHY: return "SHY";
      case Gusano.FEAR: return "FEAR";
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

  void logFearEntry(int prevState, String reason,
                    float vmagNow, float speedEMA, float speedDelta, float spikeThreshold,
                    int spikeFrames, int spikeFramesRequired,
                    float dt, float dtNorm, float fps,
                    float stateCooldown, int fearCooldownFrames) {
    int now = millis();
    if (now == g.lastFearEntryMs) return;
    g.lastFearEntryMs = now;
    println("[FEAR] id=" + g.id +
            " prev=" + stateLabelFor(prevState) +
            " reason=" + reason +
            " v=" + nf(vmagNow, 0, 2) +
            " ema=" + nf(speedEMA, 0, 2) +
            " d=" + nf(speedDelta, 0, 2) +
            " thr=" + nf(spikeThreshold, 0, 2) +
            " frames=" + spikeFrames + "/" + spikeFramesRequired +
            " dt=" + nf(dt, 0, 4) +
            " dtN=" + nf(dtNorm, 0, 2) +
            " fps=" + nf(fps, 0, 1) +
            " cd=" + nf(stateCooldown, 0, 2) +
            " fearFrames=" + fearCooldownFrames);
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
