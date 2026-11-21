# Estado atual

**Atualizado em:** 21/11/2026 (sábado).

Atualize este arquivo a cada segunda e quarta, junto com a apresentação de atualização.

## Branches

- `Prototipo`: protótipo 1, só a fase 1 (11/11).
- `Prototipo2`: protótipo 2, o jogo completo com 3 fases (16 a 18/11).
- `Prototipo3`: ajustes do controle de ESP32 e créditos (19/11).
- `Prototipo4`: protótipo 4, descrito abaixo (20/11). Build `build/MinhaLuz.exe` (versão 0.7). Em 21/11 o Lauan jogou e aprovou a dificuldade, o Respirar e a animação, e decidiu que as amigas ficam no lugar.

## Pronto (Protótipo 4)

Resposta à apresentação para crianças ("o jogo está parado"). As decisões estão em `docs/decisoes.md`, seção Protótipo 4.

- [x] Crianças apagadas que andam e falam as frases ruins (5 personagens novos), e que viram amigas e ficam acenando no lugar.
- [x] Combate de palavras: a criança solta palavras ruins que é preciso desviar, e a menina responde com palavras boas até ela pedir desculpas.
- [x] Animação com mais quadros (4 parada, 8 andando) em 16 direções para a menina e as crianças: viram suave, e o passo continua ao virar e acompanha a velocidade.
- [x] Frases ruins soltas que seguem a menina de pouquinho em pouquinho.
- [x] Vaga-lumes em trilhas, poder Brilhar e Procurar em outro botão.
- [x] A última frase boa deixa o mundo claro; a nuvem escura só aparece depois.
- [x] Final de fase com a menina brilhando e as palavras boas respondendo às ruins.
- [x] Cenas de história antes de cada fase e no fim; tela final com estrelas e recorde.
- [x] Respirar no lugar do game over; 3 estrelas por fase.
- [x] Lugares seguros: bancos da amizade (escola) e postes (beco).
- [x] 9 sons e 2 músicas novos; arte dos personagens, do banco e da nuvem triste.
- [x] Dificuldade no Config (Fácil, Normal e Difícil). No Difícil, 2 respiros por fase; no 3º a luz apaga e uma tela calma oferece recomeçar.
- [x] Segurar o botão continua falando palavras boas; as crianças não falam mais todas ao mesmo tempo.
- [x] Testes automáticos: o jogo inteiro roda do menu à tela final sem erro nas 3 dificuldades, e um robô com 3 jeitos de jogar terminou 27 partidas (3 por dificuldade e jeito) só pelos controles, sem travar.

**Ainda não verificado:** ninguém jogou esta versão de verdade (teclado ou controle), e os sons novos não foram ouvidos.

## Pronto (Protótipo 2)

**Telas**
- [x] Menu inicial (Start, Config, Controles, Sair), seguindo o mockup do time.
- [x] Config: volume da música, volume dos efeitos, tela cheia e opção de desligar a piscada da tela. Fica salvo entre partidas.
- [x] Pausa (Continuar, Menu principal, Sair do jogo), game over, fase concluída e tela final com tempo e pontos.

**Jogo**
- [x] 3 fases: Campo, Escola e Beco, cada uma com mapa sorteado e a nuvem escura no fim.
- [x] Banco de frases do SGDD (12 pares), 4 pares por fase. Pegar uma frase boa dissolve as frases ruins que ela responde.
- [x] Frases ruins paradas, errantes e com caminho (Ideia 2), piscada da tela (Ideia 3) e luz que cai mais rápido a cada fase (Ideia 1).
- [x] Frases boas só aparecem dentro da luz; o poder **Procurar** (Espaço ou botão no HUD) mostra uma seta para a mais perto.
- [x] A cada frase boa pega, a bolha abre e o mundo clareia (tom do cenário e névoa).
- [x] Controle: o jogo aceita gamepad, e o ESP32 vira um controle Bluetooth (`ferramentas/esp32/LEIAME.md`). O firmware ainda não foi gravado num ESP32 de verdade.
- [x] HUD: barra de luz, contador de frases, tempo, frase boa grande no centro e dicas.
- [x] Pontuação: 100 por frase boa + a luz que sobrou no fim de cada fase.
- [x] Envio de pontuação e tempo ao servidor da matéria (tutorial "Score Request"), desligado até existir `config/placar.cfg`.

**Arte e som**
- [x] Arte da escola, do beco, da nuvem escura e ícone do jogo (`ferramentas/arte/`).
- [x] Músicas do menu, das 3 fases, da vitória e do game over, e 10 efeitos sonoros (`ferramentas/audio/`).

**Correções do protótipo 1**
- [x] A menina não sai mais do mapa.
- [x] A frase ruim não acerta de novo a menina parada em cima dela.
- [x] A menina pisca no máximo 2 vezes por segundo na proteção.
- [x] Controles no Mapa de Entrada do projeto.
- [x] A névoa anda para a esquerda.

**Entrega**
- [x] Preset de exportação Windows com o PCK embutido (`export_presets.cfg`, saída em `build/`).
- [x] `.exe` gerado em `build/MinhaLuz.exe` (um arquivo só, com ícone; fica fora do git). Para gerar de novo: Projeto > Exportar > Exportar Projeto.

## Falta

- [ ] Testar o `.exe` no PC da apresentação (no PC do Lauan ele já abre e roda; os templates do Godot 4.7.2 só estão instalados nessa máquina).
- [ ] Pedir à professora o endereço e a chave do servidor e criar `config/placar.cfg` (modelo em `config/placar.exemplo.cfg`).
- [ ] Página no itch.io: capa 630×500, 2 ou 5 prints, gênero Educacional, comentários desligados. Mandar o link para a professora.
- [ ] Revisar com o time o SGDD atualizado para o Protótipo 4 e entregar.
- [ ] Ensaiar no PC da apresentação.
- [ ] Testar o Protótipo 4 com o controle de ESP32: o botão A agora também é o Brilhar, e o B continua sendo o Procurar.
- [ ] Levar o Protótipo 4 para crianças de novo e ver se o "parado" sumiu.
