class Gusano {
  static final int SHY = 0;
  static final int AGGRESSIVE = 1;

  ArrayList<Segmento> segmentos;
  color colorGusano;
  color targetColor;
  color currentColor;
  float colorLerpSpeed;
  float frecuenciaCambio;
  int id;
  float noiseOffset;

  // Current angle of the head (for smooth turning)
  float headAngle = 0;
  float prevHeadAngleForTurn = 0;
  float turnEMA = 0;
  float turnEMAFactor = 0.18;

  // Velocity-based swimming
  PVector vel;
  float drag;
  float maxSpeed = 14.0;
  float pulsePhase;
  float pulseRate;
  float pulseStrength;
  float contractPortion;
  float holdPortion;
  float sinkStrength;
  float buoyancyLift;

  // Personality bases (per-jelly defaults)
  float basePulseRate;
  float basePulseStrength;
  float baseDrag;
  float baseSinkStrength;
  float baseTurnRate;
  float baseTurbulence;
  float sizeFactor;
  float social;
  float timidity;
  float aggression;
  float curiosity;
  String personalityLabel;
  // Species archetype (rhythm baseline)
  String speciesLabel;

  // Mood/state
  int state;
  float stateTimer;
  float stateDuration;
  float moodBlend;
  float turnRate;
  float followMoodScale;
  float turbulenceMoodScale;
  float headNoiseScale;
  float prevSpeed;
  float speedEMA = 0;
  float speedEMAFactor = 0.12;
  int spikeFrames = 0;
  int spikeFramesRequired = 4;
  float spikeThreshold = 8.0;
  int moodChangeCount = 0;
  int lastMoodChangeMs = 0;
  int lastState = -1;
  int lastAggressiveEntryMs = -1;
  int lastClampMsX = -9999;
  int lastClampMsY = -9999;
  int aggroTargetId = -1;
  int aggroLastSeenMs = -9999;
  int aggroLockMs = -9999; // When target was first locked
  float aggroPauseTime = 0.4; // Pause duration before pounce (seconds)
  boolean aggroPounceReady = false; // Ready to accelerate
  int baseMood = SHY;
  float debugVmagNow = 0;
  float debugSpeedEMA = 0;
  float debugSpeedDelta = 0;
  float debugDt = 0;
  float debugDtNorm = 0;
  float debugFrameRate = 0;
  int debugSpikeFrames = 0;
  int debugSpikeFramesRequired = 0;
  float debugSpikeThreshold = 0;
  float debugContraction = 0;
  float debugGlideScale = 0;
  float debugHeadGlideScale = 0;
  float debugBodyGlideScale = 0;
  float debugUndulationGate = 0;
  float debugTurnAmt = 0;
  float debugWanderScale = 0;
  PVector steerSmoothed = new PVector(0, 0);
  PVector tmpSteerA = new PVector(0, 0);
  PVector tmpSteerB = new PVector(0, 0);
  PVector tmpSteer = new PVector(0, 0);
  PVector tmpVelDir = new PVector(0, 0);
  PVector tmpHeadingVec = new PVector(0, 0);
  PVector tmpDir = new PVector(0, 0);
  PVector tmpAway = new PVector(0, 0);
  float thrustSmoothed = 0;
  float lastCycleHz = 0;
  float lastCycleDist = 0;
  float lastCycleSpeed = 0;
  float avgCycleHz = 0;
  float avgCycleDist = 0;
  float avgCycleSpeed = 0;
  float cycleStartX = 0;
  float cycleStartY = 0;
  int cycleStartMs = -1;
  PVector debugSteerMouse = new PVector(0, 0);
  PVector debugSteerWall = new PVector(0, 0);
  PVector debugSteerSep = new PVector(0, 0);
  PVector debugSteerCoh = new PVector(0, 0);
  PVector debugSteerNeighbors = new PVector(0, 0);
  PVector debugSteerWander = new PVector(0, 0);
  PVector debugSteerSway = new PVector(0, 0);
  PVector debugSteerAlign = new PVector(0, 0);
  PVector debugSteerOrbit = new PVector(0, 0);
  PVector debugSteerAggro = new PVector(0, 0);
  int prevMood = -1;
  int lastMoodChangeFrame = 0;
  float smoothedThreat = 0;
  float smoothedCuriosity = 0;
  float smoothedProx = 0;
  int moodHoldFramesRemaining = 0;
  int moodCandidate = -1;
  int moodCandidateFrames = 0;
  GusanoMood mood;
  GusanoSteering steering;
  GusanoRender render;
  GusanoPulse pulse;
  GusanoBody body;
  GusanoDynamics dynamics;

