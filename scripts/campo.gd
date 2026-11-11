extends Node2D
## Fase 1: o campo. Os nós fixos (chão, menina, névoa e interface) ficam na cena
## cenas/campo.tscn. Casas, árvores e frases são sorteadas a cada partida e
## colocadas dentro do nó Mundo/Cenario. Também cuida da pausa, do game over e da vitória.
## Ver Tarefas/03 e 05.

const CENA_FRASE := preload("res://cenas/frase.tscn")

const TAMANHO_MAPA := Vector2(1536, 864)
const MARGEM := 24.0
const QTD_CASAS := 8
const QTD_ARVORES := 18
# Casas e árvores desenhadas pequenas demais perto da menina: ampliadas no jogo.
# Provisório (ver docs/decisoes.md). Use número inteiro para o pixel ficar nítido.
const ESCALA_CENARIO := 2.0

# Frases provisórias, simples para crianças. A lista oficial ainda vai ser feita.
const FRASES_BOAS := [
	"Você é importante",
	"Tudo bem pedir ajuda",
	"Você é capaz",
	"Sempre há algo de bom",
	"Você não está sozinha",
	"Amanhã pode ser melhor",
]
const FRASES_RUINS := [
	"Ninguém liga",
	"Você não consegue",
	"Não adianta tentar",
	"Você é sozinha",
	"Você sempre erra",
	"Ninguém gosta de você",
]

const MSG_GAME_OVER := "Você sempre pode recomeçar\ne tentar novamente."
const MSG_VITORIA := "Você conseguiu!\nO mundo se ilumina."

# Controles: cada ação com WASD e setas (ver Tarefas/01).
const CONTROLES := {
	"mover_cima": [KEY_W, KEY_UP],
	"mover_baixo": [KEY_S, KEY_DOWN],
	"mover_esquerda": [KEY_A, KEY_LEFT],
	"mover_direita": [KEY_D, KEY_RIGHT],
	"pausar": [KEY_ESCAPE],
}

var ocupados: Array[Rect2] = []
var sprites_cenario: Array = []   # [sprite, caminho da versão original] para a vitória
var boas_total := 0
var boas_pegas := 0
var terminou := false

@onready var mundo: Node2D = $Mundo            # tudo que para quando o jogo pausa
@onready var tom: CanvasModulate = $Mundo/Tom  # deixa o mundo um pouco apagado
@onready var cenario: Node2D = $Mundo/Cenario  # casas, árvores e frases sorteadas
@onready var menina: Menina = $Mundo/Menina
@onready var hud_contador: Label = $HUD/Contador
@onready var hud_mensagem: Label = $HUD/Mensagem


func _ready() -> void:
	_configurar_controles()
	menina.apagou.connect(_game_over)

	var inicio := menina.position
	ocupados.append(Rect2(inicio - Vector2(48, 48), Vector2(96, 96)))   # área livre no começo
	_criar_casas()
	_criar_arvores()
	_criar_frases()
	_atualizar_contador()
	hud_mensagem.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if terminou:
		if event.is_action_pressed("ui_accept"):
			_recomecar()
		return
	if event.is_action_pressed("pausar"):
		get_tree().paused = not get_tree().paused
		hud_mensagem.text = "Pausado\n(Esc para continuar)" if get_tree().paused else ""


# ---------- Mapa ----------

func _criar_casas() -> void:
	var numeros := range(1, 17)
	numeros.shuffle()
	for i in QTD_CASAS:
		var n: int = numeros[i]
		var caminho := "res://assets/sprites/casas/%s/casa_%02d_nativa.png"
		var textura: Texture2D = load(caminho % ["melancolica", n])
		var tamanho := textura.get_size() * ESCALA_CENARIO
		var pos := _lugar_livre(tamanho, 16.0)
		if pos.x < 0.0:
			continue

		var casa := StaticBody2D.new()
		casa.name = "Casa%02d" % n
		casa.position = pos
		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.scale = Vector2.ONE * ESCALA_CENARIO
		casa.add_child(sprite)
		var colisao := CollisionShape2D.new()
		var forma := RectangleShape2D.new()
		forma.size = tamanho - Vector2(4, 4)
		colisao.shape = forma
		casa.add_child(colisao)
		cenario.add_child(casa)
		sprites_cenario.append([sprite, caminho % ["original", n]])


