shader_type canvas_item;
// Recolors one hue band (the wizard's blue robe and hat) and leaves everything else alone,
// so Player 2 can reuse Player 1's sprites. Skin, outline and the yellow button fall outside the band.

uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
uniform float hue_min : hint_range(0.0, 1.0) = 0.5;
uniform float hue_max : hint_range(0.0, 1.0) = 0.8;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * clamp(p - 1.0, 0.0, 1.0);
}

void fragment() {
	vec3 hsv = rgb2hsv(COLOR.rgb);
	if (hsv.y > 0.15 && hsv.x >= hue_min && hsv.x <= hue_max) {
		hsv.x = fract(hsv.x + hue_shift);
		COLOR.rgb = hsv2rgb(hsv);
	}
}
