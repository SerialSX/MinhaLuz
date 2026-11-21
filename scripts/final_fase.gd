class_name FinalFase
extends Node2D
## O final da fase: a menina, parada no centro da nuvem, brilha. A nuvem se abre
## em palavras ruins, que aparecem em volta e vêm em espiral, atraídas pelo
## brilho. A menina e as amigas falam palavras boas, que voam até as ruins: cada
## ruim vira a resposta do seu par, em dourado, e estoura em faíscas.
## Não dá para perder: apertar Brilhar ou Procurar só solta mais palavras boas.
## A fase cria este nó em SobreNevoa, na posição da menina, e chama comecar().
## As palavras são desenhadas aqui (_draw); o brilho e as faíscas são nós filhos.
## No fim, emite `terminou` e se libera sozinho.

signal terminou(respondidas_longe: int, total: int)

const RAIO_HALO := 60.0          # o brilho da menina: as palavras ruins param na borda dele
const RAIO_NASCER := 125.0       # as palavras ruins aparecem num anel a esta distância...
const RAIO_NASCER_MIN := 118.0   # ...ou um pouco menos, onde a tela corta o anel
const LONGE := 90.0              # respondida além disto vale mais e conta para a estrela
const MAX_NA_TELA := 5
const ATRACAO := 18.0            # px/s na direção do brilho
const GIRO := 0.25               # rad/s: elas vêm em espiral
const TEMPO_NUVEM := 7.0         # a nuvem solta todas as palavras ruins ao longo deste tempo
const TEMPO_SURGIR := 0.3        # a palavra ruim aparece aos poucos (nada surge de repente)
const VELOCIDADE_BOA := 160.0
const INTERVALO_MENINA := 0.7    # a menina fala uma palavra boa sozinha...
const INTERVALO_AMIGA := 1.5     # ...e cada amiga também
const ESPERA_SOZINHA := 0.6      # ...mas só responde a ruim que já deu para ver chegando
const ACUMULADAS := 3            # com tantas ruins sem resposta, a menina fala 2 vezes mais depressa
const INTERVALO_BOTAO := 0.25    # apertando: no máximo 4 por segundo (e sem aquela espera)
const TEMPO_RESPOSTA := 0.4      # a ruim fica este tempo como resposta dourada, e estoura
const TEMPO_FRASE_CHAVE := 1.5
const PONTOS_LONGE := 25
const PONTOS_PERTO := 10
const NOTAS := [1.0, 1.125, 1.25, 1.5, 1.667]   # escala de 5 notas: o som sobe a cada palavra
const TAMANHO_TEXTO := 8
const BOCA := Vector2(0, -6)     # de onde a palavra boa sai, a partir do centro de quem fala
const DOURADO := Color(1.0, 0.827, 0.42)
const COR_BOA := Color(1.0, 0.878, 0.541)
const COR_FAISCA := Color(1.0, 0.93, 0.65)
const COR_RUIM := Color(0.62, 0.5, 0.68)
const COR_FUNDO_RUIM := Color(0.13, 0.09, 0.19)
const COR_CONTORNO := Color(0.16, 0.09, 0.02)


## Uma palavra ruim na tela. `pos` é a partir da menina (o centro do brilho).
class Ruim:
	var par := 0           # índice em `pares`
	var pos := Vector2.ZERO
	var idade := 0.0
	var mirada := false    # já tem uma palavra boa a caminho
	var virou := -1.0      # 0 ou mais: há quantos segundos virou a resposta do par


## Uma palavra boa voando até a ruim que ela responde.
class Boa:
	var texto := ""
	var pos := Vector2.ZERO
	var alvo: Ruim


