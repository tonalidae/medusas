// GusanoBiolight.pde
// Deep-ocean bioluminescence rendering system
// Computes per-point emission and renders multiple bloom/glint passes
// for realistic underwater light diffusion effects

class GusanoBiolight {
  Gusano g;
  
  // Cached alignment values (mirrors GusanoRender)
  float alignDx = 0;
  float alignDy = 0;
  
  // Bloom layer configuration (outer → inner)
  int bloomLayers = 4;
  float[] bloomRadius = {22.0, 12.0, 5.0, 2.0};
  float[] bloomAlpha = {0.018, 0.04, 0.09, 0.18};
  float[] bloomWhiteMix = {0.55, 0.35, 0.15, 0.0};
  
  // Biological pulse parameters
  float heartbeatHz = 0.22;
  float heartbeatBoost = 0.25;
  float pulseBoost = 0.6;
  float rimPower = 2.2;
  float rimBoost = 1.4;
  
  // Glint (specular sparkle) parameters
  float glintHz = 1.3;
  float glintStrength = 2.5;
  float glintRadius = 2.0;
  
  // Band emission (creates horizontal glow bands along body)
  float[] bandCenters = {0.25, 0.55, 0.8};
  float bandSigma = 0.08;
  float bandStrength = 0.4;
  
  // Motion trailing
  float streakStrength = 0.6;
  
  // Photophore data (sparse glow points)
  float[] photophoreU;      // Position along body (0..1)
  int photophoreCount = 0;
  int maxPhotophores = 12;
  
  // Cached colors
  color baseGlowColor;
  color haloGlowColor;
  float glowIntensity = 1.0;
  float heartbeatPhase;
  
  GusanoBiolight(Gusano g) {
    this.g = g;
    this.heartbeatPhase = g.noiseOffset * TWO_PI;
    initPhotophores();
    initColors();
  }
  
  void initPhotophores() {
    // Generate sparse photophore positions (2-6% of body length)
    photophoreU = new float[maxPhotophores];
    photophoreCount = 0;
    for (int i = 0; i < maxPhotophores; i++) {
      if (random(1) < BIOLIGHT_GLINT_DENSITY) {
        photophoreU[photophoreCount++] = random(0.15, 0.85);
      }
    }
  }
  
  void initColors() {
    // Base color from mood palette
    baseGlowColor = g.mood.paletteForState(g.baseMood, 1.0);
    // Halo is whiter/greener version for water scattering effect
    haloGlowColor = lerpColor(baseGlowColor, color(180, 230, 220, 80), 0.4);
  }
  
  // ============================================================
  // SIGNAL COMPUTATION (biological control signals)
  // ============================================================
  
  // Slow heartbeat signal (0..1) - desync between individuals
  float computeHeartbeat() {
    return 0.5 + 0.5 * sin(t * TWO_PI * heartbeatHz + heartbeatPhase);
  }
  
  // Contraction-synced pulse (0..1, peaks during thrust)
  float computePulseSync() {
    float contraction = g.pulseContractCurve(g.pulsePhase);
    return pow(contraction, 1.5);
  }
  
  // Rim factor: how close to edge (0=center, 1=rim)
  float computeRim(float xLocal, float rimRadius) {
    return pow(constrain(abs(xLocal) / max(1, rimRadius), 0, 1), rimPower);
  }
  
  // Band emission: creates glowing horizontal bands
  float computeBand(float u) {
    float band = 0;
    for (int i = 0; i < bandCenters.length; i++) {
      float dist = u - bandCenters[i];
      band += exp(-(dist * dist) / (2 * bandSigma * bandSigma));
    }
    return band;
  }
  
  // Check if point is near a photophore
  float computePhotophore(float u) {
    for (int i = 0; i < photophoreCount; i++) {
      float dist = abs(u - photophoreU[i]);
      if (dist < 0.04) {
        return 1.0 - (dist / 0.04); // Falloff
      }
    }
    return 0;
  }
  
