class_name Hud
extends CanvasLayer
## HUD da fase. No topo: luz e vaga-lumes (esquerda), pontos e respostas do final
## (meio), frases boas em estrelinhas e amigas em corações (direita). Também:
## cartão de título, frase boa no centro, dicas, pálpebras (Ideias/03_piscada.md),
## seta do Procurar, ícone do botão sobre a menina, o "Respirar", a pausa, o
## painel de fase concluída e a tela de recomeçar (luz apagada, no Difícil).
## A fase instancia cenas/hud.tscn como filho "HUD" e chama os métodos públicos.
## Tudo é montado aqui; a cena só tem a raiz (process_mode ALWAYS, para a pausa).

const LARGURA := 480.0
const ALTURA := 270.0
const COR_OURO := Color(1.0, 0.827, 0.42)          # #ffd36b
const COR_OURO_CLARO := Color(1.0, 0.878, 0.541)   # #ffe08a
const COR_TEXTO := Color(0.925, 0.902, 0.961)
const COR_SUAVE := Color(0.663, 0.612, 0.761)
const COR_NOITE := Color(0.043, 0.039, 0.078)      # #0b0a14
const COR_CONTORNO := Color(0.16, 0.09, 0.02)      # marrom escuro em volta do dourado
const COR_VAZIO_ESCURO := Color(0.12, 0.1, 0.18)   # ícone ainda não ganho: lilás apagado
const COR_VAZIO_CLARO := Color(0.49, 0.44, 0.64)
const ICONE := "res://assets/ui/%s_nativa.png"
const LARGURA_BARRA := 60
const FECHAR := 0.2    # cada piscada: fecha 0,2 s, fica fechada 0,1 s e abre 0,2 s
const FECHADO := 0.1
const ABRIR := 0.2
const ACIMA_DO_ALVO := 17.0      # o ícone do botão quica acima da cabeça e da carga do Brilho...
const PULO_BOTAO := 4.0          # ...subindo até este tanto a cada pulinho
const RESPIRACOES := 3           # no "Respirar", o anel abre e fecha 3 vezes...
const TEMPO_RESPIRACAO := 2.0    # ...em 2 s cada (1 s abrindo, 1 s fechando)
const ANEL_FECHADO := 14.0
const ANEL_ABERTO := 40.0
const TRAVA_PAUSA := 0.5         # a pausa não aceita "confirmar" neste começo
const TRAVA_FIM := 1.5           # o painel de fase concluída não aceita nada neste começo
const APAGOU := -2               # respirar(APAGOU): acabaram os respiros da fase (Difícil)
const VOLTAR_AO_MENU := 60.0     # pausa ou painel sem nenhum botão: volta ao menu sozinho
const ENTRADA_ESTRELA := 0.4     # as estrelas do painel entram uma a uma
const TONS_ESTRELA := [1.0, 1.12, 1.25]

## O botãozinho de procurar foi clicado com o mouse (a tecla a fase trata sozinha).
signal procurar_pedido
## O "Respirar" acabou: a fase levanta a menina.
signal respirou

var palpebra_cima: ColorRect
var palpebra_baixo: ColorRect
var luz: Control
var barra: ColorRect
var rotulo_vagalumes: Label
var rotulo_pontos: Label
var rotulo_respostas: Label
var fila_estrelas: HBoxContainer
var fila_coracoes: HBoxContainer
var estrela_cheia: Texture2D
var estrela_vazia: Texture2D
var coracao_cheio: Texture2D
var coracao_vazio: Texture2D
var cartao: Control
var cartao_titulo: Label
var cartao_sub: Label
var frase: Control
var frase_textos: Array[Label] = []
var dica: Label
var poder: Button
var botao: Label           # ícone do botão que quica sobre o alvo (mostrar_botao)
var acao_botao := ""
var alvo_botao: Node2D
var tempo_botao := 0.0
var camada_seta: Node2D
var respiro: ColorRect
var anel: Control
var raio_anel := ANEL_FECHADO
var texto_respiro: Label
var respirando := false
var pausa: ColorRect
var primeiro_pausa: Button
var tela_fim: ColorRect = null
var pulso: Tween
var anim_piscada: Tween
var anim_cartao: Tween
var anim_frase: Tween
var anim_dica: Tween
var com_controle := false   # os nomes de botão na tela são os do controle (ou os do teclado)
var trava := 0.0            # segundos em que a pausa ou o painel ainda não aceitam botão
var parado := 0.0           # segundos sem nenhum botão na pausa ou no painel
var saindo := false         # um botão já trocou de cena: ignora outros cliques e a pausa
var sem_som := false        # foco mudado pelo código não toca "foco"


