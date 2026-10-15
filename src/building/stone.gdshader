shader_type spatial;
uniform vec4 stone_color : source_color = vec4(0.87, 0.82, 0.72, 1.0);
uniform float marble = 0.0;
varying vec3 world_pos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
    vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float grain = noise(world_pos * 24.0) * 0.055 + noise(world_pos * 2.2) * 0.06;
    float veins = pow(1.0-abs(sin(world_pos.x*1.6 + world_pos.y*0.9 + noise(world_pos*1.2)*5.0)), 14.0);
    ALBEDO = stone_color.rgb * (0.92 + grain - veins*marble*0.12);
    ROUGHNESS = mix(0.83, 0.46, marble); SPECULAR = 0.25;
}
