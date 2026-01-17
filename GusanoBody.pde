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
      float targetX = segAnterior.x + velFluidoSeg.x * 10;
      float targetY = segAnterior.y + velFluidoSeg.y * 10 - alturaFluidoSeg * 0.3;

      seg.seguir(targetX, targetY, velocidad * g.speedMul);

      // --- Fluid drag + wake (stronger toward the tail) ---
      float tailT = (nAct <= 1) ? 1.0 : (i / (float)(nAct - 1));

      float drag = lerp(0.08, 0.22, tailT)
                 + 0.10 * (1.0 - pulse)
                 + 0.04 * (1.0 - g.arousal)
                 - 0.02 * g.userMode;

      float mvx = seg.x - seg.prevX;
      float mvy = seg.y - seg.prevY;

      mvx = lerp(mvx, velFluidoSeg.x, drag);
      mvy = lerp(mvy, velFluidoSeg.y, drag);

      float sp = sqrt(mvx*mvx + mvy*mvy);

      // Tiny momentum loss when pushing the medium (a bit stronger on tail)
      float slow = 1.0 - (0.02 + 0.02 * tailT) * constrain(sp / 6.0, 0, 1);
      mvx *= slow;
      mvy *= slow;

      seg.x = seg.prevX + mvx;
      seg.y = seg.prevY + mvy;

      // Directional wake: radius and strength grow slightly toward the tail
      if (sp > 0.10) {
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

      seg.actualizar();
    }

    // Enforce rope-like length constraints so the body can't "stretch" unnaturally
    g.aplicarRestriccionesCuerpo();

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
  }
}