class_name Hud
extends CanvasLayer
## HUD da fase: luz, frases boas pegas, tempo, cartão de título, frase boa no
## centro, dicas, pálpebras (Ideias/03_piscada.md), pausa e telas de fim.
## A fase instancia cenas/hud.tscn como filho "HUD" e chama os métodos públicos.
## Tudo é montado aqui; a cena só tem a raiz (process_mode ALWAYS, para a pausa).

const LARGURA := 480.0
const ALTURA := 270.0
const COR_OURO := Color(1.0, 0.827, 0.42)          # #ffd36b
const COR_OURO_CLARO := Color(1.0, 0.878, 0.541)   # #ffe08a
const COR_TEXTO := Color(0.925, 0.902, 0.961)
const COR_SUAVE := Color(0.663, 0.612, 0.761)
const COR_NOITE := Color(0.043, 0.039, 0.078)      # #0b0a14
const LARGURA_BARRA := 60
const FECHAR := 0.2    # cada piscada: fecha 0,2 s, fica fechada 0,1 s e abre 0,2 s
const FECHADO := 0.1
const ABRIR := 0.2

var palpebra_cima: ColorRect
var palpebra_baixo: ColorRect
var luz: Control
var barra: ColorRect
var estrela: TextureRect
var contador: Label
var tempo: Label
var cartao: Control
var cartao_titulo: Label
var cartao_sub: Label
var frase: Control
var frase_textos: Array[Label] = []
var dica: Label
var pausa: ColorRect
var primeiro_pausa: Button
var tela_fim: ColorRect = null
var pulso: Tween
var anim_piscada: Tween
var anim_cartao: Tween
var anim_frase: Tween
var anim_dica: Tween
var saindo := false    # um botão já trocou de cena: ignora outros cliques e a pausa
var sem_som := false   # foco mudado pelo código não toca "foco"


func _ready() -> void:
	# As pálpebras ficam por baixo do resto do HUD: a luz continua visível.
	palpebra_cima = _retangulo(self, Color.BLACK, Vector2.ZERO, Vector2(LARGURA, 0))
	palpebra_baixo = _retangulo(self, Color.BLACK, Vector2(0, ALTURA), Vector2(LARGURA, 0))
	_montar_luz()
	_montar_contador()
	tempo = _texto(self, "00:00", 8, COR_SUAVE, Vector2(0, 3), LARGURA, HORIZONTAL_ALIGNMENT_CENTER)
	_montar_cartao()
	_montar_frase()
	_montar_dica()
	_montar_pausa()
	get_viewport().gui_focus_changed.connect(_ao_mudar_foco)


func _process(_delta: float) -> void:
	tempo.text = Jogo.formatar_tempo(Jogo.tempo_partida)


## Tecla segurada desde o jogo (repetição) não troca o botão da tela de fim; um toque novo troca.
func _input(event: InputEvent) -> void:
	if tela_fim != null and event.is_echo():
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pausar") or tela_fim != null or saindo:
		return
	get_viewport().set_input_as_handled()
	Audio.tocar_sfx("clique")
	if pausa.visible:
		_fechar_pausa()
	else:
		get_tree().paused = true
		pausa.show()
		_focar(primeiro_pausa)


# --- API usada pela fase -------------------------------------------------

## Cartão "Fase 1 · O Campo" + subtítulo por ~3 s, e zera o contador.
func configurar(numero: int, nome: String, subtitulo: String, total_boas: int) -> void:
	cartao_titulo.text = "Fase %d · %s" % [numero, nome]
	cartao_sub.text = subtitulo
	atualizar_contador(0, total_boas)
	if anim_cartao:
		anim_cartao.kill()
	cartao.modulate.a = 0.0
	anim_cartao = create_tween()
	anim_cartao.tween_property(cartao, "modulate:a", 1.0, 0.5)
	anim_cartao.tween_interval(2.0)
	anim_cartao.tween_property(cartao, "modulate:a", 0.0, 0.6)


