extends Control
## Menu principal (mockup do time): título, botões Start, Config, Controles e
## Sair, e um fundo vivo: névoa andando, a menina com a luz pulsando e frases
## boas subindo devagar. Config e Controles abrem como painéis no meio da tela.
## No Config também se escolhe a dificuldade (Jogo.config["dificuldade"]).
## Tudo é montado aqui; a cena cenas/menu.tscn só tem a raiz.

const COR_OURO := Color(1.0, 0.827, 0.42)          # #ffd36b
const COR_OURO_CLARO := Color(1.0, 0.878, 0.541)   # #ffe08a
const COR_RUIM := Color(0.62, 0.502, 0.678)        # #9e80ad
const COR_TEXTO := Color(0.925, 0.902, 0.961)
const COR_SUAVE := Color(0.663, 0.612, 0.761)
const POS_MENINA := Vector2(86, 208)
const VAGALUMES := [Vector2(58, 46), Vector2(406, 36), Vector2(34, 136), Vector2(430, 158), Vector2(362, 232), Vector2(150, 252)]
## Embaixo da escolha de dificuldade (mesma ordem de DadosFases.DIFICULDADES).
const FRASES_DIFICULDADE := [
	"Para os pequenos: mais calma e mais luz.",
	"Do jeito que o jogo foi pensado.",
	"Desafio: a névoa fala mais e a luz pode apagar.",
]

var botoes: VBoxContainer
var rodape: Label
var camada_frases: Control
var painel_config: Control
var painel_controles: Control
var primeiro_config: Control
var primeiro_controles: Control
var painel_aberto: Control = null
var botao_que_abriu: Control = null
var check_tela_cheia: CheckBox
var check_piscar: CheckBox
var opcoes_dificuldade: Array[Button] = []   # Fácil, Normal e Difícil, no Config
var frase_dificuldade: Label                 # explica a escolha, embaixo das opções
var rotulo_dificuldade: Label                # "Dificuldade: Normal", embaixo dos botões
var saindo := false    # já apertou Start ou Sair: ignora outros cliques
var sem_som := false   # foco mudado pelo código não toca "foco"
var lado := 0          # lado da próxima frase que sobe (0 esquerda, 1 direita)


func _ready() -> void:
	Audio.tocar_musica("menu")
	_montar_fundo()
	camada_frases = Control.new()
	camada_frases.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(camada_frases)
	_montar_titulo()

	botoes = VBoxContainer.new()
	botoes.position = Vector2(184, 116)
	botoes.add_theme_constant_override("separation", 6)
	add_child(botoes)
	_montar_config()
	_montar_controles()
	_botao(botoes, "Start", _comecar)
	_botao(botoes, "Config", _abrir.bind(painel_config, primeiro_config))
	_botao(botoes, "Controles", _abrir.bind(painel_controles, primeiro_controles))
	_botao(botoes, "Sair", _sair)
	if Jogo.config["recorde"] > 0:
		_texto(botoes, "Recorde: %d" % Jogo.config["recorde"], 9, COR_OURO_CLARO, Vector2.ZERO, 0.0,
			HORIZONTAL_ALIGNMENT_CENTER)
	rotulo_dificuldade = _texto(botoes, "", 8, COR_SUAVE, Vector2.ZERO, 0.0, HORIZONTAL_ALIGNMENT_CENTER)
	_mostrar_dificuldade()

	rodape = _texto(self, "", 8, COR_SUAVE, Vector2(0, 256), 472.0, HORIZONTAL_ALIGNMENT_RIGHT)

	get_viewport().gui_focus_changed.connect(_ao_mudar_foco)
	Jogo.config_mudou.connect(_ler_config)
	_focar(botoes.get_child(0) as Control)

	var relogio := Timer.new()
	relogio.wait_time = 2.4
	relogio.autostart = true
	relogio.timeout.connect(_soltar_frase)
	add_child(relogio)
	_soltar_frase()


