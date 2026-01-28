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
// Blend mode choice: false -> BLEND (subtle), true -> SCREEN (gentle brighten)
boolean useScreenBlend = false;
float waterAlpha = 25; // tint alpha when drawing overlay (0-255) — lowered for greater transparency
float waterFPS = 12.0;
OscP5 oscP5;

float remoteX = -1000;
float remoteY = -1000;
float remoteSmoothX = -1000;
float remoteSmoothY = -1000;

// --- VOLUMETRIC INTERACTION VARS ---
// Stores previouspositions for up to 12 tracked points (2 hands × 6 points)
PVector[] prevHandPoints = new PVector[12]; 

boolean handPresent = false;
int lastHandTime = 0;

int HAND_TIMEOUT_MS = 1000;


ArrayList<Gusano> gusanos;
int numGusanos = 7;
int numSegmentos = 30;

float timeScale = 0.001;
float t = 0;
boolean debugSteering = false;
boolean debugWake = false;
boolean debugFlow = false;
boolean debugObjetivos = true;
boolean debugStateChanges = false;
boolean debugFlowMean = false;
boolean debugNeighborStats = false;
boolean debugMoodStats = false;
boolean debugSteeringNeighbors = false;
boolean debugHelp = true;
boolean showHead = false;
boolean debugJellyMotion = false;
boolean debugJumps = false;
boolean AUTO_HEAL_NANS = false;
boolean debugCycles = false;
boolean debugBiologicalVectors = false;




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

boolean LOCK_MOOD_TO_PERSONALITY = true;

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
boolean DEBUG_MOOD = true;

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
float clampMarginX = 120;
float clampMarginTop = 80;
float clampMarginBottom = 260;

// --- Spatial hash grid (local interactions: Rain World vibe) ---
HashMap<Long, ArrayList<Gusano>> spatialGrid = new HashMap<Long, ArrayList<Gusano>>();
// Cell size should be >= max interaction radius (cohesion/pursuit). Adjust as needed.
float gridCellSize = 260;
