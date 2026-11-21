#!/usr/bin/env python3
"""Gerador procedural das músicas e dos efeitos sonoros do Minha Luz.

Todo o som é sintetizado aqui (original), só com a biblioteca padrão do
Python 3: nada de numpy, downloads ou serviços externos. As sementes são
fixas, então a saída é sempre a mesma.

Uso, na raiz do repositório:
    python ferramentas/audio/gerar_audio.py

Gera:
    assets/audio/musica/*.wav  22050 Hz, PCM 16 bits, mono. Laços sem emenda:
        as notas, o eco e o reverb que passam do fim voltam para o começo, e a
        emenda cai num cruzamento por zero. Cada arquivo leva um bloco "smpl"
        com o laço (o Godot importa em loop no modo padrão "Detect From WAV").
    assets/audio/sfx/*.wav     32000 Hz, PCM 16 bits, mono, fades de 5 ms.
"""

import array
import cmath
import math
import operator
import os
import random
import struct
import sys
import time
import wave
from itertools import accumulate, repeat

TAU = 2.0 * math.pi
SR_MUSICA = 22050
SR_SFX = 32000
RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PASTA_MUSICA = os.path.join(RAIZ, "assets", "audio", "musica")
PASTA_SFX = os.path.join(RAIZ, "assets", "audio", "sfx")
MUSICA_RMS_DB = -20.0  # volume médio das músicas (suave)
MUSICA_PICO_DB = -3.5  # teto de pico das músicas (pedido: <= -3 dBFS)


# ------------------------------------------------------------------ básico

def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def db(x):
    return 20.0 * math.log10(max(x, 1e-12))


def somar(a, b):
    return list(map(operator.add, a, b))


def mult(a, b):
    return list(map(operator.mul, a, b))


def escalar(a, k):
    return [v * k for v in a]


def rms(x):
    return math.sqrt(math.fsum(v * v for v in x) / len(x))


def pico(x):
    return max(map(abs, x))


def parcial(f, amp, dec, n, sr, fase=0.0):
    """amp * e^(-t/dec) * sen(2*pi*f*t + fase); dec = 0: sem decaimento.
    Fasor complexo multiplicado a cada amostra (o laço roda em C)."""
    if n <= 0:
        return []
    if f <= 0.0 or f >= 0.45 * sr:  # perto de Nyquist: descarta (sem aliasing)
        return [0.0] * n
    r = math.exp(-1.0 / (dec * sr)) if dec else 1.0
    passo = cmath.rect(r, TAU * f / sr)
    return [z.imag for z in accumulate(repeat(passo, n - 1), operator.mul,
                                        initial=cmath.rect(amp, fase))]


def tom_continuo(f, amp, n, sr, fase=0.0):
    """Senoide sem decaimento com número inteiro de ciclos em n amostras (laço sem emenda)."""
    ciclos = max(1, round(f * n / sr))
    return parcial(ciclos * sr / n, amp, 0, n, sr, fase)


def envelope(n, sr, ataque, fim):
    """1.0 no meio, sobe e desce em cosseno; começa e termina em 0 (sem clique)."""
    na = min(n, max(1, int(ataque * sr)))
    nf = min(n - na, max(1, int(fim * sr)))
    sobe = [0.5 - 0.5 * math.cos(math.pi * i / na) for i in range(na)]
    desce = [0.5 + 0.5 * math.cos(math.pi * (i + 1) / nf) for i in range(nf)]
    return sobe + [1.0] * (n - na - nf) + desce


def somar_em(buf, sinal, inicio, circular):
    """Soma sinal em buf a partir de inicio. circular: o que passa do fim volta ao começo."""
    n_buf, n = len(buf), len(sinal)
    pos = 0
    if circular:
        i = inicio % n_buf
    elif inicio < 0:
        pos, i = -inicio, 0
    else:
        i = inicio
    while pos < n and i < n_buf:
        k = min(n_buf - i, n - pos)
        buf[i:i + k] = map(operator.add, buf[i:i + k], sinal[pos:pos + k])
        pos += k
        i = 0 if circular else n_buf


# ------------------------------------------------------------------ instrumentos

# Timbres: (razão da frequência, amplitude, decaimento em s) de cada parcial.
CAIXINHA = ((1.0, 1.0, 1.1), (2.0, 0.22, 0.45), (3.0, 0.07, 0.25), (5.43, 0.035, 0.09))
SINO = ((1.0, 1.0, 1.9), (2.0, 0.25, 0.8), (3.0, 0.08, 0.45), (4.0, 0.03, 0.3))
MARIMBA = ((1.0, 1.0, 0.42), (3.99, 0.2, 0.07), (9.9, 0.035, 0.025))
KALIMBA = ((1.0, 1.0, 1.5), (2.0, 0.08, 0.45), (3.0, 0.04, 0.3), (5.92, 0.07, 0.07))
CARRILHAO = ((1.0, 1.0, 1.0), (2.76, 0.28, 0.32), (5.4, 0.09, 0.12), (8.93, 0.03, 0.05))
DEDILHADO = tuple((float(k), k ** -1.5, 1.5 / (1.0 + 0.9 * (k - 1))) for k in range(1, 8))
BAIXO = ((1.0, 1.0, 0.6), (2.0, 0.3, 0.3), (3.0, 0.1, 0.18))
BRILHO = ((1.0, 1.0, 0.04), (2.0, 0.12, 0.02))


def nota(f, vel, sr, timbre, dur, ataque=0.002, fim=0.3):
    """Nota percussiva: soma de parciais que decaem, com envelope sem clique."""
    n = int(dur * sr)
    soma = [0.0] * n
    for razao, amp, dec in timbre:
        soma = somar(soma, parcial(f * razao, amp * vel, dec, n, sr))
    return mult(soma, envelope(n, sr, ataque, fim))


def pad(f, vel, sr, dur, rng, ataque=0.8, soltura=1.5, brilho=0.3):
    """Nota sustentada e macia: dois osciladores levemente desafinados (coro)."""
    n = int((dur + soltura) * sr)
    soma = [0.0] * n
    for desafino in (0.9975, 1.0025):
        for k, amp in ((1, 1.0), (2, brilho), (3, brilho * 0.4), (4, brilho * 0.15)):
            soma = somar(soma, parcial(f * desafino * k, 0.5 * amp * vel, 0, n, sr, rng.uniform(0, TAU)))
    return mult(soma, envelope(n, sr, ataque, soltura))


# ------------------------------------------------------------------ efeitos

def _estender(x, w):
    """x precedido das suas últimas w amostras (o fim da volta anterior do laço)."""
    voltas = w // len(x) + 2
    return (x * voltas)[-(w + len(x)):]


def passa_altas(x, sr, fc):
    a = math.exp(-TAU * fc / sr)
    out = [0.0] * len(x)
    lp = 0.0
    for i, v in enumerate(x):
        lp = v + a * (lp - v)
        out[i] = v - lp
    return out


def _pente(x, d, g, amort):
    buf = [0.0] * d
    out = [0.0] * len(x)
    a = 1.0 - amort
    f = 0.0
    i = 0
    for k, v in enumerate(x):
        y = buf[i]
        f = y * a + f * amort
        buf[i] = v + f * g
        out[k] = y
        i += 1
        if i == d:
            i = 0
    return out


def _passa_tudo(x, d, g=0.5):
    buf = [0.0] * d
    out = [0.0] * len(x)
    i = 0
    for k, v in enumerate(x):
        b = buf[i]
        out[k] = b - v
        buf[i] = v + b * g
        i += 1
        if i == d:
            i = 0
    return out


