// Ar quente a tremer por cima dos fogões ao lume. A textura só serve para dar
// as coordenadas UV de 0 a 1 do retângulo.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength = 0.0022;

void fragment() {
	float fade = smoothstep(0.0, 0.45, UV.y) * smoothstep(1.0, 0.75, UV.y) * smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	vec2 off = vec2(sin(UV.y * 22.0 - TIME * 7.0), cos(UV.x * 15.0 + TIME * 5.0)) * strength * fade;
	COLOR = vec4(texture(screen_tex, SCREEN_UV + off).rgb, fade > 0.01 ? 1.0 : 0.0);
}
