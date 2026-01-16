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
int numGusanos = 4;
int numSegmentos = 30;
float velocidad = 4;
float suavidad = 0.15;

float t = 0;

color bgDark = color(5, 3, 10);

// Palettes
color p1Head = color(255, 255, 150);
color p1Tail = color(20, 100, 50);

color p2Head = color(200, 230, 255);
color p2Tail = color(100, 40, 180);

void setup() {
  size(1280, 800);
  stroke(0, 66);
  background(bgDark);
  smooth(8);

  // Inicializar el sistema de fluido
  fluido = new Fluido(60, 50, 20); // Ancho, alto, espaciado de la malla

  // Inicializar los gusanos
  gusanos = new ArrayList<Gusano>();

  // Crear varios gusanos en posiciones aleatorias
  for (int i = 0; i < numGusanos; i++) {
    float x = random(200, width-200);
    float y = random(200, height-200);

    color head = (i % 2 == 0) ? p1Head : p2Head;
    color tail = (i % 2 == 0) ? p1Tail : p2Tail;

    gusanos.add(new Gusano(x, y, head, tail, i));
  }
}

void draw() {
  background(bgDark);
  t += PI / 20;

  fluido.actualizar();
  fluido.dibujar();

  blendMode(ADD);

  for (Gusano gusano : gusanos) {
    gusano.actualizar();
    gusano.dibujarForma();
  }

  blendMode(BLEND);
}

void mouseDragged() {
  fluido.perturbar(mouseX, mouseY, 80, 5.0);
}

void mousePressed() {
  fluido.perturbar(mouseX, mouseY, 50, 3.0);
}

void mouseMoved() {
  if (frameCount % 3 == 0) {
    fluido.perturbar(mouseX, mouseY, 30, 1.5);
  }
}

void reiniciarGusanos() {
  gusanos.clear();
  for (int i = 0; i < numGusanos; i++) {
    float x = random(200, width-200);
    float y = random(200, height-200);

    color head = (i % 2 == 0) ? p1Head : p2Head;
    color tail = (i % 2 == 0) ? p1Tail : p2Tail;

    gusanos.add(new Gusano(x, y, head, tail, i));
  }
}