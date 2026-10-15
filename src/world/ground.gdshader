shader_type spatial;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p=world_pos.xz;
    float n=noise(p*0.28)*0.65+noise(p*3.0)*0.2+noise(p*35.0)*0.15;
    vec3 grass=mix(vec3(0.26,0.33,0.20),vec3(0.52,0.55,0.34),n);
    float plot=1.0-smoothstep(0.0,0.5,max(abs(p.x-12.0)-13.0,abs(p.y)-14.0));
    float path=1.0-smoothstep(1.5,2.4,abs(p.x+16.0));
    path *= (1.0-smoothstep(21.0,23.0,abs(p.y-8.0)));
    ALBEDO=mix(grass,vec3(0.64,0.60,0.48)*(0.88+n*0.18),max(plot,path));
    ROUGHNESS=1.0;
}
