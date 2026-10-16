shader_type spatial;
render_mode cull_disabled;

void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float sway = smoothstep(1.5, 10.0, VERTEX.y);
    float breeze = sin(TIME * 0.85 + world.x * 0.13 + world.z * 0.11);
    VERTEX.x += breeze * 0.07 * sway;
    VERTEX.z += sin(TIME * 0.7 + world.x * 0.09) * 0.045 * sway;
}

void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.95;
    SPECULAR = 0.15;
    BACKLIGHT = COLOR.rgb * 0.12;
}
