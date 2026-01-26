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
    contractPortion = random(0.20, 0.30); // Individual contraction timing
    holdPortion = random(0.08, 0.15); // Individual hold duration

    // Personality base values (some of these are set after label is chosen)
    baseSinkStrength = random(0.04, 0.10);
    baseTurnRate = random(0.045, 0.085); // Higher turn rate for curves
    baseTurbulence = random(0.9, 1.2);
    sizeFactor = random(0.85, 1.15);

    // Personality archetype (stable baseline)
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
        // Slower, softer cycles
        basePulseRate = random(0.18, 0.38);
        basePulseStrength = random(0.7, 1.2);
        baseDrag = random(0.90, 0.93);
        break;
      case "DOM":
      default:
        social = random(0.1, 0.4);
        timidity = random(0.0, 0.2);
        aggression = random(0.7, 1.0);
        curiosity = random(0.0, 0.3);
        // Faster, stronger cycles
        basePulseRate = random(0.22, 0.50);
        basePulseStrength = random(1.1, 2.1);
        baseDrag = random(0.86, 0.90);
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

    colorLerpSpeed = 0.05;
    mood = new GusanoMood(this);
    steering = new GusanoSteering(this);
    render = new GusanoRender(this);
    targetColor = mood.paletteForState(state);
    currentColor = targetColor;
    cycleStartX = x;
    cycleStartY = y;
    cycleStartMs = millis();
  }

  void actualizar() {
    Segmento cabeza = segmentos.get(0);
    float dt = 1.0 / max(1, frameRate);
    // Startup / low-FPS safety: prevent huge impulses when frameRate is small
    dt = constrain(dt, 1.0/120.0, 1.0/20.0);
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
        PVector away = new PVector(cabeza.x - mouseX, cabeza.y - mouseY);
        if (away.magSq() > 0.0001) {
          away.normalize();
          vel.add(PVector.mult(away, 3.5));
        }
        if (stateCooldown <= 0) {
          // Personality lock: only aggressive personalities react with AGGRESSIVE.
          if (baseMood == AGGRESSIVE && state != AGGRESSIVE) {
            lastFearReason = "MOUSE_HIT_AGG";
            lastFearTime = millis();
            stateCooldown = random(3.0, 6.0);
            fearCooldownFrames = int(random(180, 360));
            mood.setState(AGGRESSIVE, random(2.2, 3.6));
          }
        }
      }
    }

    float preContractCurve = pulseContractCurve(pulsePhase);
    float glide01Pre = 1.0 - preContractCurve;
    float headGlideScale = lerp(1.0, GLIDE_HEAD_NOISE_SCALE, glide01Pre);
    debugHeadGlideScale = headGlideScale;

    // Head turbulence
    float headTurbulenceX = map(noise(t * 0.5, 0, noiseOffset), 0, 1, -1.5, 1.5) * headNoiseScale * baseTurbulence * jitterGate * headGlideScale;
    float headTurbulenceY = map(noise(t * 0.5, 100, noiseOffset), 0, 1, -1.5, 1.5) * headNoiseScale * baseTurbulence * jitterGate * headGlideScale;

    // Inertia / smooth turning
    PVector desiredSteer = steering.computeSteering(cabeza);
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

    float speed01 = constrain(vmagNow / maxSpeed, 0, 1);
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
      int nowMs = millis();
      if (cycleStartMs > 0) {
        float dtCycle = (nowMs - cycleStartMs) / 1000.0;
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
      cycleStartMs = nowMs;
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
      alignmentGate = constrain(map(alignment, 0.3, 0.9, 0.15, 1.0), 0.15, 1.0);
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

    // Buoyancy drift: subtle sinking when not contracting
    float sinkStrengthEffective = sinkStrength;
    if (cabeza.y > height - marginBottom) {
      sinkStrengthEffective *= 0.2;
    }
    float idleFactor = 1.0 - contraction;
    vel.y += sinkStrengthEffective * idleFactor * dtNorm;
    vel.y -= buoyancyLift * contraction * dtNorm;

    float dragPhaseScale = lerp(DRAG_RELAX_SCALE, DRAG_CONTRACT_SCALE, contractCurve);
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
    if (vel.magSq() < 0.0004) { // ~0.02^2
      vel.set(0, 0);
    }

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
    }
    if (clampedY) {
      vel.y *= 0.3;
      lastClampMsY = millis();
    }
    if (clampedX || clampedY) vel.mult(0.7);
    vel.limit(maxSpeed);
    // Update body
    float vmag = vel.mag();
    float vnorm = constrain(vmag / maxSpeed, 0, 1);
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

    float deposit = wakeDeposit * (0.5 + vmag * 0.2);
    depositWakePoint(cabeza.x, cabeza.y, deposit);
  }

  // Contraction amount: 0..1 with contract/hold/release shaping
  float pulseShape(float phase) {
    float c = max(0.0001, contractPortion);
    float h = max(0.0, holdPortion);
    float r = max(0.0001, 1.0 - c - h);

    float p = wrap01(phase);
    if (p < c) {
      float x = p / c;
      // Fast snap-in: ease-out
      return 1.0 - pow(1.0 - x, 3);
    } else if (p < c + h) {
      return 1.0;
    } else {
      float x = (p - c - h) / r;
      // Slow release: ease-in
      return 1.0 - pow(x, 2);
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

  String stateLabel() {
    return mood.stateLabel();
  }

  String stateLabelFor(int s) {
    return mood.stateLabelFor(s);
  }

  int baseMoodForLabel(String label) {
    if ("SHY".equals(label)) return SHY;
    if ("DOM".equals(label)) return AGGRESSIVE;
    return CALM;
  }
}
