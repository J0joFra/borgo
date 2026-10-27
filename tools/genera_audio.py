#!/usr/bin/env python3
"""Genera musica ed effetti sonori del gioco con un piccolo sintetizzatore (nessun file esterno).

Uso:  python3 tools/genera_audio.py   (serve numpy e ffmpeg; scrive in art/audio/*.ogg)

Strumenti: liuto pizzicato (Karplus-Strong), flauto (sinusoidi con vibrato), bordone,
tamburo e corno. Le melodie sono in modo dorico e misolidio, come una musica medievale.
"""
import os
import subprocess
import wave

import numpy as np

SR = 22050
CARTELLA = os.path.join(os.path.dirname(__file__), "..", "art", "audio")
rng = np.random.default_rng(7)


def nota(nome: str) -> float:
    """Frequenza di una nota scritta come 'D4', 'F#3', 'Bb4'."""
    semitoni = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    base = semitoni[nome[0]]
    resto = nome[1:]
    if resto.startswith("#"):
        base += 1
        resto = resto[1:]
    elif resto.startswith("b"):
        base -= 1
        resto = resto[1:]
    ottava = int(resto)
    return 440.0 * 2 ** ((base + (ottava - 4) * 12) / 12)


def liuto(f: float, durata: float, forza=0.5) -> np.ndarray:
    """Corda pizzicata (Karplus-Strong) con un po' di corpo."""
    n = int(SR * durata)
    periodo = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, periodo) * forza
    out = np.zeros(n)
    for i in range(n):
        j = i % periodo
        out[i] = buf[j]
        buf[j] = 0.5 * (buf[j] + buf[(j + 1) % periodo]) * 0.996
    return out


def flauto(f: float, durata: float, forza=0.25) -> np.ndarray:
    t = np.arange(int(SR * durata)) / SR
    vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t) * np.minimum(1, t * 3)
    fase = 2 * np.pi * f * np.cumsum(vibrato) / SR
    voce = np.sin(fase) + 0.3 * np.sin(2 * fase) + 0.12 * np.sin(3 * fase)
    soffio = rng.normal(0, 0.02, t.size)
    inviluppo = np.minimum(1, t / 0.06) * np.minimum(1, (durata - t) / 0.12)
    return (voce + soffio) * inviluppo * forza


def bordone(fs, durata: float, forza=0.08) -> np.ndarray:
    t = np.arange(int(SR * durata)) / SR
    out = np.zeros(t.size)
    for f in fs:
        out += np.sin(2 * np.pi * f * t) + 0.4 * np.sin(4 * np.pi * f * t)
    lento = 0.8 + 0.2 * np.sin(2 * np.pi * 0.11 * t)
    inviluppo = np.minimum(1, t / 2.0) * np.minimum(1, (durata - t) / 2.0)
    return out * lento * inviluppo * forza / len(fs)


def tamburo(durata=0.5, forza=0.6, basso=70.0) -> np.ndarray:
    t = np.arange(int(SR * durata)) / SR
    f = basso * (1 + 1.5 * np.exp(-t * 30))
    corpo = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    pelle = rng.normal(0, 1, t.size) * np.exp(-t * 40) * 0.3
    return (corpo + pelle) * forza


def corno(f: float, durata: float, forza=0.35) -> np.ndarray:
    t = np.arange(int(SR * durata)) / SR
    fase = 2 * np.pi * f * t * (1 + 0.003 * np.sin(2 * np.pi * 4 * t))
    voce = sum(np.sin(k * fase) / k ** 1.2 for k in range(1, 8))
    inviluppo = np.minimum(1, t / 0.12) * np.minimum(1, (durata - t) / 0.2)
    return voce * inviluppo * forza


def campana(f: float, durata=2.5, forza=0.4) -> np.ndarray:
    t = np.arange(int(SR * durata)) / SR
    parziali = [(1, 1.0), (2.0, 0.6), (2.4, 0.4), (3.0, 0.25), (4.2, 0.2), (5.4, 0.15)]
    out = sum(a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (1.5 + k)) for k, a in parziali)
    return out * forza


def rumore(durata: float, forza=0.3, taglio=0.3) -> np.ndarray:
    x = rng.normal(0, 1, int(SR * durata))
    # passa-basso semplice
    y = np.zeros_like(x)
    for i in range(1, x.size):
        y[i] = y[i - 1] + taglio * (x[i] - y[i - 1])
    return y * forza


def metti(traccia: np.ndarray, suono: np.ndarray, quando: float) -> None:
    i = int(quando * SR)
    fine = min(traccia.size, i + suono.size)
    if i < traccia.size:
        traccia[i:fine] += suono[: fine - i]


def riverbero(x: np.ndarray, quanto=0.25) -> np.ndarray:
    out = x.copy()
    for ritardo, guadagno in [(0.031, 0.5), (0.047, 0.4), (0.071, 0.3), (0.113, 0.22), (0.17, 0.15)]:
        d = int(ritardo * SR)
        out[d:] += x[:-d] * guadagno * quanto * 2
    return out