  Gusano(float x, float y, color c, int id_) {
    segmentos = new ArrayList<Segmento>();
    colorGusano = c;
    id = id_;
    noiseOffset = random(1000);

    for (int i = 0; i < numSegmentos; i++) {
      segmentos.add(new Segmento(x, y));
    }

    // Longer decision times (graceful arcs)
    frecuenciaCambio = random(200, 400);

    // Swimming dynamics
    vel = new PVector(0, 0);
    pulsePhase = (float)id / max(1, numGusanos) + random(0.0, 0.5);
    pulsePhase = pulsePhase % 1.0;
    

    // Personality base values (some of these are set after label is chosen)
    baseSinkStrength = random(0.04, 0.10);
    baseTurnRate = random(0.045, 0.085); // Higher turn rate for curves
    baseTurbulence = random(0.9, 1.2);
    sizeFactor = random(0.85, 1.15);

    // --- Species archetype (stable rhythm baseline) ---
    float sp = random(1);
    if (sp < 0.65) {
      speciesLabel = "ROWER";   // scypho-like: slower, longer coasts
    } else if (sp < 0.85) {
      speciesLabel = "CUBO";    // cubo-like: faster, more continuous pumping
    } else {
      speciesLabel = "EPHYRA";  // juvenile flutter
    }

    // Set baseline rhythm by species (Hz + phase proportions)
    if ("ROWER".equals(speciesLabel)) {
      basePulseRate = random(0.35, 0.85);
      contractPortion = random(0.24, 0.38);
      holdPortion = random(0.16, 0.30);
    } else if ("CUBO".equals(speciesLabel)) {
      basePulseRate = random(1.6, 2.4);
      contractPortion = random(0.22, 0.30);
      holdPortion = random(0.08, 0.16);
    } else { // EPHYRA
      basePulseRate = random(1.2, 3.0);
      contractPortion = random(0.22, 0.30);
      holdPortion = random(0.07, 0.14);
    }

    // --- Personality archetype (stable baseline) ---
    float pr = random(1);
    if (pr < 0.5) {
      personalityLabel = "DOM";
    } else {
      personalityLabel = "SHY";
    }
    baseMood = baseMoodForLabel(personalityLabel);

    // Single-trait personality: one dominant trait, others kept low.
    switch(personalityLabel) {
      case "SHY":
        social = random(0.2, 0.5);
        timidity = random(0.7, 1.0);
        aggression = random(0.0, 0.2);
        curiosity = random(0.0, 0.3);
        // Rhythm is controlled by speciesLabel (not personality)
        // Strength/drag baselines (personality flavor)
        basePulseStrength = random(0.7, 1.2);
        baseDrag = random(0.90, 0.93);
        break;
      case "DOM":
      default:
        social = random(0.1, 0.4);
        timidity = random(0.0, 0.2);
        aggression = random(0.7, 1.0);
        curiosity = random(0.0, 0.3);
        // Rhythm is controlled by speciesLabel (not personality)
        // Strength/drag baselines (personality flavor)
        basePulseStrength = random(1.1, 2.1);
        baseDrag = random(0.86, 0.90);
        break;
    }

    // --- Species balancing (cheap): keep fast rhythms from teleporting ---
    // Species controls cadence; this block only scales displacement/feel.
    if ("CUBO".equals(speciesLabel)) {
      // Fast pumping: reduce per-pulse displacement, add a touch more damping.
      // (30% stronger reduction than before)
      basePulseStrength *= random(0.385, 0.525); // 0.55..0.75 scaled by 0.7
      baseDrag += random(0.039, 0.078);          // 0.03..0.06 scaled by 1.3
      maxSpeed *= random(0.574, 0.644);          // 0.82..0.92 scaled by 0.7
    } else if ("EPHYRA".equals(speciesLabel)) {
      // Juvenile flutter: very frequent, so each pulse should be tiny and quickly damped.
      // (30% stronger reduction than before)
      basePulseStrength *= random(0.245, 0.385); // 0.35..0.55 scaled by 0.7
      baseDrag += random(0.065, 0.104);          // 0.05..0.08 scaled by 1.3
      maxSpeed *= random(0.490, 0.595);          // 0.70..0.85 scaled by 0.7
    } else {
      // ROWER: keep as-is (slow cadence already reads well).
      maxSpeed *= random(0.95, 1.05);
    }

    // Global cadence control (post-species, pre-clamp)
    basePulseRate *= PULSE_RATE_SCALE;

    // Clamp to sane ranges
    baseDrag = constrain(baseDrag, 0.82, 0.97);
    basePulseStrength = constrain(basePulseStrength, 0.25, 2.4);
    maxSpeed = constrain(maxSpeed, 6.0, 16.0);

    // Keep phase proportions sane
    contractPortion = constrain(contractPortion, 0.12, 0.45);
    holdPortion = constrain(holdPortion, 0.02, 0.45);
    if (contractPortion + holdPortion > 0.85) {
      float s = 0.85 / (contractPortion + holdPortion);
      contractPortion *= s;
      holdPortion *= s;
    }

    // Current (smoothed) params
    pulseRate = basePulseRate;
    pulseStrength = basePulseStrength;
    drag = baseDrag;
    sinkStrength = baseSinkStrength;
    buoyancyLift = sinkStrength * 0.3;
    turnRate = baseTurnRate;
    followMoodScale = 1.0;
    turbulenceMoodScale = 1.0;
    headNoiseScale = 1.0;

    // Mood init (locked to personality)
    state = baseMood;
    stateTimer = 0;
    stateDuration = random(4.0, 8.0);
    lastState = state;
    moodBlend = 1.0;
    prevSpeed = 0;
    prevHeadAngleForTurn = headAngle;
    turnEMA = 0;

    colorLerpSpeed = 0.05;
    mood = new GusanoMood(this);
    steering = new GusanoSteering(this);
    render = new GusanoRender(this);
    pulse = new GusanoPulse(this);
    body = new GusanoBody(this);
    dynamics = new GusanoDynamics(this);
    targetColor = mood.paletteForState(state);
    currentColor = targetColor;
    cycleStartX = x;
    cycleStartY = y;
    cycleStartMs = millis();
  }