def reverb(x, sr, rt60, amort=0.3, circular=False):
    """Reverb leve (Schroeder/Freeverb mono): 6 filtros pente + 3 passa-tudo.
    Devolve só o sinal molhado, do tamanho de x. circular: processa antes o fim
    do laço, então a cauda do fim já está no começo (emenda inaudível)."""
    n = len(x)
    ent = _estender(x, int(2.5 * rt60 * sr)) if circular else x
    ent = passa_altas(ent, sr, 140.0)  # grave no reverb embola o som
    esc = sr / 44100.0
    soma = [0.0] * len(ent)
    for t in (1116, 1188, 1277, 1356, 1422, 1491):
        d = int(t * esc)
        soma = somar(soma, _pente(ent, d, 10.0 ** (-3.0 * d / (sr * rt60)), amort))
    for t in (556, 441, 341):
        soma = _passa_tudo(soma, int(t * esc))
    return soma[-n:]


def eco(x, sr, tempo, fb, amort=0.35, circular=False):
    """Eco com realimentação e agudos amortecidos; devolve só as repetições."""
    n = len(x)
    d = int(tempo * sr)
    if circular:
        x = _estender(x, d * math.ceil(math.log(1e-5) / math.log(fb)))
    buf = [0.0] * d
    out = [0.0] * len(x)
    a = 1.0 - amort
    f = 0.0
    i = 0
    for k, v in enumerate(x):
        f = buf[i] * a + f * amort
        buf[i] = v + f * fb
        out[k] = f
        i += 1
        if i == d:
            i = 0
    return out[-n:]


# ------------------------------------------------------------------ músicas

class Laco:
    """Música em laço: cada nota é somada num barramento circular de n amostras."""

    def __init__(self, bpm, compassos, semente):
        self.sr = SR_MUSICA
        self.spb = 60.0 / bpm
        self.n = int(round(compassos * 4 * self.spb * self.sr))
        self.rng = random.Random(semente)
        self.barramentos = {}

    def vel(self, v, variacao=0.07):
        return v * self.rng.uniform(1.0 - variacao, 1.0 + variacao)

    def tocar(self, bus, sinal, batida, humano=0.004):
        desvio = self.rng.uniform(-humano, humano) if humano else 0.0
        inicio = int(round((batida * self.spb + desvio) * self.sr))
        somar_em(self.barramentos.setdefault(bus, [0.0] * self.n), sinal, inicio, True)

    def pads(self, acordes, vozes, vel, ataque, soltura, brilho=0.3):
        """acordes: lista de (nome, batida inicial, duração em batidas)."""
        for nome, batida, dur in acordes:
            for m in vozes[nome]:
                self.tocar("pad", pad(hz(m), vel, self.sr, dur * self.spb, self.rng, ataque, soltura, brilho),
                           batida, humano=0)

    def mixar(self, envios, rt60, mix_reverb, ecos=None):
        """Soma os barramentos (com eco), aplica o reverb circular e normaliza."""
        seco = [0.0] * self.n
        envio = [0.0] * self.n
        for nome, sinal in self.barramentos.items():
            if ecos and nome in ecos:
                batidas, fb, nivel = ecos[nome]
                sinal = somar(sinal, escalar(eco(sinal, self.sr, batidas * self.spb, fb, circular=True), nivel))
            seco = somar(seco, sinal)
            envio = somar(envio, escalar(sinal, envios.get(nome, 0.0)))
        molhado = reverb(envio, self.sr, rt60, circular=True)
        final = somar(seco, escalar(molhado, mix_reverb * rms(seco) / rms(molhado)))
        niveis = " ".join("%s %+.1f" % (nome, db(rms(s) / rms(final))) for nome, s in self.barramentos.items())
        ganho = min(10 ** (MUSICA_RMS_DB / 20) / rms(final), 10 ** (MUSICA_PICO_DB / 20) / pico(final))
        return girar_para_zero(escalar(final, ganho)), niveis


def girar_para_zero(x):
    """Começa o laço 5 a 18 ms antes do 1º tempo, num cruzamento por zero: a emenda
    fica sem salto e o ataque das notas do 1º tempo cabe inteiro no arquivo."""
    n = len(x)
    r = min(range(-400, -100), key=lambda k: abs(x[k - 1]) + abs(x[k])) % n
    return x[r:] + x[:r]


def em_compassos(nomes, batidas=4):
    return [(nome, batidas * c, batidas) for c, nome in enumerate(nomes)]