func _process(_delta: float) -> void:
	# O rodapé mostra os botões do aparelho em uso (teclado ou controle).
	rodape.text = "Andar: %s · Brilhar: %s · Procurar: %s · Pausar: %s" % [
		"joystick" if Jogo.usando_controle() else "WASD ou setas",
		Jogo.nome_botao("brilhar"), Jogo.nome_botao("procurar"), Jogo.nome_botao("pausar")]


func _unhandled_input(event: InputEvent) -> void:
	# Esc fecha o painel aberto.
	if painel_aberto and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.tocar_sfx("clique")
		_fechar()


# --- Fundo ---------------------------------------------------------------

func _montar_fundo() -> void:
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_fundo := ShaderMaterial.new()
	material_fundo.shader = preload("res://shaders/ui_fundo_menu.gdshader")
	material_fundo.set_shader_parameter("nevoa", preload("res://assets/texturas/nevoa/nevoa_v2_tile_nativa.png"))
	material_fundo.set_shader_parameter("centro_luz", POS_MENINA)
	fundo.material = material_fundo
	add_child(fundo)

	# A luz da menina: um brilho quente que pulsa devagar.
	var aditivo := CanvasItemMaterial.new()
	aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var brilho := Sprite2D.new()
	brilho.texture = _gradiente(120, Color(1.0, 0.83, 0.42, 0.42))
	brilho.position = POS_MENINA + Vector2(0, 2)
	brilho.material = aditivo
	add_child(brilho)
	_pulsar(brilho, 0.55, 1.4)

	var menina := AnimatedSprite2D.new()
	# A mesma folha da fase (Menina.folha(): 4 quadros parada, 8 andando); sem ela, a antiga.
	if Menina.folha() != "":
		menina.sprite_frames = Crianca.animacoes(load(Menina.folha()))
	else:
		menina.sprite_frames = load("res://assets/sprites/personagem/menina_animacoes.tres")
	menina.scale = Vector2(2, 2)
	menina.position = POS_MENINA
	add_child(menina)
	menina.play(&"parada_baixo")

	# Vagalumes do mockup: pontinhos dourados piscando devagar.
	for p: Vector2 in VAGALUMES:
		var vagalume := Sprite2D.new()
		vagalume.texture = _gradiente(10, Color(1.0, 0.9, 0.6, 1.0))
		vagalume.position = p
		vagalume.material = aditivo
		add_child(vagalume)
		_pulsar(vagalume, 0.15, randf_range(0.8, 1.6))


func _montar_titulo() -> void:
	# Brilho suave: duas cópias do título só com o contorno dourado transparente.
	var brilho := Control.new()
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brilho)
	_contorno(_texto(brilho, "Minha Luz", 32, Color(0, 0, 0, 0), Vector2(0, 24), 480.0,
		HORIZONTAL_ALIGNMENT_CENTER), 12, Color(1.0, 0.8, 0.4, 0.1))
	_contorno(_texto(brilho, "Minha Luz", 32, Color(0, 0, 0, 0), Vector2(0, 24), 480.0,
		HORIZONTAL_ALIGNMENT_CENTER), 7, Color(1.0, 0.8, 0.4, 0.2))
	_pulsar(brilho, 0.6, 1.8)
	_contorno(_texto(self, "Minha Luz", 32, COR_OURO_CLARO, Vector2(0, 24), 480.0,
		HORIZONTAL_ALIGNMENT_CENTER), 4, Color(0.16, 0.09, 0.02))
	_texto(self, "Ajude uma pequena luz a atravessar a escuridão", 10, Color(0.8, 0.75, 0.9),
		Vector2(0, 72), 480.0, HORIZONTAL_ALIGNMENT_CENTER)


