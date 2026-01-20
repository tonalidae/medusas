

// ============================================================
// GusanoRender.pde
//
// RENDERING PIPELINE
// Converts jellyfish body segments into point clouds using parametric equations
//
// ARCHITECTURE:
// 1. DEPTH SIMULATION: 3D ocean effect via vertical bobbing
//    - depthPhase: Oscillator for depth animation (sin wave)
//    - depthNow: Current depth (0=deep, 1=surface)
//    - Affects: size (depthScale), alpha (depthAlpha)
//
// 2. BIOLUMINESCENCE: Dynamic glow based on emotion & personality
//    - bioGlow = 1.0 + arousal*0.8 + userAttitude*0.6 * personalityGlow
//    - Higher arousal or curiosity = brighter jellyfish
//    - ADD blend mode creates luminescent effect
//
// 3. POINT CLOUD GENERATION: ~1200-10000 points per jellyfish
//    - Loop iteration 'i' maps to parametric coords (x_param, y_param)
//    - Parametric equations produce jellyfish-shaped point distribution
//    - verticalProgression (0-1) determines which body segment each point attaches to
//
// 4. SEGMENT MAPPING: Points follow rope-physics body
//    - Each point interpolates between adjacent segments
//    - Creates smooth deformation as jellyfish swims
//
// 5. FLUID DISPLACEMENT: Points ride water currents
//    - Cached fluid velocity per segment (performance)
//    - Interpolated to each render point
//    - Creates flowing tentacle effect
//
// 6. SHAPE VARIANTS: 6 different parametric equations (cases 0-5)
//    - Original jellyfish (cases 0-3 from prototype)
//    - Digital organism (case 4, from processing.org)  
//    - Spiral jellyfish (case 5, new addition)
//
// RENDERING STAGES (per frame):
//   1. Calculate depth bobbing (sin oscillation)
//   2. Compute bioluminescent glow multiplier
//   3. Determine point count (based on life, population, depth)
//   4. For each point:
//      a. Map i → parametric coords (x_param, y_param)
//      b. Compute vertical position in canonical shape
//      c. Find which body segments it maps to
//      d. Interpolate position between segments
//      e. Apply fluid displacement (cached samples)
//      f. Calculate final position via parametric equations
//      g. Draw point with appropriate color & alpha
//   5. Draw pulsing head marker
//
// PERFORMANCE NOTES:
// - Dynamic point density scales with population (fewer points per jellyfish when crowded)
// - Fade-in prevents spawn bloom (collapsed geometry → full expansion)
// - Fluid samples cached per-segment, not per-point (40x speedup)
// ============================================================

class GusanoRender {
  Gusano g;
  GusanoRender(Gusano g_) { g = g_; }

