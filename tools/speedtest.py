#!/usr/bin/env python3
"""A test tape for a real deck: one self-checking program mastered at
several speeds, one after another, each its own file "SPEED N".

    speedtest.py out.tap|out.wav [-speeds 3,5,7,9,11,13] [-show MODE|all]
                 [-module NAME] [-picture file.koa] [-kb 16] [-precomp deck.json]

MODE is what shows while loading (slopload.py -show): module (Flappy-Load,
the default; -module another), none (screen off), picture, picmusic
(pictures/slopload.koa unless -picture gives another), music. -show all
makes one tape per mode, out-<mode>.tap, so each situation can be
measured on the deck; each file's name carries its mode
("SPEED 7 PIC+MUS").

Record it to a cassette (a TAPuino or an Ultimate writes the .tap; a PC
plays the .wav into the deck's record input), then on the C64 LOAD each
file in turn: LOAD alone takes the next one, LOAD"SPEED 7" a given one.
Each loads with Flappy-Load running (unless -show none) and, when it
starts (SPACE, or the bird crashing), checks its own bytes: PASS on a
green border, FAIL on a red one. A
"TAPE ERROR" on the game's status line is a fail for that speed too.
The fastest speed that passes every time, with some to spare, is the
one to master with for that deck and tape.
"""
import contextlib
import io
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import taplib as T  # noqa: E402
import slopload as S  # noqa: E402


TAG = {'module': 'GAME', 'none': 'OFF', 'picture': 'PIC', 'picmusic': 'PIC+MUS', 'music': 'MUSIC'}


def make(out, show, speeds, opt):
    """one tape: the test program at each speed, with show"""
    end = 0x0801 + int(opt['kb']) * 1024
    pulses = []
    with tempfile.TemporaryDirectory() as d:
        prg = os.path.join(d, 'test.prg')
        subprocess.run([sys.executable, os.path.join(ROOT, 'tests', 'mktest.py'), prg, hex(end), '7'],
                       check=True, capture_output=True)
        for sp in speeds:
            args = [prg, os.path.join(d, f's{sp}.tap'), '-speed', str(sp),
                    '-filename', f'SPEED {sp} {TAG[show]}', '-show', show]
            if show == 'module' and opt['module']:
                args += ['-module', opt['module']]
            if show in ('picture', 'picmusic'):
                args += ['-picture', opt['picture']]
            if opt['precomp']:
                args += ['-precomp', opt['precomp'], '-hires']
            o, pos = S.parse_args(args)
            rep = io.StringIO()
            with contextlib.redirect_stdout(rep):
                p = S.master(pos[0], pos[1], o)
            print(f"  SPEED {sp:2d} {TAG[show]:8s}: {sum(p) / T.PAL_HZ:5.1f} s")
            if pulses:                      # the trailer only at the tape's end
                pulses = pulses[:len(pulses) - S.TRAILER_PULSES]
            pulses += p
    if out.lower().endswith(('.wav', '.mp3')):
        back = S.write_sound(out, pulses, {})
        if len(back) != len(pulses):
            print(f"speedtest: {out} read back with {len(back) - len(pulses):+d} edges", file=sys.stderr)
            return 1
    else:
        # 8-cycle units, as every player and writer takes them; exact
        # counts only matter with -precomp
        T.tap_write(out, pulses, hires=bool(opt['precomp']))
    print(f"{out}: {len(speeds)} files, {sum(pulses) / T.PAL_HZ / 60:.1f} minutes,"
          f" a {opt['kb']} KB test program each, show {show}"
          + (f" ({opt['module']})" if show == 'module' and opt['module'] else ""))
    return 0


def main(argv):
    if not argv or argv[0] in ('-h', '-help', '--help'):
        print(__doc__)
        return 1
    out = argv[0]
    opt = {'speeds': '3,5,7,9,11,13', 'show': 'module', 'kb': '16', 'precomp': None, 'module': None,
           'picture': os.path.join(ROOT, 'pictures', 'slopload.koa')}
    i = 1
    while i < len(argv):
        k = argv[i].lstrip('-')
        if k not in opt or i + 1 >= len(argv):
            print(f"speedtest: unknown option {argv[i]}", file=sys.stderr)
            return 1
        opt[k] = argv[i + 1]
        i += 2
    try:
        speeds = [int(v) for v in opt['speeds'].split(',')]
    except ValueError:
        print(f"speedtest: -speeds wants numbers, as 3,5,7: not {opt['speeds']!r}", file=sys.stderr)
        return 1
    if opt['module'] == 'none':                 # (as -show none)
        opt['show'] = 'none'
    shows = list(S.SHOWS) if opt['show'] == 'all' else [opt['show']]
    for show in shows:
        o_ = out if len(shows) == 1 else '-{}'.join(os.path.splitext(out)).format(show)
        try:
            if make(o_, show, speeds, opt):
                return 1
        except (S.Fail, OSError) as ex:
            print(f"speedtest: {getattr(ex, 'strerror', None) or ex}", file=sys.stderr)
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