func atualizar_luz(valor: float, maximo: float, baixa_ate: float) -> void:
	var fracao := clampf(valor / maximo, 0.0, 1.0) if maximo > 0.0 else 0.0
	barra.size.x = roundf(LARGURA_BARRA * fracao)
	var baixa := valor <= baixa_ate
	if baixa and pulso == null:
		pulso = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		pulso.tween_property(luz, "modulate:a", 0.35, 0.6)
		pulso.tween_property(luz, "modulate:a", 1.0, 0.6)
	elif not baixa and pulso != null:
		pulso.kill()
		pulso = null
		luz.modulate.a = 1.0


func atualizar_contador(pegas: int, total: int) -> void:
	var texto := "%d/%d" % [pegas, total]
	if pegas > 0 and texto != contador.text:
		# Brilha um instante quando pega mais uma.
		contador.modulate = Color(1.8, 1.8, 1.8)
		estrela.modulate = Color(1.8, 1.8, 1.8)
		var t := create_tween().set_parallel()
		t.tween_property(contador, "modulate", Color.WHITE, 0.5)
		t.tween_property(estrela, "modulate", Color.WHITE, 0.5)
	contador.text = texto
	var largura := ThemeDB.fallback_font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	estrela.position.x = roundf(LARGURA - 6.0 - largura - 3.0 - 9.0)


## Frase boa grande, dourada e brilhando, por 2 s.
func mostrar_frase(texto: String) -> void:
	if anim_cartao:
		anim_cartao.kill()
	cartao.modulate.a = 0.0
	for l in frase_textos:
		l.text = texto
	if anim_frase:
		anim_frase.kill()
	frase.modulate.a = 0.0
	frase.position.y = 6.0
	anim_frase = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	anim_frase.tween_property(frase, "modulate:a", 1.0, 0.25)
	anim_frase.parallel().tween_property(frase, "position:y", 0.0, 0.4)
	anim_frase.tween_interval(1.2)
	anim_frase.tween_property(frase, "modulate:a", 0.0, 0.4)


## Texto pequeno embaixo. Pode ser chamada todo quadro: só mantém visível.
func mostrar_dica(texto: String, segundos := 3.0) -> void:
	if dica.text != texto:
		dica.text = texto
		dica.reset_size()
		dica.position = Vector2(roundf((LARGURA - dica.size.x) / 2.0), ALTURA - 10.0 - dica.size.y)
	if anim_dica:
		anim_dica.kill()
	anim_dica = create_tween()
	anim_dica.tween_property(dica, "modulate:a", 1.0, 0.25)
	anim_dica.tween_interval(maxf(segundos - 0.5, 0.1))
	anim_dica.tween_property(dica, "modulate:a", 0.0, 0.25)


## Pálpebras pretas fechando e abrindo (nunca clarão). 0,5 s cada: no máx. 2 por segundo.
func piscar(vezes: int) -> void:
	if not Jogo.config.get("piscar_tela", true) or vezes <= 0:
		return
	if anim_piscada:
		anim_piscada.kill()
	anim_piscada = create_tween().set_trans(Tween.TRANS_SINE)
	for _i in vezes:
		_palpebras(ALTURA / 2.0, FECHAR)
		anim_piscada.tween_interval(FECHADO)
		_palpebras(0.0, ABRIR)


func mostrar_game_over() -> void:
	var caixa := _abrir_tela_fim(Color(0.02, 0.018, 0.04, 0.9))
	_rotulo(caixa, "Você sempre pode recomeçar\ne tentar novamente.", 12, COR_TEXTO)
	var primeiro := _botao(caixa, "Tentar novamente", _sair_para.bind(Jogo.reiniciar_fase))
	_botao(caixa, "Menu principal", _sair_para.bind(Jogo.ir_para_menu))
	_focar(primeiro)


