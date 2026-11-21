extends Node2D
## Uma fase (campo, escola ou beco), montada com DadosFases.fase(Jogo.fase_atual):
## os números de DadosFases.FASES com a dificuldade escolhida no Config.
## Combate de palavras: perto da menina, as crianças apagadas soltam palavras ruins
## que voam (é preciso desviar), e a menina responde com palavras boas, que tiram a
## névoa de cima delas (scripts/crianca.gd e scripts/palavra.gd).
## Os nós fixos (chão, menina, névoa, SobreNevoa e HUD) ficam na cena cenas/fase.tscn.
## O resto é sorteado a cada partida: frases boas, crianças apagadas, frases
## ruins que seguem, lugares seguros, obstáculos, decoração e vaga-lumes.
## Fluxo: JOGANDO (acha as 4 frases boas) → CLARO (o mundo ganha cor e a névoa
## vira a nuvem escura) → FINAL (a menina brilha dentro da nuvem; scripts/final_fase.gd)
## → FIM (painel com estrelas). RESPIRANDO é a pausa para respirar quando a luz acabaria
## (no Difícil, acabados os respiros da fase, o HUD oferece recomeçar).
## Ver docs/visao_geral.md, docs/decisoes.md e Ideias/.

enum Estado { JOGANDO, RESPIRANDO, CLARO, FINAL, FIM }

const CENA_FRASE := preload("res://cenas/frase.tscn")
const CENA_NUVEM := preload("res://cenas/nuvem_escura.tscn")

const MARGEM := 24.0
# Obstáculos e decoração desenhados pequenos demais perto da menina: ampliados no jogo.
# Provisório (ver docs/decisoes.md). Use número inteiro para o pixel ficar nítido.
const ESCALA_CENARIO := 2.0
const AREA_CRIANCA := Vector2(170, 130)   # área livre em volta da frase boa de um par dito
const LONGE_DO_INICIO := 220.0            # frases boas e crianças nascem pelo menos a esta distância
const INTERVALO_PULSO := 1.2              # som "pulso" com a luz baixa
const CALMA_INICIAL := 10.0               # as frases ruins não acordam nos primeiros segundos
const RECARGA_PROCURAR := 2.0
const SEM_PEGAR := 8.0                    # este tempo sem pegar nada: a seta liga sozinha
const RAIO_BRILHAR := 85.0                # o anel do Brilho grande (carga cheia)
const NEVOA_BRILHO := 2                   # névoa que o Brilho grande tira de cada criança no anel...
const ESCUTA_BRILHO := 3.0                # ...que fica este tempo escutando, sem falar
const INTERVALO_PALAVRA := 0.5            # tempo mínimo entre duas palavras boas da menina...
const GUARDA_APERTO := 0.2                # ...e um aperto feito até este tanto antes do fim dele fica guardado
const MIRA_CRIANCA := Crianca.PERTO       # a palavra boa mira a criança apagada em confronto (que responde)...
const MIRA_SEGUIDORA := 110.0             # ...ou a frase ruim acordada até esta distância
const EMPURRAO_PALAVRA := 30.0            # a frase ruim atingida é empurrada este tanto...
const SONO_PALAVRA := 3.0                 # ...e dorme este tempo
const SILENCIO_RESPIRAR := 6.0            # depois de respirar, as crianças ficam este tempo sem falar
const BOCA := Vector2(0, -6)              # de onde sai a palavra boa, a partir do centro da menina
const SOCORRO_ESPERA := 3.0               # luz baixa por este tempo: vem um enxame de vaga-lumes
const SOCORRO_RECARGA := 25.0
# A cada frase boa pega, a bolha abre e o mundo clareia; com todas, o mundo fica claro de vez.
const RAIO_EXTRA := 0.10                  # fração da altura da tela
const CLAREAR_POR_FRASE := 0.2            # quanto o tom anda até o branco a cada frase
const TEMPO_CLAREAR := 2.5
# Pontos
const PONTOS_FRASE_BOA := 100
const PONTOS_VAGALUME := 10               # vezes o combo (até 5)
const PONTOS_AMIGA := 50
const PONTOS_PALAVRA := 10                # palavra boa que acerta uma criança apagada
const PONTOS_EMPURRAO := 5                # palavra boa que acerta uma frase ruim acordada
const PONTOS_ESPANTO := 15
const PONTOS_ESCUTA := 25
const PONTOS_REFUGIO := 20
const PONTOS_ESTRELA := 100
const CUSTO_RESPIRAR := 50
const LUZ_VAGALUME := 2.0

var dados: Dictionary
var mapa: Vector2
var estado := Estado.JOGANDO
var ocupados: Array[Rect2] = []
var solidos: Array[Rect2] = []      # obstáculos: vaga-lume não nasce dentro, nuvem não nasce em cima
var sprites_cenario: Array = []     # [sprite, caminho da versão original] para o mundo ganhar cor
var frases_boas: Array[Frase] = []
var criancas: Array[Crianca] = []
var refugios: Array[Refugio] = []
var primeira_frase: Frase           # fase 1: a que fica perto do começo
var boas_total := 0
var boas_pegas := 0
var tempo_fase := 0.0
var espera_pulso := 0.0
var espera_procurar := 0.0
var espera_palavra := 0.0
var aperto_guardado := false        # apertou no fim do intervalo: a palavra sai quando ele acabar
var vezes_respirou := 0             # nesta fase (no Difícil há um limite: dados.respiros)
var sem_pegar := 0.0
var luz_baixa_ha := 0.0
var espera_socorro := 0.0
var dicas_dadas := {}
var nuvem: NuvemEscura
var vagalumes: Vagalumes
var balao_menina: Balao

