// ============================================================
// jellyfish_fluid.pde (MAIN)
// - Imports + globals
// - setup(), draw(), mouse handlers
// - utilities (reiniciarGusanos)
//
// IMPROVED BEHAVIOR SYSTEM:
// 1. Personality presets - reduces parameter complexity
// 2. Visual feedback - color tints show arousal/attitude/stress
// 3. Hysteresis - prevents mode flip-flopping
// 4. Gradual transitions - lonely mode and exit are smooth
// 5. Spatial partitioning - O(N) instead of O(N²) neighbor queries
// 6. Bravery system - group courage affects scare accumulation
// 7. Escape choreography - jellyfish swim away before fading
// ============================================================

import java.util.HashMap;
import java.util.HashSet;

ArrayList<Gusano> gusanos;
Fluido fluido;  // Nuevo sistema de fluido
SpatialGrid spatialGrid;  // Spatial partitioning for performance
PersonalityPresets personalityPresets;  // Instance for personality system
int numGusanos = 12;
int numSegmentos = 30;
float velocidad = 6;
float suavidad = 0.15;
float pointDensityMul = 1.0;  // scales per-gusano point count to keep perf OK with many gusanos


// --- Gusanos delayed spawn + exit/fade control ---
boolean gusanosSpawned = false;     // ya aparecieron?
boolean spawnArmed = false;         // hay un spawn programado?
int spawnDueMs = 0;                // momento en ms cuando deben aparecer

int lastInteractionMs = 0;         // última interacción del usuario
boolean exitArmed = false;          // estamos en modo salida?
int exitStartMs = 0;               // inicio del fade-out
final int spawnDelayMs = 1000;      // 1 segundo después de la última interacción
final int idleToExitMs = 12000;     // sin interacción => empiezan a irse (MUCHO más largo)
final int fadeOutMs = 1200;         // duración del desvanecimiento (ajusta)

// NEW: Two-stage idle behavior
final int idleToLonelyMs = 4500;    // jellyfish start wandering away
final int lonelyToExitMs = 3500;    // if STILL idle, fade out
boolean lonelyMode = false;          // intermediate state

// "Scared" exit: very strong user interaction can trigger an immediate exit
float scare = 0.0;                  // accumulates with intense input, decays over time
boolean scaredExit = false;         // if true, they keep leaving even if you keep interacting

// NEW: Track time since scared exit to allow return
int scaredExitCompleteMs = 0;
final int calmBeforeReturnMs = 8000; // 8s of calm = they come back

// Tuning: require sustained harsh interaction (~1 minute)
final float scareThreshold = 1.25;  // threshold to trigger exit
final float scareGain = 0.12;       // was 0.38 - much slower accumulation
final float scareDecay = 0.985;     // decay rate when not interacting

// --- NEW: low-pass mouse intensity + scare drive filter ---
float intensitySmoothed = 0.0;     
final float intensityFollow = 0.18; // qué tan rápido sigue (sube si quieres más reactivo)

// ScareDrive filtra el input del scare (un spike no sube todo)
float scareDrive = 0.0;             // 0..1
final float scareDriveFollow = 0.08; //

// Cooldown más agresivo cuando te alejas o estás suave
final float scareCoolFar   = 0.965; 
final float scareCoolGentle= 0.972; 
float gusanosAlpha = 0.0;           // multiplicador global de alpha (0..1)

// Mouse behavior tracking
boolean mouseStill = false;
int mouseStillStartMs = 0;
final int mouseStillThresholdMs = 800; // hovering still = calming presence
float scareProximityMul = 0.0;         // proximity-based threat multiplier

// Mouse history for smoothness calculation
ArrayList<PVector> mouseHistory = new ArrayList<PVector>();
final int mouseHistorySize = 8;

// Performance: cached values for debug overlay
float cachedAvgBravery = 0;
float cachedAvgArousal = 0;

float t = 0;

float boundsInset = 260;

color bgDark = color(5, 3, 10);

// Palettes
color p1Head = color(255, 255, 150);
color p1Tail = color(20, 100, 50);

color p2Head = color(200, 230, 255);
color p2Tail = color(100, 40, 180);


