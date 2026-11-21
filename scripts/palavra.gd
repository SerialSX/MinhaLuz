class_name Palavra
extends Node2D
## Uma palavra que voa, desenhada por código. Quem solta põe a palavra em
## SobreNevoa: sempre por cima da névoa, em coordenadas do mundo. Não usa física:
## a posição é calculada a cada quadro. São duas:
## - Ruim: a criança apagada solta na direção de onde a menina está. Voa reto,
##   atravessa obstáculos, some no fim do alcance ou na borda de um lugar seguro
##   aceso, e acerta a menina só pelo miolo do texto: dá para desviar andando.
##   Não acerta logo que sai da boca nem quem está num lugar seguro aceso.
## - Boa: a menina solta. Segue o alvo (criança apagada ou frase ruim acordada)
##   numa curva suave e avisa com `acertou` quando chega nele. Sem alvo, voa reto.
## Código visual do jogo: ruim = roxo com borda pontuda; boa = dourada.

signal acertou(alvo: Node2D, rumo: Vector2)   ## a palavra boa chegou no alvo

const GRUPO_RUINS := "palavras_ruins"   # as ruins que ainda voam (a fase limpa todas de uma vez)
const TAMANHO_FONTE := 8
const ALCANCE_RUIM := 230.0
const ALCANCE_BOA := 170.0
const VELOCIDADE_BOA := 180.0
const GIRO := 8.0                  # rad/s: quanto a palavra boa vira para seguir o alvo
const TOCA := 9.0                  # a palavra boa acerta a esta distância do meio do alvo
const MIOLO := Vector2(0.6, 8.0)   # a ruim acerta por 60% da largura do texto e 8 px de altura
const CORPO_MENINA := 5.0          # raio do corpo da menina (cenas/menina.tscn)
const ARMA := 28.0                 # a ruim só acerta depois de voar isto: de perto, dá tempo de sair da frente
const PUF := 0.15                  # segundos para sumir
const COR_BOA := Color(1.0, 0.878, 0.541)
const COR_CONTORNO := Color(0.16, 0.09, 0.02)
const COR_RUIM := Color(0.62, 0.5, 0.68)
const COR_FUNDO_RUIM := Color(0.13, 0.09, 0.19)
const COR_TEXTO_RUIM := Color(0.663, 0.612, 0.761)   # lilás

var boa := false
var texto := ""
var rumo := Vector2.RIGHT
var velocidade := VELOCIDADE_BOA
var alcance := ALCANCE_BOA
var menina: Menina          # ruim: quem ela pode acertar
var dona: Node2D            # ruim: a criança que soltou
var alvo: Node2D            # boa: quem ela segue (null = voa reto)
var pos := Vector2.ZERO     # posição exata; `position` é ela em pixels inteiros (o texto não treme)
var andou := 0.0
var sumindo := false
var fonte: Font
var meio := Vector2.ZERO    # metade do tamanho do texto


## Palavra ruim: sai de `de` e voa reto para o lado de `para_onde`.
static func nova_ruim(frase: String, de: Vector2, para_onde: Vector2, px_por_s: float, a_menina: Menina, a_dona: Node2D) -> Palavra:
	var palavra := Palavra.new()
	palavra.texto = frase
	palavra.pos = de
	palavra.rumo = para_onde
	palavra.velocidade = px_por_s
	palavra.alcance = ALCANCE_RUIM
	palavra.menina = a_menina
	palavra.dona = a_dona
	palavra.add_to_group(GRUPO_RUINS)
	return palavra


## Palavra boa: sai de `de` para o lado de `para_onde` e segue `o_alvo` (pode ser null).
static func nova_boa(frase: String, de: Vector2, para_onde: Vector2, o_alvo: Node2D) -> Palavra:
	var palavra := Palavra.new()
	palavra.boa = true
	palavra.texto = frase
	palavra.pos = de
	palavra.rumo = para_onde
	palavra.alvo = o_alvo
	return palavra


## Vale mirar nisto? Criança ainda apagada, ou frase ruim acordada.
static func e_alvo(no: Node2D) -> bool:
	var crianca := no as Crianca
	if crianca:
		return not crianca.acesa
	var frase := no as Frase
	return frase != null and not frase.boa and not frase.dissolvendo and frase.estado != Frase.Estado.DORMINDO


