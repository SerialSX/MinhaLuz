class_name Frase
extends Area2D
## Uma frase no chão. As boas brilham através da névoa e aumentam a luz;
## as ruins só aparecem dentro da bolha e tiram luz.
## Cada frase sabe o seu par do banco (DadosFases.PARES): pegar a boa dissolve
## as ruins do mesmo par (quem faz isso é scripts/fase.gd).
## Tipos de frase ruim (Ideia 2):
## - parada: fica no lugar;
## - errante: flutua devagar perto de onde nasceu, nunca persegue;
## - caminho: ida e volta, círculo ou zigue-zague, e só anda quando a menina está
##   no último hit (treme e escurece 1 s antes de andar).
## Os nós (Texto e Colisao) ficam na cena cenas/frase.tscn.
## Ver Ideias/02_frases_ruins.md.

signal pega(frase: Frase)   ## uma frase boa foi pega

const COR_BOA := Color(1.0, 0.9, 0.5)      # amarelo, como os elásticos da menina
const COR_RUIM := Color(0.62, 0.5, 0.68)   # roxo apagado
const VELOCIDADE := 24.0                   # 40% da velocidade da menina (60)
const RAIO_ERRANTE := 40.0                 # a errante flutua até essa distância de onde nasceu
const TEMPO_AVISO := 1.0                   # treme e escurece antes de andar
const TEMPO_ESCONDIDA := 5.0               # depois de um hit; pisca no último segundo

@export var boa := true
@export var texto := "Eu consigo tentar de novo"
var par := 0                  # índice em DadosFases.PARES
var tipo := "parada"          # frases ruins: "parada", "errante" ou "caminho"
var comprimento := 90.0       # largura do caminho (a altura é a metade)
var menina: Menina            # para saber quando ela está no último hit

var casa := Vector2.ZERO      # onde a frase nasceu
var pontos: Array[Vector2] = []   # o caminho, relativo à casa
var alvo := 0
var destino := Vector2.ZERO   # errante: para onde está flutuando
var tempo_destino := 0.0
var acordada := false         # caminho: andando
var aviso := -1.0             # caminho: tempo de aviso que falta (-1 = sem aviso)
var escondida := false        # some depois de um hit: não acerta ninguém
var dissolvendo := false
var anim_sumir: Tween
var tamanho_texto := Vector2.ZERO

static var ultimo_aviso_ms := -1000   # várias frases acordam juntas: um som só

@onready var label: Label = $Texto
@onready var colisao: CollisionShape2D = $Colisao


func configurar(e_boa: bool, frase: String, n_par: int, n_tipo := "parada", n_comprimento := 90.0) -> Frase:
	boa = e_boa
	texto = frase
	par = n_par
	tipo = n_tipo
	comprimento = n_comprimento
	return self


func _ready() -> void:
	# Cada frase tem a sua cópia do estilo, para mudar a cor sem afetar as outras.
	var estilo: LabelSettings = label.label_settings.duplicate()
	estilo.font_color = COR_BOA if boa else COR_RUIM
	label.label_settings = estilo
	label.text = texto
	z_index = 60 if boa else 15   # névoa = 50: as boas brilham no escuro, as ruins só na bolha

	# Centraliza o texto e ajusta a colisão ao tamanho dele (com a fonte do tema).
	tamanho_texto = label.get_minimum_size()
	label.position = -tamanho_texto / 2.0
	var forma := RectangleShape2D.new()
	forma.size = tamanho_texto + Vector2(4, 4)
	colisao.shape = forma

	body_entered.connect(_ao_encostar)

	if boa:
		# brilho suave, pulsando devagar, e faíscas douradas
		var t := create_tween().set_loops()
		t.tween_property(label, "modulate", Color(1.3, 1.3, 1.3), 0.9)
		t.tween_property(label, "modulate", Color(1.0, 1.0, 1.0), 0.9)
		_particulas(COR_BOA, 6).emitting = true
	elif tipo == "caminho":
		_criar_caminho()
	set_physics_process(not boa and tipo != "parada")


## Coloca a frase no mapa: o lugar vira a "casa" dela.
func colocar(pos: Vector2) -> void:
	position = pos
	casa = pos
	destino = pos


## Espaço que a frase precisa no mapa: o texto e o quanto ela anda.
func area() -> Vector2:
	if boa:
		return tamanho_texto
	match tipo:
		"errante":
			return tamanho_texto + Vector2.ONE * RAIO_ERRANTE * 2.0
		"caminho":
			return tamanho_texto + Vector2(comprimento, comprimento * 0.5)
	return tamanho_texto


