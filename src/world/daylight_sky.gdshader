shader_type sky;

uniform vec3 sun_direction = vec3(0.7, 0.6, -0.3);
uniform vec4 sun_color : source_color = vec4(1.0, 0.97, 0.87, 1.0);
uniform vec4 zenith_color : source_color = vec4(0.45, 0.58, 0.67, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.84, 0.85, 0.78, 1.0);
uniform vec4 ground_color : source_color = vec4(0.37, 0.44, 0.40, 1.0);

void sky() {
    vec3 direction = normalize(EYEDIR);
    vec3 background;
    if (direction.y >= 0.0) {
        background = mix(horizon_color.rgb, zenith_color.rgb, pow(direction.y, 0.45));
    } else {
        background = mix(horizon_color.rgb, ground_color.rgb, pow(-direction.y, 0.45));
    }

    // Draw directly at full resolution, independent of the blurred radiance cubemap
    // and the much lower light energies used to keep the stonework readable.
    float angle = acos(clamp(dot(direction, normalize(sun_direction)), -1.0, 1.0));
    float radius = 0.0096;
    float edge = max(fwidth(angle), 0.0002);
    float disc = 1.0 - smoothstep(radius - edge, radius + edge, angle);
    float halo = 0.18 * exp(-angle * angle / 0.0016);
    COLOR = mix(background + sun_color.rgb * halo, sun_color.rgb * 3.0, disc);
}
