class_name Vagalumes
extends Node2D
## Todos os vaga-lumes da fase num nó só, dentro de SobreNevoa (por cima da
## névoa, em coordenadas do mundo): pontinhos dourados sempre visíveis, que dão
## à criança um lugar para onde ir no escuro.
## - Fixos: em trilhas e grupinhos; contam para a estrela da fase.
## - Bônus: enxames de socorro e convites; dão luz e carga, mas não contam.
## Pegar em sequência sobe o combo (o som sobe de tom). Cada vaga-lume pego vira
## 1 de carga do Brilho, que aparece girando em volta da menina.
## Quem usa é scripts/fase.gd.

signal pego(combo: int)   ## a menina pegou um vaga-lume (fixo ou bônus)

const RAIO_PEGAR := 9.0
const RAIO_IMA := 28.0          # mais perto que isso, o vaga-lume voa até a menina
const VELOCIDADE_IMA := 160.0
const TEMPO_COMBO := 1.2        # sem pegar por este tempo, o combo zera
const CARGA_CHEIA := 6
const COR := Color(1.0, 0.93, 0.5)
const COR_BRILHO := Color(1.0, 0.82, 0.3, 0.3)

var menina: Menina
var total := 0                  # fixos colocados
var pegos := 0                  # fixos pegos
var carga := 0                  # 0 a CARGA_CHEIA
var combo := 0
var tempo_combo := 0.0
var tempo := 0.0

# Um vaga-lume = uma posição em cada lista (mesmo índice).
var posicoes := PackedVector2Array()
var velocidades := PackedVector2Array()   # bônus voando; ZERO = parado
var vidas := PackedFloat32Array()         # bônus: segundos que faltam; fixos: -1
var puxados := PackedByteArray()          # 1 = voando até a menina (ímã ou Brilhar)


func adicionar(posicao: Vector2) -> void:
	_novo(posicao, Vector2.ZERO, -1.0)
	total += 1


## Vaga-lume bônus: some depois de `vida` segundos se ninguém pegar.
func adicionar_bonus(posicao: Vector2, velocidade: Vector2, vida: float) -> void:
	_novo(posicao, velocidade, vida)


func _novo(posicao: Vector2, velocidade: Vector2, vida: float) -> void:
	posicoes.append(posicao)
	velocidades.append(velocidade)
	vidas.append(vida)
	puxados.append(0)


## Poder Brilhar: os vaga-lumes dentro do anel voam até a menina.
func puxar(centro: Vector2, raio: float) -> void:
	for i in posicoes.size():
		if posicoes[i].distance_to(centro) <= raio:
			puxados[i] = 1


func _physics_process(delta: float) -> void:
	tempo += delta
	tempo_combo = maxf(tempo_combo - delta, 0.0)
	if tempo_combo <= 0.0:
		combo = 0
	if menina == null:
		return
	var alvo := menina.global_position
	var pode_pegar := menina.ativa
	var i := 0
	while i < posicoes.size():
		var p := posicoes[i]
		var distancia := p.distance_to(alvo)
		if pode_pegar and (puxados[i] == 1 or distancia <= RAIO_IMA):
			puxados[i] = 1
			p = p.move_toward(alvo, VELOCIDADE_IMA * delta)
		else:
			p += velocidades[i] * delta
		posicoes[i] = p
		var acabou := false
		if vidas[i] >= 0.0:
			vidas[i] -= delta
			acabou = vidas[i] <= 0.0
		if pode_pegar and p.distance_to(alvo) <= RAIO_PEGAR:
			if vidas[i] < 0.0:
				pegos += 1
			_pegar()
			acabou = true
		if acabou:
			_tirar(i)
		else:
			i += 1
	queue_redraw()


func _pegar() -> void:
	combo += 1
	tempo_combo = TEMPO_COMBO
	carga = mini(carga + 1, CARGA_CHEIA)
	# O tom sobe a cada vaga-lume da sequência (até 8 passos, uns 60% mais agudo).
	Audio.tocar_sfx("vagalume", pow(2.0, mini(combo - 1, 8) / 12.0))
	pego.emit(combo)


func _tirar(i: int) -> void:
	posicoes.remove_at(i)
	velocidades.remove_at(i)
	vidas.remove_at(i)
	puxados.remove_at(i)


func _draw() -> void:
	for i in posicoes.size():
		var p := posicoes[i].round()
		var pisca := 0.5 + 0.5 * sin(tempo * 3.0 + p.x * 0.37 + p.y * 0.21)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 5)), Color(COR_BRILHO, 0.15 + 0.3 * pisca))
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(COR, 0.7 + 0.3 * pisca))
	if menina == null or carga <= 0:
		return
	# A carga do Brilho gira em volta da menina; cheia, gira mais rápido e maior.
	var cheia := carga >= CARGA_CHEIA
	var centro := menina.global_position
	var giro := tempo * (5.0 if cheia else 2.0)
	for n in carga:
		var angulo := giro + TAU * n / CARGA_CHEIA
		var p := (centro + Vector2(cos(angulo), sin(angulo) * 0.8) * (15.0 if cheia else 13.0)).round()
		if cheia:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(5, 5)), COR_BRILHO)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), COR)
