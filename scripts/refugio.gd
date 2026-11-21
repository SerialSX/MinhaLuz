class_name Refugio
extends Node2D
## Lugar seguro: um disco de luz dourada por cima da névoa. Dentro dele a luz
## da menina não cai e as frases ruins não entram.
## - Banco da amizade (escola): já nasce aceso e devolve um pouco de luz.
## - Poste (beco): acende quando a menina passa perto e fica aceso.
## Quem cria e posiciona é scripts/fase.gd.

signal acendeu(refugio: Refugio)

const RAIO := 44.0
const COR := Color(1.0, 0.85, 0.45)

static var acesos: Array[Refugio] = []   # a fase esvazia no começo

var raio_acender := 0.0    # > 0: acende quando a menina chega a essa distância; 0: nasce aceso
var cura := 0.0            # luz por segundo dentro do disco...
var cura_ate := 60.0       # ...até este valor
var aceso := false
var disco: Sprite2D        # a luz, dentro de SobreNevoa (por cima da névoa)


## Algum lugar seguro aceso cobre este ponto?
static func protege(ponto: Vector2) -> bool:
	return em(ponto) != null


## O lugar seguro aceso que cobre este ponto, ou null.
static func em(ponto: Vector2) -> Refugio:
	for r in acesos:
		if r.global_position.distance_to(ponto) <= RAIO:
			return r
	return null


## `sobre_nevoa`: a camada por cima da névoa, onde a luz é desenhada.
## Chame depois de posicionar o lugar seguro.
func preparar(sobre_nevoa: CanvasLayer) -> void:
	var rampa := Gradient.new()
	rampa.set_color(0, Color(COR, 0.5))
	rampa.set_color(1, Color(COR, 0.0))
	var textura := GradientTexture2D.new()
	textura.gradient = rampa
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = int(RAIO * 2.0)
	textura.height = int(RAIO * 2.0)
	disco = Sprite2D.new()
	disco.texture = textura
	disco.position = position
	disco.modulate.a = 0.0
	sobre_nevoa.add_child(disco)
	if raio_acender <= 0.0:
		acender()


## A fase chama a cada quadro de física com a posição da menina.
func conferir(ponto: Vector2) -> void:
	if not aceso and raio_acender > 0.0 and global_position.distance_to(ponto) <= raio_acender:
		acender()
		acendeu.emit(self)


func acender() -> void:
	aceso = true
	acesos.append(self)
	var t := create_tween()
	t.tween_property(disco, "modulate:a", 1.0, 0.5)
	t.tween_callback(_respirar)


## A luz respira devagar (nunca pisca rápido).
func _respirar() -> void:
	var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(disco, "modulate:a", 0.75, 1.4)
	t.tween_property(disco, "modulate:a", 1.0, 1.4)


func _exit_tree() -> void:
	acesos.erase(self)