func _ready() -> void:
	# As pálpebras ficam por baixo do resto do HUD: a luz continua visível.
	palpebra_cima = _retangulo(self, Color.BLACK, Vector2.ZERO, Vector2(LARGURA, 0))
	palpebra_baixo = _retangulo(self, Color.BLACK, Vector2(0, ALTURA), Vector2(LARGURA, 0))
	_montar_luz()
	_montar_contadores()
	_montar_cartao()
	_montar_frase()
	_montar_dica()
	_montar_poder()
	_montar_botao()
	# A seta do poder fica por baixo do respirar, da pausa e do painel, e para na pausa.
	camada_seta = Node2D.new()
	camada_seta.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(camada_seta)
	_montar_respirar()
	_montar_pausa()
	_atualizar_nomes()
	get_viewport().gui_focus_changed.connect(_ao_mudar_foco)


func _process(delta: float) -> void:
	trava = maxf(trava - delta, 0.0)
	# Pausa ou painel esquecidos, sem ninguém apertar nada: volta ao menu sozinho.
	if (pausa.visible or tela_fim != null) and not saindo:
		parado += delta
		if parado >= VOLTAR_AO_MENU:
			_sair_para(Jogo.ir_para_menu)
	if com_controle != Jogo.usando_controle():
		_atualizar_nomes()
	# O botãozinho de procurar fica translúcido quando a menina passa por trás dele.
	poder.modulate.a = 0.35 if poder.get_rect().grow(10.0).has_point(_menina_na_tela()) else 1.0
	if botao.visible and not get_tree().paused:
		_quicar_botao(delta)


## Qualquer botão zera a volta ao menu. Na pausa e no painel, tecla segurada desde
## o jogo (repetição) não troca nem aperta botão. No começo (`trava`), o painel de
## fase concluída não aceita nada e a pausa não aceita "confirmar": quem estava
## apertando o botão de brilhar sem parar não confirma sem querer.
func _input(event: InputEvent) -> void:
	if event.is_pressed():
		parado = 0.0
	if tela_fim == null and not pausa.visible:
		return
	var travado := trava > 0.0 and (tela_fim != null or event.is_action("ui_accept"))
	if travado or event.is_echo():
		get_viewport().set_input_as_handled()


## A pausa não abre por cima do painel de fase concluída nem do "Respirar".
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pausar") or tela_fim != null or respirando or saindo:
		return
	get_viewport().set_input_as_handled()
	Audio.tocar_sfx("clique")
	if pausa.visible:
		_fechar_pausa()
	else:
		get_tree().paused = true
		trava = TRAVA_PAUSA
		parado = 0.0
		pausa.show()
		_focar(primeiro_pausa)


# --- API usada pela fase -------------------------------------------------

## Zera os contadores e, se `com_cartao`, mostra "Fase 1 · O Campo" + subtítulo por ~3 s.
func configurar(numero: int, nome: String, subtitulo: String, total_boas: int,
		total_amigas: int, total_vagalumes: int, com_cartao: bool) -> void:
	atualizar_contador(0, total_boas)
	atualizar_amigas(0, total_amigas)
	atualizar_vagalumes(0, total_vagalumes)
	if not com_cartao:
		return
	cartao_titulo.text = "Fase %d · %s" % [numero, nome]
	cartao_sub.text = subtitulo
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


## Frases boas: uma estrelinha para cada, vazia até ser pega. Com todas pegas não
## há mais o que procurar: o botãozinho de procurar some.
func atualizar_contador(pegas: int, total: int) -> void:
	_encher(fila_estrelas, pegas, total, estrela_cheia, estrela_vazia)
	poder.visible = pegas < total


## Amigas (crianças que acenderam): um coração para cada, vazio até acender.
func atualizar_amigas(acesas: int, total: int) -> void:
	_encher(fila_coracoes, acesas, total, coracao_cheio, coracao_vazio)


func atualizar_vagalumes(pegos: int, total: int) -> void:
	rotulo_vagalumes.text = "%d/%d" % [pegos, total]


func atualizar_pontos(pontos: int) -> void:
	rotulo_pontos.text = str(pontos)


