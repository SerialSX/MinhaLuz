# Tarefa 03: O campo

| | |
|---|---|
| **Status** | A fazer |
| **Depende de** | Tarefa 02 |
| **Ideia de origem** | Protótipo da fase 1 (fase 1: campo) |

## Objetivo

Uma cena de campo com grama no chão, algumas casas e árvores, e a menina andando por ela.

## Arquivos

- **Usar:**
  - `assets/texturas/grama/grama_tile_nativa.png` (192×96, repete sem emenda)
  - `assets/sprites/casas/melancolica/casa_NN_nativa.png`
  - `assets/sprites/arvores/melancolica/arvore_NN_nativa.png`
  - `cenas/menina.tscn`
- **Criar:** `cenas/campo.tscn`

Usar as versões **melancólicas**: o visual alvo (a prévia do Lauan) tem o mundo apagado dentro da bolha.

## Passos

1. Criar `cenas/campo.tscn`:
   ```
   Campo (Node2D)
   ├── Chao (Sprite2D)
   ├── Casas (Node2D)
   │   └── Casa1 (StaticBody2D) ─ Sprite2D + CollisionShape2D (retângulo)
   │   └── ... (umas 5 ou 6 casas)
   ├── Arvores (Node2D)
   │   └── ... (umas 10 árvores, Sprite2D, sem colisão)
   └── Menina (instância de cenas/menina.tscn)
   ```
2. **Chão:** `Sprite2D` com a grama, `centered = false`, `region_enabled = true`, `region_rect = Rect2(0, 0, 1536, 864)` e **Texture → Repeat = Enabled**. A grama cobre um mapa de 1536×864.
3. **Casas:** espalhar 5 ou 6 casas diferentes. Cada uma é um `StaticBody2D` com o sprite e uma colisão retangular do tamanho do telhado, para a menina não atravessar.
4. **Árvores:** espalhar umas 10. Sem colisão. Colocar `z_index = 10` nas árvores: a menina passa **por baixo** da copa (visão de cima).
5. **Menina:** no meio do mapa. Na `Camera2D` dela, limitar a câmera ao mapa: `limit_left = 0`, `limit_top = 0`, `limit_right = 1536`, `limit_bottom = 864`.
6. Definir `campo.tscn` como a **cena principal** do projeto.

## Como conferir

- [ ] F5 abre o campo com a grama sem linhas de emenda.
- [ ] A menina não atravessa as casas.
- [ ] A menina passa por baixo das árvores (a copa fica por cima dela).
- [ ] A câmera não mostra nada fora do mapa nas bordas.
- [ ] Tudo nítido, com o mesmo tamanho de "pixel".

## Fora do escopo

- Luz e névoa (tarefa 04): por enquanto o campo fica todo visível.
- Mapa gerado sozinho a cada partida (fica para depois do protótipo).

## Ao terminar

- Status: **Feito**.
- Mensagem de commit sugerida: `Adiciona a cena do campo com casas e árvores`
