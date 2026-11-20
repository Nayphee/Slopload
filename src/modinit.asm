; ------------------------------------------------------------
; modinit.asm  -  the kit's routines that only init calls (the
; standard: MODULES.md). Include it anywhere in the module's memory,
; beside modkit.asm or where init runs from (Crossy-Load runs its init
; from a screen buffer it draws over afterwards: boot.asm).
;   gk_musinit  copy the header's music fields (call first in init)
;   sidinit     the SID cleared, voice 3 ready for effects
;   gk_bank     the VIC bank the module is in (3; 2 where a tool moved it)
; ------------------------------------------------------------

; gk_bank  the VIC bank the module is in: bank 3 as built, 2 where a tool
; moved it a bank down for a chain (its own address's high byte, one of
; its relocations, says which); $dd00's bits
;   uses: a
gk_bank lda $dd02
        ora #3
        sta $dd02
        lda #>gk_bank           ; ($c0-$ff: bank 3; $80-$bf: bank 2)
        clc
        rol a
        rol a
        rol a                   ; (its top two bits: the bank)
        eor #3                  ; ($dd00's bits for it)
        sta @b+1
        lda $dd00
        and #$fc
@b      ora #0                  ; (the bits, written in)
        sta $dd00
        rts

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
        and #gk_chain           ; (a tune playing on: gk_keep until mplay,
        sta gk_kon              ; from the line now: just after the last play
        lda $d011               ; call, a new frame after it its next)
        and #$80
        sta gk_kh
        lda $d012
        sta gk_kl
        lda hblocks             ; the blocks to count down
        sta gk_blk
        rts

; sidinit  the music on voices 1 and 2 (and 3 when no effect plays:
; the built-in player is told to leave voice 3 alone); with a tune
; already playing (a chain's second module, the music first), the SID
; as the tune has it, but for voice 3 when it is the effects' from here
; (gk_musinit first)
sidinit lda gk_opt              ; a tune playing on (+28 bit 4): the SID as
        and #gk_chain           ; it has it
        beq @all
        lda mflags              ; SlopLoad's player, about to be told to leave
        lsr a                   ; voice 3 alone (musicgo): the note it has on
        bcc @x                  ; there would sound on until the first effect
        lda #0
        sta $d412
        beq @v3                 ; (always)
@all    ldx #$18
        lda #0
@c      sta $d400,x
        dex
        bpl @c
        lda #$0f
        sta $d418
@v3     lda #$08
        sta $d410
        sta $d411               ; voice 3 pulse 50%
@x      rts
