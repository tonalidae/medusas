// ============================================================
// GusanoBody.pde
// ============================================================

class GusanoBody {
  Gusano g;
  GusanoBody(Gusano g_) { g = g_; }

  // Cap fluid wake strength to prevent feedback loops
  float maxWakeStrength = 3.5;

  void actualizar() {
    // ===== TEST MODE: Physics disabled for shape verification =====
    /*
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
      
      // --- Natural tentacle motion ---
      // Variants 0-3: Complex spiral behavior (inspired by parametric animation)
      // Variant 4: Simple trailing (keeps original digital organism character)
      if (g.variant != 4) {
        // Calculate perpendicular direction to movement
        float mvx = segAnterior.x - segAnterior.prevX;
        float mvy = segAnterior.y - segAnterior.prevY;
        float mvMag = sqrt(mvx*mvx + mvy*mvy);
        
        if (mvMag > 0.1) {
          // Perpendicular vector (rotated 90 degrees)
          float perpX = -mvy / mvMag;
          float perpY = mvx / mvMag;
          
          // Phase grouping: creates discrete tentacle behaviors (inspired by i%6 in parametric code)
          float phaseGroup = i % 5;  // 5 distinct groups
          
          // Spiral phase: creates rotating wave pattern with group variation
          float spiralPhase = g.tentaclePhase - (i * 0.3 * g.tentacleLagMul) + phaseGroup * TWO_PI / 5.0;
          float angleOffset = tailT * PI; // Phase rotation along body
          
          // Frequency variation per group (subtle diversity)
          float freqVariation = 1.0 + (phaseGroup / 20.0);
          
          // Layered oscillations (inspired by parametric sketch's multiple frequency components)
          // Similar to: k=5*cos(i/8), e=5*cos(y/9), mag(k,e)/(6+i%5)
          float wave1 = sin(spiralPhase * freqVariation + angleOffset);
          float wave2 = sin(spiralPhase * 1.6 + angleOffset * 2.3) * 0.5; // Higher frequency, lower amp
          float wave3 = cos(spiralPhase * 0.7 + i * 0.2) * 0.3; // Slow rotating component
          
          // Angular twist: atan2-based spiral (creates DNA-helix effect)
          float segAngle = atan2(seg.y - segAnterior.y, seg.x - segAnterior.x);
          float spiralTwist = sin(segAngle * 3.0 + spiralPhase) * 0.25;
          
          // Radial distance from head (distance field modulation)
          float dx = seg.x - g.segmentos.get(0).x;
          float dy = seg.y - g.segmentos.get(0).y;
          float distFromHead = sqrt(dx*dx + dy*dy) / 100.0;
          float radialFreedom = pow(constrain(distFromHead, 0, 1), 0.8);
          
          // Radial modulation: amplitude grows and oscillates toward tail
          float radialMod = (1.0 + sin(tailT * PI * 2.0 + spiralPhase * 0.5) * 0.4) * (0.6 + 0.4 * radialFreedom);
          
          // Combined wave with spiral characteristics
          float waveOffset = (wave1 + wave2 + wave3 + spiralTwist) * g.tentacleWaveAmp * radialMod;
          
          // CRITICAL: Only apply to tentacles (back 60%), preserve bell shape (front 40%)
          // This maintains the compact jellyfish bell while letting tentacles flow
          float tentacleStart = 0.4;  // Bell is front 40%
          if (tailT > tentacleStart) {
            float tentacleT = (tailT - tentacleStart) / (1.0 - tentacleStart);
            waveOffset *= lerp(0.0, 1.0, tentacleT * tentacleT); // Quadratic ramp
          } else {
            waveOffset *= 0.0;  // No oscillation in bell region
          }
          
          // Reduced during high arousal (tense = straighter)
          waveOffset *= (1.0 - g.arousal * 0.4);
          
          // Apply perpendicular displacement
          targetX += perpX * waveOffset;
          targetY += perpY * waveOffset;
        }
      }

      seg.seguir(targetX, targetY, velocidad * g.speedMul);

      // --- Fluid drag + wake (stronger toward the tail) ---
      
      // Progressive lag: tail segments respond more slowly (trailing effect)
      float lagFactor = lerp(1.0, 0.70, tailT * g.tentacleLagMul);

      float drag = lerp(0.05, 0.18, tailT)
                 + 0.10 * (1.0 - pulse)
                 + 0.04 * (1.0 - g.arousal)
                 - 0.04 * g.userMode;

      float mvx = seg.x - seg.prevX;
      float mvy = seg.y - seg.prevY;

      mvx = lerp(mvx, velFluidoSeg.x, drag);
      mvy = lerp(mvy, velFluidoSeg.y, drag);
      
      // Apply lag factor (tail trails behind)
      mvx *= lagFactor;
      mvy *= lagFactor;

      float sp = sqrt(mvx*mvx + mvy*mvy);

      // Tiny momentum loss when pushing the medium (a bit stronger on tail)
      float slow = 1.0 - (0.02 + 0.02 * tailT) * constrain(sp / 6.0, 0, 1);
      mvx *= slow;
      mvy *= slow;

      seg.x = seg.prevX + mvx;
      seg.y = seg.prevY + mvy;

      // Directional wake: radius and strength grow slightly toward the tail
      if (sp > 0.10) {
        // Grace period: skip wake for first 45 frames after spawn (about 0.75 seconds)
        int framesSinceSpawn = frameCount - g.spawnFrame;
        if (framesSinceSpawn > 45) {
          float radio = lerp(14, 30, tailT);
          float fuerza = constrain(
            sp * lerp(1.2, 2.2, tailT)
              * (1.0 + 0.8 * pulse + 0.6 * g.arousal)
              * lerp(1.0, 1.28, g.userMode)
              * spawnEase,
            0, 7.0
          );
          // Cap wake strength to prevent feedback loops
          float wakeStrength = constrain(fuerza, 0, maxWakeStrength);
          fluido.perturbarDir(seg.x, seg.y, radio, mvx, mvy, wakeStrength);
        }
      }

      seg.actualizar();
    }

    // Enforce rope-like length constraints so the body can't "stretch" unnaturally
    g.aplicarRestriccionesCuerpo();
    
    // Advance tentacle wave phase
    g.tentaclePhase += g.tentacleWaveFreq;

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
    */
    // ==================================================================
  }
}