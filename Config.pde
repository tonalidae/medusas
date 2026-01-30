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
final int MAX_HANDS = 6;              // persistent slots 0..5
final int HAND_POINTS_PER_HAND = 6;   // keep legacy per-hand stride
// Stores previous positions for up to MAX_HANDS × HAND_POINTS_PER_HAND points
PVector[] prevHandPoints = new PVector[MAX_HANDS * HAND_POINTS_PER_HAND];
float[] prevHandDepth = new float[MAX_HANDS * HAND_POINTS_PER_HAND];
float[] handSizes = new float[MAX_HANDS];   // bbox size cue per slot

boolean handPresent = false;
int lastHandTime = 0;
boolean handNear = false;      // True when user's hand is close enough to interact
float handProximity = 0;       // 0..1 estimate of closeness
float handProximitySmoothed = 0;
float HAND_NEAR_THR = 0.075;   // Hysteresis thresholds for proximity gate (tuned for smaller hands)
float HAND_FAR_THR = 0.05;
float HAND_PROX_ALPHA = 0.2;
boolean HAND_FLIP_X = true;    // Flip horizontal when camera faces the screen
boolean HAND_FLIP_Y = false;   // Set true if camera is upside-down

int HAND_TIMEOUT_MS = 1000;

// --- User tap burst detection (mouse or hand) ---
float tapScore = 0;                 // accumulates recent taps
int tapLastUpdateMs = 0;
int tapLastTriggerMs = -9999;
float TAP_DECAY_PER_SEC = 1.5;      // how fast tapScore decays without taps
int TAP_FEAR_THR = 6;               // taps within window to scare
int TAP_AGG_THR = 12;               // taps within window to anger
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
float HAND_FEAR_SPEED = 3;          // px/frame speed that counts as harsh press motion
float HAND_FEAR_RADIUS = 220;          // radius in px to scare nearby jellies
float HAND_FEAR_FIELD_SCALE = 1.4;     // extra fear deposited into mood field
int HAND_FEAR_COOLDOWN_MS = 450;       // min gap between forced fear events
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
float GLIDE_STEER_SCALE = 0.25;
float GLIDE_HEAD_NOISE_SCALE = 0.4;
float GLIDE_BODY_TURB_SCALE = 0.55;
float FOLLOW_CONTRACTION_BOOST = 1.15;
float FOLLOW_GLIDE_REDUCE = 0.7;
float SIDE_SLIP_DAMP = 0.05; // Lower = less sideways slip (more diagonal motion)
float THRUST_SMOOTH_ALPHA = 0.18; // Lower = smoother, slower response
float RECOVERY_THRUST_SCALE = 0.18; // Small tail force during relaxation
float DRAG_RELAX_SCALE = 1.03; // Slightly higher drag during relaxation
float DRAG_CONTRACT_SCALE = 0.96; // Slightly lower drag during contraction
float CYCLE_EMA_ALPHA = 0.2; // Rolling average smoothing for cycle debug
float STEER_SMOOTH_ALPHA = 0.18; // Lower = smoother turns, higher = snappier
float STEER_FLIP_DOT = -0.2; // If desired steer points opposite, damp the flip
float STEER_FLIP_SLOW = 0.15; // Extra damping factor on flips
float MAX_TURN_RAD = 0.25; // Max turn per frame (~14 deg)

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
float FEAR_MEMORY_MS = 8000;     // how long a fear imprint lingers
float FEAR_AVOID_BOOST = 1.8;    // flee multiplier when fear memory is active

// --- Energy / fatigue loop ---
float ENERGY_MAX = 1.0;
float ENERGY_MIN = 0.3;
float ENERGY_DRAIN_RATE = 0.00035;   // scales with thrust impulse
float ENERGY_RECOVER_RATE = 0.00025; // base recover per frame (scaled by dtNorm)
float ENERGY_CALM_BONUS = 2.0;       // recovery multiplier when CALM
float ENERGY_LOW_DRAG_BOOST = 0.25;  // extra drag when tired (1-energy) * this
float ENERGY_MAXSPEED_SCALE = 0.3;   // fraction of maxSpeed lost when fully tired

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

// --- Frustration (wall/flow memory) ---
float FRUSTRATION_DECAY = 0.96;
float FRUSTRATION_TURN_BOOST = 0.6;
float FRUSTRATION_WALL_PUSH = 0.8;

// --- Mood field diffusion ---
float MOOD_FIELD_DECAY = 0.92;   // base decay per 16ms; now time-scaled
float MOOD_FIELD_SPLAT = 1.0;
float MOOD_FIELD_NEIGHBOR_SPLAT = 0.5;
float MOOD_FIELD_DIAGONAL_SPLAT = 0.35;
float MOOD_FIELD_MAX = 2.0;

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
float clampMarginTop = 80;
float clampMarginBottom = 260;
// Percentage-based invisible box (relative to viewport); actual margins are max(pixel, percent*size)
float clampMarginPctX = 0.08;      // 8% from each side
float clampMarginTopPct = 0.30;    // keep top 30% clear
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