## Contador do final da fase, no topo: "Respostas 7/14". Com total 0 (ou menos), some.
func atualizar_final(respondidas: int, total: int) -> void:
	rotulo_respostas.visible = total > 0
	rotulo_respostas.text = "Respostas %d/%d" % [respondidas, total]


## Seta do poder "Procurar" apontando da menina para o alvo (troca a anterior).
## Com `segundos` 0 ou menos, fica até esconder_seta().
func mostrar_seta(menina: Node2D, alvo: Node2D, segundos := 3.0) -> void:
	esconder_seta()
	var seta := SetaCaminho.new()
	seta.menina = menina
	seta.alvo = alvo
	seta.duracao = segundos
	camada_seta.add_child(seta)


func esconder_seta() -> void:
	for seta in camada_seta.get_children():
		seta.queue_free()


## Ícone redondo com o nome do botão da ação ("A", "Espaço"...) quicando sobre o
## alvo, até esconder_botao(). Mostra qual botão apertar sem precisar ler uma frase.
func mostrar_botao(acao: String, alvo: Node2D) -> void:
	acao_botao = acao
	alvo_botao = alvo
	botao.text = Jogo.nome_botao(acao)
	botao.reset_size()
	botao.show()
	_quicar_botao(0.0)


func esconder_botao() -> void:
	botao.hide()


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


## "Respirar", no lugar do game over: a tela escurece até a metade (nunca preto),
## um anel dourado abre e fecha devagar em volta da menina, para a criança
## respirar junto, e depois vem a mensagem de recomeço. Dura uns 8 s e emite
## `respirou` no fim, com a tela já limpa. `restam`: quantas vezes ainda dá para
## respirar nesta fase (a mensagem avisa); -1 = sem limite; APAGOU = acabaram os
## respiros (Difícil): sem mensagem, emite `respirou` com a tela ainda escura, e a
## tela de recomeçar (mostrar_luz_apagou) entra por cima, sem clarear antes.
func respirar(restam := -1) -> void:
	if respirando:
		return
	respirando = true
	anel.position = _menina_na_tela()
	# O texto fica na metade da tela em que a menina (e o anel) não está.
	texto_respiro.position.y = 54.0 if anel.position.y >= ALTURA / 2.0 else 200.0
	texto_respiro.text = "Respira fundo..."
	_abrir_anel(ANEL_FECHADO)
	respiro.modulate.a = 0.0
	respiro.show()
	create_tween().tween_property(respiro, "modulate:a", 1.0, 0.4)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	for _i in RESPIRACOES:
		t.tween_method(_abrir_anel, ANEL_FECHADO, ANEL_ABERTO, TEMPO_RESPIRACAO / 2.0)
		t.tween_method(_abrir_anel, ANEL_ABERTO, ANEL_FECHADO, TEMPO_RESPIRACAO / 2.0)
	if restam == APAGOU:
		t.tween_callback(_fim_do_respirar.bind(false))
		return
	t.tween_callback(texto_respiro.set_text.bind(_pronto(restam)))
	# Com limite (Difícil) a frase diz quantas vezes ainda dá: fica mais tempo para ler.
	t.tween_interval(1.4 if restam < 0 else 3.5)
	t.tween_property(respiro, "modulate:a", 0.0, 0.4)
	t.tween_callback(_fim_do_respirar)


## Acabaram os respiros da fase (Difícil): tela calma, escura mas nunca preta, com
## Tentar de novo (recomeça a fase com os pontos do começo dela) e Menu principal.
## Entrada travada por 1,5 s; 60 s sem botão volta ao menu (como o painel de fase concluída).
func mostrar_luz_apagou() -> void:
	if tela_fim != null:
		return
	esconder_botao()
	tela_fim = _janela(Color(COR_NOITE, 0.85))
	tela_fim.modulate.a = 0.0
	trava = TRAVA_FIM
	parado = 0.0
	var caixa: VBoxContainer = tela_fim.get_node("Centro/Painel/Caixa")
	_rotulo(caixa, "A luz apagou desta vez.\nVocê sempre pode recomeçar.", 12, COR_OURO_CLARO)
	_focar(_botao(caixa, "Tentar de novo", _sair_para.bind(Jogo.reiniciar_fase)))
	_botao(caixa, "Menu principal", _sair_para.bind(Jogo.ir_para_menu))
	create_tween().tween_property(tela_fim, "modulate:a", 1.0, 0.6)
	if respiro.visible:   # veio do Respirar: a escuridão dele sai enquanto esta entra
		var t := create_tween()
		t.tween_property(respiro, "modulate:a", 0.0, 0.6)
		t.tween_callback(respiro.hide)
	if ResourceLoader.exists(Audio.MUSICA % "game_over"):
		Audio.tocar_musica("game_over")


