class GusanoDynamics {
  Gusano g;
  final PVector tmpSteerDir = new PVector(0, 0);
  final PVector tmpWallNormal = new PVector(0, 0);
  final PVector tmpVelPerp = new PVector(0, 0);
  final PVector tmpVelPara = new PVector(0, 0);
  final PVector tmpHeading = new PVector(0, 0);
  final PVector tmpVParallel = new PVector(0, 0);
  final PVector tmpVPerp = new PVector(0, 0);

  GusanoDynamics(Gusano g) {
    this.g = g;
  }

  void applyThrust(float dtNorm, float thrustScale, float contractCurve, float contraction, PVector dir) {
    // === BIOLOGICAL CONSTRAINT: Orientation-Gated Thrust ===
    // Jellyfish can only move effectively in the direction they're facing.
    // Gate thrust by alignment between heading and desired steering direction.
    tmpSteerDir.set(g.steerSmoothed);
    
    float alignmentGate = 1.0; // Default: full thrust
    if (tmpSteerDir.magSq() > 0.0001) {
      tmpSteerDir.normalize();
      // Dot product: 1 = aligned, 0 = perpendicular, -1 = opposite
      float alignment = PVector.dot(dir, tmpSteerDir);
      // Only allow full thrust when reasonably aligned (>~30° from target)
      // Smoothly reduce thrust as misalignment increases
      // Raise minimum gate so misalignment doesn't strangle motion as often
      // Relax the gate range so some thrust is allowed at larger misalignment
      alignmentGate = constrain(map(alignment, 0.0, 0.9, 0.15, 1.0), 0.15, 1.0);
    }
    
    // Breathing variation: strength varies slowly over time like breathing rhythm
    float breathCycle = noise(g.noiseOffset * 0.05, t * 0.08) * 0.3 + 0.85;
    float targetImpulse = 0;
    if (contractCurve > 0) {
      targetImpulse = g.pulseStrength * contractCurve * dtNorm * thrustScale * breathCycle * alignmentGate;
    }
    float recoveryGate = constrain(1.0 - contraction, 0, 1);
    float recoveryImpulse = g.pulseStrength * RECOVERY_THRUST_SCALE * recoveryGate * dtNorm * thrustScale * alignmentGate;
    targetImpulse += recoveryImpulse;
    float thrustAlpha = 1.0 - pow(1.0 - THRUST_SMOOTH_ALPHA, dtNorm);
    g.thrustSmoothed = lerp(g.thrustSmoothed, targetImpulse, thrustAlpha);
    if (g.thrustSmoothed > 0.00001) {
      tmpSteerDir.set(dir).mult(g.thrustSmoothed);
      g.vel.add(tmpSteerDir);
    }
  }

  void applyBuoyancy(float dtNorm, float contraction, float marginBottom) {
    // Buoyancy drift: subtle sinking when not contracting
    float sinkStrengthEffective = g.sinkStrength;
    if (g.segmentos.get(0).y > height - marginBottom) {
      sinkStrengthEffective *= 0.2;
    }
    float idleFactor = 1.0 - contraction;
    g.vel.y += sinkStrengthEffective * idleFactor * dtNorm;
    g.vel.y -= g.buoyancyLift * contraction * dtNorm;
  }

  void applyDrag(float contractCurve, float contraction, float dtNorm) {
    float dragPhaseScale = lerp(DRAG_RELAX_SCALE, DRAG_CONTRACT_SCALE, contractCurve);

    // Phase 5: brief low-drag glide after contraction (vortex-ring feel)
    float cc = constrain(contractCurve, 0, 1);
    float s  = constrain(contraction, 0, 1);
    float relax01 = 1.0 - cc;
    float vortex = constrain(s * relax01, 0, 1);
    float vortexDragScale = lerp(1.0, 0.90, vortex); // up to 10% less drag briefly

    float dragBase = g.drag * dragPhaseScale * vortexDragScale;
    dragBase = constrain(dragBase, 0.0, 0.999);
    float dragFrame = pow(dragBase, dtNorm);
    g.vel.mult(dragFrame);
  }