var amigas: Array = []
var pares: Array = []            # [ruim, boa] da fase
var total := 0
var frase_chave := ""
var hud: Hud
var fonte: Font
var halo: Sprite2D
var placa_boa: StyleBoxFlat      # fundo da resposta: dourado e redondo (o "bom" do jogo)
var tamanhos: Array[Vector2] = []   # espaço que cada par ocupa (a resposta é a mais comprida)
var tempo := 0.0
var faltam := 0                  # palavras ruins ainda dentro da nuvem
var ruins: Array[Ruim] = []
var boas: Array[Boa] = []
var respondidas := 0
var respondidas_longe := 0
var faladas := 0
var estouradas := 0
var angulo := 0.0                # onde a próxima ruim tenta aparecer
var espera_ruim := 1.0           # a primeira sai quando o brilho termina de abrir
var espera_botao := 0.0
var apertou := false             # um aperto fica guardado até o intervalo do botão acabar
var esperas := PackedFloat32Array()   # até a próxima palavra boa: [menina, amiga 1, amiga 2, ...]
var acabou := false


func _init() -> void:
	set_process(false)   # só depois de comecar()


## `as_amigas`: crianças acesas (podem ser 0). `os_pares`: os [ruim, boa] da fase.
## `quantas`: total de palavras ruins deste final.
func comecar(menina: Menina, as_amigas: Array, os_pares: Array, quantas: int, a_frase_chave: String, o_hud: Hud) -> void:
	amigas = as_amigas
	pares = os_pares
	total = quantas
	faltam = quantas
	frase_chave = a_frase_chave
	hud = o_hud
	fonte = ThemeDB.fallback_font
	for par: Array in pares:
		var medida := _medir(par[0])
		tamanhos.append(Vector2(maxf(medida.x, _medir(par[1]).x) + 12.0, medida.y + 8.0))
	# Um instante só com as palavras ruins chegando, e então as boas começam.
	esperas.append(1.6)
	for i in amigas.size():
		esperas.append(1.8 + 0.25 * i)
	angulo = randf() * TAU
	_criar_halo()
	Audio.tocar_sfx("brilhar")
	hud.mostrar_dica("Agora ela não foge mais.")
	hud.atualizar_final(0, total)
	hud.mostrar_botao("brilhar", menina)
	set_process(true)


func _process(delta: float) -> void:
	tempo += delta
	# O brilho abre em 1 s e depois respira devagar (nunca pisca, nunca clarão).
	var abre := minf(tempo, 1.0)
	halo.scale = Vector2.ONE * (abre * (2.0 - abre) * (0.96 + 0.04 * sin(tempo * 2.5)))
	if acabou:
		return

	espera_ruim -= delta
	if espera_ruim <= 0.0 and _soltar_ruim():
		espera_ruim = TEMPO_NUVEM / total
	_falar_no_botao(delta)
	_falar_sozinhas(delta)
	_mover_ruins(delta)
	_mover_boas(delta)
	queue_redraw()

	if respondidas >= total and ruins.is_empty():
		acabou = true
		hud.esconder_botao()
		hud.mostrar_frase(frase_chave)
		create_tween().tween_callback(_terminar).set_delay(TEMPO_FRASE_CHAVE)


func _terminar() -> void:
	hud.atualizar_final(0, 0)
	terminou.emit(respondidas_longe, total)
	var t := create_tween()
	t.tween_property(halo, "modulate:a", 0.0, 0.8)
	t.tween_callback(queue_free)


# ---------- Palavras ruins ----------

## A nuvem solta mais uma palavra ruim, num lugar livre do anel e dentro da tela.
## Retorna null se não deu (nuvem vazia, tela cheia ou sem lugar agora).
func _soltar_ruim() -> Ruim:
	if faltam <= 0 or ruins.size() >= MAX_NA_TELA:
		return null
	var ruim := Ruim.new()
	ruim.par = (total - faltam) % pares.size()
	var area := _area_na_tela(ruim)
	for _tentativa in 16:
		angulo += 2.4   # ângulo de ouro: cada uma aparece longe da anterior
		var pos := (Vector2.from_angle(angulo) * RAIO_NASCER).clamp(area.position, area.end)
		if pos.length() >= RAIO_NASCER_MIN and _livre(ruim, pos):
			ruim.pos = pos
			ruins.append(ruim)
			faltam -= 1
			return ruim
	return null


