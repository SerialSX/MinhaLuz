extends Node
## Autoload "Jogo": estado da partida (fase, pontos, tempo, estrelas), configurações
## e recorde salvos em user://config.cfg, troca de cena com fade e o aparelho em
## uso (teclado ou controle), para mostrar o nome certo dos botões.

signal config_mudou

const CENA_MENU := "res://cenas/menu.tscn"
const CENA_HISTORIA := "res://cenas/historia.tscn"
const CENA_FASE := "res://cenas/fase.tscn"
const ARQUIVO_CONFIG := "user://config.cfg"
const TAMANHO_BASE := Vector2i(480, 270)
const COR_FADE := Color(0.043, 0.039, 0.078)
## Nome do botão de cada ação: [no teclado, no controle].
const BOTOES := {
	"brilhar": ["Espaço", "A"],
	"procurar": ["Shift", "B"],
	"pausar": ["Esc", "Start"],
}

var fase_atual := 0
var pontos := 0
var pontos_inicio_fase := 0
## Estrelas (0 a 3) ganhas em cada fase desta partida.
var estrelas: Array[int] = []
## true depois da última fase: a história mostra o final e a tela final.
var fim_de_jogo := false
## Segundos jogados nesta partida (só conta durante a fase, fora da pausa).
var tempo_partida := 0.0
## Segundos desde que o jogo abriu: é o "gametime" enviado ao servidor.
var tempo_total := 0.0
var contando_tempo := false
var config := {
	"volume_musica": 0.8,
	"volume_efeitos": 0.8,
	"tela_cheia": false,
	"piscar_tela": true,
	"recorde": 0,
	"dificuldade": 1,   # 0 Fácil, 1 Normal, 2 Difícil (DadosFases.DIFICULDADES)
}

var _trocando := false
var _com_controle := false
var _saindo := false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_criar_fade()
	_carregar_config()
	_aplicar_config()
	_ajustar_janela()


func _process(delta: float) -> void:
	tempo_total += delta
	if contando_tempo and not get_tree().paused:
		tempo_partida += delta


func _input(event: InputEvent) -> void:
	# Guarda de que aparelho veio o último botão (ou o joystick inclinado).
	if event.is_pressed():
		_com_controle = event is InputEventJoypadButton or event is InputEventJoypadMotion


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tela_cheia"):
		config["tela_cheia"] = not config["tela_cheia"]
		salvar_config()


func _notification(what: int) -> void:
	# Fechar no X da janela também envia o tempo de jogo.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		sair_do_jogo()


func somar_pontos(n: int) -> void:
	pontos += n


## Estrelas (0 a 3) ganhas na fase atual.
func registrar_estrelas(n: int) -> void:
	estrelas.resize(DadosFases.FASES.size())
	estrelas[fase_atual] = n


func total_estrelas() -> int:
	var total := 0
	for n in estrelas:
		total += n
	return total


## Guarda os pontos desta partida se forem o novo recorde. Devolve true se bateu.
func registrar_recorde() -> bool:
	if pontos <= config["recorde"]:
		return false
	config["recorde"] = pontos
	salvar_config()
	return true


## O último botão apertado foi de um controle (e não do teclado ou do mouse).
func usando_controle() -> bool:
	return _com_controle


## Como o botão da ação ("brilhar", "procurar" ou "pausar") se chama no aparelho em uso.
func nome_botao(acao: String) -> String:
	return BOTOES[acao][1 if _com_controle else 0]


## Cada fase começa pela história dela (cenas/historia.tscn), que depois abre a fase.
func novo_jogo() -> void:
	fase_atual = 0
	pontos = 0
	pontos_inicio_fase = 0
	tempo_partida = 0.0
	estrelas.clear()
	fim_de_jogo = false
	trocar_cena(CENA_HISTORIA)


func reiniciar_fase() -> void:
	pontos = pontos_inicio_fase
	trocar_cena(CENA_FASE)


func proxima_fase() -> void:
	fase_atual = mini(fase_atual + 1, DadosFases.FASES.size() - 1)
	pontos_inicio_fase = pontos
	trocar_cena(CENA_HISTORIA)


## Depois da última fase: a história final e a tela final.
func terminar_jogo() -> void:
	fim_de_jogo = true
	trocar_cena(CENA_HISTORIA)


func ir_para_menu() -> void:
	contando_tempo = false
	trocar_cena(CENA_MENU)


## Envia o tempo de jogo e fecha, mesmo que o servidor não responda (máx. 5 s).
func sair_do_jogo() -> void:
	if _saindo:
		return
	_saindo = true
	contando_tempo = false
	get_tree().paused = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	create_tween().tween_property(_fade, "color:a", 1.0, 0.3)
	await Placar.enviar_tempo(int(tempo_total))
	get_tree().quit()


func formatar_tempo(segundos: float) -> String:
	var s := int(segundos)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [s / 60, s % 60]


func trocar_cena(caminho: String) -> void:
	if _trocando:
		return
	_trocando = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.35)
	await t.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(caminho)
	await get_tree().process_frame
	await get_tree().process_frame
	_trocando = false
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t = create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.35)


func salvar_config() -> void:
	var arquivo := ConfigFile.new()
	for chave: String in config:
		arquivo.set_value("config", chave, config[chave])
	arquivo.save(ARQUIVO_CONFIG)
	_aplicar_config()
	config_mudou.emit()


func _carregar_config() -> void:
	var arquivo := ConfigFile.new()
	if arquivo.load(ARQUIVO_CONFIG) != OK:
		return
	for chave: String in config:
		config[chave] = arquivo.get_value("config", chave, config[chave])
	# Arquivo editado à mão ou estragado: a dificuldade sempre vale uma das três.
	config["dificuldade"] = clampi(int(config["dificuldade"]), 0, DadosFases.DIFICULDADES.size() - 1)


func _aplicar_config() -> void:
	_volume("Musica", config["volume_musica"])
	_volume("Efeitos", config["volume_efeitos"])
	var cheia := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if cheia != config["tela_cheia"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if config["tela_cheia"] else DisplayServer.WINDOW_MODE_WINDOWED)
		_ajustar_janela()


func _volume(barramento: String, valor: float) -> void:
	var i := AudioServer.get_bus_index(barramento)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(valor, 0.0001)))
	AudioServer.set_bus_mute(i, valor <= 0.0)


## Janela no maior múltiplo inteiro de 480×270 que cabe na tela
## (1440×810 não cabe num notebook 1366×768).
func _ajustar_janela() -> void:
	if DisplayServer.get_name() == "headless" or config["tela_cheia"]:
		return
	var area := DisplayServer.screen_get_usable_rect()
	@warning_ignore("integer_division")
	var escala := mini((area.size.x - 16) / TAMANHO_BASE.x, (area.size.y - 64) / TAMANHO_BASE.y)
	var tamanho := TAMANHO_BASE * clampi(escala, 1, 4)
	DisplayServer.window_set_size(tamanho)
	@warning_ignore("integer_division")
	DisplayServer.window_set_position(area.position + (area.size - tamanho) / 2)


func _criar_fade() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 100
	add_child(camada)
	_fade = ColorRect.new()
	_fade.color = Color(COR_FADE, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_fade)