// color new one orange red gradient
color p3Head = color(255, 100, 50);
color p3Tail = color(150, 20, 10);
void setup() {
  size(1280, 800);
  stroke(0, 66);
  background(bgDark);
  smooth(8);

  fluido = new Fluido(40, 35, 25);  // Reduced from (60, 50, 20) for better performance
  
  // Initialize spatial partitioning grid
  spatialGrid = new SpatialGrid(0, 0, width, height, 150);
  
  // Initialize personality presets (instance, not static)
  personalityPresets = new PersonalityPresets();

  gusanos = new ArrayList<Gusano>();   // existe la lista, pero VACÍA
  gusanosSpawned = false;
  spawnArmed = false;
  exitArmed = false;
  gusanosAlpha = 0;

  pointDensityMul = constrain(3.5 / max(1.0, (float)numGusanos), 0.25, 0.80);  // Optimized density
}


void registrarInteraccion() {
  registrarInteraccion(0.25);
}

void registrarInteraccion(float intensidad) {
  int now = millis();
  // Si aún no han aparecido: re-lanza el temporizador siempre
  if (!gusanosSpawned) {
    // NEW: If they left scared, require calm period before returning
    if (scaredExitCompleteMs > 0) {
      if ((now - scaredExitCompleteMs) > calmBeforeReturnMs) {
        // Enough calm time: allow return
        scaredExitCompleteMs = 0;
        scare = 0;
        spawnArmed = true;
        spawnDueMs = now + spawnDelayMs;
      } else {
        // Still too soon: gentle interaction resets the timer to halfway
        if (intensidad < 0.25) {
          scaredExitCompleteMs = now - (calmBeforeReturnMs / 2);
        }
      }
      return;
    }
    
    spawnArmed = true;
    spawnDueMs = now + spawnDelayMs;
    return;
  }
  // Ya existen
  lastInteractionMs = now;
  // NEW: Reset lonely mode
  if (lonelyMode) {
    lonelyMode = false;
    for (Gusano g : gusanos) {
      // Restore social behavior from stored original values
      g.rangoSocial = g.rangoSocialOriginal;
      g.wanderMul = g.wanderMulOriginal;
      g.frecuenciaCambio = g.frecuenciaCambioOriginal;
    }
  }

  // Si estaban saliendo por INACTIVIDAD, una nueva interacción los "calma" y cancela la salida.
  // Si están saliendo por "miedo", NO cancelamos.
  if (exitArmed && !scaredExit) {
    exitArmed = false;
    gusanosAlpha = 1.0;
  }

if (!exitArmed) {
  intensidad = constrain(intensidad, 0, 1);

  boolean near = scareNearGate(mouseX, mouseY);

  // scareDrive filtra el input: si no estás "near", drive tiende a 0
  float driveTarget = near ? intensidad : 0.0;
  scareDrive = lerp(scareDrive, driveTarget, scareDriveFollow);
  
  // Much faster decay when not actively threatening
  float coolRate = (scareDrive > 0.2) ? scareDecay : 0.965;
  scare *= coolRate;
  
  // Only accumulate with sustained drive
  if (scareDrive > 0.25) {  // Buffer zone
    // Average bravery affects how quickly the group gets scared
    float avgBravery = 0.5;
    if (gusanos.size() > 0) {
      float sumBravery = 0;
      for (Gusano g : gusanos) sumBravery += g.scareResistance;
      avgBravery = sumBravery / gusanos.size();    }
    
    // Apply proximity multiplier (closer = more threatening)
    float effectiveGain = scareGain * (1.0 - avgBravery * 0.5) * scareProximityMul;
    scare = min(1.5, scare + scareDrive * effectiveGain);
  }
  
  if (scare >= scareThreshold) {
    scaredExit = true;
    exitArmed = true;
    exitStartMs = now;
  }
}
  
}
void draw() {
  background(bgDark);
  t += PI / 20;
  
  // Update fluid less frequently for better performance
  if (frameCount % 2 == 0) {
    fluido.actualizar();
  }
  fluido.dibujar();
  
  // NEW: Draw tension warning (only shows at higher scare levels)
  if (gusanosSpawned && !exitArmed && scare > 0.60) { // was 0.35 - much later warning
    drawTensionVignette();
  }

  int now = millis();
  // 1) Spawn delayed: solo después de 1000ms SIN nuevas interacciones
  if (!gusanosSpawned) {
    if (spawnArmed && now >= spawnDueMs) {
      reiniciarGusanos();           // crea gusanos aquí
      gusanosSpawned = true;
      spawnArmed = false;
      lastInteractionMs = now;
      gusanosAlpha = 1.0;
      
      // NEW: Reset scare/intensity on spawn (fresh start)
      scare = 0.0;
      scareDrive = 0.0;
      intensitySmoothed = 0.0;
    }
  } else {

    // (A) Micro-limpieza de scare mientras no están saliendo
    if (!exitArmed) {
      if (scare < 0.001) scare = 0;
      if (scareDrive < 0.001) scareDrive = 0;
    }    // (B) Si ya existen y el usuario deja de interactuar, activa modo salida (MUCHO más tarde)
    int idleMs = now - lastInteractionMs;
    if (!lonelyMode && idleMs > idleToLonelyMs) {
      lonelyMode = true;
      // Signal to jellyfish: reduce cohesion, wander more (with individual timing)
      for (int i = 0; i < gusanos.size(); i++) {
        Gusano g = gusanos.get(i);
        // Store original values before modifying
        g.rangoSocialOriginal = g.rangoSocial;
        g.wanderMulOriginal = g.wanderMul;
        g.frecuenciaCambioOriginal = g.frecuenciaCambio;
        
        // Individual timing offset based on personality and index
        float offset = i * 80 + g.userAttitude * 200; // curious ones leave later
        g.lonelyTransitionStart = now + (int)offset;
      }
    }
    
    // Gradual lonely transition for each jellyfish
    if (lonelyMode) {
      for (Gusano g : gusanos) {
        if (now >= g.lonelyTransitionStart && g.lonelyBlend < 1.0) {
          g.lonelyBlend += 0.008; // smooth transition over ~2 seconds
          g.lonelyBlend = min(1.0, g.lonelyBlend);
          
          // Interpolate parameters
          g.rangoSocial = lerp(g.rangoSocialOriginal, g.rangoSocialOriginal * 0.65, g.lonelyBlend);
          g.wanderMul = lerp(g.wanderMulOriginal, g.wanderMulOriginal * 1.45, g.lonelyBlend);
          g.frecuenciaCambio = lerp(g.frecuenciaCambioOriginal, g.frecuenciaCambioOriginal * 0.70, g.lonelyBlend);
        }
      }
    }
    
    if (!exitArmed && lonelyMode && idleMs > (idleToLonelyMs + lonelyToExitMs)) {
      scaredExit = false;
      exitArmed = true;
      exitStartMs = now;
    }    // (C) Fade-out mientras salen
    if (exitArmed) {
      float u = constrain((now - exitStartMs) / (float)fadeOutMs, 0, 1);
      u = u*u*(3.0 - 2.0*u);     // smoothstep
      
      // Add escape choreography: jellyfish swim away from center before fading
      float escapePhase = constrain(u * 2.0, 0, 1); // first half of fade
      for (Gusano g : gusanos) {
        if (escapePhase < 1.0) {
          // Push away from center
          float cx = width / 2;
          float cy = height / 2;
          if (g.segmentos != null && g.segmentos.size() > 0) {
            Segmento head = g.segmentos.get(0);
            float dx = head.x - cx;
            float dy = head.y - cy;
            float dist = sqrt(dx*dx + dy*dy);
            if (dist > 0) {
              float escapeForce = (scaredExit ? 4.5 : 2.5) * escapePhase;
              head.x += (dx / dist) * escapeForce;
              head.y += (dy / dist) * escapeForce;
            }
          }
        }
      }
      
      gusanosAlpha = 1.0 - u;// Cuando ya es invisible: limpiar y volver al estado inicial
      if (gusanosAlpha <= 0.01) {
        gusanos.clear();
        gusanosSpawned = false;
        spawnArmed = false;
        exitArmed = false;
        gusanosAlpha = 0.0;
        
        // NEW: If it was a scared exit, mark the time
        if (scaredExit) {
          scaredExitCompleteMs = now;
          scaredExit = false; // reset flag
        }
      }
    } else {
      gusanosAlpha = 1.0;
    }
  }  // Dibujo de gusanos (si existen)
  blendMode(ADD);
  
  // Update spatial grid for neighbor queries - only every other frame
  if (gusanosSpawned && frameCount % 2 == 0) {
    spatialGrid.clear();
    for (Gusano g : gusanos) {
      spatialGrid.insert(g);
    }
  }
  
  for (Gusano gusano : gusanos) {
    gusano.actualizar();
    gusano.dibujarForma();
  }
  
  blendMode(BLEND);
    // Draw debug overlay if enabled
  if (showDebug) {
    drawDebugOverlay();
  }
  
  // Draw interaction cursor feedback
  if (gusanosSpawned) {
    drawInteractionCursor();
  }
}

