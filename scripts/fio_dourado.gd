class_name FioDourado
extends Node2D
## Um risco dourado que sai da menina e voa até uma coisa (criança apagada ou
## frase ruim) quando ela pega a frase boa do par: mostra que foi aquela frase
## que mudou aquilo. Ao chegar, chama `ao_chegar`. Fica em SobreNevoa.

const VELOCIDADE := 220.0
const TEMPO_MAXIMO := 1.5      # mesmo de longe, não demora mais que isto
const COR := Color(1.0, 0.878, 0.541)

var alvo: Node2D
var ao_chegar: Callable
var origem := Vector2.ZERO
var destino := Vector2.ZERO
var duracao := 0.1
var tempo := 0.0


func _ready() -> void:
	origem = position
	destino = alvo.global_position
	duracao = clampf(origem.distance_to(destino) / VELOCIDADE, 0.1, TEMPO_MAXIMO)


func _process(delta: float) -> void:
	tempo += delta
	if is_instance_valid(alvo):
		destino = alvo.global_position   # o alvo pode estar andando
	var avanco := minf(tempo / duracao, 1.0)
	position = origem.lerp(destino, avanco)
	queue_redraw()
	if avanco >= 1.0:
		if is_instance_valid(alvo) and ao_chegar.is_valid():
			ao_chegar.call()
		queue_free()


func _draw() -> void:
	# A ponta e um rastro de 4 pontinhos para trás.
	var para_tras := position.direction_to(origem)
	for n in 5:
		var p := (para_tras * n * 5.0).round()
		var lado := 3.0 if n == 0 else 2.0
		draw_rect(Rect2(p - Vector2.ONE * lado / 2.0, Vector2.ONE * lado), Color(COR, 1.0 - n * 0.2))
