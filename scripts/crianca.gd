class_name Crianca
extends Node2D
## Uma criança que a névoa apagou. Ela anda dentro da sua área, e a névoa que a
## cobre aparece como bolinhas roxas em cima da cabeça.
## Com a menina por perto é o confronto: a criança continua andando, de frente
## para a menina, e de tempos em tempos solta uma palavra ruim que voa
## (scripts/palavra.gd). Antes de soltar ela avisa: para, puxa o ar e abre um
## balão "...". Cada palavra boa que a menina acerta tira uma bolinha de névoa.
## Sem névoa, a criança acende: ganha cor, pede desculpa e vira amiga, e fica
## acenando no lugar (com AMIGAS_SEGUEM, as 3 primeiras seguiriam a menina em fila). Amiga nunca leva dano, nunca apaga de novo e
## dá um pouco de luz quando a luz da menina fica baixa.
## Tudo é montado por código. O balão (scripts/balao.gd), as bolinhas, as palavras
## e a cópia do sprite que aparece no escuro ficam em SobreNevoa: por cima da
## névoa, em coordenadas do mundo.

signal acendeu(crianca: Crianca)   ## acabou de ganhar cor

enum Estado { ANDANDO, AVISANDO, SEGUINDO, ACENANDO, INDO, PARADA }

## A "equipe" decidida num lugar só: com false, a criança acesa fica acenando no
## lugar em vez de seguir a menina (o resto, como a ajuda da luz baixa, não muda).
const AMIGAS_SEGUEM := false   # decidido pelo Lauan em 21/11: as amigas ficam no lugar
const FOLHA := "res://assets/sprites/personagens/%s_%s_folha_nativa.png"
const FOLHA_16 := "res://assets/sprites/personagens/%s_%s_folha16_nativa.png"   # a mesma, em 16 direções
const FOLHA_MENINA := "res://assets/sprites/personagem/menina_folha_nativa.png"
const COR_SEM_ARTE := Color(0.5, 0.54, 0.7)   # sem a folha apagada: a da menina, cinza-azulada
const DIRECOES := ["baixo", "esquerda", "direita", "cima"]   # as linhas da folha de 4
const CARDINAIS := ["direita", "baixo", "esquerda", "cima"]  # na ordem dos ângulos (0°, 90°, 180°, 270°)
const QUADRO := 20                  # cada quadro da folha tem 20x20 pixels
const HISTERESE := 4.0              # graus: só troca de direção mostrada passando isto da borda (joystick com ruído)
const VELOCIDADE := 26.0            # px/s, andando na área
const CORRIDA := 100.0              # px/s, indo até a menina e na fila
const PASSO_REF := 58.0             # px/s em que o passo vai no ritmo da folha: a 26 px/s, passos lentos (0,45)...
const PASSO_MIN := 0.4              # ...e o speed_scale fica entre estes dois
const PASSO_MAX := 1.2
const PERTO := 130.0                # confronto: a menina a menos disto, e a criança na tela
const PRIMEIRA_FALA := 0.4          # a menina chegou perto: o primeiro aviso vem depois deste tempo
const ESPALHAR_FALAS := 0.618034    # razão áurea: o tempo de fala de cada criança fica longe do das outras
const ESPERA_ESPALHADA := 0.3       # a primeira palavra vem até este tanto depois de PRIMEIRA_FALA (pela defasagem)
const MAX_VOANDO := 2               # palavras ruins voando ao mesmo tempo, por criança
const JUNTO := 12.0                 # outra palavra ruim mais perto que isto de onde esta sai...
const DESVIO_PALAVRA := 10.0        # ...e esta sai este tanto acima ou abaixo: dá para ler as duas
const OUVE_ATE := 220.0             # a fala só faz som com a menina por perto
const RECUO := 8.0                  # pulinho para trás ao ouvir uma palavra boa...
const CLARAO := 0.15                # ...e fica clara por este tempo
const ENTRE_AMIGAS := 18.0          # distância entre as amigas da fila
const MAX_FILA := 3
const AJUDA := 8.0                  # luz que a amiga dá quando a luz da menina fica baixa
const RECARGA_AJUDA := 20.0         # segundos; vale para todas as amigas juntas
const CABECA := Vector2(0, -12)     # de onde sai o balão
const BOLINHAS := Vector2(0, -13)   # o meio da fila de bolinhas de névoa
const SOBRE_AS_BOLINHAS := Vector2(0, -17)   # o balão da criança apagada sai de cima delas
const BOCA := Vector2(0, -4)        # de onde sai a palavra ruim
const COR_NEVOA := Color(0.74, 0.56, 0.9)
const COR_FUNDO_NEVOA := Color(0.13, 0.09, 0.19)
const GRUPO_AMIGAS := "amigas"

