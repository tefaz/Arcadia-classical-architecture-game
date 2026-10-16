shader_type spatial;
// Explicit colour uniforms keep this palette consistent in linear HDR and OpenGL.
uniform vec4 grass_dark : source_color = vec4(0.26, 0.33, 0.20, 1.0);
uniform vec4 grass_light : source_color = vec4(0.52, 0.55, 0.34, 1.0);
uniform vec4 path_color : source_color = vec4(0.64, 0.60, 0.48, 1.0);
uniform vec4 earth_color : source_color = vec4(0.35, 0.31, 0.22, 1.0);
uniform vec4 rock_color : source_color = vec4(0.47, 0.46, 0.37, 1.0);
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() {
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec2 p=world_pos.xz;
    float broad=noise(p*0.11);
    float middle=noise(p*1.7);
    // Filter subpixel grains rather than letting distant detail shimmer.
    float near_detail=1.0-smoothstep(0.035,0.18,length(fwidth(p)));
    vec2 rotated=mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*p;
    float grains=mix(0.5,noise(rotated*38.0),near_detail);
    float pebbles=mix(0.5,noise(rotated*13.0),near_detail);
    float n=broad*0.6+middle*0.25+grains*0.15;
    vec3 grass=mix(grass_dark.rgb,grass_light.rgb,n);
    float soil=smoothstep(0.53,0.74,noise(p*0.24)+middle*0.18);
    grass=mix(grass,earth_color.rgb*(0.83+grains*0.28),soil*0.7);
    float plot=1.0-smoothstep(0.0,0.5,max(abs(p.x-12.0)-13.0,abs(p.y)-14.0));
    float path=1.0-smoothstep(1.5,2.4,abs(p.x+16.0));
    path *= (1.0-smoothstep(21.0,23.0,abs(p.y-8.0)));
    float gravel=max(plot,path);
    vec3 gravel_color=path_color.rgb*(0.77+pebbles*0.36+grains*0.13);
    float stones=smoothstep(0.59,0.74,pebbles)*near_detail;
    gravel_color=mix(gravel_color,path_color.rgb*1.12,stones*0.5);
    float slope=1.0-smoothstep(0.72,0.93,world_normal.y);
    vec3 land=mix(grass,rock_color.rgb*(0.8+middle*0.32+grains*0.12),slope*0.8);
    ALBEDO=mix(land,gravel_color,gravel);
    ROUGHNESS=mix(0.98,0.85,stones*gravel);
    SPECULAR=0.15;
    // Derivative bump mapping gives grains and pebbles actual lighting relief.
    float height=mix((middle*0.008+grains*0.003),(pebbles*0.012+grains*0.004),gravel);
    vec3 dx=dFdx(VERTEX);
    vec3 dy=dFdy(VERTEX);
    vec3 rx=cross(dy,NORMAL);
    vec3 ry=cross(NORMAL,dx);
    float determinant=dot(dx,rx);
    vec3 bumped=abs(determinant)*NORMAL-sign(determinant)*(dFdx(height)*rx+dFdy(height)*ry);
    if (dot(bumped,bumped)>0.000000000001) NORMAL=normalize(bumped);
}
