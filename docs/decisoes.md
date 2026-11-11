# Registro de decisões

Cada decisão com o **porquê**, para nenhuma conversa sugerir de novo o que já foi descartado. Decisão nova entra no fim da lista.

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
| 11/11 | Casas e árvores **ampliadas 2× no jogo** (`ESCALA_CENARIO` em `scripts/campo.gd`). **Provisório**: quebra a regra da mesma grade | Desenhadas com ~40 px, ficavam só 2× maiores que a menina (20 px). Redesenhar maiores na mesma grade, se sobrar tempo até o dia 19 |
| 11/11 | Menina com **4 direções**, sem sprite diagonal | Na diagonal ela anda na diagonal e mostra a direção do eixo mais forte. Comum em jogos de pixel art vistos de cima |

## Organização

| Data | Decisão | Por quê |
|---|---|---|
| 10/11 | **Commit e push só pela equipe** | Controle do repositório fica com as pessoas |
| 10/11 | Pastas `assets/`, `referencias/`, `Ideias/`, `docs/`; nomes em minúsculo, sem acento e sem espaço | Padrão recomendado para o Godot |
| 11/11 | Projeto do app do Claude como **Diretor**: Contexto só com o obrigatório e **uma conversa por função** | Funciona de qualquer PC e mantém cada conversa focada |
| 11/11 | **Imagens só na conversa de arte** | Não estourar o limite do Contexto |
