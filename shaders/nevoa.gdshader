// Névoa em volta da menina: transparente dentro da bolha, com borda suave,
// e andando devagar para a esquerda. Ver Tarefas/04_bolha_e_nevoa.md.
shader_type canvas_item;

uniform vec2 centro = vec2(0.5, 0.5);        // posição da menina na tela (0 a 1)
uniform float raio = 0.18;                    // raio da bolha, em fração da altura da tela
uniform float suavidade = 0.12;               // largura da borda suave
uniform vec2 velocidade = vec2(0.01, 0.0);    // positivo: a névoa anda para a esquerda
uniform float opacidade = 1.0;                // força da névoa longe da menina (1 = nada passa; 0 = sem névoa)

void fragment() {
	vec4 cor = texture(TEXTURE, UV + velocidade * TIME);
	vec2 d = SCREEN_UV - centro;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;   // corrige a proporção da tela
	float alfa = smoothstep(raio, raio + suavidade, length(d)) * opacidade;
	COLOR = vec4(cor.rgb, alfa);
}