static var fila: Array[Crianca] = []   ## amigas seguindo a menina, em ordem; a fase limpa no _ready
static var quadro_da_ajuda := 0        # quadro de física em que a ajuda volta a valer (a fase zera no _ready)
static var vez_da_fala := 0.0          # anda ESPALHAR_FALAS a cada criança criada (ver defasagem)

var menina: Menina                 ## a fase define antes de add_child
var sobre_nevoa: CanvasLayer       ## a fase define antes de add_child
var acesa := false
var par := 0                       # índice em DadosFases.PARES
var nevoa := 4                     ## bolinhas de névoa que faltam (palavras boas até acender)
var em_confronto := false          ## a menina está perto: a criança solta palavras ruins

var tipo_folha := ""
var frase := ""                    # a palavra ruim que ela solta
var casa := Rect2()                # a área onde ela anda
var ritmo := 1.8                   # no confronto, solta uma palavra ruim a cada tantos segundos
var aviso := 0.6                   # segundos de aviso antes de soltar
var vel_palavra := 75.0            # px/s da palavra ruim
var defasagem := 0.0               # o seu tempo na roda das falas: sem poder falar, o relógio espera aqui

var estado := Estado.ANDANDO
var relogio := 0.0                 # tempo no estado atual
var silencio := 0.0                # tempo que falta sem poder falar
var escutando := 0.0               # tempo que falta parada, com o "?"
var destino := Vector2.ZERO
var angulo := PI / 2.0             # para onde ela está de frente, na tela (0 = direita): gira devagar
var setor := 4                     # a direção mostrada, de 0 a 15 (de 22,5° em 22,5°)
var direcao := "baixo"             # a cardinal mais perto de `angulo` (folha de 4 linhas)
var pulando := 0.0                 # tempo que falta comemorando
var tempo_balao := 0.0             # os balões bons e o "?" fecham sozinhos
var sprite: AnimatedSprite2D
var por_cima: Node2D               # em SobreNevoa, sempre na posição da criança: cópia, bolinhas e balão
var copia: AnimatedSprite2D        # o mesmo sprite, fraquinho por cima da névoa
var bolinhas: Bolinhas
var balao: Balao


## A névoa em cima da criança: uma fila de bolinhas roxas, que somem uma a uma
## (no lugar de cada uma fica o fundo escuro, para dar para ver quantas faltam).
class Bolinhas extends Node2D:
	var total := 4
	var restam := 4

	func _draw() -> void:
		for i in total:
			var canto := Vector2((i - total / 2.0) * 6.0, -3.0)
			draw_rect(Rect2(canto + Vector2(1, 0), Vector2(4, 6)), COR_FUNDO_NEVOA)
			draw_rect(Rect2(canto + Vector2(0, 1), Vector2(6, 4)), COR_FUNDO_NEVOA)
			if i < restam:
				draw_rect(Rect2(canto + Vector2(2, 1), Vector2(2, 4)), COR_NEVOA)
				draw_rect(Rect2(canto + Vector2(1, 2), Vector2(4, 2)), COR_NEVOA)


## Coração que sai da criança e some: sobe quando ela acende, vai até a menina quando ela ajuda.
class Coracao extends Node2D:
	var rumo := Vector2.ZERO

	func _ready() -> void:
		var t := create_tween().set_parallel()
		t.tween_property(self, "position", position + rumo, 0.8)
		t.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.6)
		t.chain().tween_callback(queue_free)

	func _draw() -> void:
		Balao.desenhar_coracao(self, Vector2(-3, -3))


