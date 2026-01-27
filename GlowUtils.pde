// Layered additive bioluminescent glow utilities

// --- Bioluminescent palette (configurable) ---
float JELLY_ALPHA = 120;
color JELLY_CALM = color(5, 242, 219);
color JELLY_SHY = color(233, 173, 157); // #E9AD9D
color JELLY_AGGRO = color(5, 242, 219);
color JELLY_GLOW_START = color(5, 242, 175); // #05F2AF
color JELLY_GLOW_END = color(0, 138, 89); // #008A59
// Dominant/teal glow variety (start closer to white)
color JELLY_AGGRO_GLOW_START = color(255, 255, 255); // #FFFFFF
color JELLY_AGGRO_GLOW_MID = color(5, 242, 175); // #05F2AF
color JELLY_AGGRO_GLOW_END = color(0, 138, 89); // #008A59
color JELLY_SHY_GLOW_START = color(253, 242, 226); // #FDF2E2 (center)
color JELLY_SHY_GLOW_MID = color(247, 188, 151); // #F7BC97 (halo accent)
color JELLY_SHY_GLOW_END = color(227, 192, 155); // #E3C09B (outer)
color JELLY_SHY_CORE_DARK = color(244, 175, 132); // #F4AF84 (core)
float JELLY_GLOW_SHIFT_SPEED = 0.25; // slower, calmer pulse
float JELLY_GLOW_MATCH_THR = 30;

final float BASE_GLOW_MULT = 2.4;
final float SMALL_GLOW_MULT = 1.7;
final float LAYER_ALPHA_SCALE = 0.4;
final float[] LERP_TO_WHITE = {0.0, 0.25, 0.5, 0.75, 0.90};
final float[] LAYER_ALPHAS = {0.25, 0.15, 0.10, 0.05, 0.02};
final float[] STROKE_WEIGHTS = {1, 3, 6, 10, 15};

// Offscreen buffer for cheap blur (lower resolution)
PGraphics glowBuf = null;
float GLOW_BUF_SCALE = 0.45; // 0.33..0.6 - tradeoff between blur and quality
float MIN_FPS_FOR_FULL_DETAIL = 30.0;

class GlowInfo {
  color base;     // glow base color
  color coreTop;  // core top color for head->tail gradient
  color coreTail; // core tail color
  float intensity;
  float shiftT;
  GlowInfo(color b, color top, color tail, float i, float s) { base = b; coreTop = top; coreTail = tail; intensity = i; shiftT = s; }
}

// Utility: compare two colors by Euclidean distance in RGB
boolean isCloseColor(color a, color b, float thr) {
  float dr = red(a) - red(b);
  float dg = green(a) - green(b);
  float db = blue(a) - blue(b);
  float d2 = dr*dr + dg*dg + db*db;
  return d2 <= thr*thr;
}

GlowInfo computeGlow(Gusano g, float time) {
  color baseCol = g.currentColor;
  float idf = g.id * 0.37;
  float phaseOffset = g.id * 0.13;

  float glowT = 0.5 + 0.5 * sin(time * JELLY_GLOW_SHIFT_SPEED + idf);
  float deepPulse = 0.5 + 0.5 * sin(time * 0.18 + phaseOffset);
  float pulseSync = g.pulseContractCurve(g.pulsePhase + (g.id * 0.027));
  float flick = (noise(g.noiseOffset + time * 3.2) - 0.5) * 0.06;

  float baseMult = BASE_GLOW_MULT;
  float intensity = baseMult + deepPulse * SMALL_GLOW_MULT + pulseSync * (SMALL_GLOW_MULT * 0.9) + flick;
  intensity *= lerp(0.8, 1.4, glowT);

  // Determine mood by color-matching against configured palettes
  color gStart = JELLY_GLOW_START;
  color gMid = lerpColor(JELLY_GLOW_START, JELLY_GLOW_END, 0.5);
  color gEnd = JELLY_GLOW_END;
  color coreTop = baseCol;
  color coreTail = lerpColor(baseCol, color(0,0,0), 0.35);

  if (isCloseColor(baseCol, JELLY_SHY, JELLY_GLOW_MATCH_THR)) {
    gStart = JELLY_SHY_GLOW_START;
    gMid = JELLY_SHY_GLOW_MID;
    gEnd = JELLY_SHY_GLOW_END;
    coreTop = JELLY_SHY_CORE_DARK;
    coreTail = lerpColor(coreTop, color(0,0,0), 0.45);
  } else if (isCloseColor(baseCol, JELLY_AGGRO, JELLY_GLOW_MATCH_THR)) {
    gStart = JELLY_AGGRO_GLOW_START;
    gMid = JELLY_AGGRO_GLOW_MID;
    gEnd = JELLY_AGGRO_GLOW_END;
    coreTop = baseCol; // keep bright top for aggressive
    coreTail = lerpColor(coreTop, color(0,0,0), 0.25);
  } else if (isCloseColor(baseCol, JELLY_CALM, JELLY_GLOW_MATCH_THR)) {
    // calm uses default glow start/end
    gStart = JELLY_GLOW_START;
    gMid = lerpColor(JELLY_GLOW_START, JELLY_GLOW_END, 0.5);
    gEnd = JELLY_GLOW_END;
    coreTop = baseCol;
    coreTail = lerpColor(coreTop, color(0,0,0), 0.35);
  }

  // Build a representative base glow color from the 3-color gradient.
  // Use glowT to bias toward center/mid.
  color blendA = lerpColor(gStart, gMid, 0.5 + 0.5 * (glowT-0.5));
  color blendB = lerpColor(gMid, gEnd, 0.5 - 0.5 * (glowT-0.5));
  color glowBase = lerpColor(blendA, blendB, 0.5);

  return new GlowInfo(glowBase, coreTop, coreTail, max(0, intensity), glowT);
}

