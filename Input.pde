void keyPressed() {
  if (key == 'o' || key == 'O') {
    debugObjetivos = !debugObjetivos;
  } else if (key == 'p' || key == 'P') {
    debugStateChanges = !debugStateChanges;
  } else if (key == 's' || key == 'S') {
    debugSteering = !debugSteering;
  } else if (key == 'm' || key == 'M') {
    debugFlowMean = !debugFlowMean;
  } else if (key == 'b' || key == 'B') {
    debugNeighborStats = !debugNeighborStats;
  } else if (key == 'u' || key == 'U') {
    debugMoodStats = !debugMoodStats;
  } else if (key == 'n' || key == 'N') {
    debugSteeringNeighbors = !debugSteeringNeighbors;
  } else if (key == 'd' || key == 'D') {
    DEBUG_MOOD = !DEBUG_MOOD;
  } else if (key == 'h' || key == 'H') {
    debugHelp = !debugHelp;
  } else if (key == 'j' || key == 'J') {
    debugJellyMotion = !debugJellyMotion;
  } else if (key == 'c' || key == 'C') {
    debugCycles = !debugCycles;
    println("[DEBUG] debugCycles=" + debugCycles);
  } else if (key == '+' || key == '=') {
    numGusanos = min(32, numGusanos + 1);
    reiniciarGusanos();
  } else if (key == '-' || key == '_') {
    numGusanos = max(1, numGusanos - 1);
    reiniciarGusanos();
  } else if (key == 'q' || key == 'Q') {
    showHead = !showHead;
  } else if (key == '1') {
    useFlow = !useFlow;
  } else if (key == '2') {
    useWake = !useWake;
  } else if (key == '3') {
    useCohesion = !useCohesion;
  } else if (key == '4') {
    useSeparation = !useSeparation;
  } else if (key == '5') {
    useWander = !useWander;
  } else if (key == '6') {
    useWallAvoid = !useWallAvoid;
  } else if (key == 'l' || key == 'L') {
    debugBiologicalVectors = !debugBiologicalVectors;
    println("[DEBUG] debugBiologicalVectors=" + debugBiologicalVectors);
  } else if (key == 'w' || key == 'W') {
    debugWake = !debugWake;
    println("[DEBUG] debugWake=" + debugWake);
  } else if (key == 'f' || key == 'F') {
    debugWakeVectors = !debugWakeVectors;
    println("[DEBUG] debugWakeVectors=" + debugWakeVectors);
  } else if (key == 'i' || key == 'I') {
    showWaterInteraction = !showWaterInteraction;
    println("[DEBUG] showWaterInteraction=" + showWaterInteraction);
  } else if (key == 't' || key == 'T') {
    showWaterTex = !showWaterTex;
    println("[DEBUG] showWaterTex=" + showWaterTex);
  } else if (key == 'y' || key == 'Y') {
    useWaterFrames = !useWaterFrames;
    if (useWaterFrames && !waterFramesAvailable) {
      useWaterFrames = false;
      warnMissingWaterFrames();
    }
    println("[DEBUG] useWaterFrames=" + useWaterFrames);
  }
}
