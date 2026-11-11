# Tarefa 01: Configurar o projeto Godot

| | |
|---|---|
| **Status** | A fazer |
| **Depende de** | Projeto criado pelo Godot na pasta `MinhaLuz` (passo manual da equipe) |
| **Ideia de origem** | Protótipo da fase 1 |

## Objetivo

Deixar o projeto Godot 4 pronto para pixel art: resolução pequena com escala inteira, filtro Nearest, controles WASD e setas, e pastas organizadas.

## Antes da tarefa (manual, pela equipe)

1. Abrir o Godot 4 → **Novo Projeto** → pasta: a raiz do repositório `MinhaLuz` (onde está o `README.md`).
2. Renderizador: **Compatibilidade** ou **Mobile** (mais leve; serve bem para 2D).
3. Controle de versão: **Git** (o Godot cria o `.gitignore` e o `.gitattributes`).

## Arquivos

- **Usar:** `project.godot` (criado pelo Godot).
- **Criar:** pastas `cenas/`, `scripts/`, `shaders/` e o arquivo `referencias/.gdignore`.

## Passos

1. **Configurações do projeto** (Projeto → Configurações do Projeto):
   - `display/window/size/viewport_width` = **480**
   - `display/window/size/viewport_height` = **270**
   - `display/window/size/window_width_override` = **1440**
   - `display/window/size/window_height_override` = **810**
   - `display/window/stretch/mode` = **viewport**
   - `display/window/stretch/scale_mode` = **integer**
   - `rendering/textures/canvas_textures/default_texture_filter` = **Nearest**
2. **Mapa de entrada** (Projeto → Configurações do Projeto → Mapa de Entrada). Criar as ações, cada uma com a tecla WASD e a seta:
   - `mover_cima`: W e ↑
   - `mover_baixo`: S e ↓
   - `mover_esquerda`: A e ←
   - `mover_direita`: D e →
3. Criar as pastas `cenas/`, `scripts/` e `shaders/` na raiz.
4. Criar um arquivo **vazio** `referencias/.gdignore`. Assim o Godot não importa as imagens de referência, que são grandes e não vão para o jogo.
5. Conferir se o `.gitignore` ignora a pasta `.godot/`.

## Como conferir

- [ ] O projeto abre sem erros.
- [ ] Em `assets/sprites/personagem/menina_folha_nativa.png`, o painel Importar mostra filtro **Nearest** (ou "padrão do projeto").
- [ ] A pasta `referencias/` não aparece mais no painel Sistema de Arquivos do Godot.
- [ ] Rodando uma cena vazia (F6), a janela abre em 1440×810.

## Fora do escopo

- Criar cenas ou scripts do jogo (isso é das próximas tarefas).
- Mexer nos arquivos de `assets/`, `Ideias/` ou `docs/`.

## Ao terminar

- Status: **Feito**.
- Mensagem de commit sugerida: `Configura o projeto Godot para pixel art`
