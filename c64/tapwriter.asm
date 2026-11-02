; ------------------------------------------------------------
; tapwriter.asm  -  the SlopLoad TAP writer: any .tap file from disk to
; a cassette, on a C64 (or a C128 in C64 mode, an Ultimate 64) with an
; REU of 512 KB or more
;
; LOAD"TAPWRITER",8 and RUN. Asks for the .tap's drive and name ("$"
; there: the drive's directory, "@" its status and commands), reads
; the whole file into the REU (the disk can't keep up with a tape: a
; pulse every few hundred cycles), then writes it to the cassette with
; every pulse as long as the file says, start to start (CIA 2's timer A
; times the edges). The REU keeps it: the same tape can be written again
; to another cassette.
;
; .tap versions 0 and 1: a byte n is a pulse of 8n cycles; a 0 is, in
; version 1, followed by 3 bytes with the exact count (pauses), in
; version 0 an overflow (written as 2,048 cycles). The cycles are taken
; as they are, at the machine's clock: write a PAL tape on a PAL C64.
;
; Memory: the program $0801 on, the half-pulse tables and the page
; buffer after it; zero page $02-$4f (BASIC's: it leaves through BASIC's
; warm start).
; ------------------------------------------------------------

; ---- KERNAL ----
chrout = $ffd2
chrin = $ffcf
getin = $ffe4
setlfs = $ffba
setnam = $ffbd
open = $ffc0
close = $ffc3
chkin = $ffc6
chkout = $ffc9
clrchn = $ffcc
readst = $ffb7
stop = $ffe1

