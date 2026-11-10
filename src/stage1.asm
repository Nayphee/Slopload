; ------------------------------------------------------------
; stage1.asm  -  SlopLoad stage 1
;
; Loaded by the KERNAL's own tape loader in two pieces:
;   - the spare bytes of the tape header, $0351-$03fb (main part)
;   - the data block, s1lo-$0303: the subroutines below, then the
;     BASIC vectors $0300-$0303 with the idle vector ($0302)
;     pointing at s1, so this runs as soon as LOAD has finished.
;     (tools/build.py moves s1lo up so the block ends at $02ff:
;     the smaller the block, the shorter the KERNAL's part.)
;
; It polls the tape (no interrupts, screen off), measures the
; pilot to calibrate, and loads the core to $0400 (s1_pages whole
; pages, then an xor check byte), then jumps to it. On a bad check
; byte it turns the border red and waits for the block again, so
; rewinding a little and pressing play retries.
;
; RESTORE is locked out from here to the program's start: cia2's timer
; a interrupt is enabled once and never read, so its first underflow
; holds the NMI line low and the key can no longer make an edge on it
; (the trick TND's Loader Game Tape Master Kit 3 used). That one NMI
; goes to an rti; the core's exit releases the line (s1ioi).
; ------------------------------------------------------------
        incasm "abi.asm"

core = $0400
s1lo = $02c0                    ; set by tools/build.py

*=s1lo
; ------------------------------------------------------------
; s1getb  read one byte (4 pulses of 2 bits, msb first)
;   out:  a = byte
;   uses: a, x, ld_sr
; ------------------------------------------------------------
s1getb  lda #1                  ; marker bit, shifted out after 4 pulses
@pl     sta ld_sr
        jsr s1getp
        lda ld_sr
        asl a
        asl a
        ora s1dtab,x
        bcc @pl
        rts

; ------------------------------------------------------------
; s1getp  wait for the next tape edge and measure the pulse
;   out:  x = cia2 timer b (11 - quanta since the last edge)
;   uses: a, x
;   note: timer a is restarted before timer b is read, so the
;         measurement and the next pulse start at the same cycle
; ------------------------------------------------------------
s1getp  lda #$10
@w      bit $dc0d               ; flag: an edge from the tape
        beq @w
        lda #cia_ta_run
        sta $dd0e               ; quantum timer back to phase 0
        ldx $dd06               ; quanta left
        lda #cia_tb_count
        sta $dd0f               ; count quanta again from 11
s1str   stx $d020               ; border stripes (slopload.py: bit, for a flat border)
        rts

; timer b value -> 2 bits (classes 3,3,3,2,2,1,1,0,0,0,0,0)
s1dtab  byte 3,3,3,2,2,1,1,0,0,0,0,0
s1_pages byte 3                 ; core length in pages (set by the tool)

; s1ioi  the core's exit stub calls it in place of the KERNAL's ioinit:
; ioinit (the cias' interrupts off, their timers stopped), then $dd0d
; read: the interrupt stage 1 left pending is gone, the NMI line free,
; so RESTORE (and a program's own NMIs) work again. The last 7 bytes
; before $0300: abi.asm's s1ioi, nothing loads here
s1rel   jsr $ff84               ; (at s1ioi: tools/build.py checks)
        bit $dd0d
        rts
s1lowend

*=$0300
        word $e38b              ; IERROR as the KERNAL has it
        word s1                 ; IMAIN: BASIC's idle loop comes here

*=$0351
s1      sei
        cld
        lda #<s1rti             ; an nmi (through the KERNAL's $0318) to an rti
        sta $0318
        lda #>s1rti
        sta $0319
        lda #$7f
        sta $dc0d               ; no cia interrupts
        sta $dd0d
        lda #$81                ; but cia2's timer a: its first underflow
        sta $dd0d               ; holds the nmi line low (RESTORE locked out)
        lda #$0b
        sta $d011               ; screen off: no bad lines, no jitter
s1bc    lda #0                  ; the border (slopload.py: a flat border's colour)
        sta $d020
        lda #0
        sta $dd05               ; cia2 ta latch hi
        sta $dd07               ; cia2 tb latch hi
        lda #tb_start
        sta $dd06
        lda #$ff
        sta $dc06               ; cia1 tb latch = $ffff: the stopwatch
        sta $dc07
        lda $01
        and #$1f                ; cassette motor on
        sta $01
s1again lda #>core
        sta s1dst+2
        lda s1_pages
        sta s1left

; ---- find a pilot, measure it, wait for the sync pulse ----
s1sync  lda #h_def-1
        sta $dd04               ; wide window until measured
        ldy #0                  ; y = pilot pulses so far
        sty ld_cal
@p      jsr s1getp
        cpx #7
        bcc @nc0                ; not class 0
        cpx #tb_start
        bcs s1sync              ; gap or glitch
        iny
        cpy #cal_start
        bne @n1
        lda #cia_ta_run
        sta $dc0f               ; stopwatch from $ffff
@n1     cpy #cal_end
        bne @p
        lda #$fe                ; 128 pulses of 4h = 512h cycles:
        sec                     ; ($ff - hi) = elapsed / 256 = 2h (rounded
        sbc $dc07               ; up), less 1
        lsr a                   ; h-1: the latch for a period of h
        sta $dd04
        sta ld_cal              ; non-zero: measured
        bne @p                  ; (always)
@nc0    cpx #3
        bcs s1sync              ; class 1 or 2 inside a pilot: noise
        lda ld_cal
        beq s1sync              ; class 3 before the measurement

; ---- synced: s1_pages pages to $0400, then the check byte ----
s1load  ldy #0
        sty ld_chk
@ld     jsr s1getb
s1dst   = *
        sta core,y
        eor ld_chk
        sta ld_chk
        iny
        bne @ld
        inc s1dst+2
        dec s1left
        bne @ld
        jsr s1getb
        cmp ld_chk
        beq core
s1bad   lda #2                  ; red: rewind a little, press play
        sta $d020
        bne s1again             ; (always)
s1rti   rti                     ; (the nmi that locks RESTORE out)

s1left  byte 3                  ; pages still to load