  void dibujarForma() {
    strokeWeight(1);

    // Simulate vertical depth movement (bobbing)
    g.depthPhase += g.depthFreq;
    float depthOsc = sin(g.depthPhase) * g.depthAmp;
    float depthNow = constrain(g.depthLayer + depthOsc, 0, 1);
    
    // Depth affects apparent size and visibility
    // Deeper (0) = smaller/dimmer, Surface (1) = larger/brighter
    float depthScale = lerp(0.65, 1.15, depthNow);
    float depthAlpha = lerp(0.55, 1.0, depthNow);

    // DRAMATIC BIOLUMINESCENCE: Strong glow for arousal and curiosity
    // Linear component: base contribution from state
    float bioGlow = 1.0 + g.arousal * 1.4 + max(0, g.userAttitude) * 1.2;  // Increased from 0.8, 0.6
    bioGlow *= lerp(0.85, 1.5, g.getGlowIntensity());  // Increased max from 1.35 to 1.5
    
    // Non-linear boost: excited jellyfish REALLY glow
    float excitement = g.arousal + max(0, g.userAttitude * 0.5);
    bioGlow *= (1.0 + excitement * excitement * 0.8);  // Squared for dramatic effect

    // Precompute once per draw call
    boolean isFire = (g.variant == 4);

    // ENHANCED: Brighter fire gradient colors for stronger bioluminescence
    color fireC0 = color(255, 255, 255);
    color fireC1 = color(255, 245, 180); // brighter mid-tone
    color fireC2 = color(255, 160, 60);  // more saturated orange
    color fireC3 = color(220, 60, 20);   // brighter red

    // As the jellyfish dies, it loses points (density) and segments (length)
    int nAct = constrain(g.segActivos, 1, numSegmentos);

    int puntosMaxBase = int(map(nAct, 1, numSegmentos, 1200, 10000));

    // More gusanos => scale density down a bit for performance + ecosystem balance
    // Apply depth scale for 3D ocean effect
    // Apply life stage scale modifier (ephyra are small, adults full-size)
    float effectiveScale = g.shapeScale * g.stageScaleMul;
    puntosMaxBase = int(puntosMaxBase * pointDensityMul * g.densityMul * depthScale * (effectiveScale * effectiveScale) / (0.60 * 0.60));

    // Fade-in to prevent initial oversaturation (ADD blend + collapsed geometry)
    // Extended to 75 frames (~1.25s) for gentler appearance
    float fade = constrain(g.ageFrames / 75.0, 0, 1);
    fade = fade * fade * (3.0 - 2.0 * fade); // smoothstep
    
    // Apply death/rebirth and spawn fade multipliers
    fade *= g.deathFade * g.spawnEaseNow;

    int puntosMax = max(80, int(puntosMaxBase * fade));

    for (int i = puntosMax; i > 0; i--) {
      float x_param = i % 200;
      float y_param = i / 43.0;

      // Calculate py for color gradient using variant-specific equation
      float k, e, d, py;
      switch(g.variant) {
        case 0:
          k = 3.5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 9;  // Reduced offset for larger head proportion
          d = (k*k + e*e) / 59.0 + 4.0;
          py = d * 52;
          break;
        case 1:
          k = 4.2 * cos(x_param / 12) * cos(y_param / 25);
          e = y_param / 7 - 11;  // Reduced offset for larger head proportion
          d = (k*k + e*e) / 50.0 + 3.0;
          py = d * 48;
          break;
        case 2:
          k = 3.0 * cos(x_param / 16) * cos(y_param / 35);
          e = y_param / 9 - 8;  // Reduced offset for larger head proportion
          d = (k*k + e*e) / 65.0 + 5.0;
          py = d * 56;
          break;
        case 3:
          k = 5.0 * cos(x_param / 10) * cos(y_param / 20);
          e = y_param / 6 - 12;  // Reduced offset for larger head proportion
          d = (k*k + e*e) / 45.0 + 2.0;
          py = d * 44;
          break;
        case 4:
        default:
          k = 5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 13;
          d = (k*k + e*e) / 59.0 + 4.0;
          py = d * 45;
          break;
      }

      float minPY = 100;
      float maxPY = 400;
      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);

      color cPoint;

      if (isFire) {
        float u = verticalProgression;
        if (u < 0.33)       cPoint = lerpColor(fireC0, fireC1, u / 0.33);
        else if (u < 0.66)  cPoint = lerpColor(fireC1, fireC2, (u - 0.33) / 0.33);
        else                cPoint = lerpColor(fireC2, fireC3, (u - 0.66) / 0.34);
      } else {
        cPoint = lerpColor(g.colorCabeza, g.colorCola, verticalProgression);
      }

      // DRAMATIC GLOW: Higher base alpha + boost when excited
      float baseAlpha = 120 + (bioGlow - 1.0) * 25;  // Add 25 per glow unit above base
      float enhancedAlpha = baseAlpha * fade * gusanosAlpha * depthAlpha * bioGlow * g.deathFade * g.spawnEaseNow;
      stroke(cPoint, enhancedAlpha);

      // Map points only onto the currently active body
      int maxIdx = max(0, nAct - 1);
      int segmentIndex = int(verticalProgression * maxIdx);
      segmentIndex = constrain(segmentIndex, 0, maxIdx);
      Segmento seg = g.segmentos.get(segmentIndex);

      float segmentProgression = (verticalProgression * maxIdx) - segmentIndex;
      float x, y;

      if (segmentIndex < nAct - 1) {
        Segmento nextSeg = g.segmentos.get(segmentIndex + 1);
        x = lerp(seg.x, nextSeg.x, segmentProgression);
        y = lerp(seg.y, nextSeg.y, segmentProgression);
      } else {
        x = seg.x;
        y = seg.y;
      }

      // ---- FAST: use cached fluid samples (per segment) ----
      float vx, vy, h;
      if (segmentIndex < nAct - 1) {
        vx = lerp(g.cacheVx[segmentIndex], g.cacheVx[segmentIndex + 1], segmentProgression);
        vy = lerp(g.cacheVy[segmentIndex], g.cacheVy[segmentIndex + 1], segmentProgression);
        h  = lerp(g.cacheH[segmentIndex],  g.cacheH[segmentIndex + 1],  segmentProgression);
      } else {
        vx = g.cacheVx[segmentIndex];
        vy = g.cacheVy[segmentIndex];
        h  = g.cacheH[segmentIndex];
      }

      x += vx * 0.5;
      y += vy * 0.5 - h * 0.2;

      // For the "digital organism" variant (id == 4), use the original web-style
      // parametrization x=i, y=i/235 so the pattern reads correctly.
      float xIn = x_param;
      float yIn = y_param;
      if (g.variant == 4) {
        xIn = i;
        yIn = i / 235.0;
      }

      dibujarPuntoForma(xIn, yIn, x, y, i);
    }

    // DRAMATIC HEAD GLOW: Brightest part of jellyfish, pulses strongly when aroused
    float life01 = constrain(g.vida / g.vidaMax, 0, 1);
    float headPulse = 1.0 + sin(g.phase) * (0.3 + g.arousal * 0.5);  // Stronger pulse when aroused
    float headGlow = bioGlow * (1.0 + g.arousal * 0.8);  // Extra boost for head
    float headAlpha = (160 + 160 * life01) * fade * headGlow * headPulse * g.deathFade * g.spawnEaseNow;  // Increased base from 140+120
    stroke(g.colorCabeza, headAlpha);
    
