# Registro de decisões

Cada decisão com o **porquê**, para ninguém sugerir de novo o que já foi descartado. Decisão nova entra no fim da lista.

## Jogo e tema

| Data | Decisão | Por quê |
|---|---|---|
| 10/11 | Visão **100% de cima** | Combina com a bolha de visão em volta da personagem |
| 10/11 | Público de **4 a 13 anos** | Jogo educativo para crianças |
| 11/11 | **Três fases: campo, escola e beco** | A dificuldade sobe junto com o ambiente, do aberto para o fechado, como o sentimento apertando |

## Mecânicas

| Data | Decisão | Por quê |
|---|---|---|
| 11/11 | **Lanterna descartada** | A luz é o emocional da menina. Uma lanterna seria uma luz de fora resolvendo um problema de dentro |
| 11/11 | A luz **diminui sozinha**, mas **nunca apaga sozinha** | A tristeza volta quando a gente fica parado, mas o tempo sozinho não derrota ninguém. Evita frustração |
| 11/11 | **Andar** faz a luz cair mais devagar; **ficar parado**, mais rápido | "Se mexer ajuda" |
| 11/11 | Frases ruins **não perseguem de verdade** | Crianças pequenas precisam de perigo previsível. A frase "com caminho" segue uma rota fixa |
| 11/11 | **Sussurro removido** (frase invisível que aparecia de surpresa) | Assustaria crianças de 4 anos |
| 11/11 | Frases ruins andam a **40% da velocidade** da menina | Sempre dá para desviar |
| 11/11 | Dano da frase ruim é **25** (4 hits com a luz cheia) | Fecha com a piscada: 2, 3 e 4 piscadas, e o 4º hit é game over |
| 11/11 | **5 segundos de proteção** depois de um hit | A menina não perde luz várias vezes seguidas |
| 11/11 | A piscada **escurece, nunca clareia**, com no máximo 2 piscadas por segundo | Segurança para pessoas com epilepsia fotossensível |

## Arte

| Data | Decisão | Por quê |
|---|---|---|
| 10/11 | **Pixel art** na mesma grade de blocos da grama | Tudo fica com o mesmo tamanho de "pixel" e combina |
| 10/11 | Texturas **sem emenda** | Repetir como tile no Godot sem linhas aparecendo |
| 10/11 | Casas e árvores em **duas versões: original e melancólica** | O mundo pode recuperar a cor conforme a menina se recupera |
| 10/11 | Só **casas e árvores** do pacote de referência (sem carros, pedras e pisos) | Escolha da equipe |
| 10/11 | **10 casas desenhadas do zero**, além das 6 convertidas | Mais variedade, sem depender de imagem de banco de imagens (licença) |
| 10/11 | Sprites **com fundo transparente**, separados do chão | Montar o cenário livremente no Godot |
| 10/11 | A névoa clara/cinza ficou com o Lauan | Escolha da equipe |
| 11/11 | Menina: **duas maria-chiquinhas marrom-escuras e roupa azul desbotada**, na versão mais "bolinha" | Tem mais cara de criança |
| 11/11 | O que brilha é **a bolha de visão**, não um objeto | Representa o coração e a sanidade da menina |
| 11/11 | Casas e árvores **ampliadas 2× no jogo** (`ESCALA_CENARIO` em `scripts/fase.gd`). **Provisório**: quebra a regra da mesma grade | Desenhadas com ~40 px, ficavam só 2× maiores que a menina (20 px). Redesenhar maiores na mesma grade, se sobrar tempo até o dia 19 |
| 11/11 | Menina com **4 direções**, sem sprite diagonal | Na diagonal ela anda na diagonal e mostra a direção do eixo mais forte. Comum em jogos de pixel art vistos de cima |

## Organização

| Data | Decisão | Por quê |
|---|---|---|
| 10/11 | **Commit e push só pela equipe** | Controle do repositório fica com a equipe |
| 10/11 | Pastas `assets/`, `referencias/`, `Ideias/`, `docs/`; nomes em minúsculo, sem acento e sem espaço | Padrão recomendado para o Godot |

