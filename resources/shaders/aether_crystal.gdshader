shader_type spatial;
render_mode diffuse_burley;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float pulse = 0.0;
varying float crystal_height;
void vertex() { crystal_height = VERTEX.y; }
void fragment() {
	float blend = smoothstep(-0.65, 1.25, crystal_height);
	vec3 cyan = vec3(0.05, 0.83, 0.94);
	vec3 violet = vec3(0.69, 0.08, 0.88);
	vec3 color = mix(cyan, violet, blend);
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = color * (0.18 + power * 0.72);
	METALLIC = 0.28;
	ROUGHNESS = 0.22;
	EMISSION = color * power * (0.5 + edge * 1.2 + pulse * 2.0);
}
