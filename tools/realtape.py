"""Real cassette support: a calibration tape, the analysis of a dump of it
read back from a real deck, and precompensation.

The workflow (the same idea as slushload's -calibrate / -wptable_create):

  1. slopload.py -calibrate cal.tap         a tape with every speed on it
  2. record cal.tap to a cassette, then dump that cassette back to a .tap
     with the same deck (TAPuino, DC2N, Ultimate's tape capture ...)
  3. slopload.py -analyse dump.tap [-out deck.json]
        per speed: how far each pulse class spreads, the slow speed drift
        (wow), the fast scatter (flutter), how much a pulse's neighbour
        shifts it (peak shift), the margin left, and which speeds this
        deck can carry with a module running and with the screen off.
        It writes deck.json for step 4.
  4. slopload.py game.prg game.tap -precomp deck.json ...
        writes each pulse shorter or longer by what the deck was measured
        to do to it after the pulse before.

Lengths are kept relative to the quantum h, since the loader measures h
again on every block's pilot: a deck that runs 3% fast just looks like
a slightly different h.
"""
import json
import math
import random

import taplib as T

CAL_SEED = 0x1d872b41
CAL_SYMBOLS = 6144          # per speed
CAL_MARKER = [3, 0, 3, 3, 0, 0, 3, 1, 2, 3, 2, 1]   # after the sync pulse


def cal_symbols(seed=CAL_SEED, n=CAL_SYMBOLS):
    """The known class sequence: every pair of neighbours many times."""
    r = random.Random(seed)
    return [r.randrange(4) for _ in range(n)]


def calibration_tap(path, sets):
    """sets: list of (h, m) pulse sets, as the tool will use them. Each
    section: a 4h pilot, a 10h sync, then the known classes in pulse set
    m. Returns the pulse list written."""
    p = [T.pulse(0, 64)] * int(5 * T.PAL_HZ / 256)        # 5 s: deck up to speed
    seq = cal_symbols()
    for h, m in sets:
        p += [T.pulse(0, h)] * 2000
        p += [T.pulse(3, h)]
        p += [T.pulse(k, h, m) for k in CAL_MARKER]
        p += [T.pulse(k, h, m) for k in seq]
        p += [T.pulse(0, h)] * 400
    p += [T.pulse(0, 64)] * 2000
    T.tap_write(path, p)
    return p


def find_sections(pulses):
    """Calibration sections: a class-3 sync pulse after 1000 near-equal
    pilot pulses (within 15%: a deck's flutter and a .tap's 8-cycle steps
    spread them). Returns (start of data, pilot pulse length: the mean of
    the middle 80%, finer than the steps)."""
    out = []
    n = len(pulses)
    j = 1000
    while j < n:
        if 2.1 < pulses[j] / pulses[j - 1] < 2.9:
            run = sorted(pulses[j - 1000:j])
            mid = run[500]
            if run[10] > 0.85 * mid and run[989] < 1.15 * mid:
                p0 = sum(run[100:900]) / 800
                out.append((j + 1, p0))
                j += 2000
                continue
        j += 1
    return out


def identify(pulses, start, p0):
    """the pulse set m a section is in: the one its marker fits"""
    h = p0 / 4
    got = pulses[start:start + len(CAL_MARKER)]
    fit = {m: sum(abs(g / h - (m + 2 * k)) for g, k in zip(got, CAL_MARKER)) / len(got) for m in (2, 3, 4)}
    m = min(fit, key=fit.get)
    return m, fit[m]


def match(sections, sets):
    """[(start, p0, (h, m))]: each section found, with the set it is.
    Sections come in the order of sets, some may be missing; the deck's
    speed is the same for all, so try speeds and keep the one that
    matches most (each section's m from its marker, h within 3%)."""
    info = sections
    best = None
    for i in range(201):
        sp = 0.80 + i * 0.002
        j, got, err = 0, [], 0.0
        for st, p0, m in info:
            k = j
            while k < len(sets) and not (sets[k][1] == m and abs(p0 / 4 / (sets[k][0] * sp) - 1) < 0.03):
                k += 1
            if k == len(sets):
                continue
            got.append((st, p0, sets[k]))
            err += abs(p0 / 4 / (sets[k][0] * sp) - 1)
            j = k + 1
        key = (len(got), -err)
        if best is None or key > best[0]:
            best = (key, got)
    return best[1] if best else []


