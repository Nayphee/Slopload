; ------------------------------------------------------------
; chain.asm  -  SlopLoad 64's chains (slopload.py's -then): a second
; module after the first, chosen on line 4. The first shows while the
; second's parts load, the second while the program loads; the switch
; (src/chain.asm, pl_sw: its 12 bytes filled in here) is the first's
; last part. Only the second's header, its parts' places and its claims
; are kept: its bytes are read from its file again as the tape is
; written (getblk's source 3, readb), as the program's are, so the two
; needn't fit in the high pool together. tools/c64model.py (setup and
; plan with then=) is the reference.
; ------------------------------------------------------------

bok     byte 0                  ; a second module chosen
chainon byte 0                  ; ... and a chain on this tape (prepare: the show a module)
bdev    byte 8
bnlen   byte 0                  ; its file's name
bname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
gblkn   = gorig+9-gnp           ; a module's fields, as ldgame leaves them
bsave   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
bnp     = bsave                 ; (the second's: gnp, gpal ... as the first's)
bpal    = bsave+gpal-gnp
bpah    = bsave+gpah-gnp
bpll    = bsave+gpll-gnp
bplh    = bsave+gplh-gnp
bppl    = bsave+gppl-gnp        ; (its parts' places in the pool when read:
bpph    = bsave+gpph-gnp        ; less $d000, where they are in its file)
bjit    = bsave+gjit-gnp
bshr    = bsave+gshr-gnp
bbord   = bsave+gbord-gnp
bentry  = bsave+gentry-gnp
bhdr    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
lbcl    byte 0                  ; its claims
        word 0,0,0,0,0,0,0,0
nchain  word 0                  ; its parts' bytes
cb0     byte 0                  ; its first block
bpos    word 0                  ; its file, while written: the next byte's place
bopen   byte 0                  ; ... open (channel 5)
kbord   byte 0                  ; the +27 of the module that ends the load

; ------------------------------------------------------------
; gswap  the module's fields (gnp to gorig) and bsave exchanged
;   uses: a, x, y
; ------------------------------------------------------------
gswap   ldx #gblkn-1
@c      lda gnp,x
        ldy bsave,x
        sta bsave,x
        tya
        sta gnp,x
        dex
        bpl @c
        rts

; ------------------------------------------------------------
; athen  line 4's second module: chosen from the drive's .lm files,
; read into the high pool and checked as the first was (ldgame), its
; fields, header and claims kept, the first's put back; refused if the
; two share memory; 0: none (bok 0)
;   out:  bok
; ------------------------------------------------------------
athen   lda bdev
        ldx #<sfx_lm
        ldy #>sfx_lm
        jsr pickfile
        bcc @rd
        lda pkzero              ; 0: none
        beq @kp
        lda #0
        sta bok
