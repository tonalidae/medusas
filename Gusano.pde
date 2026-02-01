class Gusano {
  static final int CALM = 0;
  static final int CURIOUS = 1;
  static final int SHY = 2;
  static final int FEAR = 3;
  static final int AGGRESSIVE = 4;

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

  // Mood/state
  int state;
  float stateTimer;
  float stateDuration;
  float stateCooldown;
  float moodBlend;
  float moodHeat = 1.0;
  float turnRate;
  float followMoodScale;
  float turbulenceMoodScale;
  float headNoiseScale;
  float postFearTimer;
  float prevSpeed;
  float speedEMA = 0;
  float speedEMAFactor = 0.12;
  int spikeFrames = 0;
  int spikeFramesRequired = 4;
  float spikeThreshold = 8.0;
  int fearCooldownFrames = 0;
  String lastFearReason = "";
  float lastFearTime = -9999;
  int moodChangeCount = 0;
  int lastMoodChangeMs = 0;
  int lastState = -1;
  int lastFearEntryMs = -1;
  int lastAggressiveEntryMs = -1;
  int lastClampMsX = -9999;
  int lastClampMsY = -9999;
  int aggroTargetId = -1;
  int aggroLastSeenMs = -9999;
  int aggroLockMs = -9999; // When target was first locked
  float aggroPauseTime = 0.4; // Pause duration before pounce (seconds)
  boolean aggroPounceReady = false; // Ready to accelerate
  int baseMood = CALM;
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
  float debugWanderScale = 0;
  PVector steerSmoothed = new PVector(0, 0);
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
  PVector debugSteerExplore = new PVector(0, 0);
  PVector debugSteerAggro = new PVector(0, 0);
  PVector debugSteerRoam = new PVector(0, 0);
  PVector debugSteerSpread = new PVector(0, 0);
  PVector debugSteerBiome = new PVector(0, 0);
  PVector debugSteerBuddyLoop = new PVector(0, 0);
  int prevMood = -1;
  int lastMoodChangeFrame = 0;
  float smoothedThreat = 0;
  float smoothedCuriosity = 0;
  float smoothedProx = 0;
  int lastUserSeenMs = -9999;     // timestamp of last user sighting
  float userInterest = 0;         // decays after user lost; drives curious linger
  int lastFearUserMs = -9999;     // timestamp of last fear trigger (user-related or spike)
  float fearMemory = 0;           // decays after fear to keep some avoidance
  float fieldFear = 0;            // sampled fear field
  float fieldCalm = 0;            // sampled calm field
  int fieldFearHoldFrames = 0;
  // User affinity memory: -1 resentful, +1 friendly, decays ~30s half-life
  float userAffinity = 0;
  int affinityLastMs = -1;
  float energy = 1.0;             // 0..1 fatigue meter
  int buddyId = -1;
  int buddyLockMs = -9999;
  float frustration = 0;          // builds on wall hits
  int moodHoldFramesRemaining = 0;
  int moodCandidate = -1;
  int moodCandidateFrames = 0;
  GusanoMood mood;
  GusanoSteering steering;
  GusanoRender render;
  GusanoBiolight biolight;
  // Ecosystem variety traits
  int ecosystemProfile = 0;
  color ecosystemTint = 0;
  float ecosystemSpeedScale = 1.0;
  float ecosystemCuriosityBoost = 0;
  float ecosystemEdgeBias = 0;
  float ecosystemVerticalBias = 0;
  int lastCellX = -9999;
  int lastCellY = -9999;
  // Roaming path state (koi-like loops)
  PVector roamCenter = new PVector(0, 0);
  float roamRadius = 200;
  float roamAngle = 0;
  float roamAngVel = 0.02;
  boolean roamFigureEight = false;
  float dtNormCurrent = 1.0; // cached dt*60 for steering use
  boolean roamActive = false;
  float roamMagLast = 0;
  float danceAxisAngle = 0;
  int nextDanceAxisChangeMs = 0;
  float danceRadiusScale = 1.0;
  float danceOrbitScale = 1.0;
  float danceImpulseScale = 1.0;
  // Long-horizon biome roaming
  PVector biomeTarget = new PVector(0, 0);
  int nextBiomeRetargetMs = 0;
  HashMap<Long, Float> biomeAffinity = new HashMap<Long, Float>();
  // Slow personal parameter drift
  float driftPhase = 0;
  float driftPulseScale = 1.0;
  float driftDragScale = 1.0;
  float driftWanderScale = 1.0;

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
    
    // Organic pulse variation: each jellyfish has unique timing irregularities
    contractPortion = random(0.24, 0.34); // Individual contraction timing
    holdPortion = random(0.05, 0.10); // Individual hold duration

    // Personality base values (some of these are set after label is chosen)
    baseSinkStrength = random(0.04, 0.10);
    baseTurnRate = random(0.060, 0.110); // Higher turn rate for curves
    baseTurbulence = random(0.9, 1.2);
    sizeFactor = random(0.85, 1.15);
    ecosystemProfile = (ECOSYSTEM_PROFILE_COUNT > 0) ? int(random(ECOSYSTEM_PROFILE_COUNT)) : 0;
    int safeProfile = max(0, min(ECOSYSTEM_PROFILE_COUNT - 1, ecosystemProfile));
    ecosystemTint = ECOSYSTEM_TINTS[safeProfile];
    ecosystemSpeedScale = ECOSYSTEM_SPEED_MOD[safeProfile];
    ecosystemCuriosityBoost = ECOSYSTEM_CURIOSITY_BOOST[safeProfile];
    ecosystemEdgeBias = ECOSYSTEM_EDGE_WEIGHT[safeProfile];
    ecosystemVerticalBias = ECOSYSTEM_VERTICAL_BIAS[safeProfile];
    float sizeMod = ECOSYSTEM_SIZE_MOD[safeProfile];
    sizeFactor = constrain(sizeFactor * sizeMod, 0.65, 1.45);
    curiosity = constrain(curiosity + ecosystemCuriosityBoost, 0, 1);
    maxSpeed = 14.0 * ecosystemSpeedScale;

    // Personality archetype (stable baseline)
    float pr = random(1);
    if (pr < 0.35) {
      personalityLabel = "SHY";
    } else if (pr < 0.65) {
      personalityLabel = "AGG";
    } else if (pr < 0.85) {
      personalityLabel = "EXPL"; // Explorer
    } else {
      personalityLabel = "DRIF"; // Drifter
    }
    baseMood = baseMoodForLabel(personalityLabel);

    // Single-trait personality: one dominant trait, others kept low.
    switch(personalityLabel) {
      case "SHY":
        social = random(0.2, 0.5);
        timidity = random(0.55, 0.85);   // narrow gap toward AGG
        aggression = random(0.1, 0.3);   // give shy a little bite
        curiosity = random(0.15, 0.35);
        // Slower, softer cycles (slightly energized)
        basePulseRate = random(0.20, 0.40);
        basePulseStrength = random(0.85, 1.40);
        baseDrag = random(0.89, 0.93);
        break;
      case "AGG":
        social = random(0.1, 0.4);
        timidity = random(0.0, 0.2);
        aggression = random(0.7, 1.0);
        // Increase AGG curiosity so these jellyfish seek the user more
        curiosity = random(0.45, 0.85);
        // Faster, stronger cycles
        basePulseRate = random(0.22, 0.50);
        basePulseStrength = random(1.1, 2.1);
        baseDrag = random(0.86, 0.90);
        break;
      case "EXPL": // Explorer: high curiosity, medium social
        social = random(0.45, 0.8);
        timidity = random(0.2, 0.5);
        aggression = random(0.0, 0.3);
        curiosity = random(0.7, 1.0);
        basePulseRate = random(0.20, 0.42);
        basePulseStrength = random(0.9, 1.4);
        baseDrag = random(0.88, 0.92);
        baseTurnRate = random(0.075, 0.120);
        baseSinkStrength = random(0.05, 0.10);
        baseTurbulence = random(1.0, 1.2);
        break;
      case "DRIF": // Drifter: low traits, high glide
      default:
        social = random(0.1, 0.3);
        timidity = random(0.1, 0.4);
        aggression = random(0.05, 0.25);
        curiosity = random(0.2, 0.5);
        basePulseRate = random(0.16, 0.32);
        basePulseStrength = random(0.7, 1.1);
        baseDrag = random(0.82, 0.88); // glidier
        baseTurnRate = random(0.050, 0.095);
        baseSinkStrength = random(0.03, 0.07);
        baseTurbulence = random(0.85, 1.05);
        break;
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
    stateCooldown = 1.5;
    lastState = state;
    moodBlend = 1.0;
    postFearTimer = 0;
    prevSpeed = 0;

    // Softer color transitions for visible gradients
    colorLerpSpeed = 0.02;
    mood = new GusanoMood(this);
    steering = new GusanoSteering(this);
    render = new GusanoRender(this);
    biolight = new GusanoBiolight(this);
    targetColor = mood.paletteForState(state, moodHeat);
    currentColor = targetColor;
    cycleStartX = x;
    cycleStartY = y;
    cycleStartMs = millis();
    initRoamPath(x, y);
    danceAxisAngle = random(TWO_PI);
    nextDanceAxisChangeMs = millis() + int(random(DANCE_AXIS_MIN_INTERVAL_MS, DANCE_AXIS_MAX_INTERVAL_MS));
    biomeTarget.set(random(width), random(height));
    nextBiomeRetargetMs = millis() + int(random(BIOME_TARGET_INTERVAL_MIN_MS, BIOME_TARGET_INTERVAL_MAX_MS));
  }

  void initRoamPath(float x, float y) {
    float margin = ROAM_CENTER_MARGIN;
    roamCenter.set(
      constrain(x, margin, width - margin),
      constrain(y, margin, height - margin)
    );
    float verticalSpan = height - clampMarginTop - clampMarginBottom;
    roamCenter.y = constrain(
      lerp(roamCenter.y, GLOBAL_VERTICAL_TARGET * height, GLOBAL_VERTICAL_PULL) +
      ecosystemVerticalBias * verticalSpan * 0.25,
      clampMarginTop, height - clampMarginBottom);
    float horizontalSpan = width - clampMarginX - clampMarginX;
    roamCenter.x = constrain(roamCenter.x + ecosystemEdgeBias * horizontalSpan * 0.25,
                              clampMarginX, width - clampMarginX);
    roamRadius = random(ROAM_RADIUS_MIN, ROAM_RADIUS_MAX);
    roamAngle = random(TWO_PI);
    float sign = random(1) < 0.5 ? -1 : 1;
    roamAngVel = sign * random(ROAM_ANG_VEL_MIN, ROAM_ANG_VEL_MAX);
    roamFigureEight = random(1) < 0.35;
  }

  void maybeUpdateDanceRandomness(boolean dancing) {
    if (!dancing) return;
    int now = millis();
    if (now < nextDanceAxisChangeMs) return;
    nextDanceAxisChangeMs = now + int(random(DANCE_AXIS_MIN_INTERVAL_MS, DANCE_AXIS_MAX_INTERVAL_MS));
    if (random(1) < DANCE_AXIS_CHANGE_PROB) {
      danceAxisAngle = random(TWO_PI);
      danceRadiusScale = 1.0 + random(-DANCE_RADIUS_JITTER, DANCE_RADIUS_JITTER);
      danceOrbitScale = 1.0 + random(-DANCE_ORBIT_JITTER, DANCE_ORBIT_JITTER);
      danceImpulseScale = constrain(1.0 + random(-DANCE_IMPULSE_JITTER, DANCE_IMPULSE_JITTER), 0.6, 1.4);
    }
  }

  void maybeRetargetBiome(int nowMs) {
    if (nowMs < nextBiomeRetargetMs) return;
    nextBiomeRetargetMs = nowMs + int(random(BIOME_TARGET_INTERVAL_MIN_MS, BIOME_TARGET_INTERVAL_MAX_MS));
    // Edge-biased random point
    float edgeBiasProfile = constrain(BIOME_EDGE_BIAS + ecosystemEdgeBias * 0.4, 0, 0.95);
    float edgeChance = edgeBiasProfile;
    float tx = random(width);
    float ty = random(height);
    ty = lerp(ty, GLOBAL_VERTICAL_TARGET * height, GLOBAL_VERTICAL_PULL);
    if (random(1) < edgeChance) {
      tx = (random(1) < 0.5) ? random(clampMarginX) : random(width - clampMarginX, width);
      ty = (random(1) < 0.5) ? random(clampMarginTop) : random(height - clampMarginBottom, height);
    }
    float verticalSpan = height - clampMarginTop - clampMarginBottom;
    ty = constrain(ty + ecosystemVerticalBias * verticalSpan * 0.25, clampMarginTop, height - clampMarginBottom);
    // Bias toward lowest-affinity cell nearby
    int cx = floor(tx / gridCellSize);
    int cy = floor(ty / gridCellSize);
    float bestScore = 1e9;
    for (int oy = -1; oy <= 1; oy++) {
      for (int ox = -1; ox <= 1; ox++) {
        long key = cellKey(cx + ox, cy + oy);
        float aff = biomeAffinity.containsKey(key) ? biomeAffinity.get(key) : 0;
        if (aff < bestScore) {
          bestScore = aff;
          biomeTarget.set((cx + ox + 0.5) * gridCellSize, (cy + oy + 0.5) * gridCellSize);
        }
      }
    }
    biomeTarget.x = constrain(biomeTarget.x, clampMarginX, width - clampMarginX);
    biomeTarget.y = constrain(biomeTarget.y, clampMarginTop, height - clampMarginBottom);
    // Avoid re-picking too close
    if (dist(biomeTarget.x, biomeTarget.y, segmentos.get(0).x, segmentos.get(0).y) < BIOME_MIN_DIST) {
      biomeTarget.x = width - biomeTarget.x;
      biomeTarget.y = height - biomeTarget.y;
    }
  }

  void updateBiomeAffinity(float dt) {
    long key = cellKey(floor(segmentos.get(0).x / gridCellSize),
                       floor(segmentos.get(0).y / gridCellSize));
    float val = biomeAffinity.containsKey(key) ? biomeAffinity.get(key) : 0;
    float delta = 0;
    if (state == CALM || state == CURIOUS) delta += BIOME_LIKE_RATE * dt * 60.0;
    if (state == FEAR) delta -= BIOME_AVOID_RATE * dt * 60.0;
    val = (val + delta) * BIOME_DECAY;
    biomeAffinity.put(key, val);
  }

  void updateDrift(float dt) {
    driftPhase += DRIFT_SPEED * TWO_PI * dt;
    driftPulseScale = 1.0 + sin(driftPhase + noiseOffset) * DRIFT_PULSE_MAG;
    driftDragScale = 1.0 + sin(driftPhase * 0.8 + noiseOffset * 1.3) * DRIFT_DRAG_MAG;
    driftWanderScale = 1.0 + sin(driftPhase * 1.2 + noiseOffset * 2.1) * DRIFT_WANDER_MAG;
  }

  void adjustAffinity(float delta) {
    userAffinity = constrain(userAffinity + delta, -1, 1);
    affinityLastMs = millis();
  }

  void actualizar() {
    Segmento cabeza = segmentos.get(0);
    // [PATCH 1] Validate incoming velocity
    if (AUTO_HEAL_NANS) validateVector(vel, "vel_start");
    float dt = 1.0 / max(1, frameRate);
    // Startup / low-FPS safety: prevent huge impulses when frameRate is small
    dt = constrain(dt, 1.0/120.0, 1.0/20.0);
    float dtNorm = dt * 60.0;
    dtNormCurrent = dtNorm;
    int nowMs = millis();
    if (affinityLastMs < 0) affinityLastMs = nowMs;
    int dtMsAffinity = max(1, nowMs - affinityLastMs);
    boolean suppressDecay = (userAffinity < 0 && (nowMs - lastUserAggMs) < 5000);
    if (!suppressDecay) {
      float decay = pow(0.5, dtMsAffinity / 120000.0); // half-life ~120s
      userAffinity *= decay;
    }
    affinityLastMs = nowMs;
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
        PVector away = new PVector(cabeza.x - mouseX, cabeza.y - mouseY);
        if (away.magSq() > 0.0001) {
          away.normalize();
          vel.add(PVector.mult(away, 3.5));
        }
        if (stateCooldown <= 0) {
          if (baseMood == AGGRESSIVE) {
            // Keep the original aggressive response for dominant archetypes.
            if (state != AGGRESSIVE) {
              lastFearReason = "MOUSE_HIT_AGG";
              lastFearTime = millis();
              stateCooldown = random(3.0, 6.0);
              fearCooldownFrames = int(random(180, 360));
              mood.setState(AGGRESSIVE, random(2.2, 3.6));
              markUserFearEvent();
            }
          } else if (state != FEAR) {
            // Any other archetype should immediately go into FEAR on a hard hit.
            lastFearReason = "MOUSE_HIT";
            lastFearTime = millis();
            stateCooldown = random(3.0, 6.0);
            fearCooldownFrames = int(random(180, 360));
            mood.setState(FEAR, random(1.4, 2.4));
            markUserFearEvent();
          }
        }
      }
    }

    nowMs = millis();
    maybeRetargetBiome(nowMs);
    updateBiomeAffinity(dt);
    updateDrift(dt);

    float preContractCurve = pulseContractCurve(pulsePhase);
    float glide01Pre = 1.0 - preContractCurve;
    float headGlideScale = lerp(1.0, GLIDE_HEAD_NOISE_SCALE, glide01Pre);
    debugHeadGlideScale = headGlideScale;

    // Head turbulence
    float headTurbulenceX = map(noise(t * 0.5, 0, noiseOffset), 0, 1, -1.5, 1.5) * headNoiseScale * baseTurbulence * jitterGate * headGlideScale;
    float headTurbulenceY = map(noise(t * 0.5, 100, noiseOffset), 0, 1, -1.5, 1.5) * headNoiseScale * baseTurbulence * jitterGate * headGlideScale;

    // Inertia / smooth turning
    PVector desiredSteer = steering.computeSteering(cabeza);
    // [PATCH 2] Validate steering from external class
    if (AUTO_HEAL_NANS) validateVector(desiredSteer, "steer_computed");
    desiredSteer.add(headTurbulenceX, headTurbulenceY);
    if (steerSmoothed.magSq() < 0.0001) {
      steerSmoothed.set(desiredSteer);
    } else {
      float smoothAlpha = STEER_SMOOTH_ALPHA;
      if (desiredSteer.magSq() > 0.0001) {
        PVector a = steerSmoothed.copy();
        PVector b = desiredSteer.copy();
        a.normalize();
        b.normalize();
        float dot = PVector.dot(a, b);
        if (dot < STEER_FLIP_DOT) smoothAlpha *= STEER_FLIP_SLOW;
      }
      steerSmoothed.lerp(desiredSteer, smoothAlpha);
    }
    PVector steer = steerSmoothed.copy();
    if (steer.magSq() < 0.0001) {
      steer.set(cos(headAngle), sin(headAngle));
    } else {
      steer.normalize();
    }
    float desiredAngle = atan2(steer.y, steer.x);
    if (debugSteering) {
      pushStyle();
      stroke(0, 120, 255, 140);
      line(cabeza.x, cabeza.y, cabeza.x + steer.x * 40, cabeza.y + steer.y * 40);
      popStyle();
    }

    // Smoothly rotate headAngle towards desiredAngle
    float diff = desiredAngle - headAngle;
    if (diff > PI) diff -= TWO_PI;
    if (diff < -PI) diff += TWO_PI;
    diff = constrain(diff, -MAX_TURN_RAD, MAX_TURN_RAD);
    float limitedAngle = headAngle + diff;
    headAngle = lerpAngle(headAngle, limitedAngle, turnRate);

    float maxSpeedEff = maxSpeed * (0.7 + ENERGY_MAXSPEED_SCALE * energy); // tired -> lower cap
    if (roamActive && useRoamingPaths && state != FEAR && state != AGGRESSIVE) {
      maxSpeedEff *= ROAM_SPEED_BOOST;
    }
    float speed01 = constrain(vmagNow / maxSpeedEff, 0, 1);
    float thrustScale = constrain(1.0 - speed01, 0.15, 1.0);

    // Velocity-based movement with pulse thrust and drag
    PVector dir = new PVector(cos(headAngle), sin(headAngle));

    // Organic pulse irregularity: real organisms don't have perfect metronome timing
    float pulseJitter = (noise(noiseOffset * 0.1, t * 0.3) - 0.5) * 0.15;
    float organicPulseRate = pulseRate * (1.0 + pulseJitter);
    
    float prevPhase = pulsePhase;
    pulsePhase += organicPulseRate * dt;
    if (pulsePhase >= 1.0) {
      pulsePhase -= 1.0;
    }
    if (pulsePhase < prevPhase) {
      int cycleNowMs = millis();
      if (cycleStartMs > 0) {
        float dtCycle = (cycleNowMs - cycleStartMs) / 1000.0;
        lastCycleHz = (dtCycle > 0.0001) ? (1.0 / dtCycle) : 0;
        lastCycleDist = dist(cycleStartX, cycleStartY, cabeza.x, cabeza.y);
        lastCycleSpeed = lastCycleHz * lastCycleDist;
        if (avgCycleHz <= 0) {
          avgCycleHz = lastCycleHz;
          avgCycleDist = lastCycleDist;
          avgCycleSpeed = lastCycleSpeed;
        } else {
          avgCycleHz = lerp(avgCycleHz, lastCycleHz, CYCLE_EMA_ALPHA);
          avgCycleDist = lerp(avgCycleDist, lastCycleDist, CYCLE_EMA_ALPHA);
          avgCycleSpeed = lerp(avgCycleSpeed, lastCycleSpeed, CYCLE_EMA_ALPHA);
        }
        if (debugCycles) {
          println("[CYCLE] id=" + id + " " + personalityLabel +
                  " state=" + stateLabel() +
                  " hz=" + nf(lastCycleHz, 0, 2) +
                  " dist=" + nf(lastCycleDist, 0, 2) +
                  " spd=" + nf(lastCycleSpeed, 0, 2) +
                  " avgHz=" + nf(avgCycleHz, 0, 2) +
                  " avgDist=" + nf(avgCycleDist, 0, 2) +
              " avgSpd=" + nf(avgCycleSpeed, 0, 2));
        }
      }
      cycleStartMs = cycleNowMs;
      cycleStartX = cabeza.x;
      cycleStartY = cabeza.y;
    }

    float contractCurve = pulseContractCurve(pulsePhase);
    float contraction = pulseShape(pulsePhase);
    float glide01 = 1.0 - contractCurve;
    debugContraction = contraction;
    debugGlideScale = glide01;
    // === BIOLOGICAL CONSTRAINT: Orientation-Gated Thrust ===
    // Jellyfish can only move effectively in the direction they're facing.
    // Gate thrust by alignment between heading and desired steering direction.
    PVector headingVec = new PVector(cos(headAngle), sin(headAngle));
    PVector steerDir = steerSmoothed.copy();
    
    float alignmentGate = 1.0; // Default: full thrust
    if (steerDir.magSq() > 0.0001) {
      steerDir.normalize();
      // Dot product: 1 = aligned, 0 = perpendicular, -1 = opposite
      float alignment = PVector.dot(headingVec, steerDir);
      // Only allow full thrust when reasonably aligned (>~30° from target)
      // Smoothly reduce thrust as misalignment increases
      alignmentGate = constrain(map(alignment, 0.2, 0.9, 0.25, 1.0), 0.25, 1.0);
    }
    
    // Breathing variation: strength varies slowly over time like breathing rhythm
    float breathCycle = noise(noiseOffset * 0.05, t * 0.08) * 0.3 + 0.85;
    float targetImpulse = 0;
    if (contractCurve > 0) {
      targetImpulse = pulseStrength * contractCurve * dtNorm * thrustScale * breathCycle * alignmentGate;
    }
    float recoveryGate = constrain(1.0 - contraction, 0, 1);
    float recoveryImpulse = pulseStrength * RECOVERY_THRUST_SCALE * recoveryGate * dtNorm * thrustScale * alignmentGate;
    targetImpulse += recoveryImpulse;
    thrustSmoothed = lerp(thrustSmoothed, targetImpulse, THRUST_SMOOTH_ALPHA);
    if (thrustSmoothed > 0.00001) {
      vel.add(PVector.mult(dir, thrustSmoothed));
    }

    // --- Energy / fatigue loop ---
    float energyDrain = thrustSmoothed * ENERGY_DRAIN_RATE;
    float energyRecover = ENERGY_RECOVER_RATE * dtNorm;
    if (state == CALM) energyRecover *= ENERGY_CALM_BONUS;
    if (vmagNow < maxSpeedEff * 0.25) energyRecover *= 1.5;
    energy = constrain(energy - energyDrain + energyRecover, ENERGY_MIN, ENERGY_MAX);

    // Buoyancy drift: subtle sinking when not contracting
    float sinkStrengthEffective = sinkStrength;
    if (cabeza.y > height - marginBottom) {
      sinkStrengthEffective *= 0.2;
    }
    float idleFactor = 1.0 - contraction;
    vel.y += sinkStrengthEffective * idleFactor * dtNorm;
    vel.y -= buoyancyLift * contraction * dtNorm;

    float dragPhaseScale = lerp(DRAG_RELAX_SCALE, DRAG_CONTRACT_SCALE, contractCurve);
    if (roamActive && useRoamingPaths && state != FEAR && state != AGGRESSIVE) {
      dragPhaseScale *= ROAM_DRAG_REDUCE;
    }
    vel.mult(drag * dragPhaseScale);

    // === BIOLOGICAL CONSTRAINT: Soft-Body Wall Response ===
    // Instead of zeroing velocity, apply rotational deflection.
    // The jellyfish "feels" the wall and rotates away while sliding along it.
    float leftBound = clampMarginX;
    float rightBound = width - clampMarginX;
    float topBound = clampMarginTop;
    float bottomBound = height - clampMarginBottom;
    float edgeSoftness = 50; // Soft zone before hard boundary

    // Calculate wall penetration and normal
    PVector wallNormal = new PVector(0, 0);
    float penetration = 0;

    if (cabeza.x < leftBound + edgeSoftness) {
      float depth = constrain(1.0 - (cabeza.x - leftBound) / edgeSoftness, 0, 1);
      wallNormal.x += depth;
      penetration = max(penetration, depth);
    }
    if (cabeza.x > rightBound - edgeSoftness) {
      float depth = constrain(1.0 - (rightBound - cabeza.x) / edgeSoftness, 0, 1);
      wallNormal.x -= depth;
      penetration = max(penetration, depth);
    }
    if (cabeza.y < topBound + edgeSoftness) {
      float depth = constrain(1.0 - (cabeza.y - topBound) / edgeSoftness, 0, 1);
      wallNormal.y += depth;
      penetration = max(penetration, depth);
    }
    if (cabeza.y > bottomBound - edgeSoftness) {
      float depth = constrain(1.0 - (bottomBound - cabeza.y) / edgeSoftness, 0, 1);
      wallNormal.y -= depth;
      penetration = max(penetration, depth);
    }

    if (penetration > 0.01 && wallNormal.magSq() > 0.0001) {
      wallNormal.normalize();
      
      // 1. ROTATIONAL DEFLECTION: Turn the head away from wall
      //    This applies "torque" rather than instant position change
      float headingToWall = atan2(wallNormal.y, wallNormal.x);
      
      // Calculate which way to turn (toward the wall normal = away from wall)
      float turnAway = headingToWall - headAngle;
      if (turnAway > PI) turnAway -= TWO_PI;
      if (turnAway < -PI) turnAway += TWO_PI;
      
      // Apply rotational torque proportional to penetration squared (soft feel)
      float torqueStrength = 0.12 * penetration * penetration;
      headAngle = lerpAngle(headAngle, headAngle + turnAway * 0.4, torqueStrength);
      
      // 2. SLIDING FRICTION: Allow movement parallel to wall, resist perpendicular
      float dotVelWall = PVector.dot(vel, wallNormal);
      PVector velPerp = PVector.mult(wallNormal, dotVelWall);
      PVector velPara = PVector.sub(vel, velPerp);
      
      // Dampen perpendicular velocity (into wall), preserve parallel (sliding)
      float perpDamping = lerp(0.85, 0.3, penetration); // More penetration = more damping
      velPerp.mult(perpDamping);
      vel.set(PVector.add(velPara.mult(0.95), velPerp));
      
      // 3. SOFT PUSH: Gentle outward force, not instant teleport
      float pushStrength = penetration * penetration * 0.6;
      vel.add(PVector.mult(wallNormal, pushStrength));
    }

    // Reduce sideways slip so movement stays closer to heading (avoid lateral "steps")
    if (vel.magSq() > 0.0001) {
      float vParallel = PVector.dot(vel, headingVec);
      PVector vParallelVec = PVector.mult(headingVec, vParallel);
      PVector vPerp = PVector.sub(vel, vParallelVec);
      vPerp.mult(SIDE_SLIP_DAMP);
      vel.set(PVector.add(vParallelVec, vPerp));
    }

    // Deadband: stop tiny residual velocities from looking like nervous twitching
    if (vel.magSq() < 0.00025) { // ~0.016^2
      vel.set(0, 0);
    }

    // Frustration decay
    frustration *= FRUSTRATION_DECAY;

    // [PATCH 3] Validate final velocity before moving position
    if (AUTO_HEAL_NANS) validateVector(vel, "vel_final");

    // Manual movement of head based on smooth angle + velocity
    cabeza.angulo = headAngle;
    cabeza.x += vel.x;
    cabeza.y += vel.y;
    float preClampX = cabeza.x;
    float preClampY = cabeza.y;
    cabeza.actualizar(); // Constrain logic (hard clamp as last resort)
    boolean clampedX = (cabeza.x != preClampX);
    boolean clampedY = (cabeza.y != preClampY);
    // Soft response even on hard clamp: just dampen, don't zero
    if (clampedX) {
      vel.x *= 0.3;
      lastClampMsX = millis();
      frustration = min(1.0, frustration + 0.35);
    }
    if (clampedY) {
      vel.y *= 0.3;
      lastClampMsY = millis();
      frustration = min(1.0, frustration + 0.35);
    }
    if (clampedX || clampedY) vel.mult(0.7);
    vel.limit(maxSpeedEff);
    // Update body
    float vmag = vel.mag();
    float vnorm = constrain(vmag / maxSpeedEff, 0, 1);
    float streamline = max(vnorm, contraction * 0.8);

    float slowFollow = 2.2;
    float fastFollow = 7.0;
    float followSpeed = lerp(slowFollow, fastFollow, streamline) * followMoodScale;
    float followPulseScale = lerp(FOLLOW_GLIDE_REDUCE, FOLLOW_CONTRACTION_BOOST, contractCurve);
    followSpeed *= followPulseScale;

    float slowTurbulence = 1.2;
    float fastTurbulence = 0.35;
    float turbulenceScale = lerp(slowTurbulence, fastTurbulence, streamline) * turbulenceMoodScale * baseTurbulence;
    float bodyGlideScale = lerp(1.0, GLIDE_BODY_TURB_SCALE, glide01);
    turbulenceScale *= bodyGlideScale;
    debugBodyGlideScale = bodyGlideScale;

    // Lateral undulation: creates swimming wave motion
    float undulationFreq = pulseRate * 0.8; // Sync with pulse rhythm
    float undulationPhase = t * undulationFreq * TWO_PI;
    float speedFade = pow(constrain(vnorm, 0, 1), UNDULATION_SPEED_EXP);
    float undulationGate = UNDULATION_MAX * (1.0 - speedFade);
    debugUndulationGate = undulationGate;
    float undulationStrength = vmag * 0.6 * undulationGate; // Tiny drift only
    
    for (int i = 1; i < segmentos.size(); i++) {
      Segmento seg = segmentos.get(i);
      Segmento segAnterior = segmentos.get(i - 1);

      float turbulenceX = map(noise(t * 0.5, i * 0.1, noiseOffset), 0, 1, -1.5, 1.5) * turbulenceScale * jitterGate;
      float turbulenceY = map(noise(t * 0.5, i * 0.1 + 100, noiseOffset), 0, 1, -1.5, 1.5) * turbulenceScale * jitterGate;

      // Add lateral wave motion perpendicular to movement direction
      float segmentRatio = float(i) / segmentos.size();
      float wavePhase = undulationPhase - segmentRatio * TWO_PI; // Wave propagates down body
      float waveAmplitude = sin(wavePhase) * undulationStrength * (1.0 - segmentRatio * 0.5);
      
      // Calculate perpendicular offset to movement direction
      PVector toParent = new PVector(segAnterior.x - seg.x, segAnterior.y - seg.y);
      if (toParent.magSq() > 0.0001) {
        toParent.normalize();
        PVector perpendicular = new PVector(-toParent.y, toParent.x);
        turbulenceX += perpendicular.x * waveAmplitude;
        turbulenceY += perpendicular.y * waveAmplitude;
      }

      seg.seguir(segAnterior.x + turbulenceX, segAnterior.y + turbulenceY, followSpeed);
      seg.actualizar();
    }

    prevSpeed = vmag;

    // Phase-gated wake deposition: only strong during contraction or fast motion
    float phaseGate = constrain((contractCurve - 0.5) * 2.0, 0, 1); // rises when contractCurve > 0.5
    float speedGate = constrain(map(vmag, 1.5, 7.0, 0, 1), 0, 1);
    float depositGate = max(phaseGate, speedGate * 0.8);
    if (depositGate > 0.001) {
      float deposit = wakeDeposit * depositGate * (0.6 + vmag * 0.25);
      depositWakePoint(cabeza.x, cabeza.y, deposit);
    }
  }

  // --- Roaming path helper: koi-like drifting loops across the tank ---
  PVector computeRoamSteer(Segmento cabeza, float glideSteerScale, float steerPhaseGate) {
    PVector zero = new PVector(0, 0);
    roamActive = false;
    roamMagLast = 0;
    if (!useRoamingPaths) return zero;

    // Advance angular position using current timestep
    float dtNorm = max(0.0001, dtNormCurrent);
    roamAngle += roamAngVel * dtNorm;
    if (roamAngle > TWO_PI) roamAngle -= TWO_PI;
    if (roamAngle < 0) roamAngle += TWO_PI;

    // Slowly drift the center with low-frequency noise so paths explore the space
    float nx = noise(noiseOffset * 0.7, t * ROAM_CENTER_FREQ) - 0.5;
    float ny = noise(noiseOffset * 1.1, t * ROAM_CENTER_FREQ) - 0.5;
    float margin = ROAM_CENTER_MARGIN;
    float cx = width * 0.5 + nx * (width * 0.5 - margin);
    float cy = height * 0.5 + ny * (height * 0.5 - margin);
    roamCenter.set(cx, cy);

    // Radius modulation for soft figure-eight wobble
    float rMod = roamFigureEight ? (1.0 + ROAM_RADIUS_JITTER * sin(roamAngle * 2.0)) : 1.0;
    float r = roamRadius * rMod;
    float tx = cx + cos(roamAngle) * r;
    float ty = cy + sin(roamAngle) * r;

    PVector toTarget = new PVector(tx - cabeza.x, ty - cabeza.y);
    float d = toTarget.mag();
    if (d < 0.0001) return zero;
    toTarget.normalize();

    // Tangential bias keeps motion flowing around the path instead of stop-start
    PVector tangent = new PVector(-toTarget.y, toTarget.x);
    tangent.normalize();

    // If we've drifted far from the path center, gently pull inward
    PVector toCenter = new PVector(cx - cabeza.x, cy - cabeza.y);
    float centerPull = 0;
    float centerDist = toCenter.mag();
    if (centerDist > 0.0001) {
      toCenter.normalize();
      float far = constrain(map(centerDist, r * 1.1, r * 2.0, 0, 1), 0, 1);
      centerPull = far * ROAM_TOWARD_CENTER_BOOST;
    }

    float moodDamp = 1.0;
    if (state == FEAR) moodDamp *= ROAM_FEEL_FEAR_DAMP;
    if (state == AGGRESSIVE) moodDamp *= ROAM_FEEL_AGG_DAMP;

    PVector roam = new PVector(0, 0);
    roam.add(PVector.mult(toTarget, ROAM_WEIGHT * glideSteerScale * steerPhaseGate));
    roam.add(PVector.mult(tangent, ROAM_TANGENT_WEIGHT * glideSteerScale * steerPhaseGate));
    if (centerPull > 0) {
      roam.add(PVector.mult(toCenter, centerPull * steerPhaseGate));
    }
    roam.mult(moodDamp);
    roamMagLast = roam.mag();
    roamActive = roamMagLast > 0.08;
    debugSteerRoam.set(roam);
    return roam;
  }

  // Contraction amount: 0..1 with contract/hold/release shaping
  float pulseShape(float phase) {
    // Sanitize inputs to ensure geometry is valid
    float c = constrain(contractPortion, 0.01, 0.90);
    // Ensure hold doesn't eat the entire remaining time
    float h = constrain(holdPortion, 0.0, 0.98 - c);
    // r is guaranteed > 0.01 due to constraints above
    float r = 1.0 - c - h;

    float p = wrap01(phase);
    if (p < c) {
      float x = p / c;
      return 1.0 - pow(1.0 - x, 3);
    } else if (p < c + h) {
      return 1.0;
    } else {
      float x = (p - c - h) / r;
      // Extra safety constrain
      return 1.0 - pow(constrain(x, 0, 1), 2);
    }
  }

  // Thrust curve: only during contraction, peaking early/mid
  float pulseContractCurve(float phase) {
    float c = max(0.0001, contractPortion);
    float p = wrap01(phase);
    if (p >= c) return 0;
    float x = p / c;
    return sin(PI * sqrt(x));
  }

  void dibujarForma() {
    render.dibujarForma();
  }
  
  void dibujarBiolight() {
    biolight.render();
  }

  String stateLabel() {
    return mood.stateLabel();
  }

  String stateLabelFor(int s) {
    return mood.stateLabelFor(s);
  }

  int baseMoodForLabel(String label) {
    if ("SHY".equals(label)) return SHY;
    if ("AGG".equals(label)) return AGGRESSIVE;
    if ("EXPL".equals(label)) return CURIOUS;
    if ("DRIF".equals(label)) return CALM;
    return CALM;
  }

  // Validate PVector for NaN/Infinite and optionally heal
  void validateVector(PVector v, String label) {
    if (v == null) return;
    if (Float.isNaN(v.x) || Float.isNaN(v.y) || Float.isInfinite(v.x) || Float.isInfinite(v.y)) {
      if (AUTO_HEAL_NANS) {
        println("[WARN] NaN detected in " + label + " (ID: " + id + "). Resetting to 0.");
        v.set(0, 0);
        // Small kick to prevent dead-stop gravity wells
        v.x = random(-0.01, 0.01);
      }
    }
  }

}
