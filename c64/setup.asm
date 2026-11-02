; ------------------------------------------------------------
; setup.asm  -  SlopLoad 64's game, picture and tune, read from disk and
; checked; then what goes on the tape with the program (prepare): the
; game, or the show module placed with its picture; the tune placed;
; the header bytes; the claims. tools/c64model.py's setup() is the
; reference: the same rules, the same choices.
; ------------------------------------------------------------

; ---- the files chosen ----
gok     byte 0                  ; a game read and checked
gdev    byte 8
gnlen   byte 0
gname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
kok     byte 0                  ; a picture
kdev    byte 8
knlen   byte 0
kname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mok     byte 0                  ; a tune (1), or one refused (2: mwhy)
mdev    byte 8
mnlen   byte 0
mname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
hpool   byte 0                  ; the high pool holds: 0 nothing, 1 the game, 2 the picture

; ---- the game (in the high pool) ----
gnp     byte 0                  ; its parts (the main one first)
gpal    byte 0,0,0,0            ; each part's address, length, place in the pool
gpah    byte 0,0,0,0
gpll    byte 0,0,0,0
gplh    byte 0,0,0,0
gppl    byte 0,0,0,0
gpph    byte 0,0,0,0
gclml   byte 0                  ; the main part's claim's end
gclmh   byte 0
gjit    byte 0
gshr    byte 0
gentry  word 0,0,0              ; init, frame, stop
gorig   byte 0,0,0,0,0,0,0,0,0  ; its header's +16 to +24, as read

; ---- the picture (in the high pool) ----
kbit    word 0                  ; its bitmap in the pool (screen +8000, colour +9000)
kbg     byte 0

; ---- the tune (in the music pool) ----
mkind   byte 0                  ; 2: a prepared .slm
msong   byte 1                  ; the song chosen (1-)
msongs  byte 1
mload   word 0                  ; where it plays
morig   word 0                  ; ... as its file has it (pltune starts there)
mlen    word 0
minit   word 0
mplay   word 0
ma      byte 0                  ; init's a: the song - 1
mppal   word 0                  ; time between play calls (1/64 lines): PAL
mpntsc  word 0                  ; ... NTSC
mcyc    word 0                  ; its longest play call, cycles
mzp     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mnws    byte 0                  ; its workspace: runs (lo, hi exclusive)
mws     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mnrel   word 0                  ; a prepared tune's relocations (at mrel): 0 can't move
mtitle  byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mwhy    byte 0                  ; why it was refused (a reason number)
mwhya   word 0                  ; ... and the address in it
mpool   = mpoolp*256            ; the tune's bytes: mpool + its offset in its page

; ------------------------------------------------------------
; ldgame  the game fdev/fname read into the high pool and checked: its
; parts, entry points, claim, jitter and share
;   out:  c set if it can't be (said); gok
; ------------------------------------------------------------
ldgame  lda #0
        sta gok
        sta hpool
        jsr tohigh
        bcc @r
        rts
@r      lda #1
        sta hpool
        lda #<hpbase            ; the parts: address, length, bytes
        sta p1
        lda #>hpbase
        sta p1+1
        lda flen                ; t4/t5: the file's end in the pool
        clc
        adc #<hpbase
        sta t4
        lda flen+1
        adc #>hpbase
        sta t5
        lda #0
        sta gnp
@p      lda p1                  ; at the end?
        cmp t4
        lda p1+1
        sbc t5
        bcs @end
        ldx gnp
        cpx #4
        bcc @bq3
        jmp @bad
@bq3
        ldy #0
        jsr hget
        sta gpal,x
        iny
        jsr hget
        sta gpah,x
        iny
        jsr hget
        sta gpll,x
        iny
        jsr hget
        sta gplh,x
        lda p1                  ; its bytes
        clc
        adc #4
        sta p1
        sta gppl,x
        lda p1+1
        adc #0
        sta p1+1
        sta gpph,x
        lda p1                  ; past them
        clc
        adc gpll,x
        sta p1
        lda p1+1
        adc gplh,x
        sta p1+1
        bcc @bq4
        jmp @bad
@bq4
        inc gnp
        lda t4                  ; within the file?
        cmp p1
        lda t5
        sbc p1+1
        bcs @p
        bcs @bq5
        jmp @bad
@bq5
@end    lda gnp                 ; the main part: PLG1, 32 bytes or more
        bne @bq6
        jmp @bad
@bq6
        lda gplh
        bne @l
        lda gpll
        cmp #32
        bcs @bq7
        jmp @bad
@bq7
@l      lda gppl
        sta p1
        lda gpph
        sta p1+1
        ldy #3
@m      jsr hget
        cmp plgmagic,y
        beq @bq8
        jmp @bad
@bq8
        dey
        bpl @m
        ldy #4                  ; init, frame, stop
@e      jsr hget
        sta gentry-4,y
        iny
        cpy #10
        bcc @e
        jsr hget                ; +10: the claim's end (0: to $10000)
        sta gclml
        iny
        jsr hget
        sta gclmh
        iny
        jsr hget                ; +12: jitter (0: 48)
        bne @j
        lda #48
@j      sta gjit
        cmp #65
        bcc @bq9
        jmp @jit
@bq9
        ldy #14                 ; +14: share (0: 35)
        jsr hget
        bne @s
        lda #35
@s      sta gshr
        ldy #16                 ; the music fields as the file has them
@go     jsr hget
        sta gorig-16,y
        iny
        cpy #25
        bcc @go
        lda gpal                ; the claim: at least the main part's end
        clc
        adc gpll
        sta t0
        lda gpah
        adc gplh
        sta t1
        bcs @full
        lda gclml
        ora gclmh
        beq @full
        lda gclml
        cmp t0
        lda gclmh
        sbc t1
        bcs @cl
        lda t0
        sta gclml
        lda t1
        sta gclmh
        jmp @cl
@full   lda #<$ffff             ; (to the end: past the loader's vectors)
        sta gclml
        lda #>$ffff
        sta gclmh
@cl     jsr gclaims             ; clear of the loader's memory?
        lda #<lmcl
        sta lov1
        lda #>lmcl
        sta lov1+1
        lda #<lldr
        sta lov2
        lda #>lldr
        sta lov2+1
        jsr lovl
        bcs @ldr
@ok     lda #1
        sta gok
        clc
        rts
@bad    ldx #<tx_notlm
        ldy #>tx_notlm
        jmp prfail