// pts: sample points in world coordinates outlining the entity
void drawGlow(Gusano g, ArrayList<PVector> pts, float time) {
  if (pts == null || pts.size() == 0) return;
  GlowInfo gi = computeGlow(g, time);

  // adaptive detail based on framerate
  float fps = (frameRate > 0) ? frameRate : 60;
  int layers = constrain(int(map(g.sizeFactor, 0.85, 1.15, 3, 5)), 3, 5);
  int effectiveLayers = layers;
  int strideBase = 1;
  if (fps < MIN_FPS_FOR_FULL_DETAIL) {
    effectiveLayers = max(2, layers - 1);
    strideBase = 2; // sample fewer points when slow
  }

  // Prepare low-res buffer
  int bw = max(2, int(width * GLOW_BUF_SCALE));
  int bh = max(2, int(height * GLOW_BUF_SCALE));
  if (glowBuf == null || glowBuf.width != bw || glowBuf.height != bh) {
    glowBuf = createGraphics(bw, bh, P2D);
    glowBuf.smooth(4);
  }

  // Draw glow into buffer (coordinates scaled)
  glowBuf.beginDraw();
  glowBuf.clear();
  glowBuf.blendMode(ADD);
  glowBuf.pushStyle();

  for (int li = 0; li < effectiveLayers; li++) {
    float lerpW = LERP_TO_WHITE[min(li, LERP_TO_WHITE.length-1)];
    color layerCol = lerpColor(gi.base, color(255,255,255), lerpW);
    float relAlpha = LAYER_ALPHAS[min(li, LAYER_ALPHAS.length-1)];
    float alphaFrac = gi.intensity * relAlpha * LAYER_ALPHA_SCALE;
    float alpha255 = constrain(alphaFrac * 255.0, 0, 255);

    // Scale stroke weight down for buffer resolution
    float strokeW = STROKE_WEIGHTS[min(li, STROKE_WEIGHTS.length-1)] * (1.0 + (g.sizeFactor - 1.0) * 1.3) * GLOW_BUF_SCALE;
    glowBuf.stroke(layerCol, alpha255);
    glowBuf.strokeWeight(max(1, strokeW));
    glowBuf.noFill();

    int stride = strideBase + li; // sparser outer layers
    float jitterAmp = (li + 1) * 0.6 * (gi.shiftT * 0.6 + 0.4);

    for (int pi = 0; pi < pts.size(); pi += stride) {
      PVector p = pts.get(pi);
      // cheaper deterministic jitter using sin() instead of per-point noise()
      float jitterKey = (p.x * 0.12 + p.y * 0.07 + li * 1.3 + g.noiseOffset + time * 0.8);
      float jx = (sin(jitterKey) * 0.5) * jitterAmp;
      float jy = (sin(jitterKey * 1.37 + 2.0) * 0.5) * jitterAmp;
      // scale to buffer coords
      float bx = (p.x) * (glowBuf.width / float(width));
      float by = (p.y) * (glowBuf.height / float(height));
      glowBuf.point(bx + jx, by + jy);
    }
  }

  glowBuf.popStyle();
  glowBuf.endDraw();

  // Composite buffer back to screen with small multi-sample blit passes to emulate blur
  pushStyle();
  blendMode(ADD);
  noTint();
  // draw centered, with slight offsets + varying alpha to soften
  float baseAlpha = 255.0;
  tint(255, baseAlpha * 0.9);
  image(glowBuf, 0, 0, width, height);
  tint(255, baseAlpha * 0.35);
  image(glowBuf, -1, -1, width, height);
  image(glowBuf, 1, 1, width, height);
  tint(255, baseAlpha * 0.12);
  image(glowBuf, -2, 0, width, height);
  image(glowBuf, 2, 0, width, height);
  popStyle();
}

void drawCore(Gusano g, ArrayList<PVector> pts, float time) {
  if (pts == null || pts.size() == 0) return;
  pushStyle();
  noStroke();

  // Prefer core gradient from computeGlow classification when available
  GlowInfo gi = computeGlow(g, time);
  color topColor = gi.coreTop;
  color tailColor = gi.coreTail;

  for (int i = 0; i < pts.size(); i++) {
    PVector p = pts.get(i);
    float t01 = i / float(max(1, pts.size()-1));
    float alpha = lerp(1.0, 0.1, t01);
    color c = lerpColor(topColor, tailColor, t01);
    fill(c, alpha * 255 * 0.95);
    float sz = lerp(2.4, 0.8, t01) * (1.0 + (g.sizeFactor - 1.0) * 0.9);
    ellipse(p.x, p.y, sz, sz);
  }

  popStyle();
}