## Painel "Fase N concluída!" com 3 estrelas entrando uma a uma, cada uma com o
## seu motivo embaixo. `estrelas`: 3 bool; `motivos`: 3 textos curtos ("Terminou",
## "24 de 30 vaga-lumes", "12 de 14 respostas"). O mundo continua rodando atrás.
func mostrar_fase_concluida(numero: int, pontos_fase: int, estrelas: Array, motivos: Array,
		ultima: bool) -> void:
	if tela_fim != null:
		return
	esconder_botao()   # agora o único botão é o do painel
	tela_fim = _janela(Color(COR_NOITE, 0.55))
	tela_fim.modulate.a = 0.0
	trava = TRAVA_FIM
	parado = 0.0
	var caixa: VBoxContainer = tela_fim.get_node("Centro/Painel/Caixa")
	_rotulo(caixa, "Fase %d concluída!" % numero, 16, COR_OURO)
	var fila := HBoxContainer.new()
	caixa.add_child(fila)
	var cheia := _icone("estrela_grande", 15)
	var vazia := _icone("estrela_grande_vazia", 15) if ResourceLoader.exists(ICONE % "estrela_grande_vazia") else _vazio(cheia)
	var anim := create_tween()
	anim.tween_property(tela_fim, "modulate:a", 1.0, 0.3)
	for i in 3:
		var ganhou: bool = estrelas[i]
		var coluna := VBoxContainer.new()
		coluna.add_theme_constant_override("separation", 2)
		fila.add_child(coluna)
		# A moldura guarda o lugar na coluna; a estrela (2x) cresce solta dentro dela.
		var moldura := Control.new()
		moldura.custom_minimum_size = Vector2(30, 30)
		moldura.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		coluna.add_child(moldura)
		var estrela := Sprite2D.new()
		estrela.texture = cheia if ganhou else vazia
		estrela.position = Vector2(15, 15)
		estrela.scale = Vector2.ZERO
		moldura.add_child(estrela)
		var motivo := _rotulo(coluna, motivos[i], 8, COR_TEXTO if ganhou else COR_SUAVE)
		motivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		motivo.custom_minimum_size.x = 84
		motivo.modulate.a = 0.0
		# A estrela ganha entra com o som subindo de tom; a não ganha entra apagada, sem som.
		if ganhou:
			anim.tween_callback(Audio.tocar_sfx.bind("estrela", TONS_ESTRELA[i]))
		anim.tween_property(estrela, "scale", Vector2(2, 2), ENTRADA_ESTRELA) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		anim.parallel().tween_property(motivo, "modulate:a", 1.0, ENTRADA_ESTRELA)
	_rotulo(caixa, "Pontos da fase: %d" % pontos_fase, 10, COR_TEXTO)
	if ultima:
		_focar(_botao(caixa, "Continuar", _sair_para.bind(Jogo.terminar_jogo)))
	else:
		_focar(_botao(caixa, "Próxima fase", _sair_para.bind(Jogo.proxima_fase)))


# --- Montagem ------------------------------------------------------------

func _montar_luz() -> void:
	luz = Control.new()
	luz.position = Vector2(6, 5)
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(luz)
	_por_icone(luz, _icone("luz", 9))
	_retangulo(luz, Color(0, 0, 0, 0.7), Vector2(11, 1), Vector2(LARGURA_BARRA + 2, 7))
	_retangulo(luz, Color(0.22, 0.16, 0.07), Vector2(12, 2), Vector2(LARGURA_BARRA, 5))
	barra = _retangulo(luz, COR_OURO, Vector2(12, 2), Vector2(LARGURA_BARRA, 5))
	var reflexo := _retangulo(barra, Color(1.0, 0.95, 0.75), Vector2.ZERO, Vector2(0, 1))
	reflexo.anchor_right = 1.0   # acompanha a largura da barra


