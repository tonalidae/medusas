// ============================================================
// SpatialGrid.pde
// Simple spatial partitioning to optimize O(N²) social calculations
// ============================================================

class SpatialGrid {
  int cols, rows;
  float cellSize;
  float offsetX, offsetY;
  float gridWidth, gridHeight;
  HashMap<Integer, ArrayList<Gusano>> cells;
  
  SpatialGrid(float x, float y, float w, float h, float cellSize) {
    this.offsetX = x;
    this.offsetY = y;
    this.gridWidth = w;
    this.gridHeight = h;
    this.cellSize = cellSize;
    this.cols = ceil(w / cellSize);
    this.rows = ceil(h / cellSize);
    this.cells = new HashMap<Integer, ArrayList<Gusano>>();
  }
  
  void clear() {
    cells.clear();
  }
  
  int getKey(int col, int row) {
    return row * cols + col;
  }
  
  void insert(Gusano g) {
    if (g.segmentos == null || g.segmentos.size() == 0) return;
    Segmento head = g.segmentos.get(0);
    
    int col = constrain(floor((head.x - offsetX) / cellSize), 0, cols - 1);
    int row = constrain(floor((head.y - offsetY) / cellSize), 0, rows - 1);
    int key = getKey(col, row);
    
    if (!cells.containsKey(key)) {
      cells.put(key, new ArrayList<Gusano>());
    }
    cells.get(key).add(g);
  }
  
  ArrayList<Gusano> getNeighbors(Gusano g, float radius) {
    ArrayList<Gusano> neighbors = new ArrayList<Gusano>();
    if (g.segmentos == null || g.segmentos.size() == 0) return neighbors;
    
    Segmento head = g.segmentos.get(0);
    int col = floor((head.x - offsetX) / cellSize);
    int row = floor((head.y - offsetY) / cellSize);
    
    // Check cells in radius
    int cellRadius = ceil(radius / cellSize);
    for (int dr = -cellRadius; dr <= cellRadius; dr++) {
      for (int dc = -cellRadius; dc <= cellRadius; dc++) {
        int c = col + dc;
        int r = row + dr;
        if (c >= 0 && c < cols && r >= 0 && r < rows) {
          int key = getKey(c, r);
          if (cells.containsKey(key)) {
            neighbors.addAll(cells.get(key));
          }
        }
      }
    }
    
    return neighbors;
  }
}
