extends Node2D
## Uma fase (campo, escola ou beco), montada com DadosFases.FASES[Jogo.fase_atual].
## Os nós fixos (chão, menina, névoa e HUD) ficam na cena cenas/fase.tscn.
## Obstáculos, decoração, frases e a nuvem escura são sorteados a cada partida
## dentro de Mundo/Cenario. O HUD cuida da pausa e dos botões das telas de fim.
## Ver docs/visao_geral.md e Ideias/.

const CENA_FRASE := preload("res://cenas/frase.tscn")
const CENA_NUVEM := preload("res://cenas/nuvem_escura.tscn")

const MARGEM := 24.0
# Obstáculos e decoração desenhados pequenos demais perto da menina: ampliados no jogo.
# Provisório (ver docs/decisoes.md). Use número inteiro para o pixel ficar nítido.
const ESCALA_CENARIO := 2.0
const DISTANCIA_NUVEM := 550.0   # a nuvem nasce longe do começo
const INTERVALO_PULSO := 1.2     # som "pulso" com a luz baixa
const PONTOS_FRASE_BOA := 100
const RECARGA_PROCURAR := 5.0    # segundos entre um uso e outro do poder "Procurar"

var dados: Dictionary
var ocupados: Array[Rect2] = []
var sprites_cenario: Array = []   # [sprite, caminho da versão original] para a vitória
var boas_total := 0
var boas_pegas := 0
var terminou := false
var espera_pulso := 0.0
var espera_procurar := 0.0
var nuvem: NuvemEscura

@onready var tom: CanvasModulate = $Mundo/Tom  # deixa o mundo um pouco apagado
@onready var chao: Sprite2D = $Mundo/Chao
@onready var cenario: Node2D = $Mundo/Cenario  # obstáculos, decoração, frases e nuvem
@onready var menina: Menina = $Mundo/Menina
@onready var hud: Hud = $HUD


func _ready() -> void:
	dados = DadosFases.FASES[Jogo.fase_atual]
	tom.color = dados.tom
	if ResourceLoader.exists(dados.chao):
		chao.texture = load(dados.chao)
	menina.mult_fase = dados.queda
	menina.apagou.connect(_game_over)
	menina.ferida.connect(_ao_levar_dano)

	ocupados.append(Rect2(menina.position - Vector2(48, 48), Vector2(96, 96)))   # área livre no começo
	_criar_nuvem()
	for grupo: Dictionary in dados.obstaculos:
		_criar_objetos(grupo, true)
	for grupo: Dictionary in dados.decoracao:
		_criar_objetos(grupo, false)
	_criar_frases()

	hud.configurar(Jogo.fase_atual + 1, dados.nome, dados.subtitulo, boas_total)
	hud.procurar_pedido.connect(procurar)
	if Jogo.fase_atual == 0:   # depois do cartão de título, ensina o poder
		create_tween().tween_callback(hud.mostrar_dica.bind("Aperte Espaço para procurar as frases boas", 4.0)).set_delay(3.2)
	Audio.tocar_musica(dados.musica)
	Jogo.contando_tempo = true


func _process(delta: float) -> void:
	hud.atualizar_luz(menina.luz, menina.luz_max, menina.luz_baixa)
	espera_procurar = maxf(espera_procurar - delta, 0.0)
	var falta := 1.0 if terminou or not menina.ativa else espera_procurar / RECARGA_PROCURAR
	hud.atualizar_poder(falta, menina.get_global_transform_with_canvas().origin)
	# Luz baixa: além da bolha pulsando, um "pulso" baixinho, como um coração.
	if terminou or not menina.ativa or menina.luz > menina.luz_baixa:
		espera_pulso = 0.0
		return
	espera_pulso -= delta
	if espera_pulso <= 0.0:
		Audio.tocar_sfx("pulso")
		espera_pulso = INTERVALO_PULSO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("procurar"):
		get_viewport().set_input_as_handled()
		procurar()


