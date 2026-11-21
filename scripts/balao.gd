class_name Balao
extends Node2D
## Balão de fala, desenhado por código. O código visual do jogo:
## bom = creme com borda dourada, redondo, com um coraçãozinho no canto;
## ruim = roxo-escuro com borda roxa pontuda.
## O dono põe o balão em SobreNevoa (por cima da névoa) e atualiza `position` a
## cada quadro: é a ponta do rabinho, logo acima da cabeça de quem fala.
## Com o dono na borda da tela, o balão desliza para o lado; se não cabe em cima
## (dono colado no topo), vai para baixo dele. O dono também pode pedir o balão
## embaixo (`para_baixo`), para não tapar quem está logo acima.

const TAMANHO_FONTE := 8
const LARGURA_MAX := 72.0          # o texto quebra em linhas até esta largura
const MARGEM := Vector2(5, 2)      # do texto até a borda do balão
const RABINHO := 4                 # altura do rabinho, em pixels
const BORDA_TELA := 3.0            # o balão não chega mais perto que isso da borda da tela
const ALTURA_DONO := 26.0          # balão embaixo do dono: o rabinho sai dos pés
const COR_FUNDO_BOM := Color(1.0, 0.965, 0.86)
const COR_BORDA_BOA := Color(1.0, 0.827, 0.42)      # dourado
const COR_TEXTO_BOM := Color(0.3, 0.19, 0.09)
const COR_FUNDO_RUIM := Color(0.15, 0.1, 0.21)
const COR_BORDA_RUIM := Color(0.62, 0.5, 0.68)      # roxo ruim
const COR_TEXTO_RUIM := Color(0.925, 0.902, 0.961)
const COR_CORACAO := Color(0.933, 0.298, 0.408)
const COR_CORACAO_BORDA := Color(0.376, 0.086, 0.18)
# Coração de 7x7 pixels, igual ao ícone assets/ui/coracao_nativa.png: contorno e miolo.
const CORACAO_BORDA := [Rect2(1, 0, 2, 1), Rect2(4, 0, 2, 1), Rect2(0, 1, 7, 3), Rect2(1, 4, 5, 1), Rect2(2, 5, 3, 1), Rect2(3, 6, 1, 1)]
const CORACAO_MIOLO := [Rect2(1, 1, 2, 1), Rect2(4, 1, 2, 1), Rect2(1, 2, 5, 2), Rect2(2, 4, 3, 1), Rect2(3, 5, 1, 1)]
# Sinais sem letras, desenhados pixel a pixel para ficarem nítidos: [tamanho, retângulos].
const SINAIS := {
	"...": [Vector2(13, 7), [Rect2(0, 2, 3, 3), Rect2(5, 2, 3, 3), Rect2(10, 2, 3, 3)]],
	"?": [Vector2(6, 9), [Rect2(1, 0, 4, 1), Rect2(0, 1, 2, 1), Rect2(4, 1, 2, 2), Rect2(3, 3, 2, 1), Rect2(2, 4, 2, 2), Rect2(2, 7, 2, 2)]],
}

var texto := ""
var bom := true
var para_baixo := false         # o dono pede o balão embaixo dele (defina antes de add_child)
var fonte: Font
var corpo := Vector2.ZERO       # tamanho do balão, sem o rabinho
var desvio := 0.0               # o corpo desliza para o lado para caber na tela...
var rabinho := 0.0              # ...e o rabinho vai junto só o que precisa para continuar preso nele
var embaixo := false            # o balão está embaixo do dono (pedido, ou sem espaço em cima)
var encaixe := Vector2.ZERO     # põe o desenho em pixels inteiros da tela (o texto não treme)
var fechando := false


static func criar(frase: String, e_bom: bool) -> Balao:
	var balao := Balao.new()
	balao.texto = frase
	balao.bom = e_bom
	balao.z_index = 1   # por cima do resto da camada (círculos, vaga-lumes, cópias das crianças)
	return balao


func _ready() -> void:
	var tema := ThemeDB.get_project_theme()
	fonte = tema.default_font if tema and tema.default_font else ThemeDB.fallback_font
	corpo = fonte.get_multiline_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, LARGURA_MAX, TAMANHO_FONTE).ceil()
	if SINAIS.has(texto):
		corpo = SINAIS[texto][0]
	corpo += MARGEM * 2.0
	_ajeitar()
	# Nasce com um "pop".
	scale = Vector2.ZERO
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	_ajeitar()
	queue_redraw()


## Encolhe e se libera.
func fechar() -> void:
	if fechando:
		return
	fechando = true
	var t := create_tween()   # criado depois do "pop": se os dois andarem juntos, vale este
	t.tween_property(self, "scale", Vector2.ZERO, 0.1)
	t.tween_callback(queue_free)


