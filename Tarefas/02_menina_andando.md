# Tarefa 02: A menina andando

| | |
|---|---|
| **Status** | A fazer |
| **Depende de** | Tarefa 01 |
| **Ideia de origem** | Protótipo da fase 1 |

## Objetivo

A menina anda nas 4 direções com WASD e setas, com a animação certa (parada e andando), e a câmera segue.

## Arquivos

- **Usar:** `assets/sprites/personagem/menina_folha_nativa.png`
- **Criar:** `cenas/menina.tscn`, `scripts/menina.gd`

## A folha de sprites

`menina_folha_nativa.png` tem **120×80**: **6 colunas × 4 linhas** de quadros de **20×20**.

| Linha | Direção |
|---|---|
| 0 | baixo |
| 1 | esquerda |
| 2 | direita |
| 3 | cima |

| Colunas | Animação |
|---|---|
| 0 e 1 | parada (2 quadros) |
| 2, 3, 4 e 5 | andando (4 quadros) |

## Passos

1. Criar `cenas/menina.tscn` com esta estrutura:
   ```
   Menina (CharacterBody2D)        script: scripts/menina.gd, motion_mode = Floating
   ├── AnimatedSprite2D
   ├── CollisionShape2D            círculo, raio 5
   └── Camera2D                    enabled = true
   ```
   O `motion_mode = Floating` é o modo para jogos vistos de cima (o padrão, Grounded, é para jogos de plataforma).
2. No `AnimatedSprite2D`, criar um `SpriteFrames` com **8 animações**, recortadas da folha (no editor: "Adicionar quadros de uma folha de sprites", Horizontal 6, Vertical 4):
   - `parada_baixo`, `parada_esquerda`, `parada_direita`, `parada_cima`: 2 quadros cada, **2 FPS**, em loop.
   - `andando_baixo`, `andando_esquerda`, `andando_direita`, `andando_cima`: 4 quadros cada, **8 FPS**, em loop.
3. Script `scripts/menina.gd`:

```gdscript
extends CharacterBody2D

@export var velocidade := 60.0   # pixels por segundo (viewport 480x270)

var direcao := "baixo"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var entrada := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
	velocity = entrada * velocidade
	move_and_slide()

	if entrada != Vector2.ZERO:
		if absf(entrada.x) > absf(entrada.y):
			direcao = "direita" if entrada.x > 0.0 else "esquerda"
		else:
			direcao = "baixo" if entrada.y > 0.0 else "cima"
		sprite.play("andando_" + direcao)
	else:
		sprite.play("parada_" + direcao)
```

4. Para testar, criar uma cena temporária `cenas/teste_menina.tscn` (um `Node2D` com a menina dentro) e rodar com F6.

## Como conferir

- [ ] WASD e setas movem a menina nas 4 direções.
- [ ] A animação muda para a direção certa e volta para "parada" ao soltar a tecla.
- [ ] A testa (pele) fica para o lado em que ela anda.
- [ ] O sprite fica nítido, sem borrar.
- [ ] A câmera segue a menina.

## Fora do escopo

- Luz, névoa, frases (tarefas 04 e 05).
- Cenário (tarefa 03).

## Ao terminar

- Status: **Feito**.
- Mensagem de commit sugerida: `Adiciona a menina com movimento e animação`