@jit    ldx #<tx_gjit
        ldy #>tx_gjit
        jmp prfail
@ldr    ldx #<tx_gldr
        ldy #>tx_gldr
        jmp prfail
plgmagic byte $50,$4c,$47,$31   ; "PLG1"
tx_notlm text "not a module (.lm)",13,0
tx_gjit  text "its jitter is over 64: the loader can't",13,0
tx_gldr  text "it needs the loader's memory",13,0

; prfail  the text at x/y, c set
prfail  jsr print
        sec
        rts

; tohigh  fdev/fname read into the high pool (from $d000): hplen
tohigh  lda #<hpbase
        sta p1
        lda #>hpbase
        sta p1+1
        lda #<hpmax
        sta fmax
        lda #>hpmax
        sta fmax+1
        jsr fload
        lda flen
        sta hplen
        lda flen+1
        sta hplen+1
        rts
hplen   word 0

; gclaims  lmcl: the game's claims, the main part to its claim's end,
; the others as they are
gclaims lda #0
        sta lmcl
        ldx #0
@p      cpx gnp
        bcs @x
        lda gpal,x
        sta t0
        lda gpah,x
        sta t1
        txa
        bne @o
        lda gclml               ; the main part
        sta t2
        lda gclmh
        sta t3
        jmp @a
@o      lda gpal,x
        clc
        adc gpll,x
        sta t2
        lda gpah,x
        adc gplh,x
        sta t3
@a      stx t6
        lda #<lmcl
        ldy #>lmcl
        jsr ladd
        ldx t6
        inx
        bne @p
@x      rts

; ------------------------------------------------------------
; ldpic  the picture fdev/fname read into the high pool: a Koala
; picture (10,003 bytes with its load address; 10,000 to 10,003)
;   out:  c set if it isn't one (said); kok
; ------------------------------------------------------------
ldpic   lda #0
        sta kok
        sta hpool
        jsr tohigh
        bcc @r
        rts
@r      lda #2
        sta hpool
        lda flen+1              ; 10000-10003: $2710-$2713
        cmp #$27
        bne @bad
        lda flen
        sec
        sbc #$10
        bcc @bad
        cmp #4
        bcs @bad
        tax                     ; 0-3: the bytes over 10,000
        lda #<hpbase
        sta kbit
        lda #>hpbase
        sta kbit+1
        cpx #2                  ; 10002, 10003: a load address first
        bcc @nl
        inc kbit
        inc kbit
@nl     lda #0                  ; the background: the byte after the colours
        sta kbg
        txa
        and #1
        beq @ok
        lda kbit                ; (10001, 10003: there is one)
        clc
        adc #<10000
        sta p1
        lda kbit+1
        adc #>10000
        sta p1+1
        ldy #0
        jsr hget
        and #15
        sta kbg
@ok     lda #1
        sta kok
        clc
        rts
@bad    ldx #<tx_notkoa
        ldy #>tx_notkoa
        jmp prfail
tx_notkoa text "not a koala picture (10,003 bytes)",13,0

; ------------------------------------------------------------
; ldmus  the tune fdev/fname: a .sid (checked by a trial run) or a .slm
; (prepared on the pc), its bytes to the music pool
;   out:  c set if it can't be read; mok 1 (fine) or 2 (refused: mwhy,
;         said)
; ------------------------------------------------------------
ldmus   lda #0
        sta mok
        sta mnrel
        sta mnrel+1
        sta mnws
        ldx #31
@z      sta mzp,x
        sta mtitle,x
        dex
        bpl @z
        lda #<stage
        sta p1
        lda #>stage
        sta p1+1
        lda #<stagemax
        sta fmax
        lda #>stagemax
        sta fmax+1
        jsr fload
        bcc @r
        lda flong               ; too long to read: refused as over 4 KB
        beq @e
        lda #r_long
        jmp mrefuse
@e      rts
@r      ldx #3                  ; what is it?
@m      lda stage,x
        cmp psidmagic,x
        bne @nps
        dex
        bpl @m
        lda #r_sid              ; a .sid: SID-SLM makes it a .slm
        jmp mrefuse
@nps    ldx #3
@m2     lda stage,x
        cmp rsidmagic,x
        bne @nrs
        dex
        bpl @m2
        lda #r_rsid
        jmp mrefuse
@nrs    ldx #3
@m3     lda stage,x
        cmp slmmagic,x
        bne @nsl
        dex
        bpl @m3
        jmp ldslm
@nsl    lda stage+3
        cmp #$31                ; SLM1: before play times were cycles
        bne @not
        lda stage
        cmp #$53
        bne @not
        lda #r_slm1
        jmp mrefuse
@not    lda #r_notmus
        jmp mrefuse
psidmagic byte $50,$53,$49,$44  ; "PSID"
rsidmagic byte $52,$53,$49,$44  ; "RSID"
slmmagic byte $53,$4c,$4d,$32   ; "SLM2"

; mrefuse  the tune refused for reason a (mwhya: the address, if any):
; said; mok 2, c clear
mrefuse sta mwhy
        lda #2
        sta mok
        jsr prwhy
        clc
        rts

; mtoolong  c set (refused: said) if the tune is over 4096 bytes
mtoolong
        lda mlen+1
        cmp #$10
        bcc @ok
        bne @long
        lda mlen
        beq @ok
@long   lda #r_long
        jsr mrefuse
        sec
        rts
@ok     clc
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
        jmp copyn

; ------------------------------------------------------------
; ldslm  a prepared tune (.slm, version 2) at stage: its fields, its
; relocations to mrel, its bytes to the music pool
; ------------------------------------------------------------
ldslm   lda #2
        sta mkind
        lda stage+4             ; load, length, init, play
        sta mload
        sta morig
        lda stage+5
        sta mload+1
        sta morig+1
        lda stage+6
        sta mlen
        lda stage+7
        sta mlen+1
        jsr mtoolong
        bcc @l
        clc
        rts
@l      lda stage+8
        sta minit
        lda stage+9
        sta minit+1
        lda stage+10
        sta mplay
        lda stage+11
        sta mplay+1
        lda stage+12            ; the song (a)
        sta ma
        clc
        adc #1
        sta msong
        lda #1
        sta msongs
        lda stage+14            ; the play times, the longest call
        sta mppal
        lda stage+15
        sta mppal+1
        lda stage+16
        sta mpntsc
        lda stage+17
        sta mpntsc+1
        lda stage+18
        sta mcyc
        lda stage+19
        sta mcyc+1
        ldx #31                 ; zero page
