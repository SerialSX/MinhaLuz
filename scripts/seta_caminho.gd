class_name SetaCaminho
extends Node2D
## Poder "Procurar": uma seta dourada ao lado da menina aponta para o alvo
## (a frase boa mais perto, ou a nuvem quando todas já foram pegas), com uma
## trilha de pontinhos mostrando o caminho. Pisca devagar (1,5 vez por segundo:
## a regra do time é no máximo 2, nunca clarão) e some depois de `duracao` segundos.
## Fica na camada do HUD (Hud.mostrar_seta), por cima da névoa e sem o tom
## apagado do mundo; a posição acompanha a menina na tela.

const PISCADAS_POR_SEGUNDO := 1.5
const DISTANCIA_PONTA := 38.0                # da menina até a ponta da seta
const PONTOS := [14.0, 21.0, 28.0]           # trilha entre a menina e a seta
const COR := Color(1.0, 0.878, 0.541)        # dourado claro do HUD
const COR_CONTORNO := Color(0.16, 0.09, 0.02)

var menina: Node2D
var alvo: Node2D
var duracao := 3.0   # 0 ou menos: fica até alguém tirar (Hud.esconder_seta)
var tempo := 0.0


func _ready() -> void:
	_seguir()


func _process(delta: float) -> void:
	tempo += delta
	if (duracao > 0.0 and tempo >= duracao) or not is_instance_valid(alvo) or not is_instance_valid(menina):
		queue_free()
		return
	_seguir()
	# Pisca devagar e some suave no fim.
	var brilho := 0.75 + 0.25 * cos(tempo * TAU * PISCADAS_POR_SEGUNDO)
	modulate.a = brilho * (minf(1.0, (duracao - tempo) / 0.4) if duracao > 0.0 else 1.0)
	queue_redraw()


func _seguir() -> void:
	position = menina.get_global_transform_with_canvas().origin   # posição na tela
	rotation = (alvo.global_position - menina.global_position).angle()


func _draw() -> void:
	# Pontinhos acendendo um depois do outro, na direção do alvo.
	for i in PONTOS.size():
		var onda := fmod(tempo * PISCADAS_POR_SEGUNDO - i / float(PONTOS.size()) + 1.0, 1.0)
		var cor := Color(COR, 1.0 if onda < 0.5 else 0.6)
		draw_rect(Rect2(PONTOS[i] - 3.0, -3.0, 6.0, 6.0), COR_CONTORNO)
		draw_rect(Rect2(PONTOS[i] - 2.0, -2.0, 4.0, 4.0), cor)
	# Ponta da seta: triângulo com contorno escuro.
	var d := DISTANCIA_PONTA
	draw_colored_polygon(PackedVector2Array([Vector2(d + 3, 0), Vector2(d - 10, -9), Vector2(d - 10, 9)]), COR_CONTORNO)
	draw_colored_polygon(PackedVector2Array([Vector2(d, 0), Vector2(d - 8, -6), Vector2(d - 8, 6)]), COR)
