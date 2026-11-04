// Ar quente por cima dos fogões ao lume: ondas claras e transparentes a subir.
// Não lê o ecrã (a versão antiga lia e fazia tremer também a interface), só
// desenha por cima. A textura só serve para dar as coordenadas UV do retângulo.
shader_type canvas_item;

uniform float strength = 0.16;

void fragment() {
	float fade = smoothstep(0.0, 0.45, UV.y) * smoothstep(1.0, 0.7, UV.y) * smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	float x = UV.x + sin(UV.y * 9.0 - TIME * 4.0) * 0.08;
	float waves = sin(x * 28.0 + TIME * 1.3) * 0.5 + 0.5;
	waves *= sin(UV.y * 18.0 + TIME * 6.0) * 0.5 + 0.5;
	COLOR = vec4(1.0, 0.93, 0.82, waves * fade * strength);
}