## Uma frase boa do banco surge num dos lados, sobe devagar e some.
func _soltar_frase() -> void:
	if camada_frases.get_child_count() >= 4:
		return
	var texto: String = DadosFases.PARES.pick_random()[1]   # a frase boa do par
	var largura := ThemeDB.fallback_font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	lado = 1 - lado
	var pos: Vector2
	if lado == 0:   # esquerda, acima da menina
		pos = Vector2(randf_range(8.0, maxf(8.0, 176.0 - largura)), randf_range(125.0, 160.0))
	else:
		pos = Vector2(randf_range(304.0, maxf(304.0, 472.0 - largura)), randf_range(130.0, 236.0))
	var frase := _texto(camada_frases, texto, 8, COR_OURO_CLARO, pos.round())
	frase.modulate.a = 0.0
	var t := frase.create_tween()
	t.tween_property(frase, "position:y", pos.y - 30.0, 8.0)
	t.parallel().tween_property(frase, "modulate:a", 0.8, 2.0)
	t.parallel().tween_property(frase, "modulate:a", 0.0, 2.5).set_delay(5.5)
	t.tween_callback(frase.queue_free)


# --- Painéis -------------------------------------------------------------

## Volumes e dificuldade numa grade, a frase da dificuldade, as duas opções lado a
## lado e Voltar. Mais alto que o painel de Controles: começa logo abaixo do subtítulo.
func _montar_config() -> void:
	var caixa := _painel("Config")
	caixa.add_theme_constant_override("separation", 4)
	painel_config = caixa.get_parent().get_parent()
	painel_config.position.y = 86.0
	painel_config.size.y = 170.0
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 6)
	caixa.add_child(grade)
	primeiro_config = _slider(grade, "Música", "volume_musica")
	_slider(grade, "Efeitos", "volume_efeitos")
	_montar_dificuldade(grade)
	frase_dificuldade = _texto(caixa, "", 9, COR_OURO_CLARO, Vector2.ZERO, 0.0, HORIZONTAL_ALIGNMENT_CENTER)
	var opcoes := HBoxContainer.new()
	opcoes.add_theme_constant_override("separation", 6)
	caixa.add_child(opcoes)
	check_tela_cheia = _check(opcoes, "Tela cheia", "tela_cheia")
	check_piscar = _check(opcoes, "Piscar a tela ao perder luz", "piscar_tela")
	_botao(caixa, "Voltar", _fechar, 80).size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## Dificuldade: as três opções numa linha, a escolhida acesa. Só ela pega o foco:
## teclado e controle chegam nela com cima e baixo, e as setas (ou o direcional)
## trocam a escolha, como nos volumes. Com o mouse, é só clicar na opção.
func _montar_dificuldade(grade: GridContainer) -> void:
	var nome := _texto(grade, "Dificuldade", 10, COR_TEXTO, Vector2.ZERO)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 3)
	grade.add_child(linha)
	for i in DadosFases.DIFICULDADES.size():
		var b := Button.new()
		b.text = DadosFases.DIFICULDADES[i]
		b.toggle_mode = true   # a escolhida fica com o visual de apertada
		b.pressed.connect(_escolher_dificuldade.bind(i))
		b.gui_input.connect(_setas_dificuldade.bind(b))
		# O nome fica dourado enquanto a escolha tem o foco.
		b.focus_entered.connect(nome.add_theme_color_override.bind("font_color", COR_OURO))
		b.focus_exited.connect(nome.add_theme_color_override.bind("font_color", COR_TEXTO))
		linha.add_child(b)
		opcoes_dificuldade.append(b)


