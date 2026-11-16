"""Gera a arte do Protótipo 2 em pixel art: escola, beco, nuvem escura, ícones do HUD e ícone do app.

Determinístico (sementes fixas): rodar de novo gera os mesmos PNGs.
Uso (na raiz do repositório): python ferramentas/arte/gerar_arte.py
Precisa só do Pillow.
"""
import math
import random
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

    base = icone_app()
    salvar(base.resize((128, 128), Image.NEAREST), "icon.png")
    tamanhos = [16, 32, 48, 64, 128, 256]
    quadros = [base.resize((s, s), Image.BOX if s < 32 else Image.NEAREST) for s in tamanhos]
    quadros[-1].save(RAIZ / "icon.ico", sizes=[(s, s) for s in tamanhos], append_images=quadros[:-1])
    print("icon.ico  " + ", ".join(str(s) for s in tamanhos))


if __name__ == "__main__":
    main()
