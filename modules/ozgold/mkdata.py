#!/usr/bin/env python3
"""OZ GOLD's music, built into the module: music/build/ozgold.sid moved
to $E900 (its own page offset kept) and written as modules/ozgold/music.asm.

tools/build.py runs this before it assembles the module. The tune is
checked as SlopLoad 64 checks one beside a game (tools/sidstrip.py: its
zero page in $70-$7F, no workspace outside itself, once a frame, 3,700
cycles a call at most), then moved by tools/sidreloc.py, which plays the
moved copy beside the original and compares every SID write. That takes
half a minute, so music.asm remembers the .sid's SHA-256 and is only made
again when the tune changes.
"""
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
SID = os.path.join(ROOT, 'music', 'build', 'ozgold.sid')
OUT = os.path.join(HERE, 'music.asm')
PAGE = 0xe9                     # the tune's page: after the module's code and colours
MAX_CYCLES = 3700


def main():
    if not os.path.exists(SID):
        sys.exit(f"ozgold: no tune ({SID}): the music's build makes it")
    sha = hashlib.sha256(open(SID, 'rb').read()).hexdigest()
    tools = hashlib.sha256(b''.join(open(os.path.join(ROOT, 'tools', f), 'rb').read()
                                    for f in ('sidstrip.py', 'sidfile.py', 'sidreloc.py'))).hexdigest()[:16]
    first = f"; from music/build/ozgold.sid, sha256 {sha}, page ${PAGE:02x}, moved by tools {tools}"
    if os.path.exists(OUT) and open(OUT).readline().strip() == first:
        return 0
    import sidstrip as SS
    import sidreloc as SR
    m = SS.strip(SID, 1)
    why = []
    if m['cia'] or m['per_pal'] != 312 * 64:
        why.append("it must play once a frame")
    if m['play_clk'] > MAX_CYCLES:
        why.append(f"its play call takes {m['play_clk']} cycles (at most {MAX_CYCLES})")
    if any(not 0x70 <= a < 0x80 for a in m['zp']):
        why.append("its zero page must be in $70-$7F")
    if m['workspace']:
        why.append("it uses memory outside itself: " +
                   ', '.join(f"${a:04X}-${b - 1:04X}" for a, b in m['workspace']))
    if m['relocs'] is None:
        why.append(f"it can't be moved ({m['reloc_why']})")
    if why:
        sys.exit("ozgold: music/build/ozgold.sid: " + "; ".join(why))
    to = PAGE * 256 + (m['load'] & 0xff)
    t = dict(path=SID, load=m['load'], end=m['load'] + len(m['data']), data=m['data'],
             init=m['init'], play=m['play'], songs=m['songs'], rsid=False)
    n = SR.move_checked(t, m['relocs'], to, 1, 1500, [])
    lines = [first,
             "; (made by mkdata.py: the tune moved to its place in the module)",
             f"; {m['name']} / {m['author']} / {m['released']}: song 1,"
             f" {len(n['data'])} bytes, play call {m['play_clk']} cycles at most",
             f"oz_init = ${n['init']:04x}",
             f"oz_play = ${n['play']:04x}",
             f"*=${to:04x}",
             "tune"]
    d = n['data']
    for i in range(0, len(d), 20):
        lines.append("        byte " + ",".join(f"${b:02x}" for b in d[i:i + 20]))
    lines.append("tuneend")
    open(OUT, 'w').write("\n".join(lines) + "\n")
    print(f"ozgold: the tune at ${to:04X}-${to + len(d) - 1:04X}, play call {m['play_clk']} cycles")
    return 0


if __name__ == '__main__':
    sys.exit(main())