func _montar_controles() -> void:
	var caixa := _painel("Controles")
	caixa.add_theme_constant_override("separation", 3)
	painel_controles = caixa.get_parent().get_parent()
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 0)
	grade.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caixa.add_child(grade)
	for par: Array in [["Andar", "WASD, setas ou joystick"], ["Brilhar", "Espaço ou A"],
			["Procurar", "Shift, Q ou B"], ["Pausar", "Esc ou Start"]]:
		_texto(grade, par[0], 9, COR_OURO, Vector2.ZERO)
		_texto(grade, par[1], 9, COR_TEXTO, Vector2.ZERO)
	_texto(caixa, "Siga os vaga-lumes até as frases boas.", 9, COR_OURO_CLARO, Vector2.ZERO, 0.0,
		HORIZONTAL_ALIGNMENT_CENTER)
	_texto(caixa, "Palavras ruins apagam um pouco da sua luz.", 9, COR_RUIM, Vector2.ZERO, 0.0,
		HORIZONTAL_ALIGNMENT_CENTER)
	_texto(caixa, "Com 6 vaga-lumes, Brilhar afasta as palavras ruins.", 9, COR_TEXTO,
		Vector2.ZERO, 0.0, HORIZONTAL_ALIGNMENT_CENTER)
	primeiro_controles = _botao(caixa, "Voltar", _fechar, 80)
	primeiro_controles.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## Painel no meio da tela (abaixo do título), escondido até abrir.
## Devolve a caixa onde vai o conteúdo.
func _painel(titulo: String) -> VBoxContainer:
	var centro := CenterContainer.new()
	centro.position = Vector2(0, 94)
	centro.size = Vector2(480, 160)
	centro.hide()
	add_child(centro)
	var painel := PanelContainer.new()
	centro.add_child(painel)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	painel.add_child(caixa)
	_texto(caixa, titulo, 12, COR_OURO, Vector2.ZERO, 0.0, HORIZONTAL_ALIGNMENT_CENTER)
	return caixa


func _slider(grade: GridContainer, rotulo: String, chave: String) -> HSlider:
	var nome := _texto(grade, rotulo, 10, COR_TEXTO, Vector2.ZERO)
	var s := HSlider.new()
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Jogo.config.get(chave, 1.0))
	s.custom_minimum_size = Vector2(120, 12)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(_mudar_volume.bind(chave))
	s.mouse_entered.connect(s.grab_focus)
	# O nome fica dourado enquanto o slider tem o foco.
	s.focus_entered.connect(nome.add_theme_color_override.bind("font_color", COR_OURO))
	s.focus_exited.connect(nome.add_theme_color_override.bind("font_color", COR_TEXTO))
	grade.add_child(s)
	return s