func _physics_process(delta: float) -> void:
	if tipo == "errante":
		_errar(delta)
	elif menina:
		_seguir_caminho(delta)


func _errar(delta: float) -> void:
	tempo_destino -= delta
	if tempo_destino <= 0.0:
		destino = casa + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * RAIO_ERRANTE
		tempo_destino = randf_range(2.0, 4.0)
	position = position.move_toward(destino, VELOCIDADE * delta)


func _seguir_caminho(delta: float) -> void:
	# Só anda no último hit (mais um hit apagaria a luz). Saiu dele: para de novo.
	if not menina.ativa or menina.luz > menina.dano_frase_ruim:
		if acordada or aviso >= 0.0:
			acordada = false
			aviso = -1.0
			_parar_aviso()
		return

	if not acordada:
		if aviso < 0.0:
			aviso = TEMPO_AVISO
			_tocar_aviso()
		aviso -= delta
		label.position = -tamanho_texto / 2.0 + Vector2(randf_range(-1.0, 1.0), 0.0)
		label.modulate = Color(0.5, 0.5, 0.5)
		if aviso <= 0.0:
			acordada = true
			_parar_aviso()
		return

	var ponto := casa + pontos[alvo]
	position = position.move_toward(ponto, VELOCIDADE * delta)
	if position == ponto:
		alvo = (alvo + 1) % pontos.size()


## Ida e volta, círculo ou zigue-zague, dentro de comprimento × (comprimento / 2).
func _criar_caminho() -> void:
	var meio := Vector2(comprimento, comprimento * 0.5) / 2.0
	match randi() % 3:
		0:
			pontos = [Vector2(-meio.x, 0.0), Vector2(meio.x, 0.0)]
		1:
			for i in 12:
				var angulo := TAU * i / 12.0
				pontos.append(Vector2(cos(angulo) * meio.x, sin(angulo) * meio.y))
		_:
			for i in 5:
				pontos.append(Vector2(lerpf(-meio.x, meio.x, i / 4.0), meio.y if i % 2 == 1 else -meio.y))
			for i in range(3, 0, -1):
				pontos.append(pontos[i])


func _tocar_aviso() -> void:
	var agora := Time.get_ticks_msec()
	if agora - ultimo_aviso_ms > 500:
		ultimo_aviso_ms = agora
		Audio.tocar_sfx("aviso")


func _parar_aviso() -> void:
	label.position = -tamanho_texto / 2.0
	label.modulate = Color.WHITE


func _ao_encostar(corpo: Node2D) -> void:
	# A frase escondida (ou dissolvendo) não acerta; e quando ela volta, a menina
	# parada em cima não leva outro hit, porque body_entered só dispara ao entrar.
	if not (corpo is Menina) or escondida or dissolvendo:
		return
	var a_menina := corpo as Menina
	if not a_menina.ativa:
		return
	if boa:
		a_menina.pegar_frase_boa()
		pega.emit(self)
		queue_free()
	elif a_menina.levar_frase_ruim():
		_sumir()


## Some por 5 s depois de um hit, piscando (2 vezes por segundo) no último segundo.
func _sumir() -> void:
	escondida = true
	hide()
	var t := create_tween()
	anim_sumir = t
	t.tween_interval(TEMPO_ESCONDIDA - 1.0)
	t.tween_callback(show)
	for i in 2:
		t.tween_property(self, "modulate:a", 0.25, 0.25)
		t.tween_property(self, "modulate:a", 1.0, 0.25)
	t.tween_callback(_voltar)


func _voltar() -> void:
	escondida = false


## Pegaram a frase boa do mesmo par: a ruim se desfaz em partículas.
func dissolver() -> void:
	if dissolvendo:
		return
	dissolvendo = true
	set_physics_process(false)
	# Escondida depois de um hit: aparece para se desfazer junto com as outras.
	if anim_sumir:
		anim_sumir.kill()
	show()
	modulate.a = 1.0
	var particulas := _particulas(COR_RUIM, 16)
	particulas.one_shot = true
	particulas.explosiveness = 0.8
	particulas.emitting = true
	var t := create_tween()
	t.tween_property(label, "modulate:a", 0.0, 0.8)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)


func _particulas(cor: Color, quantidade: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = quantidade
	p.lifetime = 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = tamanho_texto / 2.0
	p.direction = Vector2.UP
	p.spread = 60.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 10.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var rampa := Gradient.new()   # some aos poucos
	rampa.set_color(0, cor)
	rampa.set_color(1, Color(cor, 0.0))
	p.color_ramp = rampa
	add_child(p)
	return p
