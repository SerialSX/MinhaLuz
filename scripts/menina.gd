class_name Menina
extends CharacterBody2D
## A personagem: movimento nas 4 direções, animações e a luz (vida).
## Os nós (Sprite, Colisao, Camera e Nevoa) ficam na cena cenas/menina.tscn.
## As animações ficam em assets/sprites/personagem/menina_animacoes.tres.
## Ver Tarefas/02, 04 e 05 e Ideias/01_luz_diminui.md.

signal apagou   ## a luz chegou a zero: game over
signal ferida   ## levou um hit e ainda tem luz (a fase toca o som e a piscada)

@export var velocidade := 60.0       # pixels por segundo (tela de 480x270)

# Luz (Ideia 1)
@export var luz_max := 100.0
@export var luz_min := 15.0          # a queda natural para aqui: nunca apaga sozinha
@export var queda_base := 0.6        # por segundo, na fase 1
@export var mult_andando := 0.6      # andando, cai mais devagar
@export var mult_parada := 1.5       # parada, cai mais rápido
@export var mult_fase := 1.0         # 1,0 / 1,4 / 1,9 (campo, escola, beco); a fase define
@export var luz_baixa := 30.0        # daqui para baixo a bolha pulsa

# Frases (Tarefa 05 e Ideia 2)
@export var frase_boa := 12.0
@export var dano_frase_ruim := 25.0  # 4 hits com a luz cheia
@export var tempo_protecao := 5.0

# Tamanho da bolha, em fração da altura da tela (Tarefa 04)
@export var raio_min := 0.06
@export var raio_max := 0.20

var tamanho_mapa := DadosFases.TAMANHO_MAPA

const BORDA := 10.0                  # metade do sprite: a menina fica inteira dentro do mapa

var luz := 100.0
var direcao := "baixo"
var protegida := false
var ativa := true                    # false no game over
var luz_congelada := false           # true na vitória: a luz não cai mais
var tempo := 0.0                     # para o pulso da bolha (para junto com a pausa)

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera
@onready var nevoa: Nevoa = $Camera/Nevoa


func _ready() -> void:
	luz = luz_max
	camera.limit_right = int(tamanho_mapa.x)
	camera.limit_bottom = int(tamanho_mapa.y)
	camera.make_current()
	nevoa.menina = self
	sprite.play("parada_baixo")


func _physics_process(delta: float) -> void:
	if not ativa:
		return
	tempo += delta

	var entrada := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	var antes := position
	velocity = entrada * velocidade
	move_and_slide()
	position = position.clamp(Vector2.ONE * BORDA, tamanho_mapa - Vector2.ONE * BORDA)

	# "Andando" é o movimento de verdade: empurrando uma parede ela está parada.
	var movimento := position - antes
	var andando := movimento.length() > 0.01
	if andando:
		if absf(movimento.x) > absf(movimento.y):
			direcao = "direita" if movimento.x > 0.0 else "esquerda"
		else:
			direcao = "baixo" if movimento.y > 0.0 else "cima"
	sprite.play(("andando_" if andando else "parada_") + direcao)

	# Ideia 1: a luz cai devagar, mais rápido parada e a cada fase, e para no mínimo.
	if not luz_congelada and luz > luz_min:
		var taxa: float = queda_base * mult_fase * (mult_andando if andando else mult_parada)
		luz = maxf(luz - taxa * delta, luz_min)


func raio_da_bolha() -> float:
	var raio := lerpf(raio_min, raio_max, clampf(luz / luz_max, 0.0, 1.0))
	if luz <= luz_baixa and ativa and not luz_congelada:
		raio *= 1.0 + 0.1 * sin(tempo * TAU / 1.2)   # pulsa devagar, como um coração
	return raio


func pegar_frase_boa() -> void:
	luz = minf(luz + frase_boa, luz_max)


## Retorna true se o hit valeu (a menina não estava protegida).
func levar_frase_ruim() -> bool:
	if protegida or not ativa or luz_congelada:
		return false
	luz -= dano_frase_ruim
	if luz <= 0.0:
		luz = 0.0
		ativa = false
		sprite.play("parada_" + direcao)
		apagou.emit()
		return true
	_proteger()
	ferida.emit()
	return true


## Encher a luz e parar a queda (usado na vitória).
func iluminar() -> void:
	luz_congelada = true
	var t := create_tween()
	t.tween_property(self, "luz", luz_max, 2.0)


## Proteção depois do hit: a menina pisca 2 vezes por segundo, no máximo (Ideia 3).
func _proteger() -> void:
	protegida = true
	var vezes := maxi(int(tempo_protecao / 0.5), 1)   # set_loops(0) seria infinito
	var t := create_tween().set_loops(vezes)
	t.tween_property(sprite, "modulate:a", 0.3, 0.25)
	t.tween_property(sprite, "modulate:a", 1.0, 0.25)
	t.finished.connect(_fim_da_protecao)


func _fim_da_protecao() -> void:
	sprite.modulate.a = 1.0
	protegida = false
