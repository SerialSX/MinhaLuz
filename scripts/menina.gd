class_name Menina
extends CharacterBody2D
## A personagem: movimento, animações (vira devagar, em 16 direções, e o passo vai
## no ritmo da velocidade) e a luz (vida).
## Os nós (Sprite, Colisao, Camera e Nevoa) ficam na cena cenas/menina.tscn.
## As animações ficam em assets/sprites/personagem/menina_animacoes.tres.
## Ver Tarefas/02, 04 e 05 e Ideias/01_luz_diminui.md.

signal apagou   ## um hit levaria a luz a zero: a fase abre o "Respirar"
signal ferida   ## levou um hit e ainda tem luz (a fase toca o som e a piscada)

@export var velocidade := 90.0       # pixels por segundo (tela de 480x270)
@export var aceleracao := 700.0      # px/s²: arranca e para em ~0,13 s, sem tranco

# Luz (Ideia 1)
@export var luz_max := 100.0
@export var luz_min := 30.0          # a queda natural para aqui: sempre sobra mais de um hit
@export var queda_base := 0.6        # por segundo, na fase 1
@export var mult_andando := 0.6      # andando, cai mais devagar
@export var mult_parada := 1.5       # parada há mais de ESPERA_PARADA, cai mais rápido
@export var mult_fase := 1.0         # 1,0 / 1,4 / 1,9 (campo, escola, beco); a fase define
@export var luz_baixa := 30.0        # daqui para baixo a bolha pulsa
@export var luz_ao_levantar := 50.0  # depois de respirar

# Frases
@export var frase_boa := 12.0
@export var dano_frase_ruim := 25.0  # a fase define (15 / 20 / 25)
@export var tempo_protecao := 5.0

# Tamanho da bolha, em fração da altura da tela (Tarefa 04)
@export var raio_min := 0.07
@export var raio_max := 0.22
var raio_extra := 0.0                # a bolha abre a cada frase boa pega (a fase define)

const FOLHA_FLUIDA := "res://assets/sprites/personagem/menina_fluida_folha_nativa.png"
const FOLHA_16 := "res://assets/sprites/personagem/menina_fluida_folha16_nativa.png"   # a mesma, em 16 direções
const GIRO := 720.0                  # graus por segundo: virar 180° leva 0,25 s, passando pelas direções do meio
const GIRO_DE_COSTAS := 1080.0       # de costas para onde anda (arrancando para trás), vira mais rápido; 18° por quadro ainda mostra uma direção de cada vez
const SOLTAR_DIAGONAL := 3           # quadros: no teclado, as duas teclas da diagonal quase nunca saem juntas
const PASSO_MIN := 0.5               # o passo vai no ritmo da velocidade (speed_scale): arrancando e freando,
const PASSO_MAX := 1.15              # passos mais lentos; nunca fora destes dois
const BORDA := 10.0                  # metade do sprite: a menina fica inteira dentro do mapa
const ESPERA_PARADA := 3.0           # parar um pouco (para ler, para olhar) não custa luz a mais
const PASSO_RASTRO := 6.0            # um ponto do rastro a cada 6 px andados
const PONTOS_RASTRO := 40            # ~240 px de caminho guardado, para as amigas seguirem
const MENOS_QUEDA_POR_AMIGA := 0.15  # cada amiga segura 15% da queda da luz (até 60%)

