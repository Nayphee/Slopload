#!/usr/bin/env python3
"""How a deck took SlopLoad 64's motor stops: for a cassette written a
block at a time (the motor stopped while each block is read and coded)
and dumped back to a .tap, each seam's spin-up: from the gap where the
motor stopped to where the pilot's pulses settle at their full length,
and how much steady pilot was left before the block's sync. The loader
needs about 80 steady pilot pulses (it measures 64, after 16).

    seamcheck.py dump.tap

A seam is a gap of 20,000 cycles or more followed by a pilot (pulses
within 5% of each other for 200 or more, then a sync about 2.5 times as
long). Settled: from where the average of every 16 pulses on stays within
1.5% of the last 64's median (single pulses jitter; dumps are in 8-cycle
steps). The slow start is the time on tape from the gap to there: shorter
than the motor's own spin-up, as the tape moved slowly while it ran.
"""
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import taplib as T  # noqa: E402

GAP = 20000


def seams(pu):
    """(gap index, first settled pulse, sync index, pilot length) for each seam"""
    out = []
    i = 0
    n = len(pu)
    while i < n:
        if pu[i] < GAP:
            i += 1
            continue
        g = i                                   # a gap: the pilot's sync after it?
        j = g + 1
        while j < n and pu[j] >= GAP:
            j += 1
        k = j
        while k < n and k - j < 20000:          # the sync: a pulse ~2.5x the steady pilot's
            if k - j > 280:
                ref = statistics.median(pu[k - 64:k])
                if 2.2 * ref < pu[k] < 2.8 * ref and all(abs(x - ref) < 0.05 * ref for x in pu[k - 200:k]):
                    break
            k += 1
        if k >= n or k - j >= 20000:
            i = j
            continue
        ref = statistics.median(pu[k - 64:k])
        s = k - 16
        while s > j and abs(sum(pu[s - 1:s + 15]) / 16 - ref) <= 0.015 * ref:
            s -= 1
        out.append((g, s, k, ref))
        i = k + 1
    return out


def main(argv):
    if len(argv) != 1 or argv[0].lower() in ('-h', '-help', '--help'):
        print(__doc__)
        return 0 if argv and argv[0].lower() in ('-h', '-help', '--help') else 1
    if not os.path.isfile(argv[0]):
        print(f"seamcheck: no file {argv[0]}", file=sys.stderr)
        return 1
    pu = T.tap_read(argv[0])
    found = seams(pu)
    if not found:
        print(f"{argv[0]}: no seams found (written in one go, or not SlopLoad 64's)")
        return 1
    print(f"{os.path.basename(argv[0])}: {len(found)} seams")
    print("  seam  pilot pulse  slow start  steady pilot left")
    worst = None
    for idx, (g, s, k, ref) in enumerate(found):
        up = sum(pu[g + 1:s]) / T.PAL_HZ             # from the gap's end to settled
        left = k - s
        print(f"  {idx + 1:4d}  {ref:6.0f} cyc   {up * 1000:5.0f} ms    {left:5d} pulses"
              f" ({sum(pu[s:k]) / T.PAL_HZ * 1000:4.0f} ms)")
        if worst is None or left < worst:
            worst = left
    verdict = 'plenty' if worst >= 300 else 'enough' if worst >= 100 else 'TOO LITTLE: a longer pilot is needed'
    print(f"  least steady pilot left: {worst} pulses ({verdict}; the loader needs about 80)")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
