// Desenha por cima da névoa, só onde a névoa cobre (fora da bolha de luz).
// Os valores da bolha são copiados da névoa por scripts/nevoa.gd.
shader_type canvas_item;

uniform vec2 centro = vec2(0.5, 0.5);
uniform float raio = 0.2;
uniform float suavidade = 0.12;
uniform float opacidade = 1.0;      // opacidade da névoa: sem névoa, isto some
uniform float forca = 0.5;          // quanto aparece no escuro (0 a 1)
uniform float achatar = 0.0;        // 1 = silhueta numa cor só
uniform vec4 tinta : source_color = vec4(0.5, 0.45, 0.68, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 d = SCREEN_UV - centro;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float fora = smoothstep(raio, raio + suavidade, length(d)) * opacidade;
	c.rgb = mix(c.rgb, tinta.rgb, achatar);
	c.a *= fora * forca;
	COLOR = c;
}
