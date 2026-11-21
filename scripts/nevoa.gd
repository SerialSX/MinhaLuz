class_name Nevoa
extends Sprite2D
## A névoa do Lauan cobrindo a tela, com o buraco suave em volta da menina.
## A textura, o tamanho e o shader ficam na cena cenas/nevoa.tscn.
## Também cuida dos materiais "na névoa" (shaders/na_nevoa.gdshader): vultos e
## ecos de fala que aparecem por cima da névoa, só onde ela cobre.
## Ver Tarefas/04_bolha_e_nevoa.md.

const SHADER_NA_NEVOA := preload("res://shaders/na_nevoa.gdshader")
const Z_NA_NEVOA := 52   # acima da névoa (50), abaixo da nuvem (55)

# Compartilhados por todos os nós que usam: a névoa atualiza uma vez e vale para todos.
static var material_vulto: ShaderMaterial   # silhueta lilás (sombras que andam)
static var material_eco: ShaderMaterial     # texto fraquinho (falas e frases acordadas)

var menina: Menina
var shader_mat: ShaderMaterial
var claridade := 0.0


func _ready() -> void:
	# Cópia do material para cada partida: a vitória mexe na opacidade,
	# e sem a cópia a névoa voltaria transparente ao jogar de novo.
	shader_mat = (material as ShaderMaterial).duplicate()
	material = shader_mat
	_definir_opacidade(1.0)


func _process(_delta: float) -> void:
	# Fica sempre no centro do que a câmera mostra (inclusive quando ela para nas bordas).
	var camera := get_viewport().get_camera_2d()
	if camera:
		global_position = camera.get_screen_center_position()

	if menina == null:
		return
	var tela: Vector2 = get_viewport_rect().size
	var pos_na_tela: Vector2 = menina.get_global_transform_with_canvas().origin
	for m: ShaderMaterial in [shader_mat, na_nevoa(true), na_nevoa(false)]:
		m.set_shader_parameter("centro", pos_na_tela / tela)
		m.set_shader_parameter("raio", menina.raio_da_bolha())


## Material para desenhar por cima da névoa: vulto (silhueta) ou eco (texto fraquinho).
## Quem usa também põe o nó acima da névoa: z_index = Nevoa.Z_NA_NEVOA, z_as_relative = false.
static func na_nevoa(vulto: bool) -> ShaderMaterial:
	if material_vulto == null:
		material_vulto = ShaderMaterial.new()
		material_vulto.shader = SHADER_NA_NEVOA
		material_vulto.set_shader_parameter("forca", 0.6)
		material_vulto.set_shader_parameter("achatar", 1.0)
		material_eco = ShaderMaterial.new()
		material_eco.shader = SHADER_NA_NEVOA
		material_eco.set_shader_parameter("forca", 0.6)
	return material_vulto if vulto else material_eco


## Clareia a névoa aos poucos (0 = escura): a fase chama a cada frase boa pega.
func clarear(valor: float, segundos: float) -> void:
	create_tween().tween_method(_definir_claridade, claridade, valor, segundos)


func _definir_claridade(valor: float) -> void:
	claridade = valor
	shader_mat.set_shader_parameter("claridade", valor)


## Some aos poucos (o mundo se ilumina).
func dissipar(segundos: float) -> void:
	var t := create_tween()
	t.tween_method(_definir_opacidade, 1.0, 0.0, segundos)


func _definir_opacidade(valor: float) -> void:
	for m: ShaderMaterial in [shader_mat, na_nevoa(true), na_nevoa(false)]:
		m.set_shader_parameter("opacidade", valor)
