"""Gera os sons e a música do Order Up! (sintetizados, sem ficheiros externos).

Correr com: python3 tools/make_sounds.py
Escreve WAVs mono de 16 bits em assets/audio/.
"""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
RATE = 22050
rng = np.random.default_rng(42)


def t_of(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, decay=None, curve=4.0):
    """Envelope: ataque linear e decaimento exponencial até ao fim."""
    t = np.arange(n) / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    length = n / RATE
    d = np.exp(-curve * t / (decay or length))
    return a * d


def osc(freq, seconds, kind="sine"):
    t = t_of(seconds)
    f = np.broadcast_to(freq, t.shape) if np.ndim(freq) else np.full(t.shape, freq)
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if kind == "sine":
        return np.sin(phase)
    if kind == "square":
        return np.sign(np.sin(phase)) * 0.6
    if kind == "triangle":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    raise ValueError(kind)


def sweep(f0, f1, seconds):
    return np.linspace(f0, f1, int(RATE * seconds))


def noise(seconds, smooth=1):
    n = rng.uniform(-1, 1, int(RATE * seconds))
    if smooth > 1:
        n = np.convolve(n, np.ones(smooth) / smooth, mode="same") * np.sqrt(smooth) * 0.7
    return n


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(RATE * gap)))
    return np.concatenate(out)