func _criar_arvores() -> void:
	for i in QTD_ARVORES:
		var n := randi_range(1, 9)
		var caminho := "res://assets/sprites/arvores/%s/arvore_%02d_nativa.png"
		var textura: Texture2D = load(caminho % ["melancolica", n])
		var pos := _lugar_livre(textura.get_size() * ESCALA_CENARIO, 6.0)
		if pos.x < 0.0:
			continue

		var arvore := Sprite2D.new()
		arvore.texture = textura
		arvore.scale = Vector2.ONE * ESCALA_CENARIO
		arvore.position = pos
		arvore.z_index = 10   # a menina passa por baixo da copa
		cenario.add_child(arvore)
		sprites_cenario.append([arvore, caminho % ["original", n]])


func _criar_frases() -> void:
	for texto in FRASES_BOAS:
		if _colocar_frase(true, texto):
			boas_total += 1
	for texto in FRASES_RUINS:
		_colocar_frase(false, texto)


func _colocar_frase(boa: bool, texto: String) -> bool:
	var pos := _lugar_livre(Vector2(130, 16), 10.0)
	if pos.x < 0.0:
		return false
	var frase: Frase = CENA_FRASE.instantiate()
	frase.configurar(boa, texto)
	frase.position = pos
	if boa:
		frase.pega.connect(_ao_pegar_frase_boa)
	cenario.add_child(frase)
	return true


## Sorteia um lugar onde cabe um retângulo do tamanho dado, sem encostar em nada.
## Retorna (-1, -1) se não achar.
func _lugar_livre(tamanho: Vector2, folga: float) -> Vector2:
	for _tentativa in 300:
		var pos := Vector2(
			randf_range(MARGEM + tamanho.x / 2.0, TAMANHO_MAPA.x - MARGEM - tamanho.x / 2.0),
			randf_range(MARGEM + tamanho.y / 2.0, TAMANHO_MAPA.y - MARGEM - tamanho.y / 2.0))
		var area := Rect2(pos - tamanho / 2.0, tamanho)
		var livre := true
		for outro in ocupados:
			if outro.intersects(area.grow(folga)):
				livre = false
				break
		if livre:
			ocupados.append(area)
			return pos
	return Vector2(-1, -1)


# ---------- Interface ----------

func _atualizar_contador() -> void:
	hud_contador.text = "Frases boas: %d/%d" % [boas_pegas, boas_total]


# ---------- Fim de jogo ----------

func _ao_pegar_frase_boa() -> void:
	boas_pegas += 1
	_atualizar_contador()
	if boas_pegas >= boas_total:
		_vitoria()


func _game_over() -> void:
	terminou = true
	hud_mensagem.text = MSG_GAME_OVER
	await get_tree().create_timer(3.0).timeout
	_recomecar()


## Juntou todas as frases boas: a névoa se dissipa e o mundo recupera a cor.
func _vitoria() -> void:
	terminou = true
	menina.iluminar()
	for no in cenario.get_children():
		var frase := no as Frase
		if frase and not frase.boa:
			frase.queue_free()

	menina.nevoa.dissipar(3.0)
	var t := create_tween()
	t.tween_property(tom, "color", Color.WHITE, 3.0)
	for par in sprites_cenario:
		var sprite: Sprite2D = par[0]
		sprite.texture = load(par[1])

	hud_mensagem.text = MSG_VITORIA
	await get_tree().create_timer(4.0).timeout
	hud_mensagem.text = MSG_VITORIA + "\n\n(Enter para jogar de novo)"


func _recomecar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------- Controles ----------

func _configurar_controles() -> void:
	for acao in CONTROLES:
		if InputMap.has_action(acao):
			continue
		InputMap.add_action(acao)
		for tecla in CONTROLES[acao]:
			var evento := InputEventKey.new()
			evento.physical_keycode = tecla
			InputMap.action_add_event(acao, evento)