var tamanho_mapa := Vector2(1536, 864)   # a fase define com definir_mapa()
var luz := 100.0
var angulo := PI / 2.0               # para onde ela está de frente, na tela (0 = direita, PI/2 = baixo)
var virando_para := PI / 2.0         # o ângulo até onde ela está virando (sem controle, ela termina de virar)
var desde_a_diagonal := 99           # quadros desde que o controle esteve na diagonal
var setor := 4                       # a direção mostrada, de 0 a 15 (de 22,5° em 22,5°)
var direcao := "baixo"               # a cardinal mais perto de `angulo`
var protegida := false
var ativa := true                    # false enquanto respira e nas telas de fim
var luz_congelada := false           # true depois da última frase boa: a luz não cai mais
var em_refugio := false              # dentro de um lugar seguro: a luz não cai (scripts/refugio.gd)
var amigas := 0                      # crianças que acenderam (scripts/crianca.gd soma)
var tempo := 0.0                     # para o pulso da bolha (para junto com a pausa)
var tempo_parada := 0.0
var rastro := PackedVector2Array()   # por onde ela passou; o último ponto é o mais novo
var poeira: CPUParticles2D           # poeirinha nos pés enquanto anda

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera
@onready var nevoa: Nevoa = $Camera/Nevoa


func _ready() -> void:
	luz = luz_max
	camera.make_current()
	nevoa.menina = self
	# Folha nova, com mais quadros (4 parada, 8 andando) e 16 direções: movimento mais fluido.
	if folha() != "":
		sprite.sprite_frames = Crianca.animacoes(load(folha()))
	sprite.play("parada_baixo")
	definir_mapa(tamanho_mapa)
	_criar_poeira()


## A folha da menina: a de 16 direções quando existir, senão a fluida de 4; "" sem
## nenhuma (fica a da cena, menina_animacoes.tres). O menu e a história usam a mesma.
static func folha() -> String:
	for caminho: String in [FOLHA_16, FOLHA_FLUIDA]:
		if ResourceLoader.exists(caminho):
			return caminho
	return ""


## Sombra macia embaixo dela: tira a cara de figurinha colada no chão.
func _draw() -> void:
	draw_set_transform(Vector2(1, 6), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 7.0, Color(0.0, 0.0, 0.0, 0.22))


func _criar_poeira() -> void:
	poeira = CPUParticles2D.new()
	poeira.amount = 6
	poeira.lifetime = 0.4
	poeira.local_coords = false   # a poeira fica para trás, no chão
	poeira.position = Vector2(0, 6)
	poeira.show_behind_parent = true
	poeira.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	poeira.emission_rect_extents = Vector2(4, 1)
	poeira.direction = Vector2.UP
	poeira.spread = 40.0
	poeira.gravity = Vector2.ZERO
	poeira.initial_velocity_min = 3.0
	poeira.initial_velocity_max = 8.0
	poeira.scale_amount_min = 1.0
	poeira.scale_amount_max = 2.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1.0, 1.0, 1.0, 0.35))
	rampa.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	poeira.color_ramp = rampa
	poeira.emitting = false
	add_child(poeira)


## Tamanho do mapa da fase: limita a menina e a câmera.
func definir_mapa(tamanho: Vector2) -> void:
	tamanho_mapa = tamanho
	camera.limit_right = int(tamanho.x)
	camera.limit_bottom = int(tamanho.y)