## `dados`: a fase em DadosFases.FASES (névoa da criança, ritmo e aviso da fala e
## velocidade da palavra ruim).
func configurar(tipo: String, n_par: int, area: Rect2, dados: Dictionary) -> void:
	tipo_folha = tipo
	par = n_par
	frase = DadosFases.RUINS_CURTAS[n_par]
	casa = area
	nevoa = dados.nevoa_crianca
	ritmo = dados.ritmo_fala
	aviso = dados.aviso_fala
	vel_palavra = dados.vel_palavra


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	por_cima = Node2D.new()
	por_cima.position = global_position
	sobre_nevoa.add_child(por_cima)
	# No escuro a criança aparece fraquinha por cima da névoa: uma cópia do sprite.
	copia = AnimatedSprite2D.new()
	copia.material = Nevoa.na_nevoa(false)
	por_cima.add_child(copia)
	bolinhas = Bolinhas.new()
	bolinhas.position = BOLINHAS
	bolinhas.total = nevoa
	bolinhas.restam = nevoa
	por_cima.add_child(bolinhas)
	_vestir()
	destino = _sortear()
	# Cada criança tem o seu tempo para falar: depois de um hit, do Respirar ou do
	# Brilho, elas voltam espalhadas, nunca todas no mesmo quadro. Andar a razão
	# áurea a cada criança deixa bem espalhadas quantas estiverem juntas.
	vez_da_fala = fposmod(vez_da_fala + ESPALHAR_FALAS, 1.0)
	defasagem = vez_da_fala * (ritmo - aviso)


func _exit_tree() -> void:
	fila.erase(self)
	por_cima.queue_free()


func _physics_process(delta: float) -> void:
	relogio += delta
	if menina.ativa:   # enquanto a menina respira, o silêncio não conta
		silencio = maxf(silencio - delta, 0.0)
	var estava := em_confronto
	em_confronto = _confronto()
	if em_confronto and not estava and estado == Estado.ANDANDO:
		# Entrou no confronto agora: cada uma espera um pouco a mais, pela defasagem, e
		# duas que entram juntas não soltam a primeira palavra no mesmo quadro.
		relogio -= ESPERA_ESPALHADA * defasagem / (ritmo - aviso)
	var antes := global_position
	match estado:
		Estado.ANDANDO:
			_andar(delta)
		Estado.AVISANDO:
			sprite.scale = Vector2.ONE * (1.0 + 0.15 * minf(relogio / aviso, 1.0))   # puxa o ar
			if relogio >= aviso and _minhas_palavras().size() < MAX_VOANDO:
				_soltar_palavra()
		Estado.SEGUINDO:
			var lugar := menina.ponto_do_rastro(ENTRE_AMIGAS * (fila.find(self) + 1))
			global_position = global_position.move_toward(lugar, CORRIDA * delta)
		Estado.INDO:
			global_position = global_position.move_toward(destino, CORRIDA * delta)
			if global_position == destino:
				_mudar(Estado.PARADA)   # e vira para a menina (_rumo_do_olhar)
	_animar(global_position - antes, delta)
	if acesa:
		_ajudar()
	if tempo_balao > 0.0:
		tempo_balao -= delta
		if tempo_balao <= 0.0:
			_fechar_balao()
	# O que fica por cima da névoa acompanha a criança.
	por_cima.position = global_position
	copia.position = sprite.position
	copia.scale = sprite.scale
	copia.self_modulate = sprite.self_modulate
	copia.animation = sprite.animation
	copia.frame = sprite.frame


## Uma palavra boa (ou o Brilho, ou a frase boa do par) tira `pontos` de névoa de
## cima dela: a criança dá um pulinho para longe de `de` e fica clara por um
## instante. Sem névoa nenhuma, ela acende.
func tirar_nevoa(pontos: int, de: Vector2) -> void:
	if acesa or pontos <= 0:
		return
	nevoa = maxi(nevoa - pontos, 0)
	bolinhas.restam = nevoa
	bolinhas.queue_redraw()
	if nevoa == 0:
		acender()
		return
	global_position = (global_position + de.direction_to(global_position) * RECUO).clamp(casa.position, casa.end)
	sprite.self_modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(sprite, "self_modulate", Color.WHITE, CLARAO)


## Brilho grande: a criança apagada escuta. O aviso fecha, aparece um "?" e ela
## fica parada, sem falar, por `segundos`. Devolve true se interrompeu um aviso.
func escutar(segundos: float) -> bool:
	if acesa:
		return false
	var interrompeu := estado == Estado.AVISANDO
	_mudar(Estado.ANDANDO)
	escutando = segundos
	_abrir_balao("?", true)
	tempo_balao = segundos
	return interrompeu


## Fecha qualquer balão agora e fica `segundos` sem falar (Respirar).
func calar(segundos := 0.0) -> void:
	if estado == Estado.AVISANDO:
		_mudar(Estado.ANDANDO)
	_fechar_balao()
	silencio = maxf(silencio, segundos)


