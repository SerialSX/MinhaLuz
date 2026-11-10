# Ideia 3: A piscada a cada hit

| | |
|---|---|
| **Status** | Aprovada |
| **Área** | Mecânica / feedback visual |
| **Fases** | 1, 2 e 3 |

## Resumo

Quando uma frase ruim acerta a menina, ela pisca e **a tela inteira simula a piscada**, como se o jogador fechasse os olhos junto com ela. Quanto mais perto do fim da luz, mais vezes ela pisca. É um aviso que se sente, sem número nem barra de vida.

## Por que combina com o tema

Uma frase ruim dói, e a gente "fecha os olhos" para ela. As piscadas que aumentam mostram o cansaço crescendo, de um jeito que até uma criança de 4 anos entende sem ler nada.

## Regras

O número de piscadas depende de **quantos hits ainda cabem na luz** depois do hit (luz restante ÷ dano, arredondado para cima):

| Hits restantes | Piscadas | Com luz cheia, é o... |
|---|---|---|
| 3 ou mais | 2 | 1º hit (luz 75) |
| 2 | 3 | 2º hit (luz 50) |
| 1 (o próximo é o último) | 4 | 3º hit, o penúltimo (luz 25) |
| 0 | Game over | 4º hit |

Contar pela luz restante, e não pelo número do hit, mantém as piscadas certas mesmo quando a menina pega frases boas no meio.

## Como é a piscada

- A tela escurece de cima para baixo e de baixo para cima, como **pálpebras fechando**, e abre de novo.
- Cada piscada dura cerca de **0,5 s** (fechar, ficar fechado, abrir).
- Tudo acontece dentro dos **5 segundos de proteção** depois do hit (ver [Ideia 2](02_frases_ruins.md)). Mesmo 4 piscadas levam só uns 2 segundos.
- A menina também pisca (fica semitransparente e volta) durante os 5 segundos de proteção.

## Cuidados (jogo infantil e acessibilidade)

- **Nada de clarões.** A piscada é escurecer e voltar, nunca flash branco.
- **No máximo 2 piscadas por segundo.** Efeitos piscando mais de 3 vezes por segundo podem causar crises em pessoas com epilepsia fotossensível.
- Vale ter uma opção no menu **Config** para reduzir ou desligar o efeito.

## Como fazer no Godot 4 (esboço)

Um `CanvasLayer` por cima do jogo com dois `ColorRect` pretos (pálpebra de cima e de baixo), animados com `Tween`:

```gdscript
# piscada.gd, no CanvasLayer
@onready var cima: ColorRect = $Cima
@onready var baixo: ColorRect = $Baixo
const DURACAO := 0.5

func piscar(vezes: int) -> void:
	var meia: float = get_viewport().get_visible_rect().size.y / 2.0
	for i in vezes:
		var t := create_tween().set_parallel(true)
		t.tween_property(cima, "size:y", meia, DURACAO * 0.4)
		t.tween_property(baixo, "size:y", meia, DURACAO * 0.4)
		t.tween_property(baixo, "position:y", meia, DURACAO * 0.4)
		await t.finished
		await get_tree().create_timer(DURACAO * 0.2).timeout
		t = create_tween().set_parallel(true)
		t.tween_property(cima, "size:y", 0.0, DURACAO * 0.4)
		t.tween_property(baixo, "size:y", 0.0, DURACAO * 0.4)
		t.tween_property(baixo, "position:y", meia * 2.0, DURACAO * 0.4)
		await t.finished

func piscadas_para(luz: float, dano: float) -> int:
	var restantes := int(ceil(luz / dano))
	if restantes >= 3:
		return 2
	if restantes == 2:
		return 3
	return 4
```

Antes da primeira piscada, `Baixo` começa com `position.y` igual à altura da tela e `size.y` zero; `Cima` começa em `position.y` zero e `size.y` zero.

## Ligação com outras ideias

- **[Ideia 1](01_luz_diminui.md):** usa a mesma luz (máximo 100).
- **[Ideia 2](02_frases_ruins.md):** o dano de 25 por frase ruim faz caberem exatamente 4 hits na luz cheia.