func mostrar_fase_concluida(numero: int, pontos_fase: int) -> void:
	var caixa := _abrir_tela_fim(Color(COR_NOITE, 0.55))
	_rotulo(caixa, "Fase %d concluída!" % numero, 16, COR_OURO)
	_rotulo(caixa, "Pontos da fase: %d" % pontos_fase, 10, COR_TEXTO)
	_focar(_botao(caixa, "Continuar", _sair_para.bind(Jogo.proxima_fase)))


func mostrar_final(pontos: int, tempo_total: float) -> void:
	var caixa := _abrir_tela_fim(Color(COR_NOITE, 0.72))
	_rotulo(caixa, "Você encontrou a sua luz!", 16, COR_OURO)
	_rotulo(caixa, "Tempo: %s   ·   Pontos: %d" % [Jogo.formatar_tempo(tempo_total), pontos], 10, COR_TEXTO)
	_rotulo(caixa, "Se você ficar triste, converse com\nalguém em quem você confia.", 9, COR_OURO_CLARO)
	_rotulo(caixa, "Equipe: João Arthur, Lauan Moreira e Enzo\nExperimentação de Protótipos · Unifor 2026",
		8, COR_SUAVE)
	var primeiro := _botao(caixa, "Jogar de novo", _sair_para.bind(Jogo.novo_jogo))
	_botao(caixa, "Menu principal", _sair_para.bind(Jogo.ir_para_menu))
	_focar(primeiro)


# --- Montagem ------------------------------------------------------------

func _montar_luz() -> void:
	luz = Control.new()
	luz.position = Vector2(6, 5)
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(luz)
	var icone := TextureRect.new()
	icone.texture = _icone("res://assets/ui/luz_nativa.png")
	luz.add_child(icone)
	_retangulo(luz, Color(0, 0, 0, 0.7), Vector2(11, 1), Vector2(LARGURA_BARRA + 2, 7))
	_retangulo(luz, Color(0.22, 0.16, 0.07), Vector2(12, 2), Vector2(LARGURA_BARRA, 5))
	barra = _retangulo(luz, COR_OURO, Vector2(12, 2), Vector2(LARGURA_BARRA, 5))
	var reflexo := _retangulo(barra, Color(1.0, 0.95, 0.75), Vector2.ZERO, Vector2(0, 1))
	reflexo.anchor_right = 1.0   # acompanha a largura da barra


func _montar_contador() -> void:
	estrela = TextureRect.new()
	estrela.texture = _icone("res://assets/ui/estrela_nativa.png")
	estrela.position = Vector2(LARGURA - 30.0, 5)
	add_child(estrela)
	contador = _texto(self, "0/0", 10, COR_OURO_CLARO, Vector2(0, 2), LARGURA - 6.0,
		HORIZONTAL_ALIGNMENT_RIGHT)


func _montar_cartao() -> void:
	cartao = Control.new()
	cartao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.modulate.a = 0.0
	add_child(cartao)
	cartao_titulo = _texto(cartao, "", 16, COR_OURO, Vector2(0, 40), LARGURA, HORIZONTAL_ALIGNMENT_CENTER)
	cartao_titulo.add_theme_constant_override("outline_size", 4)
	cartao_sub = _texto(cartao, "", 9, COR_TEXTO, Vector2(0, 62), LARGURA, HORIZONTAL_ALIGNMENT_CENTER)


func _montar_frase() -> void:
	frase = Control.new()
	frase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frase.modulate.a = 0.0
	add_child(frase)
	# Brilho: duas cópias só com o contorno dourado transparente, atrás do texto.
	for contorno: int in [10, 6]:
		var b := _texto(frase, "", 14, Color(0, 0, 0, 0), Vector2(0, 88), LARGURA, HORIZONTAL_ALIGNMENT_CENTER)
		b.add_theme_constant_override("outline_size", contorno)
		b.add_theme_color_override("font_outline_color", Color(1.0, 0.8, 0.4, 0.12))
		frase_textos.append(b)
	var l := _texto(frase, "", 14, COR_OURO_CLARO, Vector2(0, 88), LARGURA, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.02))
	frase_textos.append(l)