    // Subtle head marker that grows when excited (scaled by life stage)
    float headEffectiveScale = g.shapeScale * g.stageScaleMul;
    float headSize = 7 * headEffectiveScale * (1.0 + g.arousal * 0.2);  // Base 3, scaled by stage
    strokeWeight(max(1, headSize));
    point(g.segmentos.get(0).x, g.segmentos.get(0).y);
    strokeWeight(1);
  }

  void dibujarPuntoForma(float x, float y, float cx, float cy, int pointIndex) {
    float k, e, d, q, px, py;
    float headOffset = 184; // may be overridden per-shape

    switch(g.variant) {
    case 0:
      k = 3.5 * cos(x / 14) * cos(y / 30);  // Reduced amplitude for narrower shape
      e = y / 8 - 9;  // Reduced offset for larger head proportion
      d = (k*k + e*e) / 59.0 + 4.0;
      q = - 1.5 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - g.animTime * 2));  // Use local animTime
      px = q + 0.6;  // Reduced horizontal offset
      py = d * 52;  // Increased vertical stretch
      break;

    case 1:
      k = 4.2 * cos(x / 12) * cos(y / 25);  // Reduced amplitude
      e = y / 7 - 11;  // Reduced offset for larger head proportion
      d = (k*k + e*e) / 50.0 + 3.0;
      q = - 1.2 * sin(atan2(k, e) * e) + k * (2 + 5 / d * sin(d * d - g.animTime * 1.5));  // Use local animTime
      px = q + 0.8;  // Reduced horizontal offset
      // Add vertical swimming motion: inspired by c = d - t/18 + i%3*4, then 80*sin(c-d)
      float verticalOsc1 = g.verticalSwimAmp * sin(-g.animTime / g.verticalSwimPhaseDiv + (pointIndex % 3) * 4);
      py = d * 48 + verticalOsc1;  // Base vertical stretch + oscillation
      break;

    case 2:
      k = 3.0 * cos(x / 16) * cos(y / 35);  // Reduced amplitude for compact shape
      e = y / 9 - 8;  // Reduced offset for larger head proportion
      d = (k*k + e*e) / 65.0 + 5.0;
      q = - 2.0 * sin(atan2(k, e) * e) + k * (4 + 3 / d * sin(d * d - g.animTime * 2.5));  // Use local animTime
      px = q + 0.4;  // Reduced horizontal offset
      // Add vertical swimming motion with phase offset from i%3 pattern
      float verticalOsc2 = g.verticalSwimAmp * sin(-g.animTime / g.verticalSwimPhaseDiv + (pointIndex % 3) * 4);
      py = d * 56 + verticalOsc2;  // Base vertical stretch + oscillation
      break;

    case 3:
      k = 5.0 * cos(x / 10) * cos(y / 20);  // Reduced amplitude from very wide spread
      e = y / 6 - 12;  // Reduced offset for larger head proportion
      d = (k*k + e*e) / 45.0 + 2.0;
      q = - 2.5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - g.animTime * 3));  // Use local animTime
      px = q + 1.0;  // Reduced horizontal offset
      py = d * 44;  // Increased vertical stretch
      break;

    case 4:
      {
        // Digital organism (ported from the Processing web/p5 snippet)
        // Uses local animTime for independent pause control
        float tLocal = g.animTime;
        
        float k0 = (4.0 + sin(y * 2.0 - tLocal) * 3.0) * cos(x / 29.0);
        float e0 = y / 8.0 - 13.0;
        float d0 = mag(k0, e0);

        // Safe reciprocal for 0.3/k
        float kk = (abs(k0) < 1e-3) ? ((k0 < 0) ? -1e-3 : 1e-3) : k0;

        float q0 = 3.0 * sin(k0 * 2.0)
          + 0.3 / kk
          + sin(y / 25.0) * k0 * (9.0 + 4.0 * sin(e0 * 9.0 - d0 * 3.0 + tLocal * 2.0));

        float c0 = d0 - tLocal;

        // Place around (cx, cy) like the other variants
        px = q0 + 30.0 * cos(c0);
        py = q0 * sin(c0) + d0 * 39.0;

        // Different head offset so it sits nicely on the body
        headOffset = 220;
        break;
      }

    case 5:
      // NEW: Sixth variant - spiral jellyfish
      k = 3 * cos(x / 18) * sin(y / 22);
      e = y / 10 - 12;
      d = (k*k + e*e) / 55.0 + 3.5;
      float spiral = atan2(e, k) * 2.0;
      q = - 2.5 * sin(spiral + t * 0.5) + k * (3.5 + 4.5 / d * sin(d * d - t * 2.2));
      px = q * cos(spiral * 0.3) + 1.0;
      py = d * 42 + q * sin(spiral * 0.3) * 8;
      headOffset = 190;
      break;

    default:
      k = 5 * cos(x / 14) * cos(y / 30);
      e = y / 8 - 13;
      d = (k*k + e*e) / 59.0 + 4.0;
      q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
      px = q + 1.6;
      py = d * 45;
      break;
    }

    // Apply life stage scale modifier
    float s = g.shapeScale * g.stageScaleMul;
    point(px * s + cx, (py - headOffset) * s + cy);
  }
}