## Vaga-lumes embaixo da barra de luz, pontos (e respostas do final) no meio do
## topo, estrelinhas e corações à direita.
func _montar_contadores() -> void:
	var caixa := _fila(Vector2(8, 14), 0.0, BoxContainer.ALIGNMENT_BEGIN)
	_por_icone(caixa, _icone("vagalume", 5))
	rotulo_vagalumes = _texto(caixa, "0/0", 8, COR_OURO_CLARO, Vector2.ZERO)
	caixa = _fila(Vector2(0, 2), LARGURA, BoxContainer.ALIGNMENT_CENTER)
	_por_icone(caixa, _icone("brilho", 9))
	rotulo_pontos = _texto(caixa, "0", 8, COR_TEXTO, Vector2.ZERO)
	rotulo_respostas = _texto(self, "", 10, COR_OURO_CLARO, Vector2(0, 14), LARGURA, HORIZONTAL_ALIGNMENT_CENTER)
	rotulo_respostas.hide()
	estrela_cheia = _icone("estrela", 9)
	estrela_vazia = _vazio(estrela_cheia)
	coracao_cheio = _icone("coracao", 7)
	coracao_vazio = _vazio(coracao_cheio)
	fila_estrelas = _fila(Vector2(0, 5), LARGURA - 6.0, BoxContainer.ALIGNMENT_END)
	fila_coracoes = _fila(Vector2(0, 17), LARGURA - 6.0, BoxContainer.ALIGNMENT_END)


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
	l.add_theme_color_override("font_outline_color", COR_CONTORNO)
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


## Canto de baixo à esquerda: estrelinha + o nome do botão de procurar, clicável
## com o mouse. Sem foco de teclado, para o Espaço e o Enter não apertarem por engano.
func _montar_poder() -> void:
	poder = Button.new()
	poder.icon = _icone("estrela", 9)
	poder.focus_mode = Control.FOCUS_NONE
	poder.add_theme_font_size_override("font_size", 8)
	poder.pressed.connect(procurar_pedido.emit)
	add_child(poder)


## Ícone do botão (mostrar_botao): bolinha dourada com o nome escuro dentro.
func _montar_botao() -> void:
	botao = _texto(self, "", 8, COR_CONTORNO, Vector2.ZERO, 0.0, HORIZONTAL_ALIGNMENT_CENTER)
	botao.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	botao.add_theme_constant_override("outline_size", 1)   # só engrossa a letra
	botao.add_theme_color_override("font_outline_color", COR_CONTORNO)
	botao.custom_minimum_size = Vector2(14, 14)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = COR_OURO
	fundo.border_color = COR_CONTORNO
	fundo.set_border_width_all(1)
	fundo.set_corner_radius_all(7)
	fundo.anti_aliasing = false
	fundo.content_margin_left = 4
	fundo.content_margin_right = 4
	botao.add_theme_stylebox_override("normal", fundo)
	botao.hide()


## O ícone do botão acompanha o alvo na tela, dando 1,5 pulinho por segundo:
## em cima da cabeça ou, com o alvo colado no alto da tela, embaixo dos pés.
## Um aviso de cada vez: some enquanto a seta ou a frase boa grande aparecem.
func _quicar_botao(delta: float) -> void:
	if not is_instance_valid(alvo_botao):
		esconder_botao()
		return
	tempo_botao += delta
	var pulo := absf(sin(tempo_botao * PI * 1.5)) * PULO_BOTAO
	var alvo := alvo_botao.get_global_transform_with_canvas().origin
	var cabe_em_cima := alvo.y - ACIMA_DO_ALVO - PULO_BOTAO - botao.size.y >= 2.0
	var y := alvo.y - ACIMA_DO_ALVO - pulo - botao.size.y if cabe_em_cima else alvo.y + ACIMA_DO_ALVO + pulo
	var x := clampf(alvo.x - botao.size.x / 2.0, 2.0, LARGURA - 2.0 - botao.size.x)
	botao.position = Vector2(x, y).round()
	botao.modulate.a = 0.0 if camada_seta.get_child_count() > 0 else 1.0 - frase.modulate.a


func _montar_respirar() -> void:
	respiro = _retangulo(self, Color(COR_NOITE, 0.5), Vector2.ZERO, Vector2(LARGURA, ALTURA))
	anel = Control.new()
	anel.draw.connect(_desenhar_anel)
	respiro.add_child(anel)
	texto_respiro = _texto(respiro, "", 12, COR_OURO_CLARO, Vector2.ZERO, LARGURA, HORIZONTAL_ALIGNMENT_CENTER)
	respiro.hide()


func _abrir_anel(raio: float) -> void:
	raio_anel = raio
	anel.queue_redraw()