## Protótipo 2

| Data | Decisão | Por quê |
|---|---|---|
| 16/11 | As fases usam o **banco de frases do SGDD**: 4 pares por fase (12 frases boas no jogo) | Texto revisado pela equipe, sem xingamentos |
| 16/11 | **Pegar uma frase boa dissolve as frases ruins do mesmo par** | "Cada frase boa responde a uma ruim" vira mecânica, e o mundo fica mais calmo a cada frase |
| 16/11 | Fase 1: 6 frases ruins; fase 2: 8; fase 3: 10. Frases com caminho só a partir da fase 2 | Dificuldade sobe junto com o ambiente (Ideia 2) |
| 16/11 | **Nuvem escura**: encostar nela sem as 4 frases boas só mostra uma dica, sem dano. Com as 4, ela se dissipa e a fase termina | Desafio do fim de fase sem susto |
| 16/11 | Pontos: **100 por frase boa + a luz que sobrou** no fim de cada fase | Adapta o "50 por vida" do SGDD para a luz de 0 a 100 |
| 16/11 | Endereço e chave do servidor ficam em `config/placar.cfg`, **fora do git** | O repositório é público |
| 16/11 | Janela no **maior múltiplo de 480×270 que cabe na tela** | 1440×810 não cabe num notebook 1366×768 |
| 16/11 | Música, sons e a arte nova (escola, beco, nuvem, ícone) **gerados por código** em `ferramentas/` | Sem dúvida de licença e sem IA generativa; dá para gerar de novo |
| 16/11 | Controles no **Mapa de Entrada** do projeto, não mais criados por código | Funcionam em qualquer cena (menu, F6) |
| 16/11 | **Frases boas só aparecem dentro da bolha de luz** (antes brilhavam através da névoa) | Pedido do Lauan depois de jogar: achar a frase faz parte do jogo |
| 16/11 | Poder **Procurar** (Espaço ou botão no HUD): seta dourada piscando aponta a frase boa mais perto, ou a nuvem com 4/4; dura 3 s e recarrega em 5 s | Sem as frases brilhando de longe, a criança precisa de uma ajuda para se orientar. Pisca 1,5 vez por segundo (regra do time: no máximo 2) |
| 16/11 | **A cada frase boa pega, a bolha abre e o mundo clareia**: o raio cresce até +0,10 da altura da tela com 4/4, o tom do cenário anda até 80% do branco e a névoa escura vira uma névoa lilás clara (continua opaca). A vitória completa: a névoa some e a cor volta | Pedido do Lauan: a recuperação da menina aparece no mundo aos poucos. A parte da luz (vida) continua encolhendo com os hits |
| 18/11 | **Controle de ESP32** como gamepad Bluetooth (firmware em `ferramentas/esp32/`), e o jogo aceita qualquer controle: analógico ou direcional anda, X procura, Start pausa, A confirma, B volta | O ESP32 aparece no Windows como um controle comum, sem driver nem código de comunicação no jogo; um controle de Xbox serve de reserva |

## Protótipo 4

Depois de uma apresentação para crianças (19/11), o retorno foi: **o jogo está parado, monótono**. O Lauan pediu as mudanças marcadas com (L); o resto saiu de um painel de crítica de design.