func _ready() -> void:
	var tema := ThemeDB.get_project_theme()
	fonte = tema.default_font if tema and tema.default_font else ThemeDB.fallback_font
	meio = (fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_FONTE) / 2.0).ceil()
	position = pos.round()
	z_index = 2   # por cima dos balões
	# Nasce pequena e cresce: nada surge de repente.
	scale = Vector2.ONE * 0.4
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.1)


func _physics_process(delta: float) -> void:
	if sumindo:
		return
	if boa:
		_seguir(delta)
	pos += rumo * velocidade * delta
	andou += velocidade * delta
	position = pos.round()
	if boa:
		if alvo and pos.distance_to(alvo.global_position) <= TOCA:
			acertou.emit(alvo, rumo)
			sumir()
	elif Refugio.protege(pos):
		sumir()   # não entra em lugar seguro aceso
	elif _pode_acertar() and _no_miolo(menina.global_position) and menina.levar_frase_ruim():
		sumir()   # com a menina protegida, a palavra passa sem efeito
	if andou >= alcance:
		sumir()


## Some com um "puf": incha um pouco e desaparece. Daqui em diante não acerta ninguém.
func sumir() -> void:
	if sumindo:
		return
	sumindo = true
	remove_from_group(GRUPO_RUINS)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2.ONE * 1.3, PUF)
	t.tween_property(self, "modulate:a", 0.0, PUF)
	t.chain().tween_callback(queue_free)


## A palavra boa vira aos poucos para o alvo. Se ele deixou de valer (acendeu,
## dormiu, se desfez), ela segue reto até o fim do alcance.
func _seguir(delta: float) -> void:
	if not (is_instance_valid(alvo) and e_alvo(alvo)):
		alvo = null
		return
	var para_o_alvo := pos.direction_to(alvo.global_position)
	rumo = rumo.rotated(clampf(rumo.angle_to(para_o_alvo), -GIRO * delta, GIRO * delta))


## A palavra ruim já vale (voou o bastante), e a menina está fora dos lugares seguros?
## O miolo é mais largo que o centro da palavra, que é o que some na borda do
## lugar seguro: sem isto, ele alcançaria a menina lá dentro.
func _pode_acertar() -> bool:
	return andou >= ARMA and not Refugio.protege(menina.global_position)


## A menina (um círculo de 5 px em `ponto`) encosta no miolo do texto?
func _no_miolo(ponto: Vector2) -> bool:
	var d := (ponto - pos).abs()
	return d.x <= meio.x * MIOLO.x + CORPO_MENINA and d.y <= MIOLO.y / 2.0 + CORPO_MENINA


func _draw() -> void:
	var onde := Vector2(-meio.x, -meio.y + fonte.get_ascent(TAMANHO_FONTE))
	if boa:
		draw_string_outline(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_FONTE, 4, COR_CONTORNO)
		draw_string(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_FONTE, COR_BOA)
		return
	# Ruim: placa roxo-escura com dentes em cima e embaixo (como as frases ruins da fase).
	var canto := meio + Vector2(3.0, 0.0)
	var pontos := PackedVector2Array()
	var dentes := maxi(int(canto.x * 2.0 / 6.0), 2)
	for i in dentes + 1:   # em cima, da esquerda para a direita
		var x := lerpf(-canto.x, canto.x, i / float(dentes))
		pontos.append(Vector2(x, -canto.y))
		if i < dentes:
			pontos.append(Vector2(x + canto.x / dentes, -canto.y - 3.0))
	for i in dentes + 1:   # embaixo, da direita para a esquerda
		var x := lerpf(canto.x, -canto.x, i / float(dentes))
		pontos.append(Vector2(x, canto.y))
		if i < dentes:
			pontos.append(Vector2(x - canto.x / dentes, canto.y + 3.0))
	draw_colored_polygon(pontos, COR_FUNDO_RUIM)
	pontos.append(pontos[0])
	draw_polyline(pontos, COR_RUIM, 1.0)
	draw_string(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_FONTE, COR_TEXTO_RUIM)
