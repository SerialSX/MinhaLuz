class_name Frase
extends Area2D
## Uma frase no chão.
## - Boa: fica parada, escondida na névoa (só aparece dentro da bolha de luz).
##   Pegar aumenta a luz; o resto é com scripts/fase.gd.
## - Ruim ("seguidora"): dorme escondida na névoa. Quando entra na tela, acorda
##   (treme 1 s, com um som de aviso), passa a aparecer por cima da névoa e vem
##   atrás da menina de pouquinho em pouquinho: agacha, dá um passinho, descansa.
##   Fora da tela por um tempo, dorme onde está. Só a frase acordada e andando machuca.
## Cada frase sabe o seu par do banco (DadosFases.PARES): pegar a boa desfaz
## as ruins do mesmo par (quem faz isso é scripts/fase.gd).
## Os nós (Texto e Colisao) ficam na cena cenas/frase.tscn.

signal pega(frase: Frase)   ## uma frase boa foi pega

enum Estado { DORMINDO, AVISANDO, SEGUINDO }

const COR_BOA := Color(1.0, 0.9, 0.5)      # amarelo, como os elásticos da menina
const COR_RUIM := Color(0.62, 0.5, 0.68)   # roxo apagado
const COR_FUNDO_RUIM := Color(0.13, 0.09, 0.19, 0.9)
const Z_DORMINDO := 15          # abaixo da névoa (50): só aparece dentro da bolha de luz
const MARGEM_TELA := 24.0       # acorda quando está este tanto para dentro da tela
const TEMPO_AVISO := 1.0        # treme antes de começar a seguir
const AGACHA := 0.15            # cada passinho: agacha...
const PASSO_ANDA := 0.5         # ...anda este tempo...
const PASSO_PARA := 0.7         # ...e descansa este
const TEMPO_FORA := 3.0         # fora da tela por este tempo: dorme onde está
const RAIO_ESPANTO := 90.0      # um hit espanta todas as seguidoras até esta distância...
const EMPURRAO_HIT := 50.0      # ...este tanto para longe...
const SONO_HIT := 5.0           # ...e elas dormem o tempo da proteção da menina

# Combinado entre todas as seguidoras da fase (scripts/fase.gd define e zera).
static var acordadas := 0          # quantas estão acordadas agora
static var max_acordadas := 2
static var liberadas := false      # false nos primeiros segundos da fase e depois da última frase boa
static var ultimo_aviso_ms := -1000   # várias acordam juntas: um som só

@export var boa := true
@export var texto := "Eu consigo tentar de novo"
var par := 0                    # índice em DadosFases.PARES
var passo := 50.0               # px/s durante o passinho (a fase define)
var mapa := Vector2(1536, 864)  # a fase define
var menina: Menina

var estado := Estado.DORMINDO
var relogio := 0.0              # tempo no estado atual
var fora := 0.0                 # há quanto tempo está fora da tela
var sono := 0.0                 # enquanto for maior que zero, não acorda
var dissolvendo := false
var tamanho_texto := Vector2.ZERO
var deslocamento := Vector2.ZERO   # cada uma mira um pouco ao lado da menina: cercam, não empilham
var zzz: Label

@onready var label: Label = $Texto
@onready var colisao: CollisionShape2D = $Colisao


func configurar(e_boa: bool, frase: String, n_par: int) -> void:
	boa = e_boa
	texto = frase
	par = n_par


func _ready() -> void:
	# Cada frase tem a sua cópia do estilo, para mudar a cor sem afetar as outras.
	var estilo: LabelSettings = label.label_settings.duplicate()
	estilo.font_color = COR_BOA if boa else COR_RUIM
	label.label_settings = estilo
	label.text = texto
	z_index = Z_DORMINDO

	# Centraliza o texto e ajusta a colisão ao tamanho dele (com a fonte do tema).
	tamanho_texto = label.get_minimum_size()
	label.position = -tamanho_texto / 2.0
	label.pivot_offset = tamanho_texto / 2.0
	var forma := RectangleShape2D.new()
	# A ruim acerta só pelo miolo do texto: dá para desviar por cima e por baixo.
	forma.size = tamanho_texto + Vector2(4, 4) if boa else Vector2(tamanho_texto.x * 0.7, 8.0)
	colisao.shape = forma

	if boa:
		body_entered.connect(_ao_encostar)
		# brilho suave, pulsando devagar, e faíscas douradas
		var t := create_tween().set_loops()
		t.tween_property(label, "modulate", Color(1.3, 1.3, 1.3), 0.9)
		t.tween_property(label, "modulate", Color(1.0, 1.0, 1.0), 0.9)
		_particulas(COR_BOA, 6).emitting = true
	else:
		add_to_group("seguidoras")
		deslocamento = Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))
		zzz = Label.new()
		zzz.text = "Zzz"
		zzz.add_theme_font_size_override("font_size", 8)
		zzz.add_theme_color_override("font_color", COR_RUIM)
		zzz.position = Vector2(tamanho_texto.x / 2.0 - 4.0, -tamanho_texto.y / 2.0 - 9.0)
		add_child(zzz)
	set_physics_process(not boa)


func _exit_tree() -> void:
	if estado != Estado.DORMINDO:
		acordadas -= 1
		estado = Estado.DORMINDO


