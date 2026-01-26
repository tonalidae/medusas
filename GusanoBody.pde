class GusanoBody {
  Gusano g;
  final PVector tmpToParent = new PVector(0, 0);
  final PVector tmpPerp = new PVector(0, 0);
  // --- Phase 2: Bell-leads / tentacle-wave tuning ---
  final float SEG_SMOOTH_HEAD = 0.86;   // stiffer near bell
  final float SEG_SMOOTH_TAIL = 0.55;   // laggier toward tail
  final float TURN_REF = 0.08;          // 
  final float TURN_WAVE_BOOST = 0.85;   // 
  final float TAIL_WAVE_BOOST = 1.15;   // >1 = amplify toward tail

  GusanoBody(Gusano g) {
    this.g = g;
  }

  void updateSegments(float vmag, float contractCurve, float contraction, float glide01, float jitterGate, float turnAmt) {
    float vnorm = constrain(vmag / g.maxSpeed, 0, 1);
    float streamline = max(vnorm, contraction * 0.8);

    float slowFollow = 2.2;
    float fastFollow = 7.0;
    float followSpeed = lerp(slowFollow, fastFollow, streamline) * g.followMoodScale;
    float followPulseScale = lerp(FOLLOW_GLIDE_REDUCE, FOLLOW_CONTRACTION_BOOST, contractCurve);
    followSpeed *= followPulseScale;

    float slowTurbulence = 1.2;
    float fastTurbulence = 0.35;
    float turbulenceScale = lerp(slowTurbulence, fastTurbulence, streamline) * g.turbulenceMoodScale * g.baseTurbulence;
    float bodyGlideScale = lerp(1.0, GLIDE_BODY_TURB_SCALE, glide01);
    turbulenceScale *= bodyGlideScale;
    float bodyPulseJitterGate = lerp(0.25, 1.0, constrain(contractCurve, 0, 1));
    turbulenceScale *= bodyPulseJitterGate;
    g.debugBodyGlideScale = bodyGlideScale;

    // Lateral undulation: creates swimming wave motion
    float undulationFreq = g.pulseRate * 0.8; // Sync with pulse rhythm
    float undulationPhase = t * undulationFreq * TWO_PI;
    // Base rule: less waving at high speed
    float speedFade = pow(constrain(vnorm, 0, 1), UNDULATION_SPEED_EXP);
    float baseGate = (1.0 - speedFade);

    // Turning can re-introduce a body wave even while moving
    float turn01 = constrain(turnAmt / max(0.0001, TURN_REF), 0, 1);
    float turnGate = lerp(baseGate, 1.0, turn01 * TURN_WAVE_BOOST);

    // Bell-driven feel: stronger during contraction, softer in glide
    float pulseGate = lerp(0.35, 1.0, constrain(contractCurve, 0, 1));

    float undulationGate = UNDULATION_MAX * turnGate * pulseGate;
    g.debugUndulationGate = undulationGate;

    // Strength scales with speed but keeps a tiny baseline so tentacles still drift
    float undulationStrength = (vmag * 0.55 + 0.35) * undulationGate;

    for (int i = 1; i < g.segmentos.size(); i++) {
      Segmento seg = g.segmentos.get(i);
      Segmento segAnterior = g.segmentos.get(i - 1);

      float turbulenceX = map(noise(t * 0.5, i * 0.1, g.noiseOffset), 0, 1, -1.5, 1.5) * turbulenceScale * jitterGate;
      float turbulenceY = map(noise(t * 0.5, i * 0.1 + 100, g.noiseOffset), 0, 1, -1.5, 1.5) * turbulenceScale * jitterGate;

      // Add lateral wave motion perpendicular to movement direction
      float segmentRatio = float(i) / g.segmentos.size();
      float wavePhase = undulationPhase - segmentRatio * TWO_PI; // Wave propagates down body

      // Tail should move more than near-bell segments (wave propagates + amplifies)
      float tailScale = lerp(0.45, 1.0, segmentRatio);
      tailScale = pow(tailScale, TAIL_WAVE_BOOST);
      float waveAmplitude = sin(wavePhase) * undulationStrength * tailScale;
      
      // Calculate perpendicular offset to movement direction
      tmpToParent.set(segAnterior.x - seg.x, segAnterior.y - seg.y);
      if (tmpToParent.magSq() > 0.0001) {
        tmpToParent.normalize();
        tmpPerp.set(-tmpToParent.y, tmpToParent.x);
        turbulenceX += tmpPerp.x * waveAmplitude;
        turbulenceY += tmpPerp.y * waveAmplitude;
      }

      // Variable follow smoothing: stiffer near head, laggier near tail.
      // Slightly stiffer during contraction, looser during glide.
      float segSmoothBase = lerp(SEG_SMOOTH_HEAD, SEG_SMOOTH_TAIL, segmentRatio);
      float phaseStiff = lerp(0.92, 1.08, constrain(contractCurve, 0, 1));
      float segSmooth = constrain(segSmoothBase * phaseStiff, 0.20, 0.95);

      seg.seguir(segAnterior.x + turbulenceX, segAnterior.y + turbulenceY, followSpeed, segSmooth);
      seg.actualizar(false);
    }
  }
}
