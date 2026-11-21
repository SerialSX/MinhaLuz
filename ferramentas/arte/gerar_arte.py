"""Gera a arte do Protótipo 2 em pixel art: escola, beco, nuvem escura, ícones do HUD e ícone do app.
No Protótipo 4, também o banco da amizade, a carinha triste da nuvem, as crianças (folha colorida
e folha apagada), a folha fluida da menina (parada respirando e 8 quadros de andar), as folhas de 16
direções da menina e das crianças (giradas com RotSprite) e os ícones novos do HUD.

Determinístico (sementes fixas): rodar de novo gera os mesmos PNGs.
Uso (na raiz do repositório): python ferramentas/arte/gerar_arte.py
Precisa só do Pillow.
"""
import math
import random
from collections import Counter
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parents[2]

# Versão "melancolica": ajuste afim por mínimos quadrados feito nos pares
# original -> melancolica das casas e árvores do campo (dessatura, escurece e esfria).
MELANCOLIA = (
    (0.588, 0.084, 0.162, -1.356),
    (0.304, 0.321, 0.173, 2.603),
    (0.305, 0.012, 0.455, 5.668),
)


class Tela:
    def __init__(self, largura, altura):
        self.l, self.a = largura, altura
        self.im = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
        self.px = self.im.load()

    def p(self, x, y, cor):
        if 0 <= x < self.l and 0 <= y < self.a:
            self.px[x, y] = tuple(cor[:3]) + (255,)

    def ret(self, x, y, largura, altura, cor):
        for j in range(y, y + altura):
            for i in range(x, x + largura):
                self.p(i, j, cor)

    def cheio(self, x, y):
        return 0 <= x < self.l and 0 <= y < self.a and self.px[x, y][3] > 0

    def contorno(self, cor, diagonal=True):
        """Contorno de 1 px por fora de tudo que já foi desenhado."""
        viz = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            viz += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        marcar = [(x, y) for y in range(self.a) for x in range(self.l)
                  if not self.cheio(x, y) and any(self.cheio(x + dx, y + dy) for dx, dy in viz)]
        for x, y in marcar:
            self.p(x, y, cor)