@onready var tom: CanvasModulate = $Mundo/Tom  # deixa o mundo um pouco apagado
@onready var chao: Sprite2D = $Mundo/Chao
@onready var cenario: Node2D = $Mundo/Cenario  # obstáculos, decoração, frases, crianças e nuvem
@onready var menina: Menina = $Mundo/Menina
@onready var sobre_nevoa: CanvasLayer = $Mundo/SobreNevoa   # por cima da névoa, em coordenadas do mundo
@onready var hud: Hud = $HUD


func _ready() -> void:
	dados = DadosFases.fase(Jogo.fase_atual)
	mapa = dados.mapa
	tom.color = dados.tom
	if ResourceLoader.exists(dados.chao):
		chao.texture = load(dados.chao)
	chao.region_rect = Rect2(Vector2.ZERO, mapa)
	menina.position = mapa / 2.0
	menina.definir_mapa(mapa)
	menina.mult_fase = dados.queda
	menina.dano_frase_ruim = dados.dano
	menina.luz_min = dados.luz_min
	menina.apagou.connect(_respirar)
	menina.ferida.connect(_ao_levar_dano)

	# O que é combinado entre os nós da fase começa do zero.
	Frase.acordadas = 0
	Frase.max_acordadas = dados.acordadas
	Frase.liberadas = false
	Crianca.fila.clear()
	Crianca.quadro_da_ajuda = 0
	Refugio.acesos.clear()

	vagalumes = Vagalumes.new()
	vagalumes.menina = menina
	vagalumes.pego.connect(_ao_pegar_vagalume)
	sobre_nevoa.add_child(vagalumes)

	# Ordem do sorteio: primeiro o que importa para o jogo, depois o cenário em volta.
	ocupados.append(Rect2(menina.position - Vector2(48, 48), Vector2(96, 96)))   # área livre no começo
	_criar_pares_ditos()
	_criar_pares_pensados()
	_criar_refugios()
	for grupo: Dictionary in dados.obstaculos:
		_criar_objetos(grupo, true)
	for grupo: Dictionary in dados.decoracao:
		_criar_objetos(grupo, false)
	_criar_vagalumes()

	hud.configurar(Jogo.fase_atual + 1, dados.nome, dados.subtitulo, boas_total, criancas.size(), vagalumes.total, true)
	hud.procurar_pedido.connect(procurar)
	Audio.tocar_musica(dados.musica)
	Jogo.contando_tempo = true


func _process(delta: float) -> void:
	hud.atualizar_luz(menina.luz, menina.luz_max, menina.luz_baixa)
	hud.atualizar_pontos(Jogo.pontos)
	if is_instance_valid(balao_menina):
		balao_menina.position = menina.global_position + Vector2(0, -13)
	if estado != Estado.JOGANDO:
		return
	tempo_fase += delta
	Frase.liberadas = tempo_fase >= CALMA_INICIAL
	espera_procurar = maxf(espera_procurar - delta, 0.0)
	espera_palavra = maxf(espera_palavra - delta, 0.0)
	# Segurando o botão, a menina continua falando, uma palavra a cada intervalo; e o
	# aperto guardado no fim do intervalo sai agora (para quem não consegue apertar rápido).
	if menina.ativa and espera_palavra <= 0.0 and (aperto_guardado or Input.is_action_pressed("brilhar")):
		aperto_guardado = false
		brilhar()

	# Perdida? A seta aparece sozinha.
	sem_pegar += delta
	if sem_pegar >= SEM_PEGAR:
		sem_pegar = 0.0
		_mostrar_seta(3.0)

	# Luz baixa: um "pulso" baixinho, como um coração, e depois de um tempo vem ajuda.
	var baixa := menina.ativa and menina.luz <= menina.luz_baixa
	luz_baixa_ha = luz_baixa_ha + delta if baixa else 0.0
	espera_socorro = maxf(espera_socorro - delta, 0.0)
	if luz_baixa_ha >= SOCORRO_ESPERA and espera_socorro <= 0.0:
		_socorro()
	espera_pulso = espera_pulso - delta if baixa else 0.0
	if baixa and espera_pulso <= 0.0:
		Audio.tocar_sfx("pulso")
		espera_pulso = INTERVALO_PULSO
	_dicas()


func _physics_process(delta: float) -> void:
	if estado != Estado.JOGANDO:
		menina.em_refugio = false
		return
	for r in refugios:
		r.conferir(menina.position)
	var seguro := Refugio.em(menina.position)
	menina.em_refugio = seguro != null
	if seguro and seguro.cura > 0.0 and menina.luz < seguro.cura_ate:
		menina.luz = minf(menina.luz + seguro.cura * delta, seguro.cura_ate)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("procurar"):
		get_viewport().set_input_as_handled()
		procurar()
	elif event.is_action_pressed("brilhar") and estado == Estado.JOGANDO:
		get_viewport().set_input_as_handled()
		brilhar()


