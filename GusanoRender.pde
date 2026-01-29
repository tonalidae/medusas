// Global cache for jelly shapes (Processing treats classes as inner to PApplet, so keep this top-level)
class ShapeCache {
  float[] k;
  float[] d;
  float[] py;
  float[] vertProg;
  float[] qConst;
  float[] qScale;
  float[] sinBase;
}
final int POINT_COUNT = 5000;
ShapeCache[] gusanoShapeCaches = new ShapeCache[4];

class GusanoRender {
  Gusano g;
  float alignDx = 0;
  float alignDy = 0;

  GusanoRender(Gusano g) {
    this.g = g;
  }

  // Lazy init: build cache for the current variant once.
  ShapeCache cacheForVariant(int variant) {
    variant = ((variant % 4) + 4) % 4; // safe modulo
    if (gusanoShapeCaches[variant] != null) return gusanoShapeCaches[variant];

    ShapeCache c = new ShapeCache();
    c.k = new float[POINT_COUNT];
    c.d = new float[POINT_COUNT];
    c.py = new float[POINT_COUNT];
    c.vertProg = new float[POINT_COUNT];
    c.qConst = new float[POINT_COUNT];
    c.qScale = new float[POINT_COUNT];
    c.sinBase = new float[POINT_COUNT];

    float minPY = 100;
    float maxPY = 400;

    for (int i = 0; i < POINT_COUNT; i++) {
      float x_param = i % 200;
      float y_param = i / 35.0;

      float k, e, d, py, qConst, qScale, sinBase;
      switch (variant) {
        case 0:
          k = 5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 13;
          d = sq(mag(k, e)) / 59 + 4;
          py = d * 45;
          qConst = -3 * sin(atan2(k, e) * e) + k * 3;
          qScale = k * (4 / d); // multiply by sin(d*d - t*2) each frame
          sinBase = d * d;
          break;
        case 1:
          k = 6 * cos((x_param * 1.1) / 12) * cos((y_param * 0.9) / 25);
          e = (y_param * 0.9) / 7 - 15;
          d = sq(mag(k, e)) / 50 + 3;
          py = d * 40;
          qConst = -2 * sin(atan2(k, e) * e) + k * 2;
          qScale = k * (5 / d); // sin(d*d - t*1.5)
          sinBase = d * d;
          break;
        case 2:
          k = 4 * cos((x_param * 0.9) / 16) * cos((y_param * 1.1) / 35);
          e = (y_param * 1.1) / 9 - 11;
          d = sq(mag(k, e)) / 65 + 5;
          py = d * 50;
          qConst = -4 * sin(atan2(k, e) * e) + k * 4;
          qScale = k * (3 / d); // sin(d*d - t*2.5)
          sinBase = d * d;
          break;
        case 3:
          k = 7 * cos((x_param * 1.2) / 10) * cos((y_param * 0.8) / 20);
          e = (y_param * 0.8) / 6 - 17;
          d = sq(mag(k, e)) / 45 + 2;
          py = d * 35;
          qConst = -5 * sin(atan2(k, e) * e) + k * 5;
          qScale = k * (6 / d); // sin(d*d - t*3)
          sinBase = d * d;
          break;
        default:
          k = 5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 13;
          d = sq(mag(k, e)) / 59 + 4;
          py = d * 45;
          qConst = -3 * sin(atan2(k, e) * e) + k * 3;
          qScale = k * (4 / d);
          sinBase = d * d;
          break;
      }

      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);

      c.k[i] = k;
      c.d[i] = d;
      c.py[i] = py;
      c.vertProg[i] = verticalProgression;
      c.qConst[i] = qConst;
      c.qScale[i] = qScale;
      c.sinBase[i] = sinBase;
    }