## Ganha cor, pede desculpa e vira amiga: corre até a menina e entra na fila
## (até 3) ou fica acenando no lugar.
func acender() -> void:
	if acesa:
		return
	acesa = true
	nevoa = 0
	bolinhas.hide()
	for palavra: Palavra in _minhas_palavras():   # quem pediu desculpa não machuca mais
		palavra.sumir()
	_vestir()
	add_to_group(GRUPO_AMIGAS)
	menina.amigas += 1
	if AMIGAS_SEGUEM and fila.size() < MAX_FILA:
		fila.append(self)
		_mudar(Estado.SEGUINDO)
	else:
		_mudar(Estado.ACENANDO)
	Audio.tocar_sfx("amigo")
	_soltar_coracao(Vector2(0, -10))
	dizer("Desculpa!")
	sprite.scale = Vector2.ONE * 1.3   # um "pop" ao ganhar cor
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.25)
	acendeu.emit(self)


## Balão bom por alguns segundos.
func dizer(texto: String, segundos := 1.5) -> void:
	_abrir_balao(texto, true)
	tempo_balao = segundos


## Pulinhos por 2 s.
func comemorar() -> void:
	pulando = 2.0


## Anda até `pos` e fica lá (final da fase: as amigas em volta da menina).
func ir_para(pos: Vector2) -> void:
	fila.erase(self)
	destino = pos
	_mudar(Estado.INDO)


## As animações de uma folha de personagem, com quadros de 20x20. Folha de 4
## linhas (baixo, esquerda, direita e cima): parada_baixo, andando_direita etc.
## Folha de 16 linhas (a linha k é a direção k × 22,5°, no sentido horário a partir
## da direita): parada_k e andando_k (k = 0 a 15) e também os nomes de antes, com
## os quadros de k = 4, 8, 0 e 12 (quem chama pelo nome: menu, história, final).
## Folha fluida (240 de largura): colunas 0-3 parada e 4-11 andando. Folha antiga
## (120): colunas 0-1 parada e 2-5 andando. A parada dá uma volta por segundo e o
## andar, duas.
static func animacoes(folha: Texture2D) -> SpriteFrames:
	var paradas := 4 if folha.get_width() >= 12 * QUADRO else 2
	var dezesseis := folha.get_height() >= 16 * QUADRO
	var quadros := SpriteFrames.new()
	quadros.remove_animation(&"default")
	if dezesseis:
		for k in 16:
			_animacao(quadros, folha, "parada_%d" % k, k, 0, paradas, paradas)
			_animacao(quadros, folha, "andando_%d" % k, k, paradas, paradas * 2, paradas * 4.0)
	for i in DIRECOES.size():
		var linha: int = CARDINAIS.find(DIRECOES[i]) * 4 if dezesseis else i
		_animacao(quadros, folha, "parada_" + DIRECOES[i], linha, 0, paradas, paradas)
		_animacao(quadros, folha, "andando_" + DIRECOES[i], linha, paradas, paradas * 2, paradas * 4.0)
	return quadros


## A folha de um tipo de criança numa versão (cor, apagada): a de 16 direções
## quando existir, senão a de 4; "" sem nenhuma.
static func folha_de(tipo: String, versao: String) -> String:
	for modelo: String in [FOLHA_16, FOLHA]:
		if ResourceLoader.exists(modelo % [tipo, versao]):
			return modelo % [tipo, versao]
	return ""


## O setor (0 a `quantos` - 1) mais perto do ângulo `a`, com histerese: continua
## no `atual` até `a` passar HISTERESE graus da borda dele.
static func setor_do_angulo(a: float, atual: int, quantos: int) -> int:
	var largura := TAU / quantos
	if absf(angle_difference(atual * largura, a)) <= largura / 2.0 + deg_to_rad(HISTERESE):
		return atual
	return posmod(roundi(a / largura), quantos)


## Toca andar ou parada virada para o setor `k` (folha de 16 linhas) ou, sem ele,
## para a `cardinal` (folha de 4). Trocando só de direção, o quadro e o ponto dele
## continuam: o passo não recomeça ao virar.
static func tocar(figura: AnimatedSprite2D, andando: bool, k: int, cardinal: String) -> void:
	var tipo := "andando_" if andando else "parada_"
	var nome := tipo + str(k)
	if not figura.sprite_frames.has_animation(nome):
		nome = tipo + cardinal
	var antes := String(figura.animation)
	if nome == antes or not antes.begins_with(tipo):
		figura.play(nome)   # continua a mesma, ou começa a andar ou a parar (do quadro 0)
		return
	var quadro := figura.frame
	var progresso := figura.frame_progress
	figura.play(nome)
	figura.set_frame_and_progress(quadro, progresso)


