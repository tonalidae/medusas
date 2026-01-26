// --- Spatial grid helpers ---
long cellKey(int cx, int cy) {
  return (((long)cx) << 32) ^ (cy & 0xffffffffL);
}

void rebuildSpatialGrid() {
  for (ArrayList<Gusano> bucket : spatialGrid.values()) {
    bucket.clear();
    spatialGridPool.add(bucket);
  }
  spatialGrid.clear();
  if (gusanos == null) return;
  for (Gusano g : gusanos) {
    if (g == null || g.segmentos == null || g.segmentos.size() == 0) continue;
    Segmento h = g.segmentos.get(0);
    int cx = floor(h.x / gridCellSize);
    int cy = floor(h.y / gridCellSize);
    long key = cellKey(cx, cy);
    ArrayList<Gusano> bucket = spatialGrid.get(key);
    if (bucket == null) {
      if (spatialGridPool.size() > 0) {
        int last = spatialGridPool.size() - 1;
        bucket = spatialGridPool.remove(last);
      } else {
        bucket = new ArrayList<Gusano>();
      }
      spatialGrid.put(key, bucket);
    }
    bucket.add(g);
  }
}

void queryNeighbors(float x, float y, ArrayList<Gusano> out) {
  out.clear();
  int cx = floor(x / gridCellSize);
  int cy = floor(y / gridCellSize);
  for (int oy = -1; oy <= 1; oy++) {
    for (int ox = -1; ox <= 1; ox++) {
      long key = cellKey(cx + ox, cy + oy);
      ArrayList<Gusano> bucket = spatialGrid.get(key);
      if (bucket != null) out.addAll(bucket);
    }
  }
}

ArrayList<Gusano> queryNeighbors(float x, float y) {
  ArrayList<Gusano> out = new ArrayList<Gusano>();
  queryNeighbors(x, y, out);
  return out;
}
