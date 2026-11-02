#!/usr/bin/env python3
"""SlopLoad's tapes as audio: for playing from a CD, an MP3 player or a
PC through a cassette adapter or an audio-to-datasette lead, and for
measuring what that does to the pulses.

    audio.py tape.tap out.wav [-rate 44100] [-invert]   the tape as a WAV
    audio.py in.wav|in.mp3 out.tap                      the pulses back

Synthesis: each pulse is one period of a square wave, low half first,
so the falling edge (the one the C64's cassette input counts) is at the
pulse's start. -invert swaps the halves, for a player or lead that
inverts (nothing loads, not even the KERNAL part, with the wrong one). The square is box-filtered: a sample an edge falls in
gets the average of the two levels over it, so an edge keeps its time
between samples through a DAC (at 44.1 kHz a sample is 22 cycles).

Reading: falling zero crossings with hysteresis (a Schmitt trigger, as
in the datasette), each placed between its two samples by linear
interpolation. Compressed files (MP3 and the rest) are decoded with
GStreamer (gst-launch-1.0), and encoded with it too (encode_mp3).
"""
import os
import subprocess
import sys
import tempfile
import wave
from array import array

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import taplib as T  # noqa: E402

RATE = 44100


def synth(pulses, rate=RATE, amp=0.7, invert=False, lead_s=0.5):
    """16-bit samples (array 'h') for pulses in PAL cycles: silence, a
    half period high, the pulses, a closing falling edge and a half
    period low, silence. So every pulse has both its edges."""
    scale = rate / T.PAL_HZ
    a = int(32767 * amp) * (-1 if invert else 1)
    lead = lead_s * rate
    first = pulses[0] * scale / 2 if pulses else 0
    edges = [(lead, 1)]
    t = lead + first
    for p in pulses:
        half = p * scale / 2
        edges += [(t, -1), (t + half, 1)]
        t += 2 * half
    edges += [(t, -1), (t + first, 0)]
    n = int(t + first + lead) + 2
    buf = array('h', bytes(2 * n))
    level = 0
    k = 0
    for x, new in edges:
        i = int(x)
        if i > k:
            buf[k:i] = array('h', [level * a]) * (i - k)
            k = i
        if i == k:
            f = x - i                   # the part of sample i before the edge
            buf[i] = round(a * (level * f + new * (1 - f)))
            k = i + 1
        level = new
    return buf


def write_wav(path, samples, rate=RATE):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(samples.tobytes())


def read_wav(path):
    """(rate, samples): 16-bit, the first channel"""
    with wave.open(path, 'rb') as w:
        if w.getsampwidth() != 2:
            raise ValueError(f"{path}: only 16-bit WAVs")
        ch, rate = w.getnchannels(), w.getframerate()
        data = array('h', w.readframes(w.getnframes()))
    if sys.byteorder == 'big':
        data.byteswap()
    return rate, data[::ch] if ch > 1 else data


def gst(pipeline):
    r = subprocess.run(['gst-launch-1.0', '-q'] + pipeline, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f"gst-launch-1.0 failed: {r.stderr.strip() or r.stdout.strip()}")


def decode_to_wav(src, dst, rate=None):
    """any file GStreamer can play (MP3, OGG, FLAC, ...) to a mono 16-bit WAV"""
    caps = 'audio/x-raw,format=S16LE,channels=1' + (f',rate={rate}' if rate else '')
    gst(['filesrc', f'location={src}', '!', 'decodebin', '!', 'audioconvert', '!',
         'audioresample', '!', caps, '!', 'wavenc', '!', 'filesink', f'location={dst}'])


def encode_mp3(src_wav, dst, bitrate=192, vbr_quality=None):
    """a WAV to MP3 with LAME: constant bitrate, or VBR at a quality 0-9"""
    enc = (['lamemp3enc', 'target=quality', f'quality={vbr_quality}'] if vbr_quality is not None
           else ['lamemp3enc', 'target=bitrate', f'bitrate={bitrate}', 'cbr=true'])
    gst(['filesrc', f'location={src_wav}', '!', 'wavparse', '!', 'audioconvert', '!']
        + enc + ['!', 'filesink', f'location={dst}'])


def read_audio(path):
    """(rate, samples) from a WAV, or from anything else via GStreamer"""
    if path.lower().endswith('.wav'):
        try:
            return read_wav(path)
        except (ValueError, wave.Error):
            pass
    with tempfile.TemporaryDirectory() as d:
        w = os.path.join(d, 'decoded.wav')
        decode_to_wav(path, w)
        return read_wav(w)


def filtered(samples, rate, lowpass=None, highpass=None):
    """one-pole low- and high-pass filters (a player's output and an
    adapter's head), as floats"""
    x = [float(v) for v in samples]
    import math
    if lowpass:
        al = 1 - math.exp(-2 * math.pi * lowpass / rate)
        y = 0.0
        for i, v in enumerate(x):
            y += al * (v - y)
            x[i] = y
    if highpass:
        ah = math.exp(-2 * math.pi * highpass / rate)
        prev_in = prev_out = 0.0
        for i, v in enumerate(x):
            o = ah * (prev_out + v - prev_in)
            prev_in, prev_out = v, o
            x[i] = o
    return x


def falling_edges(samples, rate, thr_frac=0.1):
    """times (in samples) of falling zero crossings, with hysteresis of
    thr_frac of the peak level either side of zero"""
    peak = max(max(samples), -min(samples)) or 1
    thr = thr_frac * peak
    out = []
    armed = False
    last_pos = 0                    # last sample at or above zero
    for i, v in enumerate(samples):
        if v >= 0:
            last_pos = i
            if v > thr:
                armed = True
        elif armed and v < -thr:
            j = last_pos            # crossing between j and j + 1
            a, b = samples[j], samples[j + 1]
            out.append(j + (a / (a - b) if a != b else 0.0))
            armed = False
    return out


def pulses_from_audio(samples, rate, thr_frac=0.1):
    """PAL cycles between falling edges"""
    e = falling_edges(samples, rate, thr_frac)
    k = T.PAL_HZ / rate
    return [(b - a) * k for a, b in zip(e, e[1:])]


def tape_to_audio_file(pulses, path, rate=RATE, invert=False):
    write_wav(path, synth(pulses, rate, invert=invert), rate)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    src, dst = argv[1], argv[2]
    rate = int(argv[argv.index('-rate') + 1]) if '-rate' in argv else RATE
    if src.lower().endswith('.tap'):
        tape_to_audio_file(T.tap_read(src), dst, rate, '-invert' in argv)
        print(f"{dst}: {rate} Hz")
    else:
        r, s = read_audio(src)
        p = pulses_from_audio(s, r)
        T.tap_write(dst, [max(8, round(v)) for v in p], hires=True)
        print(f"{dst}: {len(p)} pulses from {src} ({r} Hz)")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