  // ============================================================
  // MAIN EMISSION COMPUTATION
  // ============================================================
  
  // Compute final emission strength for a single point
  float computeEmission(float u, float xLocal, float rimRadius) {
    float heartbeat = computeHeartbeat();
    float pulseSync = computePulseSync();
    float rim = computeRim(xLocal, rimRadius);
    float band = computeBand(u);
    float photophore = computePhotophore(u);
    
    // Spatial distribution: stronger at rim and in bands
    float interiorLevel = 0.3;
    float rimLevel = 1.0;
    float emissionSpatial = lerp(interiorLevel, rimLevel, rim);
    emissionSpatial *= (1.0 + bandStrength * band);
    emissionSpatial *= (1.0 + 1.2 * photophore); // Photophores boost
    
    // Temporal modulation
    float emit = glowIntensity * BIOLIGHT_GLOBAL_INTENSITY;
    emit *= lerp(1.0, 1.0 + heartbeatBoost, heartbeat);
    emit *= (1.0 + pulseBoost * pulseSync);
    emit *= emissionSpatial;
    
    // Size scaling: smaller creatures glow tighter
    emit *= lerp(0.7, 1.0, g.sizeFactor);
    
    // Mood-based modulation
    switch(g.state) {
      case Gusano.FEAR:
        emit *= 1.4; // Brighter when scared
        break;
      case Gusano.AGGRESSIVE:
        emit *= 1.2 + 0.3 * sin(t * 4.0 + g.id);
        break;
      case Gusano.SHY:
        emit *= 0.7; // Dimmer when shy
        break;
      case Gusano.CURIOUS:
        emit *= 1.1;
        break;
    }
    
    return emit;
  }
  
  // ============================================================
  // POINT POSITION COMPUTATION
  // Replicates GusanoRender logic for consistency
  // ============================================================
  
  // Container for point data
  class PointData {
    float worldX, worldY;
    float u;           // Vertical progression (0..1)
    float xLocal;      // Local X offset from centerline
    float rimRadius;   // Maximum radius at this height
    boolean valid = true;
    
    PointData() {}
  }
  
  PointData computePointPosition(int i, float centerX, float centerY, float alignDx, float alignDy) {
    PointData pd = new PointData();
    
    float x_param = i % 200;
    float y_param = i / 35.0;
    
    float k, e, d, q, px, py;
    
    switch(g.id % 4) {
      case 0:
        k = 5 * cos(x_param / 14) * cos(y_param / 30);
        e = y_param / 8 - 13;
        d = sq(mag(k, e)) / 59 + 4;
        q = -3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
        py = d * 45;
        break;
      case 1:
        k = 6 * cos((x_param * 1.1) / 12) * cos((y_param * 0.9) / 25);
        e = (y_param * 0.9) / 7 - 15;
        d = sq(mag(k, e)) / 50 + 3;
        q = -2 * sin(atan2(k, e) * e) + k * (2 + 5 / d * sin(d * d - t * 1.5));
        py = d * 40;
        break;
      case 2:
        k = 4 * cos((x_param * 0.9) / 16) * cos((y_param * 1.1) / 35);
        e = (y_param * 1.1) / 9 - 11;
        d = sq(mag(k, e)) / 65 + 5;
        q = -4 * sin(atan2(k, e) * e) + k * (4 + 3 / d * sin(d * d - t * 2.5));
        py = d * 50;
        break;
      case 3:
        k = 7 * cos((x_param * 1.2) / 10) * cos((y_param * 0.8) / 20);
        e = (y_param * 0.8) / 6 - 17;
        d = sq(mag(k, e)) / 45 + 2;
        q = -5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
        py = d * 35;
        break;
      default:
        pd.valid = false;
        return pd;
    }
    
    float minPY = 100;
    float maxPY = 400;
    pd.u = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);
    
