extends Control
## História em cartões de 2 linhas: antes de cada fase (DadosFases.FASES[...].historia)
## e, depois da última, a história final (DadosFases.HISTORIA_FINAL) seguida da
## tela final (tempo, pontos, estrelas, dificuldade, recorde e créditos).
## A menina anda no lugar dentro de um círculo de luz, com o chão da fase rolando,
## e as amigas que já acenderam vêm atrás dela. No final o mundo está claro.
## Tudo é montado aqui; a cena cenas/historia.tscn só tem a raiz.

const COR_OURO := Color(1.0, 0.827, 0.42)
const COR_OURO_CLARO := Color(1.0, 0.878, 0.541)
const COR_TEXTO := Color(0.925, 0.902, 0.961)
const COR_SUAVE := Color(0.663, 0.612, 0.761)
const COR_NOITE := Color(0.043, 0.039, 0.078)
const TELA := Vector2(480, 270)
const TEMPO_CARTAO := 3.5      # cada cartão avança sozinho
const TRAVA := 1.5             # antes disso o botão não avança (nem vale na tela final)
const ABRINDO := 0.4           # a cena ainda está aparecendo: o Jogo ignoraria outra troca de cena
const VOLTA_AO_MENU := 60.0    # tela final sem nenhum botão
const CENTRO := Vector2(240, 100)   # a menina, na tela
const ESCALA := 2.0            # o palco é desenhado em dobro, como a menina do menu
const VELOCIDADE := 40.0       # px do palco por segundo: o chão rolando
const AMIGAS := [0, 2, 3]      # quantas amigas já andam com ela antes de cada fase
const LUGARES := [Vector2(-16, -8), Vector2(-18, 9), Vector2(-33, 0)]   # das amigas, atrás da menina
const RAIO_LUZ := 26.0         # círculo de luz (px do palco); abre um pouco a cada amiga
const RAIO_ESCURO := 48.0      # daqui para fora é noite: o círculo cabe inteiro acima do texto
const LUGAR_FINAL := Vector2(-44, 17)   # tela final: a turma anda à esquerda do painel

var cartoes: Array
var indice := -1
var relogio := 0.0       # tempo no cartão atual (ou na tela final)
var parado := 0.0        # tempo sem nenhum botão
var andado := 0.0        # quanto o chão já rolou
var saindo := false      # já pediu a troca de cena: ignora o resto
var chao: Sprite2D
var turma: Node2D        # a menina e as amigas
var legenda: ColorRect   # faixa escura com o texto do cartão
var texto: Label
var dica: Label
var tela_final: Control = null


func _ready() -> void:
	var final := Jogo.fim_de_jogo
	var dados: Dictionary = DadosFases.FASES[Jogo.fase_atual]
	cartoes = DadosFases.HISTORIA_FINAL if final else dados.historia
	Audio.tocar_musica("historia" if ResourceLoader.exists(Audio.MUSICA % "historia") else "menu")
	_montar_palco(dados, final)
	_montar_texto()
	_avancar()


func _process(delta: float) -> void:
	andado = fmod(andado + VELOCIDADE * delta, chao.texture.get_width())
	chao.region_rect.position.x = roundf(andado)
	relogio += delta
	parado += delta
	if saindo:
		return
	if tela_final == null:
		dica.text = "%s: continuar  ·  %s: pular" % [Jogo.nome_botao("brilhar"), Jogo.nome_botao("pausar")]
		dica.visible = relogio >= TRAVA
		if relogio >= TEMPO_CARTAO:
			_avancar()
	elif parado >= VOLTA_AO_MENU:
		_sair_para(Jogo.ir_para_menu)


