; ------------------------------------------------------------
; sidread.asm  -  a .sid made ready for SlopLoad 64: for SID-SLM. Moved
; out of SlopLoad 64 (setup.asm), which now takes the .slm SID-SLM writes.
;   ldsid    a PSID file at stage (flen bytes, the stage's first ones when
;            it's longer): its header checked, the
;            song (asked if it has several), its bytes to the music pool,
;            the trial run (trial.asm), its play rate; mok 1, or 2 when
;            refused (said by mrefuse)
;   trysid   the trial run, then sidrate
;   sidrate  mppal, mpntsc from the header's speed bit and clock, and the
;            CIA latch the tune set; mcia 1 when CIA timed
; The includer: the variables (mload ... mspd, mcia, mtitle, mok, mcut,
; mdat, mcalls), stage, flen, mpool, npool, trcalls, mrefuse and the
; reasons (r_*), mtoolong (over 4096 bytes: mcut, or refused), cutsid
; (the song cut, then trysid), asc2pet, tomusp, asknum, scrat's screen
; ($0288), cpu, fast, slow (machine.asm), mul16, divn (math.asm),
; trial.asm and sidcut.asm.
; ------------------------------------------------------------

; ------------------------------------------------------------
; ldsid  a PSID file at stage: its header, the song, its bytes to the
; music pool, then the trial run (trial.asm) and its play rate
; ------------------------------------------------------------
ldsid   lda #0
        sta mwhya
        sta mwhya+1
        sta mcut
        lda stage+13            ; play (big-endian): 0, no play routine
        ora stage+12
        bne @pl
        lda #r_noplay
        jmp mrefuse
@pl     lda stage+5             ; version 3 and 4: a second, third SID
        cmp #3
        bcc @v
        lda stage+$7a
        ora stage+$7b
        beq @v
        lda #r_sids
        jmp mrefuse
@v      lda stage+15            ; songs (1 at least)
        bne @sn
        lda #1
@sn     sta msongs
        lda stage+14
        beq @s1
        lda #255
        sta msongs
@s1     lda stage+17            ; the start song (1 if it isn't one)
        beq @st1
        cmp msongs
        beq @st
        bcc @st
@st1    lda #1
@st     sta msong
        lda #1
        sta mkind
        lda stage+6             ; the data: its offset (big-endian): $76
        beq @off                ; or $7c, so a high byte is a damaged file
        jmp @bad                ; (and past $ffff in the stage)
@off    lda stage+7
        clc
        adc #<stage
        sta p2
        lda stage+6
        adc #>stage
        sta p2+1
        lda stage+9             ; its load address (0: the data's first two bytes)
        sta mload
        lda stage+8
        sta mload+1
        ora mload
        bne @la
        ldy #0
        lda (p2),y
        sta mload
        iny
        lda (p2),y
        sta mload+1
        lda p2
        clc
        adc #2
        sta p2
        bcc @la
        inc p2+1
@la     lda stage+11            ; init (0: the load address), play
        sta minit
        lda stage+10
        sta minit+1
        ora minit
        bne @in
        lda mload
        sta minit
        lda mload+1
        sta minit+1
@in     lda stage+13
        sta mplay
        lda stage+12
        sta mplay+1
        lda p2                  ; its length: the file's, less the data's
        sec                     ; place in it (p2 - stage)
        sbc #<stage
        sta t0
        lda p2+1
        sbc #>stage
        sta t1
        lda flen
        sec
        sbc t0
        sta mlen
        lda flen+1
        sbc t1
        sta mlen+1
        bcc @bad
        ora mlen
        beq @bad
        jsr mtoolong
        bcc @len
        clc                     ; (refused, not an error: mok 2)
        rts
@len    ldx #0                  ; its name (shown in the menu)
@nm     lda stage+$16,x
        jsr asc2pet
        sta mtitle,x
        inx
        cpx #32
        bcc @nm
        lda p2                  ; (where its bytes are in the file)
        sta mdat
        lda p2+1
        sta mdat+1
        lda mcut                ; its bytes to the music pool (cut: later)
        bne @song
        jsr tomusp
@song   lda msongs              ; the song
        cmp #2
        bcc @one
        jsr asksong
@one    lda msong
        sec
        sbc #1
        sta ma
        lda stage+5             ; the header's version, flags, speed bits:
        sta mver                ; kept (the trial's scratch is where the
        lda stage+$77           ; file was)
        sta mflg
        ldx #3
@sp     lda stage+18,x
        sta mspd,x
        dex
        bpl @sp
        lda mcut                ; over 4096 bytes: its song cut down first
        beq @try
        jmp cutsid
@try    lda #<trcalls
        sta mcalls
        lda #>trcalls
        sta mcalls+1
        jmp trysid
@bad    lda #r_notmus
        jmp mrefuse

; asksong  msong from 1-msongs (the start song by default)
asksong ldx #<q_song
        ldy #>q_song
        jsr print
        lda msongs
        ldx #0
        jsr prdec16
        lda msong
        ldx #<q_song2
        ldy #>q_song2
        jsr asknum
        bcs asksong
        cmp #1
        bcc asksong
        cmp msongs
        beq @ok
        bcs asksong
@ok     sta msong
        rts
q_song  text "it has songs 1-",0
q_song2 text ". which one [",0

; ------------------------------------------------------------
; trysid  the trial run of the tune in the music pool (trial.asm's
; tstrip: what it touches, its stores the loader can't allow taken out)
; over mcalls play calls, then its play rate from the header's speed bit
; and clock; a cut tune (mcut) must play as the whole one did (ct_sum)
; ------------------------------------------------------------
trysid  lda mload
        sta tr_load
        sta tr_src
        lda mload+1
        sta tr_load+1
        lda #>mpool
        sta tr_src+1
        lda mlen
        sta tr_len
        lda mlen+1
        sta tr_len+1
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
        lda mcalls
        sta tr_calls
        lda mcalls+1
        sta tr_calls+1
        lda #<npool             ; (the pool: npool's pages)
        sta tr_pool
        lda #>npool
        sta tr_pool+1
        lda #1                  ; (run/stop stops it)
        sta tr_stop
        ldx #<tx_trial
        ldy #>tx_trial
        jsr trcount
        jsr tstrip
        jsr slow
        lda #13
        jsr chrout
        lda mcut                ; cut: the same SID writes as the whole
        beq @te                 ; tune's, or it can't be cut (stopped: said
        lda tr_err              ; so)
        cmp #16
        beq @te
        ldx #3
@cs     lda tr1s,x
        cmp ct_sum,x
        bne @cd
        dex
        bpl @cs
@te     lda tr_err
        beq @ok
        clc                     ; refused: 20 + its number
        adc #r_trial
        pha
        lda tr_erra
        sta mwhya
        lda tr_erra+1
        sta mwhya+1
        pla
        jmp mrefuse
@ok     ldx #31                 ; what it uses
@z      lda tr_zp,x
        sta mzp,x
        dex
        bpl @z
        lda tr_nws
        sta mnws
        asl a
        asl a
        tax
        beq @c
@w      lda tr_ws-1,x
        sta mws-1,x
        dex
        bne @w
@c      lda tr_cyc
        sta mcyc
        lda tr_cyc+1
        sta mcyc+1
        jsr sidrate
        bcc @fine
        rts
@fine   lda #1
        sta mok
        clc
        rts
@cd     lda #r_cutdiff
        jmp mrefuse
tx_trial text "trying it: ",0
tx_trial2 text "      of ",0
tx_trial3 text " play calls",0

; trcount  the text at x/y, then the play calls counted (tr_scr: where
; the count goes), "of tr_calls play calls"; then fast (a C128: 1 MHz,
; its 2 MHz needs the raster interrupts, which the trial turns off)
trcount jsr print
        sec                     ; its progress: where the cursor is
        jsr plot
        stx t0                  ; (row x, column y)
        sty t1
        jsr scrat
        sta tr_scr
        stx tr_scr+1
        ldx #<tx_trial2
        ldy #>tx_trial2
        jsr print
        lda tr_calls
        ldx tr_calls+1
        jsr prdec16
        ldx #<tx_trial3
        ldy #>tx_trial3
        jsr print
        lda cpu
        cmp #1
        beq @c128
        jmp fast
@c128   rts

; scrat  a/x: the screen address of row t0, column t1
scrat   lda #0
        sta t2
        lda t0                  ; row x 40
        asl a
        asl a
        adc t0                  ; x 5
        asl a
        rol t2
        asl a
        rol t2
        asl a
        rol t2                  ; x 40
        clc
        adc t1
        pha
        lda t2
        adc $0288               ; the screen's page
        tax
        pla
        rts

; ------------------------------------------------------------
; sidrate  mppal, mpntsc: the time between play calls (1/64 lines), from
; the PSID header (the song's speed bit: CIA timed; its clock: NTSC or
; not) and the CIA latch the tune set (tr_latch; none: $4025), in
; integers (tests/sidslm.py has the same rule)
;   out:  c set if refused (said)
; ------------------------------------------------------------
sidrate lda #0                  ; ntsc: the header's clock is NTSC only
        sta t6
        sta mcia
        lda mver
        cmp #2
        bcc @cl
        lda mflg
        lsr a
        lsr a
        and #3
        cmp #2
        bne @cl
        inc t6
@cl     lda msong               ; the speed bit: bit min(song - 1, 31)
        sec
        sbc #1
        cmp #32
        bcc @b
        lda #31
@b      pha
        lsr a
        lsr a
        lsr a
        eor #3                  ; byte 21 - (bit / 8): 18 + (3 - bit / 8)
        tax
        pla
        and #7
        tay
        lda mspd,x
@sh     dey
        bmi @tst
        lsr a
        jmp @sh
@tst    and #1
        bne @cia
        lda t6                  ; once a frame
        bne @nf
        lda #<19968
        ldx #>19968
        ldy #<20090
        sty mpntsc
        ldy #>20090
        jmp @set
@nf     lda #<16730
        ldx #>16730
        ldy #<16832
        sty mpntsc
        ldy #>16832
@set    sty mpntsc+1
        sta mppal
        stx mppal+1
        clc
        rts
@cia    lda #1                  ; (CIA timed: the .slm's flag 4)
        sta mcia
        lda tr_latch            ; l1 = latch + 1 (65535 at most)
        ora tr_latch+1
        bne @l
        lda #<$4025
        sta tr_latch
        lda #>$4025
        sta tr_latch+1
@l      lda tr_latch
        clc
        adc #1
        sta t4
        lda tr_latch+1
        adc #0
        sta t5
        bcc @l1
        lda #$ff
        sta t4
        sta t5
@l1     lda t6
        bne @ncia
        jsr l64d63              ; a PAL tune: pal = (l1 x 64 + 31) / 63
        bcs @slow
        sta mppal
        stx mppal+1
        lda #<1446              ; ntsc = l1 + (l1 x 1446 + 32768) >> 16
        jsr lfrac
        clc
        adc t4
        sta mpntsc
        txa
        adc t5
        sta mpntsc+1
        bcs @slow
        bcc @chk
@ncia   jsr l64d65              ; an NTSC tune: ntsc = (l1 x 64 + 32) / 65
        sta mpntsc
        stx mpntsc+1
        lda #<1399              ; pal = l1 - (l1 x 1399 + 32768) >> 16
        jsr lfrac
        sta t0
        lda t4
        sec
        sbc t0
        sta mppal
        lda t5
        stx t0
        sbc t0
        sta mppal+1
@chk    lda mppal               ; more than 8 times a frame?
        cmp #<2496
        lda mppal+1
        sbc #>2496
        bcs @ok
        lda #r_fast
        jsr mrefuse             ; (c set: trysid takes a clear carry as fine,
        sec                     ; and the refused tune was written)
        rts
@ok     clc
        rts
@slow   lda #r_slow
        jsr mrefuse
        sec
        rts

; lfrac  a/x: (t4/t5 x a/(1446 or 1399, the high byte 5) + 32768) >> 16
lfrac   sta m32a
        lda #5
        sta m32a+1
        lda t4
        sta m32b
        lda t5
        sta m32b+1
        jsr mul16
        lda m32r+1              ; + 32768
        clc
        adc #$80
        lda m32r+2
        adc #0
        pha
        lda m32r+3
        adc #0
        tax
        pla
        rts

; l64d63 / l64d65  a/x: (t4/t5 x 64 + 31) / 63, (... + 32) / 65; c set
; past 16 bits
l64d63  lda #31
        ldx #63
        bne l64d
l64d65  lda #32
        ldx #65
l64d    stx dvs
        ldx #0
        stx dvs+1
        clc
        adc #0
        sta n24                 ; (round) + l1 x 64
        lda #0
        sta n24+1
        sta n24+2
        sta n24+3
        lda t4
        sta t0
        lda t5
        sta t1
        lda #0
        sta t2
        ldx #6
@s      asl t0
        rol t1
        rol t2
        dex
        bne @s
        lda n24
        clc
        adc t0
        sta n24
        lda t1
        adc #0
        sta n24+1
        lda t2
        adc #0
        sta n24+2
        jsr divn
        lda q24+2
        ora q24+3
        cmp #1                  ; (c set: past 16 bits)
        lda q24
        ldx q24+1
        rts

