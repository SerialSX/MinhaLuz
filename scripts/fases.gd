class_name DadosFases
extends RefCounted
## Dados das 3 fases (campo, escola e beco), a dificuldade, o banco oficial de
## frases (SGDD) e os textos da história. Quem monta a fase é scripts/fase.gd,
## usando DadosFases.fase(Jogo.fase_atual) (FASES com a dificuldade escolhida).

## Pares [ruim, boa que responde]. Pegar a boa tira quase toda a névoa das
## crianças que repetem a ruim (fica faltando uma palavra boa para cada uma
## acender) e desfaz as frases ruins soltas do mesmo par.
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

## A frase ruim de cada par, bem curta (mesmo índice de PARES): é a palavra ruim
## que a criança apagada solta, voando, na direção da menina.
const RUINS_CURTAS := [
	"Não consegue!", "Desiste!", "Ninguém liga!", "Sempre erra!", "Difícil demais!", "Não vai dar!",
	"Pra quê?", "Está só!", "Ninguém nota!", "Nem fala!", "Nunca muda!", "Não é bom!",
]

## Palavras boas curtas: a menina responde com elas (voando) e no final da fase.
const PALAVRAS_MENINA := [
	"Eu consigo!", "Eu tento!", "De novo!", "Um passo!", "Posso errar.", "Vai passar.",
	"Coragem!", "Peço ajuda!", "Eu importo!", "Minha voz!", "Eu cresço!", "Tenho valor!",
	"Não estou só!",
]
## Palavras das amigas (crianças que acenderam). A primeira fala é sempre "Desculpa!".
const PALAVRAS_AMIGAS := [
	"Você consegue!", "Estou com você!", "Eu me importo!", "Conta comigo!", "Você é legal!", "Juntos!",
]
## Folhas de personagem em assets/sprites/personagens/<tipo>_{apagada,cor}_folha_nativa.png.
const TIPOS_CRIANCA := ["menino_bone", "menina_rabo", "menino_cacheado", "menina_coque", "crianca_capuz"]

## Dificuldade (Jogo.config["dificuldade"]: 0, 1 ou 2). O Normal é o jogo como foi
## pensado; as outras ajustam os números da fase, sempre na ordem [Fácil, Normal, Difícil].
const DIFICULDADES := ["Fácil", "Normal", "Difícil"]
const MULTIPLICAR := {
	"dano": [0.6, 1.0, 1.8],
	"ritmo_fala": [1.4, 1.0, 0.8],
	"aviso_fala": [1.4, 1.0, 0.85],
	"vel_palavra": [0.8, 1.0, 1.1],
	"passo": [0.8, 1.0, 1.15],
	"queda": [0.7, 1.0, 1.3],
}
const SOMAR := {
	"nevoa_crianca": [-2, 0, 3],
	"acordadas": [-1, 0, 1],
}
const MINIMOS := {"nevoa_crianca": 3, "acordadas": 1, "aviso_fala": 0.4}
const LUZ_MIN := [40.0, 30.0, 20.0]   # a luz que cai sozinha para aqui (a fase põe na menina)
const RESPIROS := [-1, -1, 2]         # vezes que dá para respirar em cada fase (-1 = sem limite)

## Cartões da história depois da última fase (2 linhas cada).
const HISTORIA_FINAL := [
	"A névoa foi embora. As cores voltaram!\nA luz estava nela o tempo todo.",
	"Às vezes a névoa volta. Tudo bem.\nFicar triste faz parte.",
	"Quando pesar, lembre das palavras boas\ne fale com alguém em quem você confia.",
]

