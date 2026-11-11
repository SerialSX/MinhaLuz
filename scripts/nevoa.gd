class_name Nevoa
extends Sprite2D
## A névoa do Lauan cobrindo a tela, com o buraco suave em volta da menina.
## A textura, o tamanho e o shader ficam na cena cenas/nevoa.tscn.
## Ver Tarefas/04_bolha_e_nevoa.md.

var menina: Menina
var shader_mat: ShaderMaterial


func _ready() -> void:
	# Cópia do material para cada partida: a vitória mexe na opacidade,
	# e sem a cópia a névoa voltaria transparente ao jogar de novo.
	shader_mat = (material as ShaderMaterial).duplicate()
	material = shader_mat


func _process(_delta: float) -> void:
	# Fica sempre no centro do que a câmera mostra (inclusive quando ela para nas bordas).
	var camera := get_viewport().get_camera_2d()
	if camera:
		global_position = camera.get_screen_center_position()

	if menina == null:
		return
	var tela: Vector2 = get_viewport_rect().size
	var pos_na_tela: Vector2 = menina.get_global_transform_with_canvas().origin
	shader_mat.set_shader_parameter("centro", pos_na_tela / tela)
	shader_mat.set_shader_parameter("raio", menina.raio_da_bolha())


## Some aos poucos (vitória: o mundo se ilumina).
func dissipar(segundos: float) -> void:
	var t := create_tween()
	t.tween_method(_definir_opacidade, 0.97, 0.0, segundos)


func _definir_opacidade(valor: float) -> void:
	shader_mat.set_shader_parameter("opacidade", valor)
