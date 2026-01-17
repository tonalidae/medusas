

// ============================================================
// FluidosSim.pde
// Simulation delegate for Fluido (physics update)
//
// IMPORTANT:
// Java/Processing cannot split a single class across multiple .pde files.
// So we use composition: Fluido owns a FluidoSim (this class) and delegates.
//
// This file is a scaffold meant to compile immediately.
// Next step: MOVE the code from Fluido.actualizar() and Fluido.propagarOndas()
// into FluidoSim.actualizar() / FluidoSim.propagarOndas() below.
// ============================================================
// ============================================================
// FluidosSim.pde
// Simulation delegate for Fluido (physics update)
//
// Java/Processing cannot split a single class across multiple .pde files.
// So we use composition: Fluido owns a FluidoSim (this class) and delegates.
//
// This file now contains the migrated logic from:
//   - Fluido.actualizar()
//   - Fluido.propagarOndas()
// ============================================================

class FluidoSim {
  final Fluido f;
  FluidoSim(Fluido f_) { f = f_; }

  // Entry point called by Fluido.actualizar()
  void actualizar() {
    // Same behavior as the old Fluido.actualizar()
    int sub = 2;
    for (int s = 0; s < sub; s++) {
      for (Resorte r : f.resortes) r.actualizar();

      for (int i = 0; i < f.cols; i++) {
        for (int j = 0; j < f.filas; j++) {
          f.particulas[i][j].actualizar();
        }
      }

      propagarOndas();
    }
  }

  // Propagation / diffusion step (cheap, not a full fluid solver)
  void propagarOndas() {
    // Smooth/propagate BOTH vx and vy so wakes actually move through the medium.
    for (int i = 1; i < f.cols - 1; i++) {
      for (int j = 1; j < f.filas - 1; j++) {
        Particula p = f.particulas[i][j];

        float vx = p.vx;
        float vy = p.vy;

        float avx = (f.particulas[i - 1][j].vx + f.particulas[i + 1][j].vx +
                     f.particulas[i][j - 1].vx + f.particulas[i][j + 1].vx) * 0.25;
        float avy = (f.particulas[i - 1][j].vy + f.particulas[i + 1][j].vy +
                     f.particulas[i][j - 1].vy + f.particulas[i][j + 1].vy) * 0.25;

        float nvx = vx + (avx - vx) * f.propagacion;
        float nvy = vy + (avy - vy) * f.propagacion;

        // keep the old damping behavior but apply it to both components
        float damp = (1.0 - f.waveDrag);
        nvx *= damp;
        nvy *= damp;

        f.tmpVx[i][j] = nvx;
        f.tmpVy[i][j] = nvy;
      }
    }

    for (int i = 1; i < f.cols - 1; i++) {
      for (int j = 1; j < f.filas - 1; j++) {
        f.particulas[i][j].vx = f.tmpVx[i][j];
        f.particulas[i][j].vy = f.tmpVy[i][j];
      }
    }
  }

  // -----------------------------
  // Small helpers (optional)
  // -----------------------------

  // World -> grid index helper (safe)
  int ixFromX(float x) {
    float lx = x - f.offsetX;
    return constrain(int(lx / f.espaciado), 0, f.cols - 1);
  }

  int iyFromY(float y) {
    float ly = y - f.offsetY;
    return constrain(int(ly / f.espaciado), 0, f.filas - 1);
  }

  // Safe access (only if you want to simplify code)
  Particula p(int i, int j) {
    return f.particulas[i][j];
  }
}

// Compatibility alias: if you already instantiated `new FluidosSim(this)`
// in Fluido.pde, this keeps it compiling.
class FluidosSim extends FluidoSim {
  FluidosSim(Fluido f_) { super(f_); }
}