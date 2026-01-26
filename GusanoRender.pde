final int POINT_COUNT = 5000;
boolean baseReady = false;
float[][] baseQ = new float[4][POINT_COUNT];
float[][] baseQScale = new float[4][POINT_COUNT];
float[][] baseQPhase = new float[4][POINT_COUNT];
float[][] basePy = new float[4][POINT_COUNT];
float[][] baseV = new float[4][POINT_COUNT];

void ensureBasePrecomputed() {
  if (baseReady) return;
  float minPY = 100;
  float maxPY = 400;
  for (int variant = 0; variant < 4; variant++) {
    for (int idx = 0; idx < POINT_COUNT; idx++) {
      int i = idx + 1;
      float x_param = i % 200;
      float y_param = i / 35.0;

      float k, e, d, qBias, qScale, qPhase, py;

      switch(variant) {
        case 0:
          k = 5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 13;
          d = sq(mag(k, e)) / 59 + 4;
          qBias = - 3 * sin(atan2(k, e) * e) + k * 3;
          qScale = k * (4 / d);
          qPhase = d * d;
          py = d * 45;
          break;
        case 1:
          k = 6 * cos((x_param*1.1) / 12) * cos((y_param*0.9) / 25);
          e = (y_param*0.9) / 7 - 15;
          d = sq(mag(k, e)) / 50 + 3;
          qBias = - 2 * sin(atan2(k, e) * e) + k * 2;
          qScale = k * (5 / d);
          qPhase = d * d;
          py = d * 40;
          break;
        case 2:
          k = 4 * cos((x_param*0.9) / 16) * cos((y_param*1.1) / 35);
          e = (y_param*1.1) / 9 - 11;
          d = sq(mag(k, e)) / 65 + 5;
          qBias = - 4 * sin(atan2(k, e) * e) + k * 4;
          qScale = k * (3 / d);
          qPhase = d * d;
          py = d * 50;
          break;
        case 3:
          k = 7 * cos((x_param*1.2) / 10) * cos((y_param*0.8) / 20);
          e = (y_param*0.8) / 6 - 17;
          d = sq(mag(k, e)) / 45 + 2;
          qBias = - 5 * sin(atan2(k, e) * e) + k * 5;
          qScale = k * (6 / d);
          qPhase = d * d;
          py = d * 35;
          break;
        default:
          k = 5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 13;
          d = sq(mag(k, e)) / 59 + 4;
          qBias = - 3 * sin(atan2(k, e) * e) + k * 3;
          qScale = k * (4 / d);
          qPhase = d * d;
          py = d * 45;
          break;
      }

      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);
      baseQ[variant][idx] = qBias;
      baseQScale[variant][idx] = qScale;
      baseQPhase[variant][idx] = qPhase;
      basePy[variant][idx] = py;
      baseV[variant][idx] = verticalProgression;
    }
  }
  baseReady = true;
}

class GusanoRender {
  Gusano g;
  float alignDx = 0;
  float alignDy = 0;
  float[] vx = new float[POINT_COUNT];
  float[] vy = new float[POINT_COUNT];
  float[] tGrad = new float[POINT_COUNT];
  color baseColor;
  color glowColor;
  color topColor;
  color tailColor;
  float baseAlpha;
  float sizeT = 1.0;
  float glowMult = 2.4;
  float coreAlphaMult = 1.0;
  float tailAlphaFalloff = 1.0;
  float coreStrokeWeight = 1.0;
  boolean isShy;
  int effectiveCount = POINT_COUNT;
  int glowLayers = 5;
  boolean hasDebugCenter = false;
  float debugCenterX = 0;
  float debugCenterY = 0;
  float frameOffsetX = 0;
  float frameOffsetY = 0;

  GusanoRender(Gusano g) {
    this.g = g;
    ensureBasePrecomputed();
  }

  void dibujarForma() {
    prepareFrame();
    drawGlowPass();
    drawCorePass();
  }

