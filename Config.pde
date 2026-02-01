// Config.pde
// Centralized configuration: global variables and tunable constants
// (moved out of muchas_medusas_nadando.pde to keep the main file cleaner)

// --- Water texture globals ---
PGraphics waterTex;
float waterT = 0;
final float WATER_TEX_SCALE = 0.5; // render at half res for speed
PImage[] waterFrames;
int waterFrameCount = 0;
int waterFrameIndex = 0;
float waterFrameAccum = 0;
int waterLastMs = 0;
boolean waterFramesAvailable = false;
boolean waterFramesWarned = false;

// Simple controls
boolean useWaterFrames = true;
boolean showWaterTex = true;
boolean showWaterInteraction = true; // render wake-based water ink/strokes/caustics
boolean showFlowTrails = false;       // show organic flow trails layer
// Blend mode choice: false -> BLEND (subtle), true -> SCREEN (gentle brighten)
boolean useScreenBlend = false;
float waterAlpha = 25; // tint alpha when drawing overlay (0-255) — lowered for greater transparency
float waterFPS = 12.0;
OscP5 oscP5;

// --- User interaction feedback (non-visual) ---
boolean useUserFlowFeedback = true;   // keep flow pushback logic active without showing a cursor
float fearIntensity = 0;             // smoothed global fear ratio (0..1)
float userFearIntensity = 0;         // smoothed intensity for user-triggered fear
int userFearLastMs = -9999;          // last time user caused fear
float USER_FEAR_BOOST = 0.65;        // how much to add on each user fear event (0..1)
float USER_FEAR_DECAY = 0.94;        // per-frame decay for user fear overlay

float remoteX = -1000;
float remoteY = -1000;
float remoteSmoothX = -1000;
float remoteSmoothY = -1000;

// --- VOLUMETRIC INTERACTION VARS ---
// Hand tracking configuration
// Up to four people at once when using body/pose tracking
final int MAX_HANDS = 4;              // persistent slots 0..3
final int HAND_POINTS_PER_HAND = 6;   // keep legacy per-hand stride
// Stores previous positions for up to MAX_HANDS × HAND_POINTS_PER_HAND points
PVector[] prevHandPoints = new PVector[MAX_HANDS * HAND_POINTS_PER_HAND];
float[] prevHandDepth = new float[MAX_HANDS * HAND_POINTS_PER_HAND];
float[] handSizes = new float[MAX_HANDS];   // bbox size cue per slot
float[] handArmEnergy = new float[MAX_HANDS];       // raw arm-energy per slot
float[] handArmEnergySmoothed = new float[MAX_HANDS];

// Arm-motion → wake scaling (used when pose/upper-limb tracking is driving OSC)
float ARM_ENERGY_SMOOTH_ALPHA = 0.22;  // low-pass for jittery velocities
float ARM_ENERGY_MIN = 6.0;            // pixels of upper-limb motion
float ARM_ENERGY_MAX = 120.0;          // pixels/frame considered vigorous
float ARM_WAKE_MIN = 0.7;              // lower bound multiplier on wake amount
float ARM_WAKE_MAX = 2.4;              // upper bound multiplier on wake amount

boolean handPresent = false;
int lastHandTime = 0;
boolean handNear = false;      // True when user's hand is close enough to interact
float handProximity = 0;       // 0..1 estimate of closeness
float handProximitySmoothed = 0;
// Thresholds tuned for body-sized detections (shoulders/torso anchors)
float HAND_NEAR_THR = 0.10;   // hysteresis gate: nearer than this → near
float HAND_FAR_THR = 0.06;    // farther than this → far
float HAND_PROX_ALPHA = 0.2;
boolean HAND_FLIP_X = true;    // Flip horizontal when camera faces the screen
boolean HAND_FLIP_Y = false;   // Set true if camera is upside-down

int HAND_TIMEOUT_MS = 1000;