func _check(pai: Node, texto: String, chave: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = texto
	c.button_pressed = bool(Jogo.config.get(chave, false))
	c.toggled.connect(_mudar_opcao.bind(chave))
	c.mouse_entered.connect(c.grab_focus)
	pai.add_child(c)
	return c


func _mudar_volume(valor: float, chave: String) -> void:
	Jogo.config[chave] = valor
	Jogo.salvar_config()
	if chave == "volume_efeitos":
		Audio.tocar_sfx("foco")   # para ouvir o volume novo


func _mudar_opcao(ligado: bool, chave: String) -> void:
	Audio.tocar_sfx("clique")
	Jogo.config[chave] = ligado
	Jogo.salvar_config()


## Vale a partir da próxima fase que começar.
func _escolher_dificuldade(nivel: int) -> void:
	Audio.tocar_sfx("clique")
	Jogo.config["dificuldade"] = nivel
	Jogo.salvar_config()
	_mostrar_dificuldade()
	_focar(opcoes_dificuldade[nivel])


## Com o foco na dificuldade, esquerda e direita trocam a escolha (e não o foco).
## Uma vez por aperto: tecla segurada e joystick inclinado não passam direto. Só vale
## o evento que apertou: o joystick manda vários valores do eixo, às vezes no mesmo quadro.
func _setas_dificuldade(event: InputEvent, opcao: Button) -> void:
	if not (event.is_action("ui_left") or event.is_action("ui_right")):
		return
	opcao.accept_event()
	var passo := 0
	if event.is_action_pressed("ui_left") and Input.is_action_just_pressed_by_event("ui_left", event):
		passo = -1
	elif event.is_action_pressed("ui_right") and Input.is_action_just_pressed_by_event("ui_right", event):
		passo = 1
	var nivel: int = Jogo.config["dificuldade"] + passo
	if passo != 0 and nivel >= 0 and nivel < opcoes_dificuldade.size():
		_escolher_dificuldade(nivel)


## A dificuldade de Jogo.config na tela: a opção acesa no Config (só ela pega o
## foco), a frase embaixo dela e o "Dificuldade: ..." embaixo dos botões.
func _mostrar_dificuldade() -> void:
	var nivel: int = Jogo.config["dificuldade"]
	for i in opcoes_dificuldade.size():
		opcoes_dificuldade[i].set_pressed_no_signal(i == nivel)
		opcoes_dificuldade[i].focus_mode = Control.FOCUS_ALL if i == nivel else Control.FOCUS_NONE
	# Para cima, das opções de baixo, o foco vai para a escolhida (pela geometria, de
	# "Tela cheia" com o Difícil escolhido, ele pularia para o volume dos efeitos).
	if check_tela_cheia and not opcoes_dificuldade.is_empty():
		for check: CheckBox in [check_tela_cheia, check_piscar]:
			check.focus_neighbor_top = check.get_path_to(opcoes_dificuldade[nivel])
	frase_dificuldade.text = FRASES_DIFICULDADE[nivel]
	rotulo_dificuldade.text = "Dificuldade: %s" % DadosFases.DIFICULDADES[nivel]


func _ler_config() -> void:
	check_tela_cheia.set_pressed_no_signal(bool(Jogo.config.get("tela_cheia", false)))
	check_piscar.set_pressed_no_signal(bool(Jogo.config.get("piscar_tela", true)))


func _abrir(painel: Control, primeiro: Control) -> void:
	botao_que_abriu = get_viewport().gui_get_focus_owner()
	botoes.hide()
	painel.show()
	painel_aberto = painel
	_focar(primeiro)


func _fechar() -> void:
	painel_aberto.hide()
	painel_aberto = null
	botoes.show()
	_focar(botao_que_abriu if is_instance_valid(botao_que_abriu) and botao_que_abriu.is_visible_in_tree()
		else botoes.get_child(0) as Control)


# --- Botões --------------------------------------------------------------

func _comecar() -> void:
	saindo = true
	Jogo.novo_jogo()


func _sair() -> void:
	saindo = true
	Jogo.sair_do_jogo()


func _botao(pai: Node, texto: String, acao: Callable, largura := 112) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(largura, 20)
	b.mouse_entered.connect(b.grab_focus)   # mouse e teclado destacam o mesmo botão
	b.pressed.connect(_apertar.bind(acao))
	pai.add_child(b)
	return b


func _apertar(acao: Callable) -> void:
	if saindo:
		return
	Audio.tocar_sfx("clique")
	acao.call()


func _focar(controle: Control) -> void:
	sem_som = true
	controle.grab_focus()
	sem_som = false


func _ao_mudar_foco(_controle: Control) -> void:
	if not sem_som:
		Audio.tocar_sfx("foco")


# --- Ajudantes -----------------------------------------------------------

func _texto(pai: Node, texto: String, tamanho: int, cor: Color, pos: Vector2,
		largura := 0.0, alinhamento := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.horizontal_alignment = alinhamento
	l.position = pos
	if largura > 0.0:
		l.size.x = largura
	pai.add_child(l)
	return l


func _contorno(l: Label, tamanho: int, cor: Color) -> void:
	l.add_theme_constant_override("outline_size", tamanho)
	l.add_theme_color_override("font_outline_color", cor)


## Círculo de luz: dourado no meio, transparente na borda.
func _gradiente(tamanho: int, cor: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, cor)
	g.set_color(1, Color(cor, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = tamanho
	t.height = tamanho
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _pulsar(no: CanvasItem, alfa_min: float, duracao: float) -> void:
	var t := no.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(no, "modulate:a", alfa_min, duracao)
	t.tween_property(no, "modulate:a", 1.0, duracao)