    // Pulse deformation
    float dragOffset = pd.u * 1.5;
    float phaseOffset = g.noiseOffset * 0.001 + g.id * 0.13;
    float phase = wrap01(g.pulsePhase + phaseOffset - dragOffset * 0.08);
    float contraction = g.pulseShape(phase);
    float contractCurve = g.pulseContractCurve(phase);
    
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
    
    float topCurve = 1.0 - pd.u * 0.5;
    float rimCurve = 0.4 + pd.u * 0.6;
    float radialContract = lerp(1.0, 0.72, contraction * rimCurve);
    float radialRebound = rebound * 0.14 * rimCurve;
    float baseBreath = lerp(1.3, 0.7, contraction);
    float localBreath = baseBreath * (radialContract + radialRebound);
    
    float verticalSqueeze = lerp(1.0, 0.92, contraction * topCurve);
    verticalSqueeze += rebound * 0.04 * topCurve;
    
    float localPulse = (contractCurve * 8.0 - rebound * 5.0) * (0.5 + 0.5 * topCurve);
    
    px = q * localBreath;
    py = py * verticalSqueeze;
    
    // Store local X before world transform for rim calculation
    pd.xLocal = q;
    pd.rimRadius = 35.0 * localBreath; // Approximate maximum radius
    
    // Get body segment position
    int segmentIndex = int(pd.u * (g.segmentos.size() - 1));
    segmentIndex = constrain(segmentIndex, 0, g.segmentos.size() - 1);
    Segmento seg = g.segmentos.get(segmentIndex);
    
    float segmentProgression = (pd.u * (g.segmentos.size() - 1)) - segmentIndex;
    float bodyX, bodyY;
    
    if (segmentIndex < g.segmentos.size() - 1) {
      Segmento nextSeg = g.segmentos.get(segmentIndex + 1);
      bodyX = lerp(seg.x, nextSeg.x, segmentProgression);
      bodyY = lerp(seg.y, nextSeg.y, segmentProgression);
    } else {
      bodyX = seg.x;
      bodyY = seg.y;
    }
    
    float pulseOffset = localPulse * (0.5 - pd.u);
    
    // Final world position with alignment
    pd.worldX = px - centerX + bodyX + alignDx;
    pd.worldY = py + pulseOffset - centerY + bodyY + alignDy;
    
