// ============================================================
// GusanoPersonality.pde
// Preset personality system to reduce parameter complexity
// ============================================================

class GusanoPersonality {
  // Personality type
  String name;
  
  // Movement characteristics (grouped)
  float swimmingSpeed;      // base movement speed
  float agility;            // how quickly it turns (0..1)
  float wanderIntensity;    // how much it wanders vs moves purposefully
  
  // Social behavior (grouped)
  float sociability;        // how much it schools (0=loner, 1=very social)
  float personalSpace;      // preferred distance from others (0=cuddly, 1=distant)
  
  // Reactivity (grouped)
  float curiosity;          // attitude toward user (-1=fearful, 0=neutral, 1=curious)
  float sensitivity;        // how quickly arousal changes (0=calm, 1=reactive)
  float bravery;            // resistance to being scared (0=easily spooked, 1=bold)
  
  // Visual/physical
  float pulseStrength;      // swimming pulse intensity
  float bodyTension;        // how stiff/loose the body is
  
  GusanoPersonality(String name, float speed, float agility, float wander, 
                    float social, float space, float curiosity, 
                    float sensitivity, float bravery, 
                    float pulse, float tension) {
    this.name = name;
    this.swimmingSpeed = speed;
    this.agility = agility;
    this.wanderIntensity = wander;
    this.sociability = social;
    this.personalSpace = space;
    this.curiosity = curiosity;
    this.sensitivity = sensitivity;
    this.bravery = bravery;
    this.pulseStrength = pulse;
    this.bodyTension = tension;
  }
  
  // Apply this personality to a Gusano
  void applyTo(Gusano g) {
    // Movement parameters
    g.baseFreq = map(swimmingSpeed, 0, 1, 0.015, 0.028);  // Slower for natural breathing rhythm
    g.suavidadGiro = map(agility, 0, 1, 0.08, 0.25);
    g.wanderMul = map(wanderIntensity, 0, 1, 0.5, 1.8);
    g.frecuenciaCambio = map(wanderIntensity, 0, 1, 140, 70);
    
    // Social parameters
    g.socialMul = sociability;
    g.rangoSocial = 260 * sociability;
    g.rangoRepulsion = map(personalSpace, 0, 1, 40, 90);
    g.pesoSeparacion = map(personalSpace, 0, 1, 1.2, 2.8);
    g.pesoAlineacion = sociability * 1.5;
    g.pesoCohesion = sociability * 0.8;
    
    // Sync behavior
    g.syncStrength = sociability * 0.18;
    g.syncRange = 180 * sociability;
    
    // User interaction
    g.userAttitude = curiosity;
    g.userAttTarget = curiosity;
    g.scareResistance = bravery;
    
    // Arousal/reactivity
    g.arousalFollow = map(sensitivity, 0, 1, 0.06, 0.18);  // Reduced for smoother reactions
    g.arousalDecay = map(sensitivity, 0, 1, 0.985, 0.94);
    g.wUser = map(sensitivity, 0, 1, 0.35, 0.75);
    g.wSocial = map(sensitivity, 0, 1, 0.25, 0.55);
    
    // Physical appearance
    g.pulseAmp = map(pulseStrength, 0, 1, 0.9, 1.5);  // Reduced for gentler pulsing
    g.pulseK = map(bodyTension, 0, 1, 3.5, 6.0);  // Higher = sharper contractions, longer pauses
    g.suavidadCuerpo = map(bodyTension, 0, 1, 0.35, 0.15);
  }
  
  // Blend between two personalities (for variation)
  GusanoPersonality blendWith(GusanoPersonality other, float t) {
    return new GusanoPersonality(
      this.name + "/" + other.name,
      lerp(this.swimmingSpeed, other.swimmingSpeed, t),
      lerp(this.agility, other.agility, t),
      lerp(this.wanderIntensity, other.wanderIntensity, t),
      lerp(this.sociability, other.sociability, t),
      lerp(this.personalSpace, other.personalSpace, t),
      lerp(this.curiosity, other.curiosity, t),
      lerp(this.sensitivity, other.sensitivity, t),
      lerp(this.bravery, other.bravery, t),
      lerp(this.pulseStrength, other.pulseStrength, t),
      lerp(this.bodyTension, other.bodyTension, t)
    );
  }
}

// ============================================================
// Preset Personalities
// ============================================================

