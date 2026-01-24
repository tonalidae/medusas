ArrayList<Gusano> gusanos;
int numGusanos = 6;
int numSegmentos = 30;

float timeScale = 0.001;
float t = 0;

void setup() {
  size(1280, 800);
  stroke(0, 66); 
  background(255); 

  gusanos = new ArrayList<Gusano>();

  for (int i = 0; i < numGusanos; i++) {
    float x = random(200, width-200);
    float y = random(200, height-200);
    color c = color(0, 66); 
    gusanos.add(new Gusano(x, y, c, i)); 
  }
}

void draw() {
  background(255); 
  t = millis() * timeScale;

  for (Gusano gusano : gusanos) {
    gusano.actualizar();
    gusano.dibujarForma();
  }
}

class Gusano {
  ArrayList<Segmento> segmentos;
  color colorGusano;
  float objetivoX, objetivoY;
  float cambioObjetivo;
  float frecuenciaCambio;
  int id; 
  float noiseOffset; 
  
  // NEW: Current angle of the head (for smooth turning)
  float headAngle = 0; 

  Gusano(float x, float y, color c, int id_) {
    segmentos = new ArrayList<Segmento>();
    colorGusano = c;
    id = id_;
    noiseOffset = random(1000); 

    for (int i = 0; i < numSegmentos; i++) {
      segmentos.add(new Segmento(x, y));
    }

    objetivoX = random(100, width-100);
    objetivoY = random(100, height-100);
    cambioObjetivo = 0;
    
    // FIX 1: Longer decision times (Graceful arcs)
    frecuenciaCambio = random(200, 400); 
  }

  void actualizar() {
    float headPulse = sin(t + id * TWO_PI/numGusanos);
    // Slight speed boost for head to simulate "pulling"
    float headSpeed = map(headPulse, -1, 1, 6.5, 2.0); 

    cambioObjetivo++;
    Segmento cabeza = segmentos.get(0);
    float distanciaAlObjetivo = dist(cabeza.x, cabeza.y, objetivoX, objetivoY);

    if (cambioObjetivo > frecuenciaCambio || distanciaAlObjetivo < 40) {
      nuevoObjetivo();
      cambioObjetivo = 0;
    }

    // FIX 2: WALL REPULSION (Steering away from walls instead of hitting them)
    float margin = 100;
    if (cabeza.x < margin) objetivoX += 5;
    if (cabeza.x > width - margin) objetivoX -= 5;
    if (cabeza.y < margin) objetivoY += 5;
    if (cabeza.y > height - margin) objetivoY -= 5;

    // Head Turbulence
    float headTurbulenceX = map(noise(t * 0.5, 0, noiseOffset), 0, 1, -1.5, 1.5);
    float headTurbulenceY = map(noise(t * 0.5, 100, noiseOffset), 0, 1, -1.5, 1.5);

    // FIX 3: INERTIA / SMOOTH TURNING
    // Instead of calling cabeza.seguir() immediately, we calculate the desired angle
    // and smoothly interpolate towards it.
    float targetX = objetivoX + headTurbulenceX;
    float targetY = objetivoY + headTurbulenceY;
    
    float dx = targetX - cabeza.x;
    float dy = targetY - cabeza.y;
    float desiredAngle = atan2(dy, dx);
    
    // Smoothly rotate headAngle towards desiredAngle (The "0.05" is the turning speed/weight)
    // We use a custom lerpAngle function to handle the -PI to PI wrap-around
    headAngle = lerpAngle(headAngle, desiredAngle, 0.05); 
    
    // Manual movement of head based on smooth angle
    cabeza.angulo = headAngle;
    cabeza.x += cos(headAngle) * headSpeed;
    cabeza.y += sin(headAngle) * headSpeed;
    cabeza.actualizar(); // Constrain logic

    // Update Body
    for (int i = 1; i < segmentos.size(); i++) {
      Segmento seg = segmentos.get(i);
      Segmento segAnterior = segmentos.get(i - 1);
      
      float waveDelay = i * 0.15; 
      float bodyPulse = sin((t - waveDelay) + id * TWO_PI/numGusanos);
      float bodySpeed = map(bodyPulse, -1, 1, 6, 2.0);
      
      float turbulenceX = map(noise(t * 0.5, i * 0.1, noiseOffset), 0, 1, -1.5, 1.5);
      float turbulenceY = map(noise(t * 0.5, i * 0.1 + 100, noiseOffset), 0, 1, -1.5, 1.5);
      
      seg.seguir(segAnterior.x + turbulenceX, segAnterior.y + turbulenceY, bodySpeed);
      seg.actualizar();
    }
  }

  void nuevoObjetivo() {
    Segmento cabeza = segmentos.get(0);
    // Find a new point within a cone in front of the jellyfish (prevent 180 flips)
    float currentHeading = atan2(objetivoY - cabeza.y, objetivoX - cabeza.x);
    float turnAngle = random(-PI/2, PI/2); // Turn up to 90 degrees left or right
    
    float distance = random(200, 400); // Longer swim distances

    objetivoX = cabeza.x + cos(currentHeading + turnAngle) * distance;
    objetivoY = cabeza.y + sin(currentHeading + turnAngle) * distance;
    
    // Keep target somewhat on screen
    objetivoX = constrain(objetivoX, 100, width-100);
    objetivoY = constrain(objetivoY, 100, height-100);
  }
  
