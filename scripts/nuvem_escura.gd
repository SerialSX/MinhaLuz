class_name NuvemEscura
extends Area2D
## A nuvem escura: a névoa que se juntou depois da última frase boa da fase.
## Só aparece nesse momento (surgir). Quando a menina encosta, começa o final
## da fase (scripts/fase.gd e scripts/final_fase.gd): a nuvem se abre e, no fim,
## sobe e some. Os nós (Sprite e Colisao) ficam na cena cenas/nuvem_escura.tscn.

signal tocada   ## a menina encostou (uma vez só)

const TEXTURA := "res://assets/sprites/nuvem/nuvem_escura_nativa.png"
const ESCALA := 2.0
const TEMPO_SURGIR := 1.5

var pronta := false      # só vale encostar depois de surgir por inteiro
var avisou := false
var balanco: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var colisao: CollisionShape2D = $Colisao


func _ready() -> void:
	if ResourceLoader.exists(TEXTURA):
		sprite.texture = load(TEXTURA)
		sprite.scale = Vector2.ONE * ESCALA
		var forma := RectangleShape2D.new()
		forma.size = sprite.texture.get_size() * ESCALA * 0.8
		colisao.shape = forma


## Aparece crescendo devagar (sem susto), e depois fica pulsando para chamar a menina.
func surgir() -> void:
	scale = Vector2.ONE * 0.6
	modulate.a = 0.0
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, TEMPO_SURGIR)
	t.tween_property(self, "modulate:a", 1.0, TEMPO_SURGIR)
	t.chain().tween_callback(_ficar_pronta)


func _ficar_pronta() -> void:
	pronta = true
	balanco = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	balanco.tween_property(self, "scale", Vector2.ONE * 1.1, 0.7)
	balanco.tween_property(self, "scale", Vector2.ONE, 0.7)


## Confere a cada quadro (e não só no sinal de entrada): a menina pode já estar
## dentro da nuvem quando ela termina de surgir.
func _physics_process(_delta: float) -> void:
	if not pronta or avisou:
		return
	for corpo in get_overlapping_bodies():
		if corpo is Menina:
			avisou = true
			tocada.emit()
			return


## O final começou: a nuvem se abre e fica fraquinha atrás das palavras.
func abrir() -> void:
	if balanco:
		balanco.kill()
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE * 1.4, 1.0)
	t.tween_property(self, "modulate:a", 0.4, 1.0)


## O final acabou: o que sobrou da nuvem sobe e some.
func subir() -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(self, "position:y", position.y - 50.0, 1.8)
	t.tween_property(self, "modulate:a", 0.0, 1.8)
	t.chain().tween_callback(queue_free)
