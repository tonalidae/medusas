#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D texture;
uniform sampler2D bloomTexture;
uniform float bloomIntensity;

varying vec4 vertColor;
varying vec4 vertTexCoord;

void main() {
    vec4 scene = texture2D(texture, vertTexCoord.st);
    vec4 bloom = texture2D(bloomTexture, vertTexCoord.st);
    
    gl_FragColor = scene + bloom * bloomIntensity;
}
