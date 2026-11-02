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


def pad_note(freq, seconds):
    """Nota de "piano elétrico" suave: seno com um pouco de 2.º harmónico e ataque lento."""
    t = t_of(seconds)
    s = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 3)
    return s * np.clip(t / 0.02, 0, 1) * np.exp(-t * 1.2)


def music(seed, bpm, progression, bars=32):
    """Música calma: piano suave, baixo em mínimas, pouca percussão e uma melodia
    com espaço (pausas), que varia de secção para secção para não cansar."""
    r = np.random.default_rng(seed)
    beat = 60 / bpm
    total = bars * 4 * beat
    out = np.zeros(int(RATE * total) + RATE * 2)

    def add(at, sound, vol):
        i = int(at * RATE)
        out[i:i + len(sound)] += sound[:len(out) - i] * vol

    rhythms = [
        [(0, 1.5), (2, 1), (3, 1)],
        [(0, 2), (2.5, 1.5)],
        [(0.5, 1), (1.5, 0.5), (2, 2)],
        [(0, 1), (1, 1), (2, 2)],
        [(1, 1), (2, 1), (3, 1)],
        [(0, 3)],
    ]
    scale = [0, 2, 4, 7, 9]  # pentatónica maior
    sections = []
    for _ in range(bars // 8):
        sections.append([(r.choice(len(rhythms)), r.integers(0, 5)) for _ in range(8)])
    # Forma A A' B A: a segunda é a primeira com pequenas mudanças.
    order = [0, 0, 1, 0] if len(sections) >= 2 else [0]
    for bar in range(bars):
        t0 = bar * 4 * beat
        chord = progression[bar % len(progression)]
        root = chord[0]
        # Baixo: fundamental e quinta em mínimas.
        add(t0, blip(note_freq(root - 12), beat * 2, "triangle", 2.0), 0.28)
        add(t0 + 2 * beat, blip(note_freq(root - 5), beat * 2, "triangle", 2.0), 0.22)
        # Acorde arpejado devagar.
        for k, n in enumerate(chord):
            add(t0 + k * beat * 0.12, pad_note(note_freq(n), beat * 4), 0.10)
        if bar % 2 == 1:
            add(t0 + 2 * beat, pad_note(note_freq(chord[1] + 12), beat * 2), 0.06)
        # Shaker muito suave.
        for k in range(4):
            add(t0 + (k + 0.5) * beat, noise(0.04, 2) * env(int(RATE * 0.04), curve=9), 0.025)
        # Melodia (com uma secção em cada 8 compassos, e alguns compassos em silêncio).
        sec = sections[order[(bar // 8) % len(order)]]
        rhythm_i, offset = sec[bar % 8]
        if (bar // 8) == 1 and bar % 8 in (3, 6):
            rhythm_i = (rhythm_i + 1) % len(rhythms)
        if bar % 8 == 7:
            continue
        degree = int(offset)
        for b, d in rhythms[rhythm_i]:
            step = int(r.choice([-1, 0, 1, 1, 2]))
            degree = int(np.clip(degree + step, 0, 9))
            n = 72 + scale[degree % 5] + 12 * (degree // 5) - 12
            dur = d * beat
            tt = t_of(dur)
            vib = 1 + 0.003 * np.sin(2 * np.pi * 5 * tt) * np.clip(tt / 0.2, 0, 1)
            sound = osc(note_freq(n) * vib, dur, "sine") + 0.2 * osc(note_freq(n) * 2 * vib, dur, "sine")
            e = np.clip(tt / 0.03, 0, 1) * np.exp(-1.3 * tt / dur)
            add(t0 + b * beat, sound * e, 0.26)
    # Cauda curta para o loop não cortar notas a meio de forma brusca.
    loop = out[:int(RATE * total)]
    tail = out[int(RATE * total):]
    loop[:len(tail)] += tail[:len(loop)]
    return loop


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
    # Duas músicas: uma para o menu e outra para a cozinha.
    save("music_menu", music(7, 72, [[60, 64, 67, 71], [57, 60, 64, 67], [62, 65, 69, 72], [55, 59, 62, 65]]), 0.5)
    save("music", music(3, 84, [[65, 69, 72, 76], [64, 67, 71, 74], [62, 65, 69, 72], [60, 64, 67, 71],
                                [65, 69, 72, 76], [64, 67, 71, 74], [62, 65, 69, 72], [67, 71, 74, 77]]), 0.5)
    print("Sons escritos em", OUT)


if __name__ == "__main__":
    main()