// --- User tap burst detection (mouse or hand) ---
float tapScore = 0;                 // accumulates recent taps
int tapLastUpdateMs = 0;
int tapLastTriggerMs = -9999;
float TAP_DECAY_PER_SEC = 1.5;      // how fast tapScore decays without taps
int TAP_FEAR_THR = 10;              // taps within window to scare
int TAP_AGG_THR = 18;               // taps within window to anger
int TAP_TRIGGER_COOLDOWN_MS = 2500; // cooldown after forcing a mood burst
boolean prevMouseDown = false;      // edge detect mouse taps

// Engagement model: a still, near hand counts as a "press"
boolean handEngaged = false;
int handStillMs = 0;
int lastHandFrameMs = 0;
float HAND_STILL_SPEED = 3.5;      // px/frame speed considered still
int HAND_STILL_DWELL_MS = 220;     // dwell time to become engaged
float HAND_RELEASE_WAKE_SPEED = 7.0;   // speed that counts as a "launch" from press
float HAND_RELEASE_WAKE_MULT = 1.6;    // strength multiplier for launch trail
int HAND_RELEASE_WAKE_STEPS = 8;       // number of blobs along the first movement segment
int handFearLastMs = 0;                // last time we forced fear from harsh press motion
float HAND_FEAR_SPEED = 5;          // px/frame speed that counts as harsh press motion
float HAND_FEAR_RADIUS = 200;          // radius in px to scare nearby jellies
float HAND_FEAR_FIELD_SCALE = 1.1;     // extra fear deposited into mood field
int HAND_FEAR_COOLDOWN_MS = 700;       // min gap between forced fear events
float HAND_DEPTH_STILL_THR = 0.045;    // max normalized depth change while still (triplet mode)

// Tap normalization and gating
float TAP_DECAY_PER_SEC_ACTIVE = 0.8;
float TAP_DECAY_PER_SEC_IDLE = 1.5;
float tapDecayPerSec = TAP_DECAY_PER_SEC_IDLE;
float lastTapX = -1000, lastTapY = -1000;
int lastTapMs = -9999;
int MIN_TAP_DIST = 25;
int MIN_TAP_GAP_MS = 220;
int TAP_DEPTH_STABLE_MS = 80;
// Per-hand debounce
int[] handTapCount = new int[MAX_HANDS];
int[] handTapLastMs = new int[MAX_HANDS];
int pendingTapHand = -1;
int pendingTapStartMs = -9999;
int lastUserAggMs = -9999; // last time user acted aggressively (harsh/tap scare)
boolean preferOSCHands = true; // when true, disable mouse fallback if OSC hand data is present

// Friendly interaction accumulation (hand tracker)
float[] handFriendlyMs = new float[MAX_HANDS];
int[] handFriendlyStableMs = new int[MAX_HANDS];
float FRIEND_SPEED_THR = 3.0;
int FRIEND_DEPTH_STABLE_MS = 80;
float FRIEND_AFFINITY_RATE = 0.0022; // per second of gentle presence (boosted affection)
float FRIEND_RADIUS = 320;
float swarmCentroidX = 0;
float swarmCentroidY = 0;


ArrayList<Gusano> gusanos;
int numGusanos = 7;
int numSegmentos = 30;

// Global bias: keep the swarm lower in the tank (0 = none, 1 = force bottom)
float GLOBAL_VERTICAL_PULL = 0.28;
// Center the pull around this normalized height (0=top,1=bottom)
float GLOBAL_VERTICAL_TARGET = 0.78;

// --- Ecosystem variety profiles (per-agent biases) ---
String[] ECOSYSTEM_LABELS = {
  "Kelp",
  "Coral",
  "Bloom",
  "Deep"
};
int[] ECOSYSTEM_TINTS = {
  #2FAF81CC,
  #FF7CAACC,
  #7FF1EBCC,
  #8B78E0CC
};
float[] ECOSYSTEM_SPEED_MOD = {
  0.92, 1.1, 1.04, 0.85
};
float[] ECOSYSTEM_SIZE_MOD = {
  1.15, 0.85, 0.95, 1.2
};
float[] ECOSYSTEM_CURIOSITY_BOOST = {
  0.08, 0.22, 0.01, 0.3
};
float[] ECOSYSTEM_EDGE_WEIGHT = {
  -0.28, 0.32, 0.1, -0.18
};
float[] ECOSYSTEM_VERTICAL_BIAS = {
  0.35, -0.25, 0.12, -0.4
};
int ECOSYSTEM_PROFILE_COUNT = ECOSYSTEM_TINTS.length;