// Visual tension feedback: red vignette warning when scare builds up
void drawTensionVignette() {
  // Map scare intensity: 0.60 → scareThreshold becomes 0 → 1
  float intensity = constrain(map(scare, 0.60, scareThreshold, 0, 1), 0, 1);
  intensity = pow(intensity, 1.5); // nonlinear ramp for dramatic buildup
  
  pushStyle();
  noStroke();
  
  // 12-step radial gradient from edges inward
  int steps = 12;
  for (int i = 0; i < steps; i++) {
    float t = i / (float)steps;
    float alpha = intensity * 45 * (1.0 - t);
    fill(180, 20, 10, alpha);
    
    float inset = t * 180;
    rect(inset, inset, width - inset*2, height - inset*2);
  }
  popStyle();
}

// Optional debug overlay - press 'd' to toggle
boolean showDebug = false;

void drawDebugOverlay() {
  // Cache expensive calculations every 10 frames
  if (frameCount % 10 == 0) {
    cachedAvgBravery = getAvgBravery();
    cachedAvgArousal = getAvgArousal();
  }
  
  pushStyle();
  fill(255, 200);
  textAlign(LEFT, TOP);
  textSize(12);
  
  float y = 20;
  text("DEBUG MODE (press 'd' to hide)", 10, y); y += 20;
  text("Scare: " + nf(scare, 1, 2) + " / " + scareThreshold, 10, y); y += 15;
  text("Scare Drive: " + nf(scareDrive, 1, 2), 10, y); y += 15;
  text("Jellyfish: " + gusanos.size(), 10, y); y += 15;
  text("Lonely Mode: " + lonelyMode, 10, y); y += 15;
  text("Exit Armed: " + exitArmed + (scaredExit ? " (SCARED)" : ""), 10, y); y += 15;
  
  if (gusanos.size() > 0) {
    y += 10;
    text("Avg Bravery: " + nf(cachedAvgBravery, 1, 2), 10, y); y += 15;
    text("Avg Arousal: " + nf(cachedAvgArousal, 1, 2), 10, y); y += 15;
  }
  
  popStyle();
}