class PersonalityPresets {
  GusanoPersonality CURIOUS_DANCER;
  GusanoPersonality SHY_DRIFTER;
  GusanoPersonality BOLD_LEADER;
  GusanoPersonality NERVOUS_FOLLOWER;
  GusanoPersonality CALM_OBSERVER;
  GusanoPersonality PLAYFUL_EXPLORER;
  
  GusanoPersonality[] allPresets;
  
  PersonalityPresets() {
    // Curious Dancer: approaches user, graceful, social
    CURIOUS_DANCER = new GusanoPersonality(
      "Curious Dancer",
      0.6,   // speed: moderate
      0.7,   // agility: quite agile
      0.4,   // wander: purposeful
      0.8,   // sociability: loves company
      0.3,   // personal space: comfortable with closeness
      0.7,   // curiosity: drawn to user
      0.5,   // sensitivity: balanced
      0.6,   // bravery: fairly brave
      0.7,   // pulse: strong
      0.4    // tension: loose, flowing
    );
    
    // Shy Drifter: avoids user, floaty, somewhat social
    SHY_DRIFTER = new GusanoPersonality(
      "Shy Drifter",
      0.4,   // speed: slow
      0.3,   // agility: gentle turns
      0.7,   // wander: dreamy
      0.6,   // sociability: likes company but not too close
      0.6,   // personal space: needs distance
      -0.5,  // curiosity: fearful
      0.7,   // sensitivity: easily startled
      0.3,   // bravery: timid
      0.5,   // pulse: gentle
      0.3    // tension: very loose
    );
    
    // Bold Leader: confident, fast, leads the school
    BOLD_LEADER = new GusanoPersonality(
      "Bold Leader",
      0.8,   // speed: fast
      0.6,   // agility: decisive
      0.3,   // wander: direct
      0.7,   // sociability: social but independent
      0.5,   // personal space: average
      0.4,   // curiosity: neutral-curious
      0.4,   // sensitivity: steady
      0.9,   // bravery: very brave
      0.8,   // pulse: powerful
      0.7    // tension: tense, muscular
    );
    
    // Nervous Follower: reactive, tight schooling, easily stressed
    NERVOUS_FOLLOWER = new GusanoPersonality(
      "Nervous Follower",
      0.5,   // speed: moderate
      0.5,   // agility: average
      0.5,   // wander: balanced
      0.9,   // sociability: needs the group
      0.4,   // personal space: stays close to others
      -0.3,  // curiosity: slightly fearful
      0.8,   // sensitivity: very reactive
      0.2,   // bravery: easily spooked
      0.6,   // pulse: moderate
      0.5    // tension: medium
    );
    
    // Calm Observer: slow, independent, unbothered
    CALM_OBSERVER = new GusanoPersonality(
      "Calm Observer",
      0.3,   // speed: very slow
      0.4,   // agility: smooth
      0.8,   // wander: meandering
      0.3,   // sociability: loner
      0.8,   // personal space: likes distance
      0.1,   // curiosity: mildly interested
      0.2,   // sensitivity: unflappable
      0.8,   // bravery: calm courage
      0.4,   // pulse: weak
      0.2    // tension: relaxed
    );
    
    // Playful Explorer: quick, curious, medium social
    PLAYFUL_EXPLORER = new GusanoPersonality(
      "Playful Explorer",
      0.7,   // speed: quick
      0.8,   // agility: very agile
      0.6,   // wander: exploratory
      0.5,   // sociability: somewhat social
      0.5,   // personal space: average
      0.8,   // curiosity: very curious
      0.6,   // sensitivity: attentive
      0.7,   // bravery: brave
      0.7,   // pulse: energetic
      0.6    // tension: springy
    );
    
    allPresets = new GusanoPersonality[] {
      CURIOUS_DANCER,
      SHY_DRIFTER,
      BOLD_LEADER,
      NERVOUS_FOLLOWER,
      CALM_OBSERVER,
      PLAYFUL_EXPLORER
    };
  }
  
  // Get a random personality with optional variation
  GusanoPersonality getRandom(float variation) {
    GusanoPersonality base = allPresets[floor(random(allPresets.length))];
    
    if (variation > 0) {
      // Blend with a neighbor to create variety
      GusanoPersonality other = allPresets[floor(random(allPresets.length))];
      float t = random(variation);
      return base.blendWith(other, t);
    }
    
    return base;
  }
  
  // Get personality by name (for specific control)
  GusanoPersonality getByName(String name) {
    for (GusanoPersonality p : allPresets) {
      if (p.name.equals(name)) return p;
    }
    return CURIOUS_DANCER; // default
  }
}
