// KinectOSCHandler.pde
// Receiver for Kinect v1 hand tracking data via OSC
// Replaces mouse interaction with Kinect hand position

void initKinectOSC() {
  // Already initialized in main sketch with oscP5
  if (oscP5 == null) {
    oscP5 = new OscP5(this, 12000);
  }
  println("Kinect OSC Receiver ready on port 12000");
}

/**
 * OSC message handler for Kinect hand position
 * /kinect/hand x y hand_id
 * x, y: screen coordinates
 * hand_id: 0=left, 1=right
 */
void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/kinect/hand")) {
    if (msg.checkTypetag("iii")) {
      int x = msg.get(0).intValue();
      int y = msg.get(1).intValue();
      int hand = msg.get(2).intValue();
      
      handleKinectHandPosition(x, y, hand);
    }
  } 
  else if (msg.checkAddrPattern("/kinect/tap")) {
    if (msg.checkTypetag("iii")) {
      int x = msg.get(0).intValue();
      int y = msg.get(1).intValue();
      int hand = msg.get(2).intValue();
      
      handleKinectTap(x, y, hand);
    }
  }
  else if (msg.checkAddrPattern("/kinect/proximity")) {
    if (msg.checkTypetag("f")) {
      float proximity = msg.get(0).floatValue();
      handleKinectProximity(proximity);
    }
  }
}

/**
 * Handle hand position update from Kinect
 * Replaces mouse movement behavior
 */
void handleKinectHandPosition(int x, int y, int handId) {
  // Update user touch position (used in wake deposition)
  userTouchPos.x = x;
  userTouchPos.y = y;
  userTouchStrength = 1.0; // Active touch
  
  // Visual feedback (optional)
  // Could draw hand cursor or interaction indicator here
  
  // Apply flow feedback from wake at hand position
  if (useUserFlowFeedback) {
    sampleFlow(x, y, flowScratch);
    userFlowVec.lerp(flowScratch, USER_FLOW_SMOOTH);
  }
}

/**
 * Handle tap/click gesture from Kinect
 * Replicates mouse click behavior for mood/fear triggers
 */
void handleKinectTap(int x, int y, int handId) {
  // Accumulate tap score (same as mouse taps)
  tapScore += 3.0; // Gesture weight
  int now = millis();
  tapLastUpdateMs = now;
  
  // Record impact for wake deposition
  recordUserImpact(x, y, 2.0);
  
  // Deposit wake blob at tap location
  depositWakeBlob(x, y, 40, 2.5);
  
  // Spawn water particles
  if (useWaterParticles) {
    spawnWaterParticles(x, y, 4);
  }
  
  // Check for mood triggers
  if (tapScore >= TAP_FEAR_THR && now - tapLastTriggerMs > TAP_TRIGGER_COOLDOWN_MS) {
    triggerFearBurst();
    tapLastTriggerMs = now;
    tapScore = 0;
  } else if (tapScore >= TAP_AGG_THR && now - tapLastTriggerMs > TAP_TRIGGER_COOLDOWN_MS) {
    triggerAggressionBurst();
    tapLastTriggerMs = now;
    tapScore = 0;
  }
  
  // Haptic/audio feedback could go here
  println("Kinect tap at (" + x + ", " + y + ") hand=" + (handId == 0 ? "LEFT" : "RIGHT"));
}

/**
 * Handle hand proximity (distance from Kinect)
 * 0 = far, 1 = very close
 */
void handleKinectProximity(float proximity) {
  // Use proximity to amplify interaction intensity
  handProximitySmoothed = handProximitySmoothed * 0.8 + proximity * 0.2;
  
  // Could use for:
  // - Amplifying fear/aggression when hand is close
  // - Scaling interaction radius
  // - Audio cue feedback
  
  handProximity = proximity;
  
  // Update hand present flag
  if (proximity > 0.1) {
    handPresent = true;
    lastHandTime = millis();
  }
}

/**
 * Trigger fear burst from intense tapping (Kinect gesture)
 */
void triggerFearBurst() {
  userFearIntensity = USER_FEAR_BOOST;
  userFearLastMs = millis();
  
  // Spawn panic particles and ripples
  depositWakeBlob(userTouchPos.x, userTouchPos.y, 60, 3.5);
  if (useWaterParticles) {
    spawnWaterParticles(userTouchPos.x, userTouchPos.y, 6);
  }
  
  println("Fear triggered by Kinect gesture!");
}

/**
 * Trigger aggression/excitement burst (sustained interaction)
 */
void triggerAggressionBurst() {
  userFearIntensity = -USER_FEAR_BOOST; // Negative = aggressive
  userFearLastMs = millis();
  
  // Create concentrated vortex
  for (int i = 0; i < 3; i++) {
    float angle = TWO_PI * i / 3.0;
    float x = userTouchPos.x + cos(angle) * 50;
    float y = userTouchPos.y + sin(angle) * 50;
    depositWakeBlob(x, y, 35, 2.0);
  }
  
  if (useWaterParticles) {
    spawnWaterParticles(userTouchPos.x, userTouchPos.y, 8);
  }
  
  println("Aggression triggered by Kinect gesture!");
}

/**
 * Update Kinect interaction system
 * Call this from main draw() loop
 */
void updateKinectInteraction() {
  if (!handPresent) return;
  
  int now = millis();
  if (now - lastHandTime > HAND_TIMEOUT_MS) {
    handPresent = false;
    userTouchStrength = 0;
    return;
  }
  
  // Decay user fear/aggression
  userFearIntensity *= USER_FEAR_DECAY;
  
  // Update global fear from Kinect interaction
  if (abs(userFearIntensity) > 0.01) {
    fearIntensity += (userFearIntensity - fearIntensity) * 0.1;
  } else {
    fearIntensity *= 0.99;
  }
}

/**
 * Draw Kinect hand indicator (optional visual feedback)
 */
void drawKinectHandIndicator() {
  if (!handPresent || userTouchPos.x < 0) return;
  
  pushStyle();
  
  // Hand position circle
  noFill();
  stroke(200, 230, 255, 100);
  strokeWeight(3);
  ellipse(userTouchPos.x, userTouchPos.y, 60, 60);
  
  // Proximity indicator
  float proximityRadius = 30 + handProximitySmoothed * 30;
  stroke(200, 230, 255, 50);
  strokeWeight(1);
  ellipse(userTouchPos.x, userTouchPos.y, proximityRadius * 2, proximityRadius * 2);
  
  // Center dot
  fill(220, 240, 255);
  noStroke();
  ellipse(userTouchPos.x, userTouchPos.y, 8, 8);
  
  popStyle();
}