static func _animacao(quadros: SpriteFrames, folha: Texture2D, nome: String, linha: int, coluna: int, quantos: int, qps: float) -> void:
	quadros.add_animation(nome)
	quadros.set_animation_speed(nome, qps)
	for i in quantos:
		var recorte := AtlasTexture.new()
		recorte.atlas = folha
		recorte.region = Rect2((coluna + i) * QUADRO, linha * QUADRO, QUADRO, QUADRO)
		quadros.add_frame(nome, recorte)


## Põe a folha apagada ou a folha em cor (de 16 direções quando houver). Arte
## faltando não quebra o jogo: sem a "apagada" vale a "sombra", e sem as duas vale
## a folha da menina.
func _vestir() -> void:
	var caminho := ""
	for versao: String in (["cor"] if acesa else ["apagada", "sombra"]):
		if caminho == "":
			caminho = folha_de(tipo_folha, versao)
	sprite.modulate = Color.WHITE
	if caminho == "":
		caminho = FOLHA_MENINA
		if not acesa:
			sprite.modulate = COR_SEM_ARTE
	sprite.sprite_frames = animacoes(load(caminho))
	copia.sprite_frames = sprite.sprite_frames
	copia.modulate = sprite.modulate


## Confronto: a criança apagada com a menina por perto, as duas na tela.
func _confronto() -> bool:
	return (not acesa and menina.ativa and not menina.luz_congelada
		and global_position.distance_to(menina.global_position) < PERTO and _na_tela())


func _na_tela() -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return false
	var d := (global_position - camera.get_screen_center_position()).abs()
	var meia_tela := get_viewport_rect().size / 2.0
	return d.x < meia_tela.x and d.y < meia_tela.y


## Anda pela área. No confronto, quando chega a hora, para e avisa que vai falar.
## Enquanto não pode falar (escutando, em silêncio ou com a menina protegida), o
## relógio da fala fica parado na defasagem dela.
func _andar(delta: float) -> void:
	if escutando > 0.0:
		escutando -= delta
		relogio = defasagem
		return
	if global_position.distance_to(destino) < 1.0:
		destino = _sortear()
	global_position = global_position.move_toward(destino, VELOCIDADE * delta)
	if not em_confronto:
		# Longe da menina, o relógio da fala espera quase na hora do aviso: quando ela
		# chega perto, a primeira palavra ruim vem logo, e não um ritmo inteiro depois.
		relogio = minf(relogio, maxf(ritmo - aviso - PRIMEIRA_FALA, 0.0))
	elif silencio > 0.0 or menina.protegida:
		# Com a menina protegida depois de um hit, ninguém começa a falar: nunca hit em cadeia.
		relogio = defasagem
	elif relogio >= ritmo - aviso:
		_mudar(Estado.AVISANDO)
		_abrir_balao("...", false)


## Solta a palavra ruim, voando para onde a menina está agora. Se outra palavra
## ruim está saindo do mesmo lugar, esta sai um pouco acima ou abaixo (no lado
## mais livre), para dar para ler as duas. O rumo é sempre o da boca: a desviada
## voa ao lado da outra, sem as duas se juntarem no caminho.
func _soltar_palavra() -> void:
	var de := global_position + BOCA
	var rumo := de.direction_to(menina.global_position)
	if _palavra_mais_perto(de) < JUNTO:
		var cima := de + Vector2(0, -DESVIO_PALAVRA)
		var baixo := de + Vector2(0, DESVIO_PALAVRA)
		de = cima if _palavra_mais_perto(cima) >= _palavra_mais_perto(baixo) else baixo
	sobre_nevoa.add_child(Palavra.nova_ruim(frase, de, rumo, vel_palavra, menina, self))
	if global_position.distance_to(menina.global_position) < OUVE_ATE:
		Audio.tocar_sfx("fala_sombra")
	_mudar(Estado.ANDANDO)


## As palavras ruins desta criança que ainda estão voando.
func _minhas_palavras() -> Array:
	return get_tree().get_nodes_in_group(Palavra.GRUPO_RUINS).filter(
		func(palavra: Palavra) -> bool: return palavra.dona == self)