## Cada fase:
## - "mapa": tamanho em pixels. "dano": luz que um hit tira.
## - "ditas": pares que as crianças apagadas repetem; "criancas": quantas por par.
##   A frase boa de um par dito fica na área das crianças dele.
## - "nevoa_crianca": pontos de névoa em cima de cada criança apagada (palavras boas
##   que ela precisa ouvir para acender).
## - "ritmo_fala": de quantos em quantos segundos a criança solta uma palavra ruim com
##   a menina por perto; "aviso_fala": segundos de aviso antes de soltar;
##   "vel_palavra": px/s da palavra ruim voando (a menina anda a 90).
## - "pensadas": pares das frases ruins soltas (seguidoras); "seguidoras": quantas por par.
## - "acordadas": máximo de seguidoras acordadas ao mesmo tempo; "passo": px/s do passinho.
## - "iscas": trilhas de vaga-lumes que não levam a uma frase boa.
## - "final_palavras": palavras ruins no final da fase; "frase_chave": a que fecha o final.
## - "refugio": lugar seguro da fase ({} = nenhum): sprite em "pasta"/"tipo", "qtd",
##   "acende_perto" (px; 0 = já nasce aceso), "cura" (luz por segundo dentro dele) e "z".
## - "historia": cartões mostrados antes da fase (2 linhas cada).
## - "queda": multiplicador da queda da luz (Ideia 1).
## - "tom": cor do CanvasModulate (o mundo apagado; com as 4 frases vai para branco).
## - "nevoa_clara": quanto a névoa clareia com as frases boas (0 a 1). No beco é menos:
##   o chão é escuro, e a bolha tem que continuar mais clara que a névoa.
## - "obstaculos" (com colisão) e "decoracao" (sem colisão): grupos de sprites em
##   assets/sprites/<pasta>/<melancolica|original>/<nome>_NN_nativa.png, NN de 1 até "variantes".
##   "z" 10 = desenhado acima da menina (copas, plantas); -5 = no chão, embaixo de tudo.
## Sprite faltando é pulado: o jogo roda mesmo sem a arte.
const FASES := [
	{
		"nome": "O Campo",
		"subtitulo": "Siga os vaga-lumes.",
		"musica": "fase1",
		"chao": "res://assets/texturas/grama/grama_tile_nativa.png",
		"tom": Color(0.8, 0.8, 0.85),
		"nevoa_clara": 0.4,
		"queda": 1.0,
		"mapa": Vector2(1152, 648),
		"dano": 15.0,
		"ditas": [0, 3],
		"criancas": [1, 1],
		"pensadas": [1, 2],
		"seguidoras": [2, 1],
		"acordadas": 2,
		"passo": 50.0,
		"nevoa_crianca": 6,
		"ritmo_fala": 1.8,
		"aviso_fala": 0.6,
		"vel_palavra": 75.0,
		"iscas": 0,
		"final_palavras": 10,
		"frase_chave": "Eu consigo!",
		"refugio": {},
		"historia": [
			"Um dia, uma névoa cobriu tudo.\nAs cores sumiram e as luzes apagaram.",
			"Quem ficou sem luz começou a repetir\nas palavras ruins da névoa.",
			"Mas a luz da menina ainda brilhava.\nVamos ajudar a achar as palavras boas?",
		],
		"obstaculos": [
			{"pasta": "casas", "nome": "casa", "variantes": 16, "qtd": 5},
		],
		"decoracao": [
			{"pasta": "arvores", "nome": "arvore", "variantes": 9, "qtd": 11, "z": 10},
		],
	},
	{
		"nome": "A Escola",
		"subtitulo": "O banco da amizade é um lugar seguro.",
		"musica": "fase2",
		"chao": "res://assets/texturas/escola/piso_tile_nativa.png",
		"tom": Color(0.72, 0.74, 0.82),
		"nevoa_clara": 0.35,
		"queda": 1.4,
		"mapa": Vector2(1344, 756),
		"dano": 20.0,
		"ditas": [7, 5],
		"criancas": [2, 2],
		"pensadas": [4, 6],
		"seguidoras": [3, 2],
		"acordadas": 3,
		"passo": 58.0,
		"nevoa_crianca": 7,
		"ritmo_fala": 1.5,
		"aviso_fala": 0.5,
		"vel_palavra": 85.0,
		"iscas": 1,
		"final_palavras": 14,
		"frase_chave": "Eu não estou só!",
		"refugio": {"pasta": "escola", "tipo": "banco", "qtd": 2, "acende_perto": 0.0, "cura": 4.0, "z": 0},
		"historia": [
			"O campo ganhou cor de novo!\nE a menina não anda mais sozinha.",
			"Na escola, a névoa ainda fala alto.\nVamos levar a luz até lá?",
		],
		"obstaculos": [
			{"pasta": "escola", "nome": "carteira", "variantes": 3, "qtd": 5},
			{"pasta": "escola", "nome": "armario", "variantes": 2, "qtd": 3},
			{"pasta": "escola", "nome": "estante", "variantes": 2, "qtd": 3},
		],
		"decoracao": [
			{"pasta": "escola", "nome": "planta", "variantes": 2, "qtd": 6, "z": 10},
		],
	},
	{
		"nome": "O Beco",
		"subtitulo": "Acenda os postes!",
		"musica": "fase3",
		"chao": "res://assets/texturas/beco/chao_tile_nativa.png",
		"tom": Color(0.62, 0.6, 0.74),
		"nevoa_clara": 0.18,
		"queda": 1.9,
		"mapa": Vector2(1344, 756),
		"dano": 25.0,
		"ditas": [10, 11],
		"criancas": [3, 2],
		"pensadas": [8, 9],
		"seguidoras": [4, 3],
		"acordadas": 4,
		"passo": 66.0,
		"nevoa_crianca": 8,
		"ritmo_fala": 1.2,
		"aviso_fala": 0.5,
		"vel_palavra": 95.0,
		"iscas": 2,
		"final_palavras": 18,
		"frase_chave": "Eu tenho valor!",
		"refugio": {"pasta": "beco", "tipo": "poste", "qtd": 6, "acende_perto": 28.0, "cura": 0.0, "z": 10},
		"historia": [
			"A escola se encheu de vozes boas.\nPedir ajuda foi um ato de coragem.",
			"Falta o beco, o lugar mais apertado.\nMas agora ela tem amigos por perto.",
		],
		"obstaculos": [
			{"pasta": "beco", "nome": "lixeira", "variantes": 2, "qtd": 3},
			{"pasta": "beco", "nome": "caixas", "variantes": 3, "qtd": 4},
			{"pasta": "beco", "nome": "muro", "variantes": 2, "qtd": 3},
		],
		"decoracao": [
			{"pasta": "beco", "nome": "poca", "variantes": 2, "qtd": 5, "z": -5},
			{"pasta": "beco", "nome": "gato", "variantes": 1, "qtd": 2},
		],
	},
]


## Uma cópia de FASES[indice] com a dificuldade escolhida: os números multiplicados
## (MULTIPLICAR) ou somados (SOMAR), sem passar dos MINIMOS, e mais "luz_min" e
## "respiros". No Normal os números são os de FASES, sem mudar nada.
static func fase(indice: int) -> Dictionary:
	var nivel: int = Jogo.config["dificuldade"]
	var dados: Dictionary = FASES[indice].duplicate(true)
	for chave: String in MULTIPLICAR:
		dados[chave] *= MULTIPLICAR[chave][nivel]
	for chave: String in SOMAR:
		dados[chave] += SOMAR[chave][nivel]
	for chave: String in MINIMOS:
		dados[chave] = max(dados[chave], MINIMOS[chave])
	dados["luz_min"] = LUZ_MIN[nivel]
	dados["respiros"] = RESPIROS[nivel]
	return dados