@z      lda stage+20,x
        sta mzp,x
        dex
        bpl @z
        lda stage+52            ; workspace: count, then (from, to) words
        cmp #17
        bcc @bq10
        jmp @bad
@bq10
        sta mnws
        asl a
        asl a
        tax
        beq @w0
@w      lda stage+52,x
        sta mws-1,x
        dex
        bne @w
@w0     lda mnws                ; p2: past them
        asl a
        asl a
        clc
        adc #<(stage+53)
        sta p2
        lda #>(stage+53)
        adc #0
        sta p2+1
        ldy #0                  ; relocations: a count, then words
        lda (p2),y
        sta mnrel
        iny
        lda (p2),y
        sta mnrel+1
        cmp #2                  ; (512 at most: that or none)
        bcc @rn
        lda #0
        sta mnrel
        sta mnrel+1
        beq @rk
@rn     lda stage+13            ; (flag 8: it can move)
        and #8
        bne @rk
        lda #0                  ; (listed but not to be moved)
        sta mnrel
        sta mnrel+1
@rk     ldy #0                  ; skip the count; copy the words
        lda (p2),y
        sta t2
        iny
        lda (p2),y
        sta t3
        lda p2
        clc
        adc #2
        sta p2
        bcc @r0
        inc p2+1
@r0     asl t2                  ; (bytes)
        rol t3
        lda mnrel
        ora mnrel+1
        beq @skip
        lda #<mrel
        sta p1
        lda #>mrel
        sta p1+1
        lda p2
        pha
        lda p2+1
        pha
        lda t2
        pha
        lda t3
        pha
        jsr copyn
        pla
        sta t3
        pla
        sta t2
        pla
        sta p2+1
        pla
        sta p2
@skip   lda p2                  ; past them
        clc
        adc t2
        sta p2
        lda p2+1
        adc t3
        sta p2+1
        ldy #0                  ; its name (32), author, released
@n      lda (p2),y
        jsr asc2pet
        sta mtitle,y
        iny
        cpy #32
        bcc @n
        lda p2
        clc
        adc #96
        sta p2
        bcc @d
        inc p2+1
@d      jsr tomusp              ; the bytes
        lda #1
        sta mok
        clc
        rts
@bad    lda #r_notmus
        jmp mrefuse

; ------------------------------------------------------------
; the reasons a tune is refused, said by prwhy
; ------------------------------------------------------------
r_notmus = 1
r_rsid  = 2
r_sid   = 3                     ; a .sid: SID-SLM makes it a .slm
r_long  = 5
r_slm1  = 6
r_zp    = 9                     ; (beside a game)
r_rate  = 10
r_cyc   = 11
r_ingame = 12
r_noroom = 13
r_ldmem = 14
r_share = 15
nwhy    = 16

