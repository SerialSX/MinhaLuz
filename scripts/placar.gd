extends Node
## Autoload "Placar": envia pontuação e tempo de jogo ao servidor da disciplina
## (tutorial "Godot Score Request": POST /v1/scores e /v1/gametime com x-api-key).
## Endereço e chave ficam em res://config/placar.cfg, que NÃO vai para o git
## (modelo em config/placar.exemplo.cfg). Sem esse arquivo, nada é enviado.

const ARQUIVO := "res://config/placar.cfg"
const ESPERA_MAX := 5.0

var _url := ""
var _chave := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) == OK:
		_url = str(cfg.get_value("servidor", "url", "")).trim_suffix("/")
		_chave = str(cfg.get_value("servidor", "chave", ""))


func enviar_pontuacao(pontos: int) -> void:
	_enviar("/v1/scores", {"score": pontos})


## Envia o tempo e espera a resposta (no máximo ESPERA_MAX segundos). Use com await.
func enviar_tempo(segundos: int) -> void:
	var http := _enviar("/v1/gametime", {"gametime": segundos})
	if http:
		await http.request_completed


## Um HTTPRequest por envio: dois pedidos ao mesmo nó dão ERR_BUSY.
func _enviar(rota: String, dados: Dictionary) -> HTTPRequest:
	if _url.is_empty() or _chave.is_empty():
		return null
	var http := HTTPRequest.new()
	http.timeout = ESPERA_MAX
	add_child(http)
	http.request_completed.connect(func(resultado: int, codigo: int, _cabecalhos: PackedStringArray, _corpo: PackedByteArray) -> void:
		if codigo != 200:
			push_warning("Placar: %s respondeu %d (resultado %d)" % [rota, codigo, resultado])
		http.queue_free())
	var cabecalhos := PackedStringArray(["Content-Type: application/json", "x-api-key: " + _chave])
	var erro := http.request(_url + rota, cabecalhos, HTTPClient.METHOD_POST, JSON.stringify(dados))
	if erro != OK:
		push_warning("Placar: não foi possível enviar %s (erro %d)" % [rota, erro])
		http.queue_free()
		return null
	return http