func _mover_ruins(delta: float) -> void:
	for ruim: Ruim in ruins.duplicate():
		ruim.idade += delta
		if ruim.virou >= 0.0:
			ruim.virou += delta
			if ruim.virou >= TEMPO_RESPOSTA:
				_estourar(ruim)
			continue
		# Atraída pelo brilho: vem em espiral e para na borda dele.
		var raio := ruim.pos.length()
		if raio <= RAIO_HALO:
			continue
		var area := _area_na_tela(ruim)
		var pos := Vector2.from_angle(ruim.pos.angle() + GIRO * delta) * maxf(raio - ATRACAO * delta, RAIO_HALO)
		pos = pos.clamp(area.position, area.end)
		if _livre(ruim, pos):
			ruim.pos = pos


## Onde o centro desta palavra pode ficar: dentro da tela, fora do topo do HUD
## e da dica de baixo. Em coordenadas deste nó.
func _area_na_tela(ruim: Ruim) -> Rect2:
	var tela := get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()
	tela.position -= global_position
	var meio := tamanhos[ruim.par] / 2.0
	return tela.grow_individual(-4.0 - meio.x, -16.0 - meio.y, -4.0 - meio.x, -26.0 - meio.y)


## A palavra cabe em `pos` sem encostar em outra? Cada uma guarda o espaço da
## sua resposta: a tela nunca vira uma sopa de texto.
func _livre(ruim: Ruim, pos: Vector2) -> bool:
	var area := Rect2(pos - tamanhos[ruim.par] / 2.0, tamanhos[ruim.par])
	for outra in ruins:
		if outra != ruim and area.intersects(Rect2(outra.pos - tamanhos[outra.par] / 2.0, tamanhos[outra.par])):
			return false
	return true


## A palavra ruim sem resposta mais distante do brilho, entre as que estão na
## tela há pelo menos `idade` segundos (null se não há nenhuma).
func _alvo(idade: float) -> Ruim:
	var alvo: Ruim = null
	for ruim in ruins:
		if ruim.mirada or ruim.idade < idade:
			continue
		if alvo == null or ruim.pos.length_squared() > alvo.pos.length_squared():
			alvo = ruim
	return alvo


## A palavra boa chegou: a ruim vira a resposta do par.
func _responder(ruim: Ruim) -> void:
	ruim.virou = 0.0
	respondidas += 1
	var longe := ruim.pos.length() > LONGE
	if longe:
		respondidas_longe += 1
	Jogo.somar_pontos(PONTOS_LONGE if longe else PONTOS_PERTO)
	hud.atualizar_final(respondidas, total)


## A resposta estoura em faíscas douradas (sem clarão). O nó das faíscas se libera sozinho.
func _estourar(ruim: Ruim) -> void:
	ruins.erase(ruim)
	Audio.tocar_sfx("estouro", NOTAS[estouradas % NOTAS.size()])
	estouradas += 1
	var faiscas := CPUParticles2D.new()
	faiscas.position = ruim.pos
	faiscas.amount = 22
	faiscas.lifetime = 0.7
	faiscas.one_shot = true
	faiscas.explosiveness = 0.9
	faiscas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	faiscas.emission_rect_extents = _medir(pares[ruim.par][1]) / 2.0
	faiscas.spread = 180.0
	faiscas.gravity = Vector2(0, 30)
	faiscas.initial_velocity_min = 12.0
	faiscas.initial_velocity_max = 40.0
	faiscas.scale_amount_min = 2.0
	faiscas.scale_amount_max = 3.0
	var rampa := Gradient.new()   # some só no fim
	rampa.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	rampa.colors = PackedColorArray([COR_FAISCA, DOURADO, Color(DOURADO, 0.0)])
	faiscas.color_ramp = rampa
	faiscas.finished.connect(faiscas.queue_free)
	add_child(faiscas)