  void prepareFrame() {
    // Bioluminescent glow pass + core pass for deep ocean visibility
    baseColor = g.currentColor;
    baseAlpha = alpha(baseColor);
    glowColor = baseColor;
    float sizeSpan = max(0.0001, JELLY_SIZE_MAX - JELLY_SIZE_MIN);
    sizeT = constrain((g.sizeFactor - JELLY_SIZE_MIN) / sizeSpan, 0, 1);
    glowMult = lerp(JELLY_SMALL_GLOW_MULT, JELLY_GLOW_MULT, sizeT);
    coreAlphaMult = JELLY_CORE_ALPHA_MULT * lerp(JELLY_SMALL_CORE_ALPHA_SCALE, 1.0, sizeT);
    tailAlphaFalloff = lerp(JELLY_SMALL_TAIL_ALPHA_FALLOFF, JELLY_TAIL_ALPHA_FALLOFF, sizeT);
    coreStrokeWeight = lerp(JELLY_SMALL_STROKE_WEIGHT, 1.0, sizeT);
    isShy = isCloseColor(baseColor, JELLY_SHY, JELLY_GLOW_MATCH_THR);
    boolean isTeal = isCloseColor(baseColor, JELLY_CALM, JELLY_GLOW_MATCH_THR) ||
                     isCloseColor(baseColor, JELLY_AGGRO, JELLY_GLOW_MATCH_THR);
    boolean isDom = (g.baseMood == Gusano.AGGRESSIVE);
    if (isDom) {
      // Dominant jellyfish: same special glow behavior, but using the DOM palette.
      float basePhase = t * JELLY_GLOW_SHIFT_SPEED + g.id * 0.7;
      float glowT = 0.5 + 0.5 * sin(basePhase);
      
      // Add slower, deeper pulse (heartbeat effect)
      float deepPulse = 0.5 + 0.5 * sin(t * 0.18 + g.id * 1.3);
      
      // Add pulse-cycle synchronization: brighten during contraction
      float pulseSync = g.pulseContractCurve(wrap01(g.pulsePhase + g.id * 0.13)) * 0.3;
      
      float glowIntensity = 2.8 + deepPulse * 0.6 + pulseSync * 0.8; // Strong, modulated by pulse
      glowIntensity *= lerp(JELLY_SMALL_SHY_GLOW_SCALE, 1.0, sizeT);
      
      // Add occasional flicker
      float nervousFlicker = 1.0 + 0.2 * sin(t * 0.7 + g.id * 0.5);
      glowIntensity *= nervousFlicker;
      
      // Three-color glow: brighter mid color accent for halo effect
      color glowRgb;
      if (glowT < 0.5) {
        glowRgb = lerpColor(JELLY_AGGRO_GLOW_START, JELLY_AGGRO_GLOW_MID, glowT * 2.0);
      } else {
        glowRgb = lerpColor(JELLY_AGGRO_GLOW_MID, JELLY_AGGRO_GLOW_END, (glowT - 0.5) * 2.0);
      }
      glowColor = color(red(glowRgb), green(glowRgb), blue(glowRgb), min(255, baseAlpha * glowIntensity));
    } else if (isShy) {
      // Shy jellyfish: enhanced bioluminescent glow with slow, pulsing heartbeat
      float basePhase = t * JELLY_GLOW_SHIFT_SPEED + g.id * 0.7;
      float glowT = 0.5 + 0.5 * sin(basePhase);
      
      // Add slower, deeper pulse (nervous heartbeat effect)
      float deepPulse = 0.5 + 0.5 * sin(t * 0.18 + g.id * 1.3);
      
      // Add pulse-cycle synchronization: brighten during contraction
      float pulseSync = g.pulseContractCurve(wrap01(g.pulsePhase + g.id * 0.13)) * 0.3;
      
      float glowIntensity = 2.8 + deepPulse * 0.6 + pulseSync * 0.8; // Much stronger, modulated by pulse
      glowIntensity *= lerp(JELLY_SMALL_SHY_GLOW_SCALE, 1.0, sizeT);
      
      // Add occasional nervous flicker
      float nervousFlicker = 1.0 + 0.2 * sin(t * 0.7 + g.id * 0.5);
      glowIntensity *= nervousFlicker;
      
      // Three-color glow: brighter mid color accent for halo effect
      color glowRgb;
      if (glowT < 0.5) {
        glowRgb = lerpColor(JELLY_SHY_GLOW_START, JELLY_SHY_GLOW_MID, glowT * 2.0);
      } else {
        glowRgb = lerpColor(JELLY_SHY_GLOW_MID, JELLY_SHY_GLOW_END, (glowT - 0.5) * 2.0);
      }
      glowColor = color(red(glowRgb), green(glowRgb), blue(glowRgb), min(255, baseAlpha * glowIntensity));
    } else if (isTeal) {
      float glowT = 0.5 + 0.5 * sin(t * JELLY_GLOW_SHIFT_SPEED + g.id * 0.7);
      color glowRgb;
      if (glowT < 0.5) {
        glowRgb = lerpColor(JELLY_AGGRO_GLOW_START, JELLY_AGGRO_GLOW_MID, glowT * 2.0);
      } else {
        glowRgb = lerpColor(JELLY_AGGRO_GLOW_MID, JELLY_AGGRO_GLOW_END, (glowT - 0.5) * 2.0);
      }
      glowColor = color(red(glowRgb), green(glowRgb), blue(glowRgb), min(255, baseAlpha * glowMult));
    } else {
      glowColor = color(red(baseColor), green(baseColor), blue(baseColor), min(255, baseAlpha * glowMult));
    }

    // Subtle head-to-tail gradient for all jellyfish; shy uses its palette.
    color headRgb = isShy
      ? lerpColor(JELLY_SHY, JELLY_SHY_GLOW_START, 0.35)
      : lerpColor(baseColor, color(255), JELLY_HEAD_LIGHTEN);
    color tailRgb = isShy
      ? lerpColor(JELLY_SHY, JELLY_SHY_CORE_DARK, 0.45)
      : lerpColor(baseColor, color(0), JELLY_TAIL_DARKEN);

    topColor = color(red(headRgb), green(headRgb), blue(headRgb), min(255, baseAlpha * 1.1));
    tailColor = color(red(tailRgb), green(tailRgb), blue(tailRgb),
                      min(255, baseAlpha * coreAlphaMult));

    effectiveCount = POINT_COUNT;
    glowLayers = 5;
    if (baseAlpha < 80) {
      effectiveCount = 1500;
      glowLayers = 3;
    } else if (baseAlpha < 140) {
      effectiveCount = 2500;
      glowLayers = 4;
    }
    glowLayers = int(lerp(2, glowLayers, sizeT));
    glowLayers = min(glowLayers, 3);

    // Recentering: compute local centroid so deformation stays centered on physics
    float centerX = 0;
    float centerY = 0;
    float targetDx = 0;
    float targetDy = 0;
    float sumLocalX = 0;
    float sumLocalY = 0;
    float sumWorldX = 0;
    float sumWorldY = 0;
    int localCount = 0;

    int variant = g.id % 4;
    if (variant < 0) variant += 4;
    float[] baseQv = baseQ[variant];
    float[] baseQScaleV = baseQScale[variant];
    float[] baseQPhaseV = baseQPhase[variant];
    float[] basePyV = basePy[variant];
    float[] baseVV = baseV[variant];
    float baseTimeScale = (variant == 0) ? 2.0
                        : (variant == 1) ? 1.5
                        : (variant == 2) ? 2.5
                        : 3.0;
    float denom = max(1, g.segmentos.size() - 1);

    for (int idx = 0; idx < effectiveCount; idx++) {
      float q = baseQv[idx] + baseQScaleV[idx] * sin(baseQPhaseV[idx] - t * baseTimeScale);
      float pyBase = basePyV[idx];
      float verticalProgression = baseVV[idx];

      float dragOffset = verticalProgression * 1.5;
      float phaseOffset = g.noiseOffset * 0.001 + g.id * 0.13;
      float phase = wrap01(g.pulsePhase + phaseOffset - dragOffset * 0.08);
      float contraction = g.pulseShape(phase); // 0 = relaxed, 1 = contracted
      float contractCurve = g.pulseContractCurve(phase); // thrust-weighted contraction
      float c = max(0.0001, g.contractPortion);
      float h = max(0.0, g.holdPortion);
      float r = max(0.0001, 1.0 - c - h);
      float p = wrap01(phase);
      float release = (p > c + h) ? (p - c - h) / r : 0.0;
      float rebound = 0.0;
      if (release > 0.0) {
        float bounce = sin(PI * min(release * 1.25, 1.0));
        rebound = bounce * (1.0 - release);
      }
      
      // Radial contract + elastic rebound tied to thrust
      float topCurve = 1.0 - verticalProgression * 0.5; // top responds a bit more
      float rimCurve = 0.4 + verticalProgression * 0.6; // rim drives the push
      float radialContract = lerp(1.0, 0.72, contraction * rimCurve);
      float radialRebound = rebound * 0.14 * rimCurve;
      float baseBreath = lerp(1.3, 0.7, contraction);
      float localBreath = baseBreath * (radialContract + radialRebound);

      // Vertical compression during contraction + slight rebound
      float verticalSqueeze = lerp(1.0, 0.92, contraction * topCurve);
      verticalSqueeze += rebound * 0.04 * topCurve;

      // Thrust-linked snap up, elastic settle down
      float localPulse = (contractCurve * 8.0 - rebound * 5.0) * (0.5 + 0.5 * topCurve);

      float px = q * localBreath;
      float py = pyBase * verticalSqueeze;

      int segmentIndex = int(verticalProgression * (g.segmentos.size() - 1));
      Segmento seg = g.segmentos.get(segmentIndex);
      float segmentProgression = (verticalProgression * (g.segmentos.size() - 1)) - segmentIndex;
      float x, y;

      if (segmentIndex < g.segmentos.size() - 1) {
        Segmento nextSeg = g.segmentos.get(segmentIndex + 1);
        x = lerp(seg.x, nextSeg.x, segmentProgression);
        y = lerp(seg.y, nextSeg.y, segmentProgression);
      } else {
        x = seg.x;
        y = seg.y;
      }

      float pulseOffset = localPulse * (0.5 - verticalProgression);
      float pyLocal = py + pulseOffset;
      float pxWorld = px + x;
      float pyWorld = pyLocal + y;
      sumLocalX += px;
      sumLocalY += pyLocal;
      sumWorldX += pxWorld;
      sumWorldY += pyWorld;
      localCount++;

      vx[idx] = pxWorld;
      vy[idx] = pyWorld;
      float segGrad = segmentIndex / denom;
      tGrad[idx] = pow(segGrad, 1.1);
    }
    if (localCount > 0) {
      centerX = sumLocalX / localCount;
      centerY = sumLocalY / localCount;
      float worldCenterX = (sumWorldX / localCount) - centerX;
      float worldCenterY = (sumWorldY / localCount) - centerY;
      targetDx = g.segmentos.get(0).x - worldCenterX;
      targetDy = g.segmentos.get(0).y - worldCenterY;
    }
    float alignBlend = 0.6;
    float alignLerp = 0.18;
    alignDx = lerp(alignDx, targetDx, alignLerp);
    alignDy = lerp(alignDy, targetDy, alignLerp);
    float finalAlignDx = alignDx * alignBlend;
    float finalAlignDy = alignDy * alignBlend;

    frameOffsetX = -centerX + finalAlignDx;
    frameOffsetY = -centerY + finalAlignDy;

    hasDebugCenter = debugJellyMotion && localCount > 0;
    if (hasDebugCenter) {
      float avgWorldX = sumWorldX / localCount;
      float avgWorldY = sumWorldY / localCount;
      debugCenterX = avgWorldX + frameOffsetX;
      debugCenterY = avgWorldY + frameOffsetY;
    }
  }