float getAvgBravery() {
  if (gusanos.size() == 0) return 0;
  float sum = 0;
  for (Gusano g : gusanos) sum += g.scareResistance;
  return sum / gusanos.size();
}

float getAvgArousal() {
  if (gusanos.size() == 0) return 0;
  float sum = 0;
  for (Gusano g : gusanos) sum += g.arousal;
  return sum / gusanos.size();
}

void keyPressed() {
  if (key == 'd' || key == 'D') {
    showDebug = !showDebug;
  }
}

void mouseDragged() {
  mouseStill = false; // reset calm state
  
  // Calculate drag velocity to determine if it's harsh
  float dragV = dist(mouseX, mouseY, pmouseX, pmouseY);
  float dragIntensity = constrain(dragV / 25.0, 0, 1); // faster threshold than mouseMoved
  dragIntensity = pow(dragIntensity, 0.85); // steeper curve
  
  // NEW: Differentiate drag direction - smooth vs erratic
  float smoothness = calculateDragSmoothness();
  
  // Dragging (with button held) uses the actual drag velocity
  // Slow smooth drag = gentle water sculpting (low threat)
  // Fast erratic drag = chasing/aggressive (high threat)
  float scareIntensity = max(0.15, dragIntensity * (1.0 - smoothness * 0.5));
  
  intensitySmoothed = max(intensitySmoothed, dragIntensity);
  registrarInteraccion(scareIntensity);

  // Stronger, directional water push when dragging
  float dx = mouseX - pmouseX;
  float dy = mouseY - pmouseY;
  
  // Use directional perturbation if available, else fallback to radial
  if (dragV > 0.5) {
    fluido.perturbar(mouseX, mouseY, 95, 6.5);
    // Add directional component via multiple offset points
    fluido.perturbar(mouseX - dx * 0.3, mouseY - dy * 0.3, 60, 4.0);
  } else {
    fluido.perturbar(mouseX, mouseY, 95, 6.5);
  }
}

