// ============================================================
// GusanoBody.pde
// ============================================================

class GusanoBody {
  Gusano g;
  GusanoBody(Gusano g_) { g = g_; }

  // Cap fluid wake strength to prevent feedback loops
  float maxWakeStrength = 3.5;

  void actualizar() {
    // Soft wall repulsion (pre-clamp), prevents "cornered = frozen" feel
    g.aplicarRepulsionParedes();

    float spawnEase = g.spawnEaseNow;
    float pulse = g.pulseNow;

    // Update body segments (only active ones)
    int nAct = constrain(g.segActivos, 1, g.segmentos.size());

    for (int i = 1; i < nAct; i++) {
      Segmento seg = g.segmentos.get(i);
      Segmento segAnterior = g.segmentos.get(i - 1);

      // Single fluid sample per segment per frame (cached for rendering)
      PVector velFluidoSeg = fluido.obtenerVelocidad(seg.x, seg.y);
      float alturaFluidoSeg = fluido.obtenerAltura(seg.x, seg.y);

      g.cacheVx[i] = velFluidoSeg.x;
      g.cacheVy[i] = velFluidoSeg.y;
      g.cacheH[i]  = alturaFluidoSeg;

      // Follow previous segment + slight fluid offset
      float targetX = segAnterior.x + velFluidoSeg.x * 6;
      float targetY = segAnterior.y + velFluidoSeg.y * 6 - alturaFluidoSeg * 0.2;
      
      // Tail position factor (0 at head → 1 at tail)
      float tailT = (nAct <= 1) ? 1.0 : (i / (float)(nAct - 1));
      
      // --- Natural tentacle motion (SIMPLIFIED FOR SUBTLETY) ---
      // Single coherent wave propagates down body with gradual intensity
      // COMPLETELY SKIP during rest phases for true stillness
      if (!g.tentaclePaused && g.variant != 4) {
        // Calculate perpendicular direction to movement
        float mvx = segAnterior.x - segAnterior.prevX;
        float mvy = segAnterior.y - segAnterior.prevY;
        float mvMag = sqrt(mvx*mvx + mvy*mvy);
        
        if (mvMag > 0.1) {
          // Perpendicular vector (rotated 90 degrees)
          float perpX = -mvy / mvMag;
          float perpY = mvx / mvMag;
          
          // SINGLE primary wave: clean, coherent oscillation down body
          float wavePhase = g.tentaclePhase - (i * g.tentacleLagMul * 0.15);
          
          // Simple sine wave (one frequency component only)
          float baseWave = sin(wavePhase);
          
          // Gentle amplitude modulation along body (ramps up toward tail)
          // BUT: clamp to tentacle region (back 40%), no motion in bell (front 60%)
          float tentacleStart = 0.6;  // Bell is front 60% (more conservative)
          float tentacleAmp = 0.0;
          
          if (tailT > tentacleStart) {
            // Smooth ramp: 0 at tentacleStart → 1 at tail
            float tentacleT = (tailT - tentacleStart) / (1.0 - tentacleStart);
            // Cubic easing for smooth natural falloff
            tentacleAmp = tentacleT * tentacleT * tentacleT;
          }
          
          // Apply personality: arousal reduces undulation (tense = straight)
          float arousalDamp = (1.0 - g.arousal * 0.5);
          
          // Final wave: subtle and controlled
          float waveOffset = baseWave * g.tentacleWaveAmp * tentacleAmp * arousalDamp;
          
          // Apply perpendicular displacement
          targetX += perpX * waveOffset;
          targetY += perpY * waveOffset;
        }
      }

      seg.seguir(targetX, targetY, velocidad * g.speedMul);

      // --- Fluid drag + wake (stronger toward the tail) ---
      
      // Progressive lag: tail segments respond more slowly (trailing effect)
      // Increased values create heavier, more meditative motion
      float lagFactor = lerp(1.0, 0.50, tailT * g.tentacleLagMul);

      // Much stronger drag on tail for graceful, heavy movement
      // Head has minimal drag (responsive), tail is very sluggish
      float drag = lerp(0.04, 0.45, tailT)
                 + 0.12 * (1.0 - pulse)
                 + 0.06 * (1.0 - g.arousal)
                 - 0.03 * g.userMode;

      float mvx = seg.x - seg.prevX;
      float mvy = seg.y - seg.prevY;

      // Apply fluid drag (stronger on tail)
      mvx = lerp(mvx, velFluidoSeg.x, drag);
      mvy = lerp(mvy, velFluidoSeg.y, drag);
      
      // Apply lag factor (tail trails behind significantly)
      mvx *= lagFactor;
      mvy *= lagFactor;

      float sp = sqrt(mvx*mvx + mvy*mvy);

      // Increased momentum loss creates silk-like drifting motion
      float slow = 1.0 - (0.035 + 0.035 * tailT) * constrain(sp / 5.0, 0, 1);
      mvx *= slow;
      mvy *= slow;

      seg.x = seg.prevX + mvx;
      seg.y = seg.prevY + mvy;

      // Directional wake: jellyfish create visible disturbances as they move
      if (sp > 0.08) {  // Lowered threshold from 0.15 to show more wake
        // Grace period: skip wake for first 45 frames after spawn (about 0.75 seconds)
        int framesSinceSpawn = frameCount - g.spawnFrame;
        if (framesSinceSpawn > 45) {
          float radio = lerp(18, 32, tailT);  // Increased from 12-22 for more visible wake
          float fuerza = constrain(
            sp * lerp(1.2, 2.0, tailT)  // Increased wake force
              * (1.0 + 0.8 * pulse + 0.5 * g.arousal)  // Enhanced arousal effect
              * lerp(1.0, 1.20, g.userMode)
              * spawnEase,
            0, 6.0  // Increased max wake strength from 4.0
          );
          // Stronger wake cap for more visible interaction
          float wakeStrength = constrain(fuerza, 0, 4.5);  // Increased from 2.0
          fluido.perturbarDir(seg.x, seg.y, radio, mvx, mvy, wakeStrength);
        }
      }

      seg.actualizar();
    }

    // Enforce rope-like length constraints so the body can't "stretch" unnaturally
    g.aplicarRestriccionesCuerpo();
    
    // Advance tentacle wave phase with pauses
    if (g.tentaclePaused) {
      // Check if pause is over
      if (frameCount >= g.tentacleResumeFrame) {
        g.tentaclePaused = false;
      }
    } else {
      // Advance phase normally
      float prevPhase = g.tentaclePhase;
      g.tentaclePhase += g.tentacleWaveFreq;
      
      // Detect cycle completion (phase wrapped around)
      if (prevPhase < TWO_PI && g.tentaclePhase >= TWO_PI) {
        g.tentaclePhase -= TWO_PI;  // normalize
        
        // Randomly pause after completing a cycle
        if (random(1) < g.tentaclePauseChance) {
          g.tentaclePaused = true;
          int pauseFrames = int(random(g.tentaclePauseMin, g.tentaclePauseMax));
          g.tentacleResumeFrame = frameCount + pauseFrames;
        }
      }
    }

    // Keep inactive segments collapsed to the last active segment (avoids stray drawing)
    Segmento ancla = g.segmentos.get(nAct - 1);
    for (int i = nAct; i < g.segmentos.size(); i++) {
      Segmento s = g.segmentos.get(i);
      s.x = ancla.x;
      s.y = ancla.y;
      s.prevX = ancla.x;
      s.prevY = ancla.y;
      s.actualizar();
    }

    // Keep cached fluid values valid for inactive segments (match the last active segment)
    int last = max(0, nAct - 1);
    for (int i = nAct; i < numSegmentos; i++) {
      g.cacheVx[i] = g.cacheVx[last];
      g.cacheVy[i] = g.cacheVy[last];
      g.cacheH[i]  = g.cacheH[last];
    }
    
    // Advance animation time (needed for shape animation)
    // All variants now have independent animation timing with rest periods
    if (g.animPaused) {
      // Check if pause is over
      if (frameCount >= g.animResumeFrame) {
        g.animPaused = false;
        g.lastAnimCycleFrame = frameCount;  // reset activity timer
      }
    } else {
      // Advance animation time
      float prevTime = g.animTime;
      g.animTime += g.animSpeed;  // use variant-specific speed
      
      // Shorter cycles for more natural breathing rhythm
      float cycleLength = TWO_PI * 0.75;  // ~6 seconds per cycle
      int framesSinceLastCycle = frameCount - g.lastAnimCycleFrame;
      
      if (floor(prevTime / cycleLength) < floor(g.animTime / cycleLength)) {
        // Only allow pause if organism has been active for minimum time
        if (framesSinceLastCycle >= g.animMinActiveFrames) {
          // Randomly pause after completing a cycle
          if (random(1) < g.animPauseChance) {
            g.animPaused = true;
            int pauseFrames = int(random(g.animPauseMin, g.animPauseMax));
            g.animResumeFrame = frameCount + pauseFrames;
          }
        }
        g.lastAnimCycleFrame = frameCount;  // update last cycle time
      }
    }
  }
}