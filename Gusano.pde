// ============================================================
// Gusano.pde
// ============================================================

class Gusano {
  ArrayList<Segmento> segmentos;
  color colorCabeza;
  color colorCola;

  float objetivoX, objetivoY;
  float cambioObjetivo;
  float frecuenciaCambio;
  int id;

  Gusano(float x, float y, color cHead, color cTail, int id_) {
    segmentos = new ArrayList<Segmento>();
    colorCabeza = cHead;
    colorCola = cTail;
    id = id_;

    for (int i = 0; i < numSegmentos; i++) {
      segmentos.add(new Segmento(x, y));
    }

    objetivoX = random(100, width-100);
    objetivoY = random(100, height-100);
    cambioObjetivo = 0;
    frecuenciaCambio = random(80, 120);
  }

  void actualizar() {
    cambioObjetivo++;
    Segmento cabeza = segmentos.get(0);
    float distanciaAlObjetivo = dist(cabeza.x, cabeza.y, objetivoX, objetivoY);

    if (cambioObjetivo > frecuenciaCambio || distanciaAlObjetivo < 20) {
      nuevoObjetivo();
      cambioObjetivo = 0;
    }

    PVector velocidadFluido = fluido.obtenerVelocidad(cabeza.x, cabeza.y);
    float alturaFluido =
      fluido.obtenerAltura(cabeza.x, cabeza.y);

    float objetivoConFluidoX = objetivoX + velocidadFluido.x * 15;
    float objetivoConFluidoY = objetivoY + velocidadFluido.y * 15;
    objetivoConFluidoY -= alturaFluido * 0.5;

    cabeza.seguir(objetivoConFluidoX, objetivoConFluidoY);
    cabeza.actualizar();

    if (random(1) < 0.03) {
      objetivoX += random(-30, 30);
      objetivoY += random(-30, 30);
      objetivoX = constrain(objetivoX, 150, width-150);
      objetivoY = constrain(objetivoY, 150, height-150);
    }

    for (int i = 1; i < segmentos.size(); i++) {
      Segmento seg = segmentos.get(i);
      Segmento segAnterior = segmentos.get(i - 1);

      PVector velFluidoSeg = fluido.obtenerVelocidad(seg.x, seg.y);
      float alturaFluidoSeg = fluido.obtenerAltura(seg.x, seg.y);

      float targetX = segAnterior.x + velFluidoSeg.x * 10;
      float targetY = segAnterior.y + velFluidoSeg.y * 10 - alturaFluidoSeg * 0.3;

      seg.seguir(targetX, targetY);
      seg.actualizar();
    }
  }

  void nuevoObjetivo() {
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
    strokeWeight(1);

    for (int i = 10000; i > 0; i--) {
      float x_param = i % 200;
      float y_param = i / 43.0;

      float k = 5 * cos(x_param / 14) * cos(y_param / 30);
      float e = y_param / 8 - 13;
      float d = sq(mag(k, e)) / 59 + 4;
      float py = d * 45;

      float minPY = 100;
      float maxPY = 400;
      float verticalProgression = constrain(map(py, minPY, maxPY, 0, 1), 0, 1);

      color cPoint = lerpColor(colorCabeza, colorCola, verticalProgression);
      stroke(cPoint, 120);

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

      PVector velFluidoPunto = fluido.obtenerVelocidad(x, y);
      float alturaFluidoPunto = fluido.obtenerAltura(x, y);

      x += velFluidoPunto.x * 0.5;
      y += velFluidoPunto.y * 0.5 - alturaFluidoPunto * 0.2;

      dibujarPuntoForma(x_param, y_param, x, y);
    }

    stroke(colorCabeza, 220);
    strokeWeight(4);
    point(segmentos.get(0).x, segmentos.get(0).y);
    strokeWeight(1);
  }

  void dibujarPuntoForma(float x, float y, float cx, float cy) {
    float k, e, d, q, px, py;
    float headOffset = 184;

    switch(id) {
    case 0:
      k = 5 * cos(x / 14) * cos(y / 30);
      e = y / 8 - 13;
      d = sq(mag(k, e)) / 59 + 4;
      q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
      px = q + 0.9;
      py = d * 45;
      break;

    case 1:
      k = 6 * cos(x / 12) * cos(y / 25);
      e = y / 7 - 15;
      d = sq(mag(k, e)) / 50 + 3;
      q = - 2 * sin(atan2(k, e) * e) + k * (2 + 5 / d * sin(d * d - t * 1.5));
      px = q + 1.2;
      py = d * 40;
      break;

    case 2:
      k = 4 * cos(x / 16) * cos(y / 35);
      e = y / 9 - 11;
      d = sq(mag(k, e)) / 65 + 5;
      q = - 4 * sin(atan2(k, e) * e) + k * (4 + 3 / d * sin(d * d - t * 2.5));
      px = q + 0.6;
      py = d * 50;
      break;

    case 3:
      k = 7 * cos(x / 10) * cos(y / 20);
      e = y / 6 - 17;
      d = sq(mag(k, e)) / 45 + 2;
      q = - 5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
      px = q + 1.5;
      py = d * 35;
      break;

    case 4:
      k = 7 * cos(x / 10) * cos(y / 3);
      e = y / 5 - 17;
      d = sq(mag(k, e)) / 45 + 2;
      q = - 5 * sin(atan2(k, e) * e) + k * (5 + 6 / d * sin(d * d - t * 3));
      px = q + 1.5;
      py = d * 35;
      break;

    default:
      k = 5 * cos(x / 14) * cos(y / 30);
      e = y / 8 - 13;
      d = sq(mag(k, e)) / 59 + 4;
      q = - 3 * sin(atan2(k, e) * e) + k * (3 + 4 / d * sin(d * d - t * 2));
      px = q + 1.6;
      py = d * 45;
      break;
    }

    point(px + cx, py - headOffset + cy);
  }
}