    gusanoShapeCaches[variant] = c;
    return c;
  }

  void dibujarForma() {
    float rimWeight = 1.2;
    color rimColor = g.currentColor;
    switch(g.state) {
      case Gusano.FEAR:
        rimWeight = 1.6 + sin(t * 8.0 + g.id) * 0.5;
        rimColor = lerpColor(rimColor, color(255, 120, 40, 180), 0.5);
        break;
      case Gusano.CALM:
        rimWeight = 1.1;
        rimColor = lerpColor(rimColor, color(180, 220, 255, 140), 0.3);
        break;
      case Gusano.AGGRESSIVE:
        rimWeight = 1.5;
        rimColor = lerpColor(rimColor, color(255, 60, 160, 170), 0.4);
        break;
      case Gusano.CURIOUS:
        rimWeight = 1.3;
        break;
      case Gusano.SHY:
        rimWeight = 1.0;
        rimColor = lerpColor(rimColor, color(200, 180, 240, 120), 0.25);
        break;
    }
    stroke(rimColor);
    strokeWeight(rimWeight);
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

    ShapeCache cache = cacheForVariant(g.id % 4);
    float timeFreq;
    switch (g.id % 4) {
      case 0: timeFreq = 2.0; break;
      case 1: timeFreq = 1.5; break;
      case 2: timeFreq = 2.5; break;
      case 3: timeFreq = 3.0; break;
      default: timeFreq = 2.0; break;
    }

    for (int idx = 0; idx < POINT_COUNT; idx++) {
      float k = cache.k[idx];
      float d = cache.d[idx];
      float pyVal = cache.py[idx];
      float verticalProgression = cache.vertProg[idx];
      float q = cache.qConst[idx] + cache.qScale[idx] * sin(cache.sinBase[idx] - t * timeFreq);

      float dragOffset = verticalProgression * 1.5;
      float phaseOffset = g.noiseOffset * 0.001 + g.id * 0.13;
      float phase = wrap01(g.pulsePhase + phaseOffset - dragOffset * 0.08);
      float contraction = g.pulseShape(phase); // 0 = relaxed, 1 = contracted
      float contractCurve = g.pulseContractCurve(phase); // thrust-weighted contraction
      float cPortion = max(0.0001, g.contractPortion);
      float h = max(0.0, g.holdPortion);
      float r = max(0.0001, 1.0 - cPortion - h);
      float p = wrap01(phase);
      float release = (p > cPortion + h) ? (p - cPortion - h) / r : 0.0;
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
      float py = pyVal * verticalSqueeze;

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
      sumLocalX += px;
      sumLocalY += py + pulseOffset;
      sumWorldX += px + x;
      sumWorldY += py + pulseOffset + y;
      localCount++;
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

    sumWorldX = 0;
    sumWorldY = 0;
    int worldCount = 0;
    beginShape(POINTS);
    for (int idx = 0; idx < POINT_COUNT; idx++) {
      float k = cache.k[idx];
      float d = cache.d[idx];
      float pyVal = cache.py[idx];
      float verticalProgression = cache.vertProg[idx];
      float q = cache.qConst[idx] + cache.qScale[idx] * sin(cache.sinBase[idx] - t * timeFreq);

      float dragOffset = verticalProgression * 1.5;
      float phaseOffset = g.noiseOffset * 0.001 + g.id * 0.13;
      float phase = wrap01(g.pulsePhase + phaseOffset - dragOffset * 0.08);
      float contraction = g.pulseShape(phase); // 0 = relaxed, 1 = contracted
      float contractCurve = g.pulseContractCurve(phase); // thrust-weighted contraction
      float cPortion = max(0.0001, g.contractPortion);
      float h = max(0.0, g.holdPortion);
      float r = max(0.0001, 1.0 - cPortion - h);
      float p = wrap01(phase);
      float release = (p > cPortion + h) ? (p - cPortion - h) / r : 0.0;
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
      float py = pyVal * verticalSqueeze;

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
      float vx = px - centerX + x + finalAlignDx;
      float vy = py + pulseOffset - centerY + y + finalAlignDy;
      vertex(vx, vy);
      sumWorldX += vx;
      sumWorldY += vy;
      worldCount++;
    }
    endShape();

    if (debugJellyMotion && worldCount > 0) {
      float cx = sumWorldX / worldCount;
      float cy = sumWorldY / worldCount;
      pushStyle();
      stroke(255, 60, 60, 200);
      strokeWeight(6);
      point(cx, cy);
      stroke(0, 180, 80, 180);
      strokeWeight(4);
      point(g.segmentos.get(0).x, g.segmentos.get(0).y);
      stroke(0, 120, 200, 140);
      line(g.segmentos.get(0).x, g.segmentos.get(0).y, cx, cy);
      popStyle();
    }

    if (showHead) {
      stroke(0, 200);
      strokeWeight(4);
      point(g.segmentos.get(0).x, g.segmentos.get(0).y);
      strokeWeight(1);
    }
  }
}
