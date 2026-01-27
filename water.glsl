// Save as data/water.glsl
#ifdef GL_ES
precision mediump float;
#endif

uniform float time;
uniform vec2 resolution;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    
    // Spatial scale for the ripples
    float s = 10.0; 
    
    // Wave math mimicking your original CPU sin() loops
    float t1 = time * 0.5;
    float t2 = time * 0.3;
    
    float w1 = sin(uv.x * s + t1);
    float w2 = sin(uv.y * s - t2);
    float w3 = sin((uv.x + uv.y) * s * 0.5 + t1);
    
    float v = (w1 + w2 + w3) * 0.33 + 0.5;
    
    // Color: Deep Blue with low alpha (transparency)
    // This allows the #050008 background to show through
    vec3 waterColor = vec3(0.05, 0.15, 0.25) * v;
    float alpha = 0.1 + 0.2 * v; 

    gl_FragColor = vec4(waterColor, alpha);
}