; ------------------------------------------------------------
; chain.asm  -  two modules, one after the other (slopload.py -then):
; the first shows while the second's parts load, then the second
; while the program loads. The tool assembles this with the modules'
; entry points and loads it with the first module; the core's pt_init
; is the first's init, its pt_frame and pt_stop come here.
;
; The second module's last block has f_chain in its flags, which the
; core ORs into ld_ev. At the first frame after it:
;   - the core's frame vector moved to the second's frame: this isn't
;     called again;
;   - the progress begun again for the program (pt_step, the progress
;     a page: until now the second module's parts');
;   - in the vertical blank the screen off, the sprites off and back to
;     one size, in front, one colour; 40 columns and no fine scroll
;     (what the core leaves a module's init: the screen off);
;   - the second's init, then its frame.
; The first's stop is never called: its tune plays on, and the second,
; told so (header +28 bit 4: the tool's), doesn't start it again.
;
; At $0380 in the tape buffer: stage 1's header part ran here and is
; done with once the core runs, and the core's exit stub ($0334-$0371)
; goes there only after the modules have stopped.
; ------------------------------------------------------------
        incasm "abi.asm"

chainat = $0380
a_frame = $c003                 ; the tool's: the first module's frame and
a_stop = $c006                  ; stop, the second's init, frame and stop,
b_init = $c000                  ; the program's progress a page (8.8), and
b_frame = $c003                 ; the core's vectors (its patch area)
b_stop = $c006
pstep = $0100
pt_frame = $0407
pt_step = $040b

*=chainat
; ------------------------------------------------------------
; cframe  the core's game frame: the first module's until the second
; is in, then the switch
;   out:  the module's frame's carry (set: the program may start)
; ------------------------------------------------------------
cframe  lda ld_ev
        and #f_chain
        bne @sw
        jmp (cafr)
@sw     inc cdone
        lda cbfr                ; from now on the core calls the second's
        sta pt_frame
        lda cbfr+1
        sta pt_frame+1
        lda cpst                ; and counts the program's progress
        sta pt_step
        lda cpst+1
        sta pt_step+1
        lda #0
        sta ld_progress
@w      bit $d011               ; the vertical blank: line 251 on (the
        bmi @vb                 ; screen off with no part of a frame torn)
        lda $d012
        cmp #251
        bcc @w
@vb     lda #$0b
        sta $d011
        lda #0
        sta $d015               ; the first's sprites off, as the KERNAL
        sta $d017               ; leaves them
        sta $d01b
        sta $d01c
        sta $d01d
        lda #$08                ; hires, 40 columns, no fine scroll
        sta $d016
        jsr @in
        jmp (cbfr)
@in     jmp (cbin)

; ------------------------------------------------------------
; cstop  the core's stop: the second's, or the first's if the program is
; in before the switch
; ------------------------------------------------------------
cstop   lda cdone
        bne @b
        jmp (cast)
@b      jmp (cbst)

cdone   byte 0                  ; 1: switched
; the tool's (SlopLoad 64 patches these 12 bytes in a copy): the first
; module's frame and stop, the second's init, frame and stop, and the
; program's progress a page (8.8)
cafr    word a_frame
cast    word a_stop
cbin    word b_init
cbfr    word b_frame
cbst    word b_stop
cpst    word pstep
chainend