func _input(event: InputEvent) -> void:
	if event.is_pressed():
		parado = 0.0
	if saindo:
		return
	if tela_final == null:
		if event.is_action_pressed("pausar"):
			if relogio >= ABRINDO:
				Audio.tocar_sfx("clique")
				_terminar()
		elif relogio >= TRAVA and (event.is_action_pressed("brilhar") or event.is_action_pressed("ui_accept")):
			Audio.tocar_sfx("clique")
			_avancar()
	# A tela final acabou de aparecer: nenhum botão vale ainda (nem o aperto que a abriu).
	if tela_final and relogio < TRAVA:
		get_viewport().set_input_as_handled()


# --- Cartões -------------------------------------------------------------

func _avancar() -> void:
	indice += 1
	if indice >= cartoes.size():
		_terminar()
		return
	relogio = 0.0
	texto.text = cartoes[indice]
	texto.modulate.a = 0.0
	create_tween().tween_property(texto, "modulate:a", 1.0, 0.4)


## Acabaram os cartões (ou foram pulados): abre a fase ou, no fim do jogo, a tela final.
func _terminar() -> void:
	if Jogo.fim_de_jogo:
		_mostrar_tela_final()
	else:
		_sair_para(Jogo.trocar_cena.bind(Jogo.CENA_FASE))


# --- Montagem ------------------------------------------------------------

func _montar_palco(dados: Dictionary, final: bool) -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_NOITE
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var palco := Node2D.new()
	palco.position = CENTRO
	palco.scale = Vector2.ONE * ESCALA
	add_child(palco)

	# O chão cobre a tela toda e rola para a esquerda: a menina "anda" para a direita.
	# No final é o campo, com todas as cores; antes, o chão da fase ainda apagado.
	chao = Sprite2D.new()
	chao.texture = load(DadosFases.FASES[0].chao if final else dados.chao)
	chao.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	chao.centered = false
	chao.position = -CENTRO / ESCALA
	chao.region_enabled = true
	chao.region_rect = Rect2(Vector2.ZERO, TELA / ESCALA)
	palco.add_child(chao)

	# As amigas vêm juntinhas atrás dela; a turma fica no meio do círculo de luz.
	var amigas: int = LUGARES.size() if final else AMIGAS[Jogo.fase_atual]
	turma = Node2D.new()
	turma.y_sort_enabled = true
	turma.position.x = 4.0 * amigas
	palco.add_child(turma)
	for i in amigas:
		var folha := Crianca.folha_de(DadosFases.TIPOS_CRIANCA[i], "cor")
		if folha != "":
			# Cada uma começa num quadro diferente, para não andarem todas iguais.
			_andando(Crianca.animacoes(load(folha)), LUGARES[i]).frame = i + 1
	# A menina com a mesma folha da fase (Menina.folha(): 8 quadros andando); sem ela, a antiga.
	if Menina.folha() != "":
		_andando(Crianca.animacoes(load(Menina.folha())), Vector2.ZERO)
	else:
		_andando(load("res://assets/sprites/personagem/menina_animacoes.tres"), Vector2.ZERO)

	if not final:
		chao.modulate = dados.tom
		turma.modulate = dados.tom
		var escuro := Sprite2D.new()
		escuro.texture = _escuro(RAIO_LUZ + 3.0 * amigas)
		palco.add_child(escuro)


