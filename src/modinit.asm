; ------------------------------------------------------------
; modinit.asm  -  the kit's routines that only init calls (the
; standard: MODULES.md). Include it anywhere in the module's memory,
; beside modkit.asm or where init runs from (Crossy-Load runs its init
; from a screen buffer it draws over afterwards: boot.asm).
;   gk_musinit  copy the header's music fields (call first in init)
;   sidinit     the SID cleared, voice 3 ready for effects
; ------------------------------------------------------------

; gk_musinit  the music's addresses, the tool's options and the
; program's blocks from the header (it may be drawn over later: a
; game's character set often starts there)
gk_musinit
        lda hminit
        sta minit+1
        lda hminit+1
        sta minit+2
        lda hmplay
        sta mplayr+1
        lda hmplay+1
        sta mplayr+2
        lda hmflags
        sta mflags
        lda hopt                ; the tool's options (-wait, -countdown)
        sta gk_opt
        lda hblocks             ; the blocks to count down
        sta gk_blk
        rts

; sidinit  the music on voices 1 and 2 (and 3 when no effect plays:
; the built-in player is told to leave voice 3 alone); in a chain's
; second module, with a tune already playing, nothing (gk_musinit first)
sidinit lda gk_opt              ; a chain's second module (+28 bit 4): the
        and #gk_chain           ; tune plays on, the SID as it has it
        bne @x
        ldx #$18
        lda #0
@c      sta $d400,x
        dex
        bpl @c
        lda #$0f
        sta $d418
        lda #$08
        sta $d410
        sta $d411               ; voice 3 pulse 50%
@x      rts
