// ============================================================
// Fluido.pde
// - class Fluido (physics + render helpers + isolines)
// ============================================================

class Fluido {
  int cols, filas;
  float espaciado;
  Particula[][] particulas;
  ArrayList<Resorte> resortes;

  float offsetX, offsetY;

  float rigidez = 0.035;
  float propagacion = 0.075; // balanced: natural spread with visible wakes
  float waveDrag = 0.075;     // medium damping: ripples persist but don't overwhelm
  float influenciaVel = 0.12; // reduced further: jellyfish swim more autonomously, less influenced by currents

  float[][] tmpVx;
  float[][] tmpVy;

  // --- per-frame render caches (computed once per dibujar()) ---
  float[][] hCache;      // height = (y - oy)
  float[][] gxCache;     // d(height)/dx
  float[][] gyCache;     // d(height)/dy
  float[][] slopeCache;  // sqrt(gx^2 + gy^2)
  // ----------------------------------------------------------

  // --- delegates (composition split; Fluido API stays the same) ---
  FluidoSim sim;
  FluidoPerturb perturb;
  FluidoRender render;
  FluidoIsolines isolines;


  Fluido(int c, int f, float esp) {
    cols = c;
    filas = f;
    espaciado = esp;

    float anchoMalla = cols * espaciado;
    float altoMalla  = filas * espaciado;

    offsetX = (width  - anchoMalla) / 2.0;
    offsetY = (height - altoMalla)  / 2.0;

    tmpVx = new float[cols][filas];
    tmpVy = new float[cols][filas];

    // render caches (updated once per frame in dibujar())
    hCache     = new float[cols][filas];
    gxCache    = new float[cols][filas];
    gyCache    = new float[cols][filas];
    slopeCache = new float[cols][filas];

    particulas = new Particula[cols][filas];
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < filas; j++) {
        float x = offsetX + i * espaciado;
        float y = offsetY + j * espaciado;
        particulas[i][j] = new Particula(x, y);
      }
    }

    resortes = new ArrayList<Resorte>();
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < filas; j++) {
        if (i < cols - 1) {
          resortes.add(new Resorte(particulas[i][j], particulas[i + 1][j], rigidez));
        }
        if (j < filas - 1) {
          resortes.add(new Resorte(particulas[i][j], particulas[i][j + 1], rigidez));
        }
        if (i < cols - 1 && j < filas - 1) {
          float kd = rigidez * 0.7;
          resortes.add(new Resorte(particulas[i][j],     particulas[i + 1][j + 1], kd));
          resortes.add(new Resorte(particulas[i + 1][j], particulas[i][j + 1],     kd));
        }
      }
    }

    // delegates
    sim = new FluidoSim(this);
    perturb = new FluidoPerturb(this);
    render = new FluidoRender(this);
    isolines = new FluidoIsolines(this);
  }


  void actualizar() {
    sim.actualizar();
  }

  void propagarOndas() {
    sim.propagarOndas();
  }

  void perturbar(float x, float y, float radio, float fuerza) {
    perturb.perturbar(x, y, radio, fuerza);
  }

  void perturbarDir(float x, float y, float radio, float dirX, float dirY, float fuerza) {
    perturb.perturbarDir(x, y, radio, dirX, dirY, fuerza);
  }

  void dibujar() {
    render.dibujar();
  }

  // Calm water velocity (used when jellyfish spawn)
  void calmarAgua(float factor) {
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < filas; j++) {
        // Reduce velocity
        particulas[i][j].vx *= factor;
        particulas[i][j].vy *= factor;
        
        // Fully reset particles to rest position (removes visual displacement)
        particulas[i][j].y = particulas[i][j].oy;
      }
    }
  }

  // ============================================================
  // OPTION 3: traced isolines + curveVertex (smooth rings)
  // (kept in file; not used by current dibujar() shading)
  // ============================================================
  void dibujarIsolinea(float lvl, float hScale) {
    isolines.dibujarIsolinea(lvl, hScale);
  }


  // Compute render-only field caches once per frame (used by dibujar())
  void actualizarCamposRender() {
    render.actualizarCamposRender();
  }

  // --- field sampling helpers for shading / refraction (render-only) ---
  float heightAt(int i, int j) {
    return render.heightAt(i, j);
  }

  float gradX(int i, int j) {
    return render.gradX(i, j);
  }

  float gradY(int i, int j) {
    return render.gradY(i, j);
  }

  float slopeMag(int i, int j) {
    return render.slopeMag(i, j);
  }

  // API methods (unchanged)
  PVector obtenerVelocidad(float x, float y) {
    float gx = (x - offsetX) / espaciado;
    float gy = (y - offsetY) / espaciado;

    int i0 = constrain(floor(gx), 0, cols - 1);
    int j0 = constrain(floor(gy), 0, filas - 1);
    int i1 = constrain(i0 + 1, 0, cols - 1);
    int j1 = constrain(j0 + 1, 0, filas - 1);

    float sx = gx - i0;
    float sy = gy - j0;

    Particula p00 = particulas[i0][j0];
    Particula p10 = particulas[i1][j0];
    Particula p01 = particulas[i0][j1];
    Particula p11 = particulas[i1][j1];

    float vx0 = lerp(p00.vx, p10.vx, sx);
    float vx1 = lerp(p01.vx, p11.vx, sx);
    float vy0 = lerp(p00.vy, p10.vy, sx);
    float vy1 = lerp(p01.vy, p11.vy, sx);

    return new PVector(lerp(vx0, vx1, sy) * influenciaVel,
                   lerp(vy0, vy1, sy) * influenciaVel);
  }

  float obtenerAltura(float x, float y) {
    float gx = (x - offsetX) / espaciado;
    float gy = (y - offsetY) / espaciado;

    int i0 = constrain(floor(gx), 0, cols - 1);
    int j0 = constrain(floor(gy), 0, filas - 1);
    int i1 = constrain(i0 + 1, 0, cols - 1);
    int j1 = constrain(j0 + 1, 0, filas - 1);

    float sx = gx - i0;
    float sy = gy - j0;

    float h00 = particulas[i0][j0].y - particulas[i0][j0].oy;
    float h10 = particulas[i1][j0].y - particulas[i1][j0].oy;
    float h01 = particulas[i0][j1].y - particulas[i0][j1].oy;
    float h11 = particulas[i1][j1].y - particulas[i1][j1].oy;

    float h0 = lerp(h00, h10, sx);
    float h1 = lerp(h01, h11, sx);
    return lerp(h0, h1, sy);
  }
}