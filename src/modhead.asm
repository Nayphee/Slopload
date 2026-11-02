; ------------------------------------------------------------
; modhead.asm  -  the standard module header: 32 bytes at the
; game's load address (characters 0-3 if its character set is there).
; The game sets, before including it:
;   g_claim   end of the memory it claims (its run-time buffers too)
;   g_jitter  its worst edge timing jitter in cycles (tests/jitter.py)
;   g_share   the most of the cpu (%) the loader may take while it runs
; and has the routines init, frame and stop. The tool fills in the
; song and the music's addresses; init must copy what it needs
; (gk_musinit) before anything draws over the header.
; ------------------------------------------------------------
        byte $50,$4c,$47,$31    ; "PLG1"
        word init
        word frame
        word stop
        word g_claim            ; +10 end of the memory claimed
        byte g_jitter           ; +12 worst edge timing jitter
hsong   byte $ff                ; +13 song (set by the tool), $ff: no music
        byte g_share            ; +14 the most of the cpu (%) the loader may take
        byte 0                  ; +15 (a picture's background: show module only)
hminit  word $c000              ; +16 music init, +18 play (set by the tool)
hmplay  word $c003
        word 312*64,263*64*6/5  ; +20/+22 time between play calls (1/64 lines)
hmflags byte 1                  ; +24 music: 1 the built-in player, 2 a sid
        byte 0                  ; +25 (the picture's vic bank: show module only)
hblocks byte 0                  ; +26 the program's size in disk blocks (set by the tool)
        byte 0,0,0,0,0          ; (to 32 bytes)