func _montar_dica() -> void:
	dica = _texto(self, "", 9, COR_TEXTO, Vector2.ZERO)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(COR_NOITE, 0.8)
	fundo.set_corner_radius_all(3)
	fundo.anti_aliasing = false
	fundo.content_margin_left = 6
	fundo.content_margin_right = 6
	fundo.content_margin_top = 2
	fundo.content_margin_bottom = 2
	dica.add_theme_stylebox_override("normal", fundo)
	dica.modulate.a = 0.0


func _montar_pausa() -> void:
	pausa = _janela(Color(COR_NOITE, 0.6))
	var caixa: VBoxContainer = pausa.get_node("Centro/Painel/Caixa")
	_rotulo(caixa, "Pausa", 14, COR_OURO)
	primeiro_pausa = _botao(caixa, "Continuar", _fechar_pausa)
	_botao(caixa, "Menu principal", _sair_para.bind(Jogo.ir_para_menu))
	_botao(caixa, "Sair do jogo", _sair_para.bind(Jogo.sair_do_jogo))
	pausa.hide()


func _fechar_pausa() -> void:
	pausa.hide()
	get_tree().paused = false


## Tela de fim por cima de tudo, aparecendo devagar. O mundo continua rodando.
func _abrir_tela_fim(cor: Color) -> VBoxContainer:
	if pausa.visible:
		_fechar_pausa()
	if tela_fim:
		tela_fim.queue_free()
	tela_fim = _janela(cor)
	tela_fim.modulate.a = 0.0
	create_tween().tween_property(tela_fim, "modulate:a", 1.0, 0.6)
	return tela_fim.get_node("Centro/Painel/Caixa") as VBoxContainer


## Fundo escuro na tela toda com um painel no meio (em "Centro/Painel/Caixa").
func _janela(cor: Color) -> ColorRect:
	var fundo := ColorRect.new()
	fundo.color = cor
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var painel := PanelContainer.new()
	painel.name = "Painel"
	centro.add_child(painel)
	var caixa := VBoxContainer.new()
	caixa.name = "Caixa"
	caixa.add_theme_constant_override("separation", 6)
	painel.add_child(caixa)
	return fundo


func _palpebras(altura: float, duracao: float) -> void:
	anim_piscada.tween_property(palpebra_cima, "size:y", altura, duracao)
	anim_piscada.parallel().tween_property(palpebra_baixo, "size:y", altura, duracao)
	anim_piscada.parallel().tween_property(palpebra_baixo, "position:y", ALTURA - altura, duracao)


# --- Botões --------------------------------------------------------------

func _botao(caixa: Control, texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(130, 20)
	b.mouse_entered.connect(b.grab_focus)   # mouse e teclado destacam o mesmo botão
	b.pressed.connect(_apertar.bind(acao))
	caixa.add_child(b)
	return b


func _apertar(acao: Callable) -> void:
	if saindo:
		return
	Audio.tocar_sfx("clique")
	acao.call()


func _sair_para(acao: Callable) -> void:
	saindo = true
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


func _rotulo(caixa: Control, texto: String, tamanho: int, cor: Color) -> Label:
	return _texto(caixa, texto, tamanho, cor, Vector2.ZERO, 0.0, HORIZONTAL_ALIGNMENT_CENTER)


func _retangulo(pai: Node, cor: Color, pos: Vector2, tamanho: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = cor
	r.position = pos
	r.size = tamanho
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)
	return r


## Ícone da arte; se ainda não existir, um círculo dourado desenhado aqui.
func _icone(caminho: String) -> Texture2D:
	if ResourceLoader.exists(caminho):
		return load(caminho) as Texture2D
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.95])
	g.colors = PackedColorArray([COR_OURO_CLARO, COR_OURO, Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 9
	t.height = 9
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
