extends Node
## Autoload "Audio": música com crossfade e loop, e efeitos sonoros.
## Arquivo faltando = silêncio (o jogo continua funcionando).

const MUSICA := "res://assets/audio/musica/%s.wav"
const SFX := "res://assets/audio/sfx/%s.wav"
const VOZES_SFX := 8
const CROSSFADE := 1.0

var _musica_atual := ""
var _tocadores: Array[AudioStreamPlayer] = []
var _ativo := 0
var _tween: Tween
var _sfx: Array[AudioStreamPlayer] = []
var _proximo_sfx := 0
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		_tocadores.append(_novo_tocador("Musica"))
	for i in VOZES_SFX:
		_sfx.append(_novo_tocador("Efeitos"))


func tocar_musica(nome: String) -> void:
	if nome == _musica_atual:
		return
	_musica_atual = nome
	var stream := _carregar(MUSICA % nome)
	if _tween:
		_tween.kill()
	var saindo := _tocadores[_ativo]
	_ativo = 1 - _ativo
	var entrando := _tocadores[_ativo]
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(saindo, "volume_db", -60.0, CROSSFADE)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = maxi(0, int(stream.get_length() * stream.mix_rate) - 1)
	if stream:
		entrando.stream = stream
		entrando.volume_db = -30.0
		entrando.play()
		_tween.tween_property(entrando, "volume_db", 0.0, CROSSFADE)
	_tween.chain().tween_callback(saindo.stop)


## `tom` muda a altura do som (1.0 = normal): usado no combo dos vaga-lumes e nas estrelas.
func tocar_sfx(nome: String, tom := 1.0) -> void:
	var stream := _carregar(SFX % nome)
	if stream == null:
		return
	# Prefere um tocador livre, para um som curto não cortar um som longo.
	var p := _sfx[_proximo_sfx]
	for i in _sfx.size():
		var candidato := _sfx[(_proximo_sfx + i) % _sfx.size()]
		if not candidato.playing:
			p = candidato
			break
	_proximo_sfx = (_sfx.find(p) + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = tom
	p.play()


func _carregar(caminho: String) -> AudioStream:
	if not _cache.has(caminho):
		_cache[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _cache[caminho]


func _novo_tocador(barramento: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = barramento
	add_child(p)
	return p
