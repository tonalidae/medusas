ArrayList<Gusano> gusanos;
int w = 1280;
int h = 800;
boolean useSmooth = true;
int smoothLevel = 2;
int numGusanos = 8;
int numSegmentos = 30;

float timeScale = 0.001;
float t = 0;
float simT = 0;
float simDt = 0;
// Global simulation speed (physics + pulse cadence). 1.0 = normal, lower = slower.
float SIM_TIME_SCALE = 1;
boolean debugSteering = false;
boolean debugWake = false;
boolean debugObjetivos = true;
boolean debugStateChanges = false;
boolean debugFlowMean = false;
boolean debugNeighborStats = false;
boolean debugMoodStats = false;
boolean debugSteeringNeighbors = false;
boolean debugHelp = true;
boolean showHead = false;
boolean debugJellyMotion = false;
boolean debugCycles = false;
boolean debugBiologicalVectors = false;
boolean debugWakeVectors = false;
boolean showWaterInteraction = true;
boolean showWaterTex = true;
boolean useWaterFrames = true;
float waterFPS = 12;
float waterAlpha = 20;
boolean allowProceduralWater = false;

// --- Water interaction rendering ---
float WATER_INK_ALPHA_SCALE = 18.0;     // Dominant layer (mass)
float WATER_STROKE_ALPHA_SCALE = 8.0;   // Direction layer (~30-40%)
float WATER_CAUSTIC_ALPHA_SCALE = 5.0;  // Sparkle layer (~20-30%)

// --- Jelly motion tuning (minimal, reversible knobs) ---
// Tuning notes:
// UNDULATION_MAX: overall lateral drift amount; lower = less snake-wiggle.
// UNDULATION_SPEED_EXP: higher exponent keeps drift at low speed, fades later at high speed.
// GLIDE_STEER_SCALE: wander/sway multiplier during glide; lower = calmer coast.
// GLIDE_HEAD_NOISE_SCALE: head turbulence during glide; lower = steadier bell lead.
// GLIDE_BODY_TURB_SCALE: body turbulence during glide; lower = less body shimmer.
// FOLLOW_CONTRACTION_BOOST / FOLLOW_GLIDE_REDUCE: body pull-in vs lag through pulse.
float PULSE_RATE_SCALE = 0.70; // Global cadence scale; lower = slower pulses
float UNDULATION_MAX = 0.15;
float UNDULATION_SPEED_EXP = 2.0;
float GLIDE_STEER_SCALE = 0.60;
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
float MAX_TURN_RAD = 0.32; // Max turn per frame (~18 deg)


// --- Stability tuning (multi-agent robustness) ---
int ATTN_MIN = 2;
int ATTN_MAX = 6;
float ATTN_FACTOR = 0.25;
int COHESION_HYST_MS = 300;

// --- Social steering (neighbor interaction feel) ---
float ALIGN_WEIGHT = 1.15;      // Strength of velocity matching
float ALIGN_RADIUS = 220;       // How far to look for alignment (px)
float ALIGN_FALLOFF_EXP = 1.35; // Higher = nearer neighbors matter more
float ORBIT_RADIUS = 95;        // Within this, sidestep instead of head-on
float ORBIT_STRENGTH = 1.05;    // Lateral slip magnitude when very close
float ORBIT_NOISE = 0.32;       // 0..1 randomness to pick left/right

float MAX_STEER_MOUSE = 6.0;
float MAX_STEER_WALL = 6.0;
float MAX_STEER_SEP = 4.0;
float MAX_STEER_COH = 2.0;
float MAX_STEER_WANDER = 1.8;
float MAX_STEER_SWAY = 1.2;
float MAX_STEER_AGGRO = 8.0;
float MAX_TOTAL_STEER = 8.0;

float POST_CLAMP_STEER_SCALE = 0.4;

float JUMP_STEP_THR = 80;
float SEG_SNAP_THR = 80;

boolean DEBUG_MOOD = true;

boolean useWander = true;
boolean useWallAvoid = true;
boolean useWake = true;
boolean useFlow = true;
boolean useSeparation = true;
boolean useCohesion = true;
boolean usePursuit = true;