void mousePressed() {
  // Single clicks are gentle pokes - not scary
  intensitySmoothed = max(intensitySmoothed, 0.35);
  registrarInteraccion(0.15); // same as gentle hover

  fluido.perturbar(mouseX, mouseY, 50, 3.0);
}

void mouseMoved() {
  // Calculate velocity
  float mouseV = dist(mouseX, mouseY, pmouseX, pmouseY);
  
  // Detect if mouse is still (hovering)
  if (mouseV < 2.0) { // very slow movement
    if (!mouseStill) {
      mouseStill = true;
      mouseStillStartMs = millis();
    }
  } else {
    mouseStill = false;
  }
  
  // Hovering still for a while = calming, reduces scare
  if (mouseStill && gusanosSpawned && (millis() - mouseStillStartMs) > mouseStillThresholdMs) {
    scare *= 0.95; // actively calm them down
  }
  
  // 1) raw intensity por velocidad (for fluid visualization only)
  float raw = constrain(mouseV / 40.0, 0, 1);

  // 2) curva no lineal: micro-movimientos cuentan más
  raw = pow(raw, 0.70);

  // 3) low-pass: elimina jitter del trackpad
  intensitySmoothed = lerp(intensitySmoothed, raw, intensityFollow);

  // NEW: Differentiate interaction intensity by movement speed
  // Very slow = curious attraction, medium = neutral, fast = mild alertness
  float interactionIntensity = (mouseV < 8.0) ? 0.05 : 0.08;
  
  // Mouse movement is always a gentle "pat" - never triggers scare
  // Just hovering/moving = friendly interaction
  if (!gusanosSpawned) {
    registrarInteraccion(0.15); // gentle constant for spawn
  } else {
    registrarInteraccion(interactionIntensity);
  }
  // Perturbación del fluido: gentle ripples follow the mouse
  if (frameCount % 4 == 0) {
    float ramp = constrain(frameCount / 90.0, 0, 1);
    ramp = ramp * ramp * (3.0 - 2.0 * ramp);

    float strength = 1.5 * ramp * (0.25 + 0.75 * intensitySmoothed);
    fluido.perturbar(mouseX, mouseY, 30, strength);
  }
}
void reiniciarGusanos() {
  scare = 0.0;
  scaredExit = false;
  gusanosAlpha = 1.0;
  lonelyMode = false;
  lastInteractionMs = millis();
  
  // Calm the water before spawning to prevent agitation
  fluido.calmarAgua(0.05);
  
  gusanos.clear(); // Clear any existing jellyfish first
  
  // Natural ocean spawning: create 2-3 loose clusters (current convergences)
  int numClusters = (int)random(2, 4);
  ArrayList<PVector> clusterCenters = new ArrayList<PVector>();
  
  for (int c = 0; c < numClusters; c++) {
    float cx = random(boundsInset + 100, width - boundsInset - 100);
    float cy = random(boundsInset + 100, height - boundsInset - 100);
    clusterCenters.add(new PVector(cx, cy));
  }
  
  for (int i = 0; i < numGusanos; i++) {
    // Pick a cluster (weighted towards first clusters = denser)
    int clusterIdx = (int)min(pow(random(1), 1.5) * numClusters, numClusters - 1);
    PVector center = clusterCenters.get(clusterIdx);
    
    // Scatter around cluster center (exponential falloff)
    float radius = randomGaussian() * 120 + 80; // cluster spread
    float angle = random(TWO_PI);
    float x = constrain(center.x + cos(angle) * radius, boundsInset, width - boundsInset);
    float y = constrain(center.y + sin(angle) * radius, boundsInset, height - boundsInset);

    // Alternate color palettes
    color head = (i % 2 == 0) ? p1Head : p2Head;
    color tail = (i % 2 == 0) ? p1Tail : p2Tail;
    
    // Create jellyfish with base personality
    Gusano g = new Gusano(x, y, head, tail, i);
    
    // Mark spawn frame for grace period
    g.spawnFrame = frameCount;
    
    // Apply a personality preset with 30% variation for diversity
    GusanoPersonality personality = personalityPresets.getRandom(0.3);
    personality.applyTo(g);
    
    gusanos.add(g);
  }
}