float timeScale = 0.001;
float t = 0;
boolean debugSteering = false;
boolean debugWake = false;
boolean debugFlow = false;
boolean debugObjetivos = false;
boolean debugStateChanges = false;
boolean debugFlowMean = false;
boolean debugNeighborStats = false;
boolean debugMoodStats = false;
boolean debugSteeringNeighbors = false;
boolean debugHelp = false;
boolean showHead = false;
boolean debugJellyMotion = false;
boolean debugJumps = false;
boolean AUTO_HEAL_NANS = false;
boolean debugCycles = false;
boolean debugBiologicalVectors = false;
boolean useRoamingPaths = true;  // when idle, follow koi-like drifting loops

// --- Roaming path tuning (koi-like figure-eights) ---
float ROAM_RADIUS_MIN = 140;
float ROAM_RADIUS_MAX = 320;
float ROAM_CENTER_FREQ = 0.08;   // low drift speed for path centers (per second on t)
float ROAM_ANG_VEL_MIN = 0.012;  // radians per frame (@60fps)
float ROAM_ANG_VEL_MAX = 0.035;
float ROAM_WEIGHT = 1.4;         // base steer weight for the path follower
float ROAM_TANGENT_WEIGHT = 0.65; // how much to bias along-path tangentially
float ROAM_CENTER_MARGIN = 140;  // keep centers away from walls
float ROAM_RADIUS_JITTER = 0.35; // modulation to make figure-eights
float ROAM_FEEL_FEAR_DAMP = 0.25; // reduce path pull when fearful
float ROAM_FEEL_AGG_DAMP = 0.15;  // reduce during aggressive chase
float ROAM_TOWARD_CENTER_BOOST = 0.9; // if far from center, lean inward
float ROAM_SPEED_BOOST = 1.15;    // increase max speed when cruising on a path
float ROAM_DRAG_REDUCE = 0.97;    // slightly lower drag while path-cruising

// --- Water interaction rendering ---
// Enhanced fluid visualization scales for richer, more dynamic appearance
float WATER_INK_ALPHA_SCALE = 12.0;     // Dominant depth layer with iridescence
float WATER_STROKE_ALPHA_SCALE = 5.5;   // Organic flow trails
float WATER_CAUSTIC_ALPHA_SCALE = 3.2;  // Enhanced caustic light network

// --- BIOLUMINESCENCE CONFIG ---
// Deep-ocean glow system: multi-pass emission, scattering, and sparkle
boolean useBioluminescence = true;       // Master toggle for glow system
float BIOLIGHT_GLOBAL_INTENSITY = 0.16;   // Master brightness multiplier (default reduced)
float BIOLIGHT_BLOOM_SCALE = 1.0;        // Scale all bloom radii
float BIOLIGHT_HEARTBEAT_HZ = 0.22;      // Slow pulse rate (Hz)
float BIOLIGHT_PULSE_BOOST = 0.6;        // How much contraction brightens glow
float BIOLIGHT_RIM_BOOST = 1.4;          // Edge enhancement multiplier
float BIOLIGHT_GLINT_DENSITY = 0.04;     // Photophore density (0..1, ~4%)
float BIOLIGHT_STREAK_STRENGTH = 0.6;    // Motion trailing amount (0..1)




