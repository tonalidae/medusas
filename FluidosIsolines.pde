// ============================================================
// FluidoIsolines.pde
// Isoline delegate for Fluido (marching squares + smooth curveVertex rings)
// ============================================================

class FluidoIsolines {
  final Fluido f;
  FluidoIsolines(Fluido f_) { f = f_; }

  void dibujarIsolinea(float lvl, float hScale) {
    ArrayList<Seg> segs = new ArrayList<Seg>();

    // Build segments via marching squares
    for (int i = 0; i < f.cols - 1; i++) {
      for (int j = 0; j < f.filas - 1; j++) {
        Particula p00 = f.particulas[i][j];
        Particula p10 = f.particulas[i + 1][j];
        Particula p11 = f.particulas[i + 1][j + 1];
        Particula p01 = f.particulas[i][j + 1];

        float a = (p00.y - p00.oy) * hScale;
        float b = (p10.y - p10.oy) * hScale;
        float c = (p11.y - p11.oy) * hScale;
        float d = (p01.y - p01.oy) * hScale;

        int idx = 0;
        if (a > lvl) idx |= 1;
        if (b > lvl) idx |= 2;
        if (c > lvl) idx |= 4;
        if (d > lvl) idx |= 8;

        if (idx == 0 || idx == 15) continue;

        float center = (a + b + c + d) * 0.25;

        // Edge intersections
        PVector AB = null, BC = null, CD = null, DA = null;

        if (edgeCross(a, b, lvl)) {
          float t = safeT((lvl - a) / (b - a));
          AB = new PVector(lerp(p00.x, p10.x, t), lerp(p00.y, p10.y, t));
        }
        if (edgeCross(b, c, lvl)) {
          float t = safeT((lvl - b) / (c - b));
          BC = new PVector(lerp(p10.x, p11.x, t), lerp(p10.y, p11.y, t));
        }
        if (edgeCross(c, d, lvl)) {
          float t = safeT((lvl - c) / (d - c));
          CD = new PVector(lerp(p11.x, p01.x, t), lerp(p11.y, p01.y, t));
        }
        if (edgeCross(d, a, lvl)) {
          float t = safeT((lvl - d) / (a - d));
          DA = new PVector(lerp(p01.x, p00.x, t), lerp(p01.y, p00.y, t));
        }

        switch (idx) {
        case 1:
        case 14:
          addSeg(segs, DA, AB);
          break;

        case 2:
        case 13:
          addSeg(segs, AB, BC);
          break;

        case 3:
        case 12:
          addSeg(segs, DA, BC);
          break;

        case 4:
        case 11:
          addSeg(segs, BC, CD);
          break;

        case 6:
        case 9:
          addSeg(segs, AB, CD);
          break;

        case 7:
        case 8:
          addSeg(segs, DA, CD);
          break;

        case 5:
        case 10:
          if (center > lvl) {
            addSeg(segs, DA, AB);
            addSeg(segs, BC, CD);
          } else {
            addSeg(segs, DA, CD);
            addSeg(segs, AB, BC);
          }
          break;

        default:
          break;
        }
      }
    }

    // Stitch into paths
    ArrayList<ArrayList<PVector>> paths = stitchSegmentsToPaths(segs);

    // Render with curveVertex (smooth)
    for (ArrayList<PVector> path : paths) {
      if (path.size() < 3) continue;

      boolean closed = isClosed(path);

      beginShape();
      noFill();

      if (closed) {
        PVector last = path.get(path.size() - 1);
        PVector first = path.get(0);
        PVector second = path.get(1);

        curveVertex(last.x, last.y);
        for (PVector p : path) curveVertex(p.x, p.y);
        curveVertex(first.x, first.y);
        curveVertex(second.x, second.y);
      } else {
        PVector first = path.get(0);
        PVector last  = path.get(path.size() - 1);

        curveVertex(first.x, first.y);
        for (PVector p : path) curveVertex(p.x, p.y);
        curveVertex(last.x, last.y);
      }

      endShape();
    }
  }

  // --- helpers for smooth contour tracing ---
  class Seg {
    PVector a, b;
    Seg(PVector a_, PVector b_) { a = a_; b = b_; }
  }

  boolean edgeCross(float v0, float v1, float lvl) {
    return (v0 > lvl) != (v1 > lvl);
  }

  float safeT(float t) {
    if (Float.isNaN(t)) return 0.5;
    return constrain(t, 0, 1);
  }

  void addSeg(ArrayList<Seg> segs, PVector p, PVector q) {
    if (p == null || q == null) return;
    if (p.dist(q) < 1e-6) return;
    segs.add(new Seg(p, q));
  }

  String keyOf(PVector p) {
    int qx = round(p.x * 1000.0);
    int qy = round(p.y * 1000.0);
    return qx + "," + qy;
  }

  ArrayList<ArrayList<PVector>> stitchSegmentsToPaths(ArrayList<Seg> segs) {
    ArrayList<ArrayList<PVector>> paths = new ArrayList<ArrayList<PVector>>();
    if (segs.isEmpty()) return paths;

    HashMap<String, ArrayList<Seg>> bucket = new HashMap<String, ArrayList<Seg>>();
    for (Seg s : segs) {
      String ka = keyOf(s.a);
      String kb = keyOf(s.b);
      if (!bucket.containsKey(ka)) bucket.put(ka, new ArrayList<Seg>());
      if (!bucket.containsKey(kb)) bucket.put(kb, new ArrayList<Seg>());
      bucket.get(ka).add(s);
      bucket.get(kb).add(s);
    }

    HashSet<Seg> used = new HashSet<Seg>();

    for (Seg start : segs) {
      if (used.contains(start)) continue;

      ArrayList<PVector> path = new ArrayList<PVector>();
      used.add(start);

      path.add(start.a.copy());
      path.add(start.b.copy());

      growPathForward(path, bucket, used);

      reverseList(path);
      growPathForward(path, bucket, used);
      reverseList(path);

      // remove duplicates
      for (int i = path.size() - 2; i >= 0; i--) {
        if (path.get(i).dist(path.get(i + 1)) < 1e-6) path.remove(i + 1);
      }

      paths.add(path);
    }

    return paths;
  }

  void growPathForward(ArrayList<PVector> path,
                      HashMap<String, ArrayList<Seg>> bucket,
                      HashSet<Seg> used) {

    while (true) {
      PVector end = path.get(path.size() - 1);
      String kEnd = keyOf(end);
      ArrayList<Seg> candidates = bucket.get(kEnd);
      if (candidates == null) break;

      Seg next = null;
      boolean endIsA = false;

      for (Seg s : candidates) {
        if (used.contains(s)) continue;
        if (keyOf(s.a).equals(kEnd)) { next = s; endIsA = true; break; }
        if (keyOf(s.b).equals(kEnd)) { next = s; endIsA = false; break; }
      }

      if (next == null) break;

      used.add(next);

      PVector other = endIsA ? next.b : next.a;
      path.add(other.copy());

      // close ring
      if (path.size() > 3 && keyOf(path.get(0)).equals(keyOf(path.get(path.size() - 1)))) {
        path.remove(path.size() - 1);
        break;
      }
    }
  }

  boolean isClosed(ArrayList<PVector> path) {
    if (path.size() < 4) return false;
    return path.get(0).dist(path.get(path.size() - 1)) < 0.75;
  }

  void reverseList(ArrayList<PVector> list) {
    for (int i = 0, j = list.size() - 1; i < j; i++, j--) {
      PVector tmp = list.get(i);
      list.set(i, list.get(j));
      list.set(j, tmp);
    }
  }
}