def musica_menu():
    """Esperançosa e quente: caixinha de música em arpejos sobre pad, C-Am-F-G, 72 BPM."""
    lp = Laco(72, 8, 101)
    sr = lp.sr
    nomes = ["C", "Am", "F", "G"] * 2
    lp.pads(em_compassos(nomes), {"C": (48, 55, 64), "Am": (45, 52, 60), "F": (41, 48, 57), "G": (43, 50, 59)},
            0.16, 0.8, 1.5)
    arpejo = {"C": (60, 64, 67, 72, 76, 79), "Am": (57, 60, 64, 69, 72, 76),
              "F": (53, 57, 60, 65, 69, 72), "G": (55, 59, 62, 67, 71, 74)}
    padroes = ((0, 2, 3, 4, 5, 4, 3, 2), (0, 3, 4, 5, 4, 3, 2, 1))
    for c, nome in enumerate(nomes):
        for i, idx in enumerate(padroes[c // 4]):
            v = 0.31 if i == 0 else (0.24 if i % 2 == 0 else 0.2)
            lp.tocar("caixinha", nota(hz(arpejo[nome][idx]), lp.vel(v), sr, CAIXINHA, 3.2, fim=0.4), 4 * c + 0.5 * i)
    melodia = ((0, 76), (3, 74), (4, 72), (6, 76), (8, 77), (10, 76), (11, 74), (12, 74),
               (16, 76), (18, 79), (20, 84), (22, 83), (23, 81), (24, 81), (26, 79), (27, 77), (28, 79))
    for b, m in melodia:
        lp.tocar("melodia", nota(hz(m), lp.vel(0.38, 0.05), sr, SINO, 4.0, ataque=0.006, fim=0.6), b)
    return lp.mixar({"pad": 0.5, "caixinha": 0.8, "melodia": 0.8}, rt60=2.6, mix_reverb=0.5)


def musica_fase1():
    """O Campo: calma, melancolia gentil; pad + melodia dedilhada lenta, Ré menor/Fá maior, 68 BPM."""
    lp = Laco(68, 8, 202)
    sr = lp.sr
    nomes = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"]
    lp.pads(em_compassos(nomes), {"Dm": (50, 57, 65), "Bb": (46, 53, 62), "F": (41, 48, 57), "C": (48, 55, 64),
                                  "Gm": (43, 50, 58), "A": (45, 52, 61)}, 0.17, 1.0, 1.8, brilho=0.25)
    raiz = {"Dm": 38, "Bb": 46, "F": 41, "C": 36, "Gm": 43, "A": 45}
    for c, nome in enumerate(nomes):
        lp.tocar("baixo", nota(hz(raiz[nome]), lp.vel(0.3), sr, DEDILHADO, 3.0, ataque=0.004, fim=0.6), 4 * c)
    melodia = ((0, 74), (1.5, 72), (2, 69), (4, 70), (5, 69), (6, 65), (8, 69), (9.5, 67), (10, 65), (11, 69),
               (12, 67), (15, 64), (16, 65), (17, 69), (18, 74), (20, 77), (21.5, 74), (22, 70),
               (24, 74), (25, 72), (26, 70), (27, 67), (28, 69), (30, 73), (31, 76))
    for b, m in melodia:
        lp.tocar("dedilhado", nota(hz(m), lp.vel(0.36), sr, DEDILHADO, 3.5, ataque=0.003, fim=0.5), b)
    return lp.mixar({"pad": 0.5, "dedilhado": 0.7, "baixo": 0.2}, rt60=2.8, mix_reverb=0.5,
                    ecos={"dedilhado": (0.75, 0.3, 0.35)})


def musica_fase2():
    """A Escola: mais movimento; marimba + baixo pulsando leve, Mi menor, 80 BPM."""
    lp = Laco(80, 8, 303)
    sr = lp.sr
    nomes = ["Em", "C", "G", "D", "Em", "C", "Am", "D"]
    lp.pads(em_compassos(nomes), {"Em": (52, 59, 67), "C": (48, 55, 64), "G": (43, 50, 59), "D": (50, 57, 66),
                                  "Am": (45, 52, 60)}, 0.08, 0.6, 1.2, brilho=0.25)
    marimba = {"Em": (64, 67, 71, 76), "C": (64, 67, 72, 76), "G": (62, 67, 71, 74), "D": (62, 66, 69, 74),
               "Am": (64, 69, 72, 76)}
    raiz = {"Em": 40, "C": 36, "G": 43, "D": 38, "Am": 45}
    ostinato = ((0, 0.9), (2, 0.55), (3, 0.7), (1, 0.55), (2, 0.8), (3, 0.55), (1, 0.65), (2, 0.5))
    pulso = (1.0, 0.45, 0.7, 0.45, 0.9, 0.45, 0.7, 0.45)
    for c, nome in enumerate(nomes):
        for i, (idx, v) in enumerate(ostinato):
            lp.tocar("marimba", nota(hz(marimba[nome][idx]), lp.vel(0.3 * v), sr, MARIMBA, 1.3, ataque=0.0015,
                                     fim=0.15), 4 * c + 0.5 * i)
        for i, v in enumerate(pulso):
            lp.tocar("baixo", nota(hz(raiz[nome]), lp.vel(0.21 * v), sr, BAIXO, 0.34, ataque=0.008, fim=0.1),
                     4 * c + 0.5 * i, humano=0.002)
    melodia = ((16, 79), (17, 78), (17.5, 76), (18, 71), (20, 72), (21, 76), (22, 79), (24, 81), (25, 79),
               (25.5, 76), (26, 72), (28, 74), (29, 78), (30, 81), (31, 78))
    for b, m in melodia:
        lp.tocar("melodia", nota(hz(m), lp.vel(0.42), sr, MARIMBA, 1.3, ataque=0.0015, fim=0.15), b)
    return lp.mixar({"pad": 0.4, "marimba": 0.45, "melodia": 0.6, "baixo": 0.05}, rt60=2.0, mix_reverb=0.4,
                    ecos={"melodia": (0.75, 0.25, 0.3)})


def musica_fase3():
    """O Beco: mais escura mas segura; drone grave quente + kalimba lenta com espaço, Lá menor, 60 BPM."""
    lp = Laco(60, 8, 404)
    n, sr = lp.n, lp.sr
    drone = [0.0] * n
    for m, amp in ((45, 0.2), (52, 0.11), (57, 0.06)):
        for desafino in (-0.12, 0.12):
            for k, a in ((1, 1.0), (2, 0.22), (3, 0.06)):
                drone = somar(drone, tom_continuo((hz(m) + desafino) * k, 0.5 * amp * a, n, sr, lp.rng.uniform(0, TAU)))
    respira = tom_continuo(2.0 * sr / n, 1.0, n, sr)  # 2 ciclos por volta do laço
    lp.barramentos["drone"] = [v * (0.82 + 0.18 * r) for v, r in zip(drone, respira)]
    lp.pads([("Am", 0, 8), ("F", 8, 8), ("Dm", 16, 8), ("Esus4", 24, 8)],
            {"Am": (57, 60, 64), "F": (57, 60, 65), "Dm": (57, 62, 65), "Esus4": (57, 59, 64)}, 0.08, 2.0, 2.5,
            brilho=0.2)
    melodia = ((0, 76), (1.5, 72), (2.5, 69), (4, 74), (5, 72), (6, 69), (8, 72), (9.5, 69), (10.5, 65),
               (12, 67), (14, 69), (16, 74), (17, 77), (18.5, 76), (20, 74), (22, 69),
               (24, 76), (25.5, 74), (26.5, 71), (28, 69), (30, 64))
    for b, m in melodia:
        lp.tocar("kalimba", nota(hz(m), lp.vel(0.4), sr, KALIMBA, 3.8, ataque=0.002, fim=0.6), b)
    return lp.mixar({"kalimba": 0.7, "pad": 0.5, "drone": 0.15}, rt60=3.5, mix_reverb=0.55,
                    ecos={"kalimba": (0.75, 0.35, 0.4)})


def musica_vitoria():
    """Vitória: alegre, Ré maior, arpejos subindo + carrilhão, 96 BPM."""
    lp = Laco(96, 8, 505)
    sr = lp.sr
    nomes = ["D", "G", "Bm", "A", "D", "G", "Em", "A"]
    lp.pads(em_compassos(nomes), {"D": (50, 57, 66), "G": (47, 55, 62), "Bm": (47, 54, 62), "A": (45, 52, 61),
                                  "Em": (52, 59, 67)}, 0.08, 0.3, 0.8, brilho=0.4)
    arpejo = {"D": (62, 66, 69, 74, 78, 81), "G": (62, 67, 71, 74, 79, 83), "Bm": (62, 66, 71, 74, 78, 83),
              "A": (61, 64, 69, 73, 76, 81), "Em": (59, 64, 67, 71, 76, 79)}
    carrilhao = {"D": (86, 81), "G": (83, 79), "Bm": (86, 78), "A": (85, 81), "Em": (83, 79)}
    raiz = {"D": 38, "G": 43, "Bm": 47, "A": 45, "Em": 40}
    for c, nome in enumerate(nomes):
        b0 = 4 * c
        for corrida in (0, 2):  # duas subidas em tercinas por compasso
            for i, m in enumerate(arpejo[nome]):
                lp.tocar("arpejo", nota(hz(m), lp.vel(0.17 + 0.017 * i), sr, CAIXINHA, 2.6, fim=0.4),
                         b0 + corrida + i / 3)
        for meio, m in zip((0, 2), carrilhao[nome]):
            lp.tocar("carrilhao", nota(hz(m), lp.vel(0.34), sr, CARRILHAO, 2.6, ataque=0.0015, fim=0.4), b0 + meio)
        for q in range(4):  # baixo saltando de oitava
            lp.tocar("baixo", nota(hz(raiz[nome] + 12 * (q % 2)), lp.vel(0.34 if q % 2 == 0 else 0.24), sr, BAIXO,
                                   0.5, ataque=0.006, fim=0.12), b0 + q, humano=0.002)
    return lp.mixar({"arpejo": 0.6, "carrilhao": 0.8, "pad": 0.4, "baixo": 0.05}, rt60=2.0, mix_reverb=0.4)


def musica_game_over():
    """Fim de jogo: suave, acolhedora; menor que resolve num acorde maior (Am-F-Dm/G-C), 56 BPM."""
    lp = Laco(56, 4, 606)
    sr = lp.sr
    lp.pads([("Am", 0, 4), ("F", 4, 4), ("Dm", 8, 2), ("G", 10, 2), ("C", 12, 4)],
            {"Am": (45, 52, 60), "F": (41, 48, 57), "Dm": (50, 57, 65), "G": (43, 50, 59), "C": (48, 55, 64)},
            0.15, 0.9, 2.0, brilho=0.25)
    acompanha = ((0, 57), (1, 64), (2, 69), (3, 64), (4, 53), (5, 60), (6, 65), (7, 60), (8, 62), (9, 57),
                 (10, 55), (11, 62), (12, 48), (13, 55), (14, 60), (15, 64))
    for b, m in acompanha:
        lp.tocar("caixinha", nota(hz(m), lp.vel(0.16), sr, CAIXINHA, 3.2, fim=0.4), b)
    melodia = ((0, 72), (1.5, 71), (2, 69), (4, 69), (5, 72), (6, 76), (8, 74), (10, 71), (11, 74),
               (12, 76), (13, 74), (14, 72))
    for b, m in melodia:
        lp.tocar("melodia", nota(hz(m), lp.vel(0.3, 0.05), sr, SINO, 4.0, ataque=0.008, fim=0.7), b)
    return lp.mixar({"pad": 0.5, "caixinha": 0.7, "melodia": 0.8}, rt60=3.0, mix_reverb=0.55)


# ------------------------------------------------------------------ músicas do Protótipo 4

def bumbo(sr):
    """Bumbo macio (o pulso da música final): senoide que cai de ~125 para 52 Hz, sem estalo."""
    n = int(0.28 * sr)
    out = [0.0] * n
    fase = 0.0
    for i in range(n):
        t = i / sr
        fase += TAU * (52.0 + 73.0 * math.exp(-t / 0.028)) / sr
        out[i] = math.exp(-t / 0.085) * (math.sin(fase) + 0.3 * math.sin(2 * fase))
    return mult(out, envelope(n, sr, 0.004, 0.05))


def chiado(sr, rng, dur, tau, graves, agudos):
    """Toque de ruído entre `graves` e `agudos` (Hz) que some rápido: chocalho ou palma macia."""
    n = int(dur * sr)
    x = passa_altas([rng.uniform(-1.0, 1.0) for _ in range(n)], sr, graves)
    a = 1.0 - math.exp(-TAU * agudos / sr)
    lp = 0.0
    for i, v in enumerate(x):
        lp += a * (v - lp)
        x[i] = lp * math.exp(-i / (tau * sr))
    return mult(x, envelope(n, sr, 0.002, 0.02))


def musica_final():
    """A menina brilha e as palavras boas vencem: animada e esperançosa, com pulso; Dó maior
    (C-G-Am-F / C-G-F-G), 120 BPM. Bumbo macio em todo tempo, palma leve no 2 e no 4, chocalho
    no contratempo, baixo em colcheias saltando de oitava, marimba e melodia de caixinha com sinos."""
    lp = Laco(120, 8, 707)
    sr = lp.sr
    nomes = ["C", "G", "Am", "F", "C", "G", "F", "G"]
    lp.pads(em_compassos(nomes), {"C": (48, 55, 64), "G": (43, 50, 59), "Am": (45, 52, 60), "F": (41, 48, 57)},
            0.09, 0.3, 0.8, brilho=0.4)
    marimba = {"C": (60, 64, 67, 72), "G": (59, 62, 67, 71), "Am": (60, 64, 69, 72), "F": (60, 65, 69, 72)}
    raiz = {"C": 36, "G": 43, "Am": 45, "F": 41}
    sinos = (88, 86, 84, 84, 88, 86, 89, 86)  # 1º tempo de cada compasso, junto com a melodia
    ostinato = ((0, 0.9), (2, 0.5), (1, 0.65), (3, 0.8), (2, 0.5), (1, 0.7), (3, 0.6), (2, 0.5))
    toque = bumbo(sr)
    for c, nome in enumerate(nomes):
        b0 = 4 * c
        graves = (43, 43, 45, 47) if c == 7 else (raiz[nome],) * 4  # no fim o baixo sobe de volta ao Dó
        for i, (idx, v) in enumerate(ostinato):
            lp.tocar("marimba", nota(hz(marimba[nome][idx]), lp.vel(0.34 * v), sr, MARIMBA, 1.0, ataque=0.0015,
                                     fim=0.15), b0 + 0.5 * i)
        for q, grave in enumerate(graves):
            lp.tocar("baixo", nota(hz(grave), lp.vel(0.32), sr, BAIXO, 0.34, ataque=0.006, fim=0.1), b0 + q,
                     humano=0.002)
            lp.tocar("baixo", nota(hz(grave + 12), lp.vel(0.2), sr, BAIXO, 0.3, ataque=0.006, fim=0.1),
                     b0 + q + 0.5, humano=0.002)
            lp.tocar("bumbo", escalar(toque, 0.42 if q % 2 == 0 else 0.34), b0 + q, humano=0)
            lp.tocar("chocalho", escalar(chiado(sr, lp.rng, 0.06, 0.016, 4000.0, 9000.0), lp.vel(0.7, 0.2)),
                     b0 + q + 0.5)
            if q % 2 == 1:
                lp.tocar("palma", escalar(chiado(sr, lp.rng, 0.11, 0.028, 900.0, 2800.0), lp.vel(0.7, 0.1)), b0 + q)
        lp.tocar("sinos", nota(hz(sinos[c]), lp.vel(0.26), sr, CARRILHAO, 2.2, ataque=0.0015, fim=0.4), b0)
    melodia = ((0, 76), (1, 79), (1.5, 84), (2.5, 88), (3, 86), (3.5, 84),
               (4, 86), (5.5, 83), (6, 79), (7, 81), (7.5, 83),
               (8, 84), (9, 88), (9.5, 84), (10.5, 81), (11, 84), (11.5, 86),
               (12, 84), (13, 81), (13.5, 77), (14.5, 81), (15, 79),
               (16, 76), (17, 79), (17.5, 84), (18.5, 88), (19, 91), (19.5, 88),
               (20, 86), (21, 91), (21.5, 86), (22.5, 83), (23, 86),
               (24, 89), (25, 88), (25.5, 84), (26.5, 81), (27, 84), (27.5, 88),
               (28, 86), (29, 83), (29.5, 86), (30.5, 91))
    for b, m in melodia:
        lp.tocar("melodia", nota(hz(m), lp.vel(0.3, 0.05), sr, CAIXINHA, 1.6, ataque=0.002, fim=0.3), b)
    return lp.mixar({"pad": 0.4, "marimba": 0.45, "melodia": 0.6, "sinos": 0.8, "baixo": 0.05, "palma": 0.3,
                     "chocalho": 0.1}, rt60=1.8, mix_reverb=0.35, ecos={"melodia": (0.75, 0.22, 0.3)})


def musica_historia():
    """Cenas de história: calma e terna, como uma canção de ninar; caixinha de música em 3/4
    sobre pad, Fá maior (F-Dm-Bb-C / F-Am-Bb-C), 72 BPM."""
    lp = Laco(72, 6, 808)  # 24 tempos = 8 compassos de 3/4 (20 s)
    sr = lp.sr
    nomes = ["F", "Dm", "Bb", "C", "F", "Am", "Bb", "C"]
    lp.pads(em_compassos(nomes, 3), {"F": (41, 48, 57), "Dm": (50, 57, 65), "Bb": (46, 53, 62), "C": (48, 55, 64),
                                     "Am": (45, 52, 60)}, 0.15, 0.9, 1.8, brilho=0.25)
    arpejo = {"F": (53, 60, 65, 69), "Dm": (50, 57, 62, 65), "Bb": (46, 53, 58, 62), "C": (48, 55, 60, 64),
              "Am": (45, 52, 57, 60)}
    for c, nome in enumerate(nomes):
        for i, idx in enumerate((0, 1, 2, 3, 2, 1)):  # colcheias: sobe e desce o acorde
            lp.tocar("caixinha", nota(hz(arpejo[nome][idx]), lp.vel(0.27 if i == 0 else 0.19), sr, CAIXINHA, 3.2,
                                      fim=0.4), 3 * c + 0.5 * i)
    melodia = ((0, 81), (2, 84), (3, 81), (5, 77), (6, 74), (7, 77), (8, 82), (9, 79), (11, 76),
               (12, 81), (14, 84), (15, 88), (17, 84), (18, 86), (19, 82), (20, 77), (21, 79), (22, 76), (23, 79))
    for b, m in melodia:
        lp.tocar("melodia", nota(hz(m), lp.vel(0.34, 0.05), sr, SINO, 4.0, ataque=0.006, fim=0.6), b)
    return lp.mixar({"pad": 0.5, "caixinha": 0.8, "melodia": 0.8}, rt60=2.8, mix_reverb=0.5)


MUSICAS = (("menu", musica_menu), ("fase1", musica_fase1), ("fase2", musica_fase2), ("fase3", musica_fase3),
           ("vitoria", musica_vitoria), ("game_over", musica_game_over), ("final", musica_final),
           ("historia", musica_historia))


# ------------------------------------------------------------------ efeitos sonoros (32 kHz)

def novo(dur):
    return [0.0] * int(dur * SR_SFX)


def colocar(buf, sinal, t):
    somar_em(buf, sinal, int(round(t * SR_SFX)), False)


def com_reverb(x, rt60, mix):
    molhado = reverb(x, SR_SFX, rt60, amort=0.35)
    return somar(x, escalar(molhado, mix * rms(x) / rms(molhado)))


def fade_fim(x, seg):
    nf = min(len(x), int(seg * SR_SFX))
    ini = len(x) - nf
    for i in range(nf):
        x[ini + i] *= 0.5 + 0.5 * math.cos(math.pi * (i + 1) / nf)
    return x


def baque(dur, f_ini, f_fim, tau_f, tau_a):
    """Baque grave e macio: senoide com queda de afinação e harmônicos (audível em caixinha de som)."""
    sr = SR_SFX
    n = int(dur * sr)
    out = [0.0] * n
    fase = 0.0
    for i in range(n):
        t = i / sr
        fase += TAU * (f_fim + (f_ini - f_fim) * math.exp(-t / tau_f)) / sr
        out[i] = math.exp(-t / tau_a) * (math.sin(fase) + 0.45 * math.sin(2 * fase) + 0.18 * math.sin(3 * fase))
    return mult(out, envelope(n, sr, 0.005, 0.03))


def brilhos(buf, rng, notas, t_ini, t_fim, qtd, amp):
    """Pinguinhos agudos (notas do acorde) espalhados entre t_ini e t_fim."""
    for i in range(qtd):
        t0 = t_ini + (t_fim - t_ini) * i / max(1, qtd - 1) + rng.uniform(-0.008, 0.008)
        colocar(buf, nota(hz(rng.choice(notas)), amp * rng.uniform(0.6, 1.0), SR_SFX, BRILHO, 0.2,
                          ataque=0.002, fim=0.05), max(0.0, t0))


def sfx_clique():
    """Blip redondo de interface: senoide com pequena queda de afinação, 70 ms."""
    sr = SR_SFX
    n = int(0.07 * sr)
    out = [0.0] * n
    fase = 0.0
    for i in range(n):
        t = i / sr
        fase += TAU * (640.0 + 240.0 * math.exp(-t / 0.018)) / sr
        out[i] = math.exp(-t / 0.028) * (math.sin(fase) + 0.12 * math.sin(2 * fase))
    return out, -6.0


def sfx_foco():
    """Tique bem suave de foco, 40 ms, ~10 dB abaixo do clique."""
    sr = SR_SFX
    n = int(0.04 * sr)
    out = [0.0] * n
    fase = 0.0
    for i in range(n):
        t = i / sr
        fase += TAU * (1150.0 + 150.0 * math.exp(-t / 0.01)) / sr
        out[i] = math.exp(-t / 0.011) * math.sin(fase)
    return out, -16.0


def sfx_frase_boa():
    """Arpejo de sininho subindo (Dó maior) com cintilar, ~0,75 s."""
    rng = random.Random(11)
    buf = novo(0.75)
    timbre = ((1.0, 1.0, 0.42), (1.0047, 0.45, 0.42), (0.9962, 0.3, 0.3), (2.0, 0.16, 0.2), (3.0, 0.05, 0.1))
    for k, m in enumerate((72, 76, 79, 84)):
        t0 = 0.075 * k
        colocar(buf, nota(hz(m), 0.5 + 0.08 * k, SR_SFX, timbre, 0.75 - t0, ataque=0.002, fim=0.15), t0)
    brilhos(buf, rng, (91, 96, 100, 103), 0.06, 0.55, 14, 0.07)
    buf = com_reverb(buf, 0.8, 0.35)
    return fade_fim(buf, 0.15), -3.0


def sfx_procurar():
    """Poder "Procurar": dois sininhos suaves subindo (uma quinta) com cintilar, ~0,6 s."""
    rng = random.Random(17)
    buf = novo(0.6)
    timbre = ((1.0, 1.0, 0.35), (2.0, 0.22, 0.2), (3.01, 0.06, 0.12))
    for k, m in enumerate((81, 88)):
        t0 = 0.11 * k
        colocar(buf, nota(hz(m), 0.45, SR_SFX, timbre, 0.6 - t0, ataque=0.003, fim=0.2), t0)
    brilhos(buf, rng, (93, 96, 100), 0.12, 0.45, 6, 0.05)
    buf = com_reverb(buf, 0.7, 0.3)
    return fade_fim(buf, 0.15), -5.0


def sfx_dano():
    """Baque grave e macio + oscilação desafinada curta descendo, ~0,45 s (sem assustar)."""
    sr = SR_SFX
    buf = novo(0.45)
    colocar(buf, baque(0.3, 150.0, 58.0, 0.035, 0.085), 0.0)
    m = int(0.36 * sr)
    out = [0.0] * m
    f1 = f2 = 0.0
    for i in range(m):
        t = i / sr
        f = 420.0 * 2.0 ** (-1.6 * t) * (1.0 + 0.02 * math.sin(TAU * 9.0 * t))
        f1 += TAU * f / sr
        f2 += TAU * f * 1.025 / sr  # 2,5% de desafino: batimento ~10 Hz
        out[i] = 0.3 * (math.sin(f1) + math.sin(f2) + 0.15 * math.sin(2 * f1))
    colocar(buf, mult(out, envelope(m, sr, 0.015, 0.22)), 0.04)
    return fade_fim(buf, 0.05), -4.0


def sfx_luz_apagando():
    """A luz se apagando: deslize descendo com cintilar que some, ~1,6 s."""
    sr = SR_SFX
    rng = random.Random(33)
    n = int(1.6 * sr)
    out = [0.0] * n
    p1 = p2 = pt = 0.0
    for i in range(n):
        x = i / n
        f = 880.0 * 0.25 ** (x ** 0.8)  # 880 -> 220 Hz
        p1 += TAU * f / sr
        p2 += TAU * f * 1.006 / sr  # +10 cents: cintilar lento
        pt += TAU * (7.0 - 4.0 * x) / sr
        trem = 1.0 - 0.3 * (1.0 - x) * (0.5 - 0.5 * math.cos(pt))
        out[i] = (1.0 - x) ** 1.6 * trem * (0.6 * math.sin(p1) + 0.4 * math.sin(p2) + 0.12 * math.sin(2 * p1))
    brilhos(out, rng, (96, 91, 88, 84, 79), 0.02, 0.8, 12, 0.08)
    out = com_reverb(out, 1.0, 0.3)
    return fade_fim(out, 0.25), -3.0


def sfx_pulso():
    """Batimento de coração suave: dois baques graves (~55-85 Hz), ~0,5 s."""
    buf = novo(0.5)
    colocar(buf, baque(0.2, 85.0, 58.0, 0.03, 0.055), 0.0)
    colocar(buf, escalar(baque(0.22, 78.0, 54.0, 0.03, 0.06), 0.75), 0.21)
    return fade_fim(buf, 0.04), -3.0


def sfx_nuvem():
    """A nuvem se desfaz: sopro (ruído filtrado que cresce) + cintilar subindo, ~2,2 s."""
    sr = SR_SFX
    rng = random.Random(44)
    dur = 2.2
    n = int(dur * sr)
    out = [0.0] * n
    low = band = suave = 0.0
    a = 1.0 - math.exp(-TAU * 2500.0 / sr)  # passa-baixas extra: sopro sem chiado
    for i in range(n):
        x = i / n
        env = math.sin(0.5 * math.pi * x / 0.45) ** 2 if x < 0.45 else (1.0 - (x - 0.45) / 0.55) ** 1.5
        fq = 2.0 * math.sin(math.pi * (350.0 + 1250.0 * math.sin(math.pi * x) ** 1.5) / sr)
        low += fq * band  # filtro de estado variável (passa-faixa)
        band += fq * (rng.uniform(-1.0, 1.0) - low - 1.2 * band)
        suave += a * (band - suave)
        out[i] = 0.5 * env * suave
    timbre = ((1.0, 1.0, 0.5), (1.0058, 0.5, 0.5), (2.0, 0.15, 0.2), (2.76, 0.05, 0.08))
    notas = (72, 74, 76, 79, 81, 84, 86, 88, 91)  # pentatônica de Dó subindo
    for k, m in enumerate(notas):
        t0 = 0.45 + 0.13 * k
        amp = 0.18 * (0.6 + 0.4 * math.sin(math.pi * (k + 0.5) / len(notas)))
        colocar(out, nota(hz(m), amp, sr, timbre, dur - t0, fim=0.2), t0)
    out = com_reverb(out, 1.3, 0.4)
    return fade_fim(out, 0.35), -3.0


def sfx_fase_completa():
    """Vinheta de vitória: arpejo maior rápido + sino, ~2,5 s."""
    sr = SR_SFX
    rng = random.Random(55)
    dur = 2.5
    buf = novo(dur)
    for k, m in enumerate((60, 64, 67, 72, 76, 79)):
        t0 = 0.065 * k
        colocar(buf, nota(hz(m), 0.3 + 0.03 * k, sr, CAIXINHA, 1.6, fim=0.3), t0)
    t_sino = 0.42
    for m, v in ((72, 0.3), (76, 0.26), (79, 0.24), (84, 0.3)):
        colocar(buf, nota(hz(m), v, sr, SINO, dur - t_sino, ataque=0.003, fim=0.6), t_sino)
    for m in (48, 55):
        colocar(buf, pad(hz(m), 0.14, sr, 1.0, rng, ataque=0.06, soltura=1.0), 0.4)
    brilhos(buf, rng, (91, 96, 100), 0.45, 1.3, 10, 0.05)
    buf = com_reverb(buf, 1.6, 0.35)
    return fade_fim(buf, 0.5), -2.0


def sfx_aviso():
    """Aviso gentil: tom grave suave, oscilando, com tremolo, ~0,6 s."""
    sr = SR_SFX
    n = int(0.6 * sr)
    out = [0.0] * n
    fase = 0.0
    for i in range(n):
        t = i / sr
        f = 233.0 * (1.0 + 0.012 * math.sin(TAU * 5.0 * t)) * (1.0 - 0.1 * t)
        fase += TAU * f / sr
        trem = 0.65 + 0.35 * math.cos(TAU * 7.0 * t)
        out[i] = trem * (math.sin(fase) + 0.3 * math.sin(2 * fase) + 0.08 * math.sin(3 * fase))
    return mult(out, envelope(n, sr, 0.03, 0.22)), -5.0


def sfx_dissolver():
    """Frase ruim se desfazendo: "puf" macio + brilhos descendo, ~0,6 s."""
    sr = SR_SFX
    rng = random.Random(66)
    dur = 0.6
    n = int(dur * sr)
    out = [0.0] * n
    l1 = l2 = 0.0
    for i in range(n):
        t = i / sr
        a = 1.0 - math.exp(-TAU * (250.0 + 1250.0 * math.exp(-t / 0.08)) / sr)
        l1 += a * (rng.uniform(-1.0, 1.0) - l1)
        l2 += a * (l1 - l2)
        out[i] = 1.4 * l2 * min(1.0, t / 0.006) * math.exp(-t / 0.07)
    timbre = ((1.0, 1.0, 0.12), (2.76, 0.18, 0.04))
    for k, m in enumerate((88, 84, 81, 79, 76, 72)):
        t0 = 0.05 + 0.065 * k
        colocar(out, nota(hz(m), 0.14 * (1.0 - 0.08 * k), sr, timbre, dur - t0, ataque=0.002, fim=0.05), t0)
    out = com_reverb(out, 0.7, 0.3)
    return fade_fim(out, 0.12), -4.0


# ------------------------------------------------------------------ efeitos sonoros do Protótipo 4

def sopro(dur, rng, f_ini, f_fim, pico_em, corte=2500.0):
    """Sopro de ar: ruído num passa-faixa que desliza de f_ini a f_fim (Hz); cresce até
    pico_em (fração da duração) e some. O passa-baixas em `corte` tira o chiado."""
    sr = SR_SFX
    n = int(dur * sr)
    out = [0.0] * n
    low = band = suave = 0.0
    a = 1.0 - math.exp(-TAU * corte / sr)
    for i in range(n):
        x = i / n
        if x < pico_em:
            env = math.sin(0.5 * math.pi * x / pico_em) ** 2
        else:
            env = ((1.0 - x) / (1.0 - pico_em)) ** 1.5
        fq = 2.0 * math.sin(math.pi * f_ini * (f_fim / f_ini) ** x / sr)
        low += fq * band  # filtro de estado variável (passa-faixa)
        band += fq * (rng.uniform(-1.0, 1.0) - low - 1.2 * band)
        suave += a * (band - suave)
        out[i] = env * suave
    return out


def sfx_vagalume():
    """Vaga-lume pego: blip brilhante e limpo (Dó agudo com uma subidinha no ataque), ~0,12 s.
    Poucos harmônicos, pois o jogo o toca com pitch_scale de 1,0 a 1,6 (combo): a fundamental
    vai de ~1,05 a ~1,7 kHz sem ficar estridente. Sem ruído: não usa semente."""
    sr = SR_SFX
    n = int(0.12 * sr)
    out = [0.0] * n
    fase = 0.0
    for i in range(n):
        t = i / sr
        fase += TAU * 1046.5 * (1.0 - 0.2 * math.exp(-t / 0.012)) / sr
        out[i] = (math.exp(-t / 0.032) * math.sin(fase) + 0.2 * math.exp(-t / 0.02) * math.sin(2 * fase)
                  + 0.05 * math.exp(-t / 0.012) * math.sin(3 * fase))
    return out, -6.0


def sfx_brilhar():
    """A menina brilha: sopro subindo + acorde de Dó maior abrindo do grave ao agudo + cintilar, ~0,9 s."""
    sr = SR_SFX
    rng = random.Random(72)
    dur = 0.9
    buf = novo(dur)
    colocar(buf, escalar(sopro(0.4, rng, 400.0, 2800.0, 0.5), 3.5), 0.0)
    colocar(buf, escalar(baque(0.3, 130.0, 65.0, 0.04, 0.1), 0.4), 0.12)  # calor no grave
    timbre = ((1.0, 1.0, 0.55), (1.004, 0.45, 0.55), (2.0, 0.22, 0.3), (3.0, 0.07, 0.15))
    for k, m in enumerate((60, 64, 67, 72, 76, 79, 84)):
        t0 = 0.12 + 0.035 * k
        colocar(buf, nota(hz(m), 0.3 + 0.02 * k, sr, timbre, dur - t0, ataque=0.004, fim=0.25), t0)
    for m in (48, 55, 60):
        colocar(buf, pad(hz(m), 0.16, sr, 0.3, rng, ataque=0.08, soltura=0.4, brilho=0.35), 0.1)
    brilhos(buf, rng, (91, 96, 100, 103), 0.3, 0.78, 12, 0.07)
    buf = com_reverb(buf, 1.0, 0.35)
    return fade_fim(buf, 0.25), -3.0


def sfx_fala_sombra():
    """Uma sombra falando: murmúrio grave e macio, três sílabas abafadas "uó-uó-uó" (voz sem
    palavras), ~0,45 s. Harmônicos de uma voz grave passando por duas formantes que abrem do
    "u" para o "ó"; sem agudos e sem aspereza, para não assustar."""
    sr = SR_SFX
    rng = random.Random(73)
    buf = novo(0.45)
    for t0, dur, f0 in ((0.0, 0.16, 172.0), (0.14, 0.16, 160.0), (0.28, 0.17, 146.0)):
        n = int(dur * sr)
        f0 *= rng.uniform(0.985, 1.015)
        silaba = [0.0] * n
        fase = 0.0
        for i in range(n):
            x = i / n
            abre = min(1.0, x / 0.45)  # a boca abre: "u" -> "ó"
            f = f0 * (1.0 + 0.06 * math.sin(math.pi * x) - 0.03 * x)
            fase += TAU * f / sr
            f1 = 300.0 + 250.0 * abre
            f2 = 720.0 + 200.0 * abre
            s = 0.0
            for k in range(1, 9):
                ganho = 1.0 / (1.0 + ((k * f - f1) / 90.0) ** 2) + 0.35 / (1.0 + ((k * f - f2) / 110.0) ** 2)
                s += ganho / k * math.sin(k * fase)
            silaba[i] = s * (0.55 + 0.45 * abre)
        colocar(buf, mult(silaba, envelope(n, sr, 0.03, 0.07)), t0)
    return fade_fim(buf, 0.05), -8.0


def sfx_amigo():
    """Uma sombra vira amiga: duas notas alegres subindo (Sol -> Dó, com a terça por cima) e cintilar, ~0,5 s."""
    rng = random.Random(74)
    buf = novo(0.5)
    timbre = ((1.0, 1.0, 0.3), (1.005, 0.4, 0.3), (2.0, 0.2, 0.16), (3.0, 0.06, 0.09))
    colocar(buf, nota(hz(79), 0.45, SR_SFX, timbre, 0.5, ataque=0.003, fim=0.15), 0.0)
    colocar(buf, nota(hz(84), 0.5, SR_SFX, timbre, 0.37, ataque=0.003, fim=0.15), 0.13)
    colocar(buf, nota(hz(88), 0.22, SR_SFX, timbre, 0.37, ataque=0.003, fim=0.15), 0.13)
    brilhos(buf, rng, (96, 100, 103), 0.17, 0.4, 7, 0.06)
    buf = com_reverb(buf, 0.7, 0.3)
    return fade_fim(buf, 0.12), -4.0


def sfx_palavra_boa():
    """Uma palavra boa sendo lançada: sopro leve subindo + brilho na ponta, ~0,25 s.
    Curto e baixo (toca muitas vezes seguidas)."""
    rng = random.Random(75)
    buf = novo(0.25)
    colocar(buf, sopro(0.22, rng, 700.0, 2400.0, 0.35, corte=3000.0), 0.0)
    timbre = ((1.0, 1.0, 0.09), (2.0, 0.15, 0.04))
    for t0, m, v in ((0.07, 88, 0.16), (0.11, 91, 0.13)):
        colocar(buf, nota(hz(m), v, SR_SFX, timbre, 0.25 - t0, ataque=0.003, fim=0.06), t0)
    brilhos(buf, rng, (96, 100), 0.1, 0.19, 3, 0.05)
    return fade_fim(buf, 0.06), -8.0


def sfx_estouro():
    """Palavra ruim se desfazendo: estouro macio ("pop" que cai de 600 para 170 Hz + sopro curto)
    e uma faísca pequena, ~0,25 s. Curto (toca muitas vezes seguidas)."""
    sr = SR_SFX
    rng = random.Random(76)
    n = int(0.25 * sr)
    out = [0.0] * n
    fase = l1 = l2 = 0.0
    for i in range(n):
        t = i / sr
        fase += TAU * (170.0 + 430.0 * math.exp(-t / 0.014)) / sr
        a = 1.0 - math.exp(-TAU * (400.0 + 1800.0 * math.exp(-t / 0.03)) / sr)
        l1 += a * (rng.uniform(-1.0, 1.0) - l1)
        l2 += a * (l1 - l2)
        out[i] = (math.exp(-t / 0.035) * (math.sin(fase) + 0.25 * math.sin(2 * fase))
                  + 1.1 * l2 * min(1.0, t / 0.004) * math.exp(-t / 0.04))
    timbre = ((1.0, 1.0, 0.05), (2.76, 0.15, 0.02))
    for k, m in enumerate((91, 96, 88)):
        t0 = 0.045 + 0.04 * k + rng.uniform(-0.006, 0.006)
        colocar(out, nota(hz(m), 0.2 - 0.03 * k, sr, timbre, 0.12, ataque=0.002, fim=0.04), t0)
    return fade_fim(out, 0.06), -6.0


def sfx_nuvem_surge():
    """A nuvem aparece: onda grave crescendo (Dó em quinta aberta + nona, sem tensão), chegando
    de um tom abaixo, com ar e um brilho suave no alto, ~1,6 s. Misteriosa, não assustadora."""
    sr = SR_SFX
    rng = random.Random(77)
    dur = 1.6
    n = int(dur * sr)
    vozes = [[hz(m) * d, amp, rng.uniform(0, TAU)] for m, amp in ((36, 0.4), (48, 1.0), (55, 0.6), (62, 0.28))
             for d in (0.996, 1.004)]
    out = [0.0] * n
    for i in range(n):
        x = i / n
        if x < 0.68:
            env = math.sin(0.5 * math.pi * x / 0.68) ** 1.3
        else:
            env = 0.5 + 0.5 * math.cos(math.pi * (x - 0.68) / 0.32)
        desliza = 2.0 ** (-2.0 * (1.0 - min(1.0, x / 0.6)) ** 2 / 12.0) / sr
        s = 0.0
        for voz in vozes:
            voz[2] += TAU * voz[0] * desliza
            s += voz[1] * (math.sin(voz[2]) + 0.3 * math.sin(2 * voz[2]) + 0.1 * math.sin(3 * voz[2]))
        out[i] = env * s
    colocar(out, escalar(sopro(1.5, rng, 300.0, 1100.0, 0.7, corte=2000.0), 5.0), 0.0)
    timbre = ((1.0, 1.0, 0.5), (1.0058, 0.5, 0.5), (2.0, 0.15, 0.2))
    for t0, m in ((0.85, 79), (1.0, 86), (1.15, 91)):
        colocar(out, nota(hz(m), 0.3, sr, timbre, dur - t0, ataque=0.01, fim=0.2), t0)
    out = com_reverb(out, 1.2, 0.35)
    return fade_fim(out, 0.3), -4.0


def sfx_estrela():
    """Estrela ganha: "ding" brilhante (Dó agudo) com cintilar, ~0,4 s. O jogo toca com pitch
    1,0 / 1,12 / 1,25 na 1ª, 2ª e 3ª estrela, o que dá dó, ré, mi."""
    rng = random.Random(78)
    buf = novo(0.4)
    timbre = ((1.0, 1.0, 0.22), (1.004, 0.4, 0.22), (2.0, 0.2, 0.14), (3.0, 0.07, 0.08), (4.0, 0.03, 0.05))
    colocar(buf, nota(hz(84), 0.5, SR_SFX, timbre, 0.4, ataque=0.002, fim=0.12), 0.0)
    colocar(buf, nota(hz(96), 0.08, SR_SFX, timbre, 0.4, ataque=0.002, fim=0.12), 0.0)
    brilhos(buf, rng, (96, 100, 103), 0.05, 0.28, 6, 0.06)
    buf = com_reverb(buf, 0.6, 0.3)
    return fade_fim(buf, 0.1), -4.0


def sfx_comemoracao():
    """Comemoração: fanfarra curta e alegre em Dó maior ("tã-tã-tã-TÃ, tã-TÃÃÃ") a duas vozes,
    com sininhos e cintilar, ~2,0 s."""
    sr = SR_SFX
    rng = random.Random(79)
    dur = 2.0
    buf = novo(dur)
    corneta = tuple((float(k), k ** -1.6, 0.8 / (1.0 + 0.3 * (k - 1))) for k in range(1, 7))  # metal macio
    # (início em s, duração, notas da corneta, sininho uma oitava acima nas notas longas)
    toques = ((0.0, 0.13, (72, 67), 0), (0.13, 0.13, (72, 67), 0), (0.26, 0.13, (72, 67), 0),
              (0.39, 0.36, (76, 72), 88), (0.75, 0.17, (79, 76), 91), (0.92, 1.08, (84, 79, 76, 72), 96))
    for t0, d, notas, sininho in toques:
        for k, m in enumerate(notas):
            colocar(buf, nota(hz(m), 0.3 if k == 0 else 0.2, sr, corneta, d, ataque=0.012, fim=0.3 * d), t0)
        if sininho:
            colocar(buf, nota(hz(sininho), 0.1, sr, SINO, dur - t0, ataque=0.003, fim=0.3), t0)
    for m in (48, 55):
        colocar(buf, pad(hz(m), 0.14, sr, 0.6, rng, ataque=0.05, soltura=0.5), 0.92)
    brilhos(buf, rng, (91, 96, 100, 103), 0.95, 1.6, 12, 0.05)
    buf = com_reverb(buf, 1.2, 0.3)
    return fade_fim(buf, 0.4), -3.0


EFEITOS = (("clique", sfx_clique), ("foco", sfx_foco), ("frase_boa", sfx_frase_boa), ("dano", sfx_dano),
           ("luz_apagando", sfx_luz_apagando), ("pulso", sfx_pulso), ("nuvem", sfx_nuvem),
           ("fase_completa", sfx_fase_completa), ("aviso", sfx_aviso), ("dissolver", sfx_dissolver), ("procurar", sfx_procurar),
           ("vagalume", sfx_vagalume), ("brilhar", sfx_brilhar), ("fala_sombra", sfx_fala_sombra), ("amigo", sfx_amigo),
           ("palavra_boa", sfx_palavra_boa), ("estouro", sfx_estouro), ("nuvem_surge", sfx_nuvem_surge),
           ("estrela", sfx_estrela), ("comemoracao", sfx_comemoracao))


def finalizar_sfx(x, alvo_db):
    """Fades de 5 ms nas pontas e pico no alvo."""
    x = list(x)
    n5 = int(0.005 * SR_SFX)
    for i in range(n5):
        g = 0.5 - 0.5 * math.cos(math.pi * i / n5)
        x[i] *= g
        x[-1 - i] *= g
    return escalar(x, 10 ** (alvo_db / 20) / pico(x))


# ------------------------------------------------------------------ arquivo e conferência

def salvar_wav(caminho, sinal, sr, laco):
    """WAV PCM 16 bits mono. laco: acrescenta bloco "smpl" (laço para a frente, 0 até o fim)."""
    amostras = array.array("h", [max(-32768, min(32767, round(v * 32767.0))) for v in sinal])
    dados = amostras.tobytes() if sys.byteorder == "little" else _invertido(amostras)
    fmt = struct.pack("<HHIIHH", 1, 1, sr, sr * 2, 2, 16)
    corpo = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(dados)) + dados
    if laco:
        smpl = struct.pack("<9I", 0, 0, round(1e9 / sr), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(amostras) - 1, 0, 0)
        corpo += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(caminho, "wb") as arq:
        arq.write(b"RIFF" + struct.pack("<I", len(corpo)) + corpo)


def _invertido(amostras):
    copia = array.array("h", amostras)
    copia.byteswap()
    return copia.tobytes()


def conferir(caminho):
    """Relê o arquivo com o módulo wave e mede duração, pico, RMS, emenda e maior salto."""
    with wave.open(caminho, "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2
        sr, n = w.getframerate(), w.getnframes()
        amostras = array.array("h", w.readframes(n))
    if sys.byteorder != "little":
        amostras.byteswap()
    x = [v / 32768.0 for v in amostras]
    saltos = sorted(abs(b - a) for a, b in zip(x, x[1:]))
    return {"sr": sr, "dur": n / sr, "kb": os.path.getsize(caminho) / 1024.0, "pico": db(pico(x)),
            "rms": db(rms(x)), "emenda": abs(x[-1] - x[0]), "salto999": saltos[int(0.999 * (len(saltos) - 1))],
            "inicio": x[0], "fim": x[-1]}


def main():
    t_total = time.time()
    os.makedirs(PASTA_MUSICA, exist_ok=True)
    os.makedirs(PASTA_SFX, exist_ok=True)
    caminhos = []
    for nome, gerar in MUSICAS:
        t = time.time()
        sinal, niveis = gerar()
        caminho = os.path.join(PASTA_MUSICA, nome + ".wav")
        salvar_wav(caminho, sinal, SR_MUSICA, True)
        caminhos.append(caminho)
        print("%-10s %5.1f s  barramentos (dB vs mix): %s" % (nome, time.time() - t, niveis), flush=True)
    for nome, gerar in EFEITOS:
        sinal, alvo = gerar()
        caminho = os.path.join(PASTA_SFX, nome + ".wav")
        salvar_wav(caminho, finalizar_sfx(sinal, alvo), SR_SFX, False)
        caminhos.append(caminho)
    print()
    print("%-26s %6s %7s %7s %7s %7s %8s %8s" % ("arquivo", "Hz", "dur s", "KB", "pico", "rms", "emenda", "salto99.9"))
    total = 0.0
    problemas = []
    for caminho in caminhos:
        c = conferir(caminho)
        total += c["kb"]
        rel = os.path.relpath(caminho, os.path.join(RAIZ, "assets", "audio")).replace(os.sep, "/")
        print("%-26s %6d %7.2f %7.0f %7.2f %7.2f %8.4f %8.4f" % (rel, c["sr"], c["dur"], c["kb"], c["pico"], c["rms"],
                                                                c["emenda"], c["salto999"]))
        musica = rel.startswith("musica/")
        if c["pico"] > (-3.0 if musica else -1.0):
            problemas.append(rel + ": pico alto")
        if musica and c["emenda"] > max(0.01, c["salto999"]):
            problemas.append(rel + ": emenda com salto")
        if not musica and (c["inicio"] != 0.0 or c["fim"] != 0.0):
            problemas.append(rel + ": pontas não zeradas")
    print("\ntotal: %.2f MB   tempo: %.1f s" % (total / 1024.0, time.time() - t_total))
    print("problemas: " + ("; ".join(problemas) if problemas else "nenhum"))
    return 1 if problemas else 0


if __name__ == "__main__":
    sys.exit(main())