def chiudi_anello(x: np.ndarray, sfuma=1.5) -> np.ndarray:
    """Fa coincidere fine e inizio, così la musica gira in tondo senza scatti."""
    n = int(sfuma * SR)
    coda = x[-n:].copy()
    x = x[:-n]
    rampa = np.linspace(0, 1, n)
    x[:n] = x[:n] * rampa + coda * (1 - rampa)
    return x


def normalizza(x: np.ndarray, picco=0.8) -> np.ndarray:
    m = np.max(np.abs(x))
    return x if m == 0 else x / m * picco


def salva(nome: str, x: np.ndarray, qualita=3) -> None:
    os.makedirs(CARTELLA, exist_ok=True)
    wav = os.path.join(CARTELLA, nome + ".wav")
    dati = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dati.tobytes())
    ogg = os.path.join(CARTELLA, nome + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(qualita), ogg], check=True)
    os.remove(wav)
    print(nome, round(x.size / SR, 1), "s")


# --- Musiche -------------------------------------------------------------------------

def musica_feudo() -> np.ndarray:
    """Vita nel borgo: liuto che arpeggia in re dorico, flauto sopra, bordone di re e la."""
    bpm = 84
    battito = 60 / bpm
    accordi = [["D3", "A3", "D4", "F4"], ["C3", "G3", "C4", "E4"], ["D3", "A3", "D4", "F4"], ["G2", "D3", "G3", "B3"],
               ["F3", "C4", "F4", "A4"], ["C3", "G3", "C4", "E4"], ["A2", "E3", "A3", "C4"], ["D3", "A3", "D4", "F4"]]
    melodia = [("A4", 1), ("C5", 0.5), ("D5", 0.5), ("E5", 1), ("D5", 1), ("C5", 1), ("A4", 1), ("G4", 2),
               ("A4", 1), ("F4", 1), ("G4", 1), ("A4", 1), ("B4", 1.5), ("A4", 0.5), ("G4", 2),
               ("F4", 1), ("A4", 1), ("C5", 1), ("D5", 1), ("C5", 1.5), ("B4", 0.5), ("A4", 2),
               ("G4", 1), ("E4", 1), ("F4", 1), ("G4", 1), ("A4", 2), ("D4", 2)]
    giri = 2
    durata = len(accordi) * 4 * battito * giri + 2
    t = np.zeros(int(durata * SR))
    for g in range(giri):
        for i, acc in enumerate(accordi):
            inizio = (g * len(accordi) + i) * 4 * battito
            for k in range(8):
                f = nota(acc[[0, 1, 2, 3, 2, 1, 2, 3][k]])
                metti(t, liuto(f, 1.6, 0.35 if k % 2 == 0 else 0.25), inizio + k * battito / 2)
        if g == 1:
            momento = g * len(accordi) * 4 * battito
            for n, d in melodia:
                metti(t, flauto(nota(n), d * battito * 0.95, 0.18), momento)
                momento += d * battito
    t += bordone([nota("D2"), nota("A2")], durata, 0.06)
    return normalizza(chiudi_anello(riverbero(t), 2.0), 0.7)


def musica_regno() -> np.ndarray:
    """La mappa e il menu: lenta e solenne, arpa e flauto in sol misolidio."""
    bpm = 66
    battito = 60 / bpm
    accordi = [["G2", "D3", "G3", "B3"], ["F2", "C3", "F3", "A3"], ["C3", "G3", "C4", "E4"], ["G2", "D3", "G3", "B3"],
               ["E2", "B2", "E3", "G3"], ["F2", "C3", "F3", "A3"], ["D3", "A3", "D4", "F#4"], ["G2", "D3", "G3", "B3"]]
    melodia = [("D5", 2), ("B4", 1), ("C5", 1), ("D5", 2), ("F5", 2), ("E5", 1.5), ("D5", 0.5), ("C5", 2), ("B4", 2),
               ("G4", 2), ("A4", 1), ("B4", 1), ("C5", 2), ("A4", 2), ("B4", 1), ("A4", 1), ("G4", 4)]
    durata = len(accordi) * 4 * battito * 2 + 2
    t = np.zeros(int(durata * SR))
    for g in range(2):
        for i, acc in enumerate(accordi):
            inizio = (g * len(accordi) + i) * 4 * battito
            for k, idx in enumerate([0, 1, 2, 3, 2, 3]):
                metti(t, liuto(nota(acc[idx]), 2.2, 0.3), inizio + k * battito * 4 / 6)
        # al primo giro il flauto entra a metà con la prima frase, al secondo suona tutta la melodia
        momento = g * len(accordi) * 4 * battito + (0 if g == 1 else 4 * battito * 4)
        for n, d in melodia if g == 1 else melodia[:9]:
            metti(t, flauto(nota(n), d * battito * 0.95, 0.15), momento)
            momento += d * battito
    t += bordone([nota("G2"), nota("D3")], durata, 0.05)
    return normalizza(chiudi_anello(riverbero(t, 0.35), 2.0), 0.65)


