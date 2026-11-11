# Minha Luz: visão geral

Este documento é o que **toda conversa do projeto precisa saber**. Os detalhes de cada mecânica ficam nos arquivos da pasta `Ideias/`.

## O jogo

- **Nome:** Minha Luz.
- **Tipo:** jogo 2D educativo, feito em **Godot 4**.
- **Visão:** **100% de cima** (top-down).
- **Público:** crianças de **4 a 13 anos**.
- **Tema:** pensamentos negativos e positivos. Nasceu do tema da depressão ("a mente de uma pessoa depressiva"), adaptado para crianças: sem pesar, sem assustar, sempre com esperança.
- **Controles:** WASD ou setas para andar, Esc para pausar.

## A ideia central

Uma criança está sozinha num mundo escuro e só enxerga o que está dentro da **sua bolha de luz**. Essa luz é o **emocional dela**: é ao mesmo tempo a vida e o campo de visão.

- **Frases boas** brilham no escuro. Encostar nelas aumenta a luz.
- **Frases ruins** tiram luz quando encostam na menina.
- **Se a luz chegar a zero, é game over.** A mensagem do game over encoraja: *"Você sempre pode recomeçar e tentar novamente."*
- **Objetivo:** juntar frases boas para dissipar a **nuvem escura** no fim de cada fase.
- **São 3 fases**, cada uma com um mapa novo a cada partida. Ao dissipar a última nuvem, **o mundo inteiro se ilumina**.

## As fases

| Fase | Ambiente | Sensação | Dificuldade |
|---|---|---|---|
| 1 | Campo | Aberto, calmo, natural | Bem suave |
| 2 | Escola | Pessoas, cobrança, comparação | Média |
| 3 | Beco | Fechado, apertado, sozinho | Maior |

A dificuldade sobe junto com o ambiente: do aberto para o fechado, como o sentimento apertando.

## A personagem

- **Menina**, vista 100% de cima.
- **Cabelo** marrom-escuro, longo, em **duas maria-chiquinhas**, com elásticos amarelos.
- **Roupa azul desbotada.**
- **O que brilha é a bolha de visão** (o círculo de luz em volta dela), que representa o coração e a sanidade dela. Ela não carrega lanterna: a luz vem de dentro.

## Mecânicas aprovadas (resumo)

| # | Mecânica | Em uma linha | Arquivo |
|---|---|---|---|
| 1 | A luz diminui sozinha | Cai devagar com o tempo, mais rápido parada e mais devagar andando, e mais rápido a cada fase. **Nunca apaga sozinha**: para num mínimo | `Ideias/01_luz_diminui.md` |
| 2 | Frases ruins | Três tipos: **parada**, **errante** (lenta) e **com caminho** (só anda quando a menina está no último hit). **Nenhuma persegue de verdade** | `Ideias/02_frases_ruins.md` |
| 3 | A piscada | A cada hit a menina pisca e a tela escurece como pálpebras: 2, 3 e 4 piscadas conforme a luz acaba | `Ideias/03_piscada.md` |

**Números-base:** luz máxima 100; cada frase ruim tira 25 (4 hits a partir da luz cheia); a queda natural para em 15.

## Arte

- **Pixel art**, com todos os elementos na **mesma grade de blocos** (a grama é a referência).
- **Contorno escuro** de 1 bloco nos sprites e **luz vindo de cima à esquerda**.
- **Duas versões de cor** para casas e árvores: **original** (viva) e **melancólica** (desbotada). Ideia: o mundo recupera a cor conforme a menina se recupera.
- **Sprites com fundo transparente**, separados do chão.
- **Texturas que repetem sem emenda** (grama e névoas).
- No Godot, toda textura usa **filtro Nearest**.

## Glossário

| Termo | Significado |
|---|---|
| **Luz** | A vida e o emocional da menina, de 0 a 100 |
| **Bolha** (de visão ou de luz) | O círculo em volta da menina onde dá para ver o mundo. O tamanho acompanha a luz |
| **Frase boa** | Frase positiva que brilha no escuro. Aumenta a luz |
| **Frase ruim** | Frase negativa. Tira luz quando encosta na menina |
| **Hit** | Quando uma frase ruim encosta na menina |
| **Último hit** | Quando mais um hit apagaria a luz |
| **Nuvem escura** | O desafio do fim de cada fase, dissipado com frases boas |
| **Original / melancólica** | As duas versões de cor dos sprites: viva e desbotada |
| **Grade / bloco** | O "pixel" da arte. Todos os elementos usam a mesma grade |

## Regras fixas

1. **Nada que assuste demais.** O público começa nos 4 anos: sem sustos repentinos, sem clarões e sem perseguição de verdade.
2. **Acessibilidade:** efeitos de piscar com no máximo 2 piscadas por segundo e opção para desligar no menu.
3. **Nomes de arquivo** em minúsculo, sem acento e sem espaço (`casa_01_original.png`).
4. **Commit e push são sempre feitos pelas pessoas da equipe.** O Claude escreve arquivos e comandos, mas não envia nada sozinho.
5. **Decisão tomada numa conversa precisa virar arquivo** (em `Ideias/` ou `docs/`) e ir para o repositório. Só assim as outras conversas ficam sabendo.

## Organização do repositório

```
MinhaLuz/
  README.md
  Ideias/          uma ideia aprovada por arquivo (01_, 02_, ...)
  docs/            documentos gerais (esta visão geral, fluxo de trabalho)
  assets/
    texturas/      grama/ e nevoa/
    sprites/       casas/, arvores/ e personagem/
  referencias/     imagens originais, rascunhos e testes
```

O trabalho está na branch **`Texturas`**.

## Conversas do projeto

Cada conversa tem **uma função só**:

| Conversa | Função |
|---|---|
| Ideias e mecânicas | Discutir e escrever as próximas ideias |
| Arte | Sprites, texturas e fases. As imagens ficam só nela |
| Planejamento | Decidir o que fazer e em que ordem |
| Revisão | Comparar o que foi feito com as ideias |