// Gate espacial: el scare solo acumula si el mouse está cerca del fluido
// o cerca de la cabeza de algún gusano.
boolean scareNearGate(float mx, float my) {
  // Zone 1: Very close to jellyfish = threat zone (reduced radius)
  float threatR = 120; // reduced from 220
  float threat2 = threatR * threatR;
  
  for (Gusano g : gusanos) {
    if (g.segmentos == null || g.segmentos.size() == 0) continue;
    Segmento head = g.segmentos.get(0);
    float dx = mx - head.x;
    float dy = my - head.y;
    float dist2 = dx*dx + dy*dy;
    
    if (dist2 <= threat2) {
      // Closer = more threatening (scaled 0.5 to 1.0)
      float distNorm = sqrt(dist2) / threatR;
      scareProximityMul = map(distNorm, 0, 1, 1.0, 0.5);
      return true;
    }
  }
  
  // Zone 2: Near fluid = mild awareness zone
  float w = fluido.cols * fluido.espaciado;
  float h = fluido.filas * fluido.espaciado;
  float margin = 80; // reduced from 140
  
  boolean nearFluid =
    (mx >= fluido.offsetX - margin) && (mx <= fluido.offsetX + w + margin) &&
    (my >= fluido.offsetY - margin) && (my <= fluido.offsetY + h + margin);
  
  if (nearFluid) {
    scareProximityMul = 0.3; // low threat multiplier
    return true;
  }
    scareProximityMul = 0.0;
  return false;
}

// Calculate drag smoothness based on mouse history
float calculateDragSmoothness() {
  // Only update when dragging for better performance
  if (mousePressed) {
    mouseHistory.add(new PVector(mouseX, mouseY));
    if (mouseHistory.size() > mouseHistorySize) {
      mouseHistory.remove(0);
    }
  }
  
  if (mouseHistory.size() < 3) return 1.0; // not enough data = assume smooth
  
  // Calculate direction changes (less angular change = smoother)
  float totalAngleChange = 0;
  for (int i = 1; i < mouseHistory.size() - 1; i++) {
    PVector p0 = mouseHistory.get(i - 1);
    PVector p1 = mouseHistory.get(i);
    PVector p2 = mouseHistory.get(i + 1);
    
    PVector v1 = PVector.sub(p1, p0);
    PVector v2 = PVector.sub(p2, p1);
    
    if (v1.mag() > 0 && v2.mag() > 0) {
      float angle = PVector.angleBetween(v1, v2);
      totalAngleChange += abs(angle);
    }
  }
  
  // Map to 0..1 (smooth = 1, erratic = 0)
  float avgAngleChange = totalAngleChange / max(1, mouseHistory.size() - 2);
  return constrain(1.0 - (avgAngleChange / HALF_PI), 0, 1);
}

// Visual feedback cursor
void drawInteractionCursor() {
  if (!gusanosSpawned) return;
  
  pushStyle();
  noFill();
  strokeWeight(2);
  
  // Color based on threat level
  if (mouseStill) {
    stroke(100, 255, 150, 180); // green = calming
    ellipse(mouseX, mouseY, 30, 30);
    ellipse(mouseX, mouseY, 20, 20);
  } else if (scareDrive > 0.5) {
    stroke(255, 100, 80, 200); // red = threatening
    ellipse(mouseX, mouseY, 40 + scareDrive * 20, 40 + scareDrive * 20);
  } else {
    stroke(200, 220, 255, 150); // blue = neutral
    ellipse(mouseX, mouseY, 25, 25);
  }
  popStyle();
}