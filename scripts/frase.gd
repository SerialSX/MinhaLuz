class_name Frase
extends Area2D
## Uma frase no chão. As boas brilham através da névoa e aumentam a luz;
## as ruins só aparecem dentro da bolha e tiram luz.
## Os nós (Texto e Colisao) ficam na cena cenas/frase.tscn.
## Ver Tarefas/05_frases_e_game_over.md e Ideias/02_frases_ruins.md.

signal pega   ## uma frase boa foi pega

const COR_BOA := Color(1.0, 0.9, 0.5)      # amarelo, como os elásticos da menina
const COR_RUIM := Color(0.62, 0.5, 0.68)   # roxo apagado

@export var boa := true
@export var texto := "Você é importante"

@onready var label: Label = $Texto
@onready var colisao: CollisionShape2D = $Colisao


func configurar(e_boa: bool, frase: String) -> Frase:
	boa = e_boa
	texto = frase
	return self


func _ready() -> void:
	# Cada frase tem a sua cópia do estilo, para mudar a cor sem afetar as outras.
	var estilo: LabelSettings = label.label_settings.duplicate()
	if boa:
		estilo.font_color = COR_BOA
		z_index = 60    # acima da névoa: brilha no escuro
	else:
		estilo.font_color = COR_RUIM
		z_index = 5     # abaixo da névoa: só aparece dentro da bolha
	label.label_settings = estilo
	label.text = texto

	# Centraliza o texto e ajusta a colisão ao tamanho dele.
	var tamanho := ThemeDB.fallback_font.get_string_size(
		texto, HORIZONTAL_ALIGNMENT_LEFT, -1, estilo.font_size)
	label.position = -tamanho / 2.0
	var forma := RectangleShape2D.new()
	forma.size = tamanho + Vector2(4, 4)
	colisao.shape = forma

	body_entered.connect(_ao_encostar)

	if boa:
		# brilho suave, pulsando devagar
		var t := create_tween().set_loops()
		t.tween_property(label, "modulate", Color(1.3, 1.3, 1.3), 0.9)
		t.tween_property(label, "modulate", Color(1.0, 1.0, 1.0), 0.9)


func _ao_encostar(corpo: Node2D) -> void:
	if not (corpo is Menina):
		return
	var menina := corpo as Menina
	if boa:
		menina.pegar_frase_boa()
		pega.emit()
		queue_free()
	elif menina.levar_frase_ruim():
		_sumir_por(menina.tempo_protecao)


func _sumir_por(segundos: float) -> void:
	hide()
	set_deferred("monitoring", false)
	await get_tree().create_timer(segundos, false).timeout
	if is_inside_tree():
		show()
		monitoring = true
