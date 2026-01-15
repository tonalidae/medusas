ArrayList<Gusano> gusanos;
int numGusanos = 4;
int numSegmentos = 30;
float velocidad = 4;
float suavidad = 0.15;

float t = 0;

void setup() {
  size(1280, 800);
  stroke(0, 66); // Cambiado a negro con transparencia
  background(255); // Cambiado a fondo blanco
  
  // Inicializar los gusanos
  gusanos = new ArrayList<Gusano>();
  
  // Crear varios gusanos en posiciones aleatorias
  for (int i = 0; i < numGusanos; i++) {
    float x = random(200, width-200);
    float y = random(200, height-200);
    color c = color(0, 66); // Todos los gusanos son negros
    gusanos.add(new Gusano(x, y, c, i)); // Pasar el índice para personalizar
  }
}

void draw() {
  background(255); // Fondo blanco en cada frame
  t += PI / 20;
  
  // Actualizar y dibujar todos los gusanos
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
  int id; // Identificador único para cada gusano
  
  Gusano(float x, float y, color c, int id_) {
    segmentos = new ArrayList<Segmento>();
    colorGusano = c;
    id = id_;
    
    // Crear segmentos del gusano
    for (int i = 0; i < numSegmentos; i++) {
      segmentos.add(new Segmento(x, y));
    }
    
    // Establecer primer objetivo aleatorio
    objetivoX = random(100, width-100);
    objetivoY = random(100, height-100);
    cambioObjetivo = 0;
    frecuenciaCambio = random(80, 120); // Cada gusano tiene su propio ritmo
  }
  
  void actualizar() {
    // Cambiar dirección periódicamente o cuando está muy cerca del objetivo
    cambioObjetivo++;
    Segmento cabeza = segmentos.get(0);
    float distanciaAlObjetivo = dist(cabeza.x, cabeza.y, objetivoX, objetivoY);
    
    // Cambiar objetivo si ha pasado el tiempo o si está muy cerca del actual
    if (cambioObjetivo > frecuenciaCambio || distanciaAlObjetivo < 20) {
      nuevoObjetivo();
      cambioObjetivo = 0;
    }
    
    // Actualizar movimiento de la cabeza basado en objetivo aleatorio
    cabeza.seguir(objetivoX, objetivoY);
    cabeza.actualizar();
    
    // Pequeños ajustes aleatorios ocasionales en la dirección
    if (random(1) < 0.03) {
      objetivoX += random(-30, 30);
      objetivoY += random(-30, 30);
      objetivoX = constrain(objetivoX, 150, width-150);
      objetivoY = constrain(objetivoY, 150, height-150);
    }
    
    // Actualizar el resto de segmentos
    for (int i = 1; i < segmentos.size(); i++) {
      Segmento seg = segmentos.get(i);
      Segmento segAnterior = segmentos.get(i - 1);
      seg.seguir(segAnterior.x, segAnterior.y);
      seg.actualizar();
    }
  }
  
  void nuevoObjetivo() {
    // Generar nuevo objetivo en dirección similar pero no idéntica
    Segmento cabeza = segmentos.get(0);
    float anguloActual = atan2(objetivoY - cabeza.y, objetivoX - cabeza.x);
    float nuevoAngulo = anguloActual + random(-PI/3, PI/3);
    
    float distancia = random(100, 250);
    
    objetivoX = cabeza.x + cos(nuevoAngulo) * distancia;
    objetivoY = cabeza.y + sin(nuevoAngulo) * distancia;
    
    objetivoX = constrain(objetivoX, 100, width-100);
    objetivoY = constrain(objetivoY, 100, height-100);
  }
  
  void dibujarForma() {
    // Usar el color negro para todos los gusanos
    stroke(colorGusano);
    
    // Dibujar la forma alargada usando el sistema de segmentos
    for (int i = 10000; i > 0; i--) {
      // Calcular la posición vertical relativa en la forma
      float x_param = i % 200;
      float y_param = i / 43.0;
      
      // Calcular la posición Y final en la forma
      float k = 5 * cos(x_param / 14) * cos(y_param / 30);
      float e = y_param / 8 - 13;
      float d = sq(mag(k, e)) / 59 + 4;
      float py = d * 45;
      
      // Usar la posición vertical de la forma para determinar el segmento
      float minPY = 100;
      float maxPY = 400;
      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);
      
      // Encontrar el segmento basado en la posición vertical en la forma
      int segmentIndex = int(verticalProgression * (segmentos.size() - 1));
      Segmento seg = segmentos.get(segmentIndex);
      
      // Calcular posición interpolada entre segmentos
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
      
      // Dibujar el punto usando la posición del segmento correspondiente
      dibujarPuntoForma(x_param, y_param, x, y);
    }
    
    // Marcar la cabeza con negro más intenso
    stroke(0, 200); // Negro con mayor opacidad
    strokeWeight(4);
    point(segmentos.get(0).x, segmentos.get(0).y);
    strokeWeight(1);
  }
  
  void dibujarPuntoForma(float x, float y, float cx, float cy) {
    // AQUÍ ES DONDE PUEDES PERSONALIZAR LAS ECUACIONES PARA CADA GUSANO
    float k, e, d, q, px, py;
    float headOffset = 184;
    
    switch(id) {
      case 0:
        // Gusano 0 - Ecuación original
        k = 5 * cos(x / 14) * cos(y / 30);
        e = y / 8 - 13;
        d = sq(mag(k, e)) / 59 + 4;
        q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
        px = q + 0.9;
        py = d * 45;
        break;
        
      case 1:
        // Gusano 1 - Variación 1 (más ondulada)
        k = 6 * cos(x / 12) * cos(y / 25);
        e = y / 7 - 15;
        d = sq(mag(k, e)) / 50 + 3;
        q = - 2 * sin(atan2(k, e) * e) + k * (2 + 5 / d * sin(d * d - t * 1.5));
        px = q + 1.2;
        py = d * 40;
        break;
        
      case 2:
        // Gusano 2 - Variación 2 (más compacta)
        k = 4 * cos(x / 16) * cos(y / 35);
        e = y / 9 - 11;
        d = sq(mag(k, e)) / 65 + 5;
        q = - 4 * sin(atan2(k, e) * e) + k * (4 + 3 / d * sin(d * d - t * 2.5));
        px = q + 0.6;
        py = d * 50;
        break;
        
      case 3:
        // Gusano 3 - Variación 3 (más irregular)
        k = 7 * cos(x / 10) * cos(y / 20);
        e = y / 6 - 17;
        d = sq(mag(k, e)) / 45 + 2;
        q = - 5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
        px = q + 1.5;
        py = d * 35;
        break;
        
      default:
        // Para gusanos adicionales, usar ecuación base
        k = 5 * cos(x / 14) * cos(y / 30);
        e = y / 8 - 13;
        d = sq(mag(k, e)) / 59 + 4;
        q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
        px = q + 0.9;
        py = d * 45;
        break;
    }
    
    point(px + cx, py - headOffset + cy);
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
  
  void seguir(float targetX, float targetY) {
    float dx = targetX - x;
    float dy = targetY - y;
    angulo = atan2(dy, dx);
    
    float distancia = dist(x, y, targetX, targetY);
    
    // Siempre aplicar movimiento
    float fuerza = velocidad;
    if (distancia < 50) {
      fuerza = map(distancia, 0, 50, velocidad * 0.3, velocidad);
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