  void resolveWalls(Segmento cabeza) {
    // === BIOLOGICAL CONSTRAINT: Soft-Body Wall Response ===
    // Instead of zeroing velocity, apply rotational deflection.
    // The jellyfish "feels" the wall and rotates away while sliding along it.
    float leftBound = clampMarginX;
    float rightBound = width - clampMarginX;
    float topBound = clampMarginTop;
    float bottomBound = height - clampMarginBottom;
    float edgeSoftness = 50; // Soft zone before hard boundary

    // Calculate wall penetration and normal
    tmpWallNormal.set(0, 0);
    float penetration = 0;

    if (cabeza.x < leftBound + edgeSoftness) {
      float depth = constrain(1.0 - (cabeza.x - leftBound) / edgeSoftness, 0, 1);
      tmpWallNormal.x += depth;
      penetration = max(penetration, depth);
    }
    if (cabeza.x > rightBound - edgeSoftness) {
      float depth = constrain(1.0 - (rightBound - cabeza.x) / edgeSoftness, 0, 1);
      tmpWallNormal.x -= depth;
      penetration = max(penetration, depth);
    }
    if (cabeza.y < topBound + edgeSoftness) {
      float depth = constrain(1.0 - (cabeza.y - topBound) / edgeSoftness, 0, 1);
      tmpWallNormal.y += depth;
      penetration = max(penetration, depth);
    }
    if (cabeza.y > bottomBound - edgeSoftness) {
      float depth = constrain(1.0 - (bottomBound - cabeza.y) / edgeSoftness, 0, 1);
      tmpWallNormal.y -= depth;
      penetration = max(penetration, depth);
    }

    if (penetration > 0.01 && tmpWallNormal.magSq() > 0.0001) {
      tmpWallNormal.normalize();
      
      // 1. ROTATIONAL DEFLECTION: Turn the head away from wall
      //    This applies "torque" rather than instant position change
      float headingToWall = atan2(tmpWallNormal.y, tmpWallNormal.x);
      
      // Calculate which way to turn (toward the wall normal = away from wall)
      float turnAway = headingToWall - g.headAngle;
      if (turnAway > PI) turnAway -= TWO_PI;
      if (turnAway < -PI) turnAway += TWO_PI;
      
      // Apply reduced rotational torque proportional to penetration squared (so walls
      // nudge heading but don't induce large rapid head rotations that propagate)
      float torqueStrength = 0.06 * penetration * penetration;
      g.headAngle = lerpAngle(g.headAngle, g.headAngle + turnAway * 0.4, torqueStrength);
      
      // 2. SLIDING FRICTION: Allow movement parallel to wall, resist perpendicular
      float dotVelWall = PVector.dot(g.vel, tmpWallNormal);
      tmpVelPerp.set(tmpWallNormal).mult(dotVelWall);
      tmpVelPara.set(g.vel).sub(tmpVelPerp);
      
      // Dampen perpendicular velocity (into wall), preserve parallel (sliding)
      // Increase damping at low penetration slightly to avoid sliding-induced snaking
      float perpDamping = lerp(0.95, 0.2, penetration); // More penetration = more damping
      tmpVelPerp.mult(perpDamping);
      tmpVelPara.mult(0.95);
      tmpVelPara.add(tmpVelPerp);
      g.vel.set(tmpVelPara);
      
      // 3. SOFT PUSH: Gentle outward force, not instant teleport. Reduce magnitude
      // so wall responses don't inject large lateral velocities into the chain.
      float pushStrength = penetration * penetration * 0.3;
      tmpVelPerp.set(tmpWallNormal).mult(pushStrength);
      g.vel.add(tmpVelPerp);
    }
  }

  void applySideSlipDamp(float dtNorm) {
    // Reduce sideways slip so movement stays closer to heading (avoid lateral "steps")
    if (g.vel.magSq() > 0.0001) {
      tmpHeading.set(cos(g.headAngle), sin(g.headAngle));
      float vParallel = PVector.dot(g.vel, tmpHeading);
      tmpVParallel.set(tmpHeading).mult(vParallel);
      tmpVPerp.set(g.vel).sub(tmpVParallel);
      // Increase effective damping per-frame to more strongly suppress lateral slip
      float slipDamp = pow(constrain(SIDE_SLIP_DAMP, 0.0, 1.0), dtNorm * 1.8);
      tmpVPerp.mult(slipDamp);
      tmpVParallel.add(tmpVPerp);
      g.vel.set(tmpVParallel);
    }
  }

  void applyDeadband() {
    // Deadband: stop tiny residual velocities from looking like nervous twitching
    // Relax deadband slightly so very small motions aren't zeroed out
    if (g.vel.magSq() < 0.000025) { // ~0.005^2
      g.vel.set(0, 0);
    }
  }

  void integrateHead(Segmento cabeza) {
    // Manual movement of head based on smooth angle + velocity
    cabeza.angulo = g.headAngle;
    cabeza.x += g.vel.x;
    cabeza.y += g.vel.y;
    float preClampX = cabeza.x;
    float preClampY = cabeza.y;
    cabeza.actualizar(true); // Constrain logic (hard clamp as last resort)
    boolean clampedX = (cabeza.x != preClampX);
    boolean clampedY = (cabeza.y != preClampY);
    // Soft response even on hard clamp: just dampen, don't zero
    if (clampedX) {
      g.vel.x *= 0.3;
      g.lastClampMsX = millis();
    }
    if (clampedY) {
      g.vel.y *= 0.3;
      g.lastClampMsY = millis();
    }
    if (clampedX || clampedY) g.vel.mult(0.7);
  }
}