func _andando(quadros: SpriteFrames, pos: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = quadros
	s.position = pos
	turma.add_child(s)
	s.play(&"andando_direita")
	# O passo no ritmo do chão rolando, como o das crianças no jogo (sem passinho apressado).
	s.speed_scale = clampf(VELOCIDADE / Crianca.PASSO_REF, Crianca.PASSO_MIN, Crianca.PASSO_MAX)
	return s


## Escuridão com um buraco suave no meio: o círculo de luz em volta da menina.
func _escuro(raio: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([raio / 128.0, RAIO_ESCURO / 128.0])
	g.colors = PackedColorArray([Color(COR_NOITE, 0.0), COR_NOITE])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256    # em dobro no palco: cobre a tela toda
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _montar_texto() -> void:
	# Faixa escura embaixo: no final o mundo está claro, e o texto precisa de contraste.
	legenda = ColorRect.new()
	legenda.color = Color(COR_NOITE, 0.8)
	legenda.position = Vector2(0, 196)
	legenda.size = Vector2(TELA.x, TELA.y - 196.0)
	add_child(legenda)
	texto = _texto(legenda, "", 12, COR_TEXTO)
	texto.position = Vector2(0, 8)
	texto.size = Vector2(TELA.x, 40)
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dica = _texto(legenda, "", 8, COR_SUAVE)
	dica.position = Vector2(0, 60)
	dica.size.x = TELA.x - 8.0
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


# --- Tela final ----------------------------------------------------------

## O painel abre à direita; a turma vai para a esquerda e continua andando no mundo claro.
func _mostrar_tela_final() -> void:
	relogio = 0.0
	parado = 0.0
	Audio.tocar_musica("vitoria")
	Placar.enviar_pontuacao(Jogo.pontos)
	var bateu := Jogo.registrar_recorde()

	tela_final = CenterContainer.new()
	tela_final.position = Vector2(232, 0)
	tela_final.size = Vector2(TELA.x - 232.0, TELA.y)
	add_child(tela_final)
	var painel := PanelContainer.new()
	tela_final.add_child(painel)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 5)
	painel.add_child(caixa)

	_texto(caixa, "Você encontrou a sua luz!", 16, COR_OURO)
	var numeros := HBoxContainer.new()
	numeros.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_child(numeros)
	_texto(numeros, "Tempo: %s   ·   Pontos: %d   ·" % [Jogo.formatar_tempo(Jogo.tempo_partida), Jogo.pontos],
		10, COR_TEXTO)
	var estrela := TextureRect.new()
	estrela.texture = preload("res://assets/ui/estrela_nativa.png")
	estrela.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	numeros.add_child(estrela)
	_texto(numeros, "%d/%d" % [Jogo.total_estrelas(), 3 * DadosFases.FASES.size()], 10, COR_OURO_CLARO)
	var nivel: int = Jogo.config["dificuldade"]
	_texto(caixa, "Dificuldade: %s" % DadosFases.DIFICULDADES[nivel], 9, COR_SUAVE)
	if bateu:
		_texto(caixa, "Novo recorde!", 12, COR_OURO_CLARO)
	else:
		_texto(caixa, "Recorde: %d" % Jogo.config["recorde"], 9, COR_SUAVE)
	_texto(caixa, "Se você ficar triste, converse com\nalguém em quem você confia.", 9, COR_OURO_CLARO)
	_texto(caixa, "Equipe: João Arthur e Lauan Moreira\nExperimentação de Protótipos · Unifor 2026",
		8, COR_SUAVE)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_child(botoes)
	_botao(botoes, "Jogar de novo", Jogo.novo_jogo).grab_focus()
	_botao(botoes, "Menu principal", Jogo.ir_para_menu)
	get_viewport().gui_focus_changed.connect(_ao_mudar_foco)   # depois do primeiro foco, que não faz som

	tela_final.modulate.a = 0.0
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(tela_final, "modulate:a", 1.0, 0.6)
	t.tween_property(legenda, "modulate:a", 0.0, 0.6)
	t.tween_property(turma, "position", LUGAR_FINAL, 1.2)


func _botao(pai: Node, rotulo: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = rotulo
	b.custom_minimum_size = Vector2(100, 20)
	b.mouse_entered.connect(b.grab_focus)   # mouse e teclado destacam o mesmo botão
	b.pressed.connect(_apertar.bind(acao))
	pai.add_child(b)
	return b


func _apertar(acao: Callable) -> void:
	if saindo:
		return
	Audio.tocar_sfx("clique")
	_sair_para(acao)


func _sair_para(acao: Callable) -> void:
	saindo = true
	acao.call()


func _ao_mudar_foco(_controle: Control) -> void:
	Audio.tocar_sfx("foco")


func _texto(pai: Node, conteudo: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = conteudo
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pai.add_child(l)
	return l
