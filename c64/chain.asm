; ------------------------------------------------------------
; chain.asm  -  SlopLoad 64's chains (slopload.py's -then): a second
; module after the first, chosen on line 4. The first shows while the
; second's parts load, the second while the program loads; the switch
; (src/chain.asm, pl_sw: its 12 bytes filled in here) is the first's
; last part. Only the second's header, its parts' places and its claims
; are kept: its bytes are read from its file again as the tape is
; written (getblk's source 3, readb), as the program's are, so the two
; needn't fit in the high pool together. Where the two would share
; memory one goes a VIC bank down (MODULES.md, "A module that moves";
; chfit): the first in the pool (gmove), the second as its blocks are
; read (rdbr), from its relocations kept after the first's file in the
; pool (blmove). tools/c64model.py (setup and plan with then=) is the
; reference.
; ------------------------------------------------------------

bok     = nhand+1               ; a second module chosen (the tape buffer's
                                ; spare bytes: setup.asm's)
stpg    = bok+1                 ; its parts below $c000 staged (chstg): pages, 0 none,
stat    = stpg+1                ; ... their first page, the page they load at, and
stto    = stat+1                ; (chstg's) one of them in the first's memory
sthit   = stto+1
blhi    = sthit+1               ; a moved second's relocations: 0 after the first's file
                                ; in the pool, 1 in blbuf (the first fills the pool)
blbuf   = $9e00                 ; ... blmax bytes, below $a000 (past the music pool)
blmax   = 512
                                ; (chmv: 1 the first goes a VIC bank down, 2 the
                                ; second; blok: its relocations in the pool, at
                                ; blst; rnext, rptr, rpart rdbr's: setup.asm's)
chainon byte 0                  ; ... and a chain on this tape (prepare: the show a module)
mlate   byte 0                  ; ... the tune starting with its second (opt_late, a chain)
bdev    byte 8
bnlen   byte 0                  ; its file's name
bname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
gblkn   = gorig+9-gnp           ; a module's fields, as ldgame leaves them
bsave   = $cfc2                 ; (past the KERNAL header; gblkn bytes)
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
brel    = bsave+grel-gnp
brln    = bsave+grln-gnp
                                ; (bhdr, its header, and lbcl, its claims:
                                ; setup.asm's lists)
nchain  = bsave+gblkn           ; its parts' bytes (after bsave, from $cfc2)
cb0     = nchain+2              ; its first block
bpos    = cb0+1                 ; its file, while written: the next byte's place
bopen   = bpos+2                ; ... open (channel 5)
kbord   = bopen+1               ; the +27 of the module that ends the load
gself   = kbord+1               ; (gclaims': one of its claims on another)

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
        sta chmv
@kp     rts
@rd     lda #0                  ; (a new second: the old one gone)
        sta bok
        sta chmv
        sta blok
        ldx #<tx_reading
        ldy #>tx_reading
        jsr print
        lda fdev                ; its file
        sta bdev
        ldx #16
@n      lda fnlen,x
        sta bnlen,x
        dex
        bpl @n
        lda hpool               ; (the first moved for a tape before: read
        cmp #2                  ; again, as it is)
        bne @f
        jsr hpread
        bcc @f
@x0     rts
@f      jsr gswap               ; (the first's fields aside)
        lda bdev
        ldx #<bnlen
        ldy #>bnlen
        jsr setfn
        jsr ldgame
        lda #0                  ; (the pool: not the first any more)
        sta hpool
        bcc @rk
        jmp @back
@rk     jsr gswap               ; the first's back, the second's kept
        jsr chfit               ; apart, or one a bank down?
        bcs @x0
        lda chmv
        cmp #2
        bne @hd
        jsr gswap               ; the second a bank down: in the pool, its
        jsr gmove               ; relocations after the first's file
        jsr gswap
        jsr blmove
@hd     lda bppl                ; its header (moved, if it moved)
        sta p1
        lda bpph
        sta p1+1
        ldy #31
@h      jsr hget
        sta bhdr,y
        dey
        bpl @h
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
        jsr chrout
        ldx #<tx_mv             ; (which moved)
        ldy #>tx_mv
        lda chmv
        beq @st
        cmp #1
        beq @pm
        ldx #<tx_mvi
        ldy #>tx_mvi
@pm     jsr print
        ldx #<tx_mv2
        ldy #>tx_mv2
        jsr print
@st     lda stpg                ; (its screen staged)
        beq @x
        ldx #<tx_stg
        ldy #>tx_stg
        jsr print
        lda #0
        ldx stto
        jsr prhex4
        ldx #<tx_stg2
        ldy #>tx_stg2
        jmp print
@back   jsr gswap
@x      rts
tx_then text "then a module, parts at ",0
tx_bshare text "the two modules share memory, even",13
        text "with one a vic bank lower",13,0

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
@o      lda bhdr+28             ; (bit 4 each tape's own: off first, a tape
        and #$ef                ; before in the session may have set it)
        sta bhdr+28
        lda bbord
        and #$2c
        beq @b4
        lda bhdr+28
        and #$d5
        ora opt_gopt
        sta bhdr+28
@b4     lda muse                ; (the tune playing on, unless it starts
        beq @x                  ; with this one: mlate)
        lda mlate
        bne @x
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
        ldx #$c0                ; the second's staged pages: none (as built),
        ldy #$c0                ; or from stto's page to stat's
        lda stpg
        sta pl_sw+swst
        beq @s
        ldx stto
        ldy stat
@s      stx pl_sw+swsrc
        sty pl_sw+swdst
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
        cpx #1                  ; (a part below $c000 staged, not the main
        bcc @n                  ; part: where it loads, stto - stat pages on)
        cmp #$c0
        bcs @n
        ldy stpg
        beq @n
        clc
        adc stto
        sec
        sbc stat
        sta t1
@n      lda bpll,x
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
@s      jsr rdbr
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
        jsr rdbr
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
        ldx #27                 ; (+4 to +31: a bank down, if it moved)
@h      lda bhdr+4,x
        sta blkb+10+4,x
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
        jsr rlnew               ; (its relocations from the start)
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

; ------------------------------------------------------------
; A module that moves (MODULES.md; tools/lmreloc.py)
; ------------------------------------------------------------

; chfit  the chain's two modules apart (tools/c64model.py's chain_fit):
; as they are, else the first a VIC bank down, else the second (its
; relocations after the first's file in the pool, under $fffa, or where
; that is full in blbuf, 512 bytes at most): chmv 0,
; 1 or 2, lbcl the second's claims as they will be. The first's fields
; at gnp, the second's in bsave, both as read
;   out:  c set if they can't be (said)
chfit   lda #0
        sta chmv
        sta stpg
        jsr bclaim              ; the second's claims, the first's: apart?
        jsr gclaims
        jsr chovl
        bcc @ok
        lda gbord               ; the first a bank down? (+27 bit 7: it moves)
        bpl @b
        lda grel+1
        beq @b
        inc gcmv
        jsr gclaims
        dec gcmv
        lda gself
        bne @b
        jsr chovl
        bcs @b
        inc chmv
@ok     clc
        rts
@b      lda bbord               ; the second? (its relocations' room)
        bpl @no
        lda brel+1
        beq @no
        lda #<hpmax
        sec
        sbc gflen
        tax
        lda #>hpmax
        sbc gflen+1
        tay
        txa
        sec
        sbc brln
        tya
        sbc brln+1
        lda #0                  ; (blhi 0: after the first's file in the pool)
        bcs @rm
        lda brln+1              ; no room there (a first that fills the pool:
        cmp #>blmax             ; a picture): blbuf, blmax bytes
        bcc @bf
        bne @no
        lda brln
        bne @no
@bf     lda #1
@rm     sta blhi
        inc gcmv
        jsr bclaim
        dec gcmv
        lda gself
        bne @no
        jsr gclaims
        jsr chovl
        bcs @no
        lda #2
        sta chmv
        clc
        rts
@no     jsr bclaim              ; last: the second's parts below $c000
        jsr gclaims             ; staged (chstg), the first as it is
        jsr chstg
        bcc @ok2
        lda gbord               ; ... or a bank down
        bpl @ref
        lda grel+1
        beq @ref
        jsr bclaim
        inc gcmv
        jsr gclaims
        dec gcmv
        lda gself
        bne @ref
        jsr chstg
        bcs @ref
        inc chmv
@ok2    clc
        rts
@ref    ldx #<tx_bshare
        ldy #>tx_bshare
        jmp prfail
tx_mv   text "the first ",0
tx_mvi  text "it ",0
tx_mv2  text "goes a vic bank lower",13,0
tx_stg  text "its screen waits at ",0
tx_stg2 text " till the switch",13,0

; bclaim  lbcl: the second's claims (gclaims')
bclaim  jsr gswap
        jsr gclaims
        jsr gswap
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
        jmp lcopy

; chovl  c set if the first's claims (lmcl) and the second's (lbcl) overlap
chovl   lda #<lmcl
        sta lov1
        lda #>lmcl
        sta lov1+1
        lda #<lbcl
        sta lov2
        lda #>lbcl
        sta lov2+1
        jmp lovl

; ------------------------------------------------------------
; gmove  the module in the high pool a VIC bank down: each byte its
; relocations list $40 lower, each bank byte one higher, each part at
; $c000 or above $4000 lower (its part header in the file); its fields
; parsed again (gparse, gmvd 1)
;   out:  c set if it can't be (said)
;   uses: a, x, y, p1, p3, t0-t7
; ------------------------------------------------------------
gmove   lda grel
        sta p3
        lda grel+1
        sta p3+1
        lda #0
        sta t6                  ; the part
@pt     ldx t6
        cpx gnp
        bcs @bk
        lda gppl,x              ; p1: its part header, 4 before its bytes
        sec
        sbc #4
        sta p1
        lda gpph,x
        sbc #0
        sta p1+1
        lda gpah,x              ; its address: $4000 lower at $c000 on
        cmp #$c0
        bcc @k
        sbc #$40
        ldy #1
        jsr hput
@k      lda p1                  ; t4/t5: its first byte, less one
        clc
        adc #3
        sta t4
        lda p1+1
        adc #0
        sta t5
@g      jsr rget3               ; each gap: to the next byte to move
        beq @np
        cmp #255
        bne @mv
        lda #254
        jsr @adv
        jmp @g
@mv     jsr @adv
        lda t4
        sta p1
        lda t5
        sta p1+1
        ldy #0
        jsr hget
        sec
        sbc #$40
        jsr hput
        jmp @g
@np     inc t6
        bne @pt
@bk     jsr rget3               ; the bank bytes: n, then their places
        sta t7
        lda gppl
        sta p1
        lda gpph
        sta p1+1
@b      lda t7
        beq @x
        jsr rget3
        tay
        jsr hget
        clc
        adc #1
        jsr hput
        dec t7
        jmp @b
@x      lda #1
        sta gmvd
        jmp gparse
@adv    clc
        adc t4
        sta t4
        bcc @a
        inc t5
@a      rts

; rget3  the byte at p3 in the high pool, p3 on one: a (its flags)
;   uses: a, x, y
rget3   php
        sei
        lda #$34
        sta $01
        ldy #0
        lda (p3),y
        tax
        lda #$36
        sta $01
        plp
        inc p3
        bne @x
        inc p3+1
@x      txa
        rts

; blmove  the second's relocations, its file read into the pool (brel,
; brln), to after the first's file (blst: hpbase + gflen), by way of
; $a000; blok 1
blmove  lda #<$a000
        sta p1
        lda #>$a000
        sta p1+1
        lda brel
        sta p2
        lda brel+1
        sta p2+1
        jsr @cp
        lda gflen
        clc
        adc #<hpbase
        sta blst
        sta p1
        lda gflen+1
        adc #>hpbase
        sta blst+1
        sta p1+1
        lda blhi                ; (or blbuf: chfit's)
        beq @pl
        lda #<blbuf
        sta blst
        sta p1
        lda #>blbuf
        sta blst+1
        sta p1+1
@pl     lda #<$a000
        sta p2
        lda #>$a000
        sta p2+1
        lda #1
        sta blok
@cp     lda brln
        sta t2
        lda brln+1
        sta t3
        php
        sei
        lda #$34
        sta $01
        jsr copyn
        lda #$36
        sta $01
        plp
        clc
        rts

; blread  ... the second's file read into the pool again for them
;   out:  c set on an error (said)
blread  lda bdev
        ldx #<bnlen
        ldy #>bnlen
        jsr setfn
        jsr tohigh
        bcs @x
        lda #0
        sta hpool
        jmp blmove
@x      rts

; rlnew  the second's relocations from its start (its file opened):
; rnext the place in its file of the first byte to move ($ffff: none)
rlnew   lda #$ff
        sta rnext
        sta rnext+1
        lda chmv
        cmp #2
        bne @x
        lda blst
        sta rptr
        lda blst+1
        sta rptr+1
        lda #0
        sta rpart
        jsr rlpart
        jmp rlnxt
@x      rts

; rlpart  rnext: part rpart's first byte's place in its file, less one
rlpart  ldx rpart
        lda bppl,x
        sec
        sbc #1
        sta rnext
        lda bpph,x
        sbc #>hpbase
        sta rnext+1
        rts

; rlnxt  rnext on to the next byte to move (the list's next gap; the
; next part's at a 0; $ffff after the last)
;   uses: a, x, y, p3
rlnxt   lda rptr
        sta p3
        lda rptr+1
        sta p3+1
        jsr rget3
        pha
        lda p3
        sta rptr
        lda p3+1
        sta rptr+1
        pla
        beq @np
        cmp #255
        bne @g
        lda #254
        jsr @g
        jmp rlnxt
@g      clc
        adc rnext
        sta rnext
        bcc @x
        inc rnext+1
@x      rts
@np     inc rpart
        lda rpart
        cmp bnp
        bcs @e
        jsr rlpart
        jmp rlnxt
@e      lda #$ff
        sta rnext
        sta rnext+1
        rts

; rdbr  rdb, the byte $40 lower where the second's relocations say
; (bpos: its place in the file)
rdbr    jsr rdb
        bcs @x
        ldx bpos
        cpx rnext
        bne @k
        ldx bpos+1
        cpx rnext+1
        bne @k
        pha
        jsr rlnxt
        pla
        sec
        sbc #$40
@k      clc
@x      rts

; ------------------------------------------------------------
; chstg  the second's parts below $c000 (not its main part: a screen for
; the C64's font, a font of its own) staged, if only they are in the
; first's memory (lmcl; the second's claims in lbcl, its parts' order):
; their span, whole pages stat to stat+stpg, loads at the highest free
; page, stto, while the first shows, and the switch copies it to its
; place (src/chain.asm; slopload.py's chain_stage). lbcl is then its
; other parts', the span's and stto's
;   out:  c set if not (stpg 0)
;   uses: a, x, y, p3, t0-t3, t6, t7, lban (free here)
; ------------------------------------------------------------
chstg   lda #0                  ; the second's claims aside, in lban
        sta lban
        lda #<lbcl
        sta lcsrc
        lda #>lbcl
        sta lcsrc+1
        lda #<lban
        sta lcdst
        lda #>lban
        sta lcdst+1
        jsr lcopy
        lda #0
        sta lbcl
        sta sthit
        sta stpg                ; (the span's end page, then its pages)
        lda #$ff
        sta stat                ; (its first page)
        ldx #0
@e      cpx lban
        bcs @sp
        stx t6
        lda #<lban
        ldy #>lban
        jsr lget
        lda #<lmcl              ; in the first's memory? (t7 1)
        ldy #>lmcl
        jsr rovl
        lda #0
        rol a
        sta t7
        ldx t6
        beq @kp                 ; (the main part: never staged)
        lda t1
        cmp #$c0
        bcc @s1                 ; a part below $c000: in the span
@kp     lda t7                  ; (a part that can't be staged, in it: no)
        beq @k2
        jmp @no
@k2     lda #<lbcl
        ldy #>lbcl
        jsr ladd
        jmp @nx
@s1     lda t7
        ora sthit
        sta sthit
        lda t1
        cmp stat
        bcs @s2
        sta stat
@s2     lda t2                  ; (its end: the page, one more if any of it)
        cmp #1
        lda t3
        adc #0
        cmp stpg
        bcc @nx
        sta stpg
@nx     ldx t6
        inx
        bne @e
@sp     lda sthit
        beq @no
        lda #0                  ; the span: the second's
        sta t0
        sta t2
        lda stat
        sta t1
        lda stpg
        sta t3
        lda #<lbcl
        ldy #>lbcl
        jsr ladd
        lda stpg                ; its pages
        sec
        sbc stat
        sta stpg
        eor #$ff                ; the first place tried: $ff - pages
        sta stto
@f      lda stto                ; [stto, stto + pages) clear of the first,
        cmp #8                  ; the second, the loader and the I/O?
        bcc @no
        sta t1
        clc
        adc stpg
        sta t3
        lda #0
        sta t0
        sta t2
        lda #<lmcl
        ldy #>lmcl
        jsr rovl
        bcs @dn
        lda #<lbcl
        ldy #>lbcl
        jsr rovl
        bcs @dn
        lda #<lbusy
        ldy #>lbusy
        jsr rovl
        bcc @ok
@dn     dec stto
        jmp @f
@ok     lda #<lbcl              ; its staging place: the second's
        ldy #>lbcl
        jsr ladd
        clc
        rts
@no     lda #0
        sta stpg
        sec
        rts
