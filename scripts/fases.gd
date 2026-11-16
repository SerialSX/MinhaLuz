class_name DadosFases
extends RefCounted
## Dados das 3 fases (campo, escola e beco) e o banco oficial de frases (SGDD).
## Quem monta a fase é scripts/fase.gd, usando DadosFases.FASES[Jogo.fase_atual].

## Pares [ruim, boa que responde]. Pegar a boa dissolve as ruins do mesmo par.
## Sem xingamentos: público de 4 a 13 anos.
const PARES := [
	["Você não consegue", "Eu consigo tentar de novo"],
	["Desiste logo", "Cada passo conta"],
	["Ninguém liga", "Tem gente que gosta de mim"],
	["Você sempre erra", "Errar faz parte de aprender"],
	["Isso é difícil demais", "Pedir ajuda é coragem"],
	["Não vai dar certo", "Sempre há algo bom"],
	["Pra que tentar?", "Eu sou mais forte do que penso"],
	["Você está só", "Eu não estou só"],
	["Ninguém vai notar", "Meus sentimentos importam"],
	["Melhor nem falar", "Minha voz importa"],
	["Você nunca vai mudar", "Eu posso crescer"],
	["Não é bom o suficiente", "Eu tenho valor do jeito que sou"],
]

const TAMANHO_MAPA := Vector2(1536, 864)

## Cada fase:
## - "pares": índices em PARES (4 por fase = 4 frases boas).
## - "ruins": quantas frases ruins de cada tipo (Ideia 2). Os textos repetem os 4 pares.
## - "caminho": tamanho dos caminhos das frases "com caminho", em pixels.
## - "queda": multiplicador da queda da luz (Ideia 1).
## - "tom": cor do CanvasModulate (o mundo apagado; na vitória vai para branco).
## - "obstaculos" (com colisão) e "decoracao" (sem colisão): grupos de sprites em
##   assets/sprites/<pasta>/<melancolica|original>/<nome>_NN_nativa.png, NN de 1 até "variantes".
##   "z" 10 = desenhado acima da menina (copas, plantas, postes); -5 = no chão, embaixo de tudo.
## Sprite faltando é pulado: o jogo roda mesmo sem a arte nova.
const FASES := [
	{
		"nome": "O Campo",
		"subtitulo": "Um lugar aberto e calmo para começar.",
		"musica": "fase1",
		"chao": "res://assets/texturas/grama/grama_tile_nativa.png",
		"tom": Color(0.8, 0.8, 0.85),
		"queda": 1.0,
		"pares": [0, 1, 2, 3],
		"ruins": {"parada": 3, "errante": 3, "caminho": 0},
		"caminho": 0.0,
		"obstaculos": [
			{"pasta": "casas", "nome": "casa", "variantes": 16, "qtd": 8},
		],
		"decoracao": [
			{"pasta": "arvores", "nome": "arvore", "variantes": 9, "qtd": 18, "z": 10},
		],
	},
	{
		"nome": "A Escola",
		"subtitulo": "Mesmo com tanta gente, dá para achar a sua luz.",
		"musica": "fase2",
		"chao": "res://assets/texturas/escola/piso_tile_nativa.png",
		"tom": Color(0.72, 0.74, 0.82),
		"queda": 1.4,
		"pares": [4, 5, 6, 7],
		"ruins": {"parada": 3, "errante": 3, "caminho": 2},
		"caminho": 90.0,
		"obstaculos": [
			{"pasta": "escola", "nome": "carteira", "variantes": 3, "qtd": 6},
			{"pasta": "escola", "nome": "armario", "variantes": 2, "qtd": 4},
			{"pasta": "escola", "nome": "estante", "variantes": 2, "qtd": 4},
		],
		"decoracao": [
			{"pasta": "escola", "nome": "planta", "variantes": 2, "qtd": 8, "z": 10},
		],
	},
	{
		"nome": "O Beco",
		"subtitulo": "Apertado e escuro, mas você não está só.",
		"musica": "fase3",
		"chao": "res://assets/texturas/beco/chao_tile_nativa.png",
		"tom": Color(0.62, 0.6, 0.74),
		"queda": 1.9,
		"pares": [8, 9, 10, 11],
		"ruins": {"parada": 3, "errante": 3, "caminho": 4},
		"caminho": 150.0,
		"obstaculos": [
			{"pasta": "beco", "nome": "lixeira", "variantes": 2, "qtd": 4},
			{"pasta": "beco", "nome": "caixas", "variantes": 3, "qtd": 5},
			{"pasta": "beco", "nome": "muro", "variantes": 2, "qtd": 3},
		],
		"decoracao": [
			{"pasta": "beco", "nome": "poste", "variantes": 1, "qtd": 6, "z": 10},
			{"pasta": "beco", "nome": "poca", "variantes": 2, "qtd": 6, "z": -5},
			{"pasta": "beco", "nome": "gato", "variantes": 1, "qtd": 2},
		],
	},
]