; ---- zero page ----
t0 = $20                        ; scratch
t1 = $21
t2 = $22
t3 = $23
t4 = $24
t5 = $25
t6 = $26
t7 = $27
p1 = $28                        ; pointers (2 each)
p2 = $2a
p3 = $2c
n24 = $30                       ; numbers to print (3)
xp = $3c                        ; SuperRAM pointer (machine.asm's test)
c0 = $40                        ; writer: bytes left, low byte (0: 256)
chi = $41                       ; ... the rest (2)
have = $43                      ; xbuf holds the next pulse's byte
left = $44                      ; bytes left to fetch
porth = $45                     ; $01, the write line high
portl = $46                     ; ... and low
ver = $47                       ; the .tap's version
lc = $48                        ; a long pulse's cycles (3)
rh = $4b                        ; its high half still to run (3)
lo = $4e                        ; its low half's latch (2)

reumax = 255                    ; REU banks sized (to 16 MB)
minbanks = 8                    ; 512 KB at least

*=$0801
        byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
*=$080d
        jmp main

        incasm "io.asm"
        incasm "disk.asm"
        incasm "machine.asm"

; ---- io.asm's variables ----
inlen   byte 0
inbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
dsbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
prgdev  byte 8                  ; the .tap's drive
prglen  byte 0                  ; its name
prgname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
paddr   word 0                  ; (unused here)
eof     byte 0
tapdev  byte 0                  ; (unused here)
tapfnl  byte 0
tapfname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tapn    byte 0,0,0

; ---- the tape in the REU ----
hdr     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tn      byte 0,0,0,0                ; its bytes (the REU's from 0)
tsize   byte 0,0,0,0                ; ... as its header says
dur     byte 0,0,0,0                ; its cycles
dlong   byte 0                      ; summing: bytes of a long count to come
dlc     byte 0,0,0
loaded  byte 0                      ; a tape is in the REU

; ------------------------------------------------------------
; main
; ------------------------------------------------------------
main    lda #<rtiv              ; restore: nothing (the nmi vector)
        sta $0318
        lda #>rtiv
        sta $0319
        sei                     ; this program's interrupt (cirq; the
        lda #<cirq              ; KERNAL's again at the end: quit)
        sta $0314
        lda #>cirq
        sta $0315
        cli
        lda $01                 ; the motor off (a KERNAL's interrupt may
        ora #$20                ; have started it, PLAY down at READY)
        sta $01
        lda #0
        sta $d020
        sta $d021
        lda #5
        sta 646
        lda #147
        jsr chrout
        jsr detect              ; the machine, the REU
        ldx #<tx_title
        ldy #>tx_title
        jsr print
        lda cpu                 ; a SuperCPU: no way to the tape lines
        cmp #2
        bne @r
        ldx #<tx_noscpu
        ldy #>tx_noscpu
        jmp quit
@r      lda reubanks            ; an REU of 512 KB at least
        cmp #minbanks
        bcs @ok
        ldx #<tx_noreu
        ldy #>tx_noreu
        jmp quit
@ok     jsr tables
        lda #0
        sta loaded
again   ldx #$ff
        txs
        jsr clrchn
        lda #2
        jsr close
        jsr cmdclose
        jsr ask                 ; the .tap: read into the REU
        bcs again
write   jsr presspl
        bcs @n
        ldx #<tx_writing
        ldy #>tx_writing
        jsr print
        jsr wtape
        jsr wdone
        jmp @k
@n      ldx #<tx_stopped
        ldy #>tx_stopped
        jsr print
@k      ldx #<tx_next
        ldy #>tx_next
        jsr print
@g      jsr getin
        beq @g
        cmp #13
        beq write
        cmp #'q'
        bne again
        ldx #<tx_bye
        ldy #>tx_bye
quit    jsr print
        lda #$37
        sta $01
        jsr $ff8a               ; the KERNAL's vectors again (RESTORE: not
        jmp ($a002)             ; this program's rti); BASIC's warm start
rtiv    rti
wdone   ldx #<tx_done           ; (tests stop here)
        ldy #>tx_done
        jmp print

; ------------------------------------------------------------
; ask  the .tap's drive and name; the file read into the REU (said)
;   out:  c set to ask again
; ------------------------------------------------------------
ask     lda prgdev
        ldx #<q_drive
        ldy #>q_drive
        jsr asknum
        bcs ask
        cmp #8
        bcc ask
        cmp #31
        bcs ask
        sta prgdev
        sta ddev                ; ($ and @: disk.asm, on this drive)
        ldx #<tx_dkeys
        ldy #>tx_dkeys
        jsr print
@name   ldx #<q_file
        ldy #>q_file
        jsr print
        lda #16
        jsr readline
        lda inlen
        beq @name
        lda inbuf
        cmp #'$'                ; its directory
        bne @at
        jsr dirshow
        jmp @name
@at     cmp #'@'                ; its status and commands
        bne @nm
        lda inlen
        cmp #1
        bne @nm
        jsr dcmd
        jmp @name
@nm     lda inlen
        sta prglen
        tax
@c      dex
        lda inbuf,x
        sta prgname,x
        txa
        bne @c
        jmp rdtap

; asknum  the question at x/y, its default a in brackets: a number in a,
; c set if not one (the default on an empty line)
asknum  sta t5
        jsr print
        lda t5
        ldx #0
        jsr prdec16
        ldx #<tx_ask
        ldy #>tx_ask
        jsr print
        lda #3
        jsr readline
        jsr innum
        bcc @x
        bne @x
        lda t5
        clc
@x      rts

; ------------------------------------------------------------
; rdtap  the file: its header checked, its bytes into the REU a page at
; a time (and their cycles summed); said
;   out:  c set if it can't be used (said)
; ------------------------------------------------------------
rdtap   lda #0
        sta loaded
        lda #2
        ldx prgdev
        ldy #2
        jsr setlfs
        lda prglen
        ldx #<prgname
        ldy #>prgname
        jsr setnam
        jsr open
        lda prgdev
        jsr dstat
        bcc @o
        jsr prstat
        jmp @bad
@o      ldx #2
        jsr chkin
        ldy #0                  ; the header
@h      jsr chrin
        sta hdr,y
        jsr readst
        bne @short
        iny
        cpy #20
        bcc @h
        ldy #11                 ; "C64-TAPE-RAW"
@sig    lda hdr,y
        cmp tx_sig,y
        bne @notap
        dey
        bpl @sig
        lda hdr+12              ; version 0 or 1
        cmp #2
        bcs @vers
        sta ver
        ldx #3
@sz     lda hdr+16,x
        sta tsize,x
        dex
        bpl @sz
        lda tsize+3             ; within the REU (banks x 64 KB)?
        bne @big
        lda tsize+2
        cmp reubanks
        bcs @big
        jsr clrchn
        ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        jsr rdbody
        bcs @bad
        lda tn                  ; none at all?
        ora tn+1
        ora tn+2
        beq @empty
        jsr sayit
        lda #1
        sta loaded
        clc
        rts
@short  ldx #<tx_short
        ldy #>tx_short
        bne @say
@notap  ldx #<tx_notap
        ldy #>tx_notap
        bne @say
@vers   ldx #<tx_vers
        ldy #>tx_vers
        bne @say
@big    ldx #<tx_big
        ldy #>tx_big
        bne @say
@empty  ldx #<tx_empty
        ldy #>tx_empty
@say    stx t0                  ; (clrchn changes x and y)
        sty t1
        jsr clrchn
        ldx t0
        ldy t1
        jsr print
@bad    jsr clrchn
        lda #2
        jsr close
        sec
        rts

; rdbody  the pulses, to the header's size or the file's end, through
; out into the REU: a version 1 long count that fits a byte (under
; 2,044 cycles: a -hires tape's every pulse) becomes that byte, rounded
; to 8 cycles; a dot every 16 KB read
;   out:  tn (the REU's bytes), dur; c set if stopped (RUN/STOP)
rdbody  lda #0
        ldx #3
@z      sta tn,x
        sta dur,x
        sta tin,x
        dex
        bpl @z
        sta dlong
        sta eof
        sta bi
        ldx #2                  ; the file as input throughout (the
        jsr chkin               ; screen stays the output)
@rd     lda tin                 ; read all the header says?
        cmp tsize
        lda tin+1
        sbc tsize+1
        lda tin+2
        sbc tsize+2
        lda tin+3
        sbc tsize+3
        bcs @fin
        lda eof
        bne @fin
        jsr chrin
        sta t5
        jsr readst
        tax
        and #$bf                ; a read error: said, nothing written (not
        bne @rerr               ; taken for the file's end: a tape short)
        txa
        and #$40
        sta eof
        inc tin                 ; one more read
        bne @1
        inc tin+1
        bne @1
        inc tin+2
@1      lda t5
        jsr conv
        lda tin                 ; every 16 KB: a dot, and RUN/STOP?
        bne @rd
        lda tin+1
        and #$3f
        bne @rd
        lda #'.'
        jsr chrout
        jsr stop
        bne @rd
        jsr clrchn
        lda #2
        jsr close
        ldx #<tx_stopped
        ldy #>tx_stopped
        jsr print
        sec
        rts
@rerr   jsr clrchn
        lda #2
        jsr close
        ldx #<tx_rderr
        ldy #>tx_rderr
        jsr print
        sec
        rts
@fin    lda bi                  ; the last part page
        beq @cl
        sta t6
        jsr stashpg
        lda tn
        clc
        adc bi
        sta tn
        bcc @cl
        inc tn+1
        bne @cl
        inc tn+2
@cl     jsr clrchn
        lda #2
        jsr close
        lda #13
        jsr chrout
        clc
        rts

; conv  the file's byte a: a pulse out, or part of a long count
conv    ldx dlong
        bne @lng
        cmp #0
        bne @b
        ldx ver
        bne @v1
        jsr out                 ; version 0's overflow: 2,048 cycles
        lda #0
        ldx #8
        jmp adddur
@v1     lda #3                  ; a long count: its 3 bytes next
        sta dlong
        rts
@b      pha                     ; a pulse of 8 x a
        sta t0
        lda #0
        asl t0
        rol a
        asl t0
        rol a
        asl t0
        rol a
        tax
        lda t0
        jsr adddur
        pla
        jmp out
@lng    pha                     ; a long count's byte (low first)
        lda #3
        sec
        sbc dlong
        tax
        pla
        sta dlc,x
        dec dlong
        bne @x
        lda dlc+2               ; under 2,044 (rounded: 1-255 units)?
        bne @long
        lda dlc+1
        cmp #>2044
        bcc @short
        bne @long
        lda dlc
        cmp #<2044
        bcs @long
@short  lda dlc                 ; (c + 4) / 8
        clc
        adc #4
        sta t0
        lda dlc+1
        adc #0
        lsr a
        ror t0
        lsr a
        ror t0
        lsr a
        ror t0
        lda t0
        bne @b                  ; (0: a count under 4, dropped)
@x      rts
@long   lda dlc                 ; kept as it is: 0 and the 3 bytes
        ldx dlc+1
        jsr adddur
        lda dlc+2
        clc
        adc dur+2
        sta dur+2
        bcc @o
        inc dur+3
@o      lda #0
        jsr out
        lda dlc
        jsr out
        lda dlc+1
        jsr out
        lda dlc+2
        jmp out

; out  byte a to buf; a full page stashed at tn
out     ldx bi
        sta buf,x
        inc bi
        bne @x
        lda #0                  ; (256)
        sta t6
        jsr stashpg
        inc tn+1
        bne @x
        inc tn+2
@x      rts
tin     byte 0,0,0,0            ; the file's bytes read
bi      byte 0                  ; in buf

; stashpg  buf's t6 bytes (0: 256) to the REU at tn
stashpg lda #<buf
        sta $df02
        lda #>buf
        sta $df03
        lda tn
        sta $df04
        lda tn+1
        sta $df05
        lda tn+2
        sta $df06
        lda t6
        sta $df07
        lda #0
        sta $df09
        sta $df0a
        lda t6
        bne @n
        lda #1                  ; (256)
        bne @h
@n      lda #0
@h      sta $df08
        lda #$90
        sta $df01
        bit $d020
        rts

; adddur  a/x to dur
adddur  clc
        adc dur
        sta dur
        txa
        adc dur+1
        sta dur+1
        bcc @x
        inc dur+2
        bne @x
        inc dur+3
@x      rts

; sayit  "nnnn kb, mm:ss of tape"
sayit   lda tn+1                ; KB: tn / 1024, rounded up
        clc
        adc #3
        sta t0
        lda tn+2
        adc #0
        lsr a
        ror t0
        lsr a
        ror t0
        tax
        lda t0
        jsr prdec16
        ldx #<tx_kb
        ldy #>tx_kb
        jsr print
        jsr secs                ; seconds: dur / 985248
        lda t0                  ; minutes: / 60
        sta t2
        lda t1
        sta t3
        lda #0
        sta t4                  ; minutes
@m      lda t2
        sec
        sbc #60
        tax
        lda t3
        sbc #0
        bcc @mx
        sta t3
        stx t2
        inc t4
        bne @m
@mx     lda t4
        ldx #0
        jsr prdec16
        lda #':'
        jsr chrout
        lda t2
        cmp #10
        bcs @s
        lda #'0'
        jsr chrout
        lda t2
@s      ldx #0
        jsr prdec16
        ldx #<tx_long
        ldy #>tx_long
        jmp print

; secs  t0/t1: dur / 985248, rounded down (dur / 16 by 61578)
secs    lda dur                 ; n = dur / 16 (28 bits)
        sta t4
        lda dur+1
        sta t5
        lda dur+2
        sta t6
        lda dur+3
        sta t7
        ldx #4
@sh     lsr t7
        ror t6
        ror t5
        ror t4
        dex
        bne @sh
        lda #0                  ; t0/t1 = n / 61578 (shift-subtract)
        sta t0
        sta t1
        sta t2                  ; remainder (3 bytes)
        sta t3
        sta n24
        ldx #32
@d      asl t4
        rol t5
        rol t6
        rol t7
        rol t2
        rol t3
        rol n24
        lda t2
        sec
        sbc #<61578
        sta p1
        lda t3
        sbc #>61578
        sta p1+1
        lda n24
        sbc #0
        bcc @no
        sta n24
        lda p1
        sta t2
        lda p1+1
        sta t3
@no     rol t0
        rol t1
        dex
        bne @d
        rts

; ------------------------------------------------------------
; presspl  "press record and play": waits for the cassette's sense line
; (the cassette is this program's own: its lines driven here, the
; KERNAL's tape code never used, so any KERNAL will do, one without tape
; routines too: see cirq)
;   out:  c set if RUN/STOP was pressed instead
; ------------------------------------------------------------
presspl ldx #<tx_press
        ldy #>tx_press
        jsr print
        lda $00                 ; the write line and the motor outputs
        ora #$28
        sta $00
@pr     jsr stop
        beq @abort
        lda $01
        and #$10
        bne @pr
        clc
        rts
@abort  sec
        rts

; cirq  the interrupt while this program runs: the KERNAL's clock (and the
; STOP key) and its keyboard, through the jump table; never the rest of
; the KERNAL's interrupt, whose tape motor code (where a KERNAL has it:
; JiffyDOS has none) would start the motor whenever PLAY is down
cirq    jsr $ffea
        jsr $ff9f
        lda $dc0d
        pla
        tay
        pla
        tax
        pla
        rti

; ------------------------------------------------------------
; tables  htl/hth: each byte n's half pulse as a timer latch, 4n - 1
; ------------------------------------------------------------
tables  ldx #0
@t      txa
        sta t0
        lda #0
        asl t0
        rol a
        asl t0
        rol a
        sta t1
        lda t0                  ; - 1
        sec
        sbc #1
        sta htl,x
        lda t1
        sbc #0
        sta hth,x
        inx
        bne @t
        rts

; ------------------------------------------------------------
; wtape  the REU's tn bytes to the cassette: interrupts off, the screen
; off, the motor on; each pulse starts with the write line going high
; (where the read side times it), its second half low. Halves of 50
; cycles or more (pulses of 100).
;
; Each pulse: at its start the line goes high and the byte two pulses
; on is fetched (one byte's DMA into xbuf); at its middle the line goes
; low and the next pulse's half goes into the latch (used from the
; underflow that starts it, for both its halves). A 0 (a version 1
; tape's long count, or a version 0 overflow): its first 512 cycles
; high, while its length is read (2,048 at least), the rest of its high
; half in chunks of up to 32,768 cycles with the line kept high, then
; its low half.
; ------------------------------------------------------------
wtape   lda $01                 ; the motor on, getting up to speed over
        and #$df                ; the frame the screen takes to go blank
        sta $01
        lda #0                  ; the screen off (no bad lines)
        sta $d030               ; (a C128 at 1 MHz)
        lda $d011
        and #$ef
        sta $d011
@w      bit $d011               ; a whole frame without the display
        bpl @w
@w2     bit $d011
        bmi @w2
@w3     bit $d011
        bpl @w3
        sei
        lda $01
        and #$df                ; the motor on
        ora #$08
        sta porth
        and #$f7
        sta portl
        sta $01                 ; the line low
        lda #$7f
        sta $dd0d
        lda #0
        sta $dd0e
        lda #<xbuf              ; the REU from its start, a byte at a time
        sta $df02               ; into xbuf (the C64 address held)
        lda #>xbuf
        sta $df03
        lda #0
        sta $df04
        sta $df05
        sta $df06
        sta $df08
        sta $df09
        lda #1
        sta $df07
        lda #$80
        sta $df0a
        lda tn                  ; bytes left: tn (c0 0 meaning 256)
        sta c0
        lda tn+1
        sta chi
        lda tn+2
        sta chi+1
        lda #1
        sta left
        sta have
        lda c0
        bne @c
        jsr cnthi
@c      jsr get                 ; the first pulse's byte
        lda #<999               ; a low half's while it is set up, then
        sta $dd04               ; the first pulse
        lda #>999
        sta $dd05
        lda $dd0d
        lda #$11                ; continuous, force load, start
        sta $dd0e
        jmp prep

; the loop: a pulse's start, the byte after next fetched
wu0     lda $dd0d
        lsr a
        bcc wu0
        lda porth
        sta $01
        lda left
        beq @none
        lda #1
        sta $df07
        lda #$91
        sta $df01
        dec c0
        bne wu1
        jsr cnthi
        jmp wu1
@none   sta have                ; (a = 0: no pulse after this one)
; its middle: the next pulse's half
wu1     lda $dd0d
        lsr a
        bcc wu1
        lda portl
        sta $01
prep    lda have
        beq wend
        ldx xbuf
        beq wlong
        lda htl,x
        sta $dd04
        lda hth,x
        sta $dd05
        jmp wu0

; the end: the last pulse's end, the line high, the timer stopped
wend    lda $dd0d
        lsr a
        bcc wend
        lda porth
        sta $01
        lda #0
        sta $dd0e
        sta $df0a
        lda $dd0d
        lda $01                 ; the motor off
        ora #$20
        sta $01
        lda $d011               ; the screen on
        ora #$10
        sta $d011
        cli
        rts

; a long pulse: 512 cycles of it high, then its length
wlong   lda #<511
        sta $dd04
        lda #>511
        sta $dd05
@l0     lda $dd0d
        lsr a
        bcc @l0
        lda porth
        sta $01
        lda #<2048              ; version 0: 2,048 cycles
        sta lc
        lda #>2048
        sta lc+1
        lda #0
        sta lc+2
        lda ver
        beq @lc
        ldx #0                  ; version 1: the next 3 bytes
@g3     stx t7
        jsr get
        lda have
        beq @lc                 ; (the file ends: as 2,048)
        ldx t7
        lda xbuf
        sta lc,x
        inx
        cpx #3
        bcc @g3
@lc     lda lc+2                ; at least 2,048
        bne @l1
        lda lc+1
        cmp #8
        bcs @l1
        lda #8
        sta lc+1
        lda #0
        sta lc
@l1     lda lc+2                ; low half: c / 2, or 32,768 from 131,072 on
        cmp #2
        bcc @half
        lda #0
        sta t0
        lda #$80
        sta t1
        bne @hl
@half   lsr a
        lda lc+1
        ror a
        sta t1
        lda lc
        ror a
        sta t0
@hl     lda t0                  ; its latch: low half - 1
        sec
        sbc #1
        sta lo
        lda t1
        sbc #0
        sta lo+1
        lda lc                  ; the high half still to run: c - low - 512
        sec
        sbc t0
        sta rh
        lda lc+1
        sbc t1
        sta rh+1
        lda lc+2
        sbc #0
        sta rh+2
        lda rh+1
        sec
        sbc #2
        sta rh+1
        lda rh+2
        sbc #0
        sta rh+2
@ch     lda rh+2                ; the next chunk: 32,768 while 65,536 or
        beq @rest               ; more are left, else the rest
        lda #<32767
        sta $dd04
        lda #>32767
        sta $dd05
        lda rh+1
        sec
        sbc #$80
        sta rh+1
        lda rh+2
        sbc #0
        sta rh+2
        jmp @cw
@rest   lda rh                  ; the rest: its latch
        sec
        sbc #1
        sta $dd04
        lda rh+1
        sbc #0
        sta $dd05
        lda #0
        sta rh
        sta rh+1
@cw     lda $dd0d               ; that chunk starts (the line stays high)
        lsr a
        bcc @cw
        lda rh
        ora rh+1
        ora rh+2
        bne @ch
        lda lo                  ; the last high chunk runs: the low half next
        sta $dd04
        lda lo+1
        sta $dd05
@lw     lda $dd0d
        lsr a
        bcc @lw
        lda portl
        sta $01
        jsr get                 ; the next pulse's byte, then on
        jmp prep

; get  the next byte into xbuf (have 0 if there are none)
get     lda left
        beq @none
        lda #1
        sta $df07
        lda #$91
        sta $df01
        bit $d020
        dec c0
        bne @x
        jmp cnthi
@none   sta have
@x      rts

; cnthi  c0 reached 0: none left (chi 0), or 256 more from the rest
cnthi   lda chi
        ora chi+1
        bne @more
        sta left                ; (a = 0)
        rts
@more   lda chi
        bne @d
        dec chi+1
        inc $d020               ; (every 64 KB: the border's colour on)
@d      dec chi
        rts

; ---- texts ----
tx_title text 13,"slopload tap writer - a .tap to tape",13,13,0
tx_noscpu text "a supercpu can't reach the cassette",13,"port: switch it off and run this",13,"with an reu.",13,0
tx_noreu text "this needs an reu of 512 kb or more.",13,0
tx_bye  text "bye.",13,0
q_drive text "drive with the .tap file [",0
q_file  text "its file name? ",0
tx_dkeys text "($: its directory, @: the disk)",13,0
tx_ask  text "]? ",0
tx_reading text "reading it into the reu",0
tx_kb   text " kb, ",0
tx_long text " of tape",13,0
tx_short text "the file is too short for a .tap",13,0
tx_notap text "not a .tap file",13,0
tx_vers text "only .tap versions 0 and 1",13,0
tx_big  text "too big for the reu",13,0
tx_empty text "no pulses in it",13,0
tx_press text 13,"press record and play on tape",13,0
tx_writing text "writing...",13,0
tx_done text "done.",13,0
tx_stopped text "stopped.",13,0
tx_next text 13,"return: write it again (another tape)",13,"q: quit  other keys: another .tap",13,0
tx_sig  byte $43,$36,$34,$2d,$54,$41,$50,$45,$2d,$52,$41,$57   ; "C64-TAPE-RAW"

; ---- buffers ----
        byte 0
htl = (* + 255) / 256 * 256     ; latch low byte, a page
hth = htl + 256                 ; latch high byte
buf = hth + 256                 ; a page from the file
reusav = buf + 256              ; the REU's banks' first bytes (sizing)
bssend = reusav + 256
