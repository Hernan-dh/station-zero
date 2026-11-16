shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform float aperture : hint_range(0.0, 1.0) = 1.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float edge = 0.97 * aperture;
	if (r > edge || aperture < 0.005) { discard; }
	float angle = atan(p.y, p.x);
	float t = TIME * 0.7;
	float twist = angle * 3.0 + r * 19.0 - t * 2.7;
	float turbulence = sin(angle * 5.0 - r * 13.0 + t) * 0.36 + sin(angle * 9.0 + r * 21.0 - t) * 0.12;
	float spiral = pow(max(0.0, sin(twist + turbulence)), 16.0);
	float fine = pow(max(0.0, sin(angle * 4.0 + r * 35.0 - t * 3.0)), 36.0);
	float rim = exp(-abs(r - edge + .025) * 100.0);
	float rim_halo = exp(-abs(r - edge + .04) * 18.0);
	float heart = exp(-r * 32.0);
	float cloud = (sin(twist + turbulence) * .5 + .5) * .16;
	vec3 color = mix(vec3(.018,.006,.065),vec3(.13,.025,.32),r);
	color += vec3(.28,.035,.65) * (spiral * .63 + cloud + rim_halo * .6);
	color += vec3(.63,.22,1.0) * fine * .18;
	color += vec3(.84,.48,1.0) * rim * 1.8;
	color += vec3(.45,.65,1.0) * heart * 3.0;
	// Sparse drifting sparks make the depth readable without particle textures.
	float turn = t * .13;
	vec2 sky = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * p * 15.0;
	vec2 cell = floor(sky);
	float seed = fract(sin(dot(cell, vec2(127.1,311.7))) * 43758.5453);
	vec2 spot = fract(sky) - vec2(.5);
	float star = exp(-dot(spot,spot) * 650.0) * step(.91,seed);
	star *= (.5 + .5 * sin(t * 2.0 + seed * 40.0)) * smoothstep(.12,.35,r);
	color += vec3(.65,.55,1.0) * star * 1.4;
	float wave = exp(-pow((r - (1.0-pulse)) * 26.0, 2.0)) * pulse;
	color += vec3(.65,.35,1.0) * wave * 1.5;
	ALBEDO = color;
	ALPHA = 1.0 - smoothstep(edge - .025, edge, r);
}
