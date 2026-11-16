; ------------------------------------------------------------
; machine.asm  -  what the machine has, for SlopLoad 64 and the TAP
; writer: an accelerator (for the work between disk and tape) and
; expansion memory
;
; Accelerators (found once, at the start; turbo only while computing:
; fast / slow around it, 1 MHz for the KERNAL's disk routines and the
; tape):
;   SuperCPU  20 MHz throughout, every write copied to the C64's memory
;             (its own ROM serves the serial bus at that speed)
;   Ultimate  with its turbo registers on: $d031 = $0f while computing,
;             its old value after
;   C128      2 MHz in the vertical border only (raster interrupts at
;             lines 251 and 44), the picture at 1 MHz
; Expansion memory:
;   SuperRAM  a SuperCPU's, the free area CMD's ROM keeps at $d27c-$d27f
;   REU       any 17xx (or one on a SuperCPU, a C128, an Ultimate), sized
;             up to reumax banks of 64 KB (the includer's equate, with
;             reusav: reumax bytes for each bank's first byte, put back)
; ------------------------------------------------------------

cpu     byte 0                  ; 0 C64, 1 C128, 2 SuperCPU, 3 Ultimate
u64old  byte 0                  ; $d031 as found
infast  byte 0
irqst   byte 0
reubanks byte 0                 ; an REU's 64 KB banks (reumax: that or more)
srsp    byte 0                  ; SuperRAM: first free page, its bank,
srsb    byte 0                  ; the last free page + 1, its bank (0:
srep    byte 0                  ; none)
sreb    byte 0
xkind   byte 0                  ; what there is: 0 none, 1 REU, 2 SuperRAM
xbuf    byte 0                  ; an REU's byte at a time
isntsc  byte 0                  ; 1: an NTSC picture (263 lines or 262)

; srpages  t0/t1: SuperRAM's free pages (c clear if the end is before
; the start)
srpages lda srep
        sec
        sbc srsp
        sta t0
        lda sreb
        sbc srsb
        sta t1
        rts

; ------------------------------------------------------------
; fast / slow  the accelerator on for computing, and off again (1 MHz
; for the disk and the tape); a SuperCPU stays at 20 MHz
; ------------------------------------------------------------
fast    lda infast
        bne @x
        inc infast
        lda cpu
        cmp #3
        bne @c
        lda #$0f                ; an Ultimate: top speed
        sta $d031
        rts
@c      cmp #1
        bne @x
        sei                     ; a C128: 2 MHz from line 251 to 44
        lda $0314               ; (the interrupt it had, whatever it is:
        sta irqk+1              ; irq2 passes the rest to it, and slow
        lda $0315               ; puts it back)
        sta irqk+2
        lda #<irq2
        sta $0314
        lda #>irq2
        sta $0315
        lda #0
        sta irqst
        lda $d011
        and #$7f
        sta $d011
        lda #251
        sta $d012
        lda #$0f                ; (anything pending cleared first)
        sta $d019
        lda #1
        sta $d01a
        cli
@x      rts

slow    php                     ; (the flags kept)
        lda infast
        beq @x
        lda #0
        sta infast
        lda cpu
        cmp #3
        bne @c
        lda u64old
        sta $d031
        plp
        rts
@c      cmp #1
        bne @x
        sei
        lda #0
        sta $d01a
        sta $d030
        lda #$0f
        sta $d019
        lda irqk+1
        sta $0314
        lda irqk+2
        sta $0315
@x      plp
        rts

; irq2  a C128's raster interrupts: 2 MHz at line 251, 1 MHz at 44 (else
; the interrupt there was before fast: irqk, set by fast)
irq2    lda $d019
        lsr a
        bcc irqk
        lda #1
        sta $d019
        lda irqst
        eor #1
        sta irqst
        sta $d030
        tax
        lda irqln,x
        sta $d012
        jmp $ea81
irqk    jmp $ea31
irqln   byte 251,44
