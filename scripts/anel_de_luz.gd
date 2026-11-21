class_name AnelDeLuz
extends Node2D
## Anel dourado que se abre e some (poder Brilhar). Fica em SobreNevoa, por
## cima da névoa. Cresce uma vez, devagar o bastante para não ser um clarão.

const COR := Color(1.0, 0.85, 0.45)

var raio_final := 85.0
var duracao := 0.5
var tempo := 0.0


func _process(delta: float) -> void:
	tempo += delta
	if tempo >= duracao + 0.25:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var avanco := minf(tempo / duracao, 1.0)
	var raio := raio_final * (1.0 - (1.0 - avanco) * (1.0 - avanco))   # abre rápido e desacelera
	var some := 1.0 - clampf((tempo - duracao) / 0.25, 0.0, 1.0)
	draw_circle(Vector2.ZERO, raio, Color(COR, 0.12 * some))
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 48, Color(COR, 0.9 * some), 2.0)
	draw_arc(Vector2.ZERO, raio * 0.82, 0.0, TAU, 48, Color(COR, 0.4 * some), 1.0)