; prwhy  "refused: " and mwhy's reason (and its address, where it has
; one); prwhy2 the reason alone, no new line (the menu's)
prwhy   ldx #<tx_refused
        ldy #>tx_refused
        jsr print
        jsr prwhy2
        lda #13
        jmp chrout
prwhy2  ldx mwhy
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
        jmp prhex4
@nl     rts
tx_refused text "refused: ",0

; ------------------------------------------------------------
; reason texts (prwhy), and whether one has an address to show
; ------------------------------------------------------------
whylo   byte <rsn0,<rsn1,<rsn2,<rsn3,<rsn0,<rsn5,<rsn6,<rsn0,<rsn0,<rsn9,<rsn10,<rsn11,<rsn12,<rsn13,<rsn14,<rsn15
whyhi   byte >rsn0,>rsn1,>rsn2,>rsn3,>rsn0,>rsn5,>rsn6,>rsn0,>rsn0,>rsn9,>rsn10,>rsn11,>rsn12,>rsn13,>rsn14,>rsn15
whyadr  byte 0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0
rsn0      text "?",0
rsn1      text "not a .slm",0
rsn2      text "rsid: takes interrupts",0
rsn3      text "a .sid: sid-slm makes the .slm",0
rsn5      text "over 4096 bytes",0
rsn6      text "old .slm: prepare again",0
rsn9      text "the module's zero page",0
rsn10     text "module needs once a frame",0
rsn11     text "too slow beside a module",0
rsn12     text "in the module's memory",0
rsn13     text "no room with the picture",0
rsn14     text "in the loader's memory",0
rsn15     text "too much cpu for loading",0

; ------------------------------------------------------------
; range lists: a count, then (lo, hi exclusive) word pairs
; ------------------------------------------------------------
lldr    byte 2                  ; the loader's: no game there
        word $0000,$0800,$fffa,$ffff
lbusy   byte 3                  ; ... and i/o: no tune there
        word $0000,$0800,$d000,$e000,$fffa,$ffff
lbusyws byte 3                  ; a tune's workspace: not these
        word $0000,$0200,$0400,$0800,$fffa,$ffff
lmcl    byte 0                  ; the game's claims
        word 0,0,0,0,0,0,0,0
lmus    byte 0                  ; the tune and its workspace (17)
        word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
lban    byte 0                  ; place_show's: loader, i/o, the tune (20)
        word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        word 0,0,0,0,0,0
lpic    byte 0                  ; the picture's screen and bitmap
        word 0,0,0,0
lclaim  byte 0                  ; the claims: the program there loads after (24)
        word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
maxclaim = 24

; rovl  c set if the range t0/t1-t2/t3 overlaps one in the list at a/y
;   uses: a, y, p3 (the range kept)
rovl    sta p3
        sty p3+1
        ldy #0
        lda (p3),y
        sta rovn                ; entries left
        iny                     ; (y: an entry's lo)
@e      lda rovn
        beq @no
        iny                     ; t0/t1 < its hi?
        iny
        lda t0
        cmp (p3),y
        iny
        lda t1
        sbc (p3),y
        bcs @n                  ; (no: y on hi's high byte)
        dey                     ; its lo < t2/t3?
        dey
        dey
        lda (p3),y
        cmp t2
        iny
        lda (p3),y
        sbc t3
        bcc @yes
        iny
        iny
@n      iny                     ; the next entry's lo
        dec rovn
        jmp @e
@yes    sec
        rts
@no     clc
        rts
rovn    byte 0

; ladd  the range t0/t1-t2/t3 added to the list at a/y
;   uses: a, y, p3
ladd    sta p3
        sty p3+1
        ldy #0
        lda (p3),y
        clc
        adc #1
        sta (p3),y
        asl a                   ; its entry: 1 + 4 (n - 1)
        asl a
        tay
        dey
        dey
        dey
        lda t0
        sta (p3),y
        iny
        lda t1
        sta (p3),y
        iny
        lda t2
        sta (p3),y
        iny
        lda t3
        sta (p3),y
        rts

; lget  entry x of the list at a/y into t0/t1-t2/t3
;   uses: a, y, p3
lget    sta p3
        sty p3+1
        txa
        asl a
        asl a
        tay
        iny
        lda (p3),y
        sta t0
        iny
        lda (p3),y
        sta t1
        iny
        lda (p3),y
        sta t2
        iny
        lda (p3),y
        sta t3
        rts

; lcopy  the list at lcsrc appended to the list at lcdst
;   uses: a, x, y, p3, t0-t3
lcopy   lda #0
        sta lci
@c      lda lcsrc
        sta p3
        lda lcsrc+1
        sta p3+1
        ldy #0
        lda (p3),y
        cmp lci
        beq @x
        bcc @x
        ldx lci
        lda lcsrc
        ldy lcsrc+1
        jsr lget
        lda lcdst
        ldy lcdst+1
        jsr ladd
        inc lci
        bne @c
@x      rts
lcsrc   word 0
lcdst   word 0
lci     byte 0

; lovl  c set if a range in the list at lov1 overlaps one in the list at
; lov2
;   uses: a, x, y, p3, t0-t3
lovl    lda #0
        sta lovi
@c      lda lov1
        sta p3
        lda lov1+1
        sta p3+1
        ldy #0
        lda (p3),y
        cmp lovi
        beq @no
        bcc @no
        ldx lovi
        lda lov1
        ldy lov1+1
        jsr lget
        lda lov2
        ldy lov2+1
        jsr rovl
        bcs @yes
        inc lovi
        bne @c
@no     clc
@yes    rts
lov1    word 0
lov2    word 0
lovi    byte 0

; under  usum (3 bytes) += the program's bytes under t0/t1-t2/t3
;   uses: a (the range kept)
under   lda t0                  ; lo = max(t0, paddr)
        sta u0
        lda t1
        sta u1
        lda paddr
        cmp t0
        lda paddr+1
        sbc t1
        bcc @l
        lda paddr
        sta u0
        lda paddr+1
        sta u1
@l      lda t2                  ; hi = min(t2, pend)
        sta u2
        lda t3
        sta u3
        lda pend
        cmp t2
        lda pend+1
        sbc t3
        bcs @h
        lda pend
        sta u2
        lda pend+1
        sta u3
@h      lda u2                  ; hi - lo, if more than 0
        sec
        sbc u0
        sta u0
        lda u3
        sbc u1
        bcc @x
        sta u1
        ora u0
        beq @x
        lda usum
        clc
        adc u0
        sta usum
        lda usum+1
        adc u1
        sta usum+1
        bcc @x
        inc usum+2
@x      rts
u0      byte 0
u1      byte 0
u2      byte 0
u3      byte 0
usum    byte 0,0,0

; underl  usum += the program's bytes under every range in the list at a/y
underl  sta ulist
        sty ulist+1
        lda #0
        sta uli
@c      lda ulist
        sta p3
        lda ulist+1
        sta p3+1
        ldy #0
        lda (p3),y
        cmp uli
        beq @x
        bcc @x
        ldx uli
        lda ulist
        ldy ulist+1
        jsr lget
        jsr under
        inc uli
        bne @c
@x      rts
ulist   word 0
uli     byte 0

; ------------------------------------------------------------
; mlist  lmus: the tune at mat (its length mlen) and its workspace
; ------------------------------------------------------------
mlist   lda #0
        sta lmus
        lda mat
        sta t0
        clc
        adc mlen
        sta t2
        lda mat+1
        sta t1
        adc mlen+1
        sta t3
        lda #<lmus
        ldy #>lmus
        jsr ladd
        ldx #0
@w      cpx mnws
        bcs @x
        stx t6
        lda #<(mws-1)
        ldy #>(mws-1)
        jsr lget
        lda #<lmus
        ldy #>lmus
        jsr ladd
        ldx t6
        inx
        bne @w
@x      rts
mat     word 0                  ; where the tune is tried

; ------------------------------------------------------------
; gameok / showok  the test place_tune tries a place (mat) with: c set
; if it fits (gameok: clear of the game's claims; showok: place_show
; finds room for the module and the picture beside it)
; ------------------------------------------------------------
gameok  jsr mlist
        lda #<lmus
        sta lov1
        lda #>lmus
        sta lov1+1
        lda #<lmcl
        sta lov2
        lda #>lmcl
        sta lov2+1
        jsr lovl
        bcs @no
        sec
        rts
@no     clc
        rts
showok  jsr mlist
        jmp plshow

; ------------------------------------------------------------
; place_tune  the tune where its file has it if pltest (gameok or
; showok) passes, else (a prepared tune that can move) the highest page,
; at the same offset, where it does: moved there. (Moved for an earlier
; tape, it goes back first: each tape places it as c64model does.)
;   in:   pltest set
;   out:  c set if it fits nowhere
; ------------------------------------------------------------
pltune  lda mload+1             ; (moves keep the offset in the page)
        cmp morig+1
        beq @h
        lda morig
        sta mat
        lda morig+1
        sta mat+1
        jsr mmove
@h      lda mload
        sta mat
        lda mload+1
        sta mat+1
        jsr pltry
        bcs @ok
        lda mnrel
        ora mnrel+1
        beq @no
        lda #$ff
        sta mat+1
@p      lda mat+1
        cmp #$08
        bcc @no
        cmp mload+1             ; (not where it is)
        beq @nx
        lda mat                 ; its end: $fffa at most
        clc
        adc mlen
        sta t2
        lda mat+1
        adc mlen+1
        sta t3
        bcs @nx
        lda t2
        cmp #<$fffb
        lda t3
        sbc #>$fffb
        bcs @nx
        lda mat
        sta t0
        lda mat+1
        sta t1
        lda #<lmove             ; clear of the loader, i/o, its workspace
        ldy #>lmove
        jsr rovl
        bcs @nx
        jsr rovlw
        bcs @nx
        jsr pltry
        bcs @mv
@nx     dec mat+1
        jmp @p
@mv     jsr mmove
@ok     clc
        rts
@no     sec
        rts
pltry   jmp (pltest)
pltest  word gameok
lmove   byte 2
        word $0000,$0800,$d000,$e000

; rovlw  rovl against the tune's workspace (mws, mnws entries)
rovlw   lda mnws
        sta mws-1               ; (a count byte before the list)
        lda #<(mws-1)
        ldy #>(mws-1)
        jmp rovl

; mmove  the tune moved to mat: its relocations (high bytes + the move
; in pages), init and play
mmove   lda mat+1
        sec
        sbc mload+1
        sta t6                  ; the move, in pages
        lda #<mrel
        sta p3
        lda #>mrel
        sta p3+1
        lda mnrel
        sta t4
        lda mnrel+1
        sta t5
@r      lda t4
        ora t5
        beq @e
        ldy #0                  ; its offset: the tune's byte at the pool
        lda (p3),y              ; + mload's offset in its page
        clc
        adc mload
        sta p1
        iny
        lda (p3),y
        adc #>mpool
        sta p1+1
        ldy #0
        lda (p1),y
        clc
        adc t6
        sta (p1),y
        lda p3
        clc
        adc #2
        sta p3
        bcc @d
        inc p3+1
@d      lda t4
        bne @d2
        dec t5
@d2     dec t4
        jmp @r
@e      lda minit+1
        clc
        adc t6
        sta minit+1
        lda mplay+1
        clc
        adc t6
        sta mplay+1
        lda mat
        sta mload
        lda mat+1
        sta mload+1
        rts

; ------------------------------------------------------------
; plshow  place_show: the VIC bank (sbank) and the module's address
; (sbase) for the show module and the picture: clear of the loader, I/O,
; the tune (lmus, when there is one) and each other, with the least of
; the program under them (the first found of the least)
;   in:   kuse (a picture), muse (a tune: lmus)
;   out:  c set if there's room
; ------------------------------------------------------------
sbstart = $fe00-showlen/256*256 ; the module's highest place to try
plshow  lda #0
        sta lban
        sta sfound
        lda #<lbusy             ; the loader, i/o (and the tune)
        sta lcsrc
        lda #>lbusy
        sta lcsrc+1
        lda #<lban
        sta lcdst
        lda #>lban
        sta lcdst+1
        jsr lcopy
        lda muse
        beq @nm
        lda #<lmus
        sta lcsrc
        lda #>lmus
        sta lcsrc+1
        jsr lcopy
@nm     lda #$ff                ; the best so far: none
        sta sbest
        sta sbest+1
        sta sbest+2
        lda #3
        sta sbk
@bank   lda #0                  ; the picture's screen and bitmap here
        sta lpic
        lda kuse
        beq @np
        lda sbk                 ; bank x $40 + $0c, $0f; + $20, $3f
        asl a
        asl a
        asl a
        asl a
        asl a
        asl a
        sta t4
        lda #$00
        sta t0
        lda #$e8
        sta t2
        lda t4
        ora #$0c
        sta t1
        ora #$03
        sta t3
        lda #<lpic
        ldy #>lpic
        jsr ladd
        lda #$00
        sta t0
        lda #$40
        sta t2
        lda t4
        ora #$20
        sta t1
        ora #$1f
        sta t3
        lda #<lpic
        ldy #>lpic
        jsr ladd
        lda #<lpic              ; clear of the banned?
        sta lov1
        lda #>lpic
        sta lov1+1
        lda #<lban
        sta lov2
        lda #>lban
        sta lov2+1
        jsr lovl
        bcc @np
        jmp @nbank
@np     lda #$ca                ; the module: $ca00 first, then from the top
        sta sbh
        lda #1
        sta sfirst
@base   lda #0                  ; its range
        sta t0
        lda sbh
        sta t1
        lda #<showlen
        sta t2
        lda sbh
        clc
        adc #>showlen
        sta t3
        lda #<lban
        ldy #>lban
        jsr rovl
        bcs @nb
        lda #<lpic
        ldy #>lpic
        jsr rovl
        bcs @nb
        lda #0                  ; the program under them
        sta usum
        sta usum+1
        sta usum+2
        jsr under
        lda #<lpic
        ldy #>lpic
        jsr underl
        lda usum                ; less than the best?
        cmp sbest
        lda usum+1
        sbc sbest+1
        lda usum+2
        sbc sbest+2
        bcs @ns
        lda usum
        sta sbest
        lda usum+1
        sta sbest+1
        lda usum+2
        sta sbest+2
        lda sbk
        sta sbank
        lda sbh
        sta sbase+1
        lda #0
        sta sbase
        lda #1
        sta sfound
@ns     lda sbest               ; none under: done
        ora sbest+1
        ora sbest+2
        beq @done
@nb     lda sfirst              ; the next place
        beq @dn
        lda #0
        sta sfirst
        lda #>sbstart
        sta sbh
        beq @bq0
        jmp @base
@bq0
@dn     dec sbh
        lda sbh
        cmp #$08
        bcc @bq1
        jmp @base
@bq1
@nbank  lda kuse                ; the next bank (with a picture)
        beq @done
        lda sbest
        ora sbest+1
        ora sbest+2
        beq @done
        dec sbk
        bmi @done
        jmp @bank
@done   lda sfound
        cmp #1                  ; (c set: found)
        rts
sbk     byte 0
sbh     byte 0
sfirst  byte 0
sfound  byte 0
sbest   byte 0,0,0
sbank   byte 3
sbase   word 0
kuse    byte 0                  ; a picture on the tape
muse    byte 0                  ; a tune on the tape

; ------------------------------------------------------------
; shshare  the loader's share beside a show's tune (c64model.show_share):
; calls = the most of 19968 x 256 / pal and 16832 x 256 / ntsc; need =
; cyc x calls x 13 / 2560 + 900; avail = 17095 (less 1000 with a
; picture); share = 100 x (avail - need) / avail, 85 at most
;   out:  a; c set if under 25 (refused)
; ------------------------------------------------------------
shshare lda #<19968
        ldx #>19968
        ldy #0
        jsr c256
        lda q24
        sta t4
        lda q24+1
        sta t5
        lda #<16832
        ldx #>16832
        ldy #2
        jsr c256
        lda q24                 ; the most
        cmp t4
        lda q24+1
        sbc t5
        bcc @m
        lda q24
        sta t4
        lda q24+1
        sta t5
@m      lda t4                  ; x cyc
        sta m32a
        lda t5
        sta m32a+1
        lda mcyc
        sta m32b
        lda mcyc+1
        sta m32b+1
        jsr mul16
        lda #0                  ; x 13 (32 bits)
        sta n24
        sta n24+1
        sta n24+2
        sta n24+3
        ldx #13
@a      lda n24
        clc
        adc m32r
        sta n24
        lda n24+1
        adc m32r+1
        sta n24+1
        lda n24+2
        adc m32r+2
        sta n24+2
        lda n24+3
        adc m32r+3
        sta n24+3
        dex
        bne @a
        lda #<2560              ; / 2560
        sta dvs
        lda #>2560
        sta dvs+1
        jsr divn
        lda q24                 ; + 900: need (t4/t5)
        clc
        adc #<900
        sta t4
        lda q24+1
        adc #>900
        sta t5
        lda q24+2
        ora q24+3
        bne @no
        bcs @no
        lda #<17095             ; avail
        sta shav
        lda #>17095
        sta shav+1
        lda kuse
        beq @av
        lda #<16095
        sta shav
        lda #>16095
        sta shav+1
@av     lda t4                  ; need < avail?
        cmp shav
        lda t5
        sbc shav+1
        bcs @no
        lda shav                ; 100 x (avail - need) / avail
        sec
        sbc t4
        sta m32a
        lda shav+1
        sbc t5
        sta m32a+1
        lda #100
        sta m32b
        lda #0
        sta m32b+1
        jsr mul16
        lda m32r
        sta n24
        lda m32r+1
        sta n24+1
        lda m32r+2
        sta n24+2
        lda #0
        sta n24+3
        lda shav
        sta dvs
        lda shav+1
        sta dvs+1
        jsr divn
        lda q24
        cmp #25
        bcc @no
        cmp #86
        bcc @ok
        lda #85
@ok     clc
        rts
@no     sec
        rts

shav    word 0

; c256  q24: a/x x 256 / (mppal, y = 0; mpntsc, y = 2)
c256    sta n24+1
        stx n24+2
        lda #0
        sta n24
        sta n24+3
        lda mppal,y
        sta dvs
        lda mppal+1,y
        sta dvs+1
        jmp divn

; ------------------------------------------------------------
; prepare  what goes on the tape with the program, for the show chosen
; (c64model.setup): the parts in tape order (npart: address, place,
; length, i/o), the claims (lclaim), and the module (modon: its entry
; points, jitter, share, whether the screen is on)
;   out:  c set if it can't be (said)
; ------------------------------------------------------------
npart   byte 0                  ; the parts (8 at most)
ptal    byte 0,0,0,0,0,0,0,0
ptah    byte 0,0,0,0,0,0,0,0
ptpl    byte 0,0,0,0,0,0,0,0
ptph    byte 0,0,0,0,0,0,0,0
ptll    byte 0,0,0,0,0,0,0,0
ptlh    byte 0,0,0,0,0,0,0,0
ptio    byte 0,0,0,0,0,0,0,0
modon   byte 0                  ; a module (the game or the show module)
mdent   word 0,0,0              ; its init, frame, stop
mdjit   byte 0
mdshr   byte 0
mdscr   byte 0                  ; the screen on while it runs

prepare lda opt_lines           ; a style: its patch and colours in the
        beq @p                  ; cassette buffer whole? (nothing of ours
        lda #0                  ; uses it, but a cartridge or a wedge might)
        tax
@c2     eor c2ins,x
        inx
        cpx #c2n
        bcc @c2
        cmp #c2x
        beq @p
        ldx #<tx_c2bad
        ldy #>tx_c2bad
        jmp prfail
@p      lda #0
        sta npart
        sta lclaim
        sta modon
        sta muse
        sta kuse
        lda opt_show
        bne @s
        clc
        rts
@s      cmp #1                  ; what it needs
        bne @ng
        lda gok
        bne @gm
        ldx #<tx_needg
        ldy #>tx_needg
        jmp prfail
@gm     lda mok                 ; a game: music if a tune is chosen
        beq @hp
        cmp #1
        bne @mref
        inc muse
        bne @hp
@ng     cmp #4                  ; 2, 3: a picture
        beq @nk
        lda kok
        bne @k
        ldx #<tx_needk
        ldy #>tx_needk
        jmp prfail
@k      inc kuse
@nk     lda opt_show            ; 3, 4: a tune
        cmp #3
        bcc @hp
        lda mok
        cmp #1
        beq @mu
        cmp #2
        beq @mref
        ldx #<tx_needm
        ldy #>tx_needm
        jmp prfail
@mref   ldx #<tx_mref               ; (and why again: it was said when it
        ldy #>tx_mref               ; was read, a menu ago)
        jsr print
        jsr prwhyr
        ldx #<tx_mref2
        ldy #>tx_mref2
        jmp prfail
@mu     inc muse
@hp     jsr hpready             ; the game or the picture in the pool
        bcc @t
        rts
@t      lda muse                ; the tune: what any tune keeps to
        beq @mod
        jsr tunechk
        bcc @mod
        rts
@mod    lda opt_show
        cmp #1
        bne @show
        jmp prgame
@show   jmp prshow
tx_needg text "choose a module (4)",13,0
tx_c2bad text "$033c was overwritten: load again",13,0
tx_needk text "choose a picture (6)",13,0
tx_needm text "choose some music (5)",13,0
tx_mref text "the music was refused:",13,0
tx_mref2 text "choose another, or none (5)",13,0

; hpready  the high pool holding what the show needs (read again if
; the other one is there)
;   out:  c set on an error (said)
hpready lda opt_show
        cmp #1
        bne @k
        lda hpool
        cmp #1
        beq @ok
        lda gdev
        ldx #<gnlen
        ldy #>gnlen
        jsr setfn
        jmp ldgame
@k      cmp #4
        beq @ok
        lda hpool
        cmp #2
        beq @ok
        lda kdev
        ldx #<knlen
        ldy #>knlen
        jsr setfn
        jmp ldpic
@ok     clc
        rts

; setfn  fdev a, fnlen/fname from the length and name at x/y
setfn   sta fdev
        stx p3
        sty p3+1
        ldy #0
        lda (p3),y
        sta fnlen
@c      iny
        lda (p3),y
        sta fname-1,y
        cpy #16
        bcc @c
        rts

; tunechk  what any tune keeps to (c64model.tune_checks): out of the
; loader's memory and I/O, its workspace out of the loader's
;   out:  c set if not (said, mok 2)
tunechk lda mload
        sta mat
        lda mload+1
        sta mat+1
        jsr mlist
        ldx #0
        lda #<lmus
        ldy #>lmus
        jsr lget
        lda #<lbusy
        ldy #>lbusy
        jsr rovl
        bcs @no
        lda t2                  ; (and its end: $fffa at most, no wrap)
        cmp #<$fffb
        lda t3
        sbc #>$fffb
        bcs @no
        lda t1
        cmp t3
        beq @w
        bcs @no
@w      lda #<(mws-1)           ; the workspace
        sta lov1
        lda #>(mws-1)
        sta lov1+1
        lda #<lbusyws
        sta lov2
        lda #>lbusyws
        sta lov2+1
        jsr lovl
        bcs @no
        clc
        rts
@no     lda #r_ldmem
        jsr mrefuse
        sec
        rts

; addpart  part npart: address t0/t1, place p1, length t2/t3, i/o a
addpart ldx npart
        sta ptio,x
        lda t0
        sta ptal,x
        lda t1
        sta ptah,x
        lda p1
        sta ptpl,x
        lda p1+1
        sta ptph,x
        lda t2
        sta ptll,x
        lda t3
        sta ptlh,x
        inc npart
        rts

; tunepart  the tune as the first part
tunepart
        lda mload
        sta t0
        lda mload+1
        sta t1
        lda mload
        sta p1
        lda #>mpool
        sta p1+1
        lda mlen
        sta t2
        lda mlen+1
        sta t3
        lda #0
        jmp addpart

; ------------------------------------------------------------
; prgame  a module: the tune beside it (c64model.game_tune), placed
; clear of its claims; its header patched; its parts, the main one last
; ------------------------------------------------------------
prgame  jsr gclaims             ; lmcl
        lda muse
        bne @bq2
        jmp @hd
@bq2
        ldx #2                  ; its zero page: $10-$6f, $80-$8f are the game's
@z      lda mzp,x
        bne @zp
        inx
        cpx #14
        bcc @z
        ldx #16
        lda mzp,x
        bne @zp
        inx
        lda mzp,x
        bne @zp
        lda mppal               ; once a frame: 19968 within 399
        sec
        sbc #<19968
        sta t0
        lda mppal+1
        sbc #>19968
        bcs @pos
        eor #$ff                ; (negative: its size)
        sta t1
        lda t0
        eor #$ff
        clc
        adc #1
        sta t0
        lda t1
        adc #0
@pos    sta t1
        lda #<399
        cmp t0
        lda #>399
        sbc t1
        bcs @cy
        lda #r_rate
        jmp prnot
@cy     lda #<gameplaymax       ; its longest play call
        cmp mcyc
        lda #>gameplaymax
        sbc mcyc+1
        bcs @pl
        lda #r_cyc
        jmp prnot
@zp     ldy #0                  ; (its first: byte x, its lowest bit)
@zb     lsr a
        bcs @za
        iny
        bne @zb
@za     sty mwhya
        txa
        asl a
        asl a
        asl a
        ora mwhya
        sta mwhya
        lda #0
        sta mwhya+1
        lda #r_zp
        jmp prnot
@pl     lda #<gameok
        sta pltest
        lda #>gameok
        sta pltest+1
        jsr pltune
        bcc @hd
        lda #r_ingame
        jmp prnot
@hd     lda gppl                ; the header: song, share, music
        sta p1
        lda gpph
        sta p1+1
        ldy #13
        lda #$ff
        ldx muse
        beq @so
        lda ma
@so     jsr hput
        iny
        lda gshr
        jsr hput
        lda muse                ; the music fields: the tune's, or as the
        beq @fo                 ; file had them
        jsr mfields
        jmp @fw
@fo     ldx #8
@fc     lda gorig,x
        sta hdrmus,x
        dex
        bpl @fc
@fw     ldy #16
@mf     lda hdrmus-16,y
        jsr hput
        iny
        cpy #25
        bcc @mf
        jsr pblocks             ; +26: the program's size in disk blocks
                                ; (liveblk: what loads while it runs)
        ldy #26
        jsr hput
@pa     lda muse                ; the parts: the tune, the others, the main
        beq @o
        jsr tunepart
@o      ldx #1
@op     cpx gnp
        bcs @mn
        stx t6
        jsr gpart
        ldx t6
        inx
        bne @op
@mn     ldx #0
        jsr gpart
        lda #<lmcl              ; the claims: the game's, the tune's
        sta lcsrc
        lda #>lmcl
        sta lcsrc+1
        jsr toclaim
        jsr musclaim
        lda #1                  ; the module: the game
        sta modon
        sta mdscr
        ldx #5
@en     lda gentry,x
        sta mdent,x
        dex
        bpl @en
        lda gjit
        sta mdjit
        lda gshr
        sta mdshr
        clc
        rts
gameplaymax = 3700              ; (c64model.GAME_PLAY_MAX)

; pblocks  the program's size in disk blocks: (plen + 2) / 254, rounded
; up (250 at most: $0801-$fff9) for a game's header +26 (plan's liveblk
; then puts in the part that loads while it runs)
; nblocks  the same for a length in a (low) and x (high)
;   out:  a;  uses: x, y
pblocks lda plen                ; plen + 2 + 253, then 254s out of it
        ldx plen+1
nblocks clc
        adc #255
        bcc @s
        inx
@s      ldy #$ff
@l      iny
        sec
        sbc #254
        bcs @l
        dex
        cpx #$ff
        bne @l
        tya
        rts

; prnot  the tune can't play in this show (reason a): said, c set (it
; stays chosen: another show may take it)
prnot   sta mwhy
        jsr prwhy
        sec
        rts

; gpart  the game's part x
gpart   lda gpal,x
        sta t0
        lda gpah,x
        sta t1
        lda gppl,x
        sta p1
        lda gpph,x
        sta p1+1
        lda gpll,x
        sta t2
        lda gplh,x
        sta t3
        lda #0
        jmp addpart

; toclaim  the list at lcsrc into lclaim
toclaim lda #<lclaim
        sta lcdst
        lda #>lclaim
        sta lcdst+1
        jmp lcopy

; musclaim  the tune's ranges (lmus, as it is now) into lclaim
musclaim
        lda muse
        beq @x
        lda mload
        sta mat
        lda mload+1
        sta mat+1
        jsr mlist
        lda #<lmus
        sta lcsrc
        lda #>lmus
        sta lcsrc+1
        jmp toclaim
@x      rts

; mfields  hdrmus: the header's music fields (+16 to +24): init, play,
; the two play times, 2 (a sid tune)
mfields ldx #0
@c      lda minit,x
        sta hdrmus,x
        inx
        cpx #4
        bcc @c
        ldx #0
@p      lda mppal,x
        sta hdrmus+4,x
        inx
        cpx #4
        bcc @p
        lda #2
        sta hdrmus+8
        rts
hdrmus  byte 0,0,0,0,0,0,0,0,0

; ------------------------------------------------------------
; prshow  the show module: the tune and the picture placed beside it,
; the module moved to its place and its header patched; the parts: the
; tune, the picture's screen, colours and bitmap, the module
; ------------------------------------------------------------
prshow  lda muse
        beq @nm
        lda #<showok
        sta pltest
        lda #>showok
        sta pltest+1
        jsr pltune
        bcc @placed
        lda #r_noroom
        jmp prnot
@nm     jsr plshow
        bcs @placed
        ldx #<tx_noroom
        ldy #>tx_noroom
        jmp prfail
@placed jsr mlist               ; (lmus as placed)
        ldx #0                  ; the module, moved
@cp     lda pl_show,x
        sta showtmp,x
        lda pl_show+256,x
        sta showtmp+256,x
        inx
        bne @cp
        lda sbase+1
        sec
        sbc #>showbase
        sta t6
        ldx #0
@r      cpx #nshowrel
        bcs @hd
        lda showrello,x
        sta p1
        lda showrelhi,x
        clc
        adc #>showtmp
        sta p1+1
        ldy #0
        lda (p1),y
        clc
        adc t6
        sta (p1),y
        inx
        bne @r
@hd     lda showtmp+14          ; the share: the module's, or the tune's
        sta mdshr
        lda muse
        beq @sh
        jsr shshare
        bcc @sok
        lda #r_share
        jmp prnot
@sok    sta mdshr
@sh     lda mdshr
        sta showtmp+14
        lda #$ff                ; song, picture, music, bank
        ldx muse
        beq @so
        lda ma
@so     sta showtmp+13
        lda #$ff
        ldx kuse
        beq @bg
        lda kbg
@bg     sta showtmp+15
        lda muse
        beq @bk
        jsr mfields
        ldx #8
@mf     lda hdrmus,x
        sta showtmp+16,x
        dex
        bpl @mf
@bk     lda #3                  ; 3 - bank (bank 3 without a picture)
        ldx kuse
        beq @b3
        sec
        sbc sbank
        jmp @b
@b3     lda #0
@b      sta showtmp+25
        lda muse                ; the parts
        beq @np
        jsr tunepart
@np     lda kuse
        beq @mo
        jsr picparts
@mo     lda sbase
        sta t0
        lda sbase+1
        sta t1
        lda #<showbuf
        sta p1
        lda #>showbuf
        sta p1+1
        lda #<showlen
        sta t2
        lda #>showlen
        sta t3
        lda #0
        jsr addpart
        lda #0                  ; the claims: the module's, the tune's, the picture's
        sta t0
        lda sbase+1
        sta t1
        lda #<showclaim
        sta t2
        lda sbase+1
        clc
        adc #>showclaim
        sta t3
        lda #<lclaim
        ldy #>lclaim
        jsr ladd
        jsr musclaim
        lda kuse
        beq @md
        lda #<lpic              ; (lpic: for the bank chosen)
        sta lcsrc
        lda #>lpic
        sta lcsrc+1
        jsr toclaim
@md     jsr toshow              ; the module to its place in the high pool
        lda #1                  ; the module
        sta modon
        ldx #5
@en     lda showtmp+4,x
        sta mdent,x
        dex
        bpl @en
        lda showtmp+12
        sta mdjit
        lda #1
        sta mdscr
        lda opt_show
        cmp #4                  ; music alone: the screen off
        bne @on
        lda #0
        sta mdscr
        sta mdjit
@on     clc
        rts
tx_noroom text "no room for the picture",13,0
showtmp = $bc00                 ; the module made here, then to showbuf

; toshow  the module from showtmp to showbuf (the high pool); a game
; reaching that far there is read again when it's wanted
toshow  lda hpool
        cmp #1
        bne @c
        lda hplen+1
        cmp #>(showbuf-hpbase)
        bcc @c
        lda #0
        sta hpool
@c      lda #<showbuf
        sta p3
        lda #>showbuf
        sta p3+1
        ldy #0
@l      lda showtmp,y
        jsr hput3
        iny
        bne @l
        inc p3+1
@l2     lda showtmp+256,y
        jsr hput3
        iny
        bne @l2
        rts

; picparts  the picture's parts for bank sbank (and lpic for it): the
; screen, the colours (straight into colour ram), the bitmap
picparts
        lda sbank
        asl a
        asl a
        asl a
        asl a
        asl a
        asl a
        sta t4                  ; the bank's high byte
        lda #0                  ; screen: bank + $0c00, the bitmap + 8000
        sta t0
        lda t4
        ora #$0c
        sta t1
        lda kbit
        clc
        adc #<8000
        sta p1
        lda kbit+1
        adc #>8000
        sta p1+1
        lda #<1000
        sta t2
        lda #>1000
        sta t3
        lda #0
        jsr addpart
        lda #0                  ; colours: $d800, + 9000, i/o
        sta t0
        lda #$d8
        sta t1
        lda kbit
        clc
        adc #<9000
        sta p1
        lda kbit+1
        adc #>9000
        sta p1+1
        lda #1
        jsr addpart
        lda #0                  ; bitmap: bank + $2000
        sta t0
        lda t4
        ora #$20
        sta t1
        lda kbit
        sta p1
        lda kbit+1
        sta p1+1
        lda #<8000
        sta t2
        lda #>8000
        sta t3
        lda #0
        jsr addpart
        lda #0                  ; lpic for this bank
        sta lpic
        lda #$00
        sta t0
        lda #$e8
        sta t2
        lda t4
        ora #$0c
        sta t1
        ora #$03
        sta t3
        lda #<lpic
        ldy #>lpic
        jsr ladd
        lda #$00
        sta t0
        lda #$40
        sta t2
        lda t4
        ora #$20
        sta t1
        ora #$1f
        sta t3
        lda #<lpic
        ldy #>lpic
        jmp ladd