// --- Wake/flow environment influence (steering) ---
float FLOW_STEER_SCALE = 0.8;
float FLOW_MAX_FORCE = 2.0;
float FLOW_PERP_SCALE = 0.25; // 0 = only along heading, 1 = full lateral flow
float WAKE_STEER_SCALE = 1.0;
float WAKE_MAX_FORCE = 2.0;

// --- Wake field: cheap "fluid" upgrades (advection + ambient current) ---
// Advection makes dye/wake get carried by flow (streaks/curls instead of foggy blur).
boolean useWakeAdvection = true;
float wakeAdvectStrength = 1.0; // "cells per frame" scale (higher = faster transport)
int wakeAdvectSteps = 1;        // 1 = cheapest, 2 = nicer (RK2 / midpoint)
float wakeClamp = 8.0;          // cap wake intensity to avoid runaway blobs (<=0 disables)

// Ambient current prevents the water from feeling dead when wake is low.
boolean useAmbientCurrent = true;
float ambientCurrentStrength = 0.18; // in grid-cells per frame (small!)
float ambientCurrentScale = 0.06;    // noise spatial scale in grid space
float ambientCurrentTime = 0.10;     // noise time scale

// --- User wake shaping: "ghost waves" + "impact" ---
float USER_WAKE_SOFT_SPEED_THR = 0.6;  // minimal mouse speed to emit soft disturbance
float USER_WAKE_SOFT_RADIUS = 120;
float USER_WAKE_SOFT_AMOUNT = 0.35;    // multiplied by userDeposit and speed factor
float USER_WAKE_HIT_RADIUS = 70;
float USER_WAKE_HIT_AMOUNT = 1.00;     // multiplied by userDeposit

// --- Bioluminescent palette (configurable) ---
float JELLY_ALPHA = 120;
color JELLY_CALM = color(5, 242, 219);
color JELLY_SHY = color(233, 173, 157); // #E9AD9D
color JELLY_AGGRO = color(5, 242, 219);
color JELLY_GLOW_START = color(5, 242, 175); // #05F2AF
color JELLY_GLOW_END = color(0, 138, 89); // #008A59
// Dominant/teal glow variety (start closer to white)
color JELLY_AGGRO_GLOW_START = color(255, 255, 255); // #FFFFFF
color JELLY_AGGRO_GLOW_MID = color(5, 242, 175); // #05F2AF
color JELLY_AGGRO_GLOW_END = color(0, 138, 89); // #008A59
color JELLY_SHY_GLOW_START = color(253, 242, 226); // #FDF2E2 (center)
color JELLY_SHY_GLOW_MID = color(247, 188, 151); // #F7BC97 (halo accent)
color JELLY_SHY_GLOW_END = color(227, 192, 155); // #E3C09B (outer)
color JELLY_SHY_CORE_DARK = color(244, 175, 132); // #F4AF84 (core)
float JELLY_GLOW_SHIFT_SPEED = 0.25; // slower, calmer pulse
float JELLY_GLOW_MATCH_THR = 30;

float JELLY_CORE_DARK_SCALE = 0.22;
float JELLY_CORE_ALPHA_MULT = 0.65;
float JELLY_HEAD_LIGHTEN = 0.22;
float JELLY_TAIL_DARKEN = 0.32;
float JELLY_TAIL_ALPHA_FALLOFF = 0.6;
float JELLY_SIZE_MIN = 0.85;
float JELLY_SIZE_MAX = 1.15;
float JELLY_GLOW_MULT = 2.4;
float JELLY_SMALL_GLOW_MULT = 1.7;
float JELLY_SMALL_SHY_GLOW_SCALE = 0.75;
float JELLY_SMALL_CORE_ALPHA_SCALE = 1.25;
float JELLY_SMALL_STROKE_WEIGHT = 1.35;
float JELLY_SMALL_TAIL_ALPHA_FALLOFF = 0.9;

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
ArrayList<ArrayList<Gusano>> spatialGridPool = new ArrayList<ArrayList<Gusano>>();
// Cell size should be >= max interaction radius (cohesion/pursuit). Adjust as needed.
float gridCellSize = 260;
