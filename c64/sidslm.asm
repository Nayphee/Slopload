; ------------------------------------------------------------
; sidslm.asm  -  SID-SLM: a .sid tune made ready for SlopLoad 64, on the
; C64: tried out, its stores the loader can't allow taken out, written as
; a .slm, the file SlopLoad 64 reads for its music
;
; LOAD"SID-SLM",8 and RUN. Asks for the drive and the .sid file ("$" for
; the drive's directory, "$:sl*" for the names starting sl, "@" for its
; status and commands: disk.asm, as SlopLoad 64's @), and the song, when
; it has several; tries it out (its init and 3,000 play
; calls in a 6502 emulated in memory, trial.asm: about two minutes on a
; stock C64), says what it found, asks for the .slm's name (the .sid's,
; ending .slm) and writes it. A tune it refuses gets a reason. RUN/STOP
; stops a trial.
;
; A tune over 4,096 bytes: asked, its song is cut down to the part it
; uses (sidcut.asm, as the PC's sidstrip.py -cut: five minutes of play
; watched, then the cut tried over the same five; about half an hour or
; more on a stock C64), then written as any other. A file longer than
; the stage (about 17 KB) is read to its end all the same: the stage
; keeps its start, ring its last 256 bytes; cut, the tune's pages the
; stage hasn't room for are read from the file again when the song first
; uses them (pgread, for sidcut.asm's pager), so the disk must stay in.
;
; The .slm is tools/sidstrip.py's format (SLM2) without relocations:
; SlopLoad 64 plays it where it was written for, as it did a .sid it
; tried itself. sidstrip.py's own .slm (five minutes of play, on a PC)
; can also move.
;
; Memory: the program $0801 on; the tune's bytes in the music pool after
; it (its offset in its page kept), the file read after that, to $9fff;
; the trial's tables at $a000-$aaff, its pages $ab-$fe (and the file's
; from $8000 once the tune is in the music pool: npool), with $01 = $34;
; the cut's tables $c000-$ceff (ring, the file's last bytes, at $cc00
; until then). A file longer than the stage, cut: its tune's pages that
; fit below $8000 in the stage, its last at $fe00. Zero page $20-$3e (BASIC's), $40-$5f
; (the trial's), $60-$72, $02, $8b-$8f and $fb-$fe (the cut's): it
; leaves through BASIC's warm start.
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
plot = $fff0

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
n24 = $30                       ; division: dividend (4), quotient (4),
q24 = $34                       ; remainder (2)
rem = $38
cnt = $3a                       ; bytes to go (2)
xp = $3c                        ; SuperRAM pointer (machine.asm's test)

reumax = 1                      ; (machine.asm: an REU found, not sized)
mpoolp = (bssend + 255) / 256   ; the music pool's page: 4096 + 256 bytes
mpool = mpoolp*256              ; after the program
stage = mpool + $1100           ; the file, as read: up to $9fff
stagemax = $a000 - stage
ring = $cc00                    ; the file's last 256 bytes as read (rdfile;
                                ; sidcut.asm's ctdl later)
trcalls = 3000                  ; the trial's play calls
cutcalls = 15000                ; ... a cut's (five minutes, as the PC's)

*=$0801
        byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
*=$080d
        jmp main

        incasm "io.asm"
prch = chrout                   ; (print's character: no words packed here)
        incasm "disk.asm"
        incasm "wfile.asm"
        incasm "machine.asm"
        incasm "math.asm"
        incasm "sidread.asm"
        incasm "trial.asm"
        incasm "sidcut.asm"

; ---- io.asm's variables ----
inlen   byte 0
inbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
dsbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
prgdev  byte 8                  ; the drive
prglen  byte 0                  ; the .sid's name
prgname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
paddr   word 0                  ; (unused here)
eof     byte 0
tapdev  byte 0                  ; (unused here)
tapfnl  byte 0
tapfname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tapn    byte 0,0,0
reusav  byte 0                  ; (machine.asm)

; ---- the tune (sidread.asm's) ----
flen    word 0                  ; the file's length
mok     byte 0                  ; 1: ready, 2: refused
mwhy    byte 0                  ; why (a reason number)
mwhya   word 0                  ; ... and the address in it
mkind   byte 0
msong   byte 1                  ; the song chosen (1-)
msongs  byte 1
mload   word 0                  ; where it plays
mlen    word 0
minit   word 0
mplay   word 0
ma      byte 0                  ; init's a: the song - 1
mppal   word 0                  ; time between play calls (1/64 lines): PAL
mpntsc  word 0                  ; ... NTSC
mcyc    word 0                  ; its longest play call, cycles
mcia    byte 0                  ; 1: timed by CIA 1
mzp     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mnws    byte 0                  ; its workspace: runs (lo, hi exclusive)
mws     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mtitle  byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mver    byte 0                  ; the header's version, flags (low byte),
mflg    byte 0                  ; speed bits (big-endian)
mspd    byte 0,0,0,0
mcut    byte 0                  ; 1: over 4096 bytes, its song cut down
mdat    word 0                  ; where its bytes start in the file (stage)
mcalls  word 0                  ; the trial's play calls
mfoff   word 0                  ; (cut: the tune's place in the file,
mhave   word 0                  ; its bytes in the stage, the stage's
pgend   byte 0                  ; first page after them,
cutsp   byte 0                  ; cutsid's s, for cutout)
pgeof   byte 0                  ; (pgread: the file's end reached)
mof     word 0                  ; (cut: the whole tune's length,
mtexts  byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                ; its name, author and released)

; ------------------------------------------------------------
; main
; ------------------------------------------------------------
main    lda #<rtiv              ; restore: nothing (the nmi vector)
        sta $0318
        lda #>rtiv
        sta $0319
        ldx #5                  ; ... and the RAM under the KERNAL's vectors
@v      lda rtivs,x             ; an rti too: the trial runs with the KERNAL
        sta $fffa,x             ; out, and RESTORE then went through them
        dex
        bpl @v
        lda #$36                ; BASIC out (the trial puts this back)
        sta $01
        lda $ba                 ; the drive it was loaded from
        cmp #8
        bcc @d
        sta prgdev
@d      jsr detect
        jsr mknpool
again   ldx #$ff
        txs
        lda #0
        sta $d020
        sta $d021
        lda #5
        sta 646
        lda #147
        jsr chrout
        ldx #<tx_title
        ldy #>tx_title
        jsr print
        jsr clrchn
        lda #2
        jsr close
        jsr ask                 ; the .sid, read
        bcs @next
        lda #0
        sta mok
        sta mnws
        ldx #31
@z      sta mzp,x
        sta mtitle,x
        dex
        bpl @z
        jsr ldtune              ; checked, tried out
        lda mok
        cmp #1
        bne @next
        jsr report
        jsr name                ; the .slm: named, written
@next   ldx #<tx_next
        ldy #>tx_next
        jsr print
@k      jsr getin
        beq @k
        cmp #'q'
        bne again
        jsr cmdclose
        ldx #<tx_bye
        ldy #>tx_bye
        jsr print
        lda #$37
        sta $01
        jsr $ff8a               ; the KERNAL's vectors again (RESTORE: not
        jmp ($a002)             ; this program's rti); BASIC's warm start
rtiv    rti
rtivs   word rtiv,rtiv,rtiv       ; (the RAM under the KERNAL's vectors)

; ------------------------------------------------------------
; ask  the drive and the .sid's name; the file read to stage
;   out:  c set if it can't be read (said)
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
; rdfile  prgname from prgdev to stage, its length in flen
rdfile  ldx #<tx_reading
        ldy #>tx_reading
        jsr print
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
        lda #13
        jsr chrout
        lda #2
        jsr close
        sec
        rts
@o      ldx #2
        jsr chkin
        lda #<stage
        sta p1
        lda #>stage
        sta p1+1
        lda #0
        sta flen
        sta flen+1
@r      jsr chrin
        sta t0
        jsr readst
        and #$bf                ; (the end of the file is fine)
        bne @err
        lda t0                  ; (its last 256 bytes, kept aside: a tune
        ldy flen                ; page the stage hasn't room for)
        sta ring,y
        lda flen+1              ; in the stage while there's room (the
        cmp #>stagemax          ; rest counted: a tune that big is cut,
        bcs @p                  ; its pages read again as needed)
        lda t0
        ldy #0
        sta (p1),y
        inc p1
        bne @p
        inc p1+1
@p      inc flen
        bne @e
        inc flen+1
        beq @big                ; (64 KB)
@e      jsr readst
        and #$40
        beq @r
        jsr clrchn
        lda #2
        jsr close
        clc
        rts
@err    ldx #<tx_rderr
        ldy #>tx_rderr
        bne @say
@big    ldx #<tx_big
        ldy #>tx_big
@say    stx p2
        sty p2+1
        jsr clrchn
        lda #2
        jsr close
        ldx p2
        ldy p2+1
        jsr print
        sec
        rts

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

; ldtune  the file at stage: a PSID tried out (sidread.asm's ldsid); an
; RSID, or anything else, refused
ldtune  ldx #3
@p      lda stage,x
        cmp psidm,x
        bne @np
        dex
        bpl @p
        jmp ldsid
@np     ldx #3
@r      lda stage,x
        cmp rsidm,x
        bne @nr
        dex
        bpl @r
        lda #r_rsid
        jmp mrefuse
@nr     lda #r_notmus
        jmp mrefuse
psidm   byte $50,$53,$49,$44    ; "PSID"
rsidm   byte $52,$53,$49,$44    ; "RSID"

; ------------------------------------------------------------
; report  what the trial found: the tune, its rate, its longest call,
; its zero page and workspace
; ------------------------------------------------------------
report  ldx #0                  ; its name
@t      lda mtitle,x
        beq @te
        jsr chrout
        inx
        cpx #32
        bcc @t
@te     lda #13
        jsr chrout
        ldx #<tx_frame          ; its rate
        ldy #>tx_frame
        lda mcia
        beq @r
        ldx #<tx_cia
        ldy #>tx_cia
@r      jsr print
        ldx #<tx_cyc            ; its longest call
        ldy #>tx_cyc
        jsr print
        lda mcyc
        ldx mcyc+1
        jsr prdec16
        ldx #<tx_cyc2
        ldy #>tx_cyc2
        jsr print
        ldx #<tx_zp             ; its zero page: runs
        ldy #>tx_zp
        jsr print
        lda #0
        sta t6                  ; (any yet)
        ldx #0
@zl     jsr zpbit
        beq @zn
        stx t4                  ; a run from x
@zr     inx
        beq @ze
        jsr zpbit
        bne @zr
@ze     stx t5                  ; ... to x - 1
        jsr comma
        lda t4
        jsr prhex2d
        lda t5
        sec
        sbc #1
        cmp t4
        beq @z1
        pha
        lda #'-'
        jsr chrout
        pla
        jsr prhex2d
@z1     ldx t5
        beq @zd
@zn     inx
        bne @zl
@zd     lda t6
        bne @zw
        ldx #<tx_none
        ldy #>tx_none
        jsr print
@zw     ldx #<tx_ws             ; its workspace
        ldy #>tx_ws
        jsr print
        lda mnws
        bne @w
        ldx #<tx_none
        ldy #>tx_none
        jsr print
        jmp @wd
@w      lda #0
        sta t6
        sta t7
@wl     jsr comma
        ldx t7
        lda mws,x
        pha
        lda mws+1,x
        tax
        pla
        jsr prhex4
        lda #'-'
        jsr chrout
        ldx t7                  ; (the last byte: hi - 1)
        lda mws+2,x
        sec
        sbc #1
        pha
        lda mws+3,x
        sbc #0
        tax
        pla
        jsr prhex4
        lda t7
        clc
        adc #4
        sta t7
        lsr a
        lsr a
        cmp mnws
        bcc @wl
@wd     lda #13
        jmp chrout

; zpbit  z clear if zero page address x is the tune's
zpbit   txa
        lsr a
        lsr a
        lsr a
        tay
        txa
        and #7
        sta t3
        lda mzp,y
@b      dec t3
        bmi @x
        lsr a
        jmp @b
@x      and #1
        rts

; comma  ", " before all but the first (t6 counts them)
comma   lda t6
        beq @f
        lda #','
        jsr chrout
        lda #' '
        jsr chrout
@f      inc t6
        rts

; prhex2d  a as $hh
prhex2d pha
        lda #'$'
        jsr chrout
        pla
        jmp prhex2

; ------------------------------------------------------------
; name  the .slm's name (the .sid's, ending .slm), and it written
; ------------------------------------------------------------
name    ldx #<q_out
        ldy #>q_out
        jsr wname
        jsr wcreate
        bcc @go
        rts
@go     ldx #3
        jsr chkout
        ldx #0                  ; "SLM2", load, length, init, play
@h      lda slmhd,x
        jsr chrout
        inx
        cpx #4
        bcc @h
        lda mload
        jsr chrout
        lda mload+1
        jsr chrout
        lda mlen
        jsr chrout
        lda mlen+1
        jsr chrout
        lda minit
        jsr chrout
        lda minit+1
        jsr chrout
        lda mplay
        jsr chrout
        lda mplay+1
        jsr chrout
        lda ma                  ; the song, the flags
        jsr chrout
        jsr flags
        jsr chrout
        lda mppal               ; the times between play calls, the longest
        jsr chrout
        lda mppal+1
        jsr chrout
        lda mpntsc
        jsr chrout
        lda mpntsc+1
        jsr chrout
        lda mcyc
        jsr chrout
        lda mcyc+1
        jsr chrout
        lda #<mzp               ; zero page, workspace
        ldx #>mzp
        ldy #32
        sty cnt
        ldy #0
        jsr wrblk
        lda mnws
        jsr chrout
        asl a
        asl a
        sta cnt
        lda #<mws
        ldx #>mws
        ldy #0
        jsr wrblk
        lda #0                  ; no relocations
        jsr chrout
        lda #0
        jsr chrout
        lda #$16                ; its name, author, released (ASCII, as in the .sid)
        jsr wtext
        lda #$36
        jsr wtext
        lda #$56
        jsr wtext
        lda mload               ; its bytes, as the trial left them
        ldx #>mpool
        ldy mlen
        sty cnt
        ldy mlen+1
        jsr wrblk
        jsr wclose
        bcs @x
        lda mcut                ; cut down: said so (one song, what five
        beq @s                  ; minutes of it use)
        ldx #<tx_cd1
        ldy #>tx_cd1
        jsr print
        lda msong
        ldx #0
        jsr prdec16
        ldx #<tx_cd2
        ldy #>tx_cd2
        jsr print
        lda mlen
        ldx mlen+1
        jsr prdec16
        ldx #<tx_cd3
        ldy #>tx_cd3
        jsr print
        lda mof
        ldx mof+1
        jsr prdec16
        ldx #<tx_cd4
        ldy #>tx_cd4
        jsr print
@s      ldx #<tx_slm
        ldy #>tx_slm
        jmp print
@x      rts
slmhd   byte $53,$4c,$4d,$32    ; "SLM2"

; flags  a = the .slm's flags: 1 not an NTSC tune, 2 NTSC or both, 4 CIA
; timed (sidstrip.py's; 8, can move, never)
flags   lda #0
        sta t0
        lda mver                ; the clock: in version 2 on (bits 2-3)
        cmp #2
        bcc @pal
        lda mflg
        lsr a
        lsr a
        and #3
        cmp #2
        beq @ntsc
        cmp #3
        bne @pal
        lda #2                  ; PAL and NTSC
        sta t0
@pal    lda #1
        ora t0
        sta t0
        bne @c
@ntsc   lda #2
        sta t0
@c      lda mcia
        beq @x
        lda #4
        ora t0
        sta t0
@x      lda t0
        rts

; wtext  the header's text at stage + a: to its first 0, spaces at its
; ends left out (as sidstrip.py reads it), 32 bytes padded with zeros
wtext   clc
        adc #<stage
        sta p2
        lda #>stage
        adc #0
        sta p2+1
        ldy #0                  ; its end: the first 0
@e      lda (p2),y
        beq @ee
        iny
        cpy #32
        bcc @e
@ee     sty t5                  ; ... less spaces before it
@tr     ldy t5
        beq @st
        dey
        lda (p2),y
        cmp #' '
        bne @st
        sty t5
        jmp @tr
@st     ldy #0                  ; its start: past spaces
@sp     cpy t5
        bcs @w
        lda (p2),y
        cmp #' '
        bne @w
        iny
        bne @sp
@w      lda #32                 ; (what's written: t5 - y, then zeros)
        sta t4
@wc     cpy t5
        bcs @z
        lda (p2),y
        jsr chrout
        dec t4
        iny
        bne @wc
@z      lda t4
        beq @x
        lda #0
        jsr chrout
        dec t4
        jmp @z
@x      rts

; ------------------------------------------------------------
; what sidread.asm needs: mrefuse and the reasons, mtoolong, asc2pet,
; tomusp
; ------------------------------------------------------------
r_notmus = 1
r_rsid  = 2
r_noplay = 3
r_sids  = 4
r_long  = 5
r_fast  = 7
r_slow  = 8
r_cutroom = 9                   ; (cutpost's 1-3: 9-11)
r_cutlong = 10
r_cutpage = 11
r_cutdiff = 12
r_cutread = 13                  ; (the file read again: not as it was)
r_trial = 19                    ; + the trial's own (1-16)
nwhy    = 36

; mrefuse  the tune refused for reason a (mwhya: the address, if any):
; said; mok 2, c clear
mrefuse sta mwhy
        lda #2
        sta mok
        lda #28                 ; (red)
        jsr chrout
        ldx #<tx_refused
        ldy #>tx_refused
        jsr print
        ldx mwhy
        cpx #nwhy
        bcc @k
        ldx #0
@k      lda whylo,x
        ldy whyhi,x
        tax
        jsr print
        ldx mwhy
        lda whyadr,x
        beq @nl
        lda #' '
        jsr chrout
        lda mwhya
        ldx mwhya+1
        jsr prhex4
@nl     lda #5
        jsr chrout
        lda #13
        jsr chrout
        clc
        rts

; mtoolong  a tune over 4096 bytes: its song cut down (mcut 1), if the
; answer is y, else c set (refused: said)
mtoolong
        lda mlen+1
        cmp #$10
        bcc @ok
        bne @long
        lda mlen
        beq @ok
@long   ldx #<tx_over
        ldy #>tx_over
        jsr print
        lda mlen
        ldx mlen+1
        jsr prdec16
        ldx #<q_cut
        ldy #>q_cut
        jsr print
@k      jsr getin
        beq @k
        cmp #'y'
        bne @no
        jsr chrout
        lda #13
        jsr chrout
        lda #1
        sta mcut
@ok     clc
        rts
@no     lda #13
        jsr chrout
        lda #r_long
        jsr mrefuse
        sec
        rts

; ------------------------------------------------------------
; cutsid  one song of a tune over 4096 bytes cut down (sidcut.asm: as
;         the PC's sidstrip.py -cut), into the music pool, then tried
;         as any tune over the same play calls (trysid: it must play as
;         the whole one did)
; ------------------------------------------------------------
cutsid  tsx                     ; (cutout's way out, to mrefuse)
        stx cutsp
        ldx #95                 ; (the header's texts, for the .slm: the
@t      lda stage+$16,x         ; tune moves over them; pgread checks the
        sta mtexts,x            ; file against them)
        dex
        bpl @t
        lda mdat                ; the tune's place in the file
        sec
        sbc #<stage
        sta mfoff
        lda mdat+1
        sbc #>stage
        sta mfoff+1
        jsr cutalign            ; the tune (what the stage has of it)
        jsr cuthome             ; where each of its pages is
        jsr cutlists            ; the pages the trace may use
        lda #<pgread            ; (its pages not in memory: read again)
        sta ct_read
        lda #>pgread
        sta ct_read+1
        lda #<cutroom
        sta ct_abort
        lda #>cutroom
        sta ct_abort+1
        lda mload
        sta tr_load
        sta tr_src
        lda mload+1
        sta tr_load+1
        lda #>stage
        sta tr_src+1
        lda mlen
        sta tr_len
        sta mof
        lda mlen+1
        sta tr_len+1
        sta mof+1
        lda minit
        sta tr_init
        lda minit+1
        sta tr_init+1
        lda mplay
        sta tr_play
        lda mplay+1
        sta tr_play+1
        lda ma
        sta tr_song
        lda #<cutcalls
        sta tr_calls
        sta mcalls
        lda #>cutcalls
        sta tr_calls+1
        sta mcalls+1
        lda #<cpool
        sta tr_pool
        lda #>cpool
        sta tr_pool+1
        lda #1
        sta tr_stop
        lda #mpoolp             ; (the cut: in the music pool)
        sta ct_dst
        lda #0                  ; (the tune itself, not as init leaves it)
        sta ct_aft
        sta ct_stp
        ldx #<tx_cutting
        ldy #>tx_cutting
        jsr trcount
        jsr cuttrace
        jsr slow
        lda #13
        jsr chrout
        lda tr_err              ; refused already (as the cut would be)
        beq @post
        cmp #13
        beq @room
        clc
        adc #r_trial
        pha
        lda tr_erra
        sta mwhya
        lda tr_erra+1
        sta mwhya+1
        pla
        jmp mrefuse
@room   lda #r_cutroom
        jmp mrefuse
@post   jsr cutpost
        lda ct_err
        cmp #1
        beq @room
        cmp #3
        beq @page
        jsr prcut               ; song n: its bytes and pages
        lda ct_err
        beq @ok
        jsr aftsid              ; over 4096: again, as init leaves it
        bcc @ok
        jmp mrefuse
@page   lda #r_cutpage
        jmp mrefuse
@ok     ldx #95                 ; (the texts back)
@t2     lda mtexts,x
        sta stage+$16,x
        dex
        bpl @t2
        lda ct_first            ; the cut tune, in the music pool
        sta mload
        lda ct_first+1
        sta mload+1
        lda ct_len
        sta mlen
        lda ct_len+1
        sta mlen+1
        lda ct_init
        sta minit
        lda ct_init+1
        sta minit+1
        lda ct_play
        sta mplay
        lda ct_play+1
        sta mplay+1
        jmp trysid

; prcut  "song n: its bytes (kept of its pages)"
prcut   ldx #<tx_song
        ldy #>tx_song
        jsr print
        lda msong
        ldx #0
        jsr prdec16
        ldx #<tx_cutto
        ldy #>tx_cutto
        jsr print
        lda ct_len
        ldx ct_len+1
        jsr prdec16
        ldx #<tx_cutb
        ldy #>tx_cutb
        jsr print
        lda ct_kept
        ldx #0
        jsr prdec16
        ldx #<tx_cutof
        ldy #>tx_cutof
        jsr print
        lda ct_of
        ldx #0
        jsr prdec16
        ldx #<tx_cutp
        ldy #>tx_cutp
        jmp print

; aftsid  (cutsid's) a cut over 4096 bytes made again as the tune's init
; leaves it (sidcut.asm's cutafter, then cutpost: a tune whose init
; copies its song somewhere, such as The Last Ninja), said as the first
;   out:  c clear: the cut made (ct_first ...); else c set, a = why not
aftsid  ldx #<tx_again
        ldy #>tx_again
        jsr print
        ldx #<tx_after
        ldy #>tx_after
        jsr trcount
        jsr cutafter
        php
        jsr slow
        lda #13
        jsr chrout
        plp
        bcs @no
        jsr cutpost
        lda ct_err
        beq @pr
        cmp #2
        bne @no
@pr     jsr prcut
        lda ct_err
        bne @no
        clc
        rts
@no     lda ct_err              ; why: no room, the trial's own, else (as
        cmp #1                  ; the first) over 4096
        beq @rm
        lda tr_err
        beq @lg
        cmp #13
        beq @rm
        clc
        adc #r_trial
        sec
        rts
@lg     lda #r_cutlong
        sec
        rts
@rm     lda #r_cutroom
        sec
        rts

; cutalign  the tune's bytes (mhave of them at mdat) moved in the stage
; to where their low byte is the load address's: stage + (mload and 255).
; mhave: all of them (mlen), or for a file longer than the stage, those
; that fit below $8000 (its pages from $8000 are then the pool's)
cutalign
        lda mlen
        sta mhave
        lda mlen+1
        sta mhave+1
        lda flen                ; (the file longer than the stage?)
        cmp #<stagemax+1
        lda flen+1
        sbc #>stagemax+1
        bcc @in
        lda #<$8000-stage       ; (the stage's bytes below $8000, less the
        sec                     ; load address's offset in its page)
        sbc mload
        sta mhave
        lda #>$8000-stage
        sbc #0
        sta mhave+1
@in     lda mload
        sta p1
        lda #>stage
        sta p1+1
        lda mdat
        sta p2
        lda mdat+1
        sta p2+1
        lda mhave
        sta t2
        lda mhave+1
        sta t3
        lda p1                  ; (the same page: below or above)
        cmp p2
        bcc @up
        bne @dn
        rts
@up     jmp copyn               ; lower: from the start
@dn     lda p1                  ; higher: from the end
        clc
        adc t2
        sta p1
        lda p1+1
        adc t3
        sta p1+1
        lda p2
        clc
        adc t2
        sta p2
        lda p2+1
        adc t3
        sta p2+1
        ldy #0
@c      lda t2
        ora t3
        beq @x
        lda p1
        bne @1
        dec p1+1
@1      dec p1
        lda p2
        bne @2
        dec p2+1
@2      dec p2
        lda (p2),y
        sta (p1),y
        lda t2
        bne @3
        dec t3
@3      dec t2
        jmp @c
@x      rts

; cuthome  chome (sidcut.asm's): each tune page's real page, 0 for one
;          not in memory: the stage's (page p at >stage + p - its first),
;          those it has whole; for a file longer than the stage, its last
;          page from ring, at $fe00; pgend: the stage's first page after
;          them
cuthome ldx #0
        txa
@z      sta chome,x
        inx
        bne @z
        lda mload               ; the stage's last byte of it: its page,
        clc                     ; less one if it's only part there
        adc mhave
        sta t0
        lda mload+1
        adc mhave+1
        sta t1                  ; (t0/t1: the address past it)
        lda t0                  ; ending a page: t1 - 1 the last; else t1
        beq @d                  ; when all of it is there (the tune's last
        lda mhave               ; page), else t1 - 1 (t1 only part there)
        cmp mlen
        bne @d
        lda mhave+1
        cmp mlen+1
        beq @w1
@d      dec t1
@w1     ldx mload+1             ; pages mload+1 ... t1: the stage's
        lda #>stage
@h      cpx t1
        beq @h1
        bcs @hx
@h1     sta chome,x
        clc
        adc #1
        inx
        bne @h
@hx     sta pgend
        lda mhave               ; all of it there: done
        cmp mlen
        bne @l
        lda mhave+1
        cmp mlen+1
        beq @r
@l      lda mload               ; else its last page: its bytes are the
        clc                     ; file's last n (n the end's low byte, 0:
        adc mlen                ; 256), in ring at the file's length - n
        sta t2
        lda mload+1
        adc mlen+1
        sta t3                  ; (t2/t3: past the end)
        lda t2
        bne @n
        dec t3
@n      lda flen
        sec
        sbc t2
        tax
        ldy #0
@c      lda ring,x
        sta $fe00,y
        inx
        iny
        dec t2
        bne @c
        ldx t3
        lda #$fe
        sta chome,x
@r      rts

; cutlists  the trace's pages: cpool ($80 up: the stage's after the
; tune's, $ab-$bf, $cf-$fe but $fe when the last page is there) and
; sidcut.asm's ctlow (the origins': the music pool's, the stage's below
; $80 after the tune's)
cutlists
        ldy #0                  ; (ctlow's next)
        ldx #mpoolp
@m      txa
        sta ctlow,y
        iny
        inx
        cpx #mpoolp+17
        bne @m
        ldx #0                  ; (cpool's next)
        lda pgend
@s      cmp #$a0
        bcs @h
        cmp #$80
        bcs @hi
        sta ctlow,y
        iny
        bne @sn
@hi     sta cpool,x
        inx
@sn     clc
        adc #1
        bne @s
@h      lda #$ab
@h1     sta cpool,x
        inx
        clc
        adc #1
        cmp #$c0
        bne @h1
        lda #$cf
@h2     sta cpool,x
        inx
        clc
        adc #1
        cmp #$fe
        bne @h2
        lda mhave               ; ($fe too, unless the last page is there)
        cmp mlen
        bne @e
        lda mhave+1
        cmp mlen+1
        bne @e
        lda #$fe
        sta cpool,x
        inx
@e      lda #0
        sta cpool,x
        sta ctlow,y
        rts

; pgbyte: a = the file's next byte (pgfail: an error, or past its end)
pgbyte  lda pgeof
        bne pgfail
        jsr chrin
        sta t7
        jsr readst
        sta pgeof
        and #$bf
        bne pgfail
        lda pgeof
        and #$40
        sta pgeof
        lda t7
        rts
; pgfail: the file can't be read again as it was; cutroom: sidcut.asm's
; ct_abort, no room to read a page in; cutout: refused (a), from wherever
; the cut is, through mrefuse
pgfail  lda #r_cutread
        bne cutout
cutroom lda #r_cutroom
cutout  pha
        lda #$37                ; (the KERNAL first: the trace's $01 is $34)
        sta $01
        jsr clrchn
        lda #2
        jsr close
        lda #0
        sta tr_cut
        sta tr_home
        jsr slow
        cli
        pla
        ldx cutsp
        txs
        jmp mrefuse

; ------------------------------------------------------------
; pgread  sidcut.asm's ct_read: tune pages pgx on (pgn of them) into
;         pgfrm's pages, from the file read again: its start skipped,
;         the header's texts checked on the way (the same file?)
;   uses: a, x, y, t0-t7, p1; $01 = $36 and 1 MHz while it reads
;   note: an error, or not the same file: refused (cutout)
; ------------------------------------------------------------
pgread  lda $01
        pha
        lda #$36                ; (the KERNAL and the I/O)
        sta $01
        lda infast              ; (the speed it was at: back after)
        pha
        jsr slow
        lda #0
        sta pgeof
        lda #2
        ldx prgdev
        ldy #2
        jsr setlfs
        lda prglen
        ldx #<prgname
        ldy #>prgname
        jsr setnam
        jsr open
        bcs pgfail
        ldx #2
        jsr chkin
        bcs pgfail
        lda mfoff               ; the bytes before pgx's first: the tune's
        sta t0                  ; place in the file, and pgx * 256 - mload
        lda mfoff+1             ; past its first page
        sta t1
        lda pgx
        cmp mload+1
        beq @sk0
        lda t0
        sec
        sbc mload
        sta t0
        lda t1
        sbc mload+1
        sta t1
        lda t1
        clc
        adc pgx
        sta t1
@sk0    lda #0                  ; (t2/t3: the place in the file)
        sta t2
        sta t3
@sk     lda t0
        ora t1
        beq @pg
        jsr pgbyte
        ldx t3                  ; in the header's texts ($16-$75): as
        bne @sn                 ; they were?
        ldx t2
        cpx #$16
        bcc @sn
        cpx #$76
        bcs @sn
        cmp mtexts-$16,x
        beq @sn
        jmp pgfail
@sn     inc t2
        bne @s2
        inc t3
@s2     lda t0
        bne @s3
        dec t1
@s3     dec t0
        jmp @sk
@pg     lda #0                  ; the pages (t4: which)
        sta t4
@p      lda t4
        clc
        adc pgx
        sta t5                  ; (its number)
        ldx t4
        lda pgfrm,x
        sta p1+1
        lda #0
        sta p1
        sta t2                  ; its first byte (t2): the tune's first
        lda t5                  ; page from mload's
        cmp mload+1
        bne @f
        lda mload
        sta t2
@f      lda #$ff                ; its last: the tune's last page to its end
        sta t6
        lda mload
        clc
        adc mlen
        sta t7
        lda mload+1
        adc mlen+1
        tax
        lda t7
        bne @f2
        dex
@f2     cpx t5
        bne @b
        dec t7
        lda t7
        sta t6
@b      jsr pgbyte
        ldy t2
        sei                     ; (the page may be under the I/O)
        ldx #$34
        stx $01
        sta (p1),y
        ldx #$36
        stx $01
        cpy t6
        beq @nx
        inc t2
        bne @b
@nx     inc t4
        lda t4
        cmp pgn
        bne @p
        jsr clrchn
        lda #2
        jsr close
        pla                     ; (fast again if it was)
        beq @c
        jsr fast
@c      sei
        pla
        sta $01
        clc
        rts

; mknpool  npool, the trial's pages ($80 up): the stage's from $8000
; (the tune is in the music pool by then), $ab-$fe (sidcut.asm's tables
; are free then too)
mknpool ldx #0
        lda #$80
@a      sta npool,x
        inx
        clc
        adc #1
        cmp #$a0
        bne @a
        lda #$ab
@b      sta npool,x
        inx
        clc
        adc #1
        cmp #$ff
        bne @b
        lda #0
        sta npool,x
        rts

; asc2pet  an ASCII character as PETSCII for the screen (letters as capitals)
asc2pet cmp #$61                ; (A-Z, digits, signs as they are)
        bcc @x
        cmp #$7b
        bcs @q
        and #$df                ; a-z as A-Z: the screen's set has capitals
@x      rts                     ; only (A-Z made shifted showed as graphics)
@q      lda #'.'
        rts

; tomusp  mlen bytes from p2 to the music pool, at mload's offset in its
; page: mpool + (mload and 255)
tomusp  lda mload
        sta p1
        lda #>mpool
        sta p1+1
        lda mlen
        sta t2
        lda mlen+1
        sta t3
copyn   ldy #0                  ; t2/t3 bytes from p2 to p1
@c      lda t2
        ora t3
        beq @x
        lda (p2),y
        sta (p1),y
        inc p1
        bne @1
        inc p1+1
@1      inc p2
        bne @2
        inc p2+1
@2      lda t2
        bne @3
        dec t3
@3      dec t2
        jmp @c
@x      rts

whylo   byte <rsn0,<rsn1,<rsn2,<rsn3,<rsn4,<rsn5,<rsn0,<rsn7,<rsn8,<rsn9,<rsn10,<rsn11,<rsn12,<rsn13,<rsn0,<rsn0
        byte <rsn0,<rsn0,<rsn0,<rsn0
        byte <rst1,<rst2,<rst3,<rst4,<rst5,<rst6,<rst7,<rst8,<rst9,<rst10,<rst11,<rst12,<rst13,<rst14,<rst15
        byte <rst16
whyhi   byte >rsn0,>rsn1,>rsn2,>rsn3,>rsn4,>rsn5,>rsn0,>rsn7,>rsn8,>rsn9,>rsn10,>rsn11,>rsn12,>rsn13,>rsn0,>rsn0
        byte >rsn0,>rsn0,>rsn0,>rsn0
        byte >rst1,>rst2,>rst3,>rst4,>rst5,>rst6,>rst7,>rst8,>rst9,>rst10,>rst11,>rst12,>rst13,>rst14,>rst15
        byte >rst16
whyadr  byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0
        byte 1,0,1,1,1,1,1,1,1,0,0,1,0,0,0
        byte 0
rsn0      text "?",0
rsn1      text "not a .sid",0
rsn2      text "rsid: takes interrupts",0
rsn3      text "no play routine",0
rsn4      text "for more than one sid",0
rsn5      text "over 4096 bytes",0
rsn7      text "over 8 calls a frame",0
rsn8      text "plays too slowly",0
rst1      text "calls the rom",0
rst2      text "switches i/o out",0
rst3      text "writes a second sid",0
rst4      text "loader's zero page",0
rst5      text "writes the stack",0
rst6      text "store: i/o and ram",0
rst7      text "i/o store in new code",0
rst8      text "i/o store by pointer",0
rst9      text "odd store to i/o",0
rst10     text "init never returns",0
rst11     text "play never returns",0
rst12     text "unsupported opcode",0
rst13     text "too big to try",0
rst14     text "writes i/o once patched",0
rst15     text "plays differently patched",0
rst16     text "stopped (run/stop)",0
rsn9      text "too big to cut on a c64",0
rsn10     text "cut, still over 4096 bytes",0
rsn11     text "can't be cut (its first page)",0
rsn12     text "plays differently cut",0
rsn13     text "can't read the file again",0

; ---- texts ----
tx_title text 13,"sid-slm - a .sid tune made ready for",13,"slopload 64 (a .slm)",13,13,0
tx_bye  text "bye.",13,0
q_drive text "drive with the .sid file [",0
q_file  text "its file name? ",0
tx_dkeys text "($: its directory, @: the disk)",13,0
tx_ask  text "]? ",0
tx_reading text "reading it...",13,0
tx_big  text "too big for a tune",13,0
tx_refused text "refused: ",0
tx_frame text "plays once a frame",13,0
tx_cia  text "plays by cia 1's timer",13,0
tx_cyc  text "longest play call: ",0
tx_cyc2 text " cycles",13,0
tx_zp   text "zero page: ",0
tx_ws   text 13,"workspace: ",0
tx_none text "none",0
tx_over text "it is ",0
q_cut   text " bytes, over 4096: cut it",13,"down to one song (up to 2 hours; y/n)? ",0
tx_cutting text "cutting it: ",0
tx_again text "over 4096: again, as init leaves it",13,0
tx_after text "after init: ",0
tx_song text "song ",0
tx_cutto text ": ",0
tx_cutb text " bytes (",0
tx_cutof text " of ",0
tx_cutp text " pages)",13,0
q_out   text 13,"the .slm's name [",0
tx_cd1  text 13,"note: cut down, song ",0
tx_cd2  text " only",13,"(",0
tx_cd3  text " of the tune's ",0
tx_cd4  text " bytes: what",13,"its first 5 minutes of play use)",0
tx_slm  text 13,"choose it in slopload 64 (5: the music)",13,0
tx_next text 13,"q: quit  other keys: another tune",13,0
wold    text ".sid"                 ; (wfile.asm: the name's ending, and the new one)
wnew    byte 4
        text ".slm"
npool                                   ; the trial's pages (mknpool): 0 at the end
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
cpool                                   ; the cut's trace's (cutlists)
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
bssend