  // Helper for smooth rotation (handles the jump between PI and -PI)
  float lerpAngle(float a, float b, float t) {
    float diff = b - a;
    if (diff > PI) diff -= TWO_PI;
    if (diff < -PI) diff += TWO_PI;
    return a + diff * t;
  }

  void dibujarForma() {
    stroke(colorGusano);
    float baseOffset = 120; // Adjusted per previous discussion

    beginShape(POINTS);
    for (int i = 5000; i > 0; i--) {
      float x_param = i % 200;
      float y_param = i / 35.0;

      float k, e, d, q, px, py;

      switch(id % 4) { // Safer modulo in case you have > 4 worms
        case 0:
          k = 5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 13;
          d = sq(mag(k, e)) / 59 + 4;
          q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
          py = d * 45;
          break;
        case 1:
          k = 6 * cos((x_param*1.1) / 12) * cos((y_param*0.9) / 25);
          e = (y_param*0.9) / 7 - 15;
          d = sq(mag(k, e)) / 50 + 3;
          q = - 2 * sin(atan2(k, e) * e) + k * (2 + 5 / d * sin(d * d - t * 1.5));
          py = d * 40;
          break;
        case 2:
          k = 4 * cos((x_param*0.9) / 16) * cos((y_param*1.1) / 35);
          e = (y_param*1.1) / 9 - 11;
          d = sq(mag(k, e)) / 65 + 5;
          q = - 4 * sin(atan2(k, e) * e) + k * (4 + 3 / d * sin(d * d - t * 2.5));
          py = d * 50;
          break;
        case 3:
          k = 7 * cos((x_param*1.2) / 10) * cos((y_param*0.8) / 20);
          e = (y_param*0.8) / 6 - 17;
          d = sq(mag(k, e)) / 45 + 2;
          q = - 5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
          py = d * 35;
          break;
        default: // Fallback
          k = 5 * cos(x_param / 14) * cos(y_param / 30);
          e = y_param / 8 - 13;
          d = sq(mag(k, e)) / 59 + 4;
          q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
          py = d * 45;
          break;
      }

      float minPY = 100;
      float maxPY = 400;
      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);
      
      float dragOffset = verticalProgression * 1.5; 
      float localPulse = map(sin(t + id * TWO_PI/numGusanos - dragOffset), -1, 1, -10, 10);
      float localBreath = map(localPulse, -10, 10, 0.7, 1.3);

      px = q * localBreath;

      int segmentIndex = int(verticalProgression * (segmentos.size() - 1));
      Segmento seg = segmentos.get(segmentIndex);
      float segmentProgression = (verticalProgression * (segmentos.size() - 1)) - segmentIndex;
      float x, y;

      if (segmentIndex < segmentos.size() - 1) {
        Segmento nextSeg = segmentos.get(segmentIndex + 1);
        x = lerp(seg.x, nextSeg.x, segmentProgression);
        y = lerp(seg.y, nextSeg.y, segmentProgression);
      } else {
        x = seg.x;
        y = seg.y;
      }

      vertex(px + x, py - (baseOffset + localPulse) + y);
    }
    endShape();

    stroke(0, 200);
    strokeWeight(4);
    point(segmentos.get(0).x, segmentos.get(0).y);
    strokeWeight(1);
  }
}

class Segmento {
  float x, y;
  float angulo;

  Segmento(float x_, float y_) {
    x = x_;
    y = y_;
    angulo = 0;
  }

  void seguir(float targetX, float targetY, float speed) {
    float dx = targetX - x;
    float dy = targetY - y;
    angulo = atan2(dy, dx);

    float distancia = dist(x, y, targetX, targetY);

    float fuerza = speed;
    if (distancia < 50) {
      fuerza = map(distancia, 0, 50, speed * 0.3, speed);
    }

    x += cos(angulo) * fuerza;
    y += sin(angulo) * fuerza;
  }

  void actualizar() {
    x = constrain(x, 50, width - 50);
    y = constrain(y, 50, height - 50);
  }
}

// Controles para ajustar parámetros
//void keyPressed() {
//  if (key == '+' || key == '=') {
//    numGusanos = min(8, numGusanos + 1);
//    reiniciarGusanos();
//  } else if (key == '-' || key == '_') {
//    numGusanos = max(1, numGusanos - 1);
//    reiniciarGusanos();
//  } else if (key == ' ') {
//    // Espacio para reiniciar
//    reiniciarGusanos();
//  }
//}

void reiniciarGusanos() {
  gusanos.clear();
  for (int i = 0; i < numGusanos; i++) {
    float x = random(200, width-200);
    float y = random(200, height-200);
    color c = color(0, 66); // Todos los gusanos son negros
    gusanos.add(new Gusano(x, y, c, i));
  }
}