  void drawGlowPass() {
    drawLayeredGlow(glowColor, isShy, vx, vy, effectiveCount, glowLayers);
  }

  void drawCorePass() {
    strokeWeight(1);
    for (int i = 0; i < effectiveCount; i++) {
      float gradT = tGrad[i];
      color grad = lerpColor(topColor, tailColor, gradT);
      float alphaFalloff = lerp(1.0, JELLY_TAIL_ALPHA_FALLOFF, gradT);
      stroke(red(grad), green(grad), blue(grad), alpha(grad) * alphaFalloff);
      point(vx[i] + frameOffsetX, vy[i] + frameOffsetY);
    }

    if (debugJellyMotion && hasDebugCenter) {
      pushStyle();
      stroke(255, 60, 60, 200);
      strokeWeight(6);
      point(debugCenterX, debugCenterY);
      stroke(0, 180, 80, 180);
      strokeWeight(4);
      point(g.segmentos.get(0).x, g.segmentos.get(0).y);
      stroke(0, 120, 200, 140);
      line(g.segmentos.get(0).x, g.segmentos.get(0).y, debugCenterX, debugCenterY);
      popStyle();
    }

    if (showHead) {
      stroke(0, 200);
      strokeWeight(4);
      point(g.segmentos.get(0).x, g.segmentos.get(0).y);
      strokeWeight(1);
    }
  }