def musica_battaglia() -> np.ndarray:
    """La battaglia: tamburi, bordone grave e corni in re minore."""
    bpm = 116
    battito = 60 / bpm
    battute = 16
    durata = battute * 4 * battito + 2
    t = np.zeros(int(durata * SR))
    ritmo = [0, 1, 1.5, 2, 3, 3.5]
    for b in range(battute):
        for r in ritmo:
            metti(t, tamburo(0.45, 0.55 if r in (0, 2) else 0.35, 65 if r in (0, 2) else 95), (b * 4 + r) * battito)
        if b % 2 == 1:
            metti(t, rumore(0.12, 0.15, 0.6), (b * 4 + 3.75) * battito)
    frase = [("D4", 1), ("F4", 1), ("A4", 2), ("G4", 1), ("F4", 1), ("E4", 2), ("D4", 1), ("C4", 1), ("D4", 4)]
    for ripetizione in (4, 10):
        momento = ripetizione * 4 * battito
        for n, d in frase:
            metti(t, corno(nota(n) / 2, d * battito * 0.95, 0.22), momento)
            metti(t, corno(nota(n), d * battito * 0.95, 0.12), momento)
            momento += d * battito
    t += bordone([nota("D2"), nota("A1")], durata, 0.1)
    return normalizza(chiudi_anello(riverbero(t, 0.2), 1.0), 0.75)


# --- Effetti -------------------------------------------------------------------------

def effetti() -> dict:
    e = {}
    # un tocco su un pulsante: legno
    t = np.arange(int(SR * 0.08)) / SR
    e["click"] = (np.sin(2 * np.pi * 900 * t) * 0.5 + rumore(0.08, 0.4, 0.5)) * np.exp(-t * 60) * 0.6
    # piazzare un edificio: tre colpi di martello
    martello = np.zeros(int(SR * 0.9))
    for k in range(3):
        colpo = (tamburo(0.18, 0.5, 180) + rumore(0.18, 0.3, 0.7) * np.exp(-np.arange(int(SR * 0.18)) / SR * 50))
        metti(martello, colpo, k * 0.26)
    e["costruisci"] = martello
    # edificio finito: due note che salgono
    fine = np.zeros(int(SR * 1.2))
    metti(fine, liuto(nota("D5"), 1.0, 0.6), 0)
    metti(fine, liuto(nota("A5"), 1.0, 0.6), 0.14)
    e["completato"] = riverbero(fine)
    # moneta
    t = np.arange(int(SR * 0.5)) / SR
    e["moneta"] = (np.sin(2 * np.pi * 2093 * t) + 0.6 * np.sin(2 * np.pi * 2637 * t)) * np.exp(-t * 9) * 0.35
    # campana della nuova stagione
    e["campana"] = campana(nota("G4"), 2.5, 0.5)
    # carta evento: un foglio che si gira
    e["pagina"] = rumore(0.35, 0.5, 0.25) * np.sin(np.linspace(0, np.pi, int(SR * 0.35))) ** 2
    # corno dei banditi
    e["corno"] = riverbero(np.concatenate([corno(nota("D3"), 0.7, 0.5), corno(nota("C3"), 1.1, 0.5)]), 0.4)
    # scontro di spade
    t = np.arange(int(SR * 0.6)) / SR
    metallo = sum(np.sin(2 * np.pi * f * t) for f in (1830, 2470, 3130, 4210)) / 4
    e["scontro"] = (metallo * np.exp(-t * 12) * 0.6 + rumore(0.6, 0.6, 0.8) * np.exp(-t * 25)) * 0.8
    # freccia: un sibilo
    sibilo = rumore(0.35, 0.8, 0.9)
    e["freccia"] = sibilo * np.sin(np.linspace(0, np.pi, sibilo.size)) * 0.5
    # vittoria e sconfitta
    v = np.zeros(int(SR * 2.4))
    for k, n in enumerate(["D4", "F#4", "A4", "D5"]):
        metti(v, corno(nota(n), 0.5 if k < 3 else 1.4, 0.3), k * 0.22)
    e["vittoria"] = riverbero(v)
    s = np.zeros(int(SR * 2.4))
    for k, n in enumerate(["A3", "F3", "D3"]):
        metti(s, corno(nota(n), 0.7 if k < 2 else 1.3, 0.3), k * 0.45)
    e["sconfitta"] = riverbero(s)
    # errore / non si può
    t = np.arange(int(SR * 0.18)) / SR
    e["errore"] = np.sin(2 * np.pi * 150 * t) * np.exp(-t * 15) * 0.5
    return e


if __name__ == "__main__":
    salva("musica_feudo", musica_feudo(), 3)
    salva("musica_regno", musica_regno(), 3)
    salva("musica_battaglia", musica_battaglia(), 3)
    for nome, x in effetti().items():
        salva("effetto_" + nome, normalizza(x, 0.85), 4)