## Poder "Procurar" (Espaço ou o botão do HUD): uma seta piscando aponta a frase
## boa mais perto ou, com todas pegas, a nuvem. Depois espera RECARGA_PROCURAR.
func procurar() -> void:
	if terminou or not menina.ativa:
		return
	if espera_procurar > 0.0:
		hud.mostrar_dica("O poder volta em %d s" % ceili(espera_procurar), 1.2)
		return
	espera_procurar = RECARGA_PROCURAR
	Audio.tocar_sfx("procurar")
	hud.mostrar_seta(menina, _alvo_mais_perto())


func _alvo_mais_perto() -> Node2D:
	var alvo: Node2D = nuvem
	var menor := INF
	for no in cenario.get_children():
		var frase := no as Frase
		if frase and frase.boa and not frase.is_queued_for_deletion():
			var distancia := frase.global_position.distance_squared_to(menina.global_position)
			if distancia < menor:
				menor = distancia
				alvo = frase
	return alvo


# ---------- Mapa ----------

func _criar_nuvem() -> void:
	nuvem = CENA_NUVEM.instantiate()
	var inicio := menina.position
	var tamanho := Vector2(128, 80)
	for _tentativa in 200:
		var pos := Vector2(
			randf_range(MARGEM + tamanho.x, DadosFases.TAMANHO_MAPA.x - MARGEM - tamanho.x),
			randf_range(MARGEM + tamanho.y, DadosFases.TAMANHO_MAPA.y - MARGEM - tamanho.y))
		if pos.distance_to(inicio) >= DISTANCIA_NUVEM:
			nuvem.position = pos
			break
	cenario.add_child(nuvem)
	ocupados.append(Rect2(nuvem.position - nuvem.tamanho() / 2.0, nuvem.tamanho()).grow(16.0))
	nuvem.tocada.connect(_ao_tocar_nuvem)


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
		var pos := _lugar_livre(textura.get_size() * ESCALA_CENARIO, 16.0 if solido else 6.0)
		if pos.x < 0.0:
			continue

		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.scale = Vector2.ONE * ESCALA_CENARIO
		sprite.z_index = grupo.get("z", 0)   # 10: a menina passa por baixo (copas, postes)
		sprites_cenario.append([sprite, caminho % "original"])
		if solido:
			var corpo := StaticBody2D.new()
			corpo.position = pos
			corpo.add_child(sprite)
			_criar_colisao(corpo, textura)
			cenario.add_child(corpo)
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
		var mapa := BitMap.new()
		mapa.create_from_image_alpha(imagem)
		for contorno in mapa.opaque_to_polygons(Rect2(Vector2.ZERO, tamanho), 1.0):
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


func _criar_frases() -> void:
	var pares: Array = dados.pares
	for n in pares:
		if _colocar_frase(true, n, "parada"):
			boas_total += 1

	# Frases ruins: os tipos embaralhados, os textos repetindo os pares da fase.
	var tipos: Array[String] = []
	for tipo: String in dados.ruins:
		for i in dados.ruins[tipo]:
			tipos.append(tipo)
	tipos.shuffle()
	for i in tipos.size():
		_colocar_frase(false, pares[i % pares.size()], tipos[i])


func _colocar_frase(boa: bool, n_par: int, tipo: String) -> bool:
	var frase: Frase = CENA_FRASE.instantiate()
	frase.configurar(boa, DadosFases.PARES[n_par][1 if boa else 0], n_par, tipo, dados.caminho)
	frase.menina = menina
	cenario.add_child(frase)   # já na árvore, para medir o texto com a fonte do tema
	var pos := _lugar_livre(frase.area(), 10.0)
	if pos.x < 0.0:
		frase.queue_free()
		return false
	frase.colocar(pos)
	if boa:
		frase.pega.connect(_ao_pegar_frase_boa)
	return true