// --- Jelly motion tuning (minimal, reversible knobs) ---
float UNDULATION_MAX = 0.15;
float UNDULATION_SPEED_EXP = 2.0;
float GLIDE_STEER_SCALE = 0.4;
float GLIDE_HEAD_NOISE_SCALE = 0.4;
float GLIDE_BODY_TURB_SCALE = 0.55;
float FOLLOW_CONTRACTION_BOOST = 1.15;
float FOLLOW_GLIDE_REDUCE = 0.7;
float SIDE_SLIP_DAMP = 0.05; // Lower = less sideways slip (more diagonal motion)
float THRUST_SMOOTH_ALPHA = 0.18; // Lower = smoother, slower response
float RECOVERY_THRUST_SCALE = 0.28; // Small tail force during relaxation
float DRAG_RELAX_SCALE = 1.01; // Slightly higher drag during relaxation
float DRAG_CONTRACT_SCALE = 0.96; // Slightly lower drag during contraction
float CYCLE_EMA_ALPHA = 0.2; // Rolling average smoothing for cycle debug
float STEER_SMOOTH_ALPHA = 0.24; // Lower = smoother turns, higher = snappier
float STEER_FLIP_DOT = -0.2; // If desired steer points opposite, damp the flip
float STEER_FLIP_SLOW = 0.15; // Extra damping factor on flips
float MAX_TURN_RAD = 0.35; // Max turn per frame (~20 deg)

boolean LOCK_MOOD_TO_PERSONALITY = false;

// --- Stability tuning (multi-agent robustness) ---
int ATTN_MIN = 2;
int ATTN_MAX = 6;
float ATTN_FACTOR = 0.25;
int COHESION_HYST_MS = 300;

float MAX_STEER_MOUSE = 6.0;
float MAX_STEER_WALL = 6.0;
float MAX_STEER_SEP = 4.0;
float MAX_STEER_COH = 2.0;
float MAX_STEER_WANDER = 1.8;
float MAX_STEER_SWAY = 1.2;
float MAX_STEER_AGGRO = 8.0;
float MAX_TOTAL_STEER = 8.0;

int POST_CLAMP_CALM_MS = 450;
float POST_CLAMP_STEER_SCALE = 0.4;

float JUMP_STEP_THR = 80;
float SEG_SNAP_THR = 80;

// --- Mood stabilization toggles (A/B) ---
boolean STABILIZE_MOOD = true;
boolean DEBUG_MOOD = false;

// --- Curious stickiness toward user ---
float CURIOUS_STICK_MS = 6000;   // how long a curious jelly keeps memory of the user
float CURIOUS_ATTRACT = 1.0;     // base attraction toward user when curious
float CURIOUS_ORBIT = 0.28;      // sideways orbit factor to avoid pinning
float USER_DANCE_RADIUS = 190;   // preferred swirl distance around user
float USER_DANCE_ORBIT = 0.55;   // tangential swirl strength near user
float USER_DANCE_ATTRACT = 0.45; // radial pull to maintain dance radius
float USER_DANCE_MEM_THR = 0.15; // minimum curiosity memory to dance
float USER_DANCE_AFFINITY_THR = 0.15; // minimum affinity to dance
float USER_DANCE_PHASE_MIN = 0.55; // minimum phase gate during dance
float USER_DANCE_FIG8_BLEND = 0.75; // 0=orbit, 1=figure-8
float USER_DANCE_FIG8_FREQ = 0.35;  // cycles/sec for infinity path
float USER_DANCE_FIG8_Y_SCALE = 0.8; // vertical scale of the 8
float USER_DANCE_IMPULSE = 1.18; // extra steering push during user dance
float DANCE_AXIS_CHANGE_PROB = 0.7; // chance to jitter axis during dance
int DANCE_AXIS_MIN_INTERVAL_MS = 1800;
int DANCE_AXIS_MAX_INTERVAL_MS = 4300;
float DANCE_RADIUS_JITTER = 0.2;   // relative radius variation
float DANCE_ORBIT_JITTER = 0.2;    // relative orbit strength variation
float DANCE_IMPULSE_JITTER = 0.25; // relative impulse variation
float FEAR_MEMORY_MS = 6000;     // how long a fear imprint lingers
float FEAR_AVOID_BOOST = 1.3;    // flee multiplier when fear memory is active

