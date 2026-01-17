// ============================================================
// SimulationParams.pde
// Centralized configuration for easy tuning
// (Inspired by original code's simple parameter exposure)
// ============================================================

class SimulationParams {
  // ========== SPAWN & EXIT TIMING ==========
  int spawnDelayMs = 1000;          // Delay before jellyfish appear after interaction
  int idleToLonelyMs = 4500;        // Time before jellyfish wander away when ignored
  int lonelyToExitMs = 3500;        // Additional time before full fade-out
  int fadeOutMs = 1200;             // Duration of fade-out animation
  int calmBeforeReturnMs = 8000;    // Calm period needed before scared jellyfish return
  
  // ========== SCARE SYSTEM ==========
  float scareThreshold = 1.25;      // Accumulation needed to trigger scared exit
  float scareGain = 0.12;           // Rate of scare accumulation (lower = harder to scare)
  float scareDecay = 0.985;         // Decay rate per frame when calm
  float scareCoolFar = 0.965;       // Faster cooldown when mouse is far
  float scareCoolGentle = 0.972;    // Faster cooldown with gentle interaction
  
  // ========== MOUSE TRACKING ==========
  float intensityFollow = 0.18;     // Smoothing for mouse intensity (lower = smoother)
  float scareDriveFollow = 0.08;    // Smoothing for scare input filter
  int mouseStillThresholdMs = 800;  // Time hovering still = calming presence
  int mouseHistorySize = 8;         // Samples for smoothness calculation
  
  // ========== POPULATION ==========
  int defaultPopulation = 12;       // Starting number of jellyfish
  int minPopulation = 1;            // Minimum allowed
  int maxPopulation = 24;           // Maximum allowed
  
  // ========== RENDERING ==========
  float depthBobFreqMin = 0.015;    // Slowest depth oscillation
  float depthBobFreqMax = 0.035;    // Fastest depth oscillation
  float depthBobAmpMin = 0.15;      // Smallest depth amplitude
  float depthBobAmpMax = 0.35;      // Largest depth amplitude
  
  // ========== PHYSICS ==========
  int constraintIterations = 5;     // Rope constraint solver iterations
  float fluidDragBase = 0.4;        // Base fluid drag coefficient
  float bendSmoothingBase = 0.25;   // Base bend constraint smoothing
  
  // ========== BEHAVIOR ==========
  float brownianJitterChance = 0.03;  // Probability per frame of target micro-adjustment
  float brownianJitterMin = 15;       // Minimum jitter range (calm personalities)
  float brownianJitterMax = 45;       // Maximum jitter range (restless personalities)
  
  // ========== PERFORMANCE ==========
  float pointDensityBase = 3.5;     // Base density multiplier for point rendering
  float pointDensityMin = 0.25;     // Minimum density (many jellyfish)
  float pointDensityMax = 0.80;     // Maximum density (few jellyfish)
  
  // ========== SPATIAL GRID ==========
  float spatialCellSize = 150;      // Cell size for spatial partitioning optimization
  
  // ========== BIOLUMINESCENCE ==========
  float bioGlowArousalMul = 0.8;    // Arousal contribution to glow
  float bioGlowAttitudeMul = 0.6;   // Positive attitude (curiosity) contribution
  float bioGlowIntensityMin = 0.85; // Minimum personality glow modifier
  float bioGlowIntensityMax = 1.35; // Maximum personality glow modifier
  
  // Constructor with optional preset loading
  SimulationParams() {
    // Default values already set above
  }
  
  // Helper: calculate point density multiplier for population
  float calculatePointDensity(int population) {
    return constrain(pointDensityBase / max(1.0, (float)population), 
                     pointDensityMin, pointDensityMax);
  }
  
  // Helper: print all parameters to console
  void printParams() {
    println("\n=== SIMULATION PARAMETERS ===");
    println("Population: " + defaultPopulation + " (range: " + minPopulation + "-" + maxPopulation + ")");
    println("Spawn delay: " + spawnDelayMs + "ms");
    println("Idle → lonely: " + idleToLonelyMs + "ms");
    println("Scare threshold: " + scareThreshold + " (gain: " + scareGain + ", decay: " + scareDecay + ")");
    println("Constraint iterations: " + constraintIterations);
    println("Spatial grid cell size: " + spatialCellSize);
    println("============================\n");
  }
}