## Distância de `ponto` até a palavra ruim voando mais perto dele (de qualquer criança).
func _palavra_mais_perto(ponto: Vector2) -> float:
	var menor := INF
	for palavra: Palavra in get_tree().get_nodes_in_group(Palavra.GRUPO_RUINS):
		menor = minf(menor, palavra.pos.distance_to(ponto))
	return menor


func _mudar(novo: Estado) -> void:
	if estado == Estado.AVISANDO:   # o balão do aviso fecha
		_fechar_balao()
	estado = novo
	relogio = 0.0
	sprite.scale = Vector2.ONE


## Animação de andar ou parar conforme o próprio movimento, virando devagar (como
## a menina: Menina.GIRO, com histerese), com o passo no ritmo da velocidade (para
## trás quando ela anda de costas), e os pulinhos.
func _animar(movimento: Vector2, delta: float) -> void:
	var andando := movimento.length() > 0.01
	angulo = wrapf(rotate_toward(angulo, _rumo_do_olhar(movimento, andando), deg_to_rad(Menina.GIRO) * delta), -PI, PI)
	setor = setor_do_angulo(angulo, setor, 16)
	direcao = CARDINAIS[setor_do_angulo(angulo, CARDINAIS.find(direcao), 4)]
	# Andando devagar na área, passos lentos; correndo, mais rápidos. No confronto ela
	# fica de frente para a menina e continua andando pela área: de costas, o passo
	# toca ao contrário (speed_scale negativo), para não parecer que o pé desliza.
	var passo := clampf(movimento.length() / delta / PASSO_REF, PASSO_MIN, PASSO_MAX) if andando else 1.0
	if andando and movimento.dot(Vector2.from_angle(angulo)) < -0.5 * movimento.length():
		passo = -passo   # de costas (mais de 120°): o passo vai para trás
	sprite.speed_scale = passo
	tocar(sprite, andando, setor, direcao)
	pulando = maxf(pulando - delta, 0.0)
	var altura := 0.0
	if pulando > 0.0:
		altura = 6.0 * absf(sin(pulando * TAU / 0.8))
	elif estado == Estado.ACENANDO:   # acenando no lugar: um pulinho de vez em quando
		altura = 3.0 * maxf(sin(relogio * TAU / 1.2), 0.0)
	sprite.position.y = -roundf(altura)


## Para onde ela fica de frente: para a menina no confronto (e parada em volta
## dela no final), para baixo acenando, senão para onde anda.
func _rumo_do_olhar(movimento: Vector2, andando: bool) -> float:
	if em_confronto or estado == Estado.AVISANDO or estado == Estado.PARADA:
		return (menina.global_position - global_position).angle()
	if estado == Estado.ACENANDO:
		return PI / 2.0
	return movimento.angle() if andando else angulo


## Luz da menina baixa: a amiga mais próxima diz que está com ela e dá um pouco de luz.
func _ajudar() -> void:
	if menina.luz > menina.luz_baixa or not menina.ativa or menina.luz_congelada:
		return
	if Engine.get_physics_frames() < quadro_da_ajuda:
		return
	var distancia := global_position.distance_to(menina.global_position)
	for amiga: Crianca in get_tree().get_nodes_in_group(GRUPO_AMIGAS):
		if amiga.global_position.distance_to(menina.global_position) < distancia:
			return
	quadro_da_ajuda = Engine.get_physics_frames() + int(RECARGA_AJUDA * Engine.physics_ticks_per_second)
	menina.luz = minf(menina.luz + AJUDA, menina.luz_max)
	Audio.tocar_sfx("amigo", 1.25)
	_soltar_coracao(menina.global_position - global_position)
	dizer("Estou com você!")


func _sortear() -> Vector2:
	return casa.position + Vector2(randf(), randf()) * casa.size


func _abrir_balao(texto: String, bom: bool) -> void:
	_fechar_balao()
	balao = Balao.criar(texto, bom)
	balao.position = CABECA if acesa else SOBRE_AS_BOLINHAS
	# Com a menina logo acima, o balão abre para baixo, para não tapar a menina.
	var d := menina.global_position - global_position
	balao.para_baixo = absf(d.x) < 50.0 and d.y < -6.0 and d.y > -52.0
	por_cima.add_child(balao)


func _fechar_balao() -> void:
	tempo_balao = 0.0
	if is_instance_valid(balao):
		balao.fechar()
	balao = null


func _soltar_coracao(rumo: Vector2) -> void:
	var coracao := Coracao.new()
	coracao.rumo = rumo
	coracao.z_index = 1
	por_cima.add_child(coracao)