def analyse(pulses, sets):
    """Measure every calibration section found in a dump. sets as for
    calibration_tap. Returns a dict for the report and -precomp."""
    seq = cal_symbols()
    found = find_sections(pulses)
    sections = match([(st, p0, identify(pulses, st, p0)[0]) for st, p0 in found], sets)
    res = {'sections': [], 'found': len(found)}
    for start, p0, (h_nom, m) in sections:
        want = CAL_MARKER + seq
        got = pulses[start:start + len(want)]
        if len(got) < len(want):
            break
        h = p0 / 4.0                                     # as the loader measures it
        # slow speed: each pulse against its nominal length, over 128 pulses
        nominal = [(m + 2 * k) for k in want]
        ratio = [g / (n * h) for g, n in zip(got, nominal)]
        win = 128
        pre = [0.0]                                      # moving average
        for r in ratio:
            pre.append(pre[-1] + r)
        slow = []
        for i in range(len(ratio)):
            lo, hi = max(0, i - win // 2), min(len(ratio), i + win // 2)
            slow.append((pre[hi] - pre[lo]) / (hi - lo))
        wow = (max(slow) - min(slow)) / 2                # +- share
        # what is left after the slow drift: by (previous class, class)
        dev = [[[] for _ in range(4)] for _ in range(4)]   # in units of h
        flat = []
        for i in range(1, len(want)):
            d = got[i] / (slow[i] * h) - nominal[i]
            dev[want[i - 1]][want[i]].append(d)
            flat.append((want[i - 1], want[i], d))
        shift = [[(sum(v) / len(v) if v else 0.0) for v in row] for row in dev]
        resid = [d - shift[a][b] for a, b, d in flat]
        flutter = math.sqrt(sum(x * x for x in resid) / len(resid))
        # margin: the decoder reads class k for 2k+3 <= L/h < 2k+5 (k=0
        # also down to 1, k=3 up to 12); worst use of it, raw and with
        # the neighbour shift taken out (precompensated)
        def worst(precomp):
            least = 9.0
            for i in range(1, len(want)):
                k = want[i]
                L = got[i] / h
                if precomp:
                    L -= shift[want[i - 1]][k]
                lo = m + 2 * k - 1 if k else 1
                hi = m + 2 * k + 1 if k < 3 else 12
                least = min(least, L - lo, hi - L)
            return least
        errors = sum(1 for i in range(len(want))
                     if not ((m + 2 * want[i] - 1 if want[i] else 1) <= got[i] / h
                             < (m + 2 * want[i] + 1 if want[i] < 3 else 12)))
        res['sections'].append(dict(
            m=m, h_nominal=h_nom, h_measured=round(h, 2),
            deck_speed=round(h_nom / h, 4), wow=round(wow, 4), flutter_h=round(flutter, 4),
            shift_h=[[round(x, 4) for x in row] for row in shift],
            margin_h=round(worst(False), 3), margin_precomp_h=round(worst(True), 3),
            errors=errors))
    return res


def safe_at(res, h, m, extra, precomp, reserve=0.15):
    """Does the deck's worst pulse at quantum h (pulse set m) still leave
    reserve x h after extra cycles of the loader's own timing jitter?"""
    s = next((s for s in res['sections'] if s['h_nominal'] == h and s['m'] == m), None)
    if s is None:
        return None
    m = (s['margin_precomp_h'] if precomp else s['margin_h']) * h
    return m - extra >= reserve * h


def recommend(res, speeds, set_of_module, set_of_boot, module_jitter):
    """Fastest speed N (slushload numbering, below 0 for more margin) safe
    on this deck, of speeds: with a module running (its jitter on top of
    the tape's) and with the screen off.
    set_of_*(n) -> the (h, m) pulse sets that speed may use: all of
    them must be safe."""
    out = {}
    for pre in (False, True):
        for mode in ('module', 'screen_off'):
            ok = []
            for n in speeds:
                sets = set_of_module(n) if mode == 'module' else set_of_boot(n)
                extra = module_jitter if mode == 'module' else 8
                if all(safe_at(res, h, m, extra, pre) for h, m in sets):
                    ok.append(n)
            out[(mode, pre)] = max(ok) if ok else None
    return out


def precomp_table(res):
    """{"h:m": 4x4 shifts in units of h} for -precomp."""
    return {f"{s['h_nominal']}:{s['m']}": s['shift_h'] for s in res['sections']}


def apply_precomp(pulses_classes, h, table, m=4, prev=0):
    """Pulse lengths for a list of classes at quantum h in pulse set m,
    each moved against the shift measured after the class before it."""
    if not table:
        return [T.pulse(k, h, m) for k in pulses_classes]
    def dist(k):
        kh, km = (int(v) for v in k.split(':'))
        return (km != m, abs(kh - h))
    shift = table[min(table, key=dist)]
    out = []
    for k in pulses_classes:
        out.append(max(8, T.pulse(k, h, m) - shift[prev][k] * h))
        prev = k
    return out


# ---------------------------------------------------------------- a channel model

def distort(pulses, speed=1.0, wow=0.0, wow_hz=0.7, flutter=0.0, shift=0.0, seed=1):
    """What a (modelled) deck might do to the pulses: a speed error, wow
    (a slow sine, +- share), flutter (random, share of each pulse) and
    peak shift (a pulse after a longer one comes out longer by shift x
    the difference). For testing the analysis and the decoder's margins,
    not a substitute for a real deck."""
    r = random.Random(seed)
    t = 0.0
    out = []
    prev = pulses[0]
    for p in pulses:
        s = speed * (1 + wow * math.sin(2 * math.pi * wow_hz * t / T.PAL_HZ))
        q = p + shift * (prev - p) if p < 2000 and prev < 2000 else p
        q = q / s * (1 + r.gauss(0, flutter))
        out.append(max(8, q))
        t += p
        prev = p
    return out