func _desenhar_anel() -> void:
	anel.draw_circle(Vector2.ZERO, raio_anel, Color(COR_OURO, 0.1))
	anel.draw_arc(Vector2.ZERO, raio_anel, 0.0, TAU, 48, COR_OURO_CLARO, 2.0)


## `esconder` false: a tela fica escura (quem chamou põe outra por cima).
func _fim_do_respirar(esconder := true) -> void:
	if esconder:
		respiro.hide()
	respirando = false
	respirou.emit()


## A mensagem do fim do "Respirar". Com limite (Difícil), diz quantas vezes ainda dá.
func _pronto(restam: int) -> String:
	if restam < 0:
		return "Pronto. Você sempre pode recomeçar."
	if restam == 0:
		return "Pronto. Esta foi a última vez nesta fase."
	return "Pronto. Dá para respirar mais %d %s nesta fase." % [restam, "vez" if restam == 1 else "vezes"]


func _montar_pausa() -> void:
	pausa = _janela(Color(COR_NOITE, 0.6))
	var caixa: VBoxContainer = pausa.get_node("Centro/Painel/Caixa")
	_rotulo(caixa, "Pausa", 14, COR_OURO)
	primeiro_pausa = _botao(caixa, "Continuar", _fechar_pausa)
	_botao(caixa, "Recomeçar fase", _sair_para.bind(Jogo.reiniciar_fase))
	_botao(caixa, "Menu principal", _sair_para.bind(Jogo.ir_para_menu))
	pausa.hide()


func _fechar_pausa() -> void:
	pausa.hide()
	get_tree().paused = false


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


## Teclado ou controle: os nomes de botão na tela acompanham o aparelho em uso.
func _atualizar_nomes() -> void:
	com_controle = Jogo.usando_controle()
	poder.text = Jogo.nome_botao("procurar")
	poder.reset_size()
	poder.position = Vector2(6.0, ALTURA - 6.0 - poder.size.y)
	if botao.visible:
		botao.text = Jogo.nome_botao(acao_botao)
		botao.reset_size()


## Onde a menina aparece na tela. A câmera da fase é filha dela: a posição do nó
## da câmera na tela é a da menina, mesmo com a imagem parada na borda do mapa.
func _menina_na_tela() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	return camera.get_global_transform_with_canvas().origin if camera else Vector2(LARGURA, ALTURA) / 2.0


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


## Fila de ícones e textos do topo: começa em `pos`, tem `largura` e encosta o
## conteúdo de um lado (ou no meio) conforme `alinhamento`.
func _fila(pos: Vector2, largura: float, alinhamento: BoxContainer.AlignmentMode) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.alignment = alinhamento
	fila.position = pos
	fila.size.x = largura
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 2)
	add_child(fila)
	return fila


func _por_icone(pai: Node, textura: Texture2D) -> TextureRect:
	var icone := TextureRect.new()
	icone.texture = textura
	icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(icone)
	return icone


## Mostra `total` ícones na fila: os primeiros `cheios` com a textura cheia e o
## resto com a vazia. O que acabou de encher brilha um instante.
func _encher(fila: HBoxContainer, cheios: int, total: int, cheia: Texture2D, vazia: Texture2D) -> void:
	while fila.get_child_count() < total:
		_por_icone(fila, vazia)
	for i in total:
		var icone: TextureRect = fila.get_child(i)
		if i < cheios and icone.texture == vazia:
			icone.modulate = Color(1.8, 1.8, 1.8)
			create_tween().tween_property(icone, "modulate", Color.WHITE, 0.5)
		icone.texture = cheia if i < cheios else vazia


## Ícone da arte (assets/ui); se o arquivo faltar, um círculo dourado do mesmo tamanho.
func _icone(nome: String, lado: int) -> Texture2D:
	if ResourceLoader.exists(ICONE % nome):
		return load(ICONE % nome) as Texture2D
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.95])
	g.colors = PackedColorArray([COR_OURO_CLARO, COR_OURO, Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = lado
	t.height = lado
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## O mesmo desenho em lilás apagado: estrelinha ou coração que ainda não foi ganho.
func _vazio(textura: Texture2D) -> Texture2D:
	var imagem: Image = textura.get_image().duplicate()   # sem mexer na imagem da textura cheia
	imagem.convert(Image.FORMAT_RGBA8)
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			imagem.set_pixel(x, y, Color(COR_VAZIO_ESCURO.lerp(COR_VAZIO_CLARO, cor.v), cor.a))
	return ImageTexture.create_from_image(imagem)