# ---------- Palavras boas ----------

## Cada aperto de Brilhar ou Procurar solta mais uma palavra boa da menina.
## Sem nenhuma ruim esperando resposta, o aperto puxa mais uma de dentro da nuvem.
func _falar_no_botao(delta: float) -> void:
	espera_botao -= delta
	if Input.is_action_just_pressed("brilhar") or Input.is_action_just_pressed("procurar"):
		apertou = true
	if not apertou or espera_botao > 0.0:
		return
	apertou = false
	var alvo := _alvo(0.0)
	if alvo == null:
		alvo = _soltar_ruim()
	if alvo:
		_falar(BOCA, DadosFases.PALAVRAS_MENINA, alvo)
		espera_botao = INTERVALO_BOTAO


## Sem apertar nada: a menina e as amigas falam sozinhas, cada uma no seu ritmo.
## Com mais de uma pronta, fala quem espera há mais tempo.
func _falar_sozinhas(delta: float) -> void:
	for i in esperas.size():
		esperas[i] -= delta
	for _vez in esperas.size():
		var alvo := _alvo(ESPERA_SOZINHA)
		var quem := 0
		for i in esperas.size():
			if esperas[i] < esperas[quem]:
				quem = i
		if alvo == null or esperas[quem] > 0.0:
			return
		if quem == 0:
			# Com várias ruins sem resposta, a menina fala duas vezes mais depressa:
			# mesmo sem amigas e sem apertar nada, o final não se arrasta.
			var sem_resposta := 0
			for ruim in ruins:
				if not ruim.mirada:
					sem_resposta += 1
			esperas[0] = INTERVALO_MENINA * (0.5 if sem_resposta >= ACUMULADAS else 1.0)
			_falar(BOCA, DadosFases.PALAVRAS_MENINA, alvo)
		else:
			var amiga: Node2D = amigas[quem - 1]
			_falar(amiga.global_position - global_position + BOCA, DadosFases.PALAVRAS_AMIGAS, alvo)
			esperas[quem] = INTERVALO_AMIGA


## Uma palavra boa curta sai de `de` e voa até a ruim `alvo`.
func _falar(de: Vector2, palavras: Array, alvo: Ruim) -> void:
	alvo.mirada = true
	var boa := Boa.new()
	boa.texto = palavras[faladas % palavras.size()]
	boa.pos = de
	boa.alvo = alvo
	boas.append(boa)
	Audio.tocar_sfx("palavra_boa", NOTAS[faladas % NOTAS.size()])
	faladas += 1


func _mover_boas(delta: float) -> void:
	for boa: Boa in boas.duplicate():
		var ruim := boa.alvo
		boa.pos = boa.pos.move_toward(ruim.pos, VELOCIDADE_BOA * delta)
		# Tocou na placa da ruim (não precisa chegar ao meio: um texto não cobre o outro).
		var meio := _medir(pares[ruim.par][0]) / 2.0 + Vector2(4.0, 4.0)
		var falta := (boa.pos - ruim.pos).abs()
		if falta.x <= meio.x and falta.y <= meio.y:
			boas.erase(boa)
			_responder(ruim)


# ---------- Desenho ----------

## Halo dourado aditivo em volta da menina: soma luz ao que está embaixo, com
## pouca força, para nunca virar um clarão.
func _criar_halo() -> void:
	var rampa := Gradient.new()   # do centro para a borda, com um anel fraquinho na borda
	rampa.offsets = PackedFloat32Array([0.0, 0.5, 0.86, 0.93, 1.0])
	rampa.colors = PackedColorArray([
		Color(DOURADO, 0.42), Color(DOURADO, 0.28), Color(DOURADO, 0.14), Color(DOURADO, 0.26), Color(DOURADO, 0.0)])
	var textura := GradientTexture2D.new()
	textura.gradient = rampa
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = int(RAIO_HALO * 2.0)
	textura.height = int(RAIO_HALO * 2.0)
	var soma := CanvasItemMaterial.new()
	soma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo = Sprite2D.new()
	halo.texture = textura
	halo.material = soma
	halo.scale = Vector2.ZERO
	halo.show_behind_parent = true   # as palavras ficam por cima do brilho
	add_child(halo)
	placa_boa = StyleBoxFlat.new()
	placa_boa.bg_color = COR_BOA
	placa_boa.border_color = COR_CONTORNO
	placa_boa.set_border_width_all(1)
	placa_boa.set_corner_radius_all(5)
	placa_boa.anti_aliasing = false