| Data | Decisão | Por quê |
|---|---|---|
| 20/11 | (L) **Frases ruins soltas seguem a menina de pouquinho em pouquinho** (agacha, dá um passinho, descansa). Isto troca a regra antiga "nenhuma frase persegue" | Pedido do Lauan. Para continuar sem susto: a frase só acorda quando entra na tela, treme 1 s antes, fica sempre visível por cima da névoa, no máximo 2 / 3 / 4 acordadas por fase, e dorme se a menina sair da tela por 3 s |
| 20/11 | (L) **Crianças apagadas andam e falam as frases ruins.** A vilã é a **névoa**: ela tirou a luz das crianças, que repetem as palavras dela. Nunca escrever "sombra" ou "inimigo" em texto do jogo | Pedido do Lauan (mais personagens). O enquadramento evita a mensagem "os colegas são maus" |
| 20/11 | A fala machuca só dentro de um **círculo desenhado no chão** (40 px), com aviso antes (balão "..." e círculo pontilhado). Ruim = roxo com borda pontuda; bom = dourado redondo | Quem não lê precisa ver o que machuca |
| 20/11 | Pegar a frase boa do par **acende** as crianças do par: elas pedem desculpa, viram **amigas** e seguem a menina em fila (até 3). Cada amiga segura 15% da queda da luz | "Eu não estou só" vira regra de jogo |
| 20/11 | **Vaga-lumes**: sempre visíveis no escuro, em trilhas que levam a cada frase boa. Dão luz, pontos e carga para o poder **Brilhar** (6 vaga-lumes) | Dão sempre um lugar para onde ir: trocam "varrer a névoa" por "seguir luzinhas" |
| 20/11 | **Brilhar** (Espaço, Enter ou botão A) espanta as frases ruins e faz as crianças apagadas escutarem por 8 s. Não desfaz nada | A criança reage em vez de só desviar. Quem resolve é a frase boa do par e o final |
| 20/11 | **Procurar** passou para Shift, Q ou botão B; a seta também liga sozinha depois de 8 s sem pegar nada | O botão principal ficou com o Brilhar |
| 20/11 | (L) **A última frase boa deixa o mundo claro e colorido na hora, e só então a nuvem escura aparece**, dentro da tela: a névoa e as frases que sobraram se juntam e viram a nuvem | Pedido do Lauan. A nuvem deixa de ser um ponto no mapa e vira consequência |
| 20/11 | (L) **Final de fase**: a menina entra na nuvem e brilha; as palavras ruins são atraídas e as palavras boas respondem (a ruim vira a resposta do par e estoura). Apertar o botão fala mais palavras; não dá para perder | Pedido do Lauan. Responder, não brigar |
| 20/11 | (L) **Cenas de história** antes de cada fase e no fim | Pedido do Lauan (cutscene) |
| 20/11 | **Respirar no lugar do game over**: quando a luz acabaria, a menina para, respira 3 vezes e levanta com 50 de luz (custa 50 pontos) | Perder a luz para palavras ruins era a pior mensagem para o tema; respirar ensina a se acalmar |
| 20/11 | Piso da luz que cai sozinha: **30** (era 15). Dano por hit: **15 / 20 / 25** por fase (era 25). Parada, a luz só cai mais rápido depois de 3 s | Com coisas seguindo, a fase 1 não pode derrubar a criança pequena |
| 20/11 | **Lugares seguros**: bancos da amizade na escola (sempre acesos) e postes do beco (acendem quando a menina passa). Dentro da luz deles, a luz não cai e as frases ruins não entram | Um elemento novo por fase, e a mensagem de que existem lugares e pessoas seguros |
| 20/11 | **3 estrelas por fase**: terminou; 60% dos vaga-lumes; 80% das palavras do final respondidas de longe. Recorde salvo | Motivo para jogar de novo, sem punir quem levou hits |
| 20/11 | Mapas menores (1152×648 na fase 1; 1344×756 nas outras) e menina a 90 px/s (era 60) | Primeira vitória mais rápida, menos caminhada vazia |
| 20/11 | (L) **Combate de palavras**: a criança apagada tem névoa (6 / 7 / 8 bolinhas por fase) e, com a menina a menos de 130 px, solta **palavras ruins voadoras** (75 / 85 / 95 px/s), que é preciso desviar. A menina responde com **palavras boas** (Espaço, Enter ou botão A, uma a cada 0,5 s, com mira automática); cada uma tira 1 de névoa, e com zero a criança pede desculpa e acende. Isto troca o círculo de fala no chão | Pedido do Lauan: o jogo estava fácil. As palavras boas tiram a névoa, não machucam a criança; e não desfazem as palavras ruins, senão ficar parado apertando resolveria tudo |
| 20/11 | A **frase boa do par** deixa a névoa da criança em 1 (não acende mais sozinha). Com a carga de 6 vaga-lumes, o aperto vira o **Brilho grande**: limpa as palavras ruins do anel e tira 2 de névoa | A frase boa continua valendo muito, mas o confronto precisa acontecer |
| 20/11 | A fila de amigas fica atrás de uma chave só: `Crianca.AMIGAS_SEGUEM` | O Lauan ainda está avaliando se quer a "equipe" |
| 20/11 | (L) **Animação com mais quadros**: folhas de 240×80 (4 quadros parada, 8 andando) para a menina e as 5 crianças; a menina acelera e para suave, solta poeira e tem sombra | Pedido do Lauan: a personagem parecia um boneco estático |
| 21/11 | **Dificuldade no Config: Fácil, Normal e Difícil**, salva com as outras opções e valendo a partir da próxima fase. O Normal é o jogo de antes, sem mudar nada. Os números ficam num lugar só (`DadosFases.fase()` em `scripts/fases.gd`): o Fácil tira menos luz, as crianças têm menos névoa e falam mais devagar, e a luz não cai abaixo de 40; o Difícil tira mais luz (×1,8), dá mais névoa às crianças (+3), elas falam mais rápido, e a luz cai até 20 | O Lauan achou o jogo fácil, mas o público vai de 4 a 13 anos. A escolha atende os dois sem piorar o jogo para os pequenos |
| 21/11 | **No Difícil, 2 respiros por fase.** No 3º, a menina respira do mesmo jeito e, no fim, a luz apaga: o mundo para e uma tela calma diz "A luz apagou desta vez. Você sempre pode recomeçar.", com Tentar de novo (volta aos pontos do começo da fase) e Menu principal. No Fácil e no Normal continua sem limite | O Difícil precisa poder perder, senão não é desafio. A respiração vem antes para não cortar o ritual que acalma, e a tela nunca fica preta |
| 21/11 | **Segurar o botão continua falando** (uma palavra boa a cada 0,5 s), e um aperto no fim do intervalo fica guardado | Criança pequena não consegue apertar rápido; ninguém perde a palavra por apertar cedo demais |
| 21/11 | **As crianças não falam todas juntas**: cada uma tem a sua vez na roda das falas (defasagem pela razão áurea), e depois de um hit, do Respirar ou do Brilho elas voltam espalhadas. Palavras ruins que sairiam do mesmo lugar saem 10 px acima ou abaixo e voam lado a lado | Rajadas de palavras ao mesmo tempo são impossíveis de desviar e de ler |
| 21/11 | **O B de qualquer controle procura**: botão 2 (o B do controle de ESP32) e botão 1 (o B de um controle de Xbox) | O jogo mostra "B" para Procurar, e no controle de Xbox o B não fazia nada |
| 21/11 | (L) **As amigas ficam no lugar**: ao acender, a criança fica acenando onde está, em vez de seguir a menina em fila (`Crianca.AMIGAS_SEGUEM = false`). Continuam segurando a queda da luz e ajudando quando ela fica baixa | Decisão do Lauan depois de jogar a build 0.6 |
| 21/11 | (L) **Animação em 16 direções.** Folhas novas `*_folha16_nativa.png` (16 linhas × 12 quadros) geradas por `ferramentas/arte/gerar_arte.py`: as 4 direções de antes iguais pixel a pixel, e as do meio giradas com RotSprite. A menina e as crianças viram suave para onde andam (720°/s, uma direção de cada vez, com histerese para o joystick), o passo não recomeça ao virar, e o ritmo do passo acompanha a velocidade (arrancando e freando, passos mais lentos; crianças andando devagar, passos lentos; de costas, o passo toca para trás). Sem as folhas de 16, o jogo usa as de 4 | O Lauan achou a animação "ainda dura". Vista de cima, a figura virava em saltos de 90°, o passo recomeçava a cada virada e as crianças andavam devagar com passo de corrida |

