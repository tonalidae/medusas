// ============================================================
// jellyfish_fluid.pde (MAIN)
// - Imports + globals
// - setup(), draw(), mouse handlers
// - utilities (reiniciarGusanos)
// ============================================================

import java.util.HashMap;
import java.util.HashSet;

ArrayList<Gusano> gusanos;
Fluido fluido;  // Nuevo sistema de fluido
int numGusanos = 5;
int numSegmentos = 30;
float velocidad = 6;
float suavidad = 0.15;


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

// "Scared" exit: very strong user interaction can trigger an immediate exit
float scare = 0.0;                  // accumulates with intense input, decays over time
boolean scaredExit = false;         // if true, they keep leaving even if you keep interacting

// Tuning: less hair-trigger
final float scareThreshold = 1.25;  // subir un poco
final float scareGain = 0.38;       // bajar un poco


final float scareDecay = 0.985;

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

  fluido = new Fluido(60, 50, 20);

  gusanos = new ArrayList<Gusano>();   // existe la lista, pero VACÍA
  gusanosSpawned = false;
  spawnArmed = false;
  exitArmed = false;
  gusanosAlpha = 0;
}


void registrarInteraccion() {
  registrarInteraccion(0.25);
}

void registrarInteraccion(float intensidad) {
  int now = millis();

  // Si aún no han aparecido: re-lanza el temporizador siempre
  if (!gusanosSpawned) {
    spawnArmed = true;
    spawnDueMs = now + spawnDelayMs;
    return;
  }

  // Ya existen
  lastInteractionMs = now;

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

  // Enfriamiento más rápido si estás lejos o si la interacción es gentil
  if (!near) {
    scare *= scareCoolFar;
  } else if (intensidad < 0.20) {
    scare *= scareCoolGentle;
  } else {
    scare *= scareDecay;
  }

  // Acumulación solo con drive (sostenido)
  scare = min(1.5, scare + scareDrive * scareGain);

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

  fluido.actualizar();
  fluido.dibujar();

  int now = millis();

  // 1) Spawn delayed: solo después de 1000ms SIN nuevas interacciones
  if (!gusanosSpawned) {
    if (spawnArmed && now >= spawnDueMs) {
      reiniciarGusanos();           // crea gusanos aquí
      gusanosSpawned = true;
      spawnArmed = false;
      lastInteractionMs = now;
      gusanosAlpha = 1.0;
    }
  } else {

    // (A) Micro-limpieza de scare mientras no están saliendo
    if (!exitArmed) {
      if (scare < 0.001) scare = 0;
      if (scareDrive < 0.001) scareDrive = 0;
    }

    // (B) Si ya existen y el usuario deja de interactuar, activa modo salida (MUCHO más tarde)
    if (!exitArmed && (now - lastInteractionMs) > idleToExitMs) {
      scaredExit = false;
      exitArmed = true;
      exitStartMs = now;
    }

    // (C) Fade-out mientras salen
    if (exitArmed) {
      float u = constrain((now - exitStartMs) / (float)fadeOutMs, 0, 1);
      u = u*u*(3.0 - 2.0*u);     // smoothstep
      gusanosAlpha = 1.0 - u;

      // Cuando ya es invisible: limpiar y volver al estado inicial
      if (gusanosAlpha <= 0.01) {
        gusanos.clear();
        gusanosSpawned = false;
        spawnArmed = false;
        exitArmed = false;
        gusanosAlpha = 0.0;
      }
    } else {
      gusanosAlpha = 1.0;
    }
  }

  // Dibujo de gusanos (si existen)
  blendMode(ADD);
  for (Gusano gusano : gusanos) {
    gusano.actualizar();
    gusano.dibujarForma();
  }
  blendMode(BLEND);
}
void mouseDragged() {
  intensitySmoothed = max(intensitySmoothed, 0.85);
  registrarInteraccion(1.0);

  fluido.perturbar(mouseX, mouseY, 80, 5.0);
}

void mousePressed() {
  // bump: que clicks se sientan consistentes con la intensidad suavizada
  intensitySmoothed = max(intensitySmoothed, 0.55);
  registrarInteraccion(0.7);

  fluido.perturbar(mouseX, mouseY, 50, 3.0);
}

void mouseMoved() {
  // 1) raw intensity por velocidad
  float mouseV = dist(mouseX, mouseY, pmouseX, pmouseY);
  float raw = constrain(mouseV / 40.0, 0, 1);

  // 2) curva no lineal: micro-movimientos cuentan más
  raw = pow(raw, 0.70);

  // 3) low-pass: elimina jitter del trackpad
  intensitySmoothed = lerp(intensitySmoothed, raw, intensityFollow);


  registrarInteraccion(intensitySmoothed);

  // Perturbación del fluido: usa intensidadSmoothed (opcional pero recomendado)
  if (frameCount % 3 == 0) {
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
  lastInteractionMs = millis();
  for (int i = 0; i < numGusanos; i++) {
    float x = random(boundsInset, width - boundsInset);
    float y = random(boundsInset, height - boundsInset);

    color head = (i % 2 == 0) ? p1Head : p2Head;
    color tail = (i % 2 == 0) ? p1Tail : p2Tail;

    gusanos.add(new Gusano(x, y, head, tail, i));
  }
}

// Gate espacial: el scare solo acumula si el mouse está cerca del fluido
// o cerca de la cabeza de algún gusano.
boolean scareNearGate(float mx, float my) {
  // 1) Cerca del rectángulo del fluido (+margen)
  float w = fluido.cols * fluido.espaciado;
  float h = fluido.filas * fluido.espaciado;

  float margin = 140; // ajusta: más grande = gate más permisivo
  boolean nearFluid =
    (mx >= fluido.offsetX - margin) && (mx <= fluido.offsetX + w + margin) &&
    (my >= fluido.offsetY - margin) && (my <= fluido.offsetY + h + margin);

  if (nearFluid) return true;

  // 2) Cerca de algún gusano (cabeza)
  float nearR = 220; 
  float r2 = nearR * nearR;

  for (Gusano g : gusanos) {
    if (g.segmentos == null || g.segmentos.size() == 0) continue;
    Segmento head = g.segmentos.get(0);
    float dx = mx - head.x;
    float dy = my - head.y;
    if (dx*dx + dy*dy <= r2) return true;
  }

  return false;
}