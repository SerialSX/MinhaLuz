// Fundo do menu principal: noite escura (#0b0a14) com névoa índigo andando
// devagar para a esquerda (duas camadas, a de trás maior e mais lenta) e um
// buraco de luz suave em volta da menina. Tudo em pixels inteiros da tela
// de 480×270, para a névoa andar "de pixel em pixel", sem borrar.
shader_type canvas_item;

uniform sampler2D nevoa : repeat_enable, filter_nearest;
uniform vec2 tamanho_tela = vec2(480.0, 270.0);
uniform vec2 centro_luz = vec2(86.0, 208.0);   // menina, em pixels da tela
uniform float raio_luz = 30.0;                 // buraco limpo, em pixels
uniform float borda_luz = 46.0;                // largura da borda suave
uniform float velocidade = 6.0;                // pixels por segundo (positivo = para a esquerda)
uniform vec4 cor_fundo : source_color = vec4(0.043, 0.039, 0.078, 1.0);
uniform vec4 cor_nevoa : source_color = vec4(0.30, 0.25, 0.47, 1.0);
uniform vec4 cor_luz : source_color = vec4(1.0, 0.83, 0.42, 1.0);

void fragment() {
	vec2 px = floor(UV * tamanho_tela);
	vec2 tam = vec2(textureSize(nevoa, 0));
	float frente = texture(nevoa, (px + 0.5 + vec2(floor(velocidade * TIME), 0.0)) / tam).r;
	float tras = texture(nevoa, (floor(px / 2.0) + 0.5 + vec2(floor(velocidade * 0.4 * TIME), 31.0)) / tam).r;
	float densidade = smoothstep(0.12, 0.5, max(frente, tras * 0.85));
	vec3 cor = mix(cor_fundo.rgb, cor_nevoa.rgb, densidade * 0.75);

	// brilho quente bem fraco atrás do título e dos botões (como no mockup)
	float titulo = 1.0 - smoothstep(0.0, 190.0, length((px - vec2(240.0, 90.0)) * vec2(0.7, 1.0)));
	cor += cor_luz.rgb * titulo * 0.07;

	// buraco de luz em volta da menina, respirando devagar
	float raio = raio_luz + sin(TIME * 2.24) * 2.0;
	float fora = smoothstep(raio, raio + borda_luz, length(px - centro_luz));
	cor = mix(cor_fundo.rgb + cor_luz.rgb * 0.08, cor, fora);
	COLOR = vec4(cor, 1.0);
}
