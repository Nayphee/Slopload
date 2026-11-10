; ------------------------------------------------------------
; modhead.asm  -  the standard module header: 32 bytes at the
; game's load address (characters 0-3 if its character set is there).
; The game sets, before including it:
;   g_claim   end of the memory it claims (its run-time buffers too)
;   g_jitter  its worst edge timing jitter in cycles (tests/jitter.py)
;   g_share   the most of the cpu (%) the loader may take while it runs
;   g_border  1 if it leaves the border alone while ld_state bit 5 is
;             set (gk_bord; the loader's -showstripes), else 0
;   g_sfx     1 if it makes sound effects on voice 3 when the music is
;             SlopLoad's own player (header +24 = 1), else 0
;   g_wait    1 if it keeps the tool's -wait (header +28 bit 1): once
;             loaded it stays until SPACE (the kit's startkey) or, a
;             game, the end of a game (gk_done); a loading screen holds
;             at its end until SPACE; else 0. Without -wait every module
;             ends as soon as the program is in
;   g_count   1 if its status line counts the blocks left with the
;             tool's -countdown (header +28 bit 3: the kit's status),
;             else 0
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
        byte g_border+g_sfx*2+g_wait*4+g_count*8+gk_chain
                                ; +27 bit 0: it leaves the border to the loader (ld_state
                                ; bit 5); bit 1: its effects on voice 3 (SlopLoad's player);
                                ; bit 2: it keeps -wait; bit 3: it keeps -countdown; bit 4:
                                ; second in a chain, it plays on the tune the first started
                                ; (the kit's sidinit and musicgo)
hopt    byte 0                  ; +28 the tool's options: bit 1 -wait, bit 3 -countdown,
                                ; bit 4 a chain's tune already playing
        byte 0,0,0              ; (to 32 bytes)
