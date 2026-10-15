shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 p = abs((UV - vec2(0.5)) * 48.0);
	float cross = max(step(p.x, 2.0) * step(p.y, 18.0), step(p.y, 2.0) * step(p.x, 18.0));
	float outline = max(step(p.x, 3.0) * step(p.y, 19.0), step(p.y, 3.0) * step(p.x, 19.0));
	vec3 background = texture(scene_texture, SCREEN_UV).rgb;
	float brightness = dot(background, vec3(0.2126, 0.7152, 0.0722));
	float tone = 1.0 - smoothstep(0.35, 0.75, brightness);
	// The opposite outline keeps the cross legible even over middle grey,
	// where a plain inversion could otherwise match its own background.
	float edge_tone = step(tone, 0.5);
	COLOR = vec4(vec3(mix(edge_tone, tone, cross)), outline);
}