    return pd;
  }
  
  // ============================================================
  // RENDER PASSES
  // ============================================================
  
  void render() {
    if (!useBioluminescence) return;
    
    pushStyle();
    blendMode(ADD); // Additive blending for glow
    noStroke();
    
    // Update colors based on current mood (smooth transition)
    color targetBaseColor = g.mood.paletteForState(g.state, g.moodHeat);
    baseGlowColor = lerpColor(baseGlowColor, targetBaseColor, 0.02);
    haloGlowColor = lerpColor(baseGlowColor, color(180, 230, 220, 80), 0.4);
    
    // Compute alignment (same as GusanoRender)
    float[] alignment = computeAlignment();
    float centerX = alignment[0];
    float centerY = alignment[1];
    float finalAlignDx = alignment[2];
    float finalAlignDy = alignment[3];
    
    // Pass A: Outer water scattering bloom (widest, faintest)
    renderBloomPass(centerX, centerY, finalAlignDx, finalAlignDy);
    
    // Pass B: Emissive body glow (tight, colored)
    renderEmissivePass(centerX, centerY, finalAlignDx, finalAlignDy);
    
    // Pass C: Rim light enhancement
    renderRimPass(centerX, centerY, finalAlignDx, finalAlignDy);
    
    // Pass D: Specular sparkle glints
    renderGlintPass(centerX, centerY, finalAlignDx, finalAlignDy);
    
    blendMode(BLEND);
    popStyle();
  }
  
  // Compute alignment similar to GusanoRender
  float[] computeAlignment() {
    float sumLocalX = 0, sumLocalY = 0;
    float sumWorldX = 0, sumWorldY = 0;
    int localCount = 0;
    
    // Sparse sampling for alignment calculation
    for (int i = 5000; i > 0; i -= 50) {
      float x_param = i % 200;
      float y_param = i / 35.0;
      
      float k, e, d, q, px, py;
      
      switch(g.id % 4) {
        case 0:
          k = 5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 13;
          d = sq(mag(k, e)) / 59 + 4;
          q = -3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
          py = d * 45;
          break;
        case 1:
          k = 6 * cos((x_param * 1.1) / 12) * cos((y_param * 0.9) / 25);
          e = (y_param * 0.9) / 7 - 15;
          d = sq(mag(k, e)) / 50 + 3;
          q = -2 * sin(atan2(k, e) * e) + k * (2 + 5 / d * sin(d * d - t * 1.5));
          py = d * 40;
          break;
        case 2:
          k = 4 * cos((x_param * 0.9) / 16) * cos((y_param * 1.1) / 35);
          e = (y_param * 1.1) / 9 - 11;
          d = sq(mag(k, e)) / 65 + 5;
          q = -4 * sin(atan2(k, e) * e) + k * (4 + 3 / d * sin(d * d - t * 2.5));
          py = d * 50;
          break;
        case 3:
          k = 7 * cos((x_param * 1.2) / 10) * cos((y_param * 0.8) / 20);
          e = (y_param * 0.8) / 6 - 17;
          d = sq(mag(k, e)) / 45 + 2;
          q = -5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
          py = d * 35;
          break;
        default:
          continue;
      }
      
      float minPY = 100;
      float maxPY = 400;
      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);
      
      float dragOffset = verticalProgression * 1.5;
      float phaseOffset = g.noiseOffset * 0.001 + g.id * 0.13;
      float phase = wrap01(g.pulsePhase + phaseOffset - dragOffset * 0.08);
      float contraction = g.pulseShape(phase);
      float contractCurve = g.pulseContractCurve(phase);
      
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
      
      float topCurve = 1.0 - verticalProgression * 0.5;
      float rimCurve = 0.4 + verticalProgression * 0.6;
      float radialContract = lerp(1.0, 0.72, contraction * rimCurve);
      float radialRebound = rebound * 0.14 * rimCurve;
      float baseBreath = lerp(1.3, 0.7, contraction);
      float localBreath = baseBreath * (radialContract + radialRebound);
      float verticalSqueeze = lerp(1.0, 0.92, contraction * topCurve);
      verticalSqueeze += rebound * 0.04 * topCurve;
      float localPulse = (contractCurve * 8.0 - rebound * 5.0) * (0.5 + 0.5 * topCurve);
      
      px = q * localBreath;
      py = py * verticalSqueeze;
      
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
    
    float centerX = 0, centerY = 0;
    float targetDx = 0, targetDy = 0;
    
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
    
    return new float[]{centerX, centerY, finalAlignDx, finalAlignDy};
  }
  
  void renderBloomPass(float centerX, float centerY, float alignDx, float alignDy) {
    // Velocity for trailing effect
    PVector velNorm = g.vel.copy();
    float speed = velNorm.mag();
    if (speed > 0.1) velNorm.normalize();
    else velNorm.set(0, 0);
    
    // Render from outer (faint) to inner (brighter)
    for (int layer = 0; layer < bloomLayers; layer++) {
      float radius = bloomRadius[layer] * BIOLIGHT_BLOOM_SCALE * lerp(0.8, 1.2, g.sizeFactor);
      float alpha = bloomAlpha[layer];
      color layerColor = lerpColor(baseGlowColor, haloGlowColor, bloomWhiteMix[layer]);
      
      // Trailing offset increases with layer and speed (outer layers trail more)
      float layerTrail = (bloomLayers - 1 - layer) / (float)(bloomLayers - 1); // 1 for outer, 0 for inner
      float streakOffset = layerTrail * 8.0 * streakStrength * constrain(speed / 5.0, 0, 1);
      
      // Sample step: outer layers use sparser sampling
      int sampleStep = 8 + layer * 6;
      
      for (int i = 5000; i > 0; i -= sampleStep) {
        PointData pd = computePointPosition(i, centerX, centerY, alignDx, alignDy);
        if (!pd.valid) continue;
        
        // Apply trailing offset
        float x = pd.worldX - velNorm.x * streakOffset;
        float y = pd.worldY - velNorm.y * streakOffset;
        
        float emit = computeEmission(pd.u, pd.xLocal, pd.rimRadius);
        float a = constrain(emit * alpha * 255, 0, 60);
        
        if (a < 2) continue; // Skip nearly invisible points
        
        fill(red(layerColor), green(layerColor), blue(layerColor), a);
        ellipse(x, y, radius * 2, radius * 2);
      }
    }
  }
  
  void renderEmissivePass(float centerX, float centerY, float alignDx, float alignDy) {
    // Core emission: tighter, more saturated
    float radius = 1.8 * lerp(0.9, 1.1, g.sizeFactor);
    int sampleStep = 4;
    
    for (int i = 5000; i > 0; i -= sampleStep) {
      PointData pd = computePointPosition(i, centerX, centerY, alignDx, alignDy);
      if (!pd.valid) continue;
      
      float emit = computeEmission(pd.u, pd.xLocal, pd.rimRadius);
      float a = constrain(emit * 0.28 * 255, 0, 90);
      
      if (a < 3) continue;
      
      fill(red(baseGlowColor), green(baseGlowColor), blue(baseGlowColor), a);
      ellipse(pd.worldX, pd.worldY, radius * 2, radius * 2);
    }
  }
  
  void renderRimPass(float centerX, float centerY, float alignDx, float alignDy) {
    // Enhanced rim lighting for silhouette pop
    float radius = 2.5 * lerp(0.9, 1.1, g.sizeFactor);
    color rimColor = lerpColor(baseGlowColor, color(220, 240, 255, 120), 0.3);
    int sampleStep = 5;
    
    for (int i = 5000; i > 0; i -= sampleStep) {
      PointData pd = computePointPosition(i, centerX, centerY, alignDx, alignDy);
      if (!pd.valid) continue;
      
      float rim = computeRim(pd.xLocal, pd.rimRadius);
      if (rim < 0.5) continue; // Only render rim points
      
      float emit = computeEmission(pd.u, pd.xLocal, pd.rimRadius);
      float rimEmit = emit * rim * rimBoost;
      float a = constrain(rimEmit * 0.35 * 255, 0, 70);
      
      if (a < 3) continue;
      
      fill(red(rimColor), green(rimColor), blue(rimColor), a);
      ellipse(pd.worldX, pd.worldY, radius * 2, radius * 2);
    }
  }
  
  void renderGlintPass(float centerX, float centerY, float alignDx, float alignDy) {
    // Sparse, bright specular sparkles
    color glintColor = lerpColor(baseGlowColor, color(255, 255, 255, 200), 0.7);
    int sampleStep = 8;
    
    for (int i = 5000; i > 0; i -= sampleStep) {
      PointData pd = computePointPosition(i, centerX, centerY, alignDx, alignDy);
      if (!pd.valid) continue;
      
      float rim = computeRim(pd.xLocal, pd.rimRadius);
      float photophore = computePhotophore(pd.u);
      
      // Only glint on rim or photophore points
      if (rim < 0.7 && photophore < 0.5) continue;
      
      // Twinkle animation
      float pointPhase = (i * 0.1 + g.noiseOffset) % TWO_PI;
      float twinkle = 0.5 + 0.5 * sin(t * TWO_PI * glintHz + pointPhase);
      
      float emit = computeEmission(pd.u, pd.xLocal, pd.rimRadius);
      float glint = emit * glintStrength * twinkle * max(rim, photophore);
      float a = constrain(glint * 0.5 * 255, 0, 160);
      
      if (a < 15) continue; // Skip dim glints
      
      fill(red(glintColor), green(glintColor), blue(glintColor), a);
      ellipse(pd.worldX, pd.worldY, glintRadius * 2, glintRadius * 2);
    }
  }
}
