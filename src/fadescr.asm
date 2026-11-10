; ------------------------------------------------------------
; fadescr.asm  -  fadekit.asm's scratch as bytes, for a module with no
; memory of its own that stays untouched while it runs once the program
; is in (a loading screen keeps it in its colours' bytes instead)
; ------------------------------------------------------------
fsh     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0          ; (25) the tune's SID registers
fkn     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0          ; (25) 1: written
fsv     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; (34) the RAM under $d400-$d421
