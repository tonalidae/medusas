#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D texture;
uniform vec2 texOffset;
uniform float threshold;

varying vec4 vertColor;
varying vec4 vertTexCoord;

void main() {
    vec4 col = texture2D(texture, vertTexCoord.st);
    float brightness = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
    
    if (brightness > threshold) {
        gl_FragColor = col;
    } else {
        gl_FragColor = vec4(0.0);
    }
}
