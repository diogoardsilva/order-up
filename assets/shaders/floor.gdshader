// Chão polido (texturas Ultra): cada ladrilho com um tom ligeiramente
// diferente, grão fino e o reflexo das luzes no chão (só nas partes claras,
// não nas juntas). As posições das luzes vêm da Kitchen a cada frame.
shader_type canvas_item;

uniform vec4 lights[16];
uniform vec4 light_colors[16] : source_color;
uniform int light_count = 0;
uniform vec2 floor_size = vec2(480.0, 312.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (local.x >= 0.0 && local.y >= 0.0 && local.x < floor_size.x && local.y < floor_size.y) {
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		float gloss = smoothstep(0.38, 0.85, lum);
		c.rgb *= 0.965 + 0.07 * hash(floor(local / 24.0) + vec2(3.1, 7.7));
		c.rgb *= 0.985 + 0.03 * hash(floor(local));
		vec3 spec = vec3(0.0);
		for (int i = 0; i < 16; i++) {
			if (i >= light_count) {
				break;
			}
			vec4 l = lights[i];
			vec2 d = (local - l.xy) / vec2(l.z * 0.45, l.z * 0.8);
			float f = max(0.0, 1.0 - dot(d, d));
			spec += light_colors[i].rgb * light_colors[i].a * f * f * f * 0.9;
		}
		c.rgb += spec * gloss;
	}
	COLOR = c;
}