  void actualizar() {
    Segmento cabeza = segmentos.get(0);
    float dt = (simDt > 0) ? simDt : (1.0 / max(1, frameRate));
    dt = max(dt, 0.000001);
    float dtNorm = dt * 60.0;
    float marginBottom = clampMarginBottom;

    float vmagNow = vel.mag();
    // --- Anti-twitch: when nearly stopped, damp procedural turbulence ---
    // Map speed into 0..1 where ~0 means resting and 1 means moving.
    float motion01 = constrain(vmagNow / (maxSpeed * 0.35), 0, 1);
    // Keep a tiny bit of life even at rest, but kill most jitter.
    float jitterGate = lerp(0.06, 1.0, motion01);
    speedEMA = lerp(speedEMA, vmagNow, speedEMAFactor);
    float speedDelta = abs(vmagNow - speedEMA);
    float spikeThresholdEffective = spikeThreshold * lerp(1.15, 0.7, aggression) * lerp(1.05, 0.9, timidity);
    boolean speedSpike = (speedDelta > spikeThresholdEffective);
    if (speedSpike) {
      spikeFrames++;
    } else {
      spikeFrames = max(0, spikeFrames - 1);
    }
    boolean sustainedSpike = spikeFrames >= spikeFramesRequired;

    debugVmagNow = vmagNow;
    debugSpeedEMA = speedEMA;
    debugSpeedDelta = speedDelta;
    debugDt = dt;
    debugDtNorm = dtNorm;
    debugFrameRate = frameRate;
    debugSpikeFrames = spikeFrames;
    debugSpikeFramesRequired = spikeFramesRequired;
    debugSpikeThreshold = spikeThresholdEffective;

    mood.updateState(dt, sustainedSpike);
    mood.applyMood(dt);
    mood.updateColor();

    // Direct touch: physical hit, not attraction
    if (mousePressed) {
      float md = dist(cabeza.x, cabeza.y, mouseX, mouseY);
      if (md < 50) {
        tmpAway.set(cabeza.x - mouseX, cabeza.y - mouseY);
        if (tmpAway.magSq() > 0.0001) {
          tmpAway.normalize();
          tmpAway.mult(3.5 * dtNorm);
          vel.add(tmpAway);
        }
      }
    }

    // Advance pulse phase EARLY so steering + head + thrust use the same timing
    pulse.updatePhase(dt);

    float preContractCurve = pulseContractCurve(pulsePhase);
    float glide01Pre = 1.0 - preContractCurve;
    float headGlideScale = lerp(1.0, GLIDE_HEAD_NOISE_SCALE, glide01Pre);
    debugHeadGlideScale = headGlideScale;
    float headPulseJitterGate = lerp(0.05, 1.0, constrain(preContractCurve, 0, 1));

    // Head turbulence
    float headTurbulenceX = map(noise(t * 0.5, 0, noiseOffset), 0, 1, -1.5, 1.5) * headNoiseScale * baseTurbulence * jitterGate * headGlideScale * headPulseJitterGate;
    float headTurbulenceY = map(noise(t * 0.5, 100, noiseOffset), 0, 1, -1.5, 1.5) * headNoiseScale * baseTurbulence * jitterGate * headGlideScale * headPulseJitterGate;

    // Inertia / smooth turning
    PVector desiredSteer = steering.computeSteering(cabeza);
    desiredSteer.add(headTurbulenceX, headTurbulenceY);
    if (steerSmoothed.magSq() < 0.0001) {
      steerSmoothed.set(desiredSteer);
    } else {
      float baseAlpha = STEER_SMOOTH_ALPHA;
      if (desiredSteer.magSq() > 0.0001) {
        tmpSteerA.set(steerSmoothed);
        tmpSteerB.set(desiredSteer);
        tmpSteerA.normalize();
        tmpSteerB.normalize();
        float dot = PVector.dot(tmpSteerA, tmpSteerB);
        if (dot < STEER_FLIP_DOT) baseAlpha *= STEER_FLIP_SLOW;
      }
      float smoothAlpha = dtAlpha(baseAlpha, dt);
      steerSmoothed.lerp(desiredSteer, smoothAlpha);
    }
    tmpSteer.set(steerSmoothed);
    if (tmpSteer.magSq() < 0.0001) {
      tmpSteer.set(cos(headAngle), sin(headAngle));
    } else {
      tmpSteer.normalize();
    }

    // During glide, trust velocity direction more than instantaneous steering
    tmpVelDir.set(vel);
    if (tmpVelDir.magSq() > 0.0001) tmpVelDir.normalize();
    float contractNow = pulseContractCurve(pulsePhase);
    float glideTrust = constrain(1.0 - contractNow, 0, 1); // 1 in glide, 0 in contraction
    tmpHeadingVec.set(tmpSteer);
    if (tmpVelDir.magSq() > 0.0001) {
      tmpHeadingVec.lerp(tmpVelDir, glideTrust);
    }
    float desiredAngle = atan2(tmpHeadingVec.y, tmpHeadingVec.x);
    if (debugSteering) {
      pushStyle();
      stroke(0, 120, 255, 140);
      line(cabeza.x, cabeza.y, cabeza.x + tmpHeadingVec.x * 40, cabeza.y + tmpHeadingVec.y * 40);
      popStyle();
    }

    // Smoothly rotate headAngle towards desiredAngle
    float diff = desiredAngle - headAngle;
    if (diff > PI) diff -= TWO_PI;
    if (diff < -PI) diff += TWO_PI;
    float maxTurn = MAX_TURN_RAD * dtNorm;
    diff = constrain(diff, -maxTurn, maxTurn);
    float limitedAngle = headAngle + diff;
    // Turn mostly during contraction; coast keeps heading steadier
    float turnGate = lerp(0.25, 1.0, constrain(contractNow, 0, 1));
    float turnAlpha = dtAlpha(turnRate * turnGate, dt);
    headAngle = lerpAngle(headAngle, limitedAngle, turnAlpha);

    // --- Turn intensity (for bell-led wave propagation) ---
    float dTurn = headAngle - prevHeadAngleForTurn;
    if (dTurn > PI) dTurn -= TWO_PI;
    if (dTurn < -PI) dTurn += TWO_PI;
    float turnAmt = abs(dTurn);
    turnEMA = lerp(turnEMA, turnAmt, turnEMAFactor);
    prevHeadAngleForTurn = headAngle;
    debugTurnAmt = turnEMA;

    float speed01 = constrain(vmagNow / maxSpeed, 0, 1);
    float thrustScale = constrain(1.0 - speed01, 0.15, 1.0);

    // Velocity-based movement with pulse thrust and drag
    tmpDir.set(cos(headAngle), sin(headAngle));

    float contractCurve = pulseContractCurve(pulsePhase);
    float contraction = pulseShape(pulsePhase);
    float glide01 = 1.0 - contractCurve;
    debugContraction = contraction;
    debugGlideScale = glide01;
    dynamics.applyThrust(dtNorm, thrustScale, contractCurve, contraction, tmpDir);
    dynamics.applyBuoyancy(dtNorm, contraction, marginBottom);
    dynamics.applyDrag(contractCurve, contraction, dtNorm);
    dynamics.resolveWalls(cabeza);
    dynamics.applySideSlipDamp(dtNorm);
    dynamics.applyDeadband();
    dynamics.integrateHead(cabeza);
    vel.limit(maxSpeed);
    // Update body
    float vmag = vel.mag();
    body.updateSegments(vmag, contractCurve, contraction, glide01, jitterGate, turnEMA);
    prevSpeed = vmag;

    if (useWake || useFlow) {
      // Pulse-synced wake: stronger during contraction, minimal during glide.
      float cc = constrain(contractCurve, 0, 1);
      float pulseGate = 0.10 + 0.90 * pow(cc, 1.6);
      float deposit = wakeDeposit * (0.35 + vmag * 0.18) * pulseGate;
      depositWakePoint(cabeza.x, cabeza.y, deposit);
    }
  }

  // Contraction amount: 0..1 with contract/hold/release shaping
  float pulseShape(float phase) {
    return pulse.shape(phase);
  }

  // Thrust curve: only during contraction, peaking early/mid
  float pulseContractCurve(float phase) {
    return pulse.contractCurve(phase);
  }

  void dibujarForma() {
    render.dibujarForma();
  }

  void prepararRender() {
    render.prepareFrame();
  }

  void dibujarGlow() {
    render.drawGlowPass();
  }

  void dibujarCore() {
    render.drawCorePass();
  }

  String stateLabel() {
    return mood.stateLabel();
  }

  String stateLabelFor(int s) {
    return mood.stateLabelFor(s);
  }

  int baseMoodForLabel(String label) {
    if ("SHY".equals(label)) return SHY;
    if ("DOM".equals(label)) return AGGRESSIVE;
    return SHY;
  }
}
