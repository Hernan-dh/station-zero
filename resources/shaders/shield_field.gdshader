shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float charge : hint_range(0.0, 1.0) = 1.0;
uniform vec3 impact_position = vec3(0.0, 1.0, 1.0);
uniform float impact_age = 10.0;
varying vec3 field_position;

void vertex() {
	field_position = VERTEX;
}

void fragment() {
	// Each geodesic cell has a zero-valued center and a one-valued boundary.
	float edge = smoothstep(0.935, 0.99, COLOR.r);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.5);
	float scan = pow(0.5 + 0.5 * sin(field_position.y * 9.0 - TIME * 1.8), 14.0);
	float distance_to_hit = distance(field_position, impact_position);
	float wave = (1.0 - smoothstep(0.035, 0.14, abs(distance_to_hit - impact_age * 2.8)))
		* max(0.0, 1.0 - impact_age / 0.8);
	float flash = exp(-distance_to_hit * 3.0) * max(0.0, 1.0 - impact_age / 0.45);
	vec3 tint = mix(vec3(0.12, 0.42, 0.64), vec3(0.12, 0.75, 1.0), charge);
	ALBEDO = mix(tint, vec3(0.73, 0.96, 1.0), clamp(edge * 0.4 + rim * 0.65 + wave + flash, 0.0, 1.0));
	ALPHA = clamp((0.045 + edge * 0.34 + rim * 0.55 + scan * 0.025 + wave * 0.8 + flash * 0.65) * strength, 0.0, 0.9);
}
