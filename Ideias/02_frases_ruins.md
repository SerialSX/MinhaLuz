# Ideia 2: Frases ruins com comportamentos diferentes

| | |
|---|---|
| **Status** | Aprovada |
| **Área** | Mecânica |
| **Fases** | 1, 2 e 3 |
| **Público** | Crianças de 4 a 13 anos |

## Resumo

Nem toda frase ruim se comporta igual. Algumas ficam paradas, outras flutuam devagar, e algumas começam a andar num caminho fixo quando a menina está quase sem luz. **Nenhuma frase persegue a menina de verdade**: o perigo é previsível, para crianças pequenas conseguirem aprender e desviar.

## Por que combina com o tema

Pensamentos negativos parecem mais fortes quando a gente já está mal. No jogo, as frases "acordam" quando a luz está no fim, e quem mantém a luz alta (juntando frases boas) fica mais protegida. É o ciclo positivo, mostrado com movimento.

## Tipos de frase ruim

| Tipo | Comportamento | Quando aparece |
|---|---|---|
| **Parada** | Fica num lugar fixo, como um obstáculo | Desde a fase 1 |
| **Errante** | Flutua bem devagar, sem rumo, e nunca vai atrás da menina | Desde a fase 1 |
| **Com caminho** | Fica parada até a menina estar no último hit. Aí começa a andar num **caminho fixo** (ida e volta, círculo ou zigue-zague) | A partir da fase 2 |

**Removido:** o "sussurro" (frase invisível que aparecia de surpresa). Para crianças a partir de 4 anos, susto não é o objetivo.

## Regras

1. **Último hit:** é quando mais um hit apagaria a luz (luz ≤ dano). Nesse momento, as frases **com caminho** começam a andar.
2. Quando a menina sai do último hit (pega uma frase boa), as frases com caminho **voltam a parar**. Pegar frase boa acalma o mundo.
3. **Velocidade:** errante e com caminho andam a **40% da velocidade da menina**. Sempre dá para desviar.
4. **Aviso antes de andar:** a frase treme ou escurece por cerca de 1 segundo antes de começar o caminho.
5. **Depois de um hit:** a frase some por **5 segundos** e a menina fica protegida nesse tempo, piscando (ver [Ideia 3](03_piscada.md)). Ela não perde luz várias vezes seguidas.
6. **Dano:** cada frase ruim tira **25** de luz (máximo 100), ou seja, 4 hits a partir da luz cheia.

## Distribuição por fase

| Fase | Ambiente | Tipos |
|---|---|---|
| 1 | Campo | Parada e errante |
| 2 | Escola | Parada, errante e com caminho |
| 3 | Beco | Os três, em maior quantidade e com caminhos mais longos |

## Valores iniciais (para testar e ajustar)

| Parâmetro | Valor |
|---|---|
| Dano de frase ruim | 25 |
| Velocidade (errante e com caminho) | 40% da velocidade da menina |
| Proteção depois do hit | 5 s |
| Tempo de aviso antes de andar | 1 s |

## Como fazer no Godot 4 (esboço)

- **Parada:** um `Area2D` com o texto da frase e uma `CollisionShape2D`.
- **Errante:** a mesma cena, sorteando de tempos em tempos uma direção nova e andando devagar.
- **Com caminho:** um `Path2D` desenhado no editor com um `PathFollow2D`. A frase fica dentro do `PathFollow2D`, e o `progress` só avança quando a menina está no último hit.

```gdscript
# frase_com_caminho.gd, no PathFollow2D
@export var velocidade := 48.0     # 40% de uma menina a 120 px/s
var menina: Node                   # referência à personagem

func _physics_process(delta):
	if menina.luz <= menina.dano_frase_ruim:   # último hit
		progress += velocidade * delta
```

## Ligação com outras ideias

- **[Ideia 1](01_luz_diminui.md):** a luz cai sozinha até o mínimo (15), que já é "último hit". Ficar parado demais faz as frases com caminho acordarem.
- **[Ideia 3](03_piscada.md):** o efeito de piscada a cada hit.