func _physics_process(delta: float) -> void:
	if not ativa:
		velocity = Vector2.ZERO
		poeira.emitting = false
		sprite.speed_scale = 1.0
		return
	tempo += delta

	var entrada := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	var antes := position
	velocity = velocity.move_toward(entrada * velocidade, aceleracao * delta)
	move_and_slide()
	position = position.clamp(Vector2.ONE * BORDA, tamanho_mapa - Vector2.ONE * BORDA)

	# "Andando" é o movimento de verdade: empurrando uma parede ela está parada.
	var movimento := position - antes
	var andando := movimento.length() > 0.01

	# Ela vira devagar para onde anda de verdade (deslizando numa parede, também),
	# passando pelas direções do meio. Freando contra o controle (meia-volta) ou
	# parada empurrando, vira para o controle. Sem controle, termina de virar para
	# onde ia; se soltou antes de dar a meia-volta, para onde ainda desliza.
	# No teclado, a tecla que fica uns quadros depois da outra, ao soltar a
	# diagonal, não conta.
	desde_a_diagonal = 0 if entrada.x != 0.0 and entrada.y != 0.0 else desde_a_diagonal + 1
	var sobra_da_diagonal := desde_a_diagonal > 0 and desde_a_diagonal <= SOLTAR_DIAGONAL
	if entrada != Vector2.ZERO and not sobra_da_diagonal:
		virando_para = movimento.angle() if andando and movimento.dot(entrada) > 0.0 else entrada.angle()
	elif entrada == Vector2.ZERO and andando and movimento.dot(Vector2.from_angle(virando_para)) < 0.0:
		virando_para = movimento.angle()
	var giro := GIRO_DE_COSTAS if andando and absf(angle_difference(angulo, movimento.angle())) > PI / 2.0 else GIRO
	angulo = wrapf(rotate_toward(angulo, virando_para, deg_to_rad(giro) * delta), -PI, PI)
	setor = Crianca.setor_do_angulo(angulo, setor, 16)
	direcao = Crianca.CARDINAIS[Crianca.setor_do_angulo(angulo, Crianca.CARDINAIS.find(direcao), 4)]

	if andando:
		tempo_parada = 0.0
		if rastro.is_empty() or rastro[-1].distance_to(position) >= PASSO_RASTRO:
			rastro.append(position)
			if rastro.size() > PONTOS_RASTRO:
				rastro.remove_at(0)
	else:
		tempo_parada += delta
	# O passo vai no ritmo da velocidade de verdade: arrancando e freando, passos mais lentos.
	sprite.speed_scale = clampf(movimento.length() / delta / velocidade, PASSO_MIN, PASSO_MAX) if andando else 1.0
	Crianca.tocar(sprite, andando, setor, direcao)
	poeira.emitting = andando

	# Ideia 1: a luz cai devagar, mais rápido a cada fase, e para no mínimo.
	# Amigas seguram a queda; num lugar seguro ela não cai.
	if not luz_congelada and not em_refugio and luz > luz_min:
		var ritmo := mult_andando if andando else (mult_parada if tempo_parada >= ESPERA_PARADA else 1.0)
		var com_amigas := maxf(1.0 - MENOS_QUEDA_POR_AMIGA * amigas, 0.4)
		luz = maxf(luz - queda_base * mult_fase * ritmo * com_amigas * delta, luz_min)


func raio_da_bolha() -> float:
	var raio := lerpf(raio_min, raio_max, clampf(luz / luz_max, 0.0, 1.0)) + raio_extra
	if luz <= luz_baixa and ativa and not luz_congelada:
		raio *= 1.0 + 0.1 * sin(tempo * TAU / 1.2)   # pulsa devagar, como um coração
	return raio


## Ponto do caminho por onde a menina passou, `distancia` pixels atrás dela.
## As amigas em fila usam isto para seguir sem bater em nada.
func ponto_do_rastro(distancia: float) -> Vector2:
	var anterior := global_position
	var falta := distancia
	for i in range(rastro.size() - 1, -1, -1):
		var trecho := anterior.distance_to(rastro[i])
		if trecho >= falta:
			return anterior.move_toward(rastro[i], falta)
		falta -= trecho
		anterior = rastro[i]
	return anterior


func pegar_frase_boa() -> void:
	luz = minf(luz + frase_boa, luz_max)


## Retorna true se o hit valeu (a menina não estava protegida).
func levar_frase_ruim() -> bool:
	if protegida or not ativa or luz_congelada:
		return false
	luz -= dano_frase_ruim
	if luz <= 0.0:
		# A luz não apaga: fica um fiozinho, e a menina para para respirar.
		luz = 1.0
		ativa = false
		sprite.speed_scale = 1.0
		Crianca.tocar(sprite, false, setor, direcao)
		apagou.emit()
		return true
	_proteger()
	ferida.emit()
	return true


## Depois de respirar: levanta com luz e alguns segundos de proteção.
func levantar() -> void:
	luz = maxf(luz, luz_ao_levantar)
	ativa = true
	_proteger()


## Encher a luz e parar a queda (depois da última frase boa da fase).
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
