# Estado atual

**Atualizado em:** 16/11/2026 (segunda). **Faltam 3 dias** para a apresentação final provável (19/11).

Atualize este arquivo a cada segunda e quarta, junto com a apresentação de atualização.

## Branches

- `Prototipo`: protótipo 1, só a fase 1 (11/11).
- `Prototipo2`: protótipo 2, o jogo completo descrito abaixo (16/11). Ainda não mesclado na `main`.

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
- [ ] Atualizar o SGDD para o jogo atual (luz de 0 a 100, 3 fases, 4 frases por fase, nuvem escura).
- [ ] Ensaiar no PC da apresentação.
