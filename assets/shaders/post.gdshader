// Pós-processamento do ecrã inteiro (ver PostFX): correção de cor quente,
// vinheta e, no Ultra, bloom à volta das luzes e um pouco de aberração
// cromática nos cantos.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float contrast = 1.06;
uniform float saturation = 1.1;
uniform vec3 lift = vec3(0.015, 0.0, 0.03);
uniform vec3 gain = vec3(1.04, 1.0, 0.95);
uniform float vignette = 0.38;
uniform float bloom = 0.0;
uniform float bloom_radius = 0.012;
uniform float bloom_threshold = 0.78;
uniform float aberration = 0.0;

vec3 bright(vec2 uv) {
	vec3 c = texture(screen_tex, uv).rgb;
	return max(c - vec3(bloom_threshold), vec3(0.0));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c;
	if (aberration > 0.0) {
		vec2 d = (uv - 0.5) * aberration * dot(uv - 0.5, uv - 0.5) * 4.0;
		c = vec3(texture(screen_tex, uv + d).r, texture(screen_tex, uv).g, texture(screen_tex, uv - d).b);
	} else {
		c = texture(screen_tex, uv).rgb;
	}
	if (bloom > 0.0) {
		vec2 aspect = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0);
		vec3 b = vec3(0.0);
		for (int ring = 1; ring <= 2; ring++) {
			float r = bloom_radius * float(ring);
			for (int k = 0; k < 8; k++) {
				float a = 6.2831853 * (float(k) + 0.5 * float(ring)) / 8.0;
				b += bright(uv + vec2(cos(a), sin(a)) * r * aspect);
			}
		}
		c += b / 16.0 * bloom;
	}
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = c * gain + lift * (1.0 - c);
	vec2 v = uv - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.85, length(v * vec2(1.1, 1.0)) * 1.25);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
