# Tarefa 05: Frases boas, frases ruins e game over

| | |
|---|---|
| **Status** | A fazer |
| **Depende de** | Tarefa 04 |
| **Ideia de origem** | `docs/visao_geral.md`, `Ideias/01_luz_diminui.md`, `Ideias/02_frases_ruins.md` (só a parte básica) |

## Objetivo

Frases espalhadas pelo campo. As **boas** brilham através da névoa e aumentam a luz; as **ruins** ficam escondidas na névoa e tiram luz. Com a luz em zero, aparece a mensagem de game over e a fase recomeça.

## Arquivos

- **Usar:** `cenas/campo.tscn`, `cenas/menina.tscn`, `scripts/menina.gd`
- **Criar:** `cenas/frase.tscn`, `scripts/frase.gd`

## Regras (do Contexto)

| Item | Valor |
|---|---|
| Luz máxima | 100 |
| Frase boa | +12 de luz e some |
| Frase ruim | −25 de luz (4 hits com a luz cheia) |
| Proteção depois de um hit | 5 s (a menina pisca) |
| Frase ruim depois de acertar | some por 5 s e volta |
| Game over | luz ≤ 0 |
| Mensagem de game over | *"Você sempre pode recomeçar e tentar novamente."* |

## Passos

1. Criar `cenas/frase.tscn`:
   ```
   Frase (Area2D)              script: scripts/frase.gd
   ├── CollisionShape2D        retângulo do tamanho do texto
   └── Label                   centralizado
   ```
   No `Label`, usar `LabelSettings` com **tamanho de fonte 8** (a tela tem só 480×270, e a fonte padrão fica enorme) e posicionar o texto centralizado na colisão.
2. `scripts/frase.gd`:

```gdscript
extends Area2D

@export var boa := true
@export var texto := "Você é importante"

@onready var label: Label = $Label

func _ready() -> void:
	label.text = texto
	if boa:
		label.modulate = Color(1.0, 0.9, 0.5)   # amarelo, como os elásticos da menina
		z_index = 60                            # acima da névoa: brilha no escuro
	else:
		label.modulate = Color(0.55, 0.45, 0.6) # roxo apagado
		z_index = 5                             # abaixo da névoa: só aparece dentro da bolha
	body_entered.connect(_ao_encostar)

func _ao_encostar(corpo) -> void:   # sem tipo, para poder chamar os métodos da menina
	if not corpo.has_method("pegar_frase_boa"):
		return
	if boa:
		corpo.pegar_frase_boa()
		queue_free()
	elif corpo.levar_frase_ruim():
		_sumir_por(5.0)

func _sumir_por(segundos: float) -> void:
	hide()
	set_deferred("monitoring", false)
	await get_tree().create_timer(segundos).timeout
	show()
	monitoring = true
```

3. No `scripts/menina.gd`, acrescentar:

```gdscript
@export var frase_boa := 12.0
@export var dano_frase_ruim := 25.0
@export var tempo_protecao := 5.0
var protegida := false

func pegar_frase_boa() -> void:
	luz = minf(luz + frase_boa, luz_max)

# Retorna true se o hit valeu (a menina não estava protegida).
func levar_frase_ruim() -> bool:
	if protegida or luz <= 0.0:   # protegida, ou já em game over
		return false
	luz -= dano_frase_ruim
	if luz <= 0.0:
		game_over()
		return true
	_proteger()
	return true

func _proteger() -> void:
	protegida = true
	var t := create_tween().set_loops(int(tempo_protecao / 0.4))
	t.tween_property(sprite, "modulate:a", 0.3, 0.2)
	t.tween_property(sprite, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(tempo_protecao).timeout
	sprite.modulate.a = 1.0
	protegida = false

func game_over() -> void:
	set_physics_process(false)
	var camada := CanvasLayer.new()
	var msg := Label.new()
	msg.text = "Você sempre pode recomeçar e tentar novamente."
	var estilo := LabelSettings.new()
	estilo.font_size = 12
	msg.label_settings = estilo
	msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	camada.add_child(msg)
	get_tree().current_scene.add_child(camada)
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
```

4. Em `cenas/campo.tscn`, espalhar umas **6 frases boas** e **6 ruins**, com textos simples para crianças. Sugestões (provisórias, a lista oficial ainda vai ser feita):
   - **Boas:** "Você é importante", "Tudo bem pedir ajuda", "Você é capaz", "Sempre há algo de bom", "Você não está sozinha", "Amanhã pode ser melhor".
   - **Ruins:** "Ninguém liga", "Você não consegue", "Não adianta tentar", "Você é sozinha", "Você sempre erra", "Ninguém gosta de você".

## Como conferir

- [ ] As frases boas aparecem através da névoa, longe da menina.
- [ ] As frases ruins só aparecem quando entram na bolha.
- [ ] Encostar numa frase boa faz a bolha crescer e a frase some.
- [ ] Encostar numa ruim faz a bolha diminuir, a menina pisca por 5 s e a frase some e volta depois.
- [ ] Durante a proteção, outra frase ruim não tira luz.
- [ ] No 4º hit (com a luz cheia, sem pegar frases boas), aparece a mensagem e o campo recomeça depois de 3 s.

## Fora do escopo

- A luz caindo sozinha com o tempo (Ideia 1, depois do protótipo).
- Frases errantes e com caminho (Ideia 2).
- Piscada da tela (Ideia 3).
- Nuvem escura do fim de fase, menus e som.

## Ao terminar

- Status: **Feito**.
- Mensagem de commit sugerida: `Adiciona frases boas e ruins e o game over`
