# Ideia 1: A luz diminui sozinha, devagar

| | |
|---|---|
| **Status** | Aprovada |
| **Área** | Mecânica |
| **Fases** | 1, 2 e 3 |

## Resumo

Com o tempo, a bolha de visão da menina encolhe um pouco, mesmo sem encostar em frase ruim. Ela **nunca apaga sozinha**: para num tamanho mínimo. Só as frases ruins levam ao game over.

## Por que combina com o tema

A tristeza não precisa de um ataque para voltar; ela volta quando a gente fica parado e isolado. Cuidar de si é algo contínuo, e não uma vitória única. A criança aprende isso jogando, sem ninguém precisar explicar.

## Regras

1. **A luz cai devagar com o tempo.**
2. **Nunca apaga sozinha.** A queda para num mínimo: uma bolha pequena, mas visível. Mensagem: "o tempo deixa tudo mais difícil, mas não te derrota sozinho".
3. **Andar faz a luz cair mais devagar e ficar parado faz cair mais rápido** ("se mexer ajuda").
4. **A queda aumenta de fase para fase**, acompanhando o ambiente:

| Fase | Ambiente | Sensação | Queda da luz |
|---|---|---|---|
| 1 | Campo | Aberto, calmo, natural | Bem suave |
| 2 | Escola | Pessoas, cobrança, comparação | Média |
| 3 | Beco | Fechado, apertado, sozinho | Mais rápida |

5. **Frase boa** devolve um pedaço da luz.
6. **Frase ruim** tira luz e pode passar do mínimo. Se a luz chegar a zero, é game over.

## Cuidados (jogo infantil)

- A queda precisa ser **lenta**, para não gerar ansiedade. Referência: na fase 1, andando, a luz cheia leva uns **4 minutos** para chegar ao mínimo sem nada acontecer.
- **Aviso visual com a luz baixa:** a bolha pulsa devagar, como um coração, e a música fica abafada. Nada de alarme ou som agressivo.

## Valores iniciais (para testar e ajustar)

| Parâmetro | Valor | Observação |
|---|---|---|
| Luz máxima | 100 | |
| Luz mínima (queda natural) | 15 | Bolha pequena, mas visível |
| Queda base | 0,6 por segundo | Fase 1 |
| Multiplicador andando | 0,6 | Cai mais devagar |
| Multiplicador parada | 1,5 | Cai mais rápido |
| Multiplicador por fase | 1,0 / 1,4 / 1,9 | Campo / escola / beco |
| Frase boa | +12 | Cerca de 20 s de luz na fase 1 |
| Frase ruim | −25 | 4 hits a partir da luz cheia |
| Pulsar a partir de | 30 | Aviso de luz baixa |

Com esses valores, na fase 1 a luz cheia chega ao mínimo em cerca de 4 minutos andando e em cerca de 1,5 minuto parada.

## Como fazer no Godot 4 (esboço)

No script da personagem (`CharacterBody2D`):

```gdscript
@export var luz_max := 100.0
@export var luz_min := 15.0            # a queda natural para aqui
@export var queda_base := 0.6          # por segundo
@export var mult_andando := 0.6
@export var mult_parada := 1.5
@export var mult_fase := [1.0, 1.4, 1.9]   # campo, escola, beco
@export var raio_min := 24.0           # raio da bolha em pixels
@export var raio_max := 120.0
@export var dano_frase_ruim := 25.0   # 4 hits a partir da luz cheia

var fase := 0                          # 0 = campo, 1 = escola, 2 = beco
var luz := luz_max

func _physics_process(delta):
	# ... movimento da personagem (velocity / move_and_slide) ...

	var taxa: float = queda_base * mult_fase[fase]
	taxa *= mult_andando if velocity.length() > 0.1 else mult_parada
	if luz > luz_min:
		luz = max(luz - taxa * delta, luz_min)

	var raio: float = lerpf(raio_min, raio_max, luz / luz_max)
	# aplicar 'raio' na bolha de visão (shader, PointLight2D ou escala do sprite)

func pegar_frase_boa(valor := 12.0):
	luz = min(luz + valor, luz_max)

func levar_frase_ruim():
	luz -= dano_frase_ruim
	if luz <= 0.0:
		game_over()
```

## Ligação com outras ideias

- **[Ideia 2](02_frases_ruins.md):** a luz mínima (15) já é "último hit", que faz as frases com caminho começarem a andar. Ficar parado demais aumenta o perigo.
- **[Ideia 3](03_piscada.md):** a piscada a cada hit.
- **Arte:** as fases 2 (escola) e 3 (beco) vão precisar de chão e objetos novos no mesmo estilo pixel art.
