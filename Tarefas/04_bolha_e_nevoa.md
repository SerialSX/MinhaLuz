# Tarefa 04: A bolha de luz e a névoa

| | |
|---|---|
| **Status** | A fazer |
| **Depende de** | Tarefa 03 |
| **Ideia de origem** | Visual alvo: `assets/texturas/nevoa/nevoa_depressao_previa.png` (prévia do Lauan) |

## Objetivo

A névoa do Lauan cobre a tela inteira, andando devagar, com um buraco suave em volta da menina: a bolha de luz. O tamanho do buraco depende da variável `luz` da menina.

## Arquivos

- **Usar:** `assets/texturas/nevoa/nevoa_depressao.png` (1024×1024, repete sem emenda, sem transparência), `cenas/menina.tscn`, `scripts/menina.gd`
- **Criar:** `shaders/nevoa.gdshader`, `scripts/nevoa.gd`

## Como funciona

- A névoa é um `Sprite2D` **filho da `Camera2D`** da menina, então acompanha a câmera e sempre cobre a tela.
- Ela fica com `z_index = 50`, por cima do cenário. Na tarefa 05, as **frases boas** ficam acima dela (`z_index = 60`) para "brilhar no escuro", e as ruins ficam escondidas.
- Um **shader** deixa a névoa transparente perto da menina, com borda suave, e a faz andar para a esquerda.

## Passos

1. Criar `shaders/nevoa.gdshader`:

```glsl
shader_type canvas_item;

uniform vec2 centro = vec2(0.5, 0.5);        // posição da menina na tela (0 a 1)
uniform float raio = 0.18;                    // raio da bolha, em fração da altura da tela
uniform float suavidade = 0.12;               // largura da borda suave
uniform vec2 velocidade = vec2(-0.01, 0.0);   // névoa andando para a esquerda
uniform float opacidade = 0.97;               // força da névoa longe da menina

void fragment() {
	vec4 cor = texture(TEXTURE, UV + velocidade * TIME);
	vec2 d = SCREEN_UV - centro;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;   // corrige a proporção da tela
	float alfa = smoothstep(raio, raio + suavidade, length(d)) * opacidade;
	COLOR = vec4(cor.rgb, alfa);
}
```

2. Na `Camera2D` da cena `menina.tscn`, adicionar um filho:
   ```
   Camera2D
   └── Nevoa (Sprite2D)   script: scripts/nevoa.gd
   ```
   - `texture` = `nevoa_depressao.png`
   - `centered = true`, `region_enabled = true`, `region_rect = Rect2(0, 0, 544, 320)` (um pouco maior que a tela de 480×270)
   - **Texture → Repeat = Enabled**, **Texture → Filter = Linear** (a névoa é suave)
   - `z_index = 50`
   - `material` = `ShaderMaterial` com `shaders/nevoa.gdshader`
3. No `scripts/menina.gd`, acrescentar a luz (fixa em 100 por enquanto):

```gdscript
@export var luz_max := 100.0
@export var raio_min := 0.06   # bolha com pouca luz
@export var raio_max := 0.20   # bolha com luz cheia
var luz := 100.0

func raio_da_bolha() -> float:
	return lerpf(raio_min, raio_max, clampf(luz / luz_max, 0.0, 1.0))
```

4. Criar `scripts/nevoa.gd`, que atualiza o shader a cada quadro:

```gdscript
extends Sprite2D

@onready var menina = owner   # a raiz da cena menina.tscn (sem tipo, para poder chamar raio_da_bolha())
@onready var shader := material as ShaderMaterial

func _process(_delta: float) -> void:
	var tela: Vector2 = get_viewport_rect().size
	var pos_na_tela: Vector2 = menina.get_global_transform_with_canvas().origin
	shader.set_shader_parameter("centro", pos_na_tela / tela)
	shader.set_shader_parameter("raio", menina.raio_da_bolha())
```

5. Para testar o tamanho, mudar `luz` no inspetor (por exemplo, 100, 50 e 20) e rodar.

## Como conferir

- [ ] O campo aparece só numa bolha em volta da menina, com borda **suave**, parecido com a prévia do Lauan.
- [ ] A bolha acompanha a menina, inclusive perto das bordas do mapa (quando a câmera para).
- [ ] A névoa anda devagar para a esquerda, **sem linhas de emenda**.
- [ ] Com `luz = 20` a bolha fica pequena; com `luz = 100`, grande (mais ou menos um terço da altura da tela).
- [ ] A bolha é redonda, não oval.

## Fora do escopo

- A luz mudando durante o jogo (tarefa 05 e Ideia 1).
- Pulsar com a luz baixa, piscada (Ideias 1 e 3, depois do protótipo).

## Ao terminar

- Status: **Feito**.
- Mensagem de commit sugerida: `Adiciona a bolha de luz com a névoa`