  boolean isCloseColor(color a, color b, float thr) {
    float dr = red(a) - red(b);
    float dg = green(a) - green(b);
    float db = blue(a) - blue(b);
    return (dr * dr + dg * dg + db * db) <= (thr * thr);
  }

  // Draw multi-layered glow for realistic bioluminescence
  void drawLayeredGlow(color glow, boolean isShy, float[] vx, float[] vy, int count, int layers) {
    pushStyle();
    // Get base pulse intensity for animations
    float deepPulse = 0.5 + 0.5 * sin(t * 0.25 + g.id * 1.3);
    float pulseIntensity = 0.7 + deepPulse * 0.3; // 0.7 to 1.0 range
    
    // Very low overall alpha multiplier for subtle blending
    float alphaScale = 0.4;
    
    int stepInner = 2;
    int stepOuter = 3;

    // Layer 1: Tight inner core - original glow color
    float r1 = red(glow);
    float g1 = green(glow);
    float b1 = blue(glow);
    float a1 = alpha(glow) * pulseIntensity * 0.25 * alphaScale;
    
    stroke(r1, g1, b1, a1);
    strokeWeight(isShy ? 0.8 : 0.6);
    strokeCap(ROUND);
    strokeJoin(ROUND);
    noFill();
    drawPointsStep(vx, vy, count, stepInner);
    
    if (layers > 1) {
      // Layer 2: Light transition - 30% towards white
      float r2 = lerp(r1, 255, 0.25);
      float g2 = lerp(g1, 255, 0.25);
      float b2 = lerp(b1, 255, 0.25);
      float a2 = alpha(glow) * pulseIntensity * 0.15 * alphaScale;
      
      stroke(r2, g2, b2, a2);
      strokeWeight(isShy ? 3.0 : 2.5);
      drawPointsStep(vx, vy, count, stepOuter);
    }
    
    if (layers > 2) {
      // Layer 3: Medium transition - 50% towards white
      float r3 = lerp(r1, 255, 0.50);
      float g3 = lerp(g1, 255, 0.50);
      float b3 = lerp(b1, 255, 0.50);
      float a3 = alpha(glow) * pulseIntensity * 0.10 * alphaScale;
      
      stroke(r3, g3, b3, a3);
      strokeWeight(isShy ? 6.5 : 5.5);
      drawPointsStep(vx, vy, count, stepOuter);
    }
    
    if (layers > 3) {
      // Layer 4: Light halo - 75% towards white
      float r4 = lerp(r1, 255, 0.75);
      float g4 = lerp(g1, 255, 0.75);
      float b4 = lerp(b1, 255, 0.75);
      float a4 = alpha(glow) * pulseIntensity * 0.05 * alphaScale;
      
      stroke(r4, g4, b4, a4);
      strokeWeight(isShy ? 12.0 : 10.0);
      drawPointsStep(vx, vy, count, stepOuter);
    }
    
    if (layers > 4) {
      // Layer 5: Very subtle outer glow - almost white
      float r5 = lerp(r1, 255, 0.90);
      float g5 = lerp(g1, 255, 0.90);
      float b5 = lerp(b1, 255, 0.90);
      float a5 = alpha(glow) * pulseIntensity * 0.02 * alphaScale;
      
      stroke(r5, g5, b5, a5);
      strokeWeight(isShy ? 18.0 : 15.0);
      drawPointsStep(vx, vy, count, stepOuter);
    }
    
    popStyle();
  }
  
  void drawPointsStep(float[] vx, float[] vy, int count, int step) {
    beginShape(POINTS);
    int stride = max(1, step);
    for (int i = 0; i < count; i += stride) {
      vertex(vx[i] + frameOffsetX, vy[i] + frameOffsetY);
    }
    endShape();
  }
}