## Ajeita o balão na tela, a partir de onde a ponta do rabinho está nela.
func _ajeitar() -> void:
	var ponta := get_global_transform_with_canvas().origin
	var pixel := ponta.round()
	encaixe = pixel - ponta
	var tela := get_viewport_rect().size
	var cabe_embaixo := pixel.y + ALTURA_DONO + RABINHO + corpo.y <= tela.y - BORDA_TELA
	embaixo = (para_baixo and cabe_embaixo) or pixel.y - RABINHO - corpo.y < BORDA_TELA
	var meia := floorf(corpo.x / 2.0)
	var esquerda := pixel.x - meia
	var na_tela := clampf(esquerda, BORDA_TELA, tela.x - BORDA_TELA - corpo.x)
	desvio = clampf(na_tela - esquerda, -meia, meia)   # com o dono fora da tela, o balão sai junto
	var folga := maxf(meia - 6.0, 0.0)
	rabinho = clampf(0.0, desvio - folga, desvio + folga)


func _draw() -> void:
	draw_set_transform(encaixe)
	var borda := COR_BORDA_BOA if bom else COR_BORDA_RUIM
	var fundo := COR_FUNDO_BOM if bom else COR_FUNDO_RUIM
	var ponta_y := ALTURA_DONO if embaixo else 0.0
	var caixa := Rect2(desvio - floorf(corpo.x / 2.0), ponta_y + RABINHO if embaixo else -RABINHO - corpo.y, corpo.x, corpo.y)
	if bom:
		_redondo(caixa, borda)
		_redondo(caixa.grow(-1.0), fundo)
	else:
		draw_rect(caixa, borda)
		draw_rect(caixa.grow(-1.0), fundo)
		_dentes(caixa, borda)
	# Rabinho em degraus de pixel, da ponta até o corpo; a última linha abre a borda do corpo.
	for i in RABINHO + 1:
		var y := ponta_y + (i if embaixo else -1 - i)
		if i < RABINHO:
			draw_rect(Rect2(rabinho - i, y, 2 * i + 1, 1), borda)
		if i > 0:
			draw_rect(Rect2(rabinho + 1 - i, y, 2 * i - 1, 1), fundo)
	var cor := COR_TEXTO_BOM if bom else COR_TEXTO_RUIM
	if SINAIS.has(texto):
		for parte: Rect2 in SINAIS[texto][1]:
			draw_rect(Rect2(caixa.position + MARGEM + parte.position, parte.size), cor)
	else:
		var linha := Vector2(caixa.get_center().x - LARGURA_MAX / 2.0, caixa.position.y + MARGEM.y + fonte.get_ascent(TAMANHO_FONTE))
		draw_multiline_string(fonte, linha.floor(), texto, HORIZONTAL_ALIGNMENT_CENTER, LARGURA_MAX, TAMANHO_FONTE, -1, cor)
	if bom:
		desenhar_coracao(self, Vector2(caixa.end.x - 5.0, caixa.position.y - 3.0))


## Coraçãozinho de 7x7 pixels com o canto de cima em `pos` (scripts/crianca.gd também usa).
static func desenhar_coracao(item: CanvasItem, pos: Vector2) -> void:
	for parte: Rect2 in CORACAO_BORDA:
		item.draw_rect(Rect2(pos + parte.position, parte.size), COR_CORACAO_BORDA)
	for parte: Rect2 in CORACAO_MIOLO:
		item.draw_rect(Rect2(pos + parte.position, parte.size), COR_CORACAO)


## Retângulo de cantos redondos, em pixels.
func _redondo(caixa: Rect2, cor: Color) -> void:
	draw_rect(caixa.grow_individual(-3, 0, -3, 0), cor)
	draw_rect(caixa.grow(-1.0), cor)
	draw_rect(caixa.grow_individual(0, -3, 0, -3), cor)


## Borda pontuda: um dentinho de 3 pixels a cada 4, nos quatro lados.
func _dentes(caixa: Rect2, cor: Color) -> void:
	var a := caixa.position
	var b := caixa.end
	for x in range(int(a.x) + _sobra(caixa.size.x), int(b.x) - 2, 4):
		draw_rect(Rect2(x, a.y - 1, 3, 1), cor)
		draw_rect(Rect2(x + 1, a.y - 2, 1, 1), cor)
		draw_rect(Rect2(x, b.y, 3, 1), cor)
		draw_rect(Rect2(x + 1, b.y + 1, 1, 1), cor)
	for y in range(int(a.y) + _sobra(caixa.size.y), int(b.y) - 2, 4):
		draw_rect(Rect2(a.x - 1, y, 1, 3), cor)
		draw_rect(Rect2(a.x - 2, y + 1, 1, 1), cor)
		draw_rect(Rect2(b.x, y, 1, 3), cor)
		draw_rect(Rect2(b.x + 1, y + 1, 1, 1), cor)


## Onde começa o primeiro dentinho para a fileira ficar centralizada no lado.
func _sobra(lado: float) -> int:
	@warning_ignore("integer_division")
	return (int(lado) + 1) % 4 / 2