@kp     rts
@rd     lda #0                  ; (a new second: the old one gone)
        sta bok
        ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        jsr gswap               ; (the first's fields aside)
        jsr ldgame
        lda #0                  ; (the pool: not the first any more)
        sta hpool
        bcc @cl
        jmp @back
@cl     jsr gclaims             ; its claims
        lda #0
        sta lbcl
        lda #<lmcl
        sta lcsrc
        lda #>lmcl
        sta lcsrc+1
        lda #<lbcl
        sta lcdst
        lda #>lbcl
        sta lcdst+1
        jsr lcopy
        lda gppl                ; its header
        sta p1
        lda gpph
        sta p1+1
        ldy #31
@h      jsr hget
        sta bhdr,y
        dey
        bpl @h
        lda fdev                ; its file
        sta bdev
        ldx #16
@n      lda fnlen,x
        sta bnlen,x
        dex
        bpl @n
        jsr gswap               ; the first's back, the second's kept
        jsr gclaims
        lda #<lmcl              ; the two apart?
        sta lov1
        lda #>lmcl
        sta lov1+1
        lda #<lbcl
        sta lov2
        lda #>lbcl
        sta lov2+1
        jsr lovl
        bcs @share
        inc bok
        ldx #<tx_then
        ldy #>tx_then
        jsr print
        ldx #0                  ; its parts
@p      stx t6
        lda bpal,x
        pha
        lda bpah,x
        tax
        pla
        jsr prhex4
        lda #' '
        jsr chrout
        ldx t6
        inx
        cpx bnp
        bcc @p
        lda #13
        jmp chrout
@share  ldx #<tx_bshare
        ldy #>tx_bshare
        jmp print
@back   jsr gswap
@x      rts
tx_then text "then a module, parts at ",0
tx_bshare text "the two modules share memory: the second",13
        text "loads while the first runs (petscii-lm",13
        text "writes a screen at $a000 for a chain)",13,0

; ------------------------------------------------------------
; chgame  prgame's chain: the second's claims beside the first's
; (lmcl), its effects for the tune (plsfx's), the switch's vectors
;   uses: a, x, y, p3, t0-t3
; ------------------------------------------------------------
chclaim lda chainon
        beq @x
        lda #<lbcl
        sta lcsrc
        lda #>lbcl
        sta lcsrc+1
        lda #<lmcl
        sta lcdst
        lda #>lmcl
        sta lcdst+1
        jmp lcopy
@x      rts

; chhead  the second's header: the song, and with a tune the music's
; fields as the first's (not +15: a picture's background), its share,
; its options (+28 bits 1, 3, as the first's would be), the tune playing
; on (bit 4) where it keeps that (its +27 bit 4); +26 is liveblk's
chhead  lda chainon
        beq @x
        lda #$ff
        ldx muse
        beq @s
        lda ma
@s      sta bhdr+13
        lda bshr
        sta bhdr+14
        lda muse
        beq @o
        ldx #8                  ; +16 to +24
@m      lda hdrmus,x
        sta bhdr+16,x
        dex
        bpl @m
@o      lda bbord
        and #$0c
        beq @b4
        lda bhdr+28
        and #$f5
        ora opt_gopt
        sta bhdr+28
@b4     lda muse
        beq @x
        lda bbord
        and #$10
        ora bhdr+28
        sta bhdr+28
@x      rts

; chvecs  the switch's vectors: the first's frame and stop, the second's
; init, frame and stop (cpst, the program's step: chprogs)
chvecs  ldx #3
@a      lda gentry+2,x
        sta pl_sw+swvec,x
        dex
        bpl @a
        ldx #5
@b      lda bentry,x
        sta pl_sw+swvec+4,x
        dex
        bpl @b
        rts

; ------------------------------------------------------------
; addchain  plan's: the second's blocks after the first's, in its
; file's order (bsrc 3: bpl/bph the place in its file), at the first's
; speed (bset 3: the module's set, the first's jitter and share), the
; last flagged f_chain; nchain
; ------------------------------------------------------------
addchain
        lda nblk
        sta cb0
        lda #0
        sta nchain
        sta nchain+1
        sta t6
@p      lda t6
        cmp bnp
        bcs @e
        tax
        lda bpal,x
        sta t0
        lda bpah,x
        sta t1
        lda bpll,x
        sta t2
        clc
        adc nchain
        sta nchain
        lda bplh,x
        sta t3
        adc nchain+1
        sta nchain+1
        lda bppl,x              ; (its place in the file: the pool's, less $d000)
        sta p1
        lda bpph,x
        sec
        sbc #>hpbase
        sta p1+1
        lda #3
        sta amsrc
        jsr addmem
        inc t6
        bne @p
@e      ldx cb0
@s      lda #3
        sta bset,x
        inx
        cpx nblk
        bcc @s
        lda #f_chain
        sta bfl-1,x
        rts

; ------------------------------------------------------------
; chprogs  after progs: the switch's step (the program's), then the
; second's blocks' progress and the core's step over its bytes less 512
; (full two pages before it is in: a counter at 000)
; ------------------------------------------------------------
chprogs lda chainon
        bne @go
        rts
@go     lda stepv
        sta pl_sw+swvec+10
        lda stepv+1
        sta pl_sw+swvec+11
        lda totlive             ; (kept)
        pha
        lda totlive+1
        pha
        lda nchain              ; max(256, nchain - 512)
        sec
        sbc #<512
        sta totlive
        lda nchain+1
        sbc #>512
        bcc @min
        cmp #1
        bcs @t
@min    lda #0
        sta totlive
        lda #1
@t      sta totlive+1
        lda #0
        sta done
        sta done+1
        ldx #0
@b      cpx nblk
        bcs @st
        lda bsrc,x
        cmp #3
        bne @n
        stx t7
        lda #0                  ; done * 256 / it
        sta n24
        lda done
        sta n24+1
        lda done+1
        sta n24+2
        lda #0
        sta n24+3
        jsr divtot
        ldx t7
        lda q24+1
        ora q24+2
        beq @q
        lda #255
        bne @p
@q      lda q24
@p      sta bprog,x
        lda done
        clc
        adc bll,x
        sta done
        lda done+1
        adc blh,x
        sta done+1
@n      inx
        bne @b
@st     jsr stepcal
        pla
        sta totlive+1
        pla
        sta totlive
@x      rts

; ------------------------------------------------------------
; readb  block blk's bytes from the second module's file (opened, or
; opened again for a block before where it is), to p1; its header's +13
; to +28 the tape's (bhdr); the file closed after its last block
;   out:  c set on a read error (said)
; ------------------------------------------------------------
readb   ldx blk
        lda bph,x               ; before where it is? from its start again
        cmp bpos+1
        bne @c
        lda bpl,x
        cmp bpos
@c      bcs @f
        jsr bclose
@f      lda bopen
        bne @o
        jsr bopenf
        bcc @o
        rts
@o      jsr clrchn
        ldx #5
        jsr chkin
@sk     ldx blk                 ; on to the block
        lda bpos
        cmp bpl,x
        bne @s
        lda bpos+1
        cmp bph,x
        beq @rd
@s      jsr rdb
        bcs @err
        jsr @inc
        jmp @sk
@rd     lda bll,x
        sta t2
        lda blh,x
        sta t3
@r      lda t2
        ora t3
        beq @ok
        jsr rdb
        bcs @err
        ldy #0
        sta (p1),y
        inc p1
        bne @1
        inc p1+1
@1      jsr @inc
        lda t2
        bne @2
        dec t3
@2      dec t2
        jmp @r
@ok     jsr clrchn
        ldx blk                 ; the main part's first block: the header
        lda bal,x
        cmp bpal
        bne @nh
        lda bah,x
        cmp bpah
        bne @nh
        ldx #15
@h      lda bhdr+13,x
        sta blkb+10+13,x
        dex
        bpl @h
@nh     ldx blk                 ; its last: closed
        lda bfl,x
        and #f_chain
        beq @k
        jsr bclose
@k      clc
        rts
@err    jsr clrchn
        jsr bclose
        ldx #<tx_short
        ldy #>tx_short
        jsr print
        sec
        rts
@inc    inc bpos
        bne @i
        inc bpos+1
@i      rts

; rdb  a byte from the current input: c set at an error (the end of the
; file is no error for its last byte)
rdb     jsr chrin
        pha
        jsr readst
        and #$bf
        bne @e
        pla
        clc
        rts
@e      pla
        sec
        rts

; bopenf  the second module's file open on channel 5, at its start
;   out:  c set on the drive's error (said)
bopenf  lda #5
        ldx bdev
        ldy #5
        jsr setlfs
        lda bnlen
        ldx #<bname
        ldy #>bname
        jsr setnam
        jsr open
        lda bdev
        jsr dstat
        bcs @bad
        lda #1
        sta bopen
        lda #0
        sta bpos
        sta bpos+1
        clc
        rts
@bad    lda #1
        sta bopen
        jsr bclose
        jsr prstat
        sec
        rts

; bclose  ... closed, if open
bclose  lda bopen
        beq @x
        lda #0
        sta bopen
        jsr clrchn
        lda #5
        jmp close
@x      rts