func _draw() -> void:
	for ruim in ruins:
		if ruim.virou < 0.0:
			_desenhar_ruim(ruim)
	for ruim in ruins:   # as respostas por cima das ruins
		if ruim.virou >= 0.0:
			_desenhar_resposta(ruim)
	for boa in boas:
		_escrever(boa.pos, boa.texto, COR_BOA, 1.0)


## Código visual do jogo: ruim = roxo com borda pontuda (como as frases ruins da fase).
func _desenhar_ruim(ruim: Ruim) -> void:
	var texto: String = pares[ruim.par][0]
	var alfa := minf(ruim.idade / TEMPO_SURGIR, 1.0)
	var centro := ruim.pos.round()
	var meio := (_medir(texto) / 2.0).ceil() + Vector2(3.0, 0.0)
	var pontos := PackedVector2Array()
	var dentes := maxi(int(meio.x * 2.0 / 6.0), 2)
	for i in dentes + 1:   # em cima, da esquerda para a direita
		var x := lerpf(-meio.x, meio.x, i / float(dentes))
		pontos.append(centro + Vector2(x, -meio.y))
		if i < dentes:
			pontos.append(centro + Vector2(x + meio.x / dentes, -meio.y - 3.0))
	for i in dentes + 1:   # embaixo, da direita para a esquerda
		var x := lerpf(meio.x, -meio.x, i / float(dentes))
		pontos.append(centro + Vector2(x, meio.y))
		if i < dentes:
			pontos.append(centro + Vector2(x - meio.x / dentes, meio.y + 3.0))
	draw_colored_polygon(pontos, Color(COR_FUNDO_RUIM, 0.9 * alfa))
	pontos.append(pontos[0])
	draw_polyline(pontos, Color(COR_RUIM, alfa), 1.0)
	_escrever(centro, texto, COR_RUIM, alfa)


## A resposta do par numa placa dourada e redonda, que incha um pouco e volta
## (o texto fica parado, para dar para ler), e então estoura.
func _desenhar_resposta(ruim: Ruim) -> void:
	var texto: String = pares[ruim.par][1]
	var centro := ruim.pos.round()
	var incha := roundf(2.0 * sin(PI * ruim.virou / TEMPO_RESPOSTA))
	var meio := (_medir(texto) / 2.0).ceil() + Vector2(5.0 + incha, 1.0 + incha)
	draw_style_box(placa_boa, Rect2(centro - meio, meio * 2.0))
	draw_string(fonte, _canto(centro, texto), texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_TEXTO, COR_CONTORNO)


## Texto centrado em `centro`, com contorno escuro: legível no chão claro e no escuro.
func _escrever(centro: Vector2, texto: String, cor: Color, alfa: float) -> void:
	var onde := _canto(centro, texto)
	draw_string_outline(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_TEXTO, 4, Color(COR_CONTORNO, alfa))
	draw_string(fonte, onde, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_TEXTO, Color(cor, alfa))


## Onde começar a escrever (linha de base, à esquerda) para o texto ficar centrado em `centro`.
func _canto(centro: Vector2, texto: String) -> Vector2:
	return (centro - _medir(texto) / 2.0).round() + Vector2(0.0, fonte.get_ascent(TAMANHO_TEXTO))


func _medir(texto: String) -> Vector2:
	return fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_TEXTO)
