shader_type spatial;
render_mode cull_disabled;

uniform vec4 root_color : source_color = vec4(0.27, 0.31, 0.15, 1.0);
uniform vec4 tip_color : source_color = vec4(0.53, 0.55, 0.32, 1.0);
uniform vec4 dry_color : source_color = vec4(0.58, 0.51, 0.31, 1.0);
uniform float fade_start = 38.0;
uniform float fade_end = 62.0;
varying float variation;
varying float blade_height;

void vertex() {
    vec3 root = MODEL_MATRIX[3].xyz;
    variation = fract(sin(dot(root.xz, vec2(12.9898,78.233)))*43758.5453);
    float distance_to_eye = length(CAMERA_POSITION_WORLD.xz-root.xz);
    float fade = 1.0-smoothstep(fade_start+variation*4.0,fade_end,distance_to_eye);
    blade_height = UV.y;
    float wind = sin(TIME*1.6+root.x*0.45+root.z*0.31)*0.05;
    wind += sin(TIME*2.9+root.z*0.8)*0.018;
    VERTEX.xz += vec2(wind,wind*0.45)*blade_height*blade_height;
    VERTEX *= fade;
}

void fragment() {
    vec3 tip = mix(tip_color.rgb,dry_color.rgb,smoothstep(0.64,0.98,variation)*0.8);
    ALBEDO = mix(root_color.rgb,tip,smoothstep(0.0,0.9,blade_height));
    // Gentle upward-biased normals keep thin, folded blades softly lit.
    vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
    NORMAL = normalize(n+(VIEW_MATRIX*vec4(0.0,0.7,0.0,0.0)).xyz);
    ROUGHNESS = 0.95;
    SPECULAR = 0.12;
}