// --- Energy / fatigue loop ---
float ENERGY_MAX = 1.0;
float ENERGY_MIN = 0.3;
float ENERGY_DRAIN_RATE = 0.00028;   // scales with thrust impulse
float ENERGY_RECOVER_RATE = 0.00032; // base recover per frame (scaled by dtNorm)
float ENERGY_CALM_BONUS = 2.0;       // recovery multiplier when CALM
float ENERGY_LOW_DRAG_BOOST = 0.18;  // extra drag when tired (1-energy) * this
float ENERGY_MAXSPEED_SCALE = 0.22;  // fraction of maxSpeed lost when fully tired

// --- Exploration tuning ---
float EXPLORATION_WEIGHT = 0.18;     // how strongly individuals steer toward empty cells
float EXPLORATION_OCCUPANCY_SCALE = 4.0; // counts above this behave as "crowded"
float SWARM_SPREAD_RADIUS = 280;     // how close to swarm centroid we need to be before spreading
float SWARM_SPREAD_STRENGTH = 0.24;   // how much force pushes outward from the centroid

float BIOME_STEER_WEIGHT = 1.35;      // how strongly to pull toward biome target
int   BIOME_TARGET_INTERVAL_MIN_MS = 9000;
int   BIOME_TARGET_INTERVAL_MAX_MS = 18000;
float BIOME_EDGE_BIAS = 0.35;         // 0=center, 1=edge preference
float BIOME_AVOID_FEAR_SCALE = 0.4;   // reduce biome pull while fearful
float BIOME_LIKE_RATE = 0.003;        // per-frame affinity gain in calm/curious
float BIOME_AVOID_RATE = 0.006;       // per-frame affinity loss in fear
float BIOME_DECAY = 0.9985;           // per-frame decay of stored affinities
float BIOME_MIN_DIST = 140;           

float DRIFT_PULSE_MAG = 0.07;         // ±7% pulse rate wander
float DRIFT_DRAG_MAG = 0.04;          // ±4% drag wander
float DRIFT_WANDER_MAG = 0.10;        // ±10% wander weight wander
float DRIFT_SPEED = 0.015;            // cycles per second of drift
// --- Field fear tuning ---
float FIELD_FEAR_STARTLE_THRESHOLD = 0.6; // field value required to trigger fear
float FIELD_FEAR_THREAT_MIN = 0.25;       // threat signal minimum to accept the field startle
int FIELD_FEAR_HOLD_FRAMES = 6;           // consecutive frames of high field fear before startle

// --- Global fear feedback (screen warning) ---
float FEAR_TINT_MIN = 0;
float FEAR_TINT_MAX = 140;      // max red overlay alpha
float FEAR_WARN_FLOOR = 0.05;   // ignore tiny fear levels
float FEAR_INTENSITY_LERP = 0.12;
float FEAR_SHAKE_MIN = 0.0;
float FEAR_SHAKE_MAX = 10.0;    // max shake in pixels
float USER_FEAR_TINT_MAX = 170; // max red alpha when user caused the fear

