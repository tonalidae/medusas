#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D texture;
uniform vec2 texOffset;
uniform vec2 direction;

varying vec4 vertColor;
varying vec4 vertTexCoord;

void main() {
    vec4 sum = vec4(0.0);
    vec2 tc = vertTexCoord.st;
    
    // 9-tap gaussian blur
    float weights[5];
    weights[0] = 0.227027;
    weights[1] = 0.1945946;
    weights[2] = 0.1216216;
    weights[3] = 0.054054;
    weights[4] = 0.016216;
    
    sum += texture2D(texture, tc) * weights[0];
    
    for (int i = 1; i < 5; i++) {
        vec2 offset = direction * texOffset * float(i);
        sum += texture2D(texture, tc + offset) * weights[i];
        sum += texture2D(texture, tc - offset) * weights[i];
    }
    
    gl_FragColor = sum;
}
