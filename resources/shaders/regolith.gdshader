shader_type spatial;
render_mode diffuse_burley;

varying vec3 world_position;

float grain(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dust = grain(floor(world_position * 32.0));
	float pebbles = step(0.965, grain(floor(world_position * 9.0)));
	ALBEDO = COLOR.rgb * (0.88 + dust * 0.16 - pebbles * 0.18);
	ROUGHNESS = 0.96;
}