# ---------- Poderes ----------

## Procurar: uma seta piscando aponta a frase boa mais perto (ou a nuvem).
func procurar() -> void:
	if estado != Estado.JOGANDO or not menina.ativa or espera_procurar > 0.0:
		return
	espera_procurar = RECARGA_PROCURAR
	sem_pegar = 0.0
	Audio.tocar_sfx("procurar")
	_mostrar_seta(3.0)


func _mostrar_seta(segundos: float) -> void:
	var alvo: Node2D = nuvem
	var menor := INF
	for frase in frases_boas:
		var distancia := frase.global_position.distance_squared_to(menina.global_position)
		if distancia < menor:
			menor = distancia
			alvo = frase
	if alvo:
		hud.mostrar_seta(menina, alvo, segundos)


## Brilhar: a menina fala uma palavra boa, que voa até a criança apagada ou a
## frase ruim acordada mais perto (sem ninguém por perto, para onde ela olha).
## As palavras boas não desfazem as palavras ruins que voam: dessas é preciso desviar.
## Com a carga cheia (6 vaga-lumes) e alguma coisa dentro do anel, o aperto vira o
## Brilho grande. Sem nada ali, a carga fica guardada e sai a palavra boa de sempre.
## Um aperto no fim do intervalo entre palavras fica guardado (_process solta).
func brilhar() -> void:
	if not menina.ativa:
		return
	if vagalumes.carga >= Vagalumes.CARGA_CHEIA and _algo_no_anel():
		_brilho_grande()
	elif espera_palavra <= 0.0:
		espera_palavra = INTERVALO_PALAVRA
		var de := menina.global_position + BOCA
		var alvo := _alvo_da_palavra()
		var rumo: Vector2 = de.direction_to(alvo.global_position) if alvo else Vector2.from_angle(menina.angulo)
		var palavra := Palavra.nova_boa(DadosFases.PALAVRAS_MENINA.pick_random(), de, rumo, alvo)
		palavra.acertou.connect(_ao_acertar_palavra)
		sobre_nevoa.add_child(palavra)
		Audio.tocar_sfx("palavra_boa")
	elif espera_palavra <= GUARDA_APERTO:
		aperto_guardado = true


## Mira sozinha: a criança apagada ou a frase ruim acordada mais perto da menina.
func _alvo_da_palavra() -> Node2D:
	var alvo: Node2D = null
	var menor := INF
	for no: Node2D in criancas + get_tree().get_nodes_in_group("seguidoras"):
		var distancia := no.global_position.distance_to(menina.global_position)
		var alcance := MIRA_CRIANCA if no is Crianca else MIRA_SEGUIDORA
		if distancia <= alcance and distancia < menor and Palavra.e_alvo(no):
			menor = distancia
			alvo = no
	return alvo


## O Brilho grande alcançaria alguma coisa? Criança apagada, frase ruim acordada
## ou palavra ruim voando, dentro do anel.
func _algo_no_anel() -> bool:
	var centro := menina.global_position
	for no: Node2D in criancas + get_tree().get_nodes_in_group("seguidoras"):
		if Palavra.e_alvo(no) and no.global_position.distance_to(centro) <= RAIO_BRILHAR:
			return true
	for palavra: Palavra in get_tree().get_nodes_in_group(Palavra.GRUPO_RUINS):
		if palavra.pos.distance_to(centro) <= RAIO_BRILHAR:
			return true
	return false


## Uma palavra boa chegou no alvo: tira uma bolinha de névoa da criança apagada
## (a última faz ela acender), ou empurra a frase ruim, que dorme um pouco.
func _ao_acertar_palavra(alvo: Node2D, rumo: Vector2) -> void:
	var crianca := alvo as Crianca
	if crianca:
		crianca.tirar_nevoa(1, crianca.global_position - rumo)
		Audio.tocar_sfx("estouro")
		Jogo.somar_pontos(PONTOS_PALAVRA)
	elif (alvo as Frase).espantar(alvo.global_position - rumo, 2.0, EMPURRAO_PALAVRA, SONO_PALAVRA):
		Jogo.somar_pontos(PONTOS_EMPURRAO)


## Brilho grande (carga cheia): um anel de luz desfaz as palavras ruins que voam
## dentro dele, espanta as frases ruins, tira névoa das crianças apagadas (que
## param para escutar) e puxa os vaga-lumes de perto. Gasta a carga. A próxima
## palavra boa espera o intervalo: o mesmo aperto (ou o botão segurado) não solta as duas.
func _brilho_grande() -> void:
	var centro := menina.global_position
	vagalumes.carga = 0
	espera_palavra = INTERVALO_PALAVRA
	hud.esconder_botao()
	Audio.tocar_sfx("brilhar")
	_anel(centro, RAIO_BRILHAR, 0.5)
	_falar(DadosFases.PALAVRAS_MENINA.pick_random())
	for palavra: Palavra in get_tree().get_nodes_in_group(Palavra.GRUPO_RUINS):
		if palavra.pos.distance_to(centro) <= RAIO_BRILHAR:
			palavra.sumir()
	var pontos := 0
	var alvos := 0
	for no in get_tree().get_nodes_in_group("seguidoras"):
		if (no as Frase).espantar(centro, RAIO_BRILHAR, 60.0, 8.0):
			pontos += PONTOS_ESPANTO
			alvos += 1
	for crianca in criancas:
		if not crianca.acesa and crianca.global_position.distance_to(centro) <= RAIO_BRILHAR:
			alvos += 1
			if crianca.escutar(ESCUTA_BRILHO):
				pontos += PONTOS_ESCUTA
			crianca.tirar_nevoa(NEVOA_BRILHO, centro)
	vagalumes.puxar(centro, RAIO_BRILHAR)
	Jogo.somar_pontos(pontos * 2 if alvos >= 3 else pontos)