def save(name, data, volume=0.8):
    data = np.asarray(data, dtype=float)
    peak = np.max(np.abs(data)) or 1.0
    data = data / peak * volume
    # Pequeno fade para não estalar.
    fade = min(64, len(data) // 4)
    data[:fade] *= np.linspace(0, 1, fade)
    data[-fade:] *= np.linspace(1, 0, fade)
    pcm = (data * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def blip(freq, seconds, kind="square", decay_curve=6.0):
    s = osc(freq, seconds, kind)
    return s * env(len(s), curve=decay_curve)


def bell(freq, seconds, partials=((1, 1.0), (2.76, 0.5), (5.4, 0.25))):
    t = t_of(seconds)
    s = sum(a * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (3 + 2 * k)) for k, a in partials)
    return s * np.clip(t / 0.002, 0, 1)


def note_freq(n):
    """Número MIDI para frequência."""
    return 440.0 * 2 ** ((n - 69) / 12)


def music():
    bpm = 100
    beat = 60 / bpm
    bars = 16
    total = bars * 4 * beat
    out = np.zeros(int(RATE * total) + RATE)

    def add(at, sound, vol):
        i = int(at * RATE)
        out[i:i + len(sound)] += sound[:len(out) - i] * vol

    # Dó - Lá menor - Fá - Sol, com uma volta a Mi menor na segunda metade.
    chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]] * 2 + \
             [[60, 64, 67], [52, 55, 59], [53, 57, 60], [55, 59, 62]] * 2
    roots = [48, 45, 41, 43] * 2 + [48, 40, 41, 43] * 2
    # Melodia: um motivo de dois compassos que se repete com variações.
    motif_a = [(0, 72, 1), (1, 74, 0.5), (1.5, 76, 1.5), (3, 79, 1), (4, 76, 1), (5, 74, 1), (6, 72, 2)]
    motif_b = [(0, 76, 1), (1, 79, 0.5), (1.5, 81, 1.5), (3, 79, 1), (4, 77, 1), (5, 76, 1), (6, 74, 2)]
    motif_c = [(0, 79, 1.5), (1.5, 77, 0.5), (2, 76, 1), (3, 74, 1), (4, 72, 1.5), (5.5, 74, 0.5), (6, 72, 2)]
    melody = []
    for i, m in enumerate([motif_a, motif_b, motif_a, motif_c, motif_b, motif_a, motif_b, motif_c]):
        melody += [(i * 8 + b, n, d) for b, n, d in m]

    for bar in range(bars):
        t0 = bar * 4 * beat
        # Baixo em colcheias.
        for k in range(8):
            n = roots[bar] + (12 if k % 4 == 2 else 0)
            add(t0 + k * beat / 2, blip(note_freq(n), beat / 2 * 0.9, "triangle", 3.0), 0.32)
        # Acordes em arpejo suave.
        for k in range(8):
            n = chords[bar][k % 3] + (12 if k >= 4 else 0)
            add(t0 + k * beat / 2, blip(note_freq(n), beat * 0.8, "square", 7.0), 0.07)
        # Pratos de choque nos contratempos.
        for k in range(4):
            add(t0 + (k + 0.5) * beat, noise(0.05) * env(int(RATE * 0.05), curve=8), 0.05)
            if k % 2 == 1:
                add(t0 + k * beat, noise(0.09, 3) * env(int(RATE * 0.09), curve=6), 0.09)
    for b, n, d in melody:
        dur = d * beat
        t = t_of(dur)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.15, 0, 1)
        s = osc(note_freq(n) * vib, dur, "triangle") * 0.8 + osc(note_freq(n) * 2 * vib, dur, "sine") * 0.15
        e = np.clip(t / 0.01, 0, 1) * np.exp(-1.6 * t / dur)
        add(b * beat, s * e, 0.42)
    return out[:int(RATE * total)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save("ui_move", blip(880, 0.05, "square", 8), 0.35)
    save("ui_confirm", seq(blip(660, 0.06), blip(990, 0.1)), 0.4)
    save("ui_back", seq(blip(523, 0.06), blip(392, 0.1)), 0.4)
    save("pickup", osc(sweep(420, 860, 0.08), 0.08, "sine") * env(int(RATE * 0.08), curve=3), 0.55)
    save("drop", mix(osc(sweep(520, 220, 0.09), 0.09, "triangle") * env(int(RATE * 0.09), curve=4),
                     noise(0.05, 6) * env(int(RATE * 0.05), curve=10) * 0.5), 0.55)
    save("chop", mix(noise(0.05, 2) * env(int(RATE * 0.05), curve=14),
                     blip(1500, 0.03, "sine", 10) * 0.4), 0.6)
    crackle = noise(2.0, 4) * 0.15
    for _ in range(60):
        i = rng.integers(0, len(crackle) - 400)
        crackle[i:i + 300] += noise(300 / RATE, 2) * env(300, curve=10) * rng.uniform(0.3, 1.0)
    save("sizzle", crackle, 0.4)
    bubbles = np.zeros(int(RATE * 0.45))
    for k in range(7):
        b = osc(sweep(rng.uniform(500, 900), rng.uniform(1000, 1500), 0.05), 0.05, "sine") * env(int(RATE * 0.05), curve=5)
        i = int(k * 0.055 * RATE)
        bubbles[i:i + len(b)] += b
    save("wash", bubbles, 0.45)
    save("plate", bell(2300, 0.3, ((1, 1.0), (1.37, 0.6), (2.1, 0.3))), 0.4)
    save("ding", mix(bell(1320, 0.9), np.concatenate([np.zeros(int(RATE * 0.09)), bell(1760, 0.8)])), 0.6)
    save("coin", seq(blip(988, 0.06, "square", 5), blip(1319, 0.18, "square", 5)), 0.35)
    save("fail", osc(sweep(330, 140, 0.4), 0.4, "square") * env(int(RATE * 0.4), curve=2.5), 0.4)
    save("bell", bell(2050, 0.9, ((1, 1.0), (2.4, 0.35), (4.1, 0.15))), 0.5)
    save("trash", noise(0.25, 8) * env(int(RATE * 0.25), curve=3), 0.4)
    save("dash", noise(0.16, 12) * np.sin(np.linspace(0, np.pi, int(RATE * 0.16))), 0.35)
    save("note", seq(blip(784, 0.05, "triangle", 5), blip(1047, 0.12, "triangle", 5)), 0.45)
    save("round_end", seq(*[blip(note_freq(n), 0.14, "square", 3) for n in (72, 76, 79)], blip(note_freq(84), 0.6, "square", 2)), 0.4)
    save("music", music(), 0.55)
    print("Sons escritos em", OUT)


if __name__ == "__main__":
    main()
