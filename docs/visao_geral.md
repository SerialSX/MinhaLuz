# Minha Luz: visão geral

Este documento resume **o que toda a equipe precisa saber** sobre o jogo. Os detalhes de cada mecânica ficam nos arquivos da pasta `Ideias/`.

## O jogo

- **Nome:** Minha Luz.
- **Tipo:** jogo 2D educativo, feito em **Godot 4**.
- **Visão:** **100% de cima** (top-down).
- **Público:** crianças de **4 a 13 anos**.
- **Tema:** pensamentos negativos e positivos. Nasceu do tema da depressão ("a mente de uma pessoa depressiva"), adaptado para crianças: sem pesar, sem assustar, sempre com esperança.
- **Controles:** WASD, setas ou joystick para andar; Espaço (botão A) para brilhar; Shift (botão B) para procurar; Esc para pausar.

## A ideia central

Uma criança está sozinha num mundo escuro e só enxerga o que está dentro da **sua bolha de luz**. Essa luz é o **emocional dela**: é ao mesmo tempo a vida e o campo de visão.

A vilã é a **névoa**: ela cobriu o mundo, tirou as cores e apagou a luz das outras crianças.

- **Frases boas** só aparecem dentro da bolha de luz. Encostar nelas aumenta a luz, abre a bolha e clareia o mundo. Uma trilha de **vaga-lumes** leva até cada uma.
- **Crianças apagadas** andam e, de perto, soltam palavras ruins que voam em linha reta: é preciso desviar. A menina responde com **palavras boas** (Espaço ou botão A): cada uma tira um pouco da névoa da criança, até ela pedir desculpas e **acender**. A frase boa do par deixa a criança a uma palavra de acender.
- **Frases ruins soltas** dormem na névoa, acordam quando entram na tela e seguem a menina de pouquinho em pouquinho.
- **Brilho grande** (com 6 vaga-lumes): o próximo aperto limpa as palavras ruins em volta, espanta as frases ruins e tira bastante névoa das crianças.
- **Se a luz acabaria, a menina para e respira.** Não existe game over: ela levanta com luz e segue.
- **A última frase boa da fase** deixa o mundo claro e colorido; a névoa se junta e vira a **nuvem escura**.
- **No final de cada fase**, a menina entra na nuvem e brilha: as palavras ruins são atraídas e as palavras boas dela (e das amigas) respondem uma por uma.
- **São 3 fases**, cada uma com um mapa novo a cada partida, com uma cena de história antes de cada uma.

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
| 2 | Frases ruins | No Protótipo 4: **ditas** por crianças apagadas (de perto, elas soltam palavras ruins voadoras, que é preciso desviar) ou **soltas**, que seguem a menina de pouquinho em pouquinho. Sempre com aviso e sempre visíveis | `Ideias/02_frases_ruins.md` e `docs/decisoes.md` |
| 3 | A piscada | A cada hit a menina pisca e a tela escurece como pálpebras: 2, 3 e 4 piscadas conforme a luz acaba | `Ideias/03_piscada.md` |

**Números-base (Normal):** luz máxima 100; cada frase ruim tira 15, 20 ou 25 (fases 1, 2 e 3); a queda natural para em 30; vaga-lume dá +2 e frase boa +12. A dificuldade do Config (Fácil, Normal, Difícil) muda esses números a partir da próxima fase; a tabela está em `scripts/fases.gd` (`DadosFases.fase()`).

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
| **Bolha** (de visão ou de luz) | O círculo em volta da menina onde dá para ver o mundo. O tamanho acompanha a luz e abre um pouco a cada frase boa pega |
| **Frase boa** | Frase positiva, visível só dentro da luz. Aumenta a luz |
| **Procurar** | Poder (Shift, Q ou botão B): uma seta aponta a frase boa mais perto. Recarrega em 2 s e também liga sozinha |
| **Brilhar** | Poder (Espaço, Enter ou botão A), carregado com 6 vaga-lumes: espanta as frases ruins e faz as crianças apagadas escutarem |
| **Vaga-lume** | Pontinho de luz sempre visível no escuro. Dá luz, pontos e carga do Brilhar |
| **Criança apagada / amiga** | Criança que a névoa deixou sem luz e que repete frases ruins. Acesa pela frase boa do par, vira amiga e segue a menina |
| **Lugar seguro** | Banco da amizade (escola) ou poste aceso (beco): dentro da luz dele, a luz não cai e as frases ruins não entram |
| **Respirar** | O que acontece quando a luz acabaria: a menina para, respira e levanta com luz |
| **Frase ruim** | Frase negativa. Tira luz quando encosta na menina |
| **Hit** | Quando uma frase ruim encosta na menina |
| **Último hit** | Quando mais um hit apagaria a luz |
| **Nuvem escura** | A névoa que se junta depois da última frase boa. Entrar nela começa o final da fase |
| **Original / melancólica** | As duas versões de cor dos sprites: viva e desbotada |
| **Grade / bloco** | O "pixel" da arte. Todos os elementos usam a mesma grade |

## Regras fixas

1. **Nada que assuste demais.** O público começa nos 4 anos: sem sustos repentinos e sem clarões. O que segue a menina é lento, avisa antes e nunca é invisível.
2. **Acessibilidade:** efeitos de piscar com no máximo 2 piscadas por segundo e opção para desligar no menu.
3. **Nomes de arquivo** em minúsculo, sem acento e sem espaço (`casa_01_original.png`).
4. **Commit e push só pela equipe.**
5. **Toda decisão precisa virar arquivo** (em `Ideias/` ou `docs/`) e ir para o repositório. Assim a equipe inteira fica sabendo.

## Organização do repositório

```
MinhaLuz/
  README.md
  Ideias/          uma ideia aprovada por arquivo (01_, 02_, ...)
  docs/            documentos gerais (esta visão geral, fluxo de trabalho)
  Tarefas/         tarefas de programação, uma por arquivo
  cenas/           cenas do Godot (menu, historia, fase, hud, menina, frase, nuvem)
  scripts/         scripts GDScript (jogo, audio e placar são autoloads)
  shaders/         névoa e fundo do menu
  ui/              tema das telas
  config/          modelo do arquivo do servidor de pontuação
  ferramentas/     scripts Python que geram a arte nova e o áudio
  assets/
    texturas/      grama/, nevoa/, escola/ e beco/
    sprites/       casas/, arvores/, personagem/, personagens/, escola/, beco/ e nuvem/
    audio/         musica/ e sfx/
    ui/            ícones do HUD
  referencias/     imagens originais, rascunhos e testes
```

O jogo mais novo está na branch **`Prototipo4`** (20/11). As branches `Prototipo`, `Prototipo2` e `Prototipo3` guardam as versões anteriores.

## Frentes de trabalho

| Frente | O que inclui |
|---|---|
| Ideias e mecânicas | Discutir e escrever as próximas ideias |
| Arte | Sprites, texturas e fases |
| Planejamento | Decidir o que fazer e em que ordem |
| Revisão | Comparar o que foi feito com as ideias |