// --- Buddy / micro-cohesion ---
float BUDDY_SOCIAL_THR = 0.55;
float BUDDY_PICK_CHANCE = 0.008;   // per frame chance when eligible
float BUDDY_DURATION_MS = 4200;
float BUDDY_COH_WEIGHT = 0.9;
float BUDDY_DANCE_RADIUS = 170;    // preferred orbit distance between buddies
float BUDDY_DANCE_ORBIT = 0.65;    // tangential swirl strength
float BUDDY_DANCE_ATTRACT = 0.6;   // radial pull to maintain dance radius
float BUDDY_DANCE_PHASE_MIN = 0.55; // minimum phase gate during buddy dance
float BUDDY_DANCE_FIG8_BLEND = 0.8; // 0=orbit, 1=figure-8
float BUDDY_DANCE_FIG8_FREQ = 0.4;  // cycles/sec for infinity path
float BUDDY_DANCE_FIG8_Y_SCALE = 0.85; // vertical scale of the 8
float BUDDY_DANCE_IMPULSE = 3; // extra steering push during buddy dance
float BUDDY_LOOP_RADIUS = 280;        // large loop radius for paired figure eights
float BUDDY_LOOP_Y_SCALE = 0.45;      // flatten vertical amplitude for a horizontal ∞
float BUDDY_LOOP_FREQ = 0.16;         // slow cycle rate for graceful circling
float BUDDY_LOOP_STRENGTH = 2.6;      // steering weight for the pair loops
float BUDDY_LOOP_NOISE_FREQ = 0.11;   // phase jitter so pairs drift a bit
float BUDDY_LOOP_LEGACY_BLEND = 0.38; // keep legacy buddy dance signals while letting loops dominate

// --- Frustration (wall/flow memory) ---
float FRUSTRATION_DECAY = 0.96;
float FRUSTRATION_TURN_BOOST = 0.6;
float FRUSTRATION_WALL_PUSH = 0.8;

// --- Mood field diffusion ---
float MOOD_FIELD_DECAY = 0.96;   // base decay per 16ms; now time-scaled (higher = slower fade)
float MOOD_FIELD_SPLAT = 1.4;
float MOOD_FIELD_NEIGHBOR_SPLAT = 0.65;
float MOOD_FIELD_DIAGONAL_SPLAT = 0.45;
float MOOD_FIELD_MAX = 2.6;

// --- Mood stabilization config (conservative defaults) ---
int MOOD_COOLDOWN_FRAMES = 30;   // ~0.5s at 60fps
int MOOD_DWELL_FRAMES = 10;      // condition must persist
float MOOD_EMA_ALPHA = 0.08;     // smoothing for noisy inputs
float AGG_ENTER_THR = 0.6;
float AGG_EXIT_THR = 0.4;
float SHY_ENTER_THR = 0.6;
float SHY_EXIT_THR = 0.4;
float MOOD_PROX_RADIUS = 180;

boolean useWander = true;
boolean useWallAvoid = true;
boolean useWake = true;
boolean useFlow = true;
boolean useSeparation = true;
boolean useCohesion = true;
boolean usePursuit = true;

float lastMouseX = 0;
float lastMouseY = 0;
float mouseSpeed = 0;

float followThreshold = 80;
int lastNeighborStatsLogMs = 0;
int lastMoodStatsLogMs = 0;
int lastMoodStatsTotal = 0;
int lastMoodSummaryFrame = 0;

// --- Render-safe clamp margins (keep full body on screen) ---
// Base (pixel) safety margins; fallbacks when percentage-based clamps are tiny
float clampMarginX = 120;
float clampMarginTop = 30;
float clampMarginBottom = 260;
// Percentage-based invisible box (relative to viewport); actual margins are max(pixel, percent*size)
float clampMarginPctX = 0.08;      // 8% from each side
float clampMarginTopPct = 0.12;    // keep top ~12% clear
float clampMarginBottomPct = 0.08; // keep bottom 8% clear
float clampMarginMinX = 80;
float clampMarginMinTop = 60;
float clampMarginMinBottom = 140;
int lastClampWidth = -1;
int lastClampHeight = -1;

// --- Spatial hash grid (local interactions: Rain World vibe) ---
HashMap<Long, ArrayList<Gusano>> spatialGrid = new HashMap<Long, ArrayList<Gusano>>();
// Cell size should be >= max interaction radius (cohesion/pursuit). Adjust as needed.
float gridCellSize = 260;
ArrayList<Gusano> neighborScratch = new ArrayList<Gusano>(32);

// --- Mood propagation grid (fear/calm waves) ---
class MoodField {
  float fear = 0;
  float calm = 0;
  int lastUpdate = 0;
}
HashMap<Long, MoodField> moodGrid = new HashMap<Long, MoodField>();