## Código visual do jogo: ruim = roxo com borda pontuda (atrás do texto).
func _draw() -> void:
	if boa or dissolvendo:
		return
	var meio := tamanho_texto / 2.0 + Vector2(3.0, 0.0)
	var pontos := PackedVector2Array()
	var dentes := maxi(int(meio.x * 2.0 / 6.0), 2)
	for i in dentes + 1:   # em cima, da esquerda para a direita
		var x := lerpf(-meio.x, meio.x, i / float(dentes))
		pontos.append(Vector2(x, -meio.y))
		if i < dentes:
			pontos.append(Vector2(x + meio.x / dentes, -meio.y - 3.0))
	for i in dentes + 1:   # embaixo, da direita para a esquerda
		var x := lerpf(meio.x, -meio.x, i / float(dentes))
		pontos.append(Vector2(x, meio.y))
		if i < dentes:
			pontos.append(Vector2(x - meio.x / dentes, meio.y + 3.0))
	draw_colored_polygon(pontos, COR_FUNDO_RUIM)
	pontos.append(pontos[0])
	draw_polyline(pontos, COR_RUIM, 1.0)


func _physics_process(delta: float) -> void:
	if dissolvendo or menina == null:
		return
	relogio += delta
	sono = maxf(sono - delta, 0.0)
	var na_tela := _na_tela()
	match estado:
		Estado.DORMINDO:
			var pode := liberadas and acordadas < max_acordadas and menina.ativa and not menina.protegida
			if na_tela and sono <= 0.0 and pode:
				_mudar(Estado.AVISANDO)
				_tocar_aviso()
		Estado.AVISANDO:
			label.position = -tamanho_texto / 2.0 + Vector2(randf_range(-1.0, 1.0), 0.0)
			if relogio >= TEMPO_AVISO:
				_mudar(Estado.SEGUINDO)
		Estado.SEGUINDO:
			_seguir(delta)
			fora = 0.0 if na_tela else fora + delta
			if fora >= TEMPO_FORA or not menina.ativa or not liberadas:
				dormir(0.0)


## De pouquinho em pouquinho: agacha, dá um passinho, descansa.
## Espera a proteção da menina acabar e não entra em lugar seguro.
func _seguir(delta: float) -> void:
	var t := fmod(relogio, AGACHA + PASSO_ANDA + PASSO_PARA)
	label.scale.y = 0.75 if t < AGACHA else 1.0
	if menina.protegida:
		return
	if t >= AGACHA and t < AGACHA + PASSO_ANDA:
		var destino := global_position.move_toward(menina.global_position + deslocamento, passo * delta)
		if not Refugio.protege(destino):
			global_position = destino
	if overlaps_body(menina) and menina.levar_frase_ruim():
		# Nunca hit em cadeia: todas as que estão perto se afastam e dormem um pouco.
		get_tree().call_group("seguidoras", "espantar", menina.global_position, RAIO_ESPANTO, EMPURRAO_HIT, SONO_HIT)


func _na_tela() -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return false
	var d := (global_position - camera.get_screen_center_position()).abs()
	var meia_tela := get_viewport_rect().size / 2.0
	return d.x < meia_tela.x - MARGEM_TELA and d.y < meia_tela.y - MARGEM_TELA


func _mudar(novo: Estado) -> void:
	var estava := estado != Estado.DORMINDO
	var esta := novo != Estado.DORMINDO
	if esta != estava:
		acordadas += 1 if esta else -1
	estado = novo
	relogio = 0.0
	fora = 0.0
	# Acordada, aparece por cima da névoa: perigo nunca é invisível.
	z_index = Nevoa.Z_NA_NEVOA if esta else Z_DORMINDO
	z_as_relative = not esta
	zzz.visible = not esta
	label.scale.y = 1.0
	label.position = -tamanho_texto / 2.0


## Dorme onde está por pelo menos `tempo` segundos.
func dormir(tempo: float) -> void:
	if boa or dissolvendo:
		return
	sono = maxf(sono, tempo)
	if estado != Estado.DORMINDO:
		_mudar(Estado.DORMINDO)


## Se estiver a até `raio` de `origem`, é empurrada `distancia` para longe e dorme `tempo`.
## Usado no hit e no poder Brilhar. Retorna true se foi espantada.
func espantar(origem: Vector2, raio: float, distancia: float, tempo: float) -> bool:
	if boa or dissolvendo or global_position.distance_to(origem) > raio:
		return false
	var direcao := origem.direction_to(global_position)
	if direcao == Vector2.ZERO:
		direcao = Vector2.RIGHT
	var destino := (global_position + direcao * distancia).clamp(Vector2.ZERO, mapa)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", destino, 0.35)
	dormir(tempo)
	return true


func _tocar_aviso() -> void:
	var agora := Time.get_ticks_msec()
	if agora - ultimo_aviso_ms > 500:
		ultimo_aviso_ms = agora
		Audio.tocar_sfx("aviso")


func _ao_encostar(corpo: Node2D) -> void:
	var a_menina := corpo as Menina
	if a_menina and a_menina.ativa:
		a_menina.pegar_frase_boa()
		pega.emit(self)
		queue_free()


## Pegaram a frase boa do mesmo par: a ruim se desfaz em partículas.
func dissolver() -> void:
	if dissolvendo:
		return
	_parar()
	var particulas := _particulas(COR_RUIM, 16)
	particulas.one_shot = true
	particulas.explosiveness = 0.8
	particulas.emitting = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.8)
	t.tween_interval(0.8)
	t.tween_callback(queue_free)


## Depois da última frase boa: a frase ruim que sobrou voa até onde a nuvem vai nascer.
func voar_para(destino: Vector2, segundos: float) -> void:
	if dissolvendo:
		return
	_parar()
	z_index = Nevoa.Z_NA_NEVOA
	z_as_relative = false
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(self, "global_position", destino, segundos)
	t.tween_property(self, "scale", Vector2.ONE * 0.3, segundos)
	t.chain().tween_callback(queue_free)


func _parar() -> void:
	if estado != Estado.DORMINDO:
		_mudar(Estado.DORMINDO)
	dissolvendo = true
	zzz.hide()
	set_physics_process(false)


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