func _anel(centro: Vector2, raio: float, segundos: float) -> void:
	var anel := AnelDeLuz.new()
	anel.position = centro
	anel.raio_final = raio
	anel.duracao = segundos
	sobre_nevoa.add_child(anel)


## A menina fala uma palavra boa curta num balão.
func _falar(texto: String) -> void:
	if is_instance_valid(balao_menina):
		balao_menina.fechar()
	balao_menina = Balao.criar(texto, true)
	balao_menina.position = menina.global_position + Vector2(0, -13)
	sobre_nevoa.add_child(balao_menina)
	create_tween().tween_callback(balao_menina.fechar).set_delay(1.3)


# ---------- Mapa ----------

## Pares ditos: a frase boa fica no meio de uma área livre, e as crianças
## apagadas do par andam ali em volta, soltando a palavra ruim do par (elas
## "guardam" a frase).
func _criar_pares_ditos() -> void:
	var tipos: Array = DadosFases.TIPOS_CRIANCA.duplicate()
	tipos.shuffle()
	for i in dados.ditas.size():
		var par: int = dados.ditas[i]
		var quantas: int = dados.criancas[i]
		var tamanho := AREA_CRIANCA + Vector2(24, 14) * (quantas - 1)
		# Fase 1: a primeira frase fica perto do começo, e os primeiros segundos ensinam o jogo.
		var perto: bool = Jogo.fase_atual == 0 and i == 0
		var centro := _lugar_do_comeco(tamanho) if perto else _lugar_livre(tamanho, 12.0, LONGE_DO_INICIO)
		if centro.x < 0.0:
			continue
		var frase := _nova_frase(true, par)
		_por_frase_boa(frase, centro)
		if perto:
			primeira_frase = frase
		var area := Rect2(centro - tamanho / 2.0, tamanho).grow(-14.0)
		for n in quantas:
			var crianca := Crianca.new()
			crianca.menina = menina
			crianca.sobre_nevoa = sobre_nevoa
			crianca.configurar(tipos[criancas.size() % tipos.size()], par, area, dados)
			crianca.position = Vector2(
				randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
			crianca.acendeu.connect(_ao_acender_crianca)
			cenario.add_child(crianca)
			criancas.append(crianca)


## Pares pensados: a frase boa num lugar livre, com uma frase ruim dormindo
## perto dela (guarda o prêmio) e as outras espalhadas pelo mapa.
func _criar_pares_pensados() -> void:
	for i in dados.pensadas.size():
		var par: int = dados.pensadas[i]
		var boa := _nova_frase(true, par)
		var lugar := _lugar_livre(boa.tamanho_texto + Vector2(8, 8), 14.0, LONGE_DO_INICIO)
		if lugar.x < 0.0:
			boa.queue_free()
			continue
		_por_frase_boa(boa, lugar)
		for n in dados.seguidoras[i]:
			var ruim := _nova_frase(false, par)
			var tamanho := ruim.tamanho_texto + Vector2(8, 8)
			var pos := _lugar_perto(lugar, tamanho, 70.0, 100.0) if n == 0 else Vector2(-1, -1)
			if pos.x < 0.0:
				pos = _lugar_livre(tamanho, 10.0, LONGE_DO_INICIO + 30.0)
			if pos.x < 0.0:
				ruim.queue_free()
				continue
			ruim.position = pos


func _nova_frase(boa: bool, par: int) -> Frase:
	var frase: Frase = CENA_FRASE.instantiate()
	frase.configurar(boa, DadosFases.PARES[par][1 if boa else 0], par)
	frase.menina = menina
	frase.mapa = mapa
	frase.passo = dados.passo
	cenario.add_child(frase)   # já na árvore, para medir o texto com a fonte do tema
	return frase


func _por_frase_boa(frase: Frase, pos: Vector2) -> void:
	frase.position = pos
	frase.pega.connect(_ao_pegar_frase_boa)
	frases_boas.append(frase)
	boas_total += 1


## Lugares seguros da fase (banco da amizade ou poste), com espaço livre em volta.
func _criar_refugios() -> void:
	var r: Dictionary = dados.refugio
	if r.is_empty():
		return
	var caminho := "res://assets/sprites/%s/%%s/%s_01_nativa.png" % [r.pasta, r.tipo]
	for i in r.qtd:
		var pos := _lugar_livre(Vector2.ONE * (Refugio.RAIO * 2.0 + 8.0), 12.0, 150.0)
		if pos.x < 0.0:
			continue
		var refugio := Refugio.new()
		refugio.position = pos
		refugio.raio_acender = r.acende_perto
		refugio.cura = r.cura
		if ResourceLoader.exists(caminho % "melancolica"):
			var sprite := Sprite2D.new()
			sprite.texture = load(caminho % "melancolica")
			sprite.scale = Vector2.ONE * ESCALA_CENARIO
			sprite.z_index = r.get("z", 0)
			refugio.add_child(sprite)
			sprites_cenario.append([sprite, caminho % "original"])
		cenario.add_child(refugio)
		refugio.preparar(sobre_nevoa)
		refugio.acendeu.connect(_ao_acender_refugio)
		refugios.append(refugio)


## Sorteia os sprites de um grupo de DadosFases. Obstáculos ganham colisão.
func _criar_objetos(grupo: Dictionary, solido: bool) -> void:
	var numeros := range(1, grupo.variantes + 1)
	numeros.shuffle()   # sem repetir enquanto der
	for i in grupo.qtd:
		var caminho := "res://assets/sprites/%s/%%s/%s_%02d_nativa.png" % [
			grupo.pasta, grupo.nome, numeros[i % numeros.size()]]
		if not ResourceLoader.exists(caminho % "melancolica"):
			continue   # arte ainda não chegou
		var textura: Texture2D = load(caminho % "melancolica")
		var tamanho := textura.get_size() * ESCALA_CENARIO
		var pos := _lugar_livre(tamanho, 16.0 if solido else 6.0)
		if pos.x < 0.0:
			continue

		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.scale = Vector2.ONE * ESCALA_CENARIO
		sprite.z_index = grupo.get("z", 0)   # 10: a menina passa por baixo (copas, plantas)
		sprites_cenario.append([sprite, caminho % "original"])
		if solido:
			var corpo := StaticBody2D.new()
			corpo.position = pos
			corpo.add_child(sprite)
			_criar_colisao(corpo, textura)
			cenario.add_child(corpo)
			solidos.append(Rect2(pos - tamanho / 2.0, tamanho))
		else:
			sprite.position = pos
			cenario.add_child(sprite)


## Colisão no formato do desenho (alfa do sprite), sem paredes invisíveis
## nas casas em L, T ou cruz. Sem a imagem, usa o retângulo do sprite.
func _criar_colisao(corpo: StaticBody2D, textura: Texture2D) -> void:
	var tamanho := textura.get_size()
	var imagem := textura.get_image()
	if imagem and not imagem.is_empty():
		if imagem.is_compressed():
			imagem.decompress()
		var bits := BitMap.new()
		bits.create_from_image_alpha(imagem)
		for contorno in bits.opaque_to_polygons(Rect2(Vector2.ZERO, tamanho), 1.0):
			var pontos := PackedVector2Array()
			for p in contorno:
				pontos.append((p - tamanho / 2.0) * ESCALA_CENARIO)
			var poligono := CollisionPolygon2D.new()
			poligono.polygon = pontos
			corpo.add_child(poligono)
	if corpo.get_child_count() > 1:   # o sprite + pelo menos um polígono
		return
	var colisao := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = tamanho * ESCALA_CENARIO - Vector2(4, 4)
	colisao.shape = forma
	corpo.add_child(colisao)


## Vaga-lumes: uma trilha de 6 leva a cada frase boa (a frase continua escondida
## na névoa), mais trilhas-isca e grupinhos de 3.
func _criar_vagalumes() -> void:
	var inicio := menina.position
	for frase in frases_boas:
		var destino := frase.position
		var para_o_inicio := destino.direction_to(inicio)
		var de := destino + para_o_inicio * 220.0
		if frase == primeira_frase:   # começa quase no pé da menina
			de = inicio - para_o_inicio * 26.0
		_trilha(de, destino + para_o_inicio * 42.0, 6)
	for i in dados.iscas:
		var meio := _lugar_livre(Vector2(40, 40), 6.0, 150.0)
		if meio.x >= 0.0:
			var direcao := Vector2.from_angle(randf() * TAU)
			_trilha(meio - direcao * 75.0, meio + direcao * 75.0, 6)
	for i in 2:
		var meio := _lugar_livre(Vector2(40, 40), 6.0, 150.0)
		if meio.x >= 0.0:
			for n in 3:
				_vagalume(meio + Vector2.from_angle(TAU * n / 3.0) * 12.0)


func _trilha(de: Vector2, ate: Vector2, quantos: int) -> void:
	for n in quantos:
		_vagalume(de.lerp(ate, n / float(quantos - 1)))


## Só nasce onde a menina alcança: dentro do mapa e fora dos obstáculos.
func _vagalume(pos: Vector2) -> void:
	if not Rect2(Vector2.ZERO, mapa).grow(-14.0).has_point(pos):
		return
	for solido in solidos:
		if solido.grow(6.0).has_point(pos):
			return
	vagalumes.adicionar(pos)


## Sorteia um lugar onde cabe um retângulo do tamanho dado, sem encostar em nada
## e a pelo menos `longe` do começo. Retorna (-1, -1) se não achar.
func _lugar_livre(tamanho: Vector2, folga: float, longe := 0.0) -> Vector2:
	var inicio := mapa / 2.0
	for _tentativa in 300:
		var pos := Vector2(
			randf_range(MARGEM + tamanho.x / 2.0, mapa.x - MARGEM - tamanho.x / 2.0),
			randf_range(MARGEM + tamanho.y / 2.0, mapa.y - MARGEM - tamanho.y / 2.0))
		if pos.distance_to(inicio) >= longe and _reservar(pos, tamanho, folga):
			return pos
	return Vector2(-1, -1)


## Como _lugar_livre, mas a uma distância entre `perto` e `longe` de `centro`.
func _lugar_perto(centro: Vector2, tamanho: Vector2, perto: float, longe: float) -> Vector2:
	var dentro := Rect2(Vector2.ZERO, mapa).grow(-MARGEM)
	for _tentativa in 40:
		var pos := centro + Vector2.from_angle(randf() * TAU) * randf_range(perto, longe)
		if dentro.encloses(Rect2(pos - tamanho / 2.0, tamanho)) and _reservar(pos, tamanho, 4.0):
			return pos
	return Vector2(-1, -1)


## Fase 1: a área da primeira frase boa, a uns 200 px do começo, para um dos lados.
func _lugar_do_comeco(tamanho: Vector2) -> Vector2:
	var lado := 1.0 if randf() < 0.5 else -1.0
	var pos := mapa / 2.0 + Vector2(200.0 * lado, randf_range(-30.0, 30.0))
	_reservar(pos, tamanho, 0.0)
	return pos


## Reserva o retângulo se ele não encostar em nada já colocado.
func _reservar(pos: Vector2, tamanho: Vector2, folga: float) -> bool:
	var area := Rect2(pos - tamanho / 2.0, tamanho)
	for outro in ocupados:
		if outro.intersects(area.grow(folga)):
			return false
	ocupados.append(area)
	return true


# ---------- O que acontece no jogo ----------

func _ao_pegar_vagalume(combo: int) -> void:
	sem_pegar = 0.0
	menina.luz = minf(menina.luz + LUZ_VAGALUME, menina.luz_max)
	Jogo.somar_pontos(PONTOS_VAGALUME * mini(combo, 5))
	hud.atualizar_vagalumes(vagalumes.pegos, vagalumes.total)
	if vagalumes.carga >= Vagalumes.CARGA_CHEIA and estado == Estado.JOGANDO:
		hud.mostrar_botao("brilhar", menina)
		_dica("brilhar", "Brilho cheio! Chegue perto e aperte %s." % Jogo.nome_botao("brilhar"))


func _ao_pegar_frase_boa(frase: Frase) -> void:
	boas_pegas += 1
	sem_pegar = 0.0
	frases_boas.erase(frase)
	Jogo.somar_pontos(PONTOS_FRASE_BOA)
	Audio.tocar_sfx("frase_boa")
	hud.mostrar_frase(frase.texto)
	hud.atualizar_contador(boas_pegas, boas_total)
	hud.esconder_seta()

	# Cada frase boa responde a uma ruim: um fio dourado leva a resposta até as
	# crianças do par (fica faltando só uma palavra boa para cada uma acender; na
	# última frase boa elas acendem) e até as frases ruins do par (que se desfazem).
	var ultima := boas_pegas == boas_total
	for crianca in criancas:
		if crianca.par == frase.par and not crianca.acesa:
			_fio(crianca, crianca.acender if ultima else _quase_acender.bind(crianca))
	if not ultima:
		for no in get_tree().get_nodes_in_group("seguidoras"):
			var ruim := no as Frase
			if ruim.par == frase.par and not ruim.dissolvendo:
				_fio(ruim, _desfazer.bind(ruim))
		_clarear()
	else:
		_mundo_claro()


func _fio(alvo: Node2D, ao_chegar: Callable) -> void:
	var fio := FioDourado.new()
	fio.position = menina.global_position
	fio.alvo = alvo
	fio.ao_chegar = ao_chegar
	sobre_nevoa.add_child(fio)


## A frase boa do par tira quase toda a névoa da criança: sobra uma bolinha.
func _quase_acender(crianca: Crianca) -> void:
	crianca.tirar_nevoa(crianca.nevoa - 1, menina.global_position)


func _desfazer(ruim: Frase) -> void:
	ruim.dissolver()
	Audio.tocar_sfx("dissolver")


## A bolha abre e o mundo clareia um pouco a cada frase boa (tom e névoa).
func _clarear() -> void:
	var progresso := float(boas_pegas) / boas_total
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(menina, "raio_extra", RAIO_EXTRA * progresso, 1.2)
	t.tween_property(tom, "color", dados.tom.lerp(Color.WHITE, CLAREAR_POR_FRASE * boas_pegas), 1.2)
	menina.nevoa.clarear(progresso * dados.nevoa_clara, 1.2)


func _ao_acender_crianca(_crianca: Crianca) -> void:
	var acesas := 0
	for crianca in criancas:
		if crianca.acesa:
			acesas += 1
	hud.atualizar_amigas(acesas, criancas.size())
	Jogo.somar_pontos(PONTOS_AMIGA)


func _ao_acender_refugio(refugio: Refugio) -> void:
	Audio.tocar_sfx("amigo")
	Jogo.somar_pontos(PONTOS_REFUGIO)
	# O poste aceso mostra a versão colorida na hora.
	for par in sprites_cenario:
		var sprite: Sprite2D = par[0]
		if sprite.get_parent() == refugio and ResourceLoader.exists(par[1]):
			sprite.texture = load(par[1])
	_dica("refugio", "Luz acesa: lugar seguro!")


func _ao_levar_dano() -> void:
	Audio.tocar_sfx("dano")
	hud.piscar(_piscadas())
	vagalumes.combo = 0


## Ideia 3: 2, 3 ou 4 piscadas pelos hits que ainda cabem na luz.
func _piscadas() -> int:
	var restantes := ceili(menina.luz / menina.dano_frase_ruim)
	if restantes >= 3:
		return 2
	if restantes == 2:
		return 3
	return 4


## Um hit levaria a luz a zero: em vez de perder, a menina para e respira.
## As frases ruins dormem, as palavras ruins que voam somem, os balões fecham e
## as crianças se calam por um tempo; ela levanta com luz de novo.
## No Difícil dá para respirar só `dados.respiros` vezes por fase: na vez seguinte
## ela respira do mesmo jeito, mas no fim a luz apaga: o mundo para e o HUD mostra
## uma tela calma para recomeçar a fase.
func _respirar() -> void:
	if estado != Estado.JOGANDO:
		return
	estado = Estado.RESPIRANDO
	vezes_respirou += 1
	aperto_guardado = false
	Jogo.pontos = maxi(Jogo.pontos - CUSTO_RESPIRAR, 0)
	Audio.tocar_sfx("luz_apagando")
	get_tree().call_group("seguidoras", "dormir", 8.0)
	get_tree().call_group(Palavra.GRUPO_RUINS, "sumir")
	for crianca in criancas:
		crianca.calar(SILENCIO_RESPIRAR)
	hud.esconder_botao()
	var limite: int = dados.respiros
	if limite >= 0 and vezes_respirou > limite:
		Jogo.contando_tempo = false
		hud.respirou.connect(_luz_apagou, CONNECT_ONE_SHOT)
		hud.respirar(Hud.APAGOU)
		return
	hud.respirou.connect(_levantar, CONNECT_ONE_SHOT)
	hud.respirar(limite - vezes_respirou if limite >= 0 else -1)


## Acabaram os respiros (Difícil): o mundo para (nada acontece por baixo da tela,
## nem uma palavra boa que ainda voava) e o HUD oferece recomeçar.
func _luz_apagou() -> void:
	$Mundo.process_mode = Node.PROCESS_MODE_DISABLED
	hud.mostrar_luz_apagou()


func _levantar() -> void:
	if estado != Estado.RESPIRANDO:
		return
	estado = Estado.JOGANDO
	menina.levantar()
	if vagalumes.carga >= Vagalumes.CARGA_CHEIA:
		hud.mostrar_botao("brilhar", menina)


## Luz baixa há um tempo: um enxame de vaga-lumes passa perto da menina.
func _socorro() -> void:
	espera_socorro = SOCORRO_RECARGA
	Audio.tocar_sfx("procurar")
	var lado := 1.0 if menina.position.x < mapa.x / 2.0 else -1.0   # vem do lado com mais mapa
	for n in 8:
		var pos := menina.position + Vector2(lado * (200.0 + n * 22.0), randf_range(-32.0, 32.0))
		vagalumes.adicionar_bonus(pos, Vector2(-lado * 70.0, 0.0), 9.0)


## Dicas curtas, uma vez cada, quando a situação aparece (só as da fase 1 ensinam o básico).
func _dicas() -> void:
	if Jogo.fase_atual != 0:
		return
	if tempo_fase >= 3.5:
		_dica("vagalumes", "Siga os vaga-lumes!")
	if Frase.acordadas > 0:
		_dica("seguidora", "Ela te segue devagar. Ande!")
	for crianca in criancas:
		if crianca.em_confronto:
			_dica("confronto", "Desvie! Aperte %s para responder." % Jogo.nome_botao("brilhar"))


func _dica(chave: String, texto: String) -> void:
	if not dicas_dadas.has(chave):
		dicas_dadas[chave] = true
		hud.mostrar_dica(texto, 3.5)


# ---------- Última frase boa: o mundo fica claro e a névoa vira a nuvem ----------

func _mundo_claro() -> void:
	estado = Estado.CLARO
	Frase.liberadas = false
	menina.em_refugio = false
	menina.iluminar()   # a luz enche e não cai mais; nada mais machuca
	get_tree().call_group(Palavra.GRUPO_RUINS, "sumir")
	for crianca in criancas:
		crianca.calar()   # quem estava avisando desiste
	hud.esconder_botao()
	hud.esconder_seta()

	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(menina, "raio_extra", RAIO_EXTRA, 1.2)
	t.tween_property(tom, "color", Color.WHITE, TEMPO_CLAREAR)
	menina.nevoa.dissipar(TEMPO_CLAREAR)
	for par in sprites_cenario:
		if ResourceLoader.exists(par[1]):
			var sprite: Sprite2D = par[0]
			sprite.texture = load(par[1])

	# A névoa se junta: fiapos roxos e as frases ruins que sobraram voam para um
	# ponto dentro da tela, e ali nasce a nuvem escura.
	var ponto := _ponto_da_nuvem()
	for no in get_tree().get_nodes_in_group("seguidoras"):
		(no as Frase).voar_para(ponto, 1.3)
	for n in 16:
		_fiapo(menina.position + Vector2.from_angle(randf() * TAU) * randf_range(120.0, 260.0), ponto)
	var depois := create_tween()
	depois.tween_callback(_surgir_nuvem.bind(ponto)).set_delay(1.3)
	depois.tween_callback(_acender_todas).set_delay(0.5)


## Dentro da tela, para o lado com mais mapa, sem cair em cima de um obstáculo.
func _ponto_da_nuvem() -> Vector2:
	var lado := 1.0 if menina.position.x < mapa.x / 2.0 else -1.0
	var dentro := Rect2(Vector2.ZERO, mapa).grow(-70.0)
	var ponto := menina.position + Vector2(lado * 150.0, 0.0)
	for _tentativa in 12:
		ponto = menina.position + Vector2(lado * randf_range(130.0, 170.0), randf_range(-50.0, 50.0))
		ponto = ponto.clamp(dentro.position, dentro.end)
		var livre := true
		for solido in solidos:
			if solido.grow(24.0).has_point(ponto):
				livre = false
				break
		if livre:
			break
	return ponto


func _fiapo(de: Vector2, ate: Vector2) -> void:
	var fiapo := Polygon2D.new()
	fiapo.polygon = PackedVector2Array([Vector2(-2, -1), Vector2(2, -1), Vector2(2, 1), Vector2(-2, 1)])
	fiapo.color = Color(0.45, 0.33, 0.6, 0.85)
	fiapo.position = de
	sobre_nevoa.add_child(fiapo)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(fiapo, "position", ate, randf_range(0.9, 1.3))
	t.tween_callback(fiapo.queue_free)


func _surgir_nuvem(ponto: Vector2) -> void:
	nuvem = CENA_NUVEM.instantiate()
	nuvem.position = ponto
	nuvem.tocada.connect(_comecar_final)
	cenario.add_child(nuvem)
	nuvem.surgir()
	Audio.tocar_sfx("nuvem_surge")
	hud.mostrar_dica("A névoa virou uma nuvem!", 2.6)
	hud.mostrar_seta(menina, nuvem, 0.0)   # fica até ela chegar
	# Um caminho de vaga-lumes da menina até a nuvem, como convite.
	for n in 8:
		vagalumes.adicionar_bonus(menina.position.lerp(ponto, (n + 1.5) / 10.0), Vector2.ZERO, 40.0)
	create_tween().tween_callback(_convidar).set_delay(2.8)


func _convidar() -> void:
	if estado == Estado.CLARO:
		hud.mostrar_dica("Leve a sua luz até ela!", 4.0)


## Garantia: com o mundo claro, nenhuma criança fica apagada.
func _acender_todas() -> void:
	for crianca in criancas:
		if not crianca.acesa:
			crianca.acender()


# ---------- Final: a menina brilha dentro da nuvem ----------

func _comecar_final() -> void:
	if estado != Estado.CLARO:
		return
	estado = Estado.FINAL
	menina.ativa = false
	menina.sprite.play("parada_baixo")
	hud.esconder_seta()
	Audio.tocar_musica("final")
	var centro := nuvem.position
	nuvem.abrir()
	for i in criancas.size():   # as amigas ficam em volta dela
		criancas[i].ir_para(centro + Vector2.from_angle(TAU * i / criancas.size() + 0.5) * 30.0)
	var t := create_tween()
	t.tween_property(menina, "position", centro, 0.6)
	t.tween_callback(_criar_final)


func _criar_final() -> void:
	var pares: Array = []
	for par: int in dados.ditas + dados.pensadas:
		pares.append(DadosFases.PARES[par])
	var final := FinalFase.new()
	final.position = menina.position
	final.terminou.connect(_fim_do_final)
	sobre_nevoa.add_child(final)
	final.comecar(menina, criancas, pares, dados.final_palavras, dados.frase_chave, hud)


func _fim_do_final(respondidas_longe: int, total: int) -> void:
	estado = Estado.FIM
	Jogo.contando_tempo = false
	nuvem.subir()
	Audio.tocar_sfx("comemoracao")
	for crianca in criancas:
		crianca.comemorar()
	# Tween em vez de await: se a cena for trocada antes, nada fica pendurado.
	create_tween().tween_callback(_mostrar_painel.bind(respondidas_longe, total)).set_delay(2.2)


## Estrelas: terminou; pegou 60% dos vaga-lumes; respondeu 80% das palavras do
## final antes de elas chegarem perto.
func _mostrar_painel(respondidas_longe: int, total: int) -> void:
	var meta_vagalumes := ceili(vagalumes.total * 0.6)
	var meta_respostas := ceili(total * 0.8)
	var estrelas := [true, vagalumes.pegos >= meta_vagalumes, respondidas_longe >= meta_respostas]
	var motivos := [
		"Terminou",
		"%d de %d vaga-lumes" % [vagalumes.pegos, vagalumes.total],
		"%d de %d respostas" % [respondidas_longe, total],
	]
	var ganhas := estrelas.count(true)
	Jogo.registrar_estrelas(ganhas)
	Jogo.somar_pontos(PONTOS_ESTRELA * ganhas)
	var ultima := Jogo.fase_atual + 1 >= DadosFases.FASES.size()
	hud.mostrar_fase_concluida(Jogo.fase_atual + 1, Jogo.pontos - Jogo.pontos_inicio_fase, estrelas, motivos, ultima)