## Sorteia um lugar onde cabe um retângulo do tamanho dado, sem encostar em nada.
## Retorna (-1, -1) se não achar.
func _lugar_livre(tamanho: Vector2, folga: float) -> Vector2:
	var mapa := DadosFases.TAMANHO_MAPA
	for _tentativa in 300:
		var pos := Vector2(
			randf_range(MARGEM + tamanho.x / 2.0, mapa.x - MARGEM - tamanho.x / 2.0),
			randf_range(MARGEM + tamanho.y / 2.0, mapa.y - MARGEM - tamanho.y / 2.0))
		var area := Rect2(pos - tamanho / 2.0, tamanho)
		var livre := true
		for outro in ocupados:
			if outro.intersects(area.grow(folga)):
				livre = false
				break
		if livre:
			ocupados.append(area)
			return pos
	return Vector2(-1, -1)


# ---------- Frases ----------

func _ao_pegar_frase_boa(frase: Frase) -> void:
	boas_pegas += 1
	Jogo.somar_pontos(PONTOS_FRASE_BOA)
	Audio.tocar_sfx("frase_boa")
	hud.mostrar_frase(frase.texto)
	hud.atualizar_contador(boas_pegas, boas_total)

	# Cada frase boa responde a uma ruim: as ruins do mesmo par se desfazem.
	var dissolveu := false
	for ruim in _frases_ruins():
		if ruim.par == frase.par:
			ruim.dissolver()
			dissolveu = true
	if dissolveu:
		Audio.tocar_sfx("dissolver")

	if boas_pegas == boas_total:
		hud.mostrar_dica("Agora vá até a nuvem escura!")
		nuvem.pulsar()


func _ao_levar_dano() -> void:
	Audio.tocar_sfx("dano")
	hud.piscar(_piscadas())


## Ideia 3: 2, 3 ou 4 piscadas pelos hits que ainda cabem na luz.
func _piscadas() -> int:
	var restantes := ceili(menina.luz / menina.dano_frase_ruim)
	if restantes >= 3:
		return 2
	if restantes == 2:
		return 3
	return 4


func _frases_ruins() -> Array[Frase]:
	var lista: Array[Frase] = []
	for no in cenario.get_children():
		var frase := no as Frase
		if frase and not frase.boa and not frase.dissolvendo:
			lista.append(frase)
	return lista


# ---------- Fim da fase ----------

func _ao_tocar_nuvem() -> void:
	if terminou:
		return
	if boas_pegas < boas_total:
		hud.mostrar_dica("Junte todas as frases boas (%d/%d)" % [boas_pegas, boas_total])
		return
	_vitoria()


## Nuvem dissipada: a névoa some, o mundo ganha cor e as frases ruins se desfazem.
func _vitoria() -> void:
	terminou = true
	Jogo.contando_tempo = false
	Jogo.somar_pontos(roundi(menina.luz))   # a luz que sobrou vira ponto
	Audio.tocar_sfx("nuvem")
	nuvem.dissipar()
	menina.iluminar()
	menina.nevoa.dissipar(3.0)
	for ruim in _frases_ruins():
		ruim.dissolver()
	create_tween().tween_property(tom, "color", Color.WHITE, 3.0)
	for par in sprites_cenario:
		if ResourceLoader.exists(par[1]):
			var sprite: Sprite2D = par[0]
			sprite.texture = load(par[1])
	# Tween em vez de await: se a cena for trocada antes, nada fica pendurado.
	create_tween().tween_callback(_mostrar_fim).set_delay(3.5)


func _mostrar_fim() -> void:
	# A tela de fim usa as setas para trocar de botão: a menina para de andar.
	menina.ativa = false
	menina.sprite.play("parada_" + menina.direcao)
	Audio.tocar_sfx("fase_completa")
	if Jogo.fase_atual + 1 < DadosFases.FASES.size():
		hud.mostrar_fase_concluida(Jogo.fase_atual + 1, Jogo.pontos - Jogo.pontos_inicio_fase)
	else:
		Placar.enviar_pontuacao(Jogo.pontos)
		Audio.tocar_musica("vitoria")
		hud.mostrar_final(Jogo.pontos, Jogo.tempo_partida)


func _game_over() -> void:
	if terminou:
		return
	terminou = true
	Jogo.contando_tempo = false
	Audio.tocar_sfx("luz_apagando")
	Audio.tocar_musica("game_over")
	hud.mostrar_game_over()