def misturar(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def clarear(c, t=0.3):
    return misturar(c, (255, 255, 255), t)


def escurecer(c, t=0.3):
    return misturar(c, (0, 0, 0), t)


def melancolica(im):
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = tuple(max(0, min(255, round(m[0] * r + m[1] * g + m[2] * b + m[3])))
                                 for m in MELANCOLIA) + (a,)
    return out


def salvar(im, caminho):
    destino = RAIZ / caminho
    destino.parent.mkdir(parents=True, exist_ok=True)
    im.save(destino)
    print(f"{caminho}  {im.width}x{im.height}")


def salvar_par(im, pasta, nome):
    salvar(im, f"{pasta}/original/{nome}")
    salvar(melancolica(im), f"{pasta}/melancolica/{nome}")


def esfera(cx, cy, r, x, y, luz=(-0.55, -0.7, 0.45)):
    """Intensidade de luz (0..1) num ponto de uma esfera vista de cima (luz vindo do alto à esquerda)."""
    dx, dy = (x - cx) / r, (y - cy) / r
    d2 = dx * dx + dy * dy
    if d2 > 1:
        return None
    nz = math.sqrt(1 - d2)
    n = math.sqrt(sum(v * v for v in luz))
    return max(0.0, (dx * luz[0] + dy * luz[1] + nz * luz[2]) / n)


# ---------------------------------------------------------------- pisos (1x, sem emenda)

def piso_escola():
    """Tábuas de madeira em fileiras de 8 px, emendas desencontradas."""
    rnd = random.Random(11)
    t = Tela(96, 96)
    tons = [(170, 128, 86), (160, 119, 79), (178, 136, 92), (165, 124, 84)]
    emenda = (98, 67, 46)
    for fileira in range(12):
        y0 = fileira * 8
        juntas = sorted(rnd.sample(range(0, 96, 4), 2))
        if juntas[1] - juntas[0] < 24:
            juntas[1] = (juntas[0] + 40 + rnd.randrange(0, 16, 4)) % 96
        juntas.sort()
        for x in range(96):
            # duas tábuas por fileira; a de fora das juntas dá a volta na borda do tile
            tabua = 1 if juntas[0] <= x < juntas[1] else 0
            base = tons[(fileira * 3 + tabua) % len(tons)]
            for dy in range(8):
                y = y0 + dy
                if dy == 7 or x in juntas:
                    cor = emenda
                elif dy == 0 or (x - 1) % 96 in juntas:
                    cor = clarear(base, 0.12)
                elif dy == 6:
                    cor = escurecer(base, 0.08)
                else:
                    cor = base
                t.p(x, y, cor)
        # veios e pregos
        for _ in range(7):
            x0, dy = rnd.randrange(96), rnd.randrange(2, 6)
            comp = rnd.randrange(4, 12)
            cor = escurecer(tons[0], 0.13) if rnd.random() < 0.7 else clarear(tons[0], 0.1)
            for i in range(comp):
                x = (x0 + i) % 96
                if x not in juntas and (x - 1) % 96 not in juntas:
                    t.p(x, y0 + dy, cor)
        for j in juntas:
            for x in ((j + 2) % 96, (j - 2) % 96):
                t.p(x, y0 + 2, (116, 82, 56))
                t.p(x, y0 + 5, (116, 82, 56))
    return t.im.convert("RGB")


def chao_beco():
    """Paralelepípedos azul-acinzentados escuros, com algumas rachaduras."""
    rnd = random.Random(23)
    t = Tela(96, 96)
    rejunte = (40, 44, 58)
    bases = [(76, 82, 102), (70, 76, 96), (82, 88, 108), (66, 72, 91)]
    for fileira in range(12):
        y0 = fileira * 8
        larguras = []
        while sum(larguras) < 96:
            larguras.append(rnd.choice([10, 12, 12, 14]))
        larguras[-1] -= sum(larguras) - 96
        if larguras[-1] < 6:
            sobra = larguras.pop()
            larguras[-1] += sobra
        desloc = rnd.randrange(96)
        x0 = desloc
        for w in larguras:
            base = rnd.choice(bases)
            for sx in range(w):
                for sy in range(8):
                    x, y = (x0 + sx) % 96, y0 + sy
                    canto = (sx in (0, w - 2)) and (sy in (0, 6))
                    if sx == w - 1 or sy == 7:
                        cor = rejunte
                    elif canto:
                        cor = misturar(base, rejunte, 0.6)
                    elif sy == 0 or sx == 0:
                        cor = clarear(base, 0.1)
                    elif sy == 6 or sx == w - 2:
                        cor = escurecer(base, 0.16)
                    elif rnd.random() < 0.07:
                        cor = escurecer(base, 0.1) if rnd.random() < 0.6 else clarear(base, 0.06)
                    else:
                        cor = base
                    t.p(x, y, cor)
            x0 += w
    rachadura = (34, 37, 49)
    for _ in range(5):
        x, y = rnd.randrange(96), rnd.randrange(96)
        dx = rnd.choice([-1, 1])
        for _ in range(rnd.randrange(7, 14)):
            t.p(x % 96, y % 96, rachadura)
            if rnd.random() < 0.55:
                x += dx
            else:
                y += 1
            if rnd.random() < 0.2:
                dx = -dx
    return t.im.convert("RGB")


# ---------------------------------------------------------------- escola (obstáculos 2x)

MADEIRA = {"brilho": (226, 190, 136), "clara": (204, 164, 110), "media": (176, 134, 86),
           "escura": (150, 108, 68), "sombra": (112, 78, 50)}
CONTORNO_MADEIRA = (52, 34, 30)


def carteira(cadeira, item):
    clara, media, escura = cadeira
    t = Tela(16, 14)
    t.ret(1, 1, 14, 5, MADEIRA["clara"])          # tampo
    t.ret(1, 1, 14, 1, MADEIRA["brilho"])
    t.ret(1, 1, 1, 5, MADEIRA["brilho"])
    t.ret(14, 2, 1, 4, MADEIRA["media"])
    t.ret(1, 6, 14, 1, MADEIRA["escura"])         # frente do tampo
    t.ret(1, 7, 14, 1, MADEIRA["sombra"])
    t.ret(2, 8, 1, 4, (128, 134, 150))            # pernas
    t.ret(13, 8, 1, 4, (100, 106, 122))
    t.ret(4, 8, 8, 2, media)                      # assento
    t.ret(4, 10, 8, 1, clara)                     # topo do encosto
    t.ret(4, 11, 8, 2, escura)                    # frente do encosto
    t.ret(4, 11, 1, 2, media)
    item(t)
    t.contorno(CONTORNO_MADEIRA)
    return t.im


def item_caderno(t):
    t.ret(3, 2, 5, 3, (240, 238, 228))
    t.ret(5, 2, 1, 3, (196, 196, 196))
    t.ret(3, 3, 2, 1, (150, 170, 210))
    t.ret(6, 3, 2, 1, (150, 170, 210))


def item_lapis(t):
    t.ret(3, 2, 3, 3, (240, 238, 228))
    t.ret(3, 3, 3, 1, (210, 210, 206))
    t.p(8, 3, (232, 120, 140))
    t.ret(9, 3, 3, 1, (246, 204, 64))
    t.p(12, 3, (236, 200, 150))


def item_maca(t):
    t.ret(3, 2, 4, 2, (70, 104, 190))
    t.ret(3, 4, 4, 1, (232, 230, 220))
    t.ret(10, 2, 2, 2, (212, 52, 52))
    t.p(10, 2, (244, 120, 108))
    t.p(11, 1, (80, 170, 64))


def armario(cor, adesivo):
    clara, media, escura = clarear(cor, 0.25), cor, escurecer(cor, 0.28)
    t = Tela(15, 22)
    t.ret(1, 1, 13, 3, clara)                     # topo
    t.ret(1, 1, 13, 1, clarear(cor, 0.45))
    t.ret(1, 4, 13, 1, escura)
    t.ret(1, 5, 13, 15, media)                    # portas
    t.ret(7, 5, 1, 15, (30, 32, 48))
    for x0 in (1, 8):
        t.ret(x0, 5, 1, 15, clara)
        t.ret(x0 + 5, 5, 1, 15, escura)
        for y in (7, 9, 11):
            t.ret(x0 + 1, y, 4, 1, escura)
    t.ret(5, 13, 1, 2, (226, 230, 236))           # puxadores
    t.ret(9, 13, 1, 2, (226, 230, 236))
    t.ret(1, 20, 13, 1, escurecer(cor, 0.45))     # rodapé
    if adesivo:   # adesivo de coração
        for x, y in ((9, 15), (11, 15), (9, 16), (10, 16), (11, 16), (10, 17)):
            t.p(x, y, (240, 112, 150))
    t.contorno((30, 32, 48))
    return t.im


LIVROS = [(206, 64, 64), (64, 104, 200), (236, 196, 64), (72, 168, 92), (150, 90, 190),
          (236, 138, 56), (60, 170, 180), (230, 120, 160)]


def estante(semente):
    rnd = random.Random(semente)
    t = Tela(20, 22)
    t.ret(1, 1, 18, 3, MADEIRA["clara"])          # topo
    t.ret(1, 1, 18, 1, MADEIRA["brilho"])
    t.ret(1, 4, 18, 1, MADEIRA["sombra"])
    t.ret(1, 5, 18, 16, MADEIRA["media"])         # frente
    t.ret(1, 5, 1, 16, MADEIRA["clara"])
    t.ret(18, 5, 1, 16, MADEIRA["escura"])
    t.ret(1, 20, 18, 1, MADEIRA["sombra"])
    for topo in (6, 11, 16):                      # nichos com livros
        fundo = topo + 3
        t.ret(2, topo, 16, 4, (78, 52, 36))
        x = 2
        while x < 18:
            w = min(rnd.choice([1, 1, 2]), 18 - x)
            if rnd.random() < 0.12:
                x += w
                continue
            h = rnd.choice([2, 3, 3, 4, 4])
            cor = rnd.choice(LIVROS)
            t.ret(x, fundo - h + 1, w, h, cor)
            t.ret(x, fundo - h + 1, w, 1, clarear(cor, 0.35))
            if w == 2:
                t.ret(x + 1, fundo - h + 2, 1, h - 1, escurecer(cor, 0.2))
            x += w
        t.ret(2, fundo + 1, 16, 1, MADEIRA["escura"])
    t.contorno((44, 28, 22))
    return t.im


FOLHAS = [(46, 108, 46), (70, 148, 56), (104, 184, 72), (150, 214, 96)]
TERRACOTA = {"clara": (222, 130, 84), "media": (190, 100, 62), "escura": (150, 74, 46)}


def vaso(t):
    t.ret(1, 8, 8, 1, TERRACOTA["clara"])
    t.ret(1, 9, 8, 1, TERRACOTA["media"])
    t.ret(2, 10, 6, 3, TERRACOTA["media"])
    t.ret(2, 10, 1, 3, TERRACOTA["clara"])
    t.ret(7, 10, 1, 3, TERRACOTA["escura"])
    t.ret(2, 12, 6, 1, TERRACOTA["escura"])


def planta(tipo):
    rnd = random.Random(31 + tipo)
    t = Tela(10, 14)
    vaso(t)
    if tipo == 1:   # moita redonda
        for y in range(1, 9):
            for x in range(1, 9):
                i = esfera(4.5, 4.6, 4.1, x, y)
                if i is None:
                    continue
                nivel = 0 if i < 0.3 else 1 if i < 0.6 else 2 if i < 0.85 else 3
                if rnd.random() < 0.18:
                    nivel = max(0, nivel - 1)
                t.p(x, y, FOLHAS[nivel])
    else:           # folhas compridas
        for x0, topo, tons in ((1, 4, (1, 0)), (4, 1, (3, 2)), (7, 3, (2, 1))):
            t.ret(x0, topo + 1, 1, 9 - topo, FOLHAS[tons[0]])
            t.ret(x0 + 1, topo + 1, 1, 9 - topo, FOLHAS[tons[1]])
            t.p(x0, topo, FOLHAS[tons[0]])
            t.p(x0 + 1, topo + 3, clarear(FOLHAS[tons[1]], 0.15))
        t.ret(2, 8, 6, 1, FOLHAS[0])
    t.contorno((34, 38, 30), diagonal=False)
    return t.im


AMARELO = {"brilho": (255, 240, 150), "clara": (252, 214, 70), "media": (236, 180, 44),
           "escura": (200, 136, 32), "sombra": (146, 94, 34)}


def banco():
    """Banco da amizade (lugar seguro): madeira pintada de amarelo, com um coração no encosto."""
    t = Tela(24, 15)
    t.ret(2, 1, 20, 1, AMARELO["brilho"])         # topo do encosto
    t.ret(2, 2, 20, 4, AMARELO["media"])          # frente do encosto
    t.ret(2, 2, 1, 4, AMARELO["clara"])
    t.ret(21, 2, 1, 4, AMARELO["escura"])
    for x0 in (3, 16):                            # fresta entre as duas ripas
        t.ret(x0, 3, 5, 1, AMARELO["escura"])
    t.ret(2, 6, 20, 1, AMARELO["sombra"])         # sombra do encosto no assento
    t.ret(1, 7, 22, 4, AMARELO["clara"])          # assento
    t.ret(1, 7, 22, 1, AMARELO["brilho"])
    t.ret(1, 7, 1, 4, AMARELO["brilho"])
    t.ret(2, 9, 20, 1, AMARELO["media"])          # fresta entre as ripas do assento
    t.ret(22, 8, 1, 3, AMARELO["media"])
    t.ret(1, 11, 22, 1, AMARELO["escura"])        # frente do assento
    t.ret(2, 12, 2, 2, AMARELO["sombra"])         # pernas
    t.ret(20, 12, 2, 2, AMARELO["sombra"])
    cores = {"r": (238, 76, 104), "h": (255, 180, 190), "d": (196, 46, 86)}   # as do coração do HUD
    for y, linha in enumerate(("hr..rr", "rrrrrr", ".rrrd.", "..rd.."), 2):
        for x, ch in enumerate(linha, 9):
            if ch in cores:
                t.p(x, y, cores[ch])
    t.contorno(CONTORNO_MADEIRA)
    return t.im


# ---------------------------------------------------------------- beco (obstáculos 2x)

def lixeira(cor, papel):
    tampa, corpo = clarear(cor, 0.2), cor
    t = Tela(11, 14)
    for y, x0, x1 in ((1, 3, 7), (2, 2, 8), (3, 1, 9)):
        t.ret(x0, y, x1 - x0 + 1, 1, tampa)
    t.p(3, 1, clarear(cor, 0.45)); t.p(2, 2, clarear(cor, 0.45)); t.p(1, 3, clarear(cor, 0.45))
    t.p(7, 1, cor); t.p(8, 2, cor); t.p(9, 3, cor)
    t.ret(4, 2, 3, 1, escurecer(cor, 0.35))       # alça
    t.ret(1, 4, 9, 1, escurecer(cor, 0.15))       # borda da tampa
    t.ret(2, 5, 7, 1, escurecer(cor, 0.55))       # sombra sob a tampa
    t.ret(2, 6, 7, 6, corpo)
    t.ret(2, 6, 1, 6, clarear(cor, 0.15))
    for x in (4, 6):
        t.ret(x, 6, 1, 6, escurecer(cor, 0.18))
    t.ret(8, 6, 1, 6, escurecer(cor, 0.3))
    t.ret(2, 12, 7, 1, escurecer(cor, 0.35))
    if papel:
        t.ret(6, 4, 2, 2, (236, 234, 222))
        t.p(7, 5, (200, 198, 188))
    t.contorno((30, 32, 40))
    return t.im


PAPELAO = (186, 138, 84)


def caixa(t, x, y, largura, alt_topo, alt_frente, cor=PAPELAO):
    topo, frente = clarear(cor, 0.22), cor
    meio = x + largura // 2 - 1
    t.ret(x, y, largura, alt_topo, topo)
    t.ret(x, y, largura, 1, clarear(cor, 0.32))
    t.ret(x, y, 1, alt_topo, clarear(cor, 0.32))
    t.ret(meio, y, 2, alt_topo, clarear(cor, 0.45))     # fita
    t.ret(x, y + alt_topo, largura, 1, escurecer(cor, 0.38))
    yf = y + alt_topo + 1
    t.ret(x, yf, largura, alt_frente, frente)
    t.ret(x, yf, 1, alt_frente, clarear(cor, 0.1))
    t.ret(x + largura - 1, yf, 1, alt_frente, escurecer(cor, 0.16))
    t.ret(meio, yf, 2, alt_frente // 2, clarear(cor, 0.2))
    t.ret(x, yf + alt_frente - 1, largura, 1, escurecer(cor, 0.2))


def caixas(tipo):
    contorno = (60, 40, 28)
    if tipo == 1:
        t = Tela(14, 14)
        caixa(t, 1, 1, 12, 5, 6)
    elif tipo == 2:
        t = Tela(16, 21)
        caixa(t, 1, 8, 14, 5, 6)
        caixa(t, 3, 1, 10, 4, 6, (198, 152, 96))
    else:
        t = Tela(20, 19)
        caixa(t, 1, 7, 9, 4, 6)
        caixa(t, 10, 7, 9, 4, 6, (172, 126, 76))
        t.ret(10, 7, 1, 11, contorno)
        caixa(t, 5, 1, 10, 4, 5, (198, 152, 96))
    t.contorno(contorno)
    return t.im


def muro(largura, semente):
    rnd = random.Random(semente)
    t = Tela(largura, 16)
    t.ret(1, 1, largura - 2, 2, (150, 146, 152))   # capa de concreto
    t.ret(1, 1, largura - 2, 1, (176, 172, 178))
    t.ret(1, 3, largura - 2, 1, (92, 88, 98))
    argamassa = (98, 88, 94)
    tijolos = [(160, 84, 70), (148, 76, 64), (172, 96, 78), (154, 90, 74)]
    cores = {}
    for y in range(4, 15):
        linha, dy = divmod(y - 4, 3)
        desloc = 3 if linha % 2 else 0
        for x in range(1, largura - 1):
            dx = (x - 1 + desloc) % 6
            if dy == 2 or dx == 5:
                t.p(x, y, argamassa)
                continue
            chave = ((x - 1 + desloc) // 6, linha)
            if chave not in cores:
                cores[chave] = (120, 62, 54) if rnd.random() < 0.08 else rnd.choice(tijolos)
            base = cores[chave]
            t.p(x, y, clarear(base, 0.12) if dy == 0 else base)
    t.contorno((44, 30, 34))
    return t.im


def poste():
    t = Tela(7, 36)
    cabeca, escuro = (82, 90, 112), (58, 64, 84)
    t.ret(2, 1, 3, 1, (112, 120, 142))
    t.ret(1, 2, 5, 1, cabeca)
    t.ret(1, 3, 1, 3, cabeca)
    t.ret(5, 3, 1, 3, escuro)
    t.ret(2, 3, 3, 1, (255, 246, 206))            # luz
    t.ret(2, 4, 3, 1, (255, 222, 130))
    t.ret(2, 5, 3, 1, (246, 186, 86))
    t.ret(2, 6, 3, 1, escuro)
    t.ret(2, 7, 1, 23, (112, 120, 142))           # haste
    t.ret(3, 7, 1, 23, (86, 94, 116))
    t.ret(4, 7, 1, 23, (62, 68, 88))
    t.ret(2, 30, 3, 1, (112, 120, 142))           # base
    t.ret(1, 31, 5, 3, (86, 94, 116))
    t.ret(1, 31, 1, 3, (112, 120, 142))
    t.ret(5, 31, 1, 3, (62, 68, 88))
    t.ret(1, 34, 5, 1, (54, 60, 78))
    t.contorno((26, 28, 40))
    return t.im


def poca(tipo):
    t = Tela(20, 8)
    agua, funda = (64, 86, 124), (50, 68, 102)
    elipses = [(9.5, 3.5, 8.7, 2.8)] if tipo == 1 else [(7.0, 3.9, 6.3, 2.6), (14.6, 3.0, 4.3, 2.1)]
    for y in range(8):
        for x in range(20):
            for cx, cy, rx, ry in elipses:
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1:
                    t.p(x, y, funda if (y > cy and d > 0.45) else agua)
                    break
    brilhos = [(5, 2, 4), (12, 4, 3)] if tipo == 1 else [(3, 3, 3), (13, 2, 3)]
    for x, y, comp in brilhos:
        t.ret(x, y, comp, 1, (112, 138, 182))
        t.p(x + 1, y, (166, 188, 226))
    t.contorno((34, 42, 64), diagonal=False)
    return t.im


def gato():
    t = Tela(12, 8)
    claro, laranja, escuro, creme = (248, 182, 100), (228, 144, 64), (188, 104, 46), (250, 226, 186)
    for y in range(8):
        for x in range(12):
            if ((x - 6.9) / 4.3) ** 2 + ((y - 4.6) / 2.2) ** 2 <= 1:      # corpo
                t.p(x, y, claro if y <= 3 else laranja)
    for y in range(8):
        for x in range(12):
            if (x - 3.4) ** 2 + (y - 3.9) ** 2 <= 4.2:                    # cabeça
                t.p(x, y, claro if y <= 3 else laranja)
    t.p(2, 1, laranja); t.p(4, 1, laranja)                               # orelhas
    for x, y in ((10, 4), (10, 5), (9, 6), (8, 6), (7, 6), (6, 6)):     # rabo enrolado
        t.p(x, y, escuro)
    t.p(5, 6, creme)
    t.p(7, 3, escuro); t.p(9, 3, escuro); t.p(8, 4, escuro)              # listras
    t.p(3, 5, creme); t.p(4, 5, creme)
    t.p(2, 4, (150, 80, 40)); t.p(4, 4, (150, 80, 40))                   # olhos fechados
    t.p(3, 5, (232, 132, 132))                                           # nariz
    t.contorno((72, 42, 30), diagonal=False)
    return t.im


# ---------------------------------------------------------------- nuvem escura (2x)

def nuvem_escura():
    t = Tela(48, 32)
    tons = [(30, 22, 60), (44, 32, 86), (64, 48, 116), (90, 70, 150), (122, 100, 188)]
    bolhas = [(17, 11, 6.5), (31, 10, 7.2), (24, 14, 10.5), (12, 19, 7.5), (36, 19, 8.0),
              (18, 23, 6.5), (30, 23, 6.8)]
    for y in range(28):                                # base achatada
        for x in range(48):
            luzes = [i for i in (esfera(cx, cy, r, x, y) for cx, cy, r in bolhas) if i is not None]
            if not luzes:
                continue
            i = max(luzes) - (y / 28) * 0.4
            if y == 27:
                i = 0
            nivel = 0 if i < 0.1 else 1 if i < 0.33 else 2 if i < 0.58 else 3 if i < 0.8 else 4
            t.p(x, y, tons[nivel])
    t.contorno((172, 150, 228), diagonal=False)
    # carinha triste (não brava): sobrancelhas caindo para fora, olhinhos claros e boquinha para baixo
    claro, lilas, gota = (236, 228, 255), (198, 180, 244), (170, 210, 255)
    for x, y in ((20, 11), (19, 12), (18, 12), (17, 13), (23, 20), (24, 19)):
        t.p(x, y, lilas); t.p(49 - x, y, lilas)
    for x, y in ((18, 14), (19, 14), (18, 15), (19, 15), (18, 16), (19, 16)):
        t.p(x, y, claro); t.p(49 - x, y, claro)
    for x, y in ((14, 30), (14, 31), (34, 29), (34, 30)):          # duas gotinhas embaixo
        t.p(x, y, gota)
    return t.im


# ---------------------------------------------------------------- HUD (9x9)

def icone_mascara(linhas, cores):
    t = Tela(len(linhas[0]), len(linhas))
    for y, linha in enumerate(linhas):
        for x, ch in enumerate(linha):
            if ch in cores:
                t.p(x, y, cores[ch])
    return t.im


def estrela():
    return icone_mascara([
        "....o....",
        "...oho...",
        "...ohy...",
        "ooooyyooo",
        ".ohyyyyo.",
        "..oyyyd..",
        "..oyoyd..",
        ".oyo.oyo.",
        ".oo...oo.",
    ], {"o": (150, 80, 20), "y": (255, 204, 54), "h": (255, 244, 170), "d": (226, 150, 30)})


def luz():
    return icone_mascara([
        "....r....",
        "...ooo...",
        "..oyyyo..",
        ".oyhhyyo.",
        "royhwhyor",
        ".oyyhyyo.",
        "..oyyyo..",
        "...ooo...",
        "....r....",
    ], {"o": (226, 124, 30), "y": (255, 196, 64), "h": (255, 234, 150), "w": (255, 252, 226),
        "r": (255, 176, 60)})


# ---------------------------------------------------------------- ícone do app (32x32 -> 128)

def icone_app():
    rnd = random.Random(7)
    t = Tela(32, 32)
    noite = [(14, 18, 46), (18, 24, 60), (24, 32, 76), (30, 40, 92)]
    bayer = [[0, 2], [3, 1]]
    orbe = (20.0, 10.5)
    for y in range(32):
        for x in range(32):
            f = y / 31 * 3
            banda = int(f) + (1 if (f - int(f)) * 4 > bayer[y % 2][x % 2] + 0.5 else 0)
            cor = noite[min(3, banda)]
            d = math.dist((x, y), orbe)
            brilho = max(0.0, 1 - (d - 2.5) / 9)
            if brilho > 0:
                nivel = brilho * 3 + bayer[y % 2][x % 2] / 4 - 0.4
                cor = misturar(cor, (255, 178, 92), min(1, max(0, int(nivel)) * 0.22))
            t.p(x, y, cor)
    for _ in range(12):                               # estrelinhas
        x, y = rnd.randrange(1, 31), rnd.randrange(1, 18)
        if math.dist((x, y), orbe) > 10:
            t.p(x, y, (200, 210, 255))
    t.ret(0, 30, 32, 2, (10, 12, 30))                 # chão
    t.ret(4, 29, 22, 1, (10, 12, 30))
    # menina (silhueta) segurando a luz
    silhueta = (12, 10, 26)
    sil = set()
    for y in range(32):
        for x in range(32):
            if math.dist((x, y), (12.0, 15.2)) <= 3.1 or math.dist((x, y), (8.2, 14.8)) <= 1.5 \
                    or math.dist((x, y), (7.4, 16.8)) <= 1.1:
                sil.add((x, y))
            if 19 <= y <= 27:                       # vestido
                meia = 1.6 + (y - 19) * 0.55
                if abs(x - 12.2) <= meia:
                    sil.add((x, y))
    for y in range(18, 20):
        sil.update({(11, y), (12, y)})
    for y in range(28, 30):
        sil.update({(10, y), (11, y), (13, y), (14, y)})
    for k in range(9):                                # braço levantado
        ax, ay = 13.5 + k * 0.62, 19.5 - k * 0.95
        sil.update({(round(ax), round(ay)), (round(ax) + 1, round(ay))})
    for x, y in sil:
        t.p(x, y, silhueta)
    for x, y in sil:                                  # contraluz quente do lado da luz
        dx = 1 if orbe[0] > x else -1
        dy = 1 if orbe[1] > y else -1
        if math.dist((x, y), orbe) < 13 and ((x + dx, y) not in sil or (x, y + dy) not in sil):
            t.p(x, y, (214, 128, 70))
    for y in range(32):                               # a luz
        for x in range(32):
            d = math.dist((x, y), orbe)
            if d <= 2.9:
                t.p(x, y, (255, 252, 226) if d < 1.3 else (255, 222, 120) if d < 2.2 else (255, 172, 64))
    return t.im


# ---------------------------------------------------------------- personagens (folha 240x80, vistos de cima)
# A menina e as crianças têm o mesmo formato: quadros de 20x20; linhas = olhando para baixo, esquerda,
# direita, cima; colunas 0-3 = parada (respira), 4-11 = andando (contato, afunda, passagem, sobe e o
# mesmo com o outro lado). Nas colunas de passagem e de subida o quadro inteiro fica 1 px mais alto.
# Cada quadro é desenhado só olhando para baixo. As outras linhas são o mesmo quadro girado
# (90° horário, 90° anti-horário, 180°) e sombreado de novo, com a luz vindo do alto à esquerda
# (exceção: 2 quadros da linha de cima da menina, ver MARIAS_CIMA).
# Cada criança sai em duas folhas com a mesma silhueta: colorida e apagada (arroxeada, sem as cores).

CONTORNO_CRIANCA = (34, 24, 30)                    # o mesmo #22181e da menina
APAGADA = {"#": (26, 20, 40), "d": (74, 63, 108), "m": (101, 88, 144), "l": (138, 125, 188)}
CABECA = [(x, y) for y in (8, 9, 11, 12) for x in range(8, 12)] + [(x, 10) for x in range(7, 13)]
CLARO, ESCURO = -99.0, 99.0                        # viés que fixa o tom de um pixel
SOBE = [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1]        # coluna -> quanto o quadro sobe (o passo balança o corpo)

# Braço esquerdo em cada pose: (manga além do ombro, mão escura). O direito é o espelho.
OMBRO = [(6, 7), (7, 7), (5, 8), (6, 8), (5, 9), (6, 9), (5, 10)]
MAO = [(2, 9), (3, 9), (4, 9), (2, 10), (3, 10), (4, 10)]
MAO_ABERTA = [(2, 9), (3, 9), (2, 10), (3, 10), (4, 10)]
# Parada (colunas 0-3): respira. O ombro sobe, o braço abre, o ombro desce.
BRACOS_PARADA = [([], MAO), ([(5, 7)], MAO), ([(5, 7), (4, 8), (4, 9)], MAO_ABERTA),
                 ([(4, 8), (4, 9)], MAO_ABERTA)]
# Andando: 8 posições. A mão vai da frente para trás esticada, por fora, e volta por dentro, junto do corpo.
BRACOS_ANDANDO = [
    ([(4, 10)], [(3, 9), (2, 11), (3, 11), (2, 12), (3, 12)]),          # 0: na frente (contato)
    ([(4, 10)], [(2, 10), (3, 10), (2, 11), (3, 11)]),
    ([], MAO),                                                          # 2: no meio, indo para trás
    ([(4, 9)], [(2, 8), (3, 8), (2, 9), (3, 9)]),
    ([(4, 8), (4, 9)], [(2, 7), (3, 7), (2, 8), (3, 8), (3, 10)]),      # 4: atrás (contato do outro lado)
    ([], [(3, 8), (4, 8), (3, 9), (4, 9)]),
    ([], [(3, 9), (4, 9), (3, 10), (4, 10)]),                           # 6: no meio, voltando
    ([], [(3, 10), (4, 10), (3, 11), (4, 11)]),
]
# passo -> (pé que aparece na frente: 1 = direito, -1 = esquerdo; quantas linhas dele aparecem)
PES = [(1, 2), (1, 1), (0, 0), (-1, 1), (-1, 2), (-1, 1), (0, 0), (1, 1)]
# coluna -> balanço de 1 px do que fica solto (cabelo, capuz, mochila): (perto da cabeça, ponta).
# A ponta repete o que a parte de perto fez um quadro antes: o balanço chega atrasado.
BALANCO = [(0, 0), (1, 0), (1, 1), (0, 1),
           (1, 0), (1, 1), (0, 1), (0, 0), (-1, 0), (-1, -1), (0, -1), (0, 0)]


class Quadro:
    """Quadro 20x20 olhando para baixo. Cada pixel é (material, peça, viés) ou None (contorno)."""

    def __init__(self):
        self.px = {}
        self.pecas = []

    def peca(self, cx, cy, lim=2.5):
        """Peça = centro e limiar do sombreado: claro no alto à esquerda, escuro embaixo à direita."""
        self.pecas.append((cx, cy, lim))
        return len(self.pecas) - 1

    def pinta(self, pontos, material, peca, vies=0.0):
        for p in pontos:
            self.px[p] = (material, peca, vies)

    def escuro(self, pontos):
        for p in pontos:
            self.px[p] = None

    def contorna(self, pontos, manter=()):
        """Contorno de 1 px (sem diagonal) em volta dos pontos, sem cobrir os pontos nem os de manter."""
        dentro = set(pontos) | set(manter)
        for x, y in pontos:
            for viz in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if viz not in dentro:
                    self.px[viz] = None

    def tons(self, giros):
        """{(x, y): (tom, material)} depois de girar tantos quartos de volta no sentido horário."""
        def gira(x, y):
            for _ in range(giros):
                x, y = 19 - y, x
            return x, y

        saida = {}
        for (x, y), pixel in self.px.items():
            gx, gy = gira(x, y)
            if pixel is None:
                saida[gx, gy] = ("#", None)
                continue
            material, peca, vies = pixel
            cx, cy, lim = self.pecas[peca]
            cx, cy = gira(cx, cy)
            s = (gx - cx) + (gy - cy) + vies
            saida[gx, gy] = ("l" if s <= -lim else "d" if s >= lim else "m", material)
        return saida


def bracos_e_pe(coluna):
    """Coluna da folha -> (pose do braço esquerdo, pose do direito, pé à mostra)."""
    if coluna < 4:
        return BRACOS_PARADA[coluna], BRACOS_PARADA[coluna], (0, 0)
    passo = coluna - 4
    return BRACOS_ANDANDO[passo], BRACOS_ANDANDO[(passo + 4) % 8], PES[passo]


def maos_e_pe(q, maos, pe, pe_em):
    """Mãos, os dois pixels entre o braço e a cabeça e o pé da frente, escuros como o contorno."""
    lado, linhas = pe
    x0 = pe_em[0] if lado > 0 else 18 - pe_em[0]
    q.escuro(maos + [(6, 11), (13, 11)] + [(x0 + i, pe_em[1] + j) for i in (0, 1) for j in range(linhas)])


def corpo_crianca(q, coluna, material, afasta=0, pe=(11, 13)):
    """Ombros e mangas com contorno, mãos escuras e o pé que aparece no passo, como na menina."""
    esquerdo, direito, passo = bracos_e_pe(coluna)
    roupa, maos = [], []
    for (extra, mao), espelha in ((esquerdo, False), (direito, True)):
        manga = OMBRO + extra
        if afasta:                                  # cabeça maior: braço 1 px para fora, ombro mais largo
            manga = [(x - 1, y) for x, y in manga] + [(x, y) for x, y in manga if y <= 7]
            if min(x for x, _ in mao) > 2:          # a mão que volta por dentro não some atrás da manga
                mao = [(x - 1, y) for x, y in mao]
        if espelha:
            manga = [(19 - x, y) for x, y in manga]
            mao = [(19 - x, y) for x, y in mao]
        roupa += manga
        maos += mao
    q.pinta(roupa, material, q.peca(9.5, 8.5))
    q.contorna(roupa)
    maos_e_pe(q, [p for p in maos if p not in roupa], passo, pe)


def crianca_bone(coluna):
    """Boné vermelho com a aba para a frente, cabelo castanho aparecendo atrás e dos lados, camiseta verde."""
    q = Quadro()
    corpo_crianca(q, coluna, "camisa", pe=(12, 14))
    cabeca = q.peca(9.5, 10)
    q.pinta(CABECA, "bone", cabeca)
    q.pinta([(x, 8) for x in range(8, 12)] + [(7, 10), (12, 10)], "cabelo", cabeca)
    q.pinta([(x, 12) for x in range(8, 12)], "bone", cabeca, ESCURO)   # sombra onde a aba começa
    q.contorna(CABECA)
    d = BALANCO[coluna][0]                                             # a cabeça vira um pouco a cada passo
    aba = [(x, 13) for x in range(7, 13)] + [(x + d, 14) for x in range(8, 12)]
    q.pinta(aba, "bone", q.peca(9.5, 13.5, 2.0))
    q.contorna(aba, manter=CABECA)
    return q


def crianca_rabo(coluna):
    """Cabelo preto com um rabo de cavalo só, para trás (balança ao andar), blusa amarela."""
    q = Quadro()
    corpo_crianca(q, coluna, "blusa")
    q.pinta(CABECA, "cabelo", q.peca(9.5, 10))
    q.contorna(CABECA)
    elastico = [(9, 7), (10, 7)]
    q.pinta(elastico, "elastico", q.peca(9.5, 7, 99))
    perto, ponta = BALANCO[coluna]
    rabo = [(9, 6), (10, 6), (9 + perto, 5), (10 + perto, 5), (9 + ponta, 4), (10 + ponta, 4)]
    q.pinta(rabo, "cabelo", q.peca(9.5, 5.5, 0.5))
    q.contorna(rabo, manter=CABECA + elastico)
    return q


def crianca_cacheado(coluna):
    """Cabelo cacheado castanho-claro e volumoso (borda fofa), mochila azul nas costas, camiseta laranja."""
    q = Quadro()
    corpo_crianca(q, coluna, "camisa", afasta=1, pe=(11, 14))
    perto, ponta = BALANCO[coluna]
    mochila = []
    for y, d in ((6, perto), (5, ponta)):                         # a parte de longe chega atrasada, como o rabo
        linha = [(x + d, y) for x in range(8, 12)]
        q.pinta(linha, "mochila", q.peca(9.5 + d, 5.5, 1.5))
        mochila += linha
    q.contorna(mochila)
    cachos = [(x, y) for y in range(8, 14) for x in range(7, 13)
              if (x, y) not in ((7, 8), (12, 8), (7, 13), (12, 13))]
    antes = set(q.px)
    cabeca = q.peca(9.5, 10.5)
    for x, y in cachos:
        q.pinta([(x, y)], "cabelo", cabeca, (0, -1.5, 0, 1.5)[(x + 2 * y) % 4])
    q.contorna(cachos)
    # metade da borda vira cacho, sempre a mesma: trocando a cada passo, uns 10 pixels mudavam juntos e
    # o contorno parecia piscar
    borda = [p for p in q.px if q.px[p] is None and p not in antes and (p[0] + p[1]) % 2 == 0]
    q.pinta(borda, "cabelo", cabeca, ESCURO)
    q.cachos = borda                                               # as direções giradas refazem a borda fofa
    q.pinta([(9, 13), (10, 13)], "pele", q.peca(9.5, 13, 99))     # testa aparecendo na frente
    return q


def crianca_coque(coluna):
    """Cabelo ruivo com um coque no alto, mais para trás, blusa roxa."""
    q = Quadro()
    corpo_crianca(q, coluna, "blusa")
    q.pinta(CABECA, "cabelo", q.peca(9.5, 10))
    q.contorna(CABECA)
    d = BALANCO[coluna][1]
    coque = [(9 + d, 7), (10 + d, 7), (9 + d, 8), (10 + d, 8)]
    q.pinta(coque, "cabelo", q.peca(9.5 + d, 7.5, 1.0))
    q.contorna(coque)
    return q


def crianca_capuz(coluna):
    """Moletom azul-petróleo com o capuz levantado: ponta para trás, franja e testa aparecendo na frente."""
    q = Quadro()
    corpo_crianca(q, coluna, "moletom")
    d = BALANCO[coluna][1]                                         # a ponta do capuz cai para um lado e para o outro
    ponta = [[(9, 6)], [(10, 6)], [(11, 7), (11, 6)]][d + 1]
    capuz = CABECA + [(9, 7), (10, 7)] + ponta
    q.pinta(capuz, "moletom", q.peca(9.5, 10))
    rosto = q.peca(9.5, 12, 99)
    q.pinta([(9, 11), (10, 11)], "franja", rosto)
    q.pinta([(9, 12), (10, 12)], "pele", rosto)
    q.contorna(capuz)
    return q


CRIANCAS = [
    ("menino_bone", crianca_bone, {
        "camisa": ((200, 244, 216), (140, 214, 170), (92, 170, 130)),
        "bone": ((240, 104, 84), (212, 58, 52), (160, 36, 44)),
        "cabelo": ((112, 72, 44), (84, 52, 34), (58, 36, 26))}),
    ("menina_rabo", crianca_rabo, {
        "blusa": ((250, 224, 112), (236, 188, 64), (196, 140, 44)),
        "cabelo": ((104, 112, 146), (62, 68, 96), (40, 42, 62)),
        "elastico": ((236, 92, 124),) * 3}),
    ("menino_cacheado", crianca_cacheado, {
        "camisa": ((252, 170, 88), (232, 128, 52), (184, 88, 36)),
        "cabelo": ((222, 170, 104), (184, 128, 72), (140, 92, 52)),
        "pele": ((122, 78, 54),) * 3,
        "mochila": ((110, 160, 236), (70, 116, 204), (48, 80, 156))}),
    ("menina_coque", crianca_coque, {
        "blusa": ((186, 146, 240), (146, 100, 214), (106, 68, 170)),
        "cabelo": ((240, 130, 70), (204, 84, 44), (150, 54, 34))}),
    ("crianca_capuz", crianca_capuz, {
        "moletom": ((72, 170, 180), (40, 128, 142), (26, 92, 106)),
        "franja": ((120, 80, 52),) * 3,
        "pele": ((240, 196, 160),) * 3}),
]


# ---- a menina (protagonista): a mesma de assets/sprites/personagem/menina_folha_nativa.png.
# As colunas 0, 2, 4 e 8 são os quadros 0, 1, 2 e 4 da folha antiga; as outras ficam no meio do caminho.

CORES_MENINA = {
    "cabelo": ((104, 68, 50), (76, 48, 38), (52, 33, 28)),
    "roupa": ((152, 174, 198), (124, 148, 176), (96, 116, 144)),
    "elastico": ((246, 222, 140), (232, 198, 104), (200, 160, 80))}
# Tom desenhado à mão: letra -> deslocamento do pixel em relação ao centro da luz dele. Os tons que a
# letra dá olhando para baixo, esquerda, cima e direita: a = médio, claro, médio, escuro; b = e, m, c, m;
# p = c, m, e, m; q = m, e, m, c; c = sempre médio; e = e, c, c, e; f = e, e, c, c; g = c, c, e, e.
LUZ = {"a": (-0.5, 0.5), "b": (0.5, 0.5), "p": (-0.5, -0.5), "q": (0.5, -0.5),
       "c": (0, 0), "e": (0, 1), "f": (1, 0), "g": (-1, 0)}
OMBRO_MENINA = [(7, 7), (5, 9), (6, 9), (5, 10)]
# Braço esquerdo da menina na parada: (ombro a mais, ponta da manga, mão). Andando ela usa BRACOS_ANDANDO.
MENINA_PARADA = [([], [], MAO), ([(5, 8)], [], MAO), ([(6, 7), (5, 8)], [(4, 9)], MAO_ABERTA),
                 ([], [(4, 9)], MAO_ABERTA)]
# Maria-chiquinha: linhas de pixels a partir do elástico (y = 7, 6, 5...), cada uma (x inicial, tons);
# "#" é um pixel escuro (a pontinha). Elas esticam no contato do passo, encolhem na passagem e a ponta
# chega atrasada.
SOLTA_E = [(6, "b"), (5, "ab"), (5, "ab")]
SOLTA_D = [(13, "a"), (13, "ab"), (13, "ab")]
LONGA_E = SOLTA_E + [(5, "c")]
LONGA_D = SOLTA_D + [(14, "c")]
MARIAS = [
    (SOLTA_E + [(5, "#"), (5, "#")], SOLTA_D + [(14, "#"), (14, "#")]),                         # parada
    (SOLTA_E + [(5, "#"), (5, "#")], SOLTA_D + [(14, "#"), (14, "#")]),
    ([(5, "a"), (5, "eb"), (5, "cb"), (5, "c")], [(14, "b"), (13, "ae"), (13, "ac"), (14, "c")]),
    (LONGA_E, LONGA_D),
    ([(5, "ab"), (5, "ebf"), (5, "cb"), (5, "c")], [(13, "abb"), (13, "ae"), (13, "ac"), (14, "c")]),   # contato
    (SOLTA_E + [(6, "c")], [(13, "a"), (13, "ab"), (14, "ab"), (15, "c")]),
    (SOLTA_E, SOLTA_D),
    ([(6, "b"), (5, "ab"), (6, "c"), (6, "c")], [(13, "a"), (13, "ab"), (14, "c"), (14, "c")]),
    ([(6, "e"), (6, "e"), (6, "c"), (6, "c")], [(13, "e"), (12, "ae"), (12, "gc"), (13, "c")]),         # contato
    ([(6, "b"), (5, "ab"), (4, "ab"), (4, "c")], [(13, "a"), (13, "ab"), (12, "ab"), (12, "c")]),
    (SOLTA_E, SOLTA_D),
    (LONGA_E, LONGA_D),
]
# Andando para cima elas caem para baixo na tela e a subida do quadro as levaria junto: na passagem
# (colunas 6 e 10) ficam compridas como no quadro seguinte, e a ponta sobe só 1 px, junto com o
# corpo (antes subia 2 e voltava 1).
MARIAS_CIMA = {6: MARIAS[7], 10: MARIAS[11]}
# Retoques na roupa para as colunas 4 e 8 ficarem iguais aos quadros antigos: coluna -> [(x, y, letra)];
# "." apaga o pixel.
RETOQUES = {4: [(8, 5, "#"), (15, 9, "a")], 8: [(4, 7, "."), (4, 8, "#"), (4, 9, "b")]}


def tom_fixo(q, material, x, y, letra):
    if letra == ".":
        q.px.pop((x, y), None)
    elif letra == "#":
        q.escuro([(x, y)])
    else:
        dx, dy = LUZ[letra]
        q.pinta([(x, y)], material, q.peca(x - dx, y - dy, 0.75))


def menina(coluna, marias=None):
    """Cabelo castanho, duas maria-chiquinhas para trás com elástico amarelo, roupa azul.
    `marias`: outras maria-chiquinhas no lugar das da coluna (a linha de cima usa MARIAS_CIMA)."""
    q = Quadro()
    esquerdo, direito, pe = bracos_e_pe(coluna)
    if coluna < 4:
        esquerdo = direito = MENINA_PARADA[coluna]
    else:                                           # andando, o ombro vai junto quando a mão está atrás
        esquerdo, direito = [([(5, 8)] if min(y for _, y in mao) < 9 else [], ponta, mao)
                             for ponta, mao in (esquerdo, direito)]
    roupa, pontas, maos = [], [], []
    for (ombro, ponta, mao), espelha, letra in ((esquerdo, False, "q"), (direito, True, "p")):
        manga = OMBRO_MENINA + ombro + ponta
        if espelha:
            manga, ponta, mao = ([(19 - x, y) for x, y in pontos] for pontos in (manga, ponta, mao))
        roupa += manga
        pontas += [(x, y, letra) for x, y in ponta]
        maos += mao
    q.pinta(roupa, "roupa", q.peca(9.5, 8.5))
    q.contorna(roupa)
    for x, y, letra in pontas:
        tom_fixo(q, "roupa", x, y, letra)
    maos_e_pe(q, maos, pe, (11, 13))
    q.pinta(CABECA, "cabelo", q.peca(9.5, 10))
    q.contorna(CABECA)
    tom_fixo(q, "elastico", 6, 8, "a")
    tom_fixo(q, "elastico", 13, 8, "b")
    q.marias = []                                   # as direções giradas carimbam as maria-chiquinhas
    for maria in marias or MARIAS[coluna]:
        cabelo, pontos = [], []
        for y, (x0, tons) in zip(range(7, 2, -1), maria):
            for x, letra in enumerate(tons, x0):
                tom_fixo(q, "cabelo", x, y, letra)
                pontos.append((x, y))
                if letra != "#":
                    cabelo.append((x, y))
        q.contorna(cabelo, manter=[p for p in q.px if q.px[p] is not None])
        q.marias.append(pontos)
    for x, y, letra in RETOQUES.get(coluna, []):
        tom_fixo(q, "roupa", x, y, letra)
    return q


def folhas_personagem(desenha, cores, cima=None):
    """Devolve as duas folhas 240x80 (colorida, apagada) de um personagem. `cima`, se vier, desenha a linha
    de cima no lugar de `desenha`."""
    colorida = Image.new("RGBA", (240, 80), (0, 0, 0, 0))
    apagada = Image.new("RGBA", (240, 80), (0, 0, 0, 0))
    for coluna in range(12):
        q = desenha(coluna)
        for linha, giros in enumerate((0, 1, 3, 2)):          # baixo, esquerda, direita, cima
            fonte = cima(coluna) if cima and giros == 2 else q
            for (x, y), (tom, material) in fonte.tons(giros).items():
                pos = (coluna * 20 + x, linha * 20 + y - SOBE[coluna])
                cor = CONTORNO_CRIANCA if tom == "#" else cores[material]["lmd".index(tom)]
                colorida.putpixel(pos, cor + (255,))
                apagada.putpixel(pos, APAGADA[tom] + (255,))
    return colorida, apagada


# ---------------------------------------------------------------- 16 direções (folha 240x320)
# Linha k = direção k: ângulo de k x 22,5° na tela, no sentido horário a partir da direita (0 direita,
# 4 baixo, 8 esquerda, 12 cima, o mesmo sentido de Vector2.angle() no Godot). As linhas 0, 4, 8 e 12
# são as da folha de 4, pixel a pixel. As outras giram a figura (antes do SOBE) da cardinal mais perto
# com RotSprite: Scale2x três vezes, gira no vizinho mais próximo e reduz 8x8 pela moda. Gira-se uma
# imagem de rótulos (tom, material) e só depois se pinta: a versão colorida e a apagada saem com a
# mesma silhueta e nenhuma cor nova aparece. Nos 45° gira-se das duas cardinais vizinhas e fica a que
# sai mais limpa (a mesma em todas as colunas).

CARDINAIS = {0: (2, 3), 4: (0, 0), 8: (1, 1), 12: (3, 2)}      # direção -> (linha na folha de 4, giros)
V4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
CONTORNO = ("#", None)
# Direções a até 45° de cima: as maria-chiquinhas da menina caem para baixo na tela e usam a figura de cima
# (MARIAS_CIMA), mesmo nos 45° que giram da esquerda ou da direita.
DE_CIMA = (10, 11, 13, 14)
# Coluna do contato: as maria-chiquinhas esticadas, finas e escuras, que o RotSprite sempre come.
CONTATO = 8


def gira90(x, y, giros):
    """O mesmo giro de `Quadro.tons`: quartos de volta no sentido horário."""
    for _ in range(giros):
        x, y = 19 - y, x
    return x, y


def scale2x(grade, lado):
    """Scale2x numa grade quadrada de rótulos (lista, linha por linha): cada pixel vira 2x2 e as quinas
    das diagonais se arredondam. Na borda, o vizinho que falta é o próprio pixel."""
    s = 2 * lado
    saida = [None] * (s * s)
    for y in range(lado):
        for x in range(lado):
            i = y * lado + x
            p = grade[i]
            a = grade[i - lado] if y > 0 else p                 # cima
            b = grade[i + 1] if x < lado - 1 else p             # direita
            c = grade[i - 1] if x > 0 else p                    # esquerda
            d = grade[i + lado] if y < lado - 1 else p          # baixo
            j = 2 * y * s + 2 * x
            saida[j] = a if c == a and c != d and a != b else p
            saida[j + 1] = b if a == b and a != c and b != d else p
            saida[j + s] = c if d == c and d != b and c != a else p
            saida[j + s + 1] = d if b == d and b != a and d != c else p
    return saida


# os 64 pontos de um pixel na imagem 8x, do centro para fora: no empate da moda ganha o mais do meio
ORDEM_8X8 = sorted(((i, j) for j in range(8) for i in range(8)),
                   key=lambda p: ((p[0] - 3.5) ** 2 + (p[1] - 3.5) ** 2, p[1], p[0]))
AMOSTRAS = {}


def amostras(passos):
    """Para cada pixel do quadro girado `passos` x 22,5° no sentido horário, os índices dos seus 64 pontos
    na imagem 8x (160x160) de antes do giro: vizinho mais próximo, girando em volta do centro do quadro
    (o mesmo centro dos giros de 90°). -1 = fora da imagem."""
    if passos not in AMOSTRAS:
        cos, sen = math.cos(math.radians(passos * 22.5)), math.sin(math.radians(passos * 22.5))
        mapa = []
        for y in range(20):
            for x in range(20):
                pontos = []
                for i, j in ORDEM_8X8:
                    u, v = 8 * x + i + 0.5 - 80, 8 * y + j + 0.5 - 80
                    sx, sy = math.floor(80 + u * cos + v * sen), math.floor(80 - u * sen + v * cos)
                    pontos.append(sy * 160 + sx if 0 <= sx < 160 and 0 <= sy < 160 else -1)
                mapa.append(pontos)
        AMOSTRAS[passos] = mapa
    return AMOSTRAS[passos]


def rotsprite(rotulos, passos):
    """Gira um quadro {(x, y): rótulo} `passos` x 22,5° no sentido horário (RotSprite; o vazio conta na moda)."""
    grade = [rotulos.get((i % 20, i // 20)) for i in range(400)]
    grande = scale2x(scale2x(scale2x(grade, 20), 40), 80)
    saida = {}
    for i, pontos in enumerate(amostras(passos)):
        rotulo = Counter(grande[p] if p >= 0 else None for p in pontos).most_common(1)[0][0]
        if rotulo is not None:
            saida[i % 20, i // 20] = rotulo
    return saida


def vizinhos(t, p):
    return [t.get((p[0] + dx, p[1] + dy)) for dx, dy in V4]


def defeitos(t):
    """Sujeira de um quadro girado: pixels de cor encostados no vazio (contorno quebrado), pixels soltos
    e pedaços separados a mais."""
    quebrado = sum(1 for p, (tom, _) in t.items() if tom != "#" and None in vizinhos(t, p))
    soltos = sum(1 for p in t if vizinhos(t, p).count(None) == 4)
    pedacos, vistos = 0, set()
    for p in t:
        if p not in vistos:
            pedacos += 1
            pilha = [p]
            vistos.add(p)
            while pilha:
                x, y = pilha.pop()
                for viz in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if viz in t and viz not in vistos:
                        vistos.add(viz)
                        pilha.append(viz)
    return quebrado + soltos + pedacos - 1


def fecha(t):
    """Fecha o contorno como `Quadro.contorna`: o vazio encostado (de lado) num pixel de cor vira contorno.
    O pixel de cor que ficou sozinho no meio do contorno, preso ao resto da peça só pela quina (a ponta
    de uma maria-chiquinha, quase sempre), vira contorno também, e some quem ficou sem nenhum vizinho."""
    for (x, y), (tom, _) in list(t.items()):
        if tom != "#":
            for dx, dy in V4:
                t.setdefault((x + dx, y + dy), CONTORNO)
    pontas = [(x, y) for (x, y), (tom, material) in t.items()
              if tom != "#" and all(r == CONTORNO for r in vizinhos(t, (x, y))) and any(
                  t.get((x + dx, y + dy), CONTORNO)[1] == material for dx in (-1, 1) for dy in (-1, 1))]
    for p in pontas:
        t[p] = CONTORNO
    for p in [p for p in t if vizinhos(t, p).count(None) == 4]:
        del t[p]


def pecas_pequenas(fonte):
    """Peças de cabelo de até 4 pixels quase todas cercadas de contorno (o coque, a maria-chiquinha fininha
    do passo, o cabelo do lado do boné): no RotSprite o contorno em volta ganha a moda e elas somem."""
    pecas, vistos = [], set()
    for p, (tom, material) in fonte.items():
        if tom == "#" or material != "cabelo" or p in vistos:
            continue
        peca, pilha = [], [p]
        vistos.add(p)
        while pilha:
            x, y = pilha.pop()
            peca.append((x, y))
            for viz in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if viz not in vistos and fonte.get(viz, CONTORNO)[1] == material and fonte[viz][0] != "#":
                    vistos.add(viz)
                    pilha.append(viz)
        borda = [fonte.get((x + dx, y + dy)) for x, y in peca for dx, dy in V4 if (x + dx, y + dy) not in peca]
        if len(peca) <= 4 and sum(r == CONTORNO for r in borda) >= 0.75 * len(borda):
            pecas.append(sorted(peca))
    return pecas


def carimba(t, fonte, pecas, passos):
    """Põe as peças pequenas de volta, giradas no vizinho mais próximo (sem o Scale2x, que as arredonda até
    sumir), com contorno em volta como em `Quadro.contorna`: o vazio e o mesmo material encostados viram
    contorno."""
    cos, sen = math.cos(math.radians(passos * 22.5)), math.sin(math.radians(passos * 22.5))
    for peca in pecas:
        material = fonte[peca[0]][1]
        novo = {}
        for y in range(20):
            for x in range(20):
                u, v = x + 0.5 - 10, y + 0.5 - 10
                origem = (math.floor(10 + u * cos + v * sen), math.floor(10 - u * sen + v * cos))
                if origem in peca:
                    novo[x, y] = fonte[origem]
        if not novo:                               # peça de 1 pixel que caiu entre os centros: vai para o mais perto
            x, y = peca[0]
            u, v = x + 0.5 - 10, y + 0.5 - 10
            novo[math.floor(10 + u * cos - v * sen), math.floor(10 + u * sen + v * cos)] = fonte[x, y]
        t.update(novo)
        borda = {(x + dx, y + dy) for x, y in novo for dx, dy in V4} - set(novo)
        for q in borda:
            if q not in t or t[q][1] == material:
                t[q] = CONTORNO
        quinas = {(x + dx, y + dy) for x, y in novo for dx in (-1, 1) for dy in (-1, 1)} - set(novo) - borda
        for q in quinas:                           # sobra da peça girada pelo RotSprite, solta na quina
            if t.get(q, CONTORNO)[1] == material and all(r is None or r[1] != material for r in vizinhos(t, q)):
                t[q] = CONTORNO


def pedacos(pontos):
    """Os pedaços (vizinhos de lado) de um conjunto de pixels."""
    pontos, vistos, saida = set(pontos), set(), []
    for p in sorted(pontos):
        if p not in vistos:
            pedaco, pilha = [], [p]
            vistos.add(p)
            while pilha:
                x, y = pilha.pop()
                pedaco.append((x, y))
                for viz in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if viz in pontos and viz not in vistos:
                        vistos.add(viz)
                        pilha.append(viz)
            saida.append(pedaco)
    return saida


def na_fonte(x, y, passos):
    """Onde o centro do pixel (x, y) do quadro girado `passos` x 22,5° cai no quadro de antes do giro."""
    cos, sen = math.cos(math.radians(passos * 22.5)), math.sin(math.radians(passos * 22.5))
    u, v = x + 0.5 - 10, y + 0.5 - 10
    return 10 + u * cos + v * sen, 10 - u * sen + v * cos


def maria_girada(fonte, maria, passos):
    """Uma maria-chiquinha girada no vizinho mais próximo: {(x, y): pixel de origem}."""
    novo = {}
    for y in range(20):
        for x in range(20):
            sx, sy = na_fonte(x, y, passos)
            if (math.floor(sx), math.floor(sy)) in maria:
                novo[x, y] = (math.floor(sx), math.floor(sy))
    return novo


def comida(girado, fonte, marias, passos):
    """Alguma maria-chiquinha ficou, depois do RotSprite e do `fecha`, com menos da metade do cabelo?"""
    t = dict(girado)
    fecha(t)
    for maria in marias:
        alvo = [p for p, o in maria_girada(fonte, maria, passos).items() if fonte[o] != CONTORNO]
        if 2 * sum(t.get(p, CONTORNO)[1] == "cabelo" for p in alvo) < len(alvo):
            return True
    return False


def gira_sem_marias(t, marias, girado, passos):
    """RotSprite da figura sem as maria-chiquinhas (e sem o contorno que só existia por causa delas), com o
    que o giro com tudo mostrou de outro material em volta delas: o ombro e o elástico, que sem a maria do
    lado o RotSprite come."""
    tira = {p for maria in marias for p in maria}
    s = {p: r for p, r in t.items() if p not in tira}
    for p in {(x + dx, y + dy) for x, y in tira for dx, dy in V4} - tira:
        if s.get(p) == CONTORNO and all(r is None or r == CONTORNO for r in vizinhos(s, p)):
            del s[p]
    sem = rotsprite(s, passos)
    for p, r in girado.items():
        if r[0] != "#" and r[1] != "cabelo" and sem.get(p, CONTORNO) == CONTORNO:
            sem[p] = r
    return sem


def carimba_marias(t, fonte, marias, passos):
    """Põe as maria-chiquinhas de volta no quadro girado sem elas: no vizinho mais próximo (o RotSprite come
    as finas e deixa só o contorno), sem cobrir outro material. Dois pixels que só se tocam pela quina
    ganham o vizinho de lado mais perto da maria, como nas marias desenhadas na diagonal, e o vazio e o
    cabelo encostados viram contorno, como em `Quadro.contorna`."""
    livre = lambda p: p not in t or t[p][1] in (None, "cabelo")
    for maria in marias:
        novo = {p: o for p, o in maria_girada(fonte, maria, passos).items() if livre(p)}
        while len(partes := pedacos(novo)) > 1:
            qual = {p: i for i, parte in enumerate(partes) for p in parte}
            cantos = set()                  # vizinhos de lado de dois pedaços que se tocam pela quina
            for (x, y), i in qual.items():
                for dx in (-1, 1):
                    for dy in (-1, 1):
                        if qual.get((x + dx, y + dy), i) != i:
                            cantos.update(c for c in ((x + dx, y), (x, y + dy)) if livre(c))
            if not cantos:
                break
            perto = {c: min((math.dist(na_fonte(*c, passos), (x + 0.5, y + 0.5)), (x, y)) for x, y in maria)
                     for c in sorted(cantos)}
            canto = min(perto, key=lambda c: perto[c][0])
            novo[canto] = perto[canto][1]
        for p, o in novo.items():
            t[p] = fonte[o]
        for x, y in [p for p, o in novo.items() if fonte[o] != CONTORNO]:
            for viz in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if viz not in novo and (viz not in t or t[viz][1] == "cabelo"):
                    t[viz] = CONTORNO


def elasticos(t, fonte, passos):
    """O elástico que o giro apagou volta para o pixel onde cai o centro dele, com contorno onde for vazio."""
    cos, sen = math.cos(math.radians(passos * 22.5)), math.sin(math.radians(passos * 22.5))
    for (x, y), rotulo in fonte.items():
        if rotulo[1] != "elastico":
            continue
        u, v = x + 0.5 - 10, y + 0.5 - 10
        gx, gy = math.floor(10 + u * cos - v * sen), math.floor(10 + u * sen + v * cos)
        if all(t.get((gx + dx, gy + dy), CONTORNO)[1] != "elastico" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            t[gx, gy] = rotulo
            for viz in ((gx + 1, gy), (gx - 1, gy), (gx, gy + 1), (gx, gy - 1)):
                t.setdefault(viz, CONTORNO)


def refaz_cachos(t):
    """Borda fofa do cabelo cacheado no quadro girado: um pixel sim, um não, o contorno livre da cabeça
    (encostado no cabelo e no vazio, longe da camiseta e da mochila) vira cacho."""
    for p, (tom, _) in list(t.items()):
        perto = [r[1] for r in vizinhos(t, p) if r]
        if tom == "#" and (p[0] + p[1]) % 2 == 0 and "cabelo" in perto and len(perto) < 4 \
                and "camisa" not in perto and "mochila" not in perto:
            t[p] = ("d", "cabelo")


def quadros16(desenha, cima=None, retoques=None):
    """As 12 direções giradas de um personagem: ({(direção, coluna): rótulos já limpos e retocados, antes
    do SOBE}, {direção: cardinal de onde girou}). `cima` como em `folhas_personagem`, usado também nos 45°
    vizinhos de cima (DE_CIMA); `retoques`: (direção, coluna) -> [(x, y, rótulo)] feitos à mão depois do
    giro (rótulo "." apaga). As maria-chiquinhas da menina são carimbadas no quadro do contato e onde o
    RotSprite as come; os elásticos que somem voltam."""
    girados, fontes = {}, {}                           # (direção, coluna, cardinal de origem) -> rótulos
    cacheado = False
    for coluna in range(12):
        figuras = desenha(coluna), cima(coluna) if cima else None
        for c, (_, giros) in CARDINAIS.items():
            for passos in (-2, -1, 1, 2):
                k = (c + passos) % 16
                fonte = figuras[1] if cima and (c == 12 or k in DE_CIMA) else figuras[0]
                t = fonte.tons(giros)
                for x, y in getattr(fonte, "cachos", ()):  # o cacho gira como contorno e é refeito depois
                    t[gira90(x, y, giros)] = CONTORNO
                    cacheado = True
                marias = [[p for p in (gira90(x, y, giros) for x, y in m) if p in t]
                          for m in getattr(fonte, "marias", ())]
                # As marias do contato e as que o RotSprite come no andar (na parada, carimbar um quadro só
                # faria a respiração piscar) saem do RotSprite e são carimbadas depois. O giro com tudo
                # continua escolhendo a origem dos 45°.
                girado = rotsprite(t, passos)
                if marias and (coluna == CONTATO or coluna >= 4 and comida(girado, t, marias, passos)):
                    girados[k, coluna, c] = girado, gira_sem_marias(t, marias, girado, passos)
                    fontes[k, coluna, c] = t, marias
                else:
                    girados[k, coluna, c] = girado, None
                    fontes[k, coluna, c] = t, pecas_pequenas(t)
    origem = {k: k - 1 if k % 4 == 1 else (k + 1) % 16 for k in range(16) if k % 4 in (1, 3)}
    for k in range(2, 16, 4):                          # 45°: a cardinal que gira com menos sujeira
        origem[k] = min((sum(defeitos(girados[k, coluna, c][0]) for coluna in range(12)), c)
                        for c in ((k - 2) % 16, (k + 2) % 16))[1]
    quadros = {}
    for k, c in origem.items():
        for coluna in range(12):
            girado, sem = girados[k, coluna, c]
            t = sem or girado
            fecha(t)
            (carimba_marias if sem else carimba)(t, *fontes[k, coluna, c], (k - c + 8) % 16 - 8)
            elasticos(t, fontes[k, coluna, c][0], (k - c + 8) % 16 - 8)
            if cacheado:
                refaz_cachos(t)
            for x, y, rotulo in (retoques or {}).get((k, coluna), []):
                if rotulo == ".":
                    t.pop((x, y), None)
                else:
                    t[x, y] = rotulo
            quadros[k, coluna] = t
    return quadros, origem


# Retoques à mão nas direções giradas, onde o RotSprite deixou feio: personagem -> {(direção, coluna):
# [(x, y, rótulo)]}, em coordenadas do quadro antes do SOBE.
RETOQUES16 = {"menina": {
    # Maria-chiquinha que o RotSprite deixou curta ou reta demais: no quadro vizinho do andar ela pulava 3 px.
    (6, 11): [(15, 11, ("m", "cabelo")), (15, 12, CONTORNO)],
    (14, 7): [(4, 10, ("d", "cabelo")), (4, 11, CONTORNO)],
    (15, 7): [(4, 8, ("d", "cabelo")), (5, 8, ("d", "cabelo")), (4, 9, CONTORNO), (5, 9, CONTORNO)],
}}


def folhas16_personagem(desenha, cores, folhas4, cima=None, retoques=None):
    """Devolve as duas folhas 240x320 (colorida, apagada) de 16 direções de um personagem. `folhas4` são as
    duas folhas de 4: as linhas cardinais vêm delas."""
    colorida = Image.new("RGBA", (240, 320), (0, 0, 0, 0))
    apagada = Image.new("RGBA", (240, 320), (0, 0, 0, 0))
    for c, (linha, _) in CARDINAIS.items():
        for folha, folha4 in zip((colorida, apagada), folhas4):
            folha.paste(folha4.crop((0, linha * 20, 240, linha * 20 + 20)), (0, c * 20))
    for (k, coluna), t in sorted(quadros16(desenha, cima, retoques)[0].items()):
        for (x, y), (tom, material) in t.items():
            assert 0 <= x < 20 and 0 <= y - SOBE[coluna] < 20, (k, coluna, x, y)
            pos = (coluna * 20 + x, k * 20 + y - SOBE[coluna])
            cor = CONTORNO_CRIANCA if tom == "#" else cores[material]["lmd".index(tom)]
            colorida.putpixel(pos, cor + (255,))
            apagada.putpixel(pos, APAGADA[tom] + (255,))
    return colorida, apagada


# ---------------------------------------------------------------- ícones novos do HUD

def coracao():
    return icone_mascara([
        ".oo.oo.",
        "ohrorro",
        "orrrrro",
        "orrrrdo",
        ".orrdo.",
        "..odo..",
        "...o...",
    ], {"o": (96, 22, 46), "r": (238, 76, 104), "h": (255, 180, 190), "d": (196, 46, 86)})


def brilho():
    """Faísca dourada de 4 pontas (a luz é uma bolinha, a estrela tem 5 pontas)."""
    return icone_mascara([
        "....o....",
        "...oyo...",
        "...oyo...",
        ".ooyhyoo.",
        "oyyhwhyyo",
        ".ooyhyoo.",
        "...oyo...",
        "...oyo...",
        "....o....",
    ], {"o": (150, 84, 18), "y": (255, 208, 64), "h": (255, 238, 150), "w": (255, 255, 236)})


def vagalume():
    return icone_mascara([
        "..o..",
        ".oyo.",
        "oywyo",
        ".oyo.",
        "..o..",
    ], {"o": (78, 90, 26), "y": (214, 236, 84), "w": (255, 255, 214)})


ESTRELA_GRANDE = [
    ".......o.......",
    "......oho......",
    "......oho......",
    ".....ohyyo.....",
    ".....ohyyo.....",
    "ooooooyyyoooooo",
    "ohhyyyyyyyyyydo",
    ".ohyyyyyyyyydo.",
    "..oyyyyyyyydo..",
    "...oyyyyyydo...",
    "...oyyyyyydo...",
    "..ohyyyoyyydo..",
    "..oyyyo.oyydo..",
    ".oydoo...ooydo.",
    ".ooo.......ooo.",
]


def estrela_grande(cheia=True):
    """Estrela 15x15 do placar: dourada quando ganhou, apagada (mesma forma) quando não ganhou."""
    if cheia:
        cores = {"o": (150, 80, 20), "y": (255, 204, 54), "h": (255, 244, 170), "d": (226, 150, 30)}
    else:
        cores = {"o": (34, 28, 52), "y": (66, 58, 96), "h": (88, 80, 124), "d": (52, 46, 78)}
    return icone_mascara(ESTRELA_GRANDE, cores)


def main():
    salvar(piso_escola(), "assets/texturas/escola/piso_tile_nativa.png")
    salvar(chao_beco(), "assets/texturas/beco/chao_tile_nativa.png")

    escola = "assets/sprites/escola"
    cadeiras = [((112, 162, 228), (78, 124, 198), (54, 88, 150)),
                ((132, 202, 112), (90, 164, 80), (60, 120, 58)),
                ((250, 172, 92), (226, 130, 60), (176, 90, 40))]
    for n, (cadeira, item) in enumerate(zip(cadeiras, (item_caderno, item_lapis, item_maca)), 1):
        salvar_par(carteira(cadeira, item), escola, f"carteira_{n:02d}_nativa.png")
    salvar_par(armario((84, 124, 190), False), escola, "armario_01_nativa.png")
    salvar_par(armario((66, 156, 134), True), escola, "armario_02_nativa.png")
    salvar_par(estante(3), escola, "estante_01_nativa.png")
    salvar_par(estante(8), escola, "estante_02_nativa.png")
    salvar_par(planta(1), escola, "planta_01_nativa.png")
    salvar_par(planta(2), escola, "planta_02_nativa.png")
    salvar_par(banco(), escola, "banco_01_nativa.png")

    beco = "assets/sprites/beco"
    salvar_par(lixeira((128, 136, 152), False), beco, "lixeira_01_nativa.png")
    salvar_par(lixeira((74, 146, 86), True), beco, "lixeira_02_nativa.png")
    for n in (1, 2, 3):
        salvar_par(caixas(n), beco, f"caixas_{n:02d}_nativa.png")
    salvar_par(muro(40, 5), beco, "muro_01_nativa.png")
    salvar_par(muro(24, 9), beco, "muro_02_nativa.png")
    salvar_par(poste(), beco, "poste_01_nativa.png")
    salvar_par(poca(1), beco, "poca_01_nativa.png")
    salvar_par(poca(2), beco, "poca_02_nativa.png")
    salvar_par(gato(), beco, "gato_01_nativa.png")

    salvar(nuvem_escura(), "assets/sprites/nuvem/nuvem_escura_nativa.png")
    salvar(estrela(), "assets/ui/estrela_nativa.png")
    salvar(luz(), "assets/ui/luz_nativa.png")
    salvar(coracao(), "assets/ui/coracao_nativa.png")
    salvar(brilho(), "assets/ui/brilho_nativa.png")
    salvar(vagalume(), "assets/ui/vagalume_nativa.png")
    salvar(estrela_grande(True), "assets/ui/estrela_grande_nativa.png")
    salvar(estrela_grande(False), "assets/ui/estrela_grande_vazia_nativa.png")

    cima = lambda c: menina(c, MARIAS_CIMA.get(c))
    folhas4 = folhas_personagem(menina, CORES_MENINA, cima)
    salvar(folhas4[0], "assets/sprites/personagem/menina_fluida_folha_nativa.png")
    salvar(folhas16_personagem(menina, CORES_MENINA, folhas4, cima, RETOQUES16.get("menina"))[0],
           "assets/sprites/personagem/menina_fluida_folha16_nativa.png")
    for nome, desenha, cores in CRIANCAS:
        folhas4 = folhas_personagem(desenha, cores)
        folhas16 = folhas16_personagem(desenha, cores, folhas4, retoques=RETOQUES16.get(nome))
        for versao, folha4, folha16 in zip(("cor", "apagada"), folhas4, folhas16):
            salvar(folha4, f"assets/sprites/personagens/{nome}_{versao}_folha_nativa.png")
            salvar(folha16, f"assets/sprites/personagens/{nome}_{versao}_folha16_nativa.png")

    base = icone_app()
    salvar(base.resize((128, 128), Image.NEAREST), "icon.png")
    tamanhos = [16, 32, 48, 64, 128, 256]
    quadros = [base.resize((s, s), Image.BOX if s < 32 else Image.NEAREST) for s in tamanhos]
    quadros[-1].save(RAIZ / "icon.ico", sizes=[(s, s) for s in tamanhos], append_images=quadros[:-1])
    print("icon.ico  " + ", ".join(str(s) for s in tamanhos))


if __name__ == "__main__":
    main()
