class_name NuvemEscura
extends Area2D
## A nuvem escura do fim da fase. Fica acima da névoa, visível de longe.
## Encostar nela antes de juntar todas as frases boas só mostra uma dica;
## com todas, ela se dissipa e a fase termina (quem decide é scripts/fase.gd).
## Os nós (Sprite e Colisao) ficam na cena cenas/nuvem_escura.tscn.

signal tocada   ## a menina encostou

const TEXTURA := "res://assets/sprites/nuvem/nuvem_escura_nativa.png"
const ESCALA := 2.0
const TAMANHO_SEM_ARTE := Vector2(64, 40)   # desenho provisório, se a arte faltar

var dissipando := false
var pulso: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var colisao: CollisionShape2D = $Colisao


func _ready() -> void:
	if ResourceLoader.exists(TEXTURA):
		sprite.texture = load(TEXTURA)
		sprite.scale = Vector2.ONE * ESCALA
	var forma := RectangleShape2D.new()
	forma.size = tamanho() * 0.8
	colisao.shape = forma
	body_entered.connect(_ao_encostar)

	# balança devagar
	var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "position:y", position.y - 3.0, 1.5)
	t.tween_property(self, "position:y", position.y + 3.0, 1.5)


func tamanho() -> Vector2:
	if sprite.texture:
		return sprite.texture.get_size() * ESCALA
	return TAMANHO_SEM_ARTE * ESCALA


## Todas as frases boas pegas: a nuvem pulsa, chamando a menina.
func pulsar() -> void:
	pulso = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulso.tween_property(self, "scale", Vector2.ONE * 1.12, 0.6)
	pulso.tween_property(self, "scale", Vector2.ONE, 0.6)


func dissipar() -> void:
	dissipando = true
	if pulso:
		pulso.kill()
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE * 1.8, 2.0)
	t.tween_property(self, "modulate:a", 0.0, 2.0)
	t.chain().tween_callback(queue_free)


func _ao_encostar(corpo: Node2D) -> void:
	if corpo is Menina and not dissipando:
		tocada.emit()


func _draw() -> void:
	if sprite.texture:
		return
	# Sem a arte: silhueta escura com borda roxa suave.
	var bolhas := [Vector2(-34, 6), Vector2(-12, -10), Vector2(14, -8), Vector2(36, 6), Vector2(0, 10)]
	for c: Vector2 in bolhas:
		draw_circle(c, 28.0, Color(0.55, 0.4, 0.75, 0.5))
	for c: Vector2 in bolhas:
		draw_circle(c, 25.0, Color(0.12, 0.08, 0.18))
