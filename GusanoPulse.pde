class GusanoPulse {
  Gusano g;

  GusanoPulse(Gusano g) {
    this.g = g;
  }

  void updatePhase(float dt) {
    // Organic pulse irregularity: real organisms don't have perfect metronome timing
    float pulseJitter = (noise(g.noiseOffset * 0.1, t * 0.3) - 0.5) * 0.15;
    float organicPulseRate = g.pulseRate * (1.0 + pulseJitter);

    float prevPhase = g.pulsePhase;
    g.pulsePhase += organicPulseRate * dt;
    if (g.pulsePhase >= 1.0) {
      g.pulsePhase -= 1.0;
    }
    if (g.pulsePhase < prevPhase) {
      int nowMs = millis();
      if (g.cycleStartMs > 0) {
        float dtCycle = (nowMs - g.cycleStartMs) / 1000.0;
        g.lastCycleHz = (dtCycle > 0.0001) ? (1.0 / dtCycle) : 0;
        g.lastCycleDist = dist(g.cycleStartX, g.cycleStartY, g.segmentos.get(0).x, g.segmentos.get(0).y);
        g.lastCycleSpeed = g.lastCycleHz * g.lastCycleDist;
        if (g.avgCycleHz <= 0) {
          g.avgCycleHz = g.lastCycleHz;
          g.avgCycleDist = g.lastCycleDist;
          g.avgCycleSpeed = g.lastCycleSpeed;
        } else {
          g.avgCycleHz = lerp(g.avgCycleHz, g.lastCycleHz, CYCLE_EMA_ALPHA);
          g.avgCycleDist = lerp(g.avgCycleDist, g.lastCycleDist, CYCLE_EMA_ALPHA);
          g.avgCycleSpeed = lerp(g.avgCycleSpeed, g.lastCycleSpeed, CYCLE_EMA_ALPHA);
        }
        if (debugCycles) {
          println("[CYCLE] id=" + g.id + " " + g.personalityLabel +
                  " state=" + g.stateLabel() +
                  " hz=" + nf(g.lastCycleHz, 0, 2) +
                  " dist=" + nf(g.lastCycleDist, 0, 2) +
                  " spd=" + nf(g.lastCycleSpeed, 0, 2) +
                  " avgHz=" + nf(g.avgCycleHz, 0, 2) +
                  " avgDist=" + nf(g.avgCycleDist, 0, 2) +
                  " avgSpd=" + nf(g.avgCycleSpeed, 0, 2));
        }
      }
      g.cycleStartMs = nowMs;
      g.cycleStartX = g.segmentos.get(0).x;
      g.cycleStartY = g.segmentos.get(0).y;
    }
  }

  // Contraction amount: 0..1 with contract/hold/release shaping
  float shape(float phase) {
    float c = max(0.0001, g.contractPortion);
    float h = max(0.0, g.holdPortion);
    float r = max(0.0001, 1.0 - c - h);

    float p = wrap01(phase);
    if (p < c) {
      float x = p / c;
      // Fast snap-in: ease-out
      return 1.0 - pow(1.0 - x, 3);
    } else if (p < c + h) {
      return 1.0;
    } else {
      float x = (p - c - h) / r;
      // Slow release: ease-in
      return 1.0 - pow(x, 2);
    }
  }

  // Thrust curve: only during contraction, peaking early/mid
  float contractCurve(float phase) {
    float c = max(0.0001, g.contractPortion);
    float p = wrap01(phase);
    if (p >= c) return 0;
    float x = p / c;
    return sin(PI * sqrt(x));
  }
}
