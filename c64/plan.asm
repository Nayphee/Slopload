; ------------------------------------------------------------
; plan.asm  -  SlopLoad 64's blocks: the game's parts, the program's
; parts that load while it runs and those after (in its memory), the
; core patched, the KERNAL file, each block made ready to write
; ------------------------------------------------------------

; ---- options and state ----
opt_show byte 0                 ; 0 nothing, 1 a module, 4 music (shset: from
                                ; the module and the tune chosen)
opt_speed byte spneg           ; the speed + spneg (-12 to 13: payload.asm's tables)
opt_start word 0                ; 0: RUN, else the address to jump to
opt_out byte 0                  ; 0 the cassette, 1 a .tap file
opt_pal byte 0                  ; the colours (line 6): a style, 0 rainbow to
                                ; st_black, or npal-1 your own (ownl)
opt_eff byte 0                  ; the effect (line 7): 0 standard, 1 to nfxs one
                                ; of slopload.py's FX, neff-1 a colour a block
ownl    byte 2,6,14,0,0,0,0,0,0,0,0,0,0 ; your own colours: how many, then they
opt_lines byte 0                ; the loading lines (ui's lnset, from opt_pal and
                                ; opt_eff): 0 rainbow (the core as
                                ; it is), 1 to st_black - 1 a style (core_stripes),
                                ; st_black, st_block, st_one: no stripes (core_flat),
                                ; st_fx an effect (core_fx: opt_fx), st_own
                                ; your own colours (core_stripes, ownl)
opt_fcol byte 6                 ; st_one's colour
opt_fx  byte 0                  ; st_fx's effect: slopload.py's FX, in order (classic,
                                ; thin, mixed, and, ora, eor)
opt_fxn byte 5                  ; ... its value (and, ora, eor: 0-15)
opt_fxb byte 0                  ; ... the border's colour it starts from
opt_showl byte 0                ; 1: the lines on through the module or show
                                ; (the pc's -showstripes)
opt_cyc byte 0                  ; 1: the border a colour on each page (-cycle: an
                                ; effect, or black or one colour as the plain one)
opt_gopt byte 0                 ; a module's header +28: bit 1 SPACE alone at the end
                                ; (-wait), bit 3 the blocks counted down (-countdown);
                                ; asked only when the module keeps them (+27 bits 2, 3)
prgdev  byte 8
tapdev  byte 8
prglen  byte 0                  ; the program's file name
prgname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tnlen   byte 0                  ; the name on tape
tname   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tapfnl  byte 0                  ; the .tap file's name (and ",p,w")
tapfname byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
inlen   byte 0
inbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
dsbuf   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
paddr   word 0                  ; the program: load address, length, end
plen    word 0
pend    word 0
eof     byte 0
rdpos   word 0                  ; the address of the next byte read from it
nblk    byte 0
tapn    byte 0,0,0              ; pulses on the whole tape
totlive word 0
done    word 0
npt     byte 0                  ; boundary points (2 + 2 x maxclaim)
ptl     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
pth     byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; ------------------------------------------------------------
; plan  the blocks, in tape order (bal.. arrays, nblk)
;   out:  c set if there are too many (said)
; ------------------------------------------------------------
plan    lda opt_cyc             ; the cycle with a module or show: only with
        beq @cy                 ; the lines on through it (the border is
        jsr fxon                ; theirs otherwise)
        bcc @cy
        lda modon
        beq @cy
        jsr showl
        bcs @cy
        ldx #<tx_cycshow
        ldy #>tx_cycshow
        jsr print
        sec
        rts
@cy     lda #0
        sta nblk
        sta t6                  ; the module's parts (prepare's), in order
@mp     lda t6
        cmp npart
        bcs @me
        tax
        lda ptal,x
        sta t0
        lda ptah,x
        sta t1
        lda ptll,x
        sta t2
        lda ptlh,x
        sta t3
        lda ptpl,x
        sta p1
        lda ptph,x
        sta p1+1
        lda ptio,x              ; (colour ram: memory, written with i/o in)
        asl a
        sta amsrc
        jsr addmem
        inc t6
        bne @mp
@me     lda npart               ; its last block: the module is in
        beq @prog
        ldx nblk
        lda #f_gameready
        sta bfl-1,x
        lda chainon             ; a chain: the second module's blocks
        beq @prog
        jsr addchain
@prog   jsr bounds              ; the program between the claims' bounds
        lda #0
        sta totlive
        sta totlive+1
        lda #0
        jsr addparts            ; what loads while the game runs
        bcs @x
        lda chainon             ; a chain with none of the program while the
        beq @cn                 ; second runs: refused
        lda totlive
        ora totlive+1
        bne @cn
        ldx #<tx_bnone
        ldy #>tx_bnone
        jsr print
        sec
        rts
@cn     lda nblk
        sta t7                  ; (the first block after them)
        lda #1
        jsr addparts            ; what loads after it
        bcs @x
        ldx nblk                ; flags at the ends
        cpx t7
        beq @nolater
        ldx nblk
        lda bfl-1,x             ; the last of all
        ora #f_last
        sta bfl-1,x
        ldx t7
        lda bset,x
        ora #$40                ; the first after the game: the long pilot
        sta bset,x
        lda #0
        beq @ml
@nolater
        lda #f_last
@ml     ora #f_mainend          ; the last that loads while it runs
        ldx t7
        ora bfl-1,x
        sta bfl-1,x
        jsr progs               ; progress and the core's step
        jsr chprogs             ; (a chain: the second's, the switch's step)
        jsr liveblk
        jsr underio
        clc
@x      rts

tx_cycshow text "the border cycle needs the bars during",13,"the module or music (8: y)",13,0
tx_bnone text "the program loads where the modules are:",13,"the second would show for no time",13,0

; liveblk  a game's header +26: the disk blocks its counter counts down,
; those that load while it runs (all the program's, unless some of it
; loads into the game's memory after it)
;   uses: a, x, y, p1
liveblk lda opt_show
        cmp #1
        bne @x
        lda totlive
        ldx totlive+1
        jsr nblocks
        ldy chainon             ; a chain: the second counts the program's,
        beq @h                  ; the first the second's
        sta bhdr+26
        lda nchain
        ldx nchain+1
        jsr nblocks
@h      ldy gppl                ; (the header: the main part's start)
        sty p1
        ldy gpph
        sty p1+1
        ldy #26
        jmp hput
@x      rts

; underio  f_underio for every block storing into $d000-$dfff (the core
; banks the i/o out for it)
underio ldx #0
@b      cpx nblk
        bcs @x
        lda bsrc,x              ; (colour ram: no)
        cmp #2
        beq @n
        lda bah,x               ; starts below $e000
        cmp #$e0
        bcs @n
        lda bal,x               ; and ends past $d000
        clc
        adc bll,x
        sta t0
        lda bah,x
        adc blh,x
        bcs @y                  ; (to $10000)
        cmp #$d0
        bcc @n
        bne @y
        lda t0
        beq @n
@y      lda bfl,x
        ora #f_underio
        sta bfl,x
@n      inx
        bne @b
@x      rts

; addmem  blocks of the module's part: t0/t1 address, t2/t3 length,
; from p1 (amsrc: 0, or 2 for colour ram: written with the i/o in)
addmem  lda t2
        ora t3
        beq @x
        ldx nblk
        lda t0
        sta bal,x
        lda t1
        sta bah,x
        lda p1
        sta bpl,x
        lda p1+1
        sta bph,x
        lda amsrc
        sta bsrc,x
        lda #0
        sta bfl,x
        sta bset,x
        sta bprog,x
        lda t3                  ; 4096 at most
        cmp #$10
        bcc @all
        lda #0
        sta bll,x
        lda #$10
        sta blh,x
        bne @nx
@all    lda t2
        sta bll,x
        lda t3
        sta blh,x
@nx     inc nblk
        lda t0                  ; on by what this block took
        clc
        adc bll,x
        sta t0
        lda t1
        adc blh,x
        sta t1
        lda p1
        clc
        adc bll,x
        sta p1
        lda p1+1
        adc blh,x
        sta p1+1
        lda t2
        sec
        sbc bll,x
        sta t2
        lda t3
        sbc blh,x
        sta t3
        jmp addmem
@x      rts
amsrc   byte 0

; bounds  the points between paddr and pend where a claim starts or ends,
; sorted, both ends included
bounds  lda #0
        sta npt
        lda paddr
        ldx paddr+1
        jsr addpt
        lda pend
        ldx pend+1
        jsr addpt
        lda #0
        sta t5
@c      lda t5
        cmp lclaim
        bcs @s
        tax
        lda #<lclaim
        ldy #>lclaim
        jsr lget
        lda t2
        sta t4
        lda t3
        pha
        lda t0
        ldx t1
        jsr addptin
        pla
        tax
        lda t4
        jsr addptin
        inc t5
        bne @c
@s      lda #0                  ; sorted (bubble: 50 at most)
        sta t6
        ldx #0
@i      inx
        cpx npt
        bcs @e
        lda ptl,x               ; pt x-1 > pt x: swap
        cmp ptl-1,x
        lda pth,x
        sbc pth-1,x
        bcs @i
        lda ptl,x
        ldy ptl-1,x
        sta ptl-1,x
        tya
        sta ptl,x
        lda pth,x
        ldy pth-1,x
        sta pth-1,x
        tya
        sta pth,x
        inc t6
        bne @i
@e      lda t6
        bne @s
        rts

; addptin  the point a/x if strictly between paddr and pend
addptin sta t2
        stx t3
        lda paddr               ; paddr < point
        cmp t2
        lda paddr+1
        sbc t3
        bcs @x
        lda t2                  ; point < pend
        cmp pend
        lda t3
        sbc pend+1
        bcs @x
        lda t2
        ldx t3
        jmp addpt
@x      rts
addpt   sty t6
        ldy npt
        sta ptl,y
        txa
        sta pth,y
        inc npt
        ldy t6
        rts

; inclaim  c set if the address a/x is in a claim (a range of a byte
; against lclaim)
;   uses: a, y, t0-t3, p3
inclaim sta t0
        stx t1
        clc
        adc #1
        sta t2
        txa
        adc #0
        sta t3
        lda #<lclaim
        ldy #>lclaim
        jmp rovl

; addparts  the program's segments between points that are in a claim
; (a = 1) or not (a = 0), as blocks of 4096 at most (from the disk);
; c set if there are too many
addparts
        sta t4
        ldx #0
@s      stx t5
        inx
        cpx npt
        bcc @bf0
        jmp @ok
@bf0
        dex
        lda ptl,x               ; the segment [pt x, pt x+1)
        sta p2
        lda pth,x
        sta p2+1
        lda p2
        ldx p2+1
        jsr inclaim
        lda #0
        rol a
        cmp t4
        beq @bq0
        jmp @next
@bq0
        ldx t5
        lda ptl+1,x
        sta p3
        lda pth+1,x
        sta p3+1
@b      lda p2                  ; blocks of it
        cmp p3
        lda p2+1
        sbc p3+1
        bcs @next
        ldx nblk
        cpx #maxblk
        bcs @many
        lda p2
        sta bal,x
        lda p2+1
        sta bah,x
        lda p3                  ; length: the rest, 4096 at most
        sec
        sbc p2
        sta t0
        lda p3+1
        sbc p2+1
        cmp #$10
        bcc @l
        lda #0
        sta t0
        lda #$10
@l      sta blh,x
        lda t0
        sta bll,x
        lda #1
        sta bsrc,x
        lda #0
        sta bfl,x
        sta bprog,x
        lda t4                  ; the module's set while it runs, else boot
        eor #1
        ldy modon
        bne @st
        lda #0
@st     sta bset,x
        lda t4
        bne @nt
        lda totlive             ; (what loads while it runs: its total)
        clc
        adc bll,x
        sta totlive
        lda totlive+1
        adc blh,x
        sta totlive+1
@nt     lda p2
        clc
        adc bll,x
        sta p2
        lda p2+1
        adc blh,x
        sta p2+1
        inc nblk
        jmp @b
@next   ldx t5
        inx
        jmp @s
@ok     clc
        rts
@many   ldx #<tx_many
        ldy #>tx_many
        jsr print
        sec
        rts

; progs  each live block's progress (256 x done / total) and the core's
; step (2^24 / total, rounded; 65535 at most)
progs   lda #0
        sta done
        sta done+1
        ldx #0
@b      cpx nblk
        bcs stepcal
        lda bsrc,x
        cmp #1
        bne @n                  ; the module's own: 0
        lda modon
        beq @live
        lda bset,x
        and #1
        beq @after              ; the boot set with a game: after it
@live   stx t7
        lda #0                  ; done * 256 / total
        sta n24
        lda done
        sta n24+1
        lda done+1
        sta n24+2
        lda #0
        sta n24+3
        jsr divtot
        ldx t7
        lda q24
        sta bprog,x
        lda done
        clc
        adc bll,x
        sta done
        lda done+1
        adc blh,x
        sta done+1
        jmp @n
@after  lda #255
        sta bprog,x
@n      inx
        bne @b
; stepcal  stepv: 2^24 / totlive, rounded; 65535 at most
stepcal lda #0                  ; 2^24 / total
        sta n24
        sta n24+1
        sta n24+2
        lda #1
        sta n24+3
        jsr divtot
        lda rem                 ; rounded: + 1 if 2 x remainder >= total
        asl a
        sta t0
        lda rem+1
        rol a
        sta t1
        bcs @up
        lda t0
        cmp totlive
        lda t1
        sbc totlive+1
        bcc @nr
@up     inc q24
        bne @nr
        inc q24+1
        bne @nr
        inc q24+2
@nr     lda q24+2
        ora q24+3
        beq @fit
        lda #$ff
        sta q24
        sta q24+1
@fit    lda q24
        sta stepv
        lda q24+1
        sta stepv+1
        rts
stepv   word 0

; divtot  q24 (4 bytes) = n24 (4 bytes) / totlive, remainder in rem
; (divn, ... / dvs: math.asm)
divtot  lda totlive
        sta dvs
        lda totlive+1
        sta dvs+1
        jmp divn

; ------------------------------------------------------------
; mkcore  the core at coreb (copied there at the start: corecp), patched
; in place, every field written each time; its check
; ------------------------------------------------------------
mkcore  jsr corestd              ; (the fields: in the core's own layout,
        jsr corefd              ; with stripes)
        jsr corefxd
        lda modon               ; a module: its entry points (or none)
        sta coreb+cpt_game
        ldx #5
@en     lda mdent,x             ; init, frame, stop
        ldy modon
        bne @e
        lda #0
@e      sta coreb+cpt_init,x
        dex
        bpl @en
        lda #0                  ; (the core's autorun: never; a module ends
        sta coreb+cpt_auto      ; once the program is in unless -wait)
        ldx #1                  ; RUN (1), or jmp (0)
        lda opt_start
        ora opt_start+1
        beq @run
        dex
@run    stx coreb+cx_run
        lda opt_start
        sta coreb+cx_jmp
        lda opt_start+1
        sta coreb+1+cx_jmp
        lda #$37
        sta coreb+cx_port
        lda #$58                ; cli
        sta coreb+cx_irq
        lda pend
        sta coreb+cx_vt1
        lda pend+1
        sta coreb+cx_vt2
        lda stepv
        sta coreb+cpt_step
        lda stepv+1
        sta coreb+1+cpt_step
        jsr showl               ; the lines through the module or show
        lda #0
        bcc @sl
        lda #$20
@sl     sta coreb+cpt_strs
        lda opt_lines           ; a style: core_stripes (the fields move
        beq @ck                 ; with it), or core_flat, or core_fx
        jsr fxon                ; (an effect, or one colour with the cycle)
        bcc @nx
        jsr corefx
        jsr fxset
        jmp @ck
@nx     jsr flatcol
        bcs @fl
        jsr corestr
        jmp @ck
@fl     pha                     ; core_flat: the border the block's colour
        jsr corefl              ; (as built: ldx ld_seq), or one colour
        pla                     ; (ldx #colour)
        ldy opt_lines
        cpy #st_block
        beq @ck
        sta coreb+cbflat+1
        lda #$a2
        sta coreb+cbflat
@ck     lda #0                  ; the check
        ldx #0
@k      eor coreb,x
        eor coreb+256,x
        eor coreb+512,x
        eor coreb+768,x
        inx
        bne @k
        sta coreb+1024
        rts

; ------------------------------------------------------------
; corestr  coreb from the core to core_stripes, in place (a style's
; loading lines: payload.asm's c2ins and c2d, tools/c64build.py's
; stripes_patch), and the style's colours in its table
; corestd  coreb back to the core itself (when it was made the other)
;   uses: a, x, y, t0-t4, p1-p3
; ------------------------------------------------------------
corest  byte 0                  ; coreb's layout: 0 the core, 1 core_stripes
corestr lda corest
        bne @col                ; (already)
        inc corest
        ldx #0                  ; its end 15 on, its middle 3 on
        jsr cmvup
        ldx #6
        jsr cmvup
        ldx #2                  ; the colour lookup
@i      lda c2ins,x
        sta coreb+c2p1,x
        dex
        bpl @i
        lda #0                  ; the moved addresses: + their deltas
        jsr c2fix
@col    ldx #11                 ; the table: the colour by timer value
@s      ldy opt_lines
        txa
        jsr stcol
        sta coreb+cstab,x
        dex
        bpl @s
        rts
corestd lda corest
        beq @x
        dec corest
        lda #$ff                ; the deltas off
        jsr c2fix
        ldx #12                 ; the middle 3 back, the end 15 back
        jsr cmv
        jsr mvdn
        ldx #18
        jsr cmv
        jsr mvdn
        lda #0                  ; (the 15 bytes past it: zero, as corecp
        ldx #14                 ; left them)
@z      sta coreb+corelen,x
        dex
        bpl @z
@x      rts
; corefl  coreb from the core to core_flat, in place (flo, fhi, fxr: the
; bytes that differ, xored); corefd back to the core
;   uses: a, x, y, p1
corefs  byte 0                  ; coreb: 0 the core, 1 core_flat
corefl  lda corefs
        bne fl_x
        inc corefs
        bne flflip
corefd  lda corefs
        beq fl_x
        dec corefs
        lda #$a6                ; (bflat as the list has it: ldx ld_seq)
        sta coreb+cbflat
        lda #cldseq
        sta coreb+cbflat+1
flflip  ldx #0
@f      lda flo,x
        sta p1
        lda fhi,x
        clc
        adc #>coreb
        sta p1+1
        ldy #0
        lda (p1),y
        eor fxr,x
        sta (p1),y
        inx
        cpx #nfl
        bcc @f
fl_x    rts

; flatcol  the style: c set for one with no stripes (core_flat), a its
; colour (st_black 0, st_one opt_fcol, st_block 0: the block's own);
; c clear for rainbow, a table style or an effect (keeps x, y)
flatcol lda opt_lines
        cmp #st_black
        bcc @x
        cmp #st_fx
        bcs @fx
        cmp #st_one
        lda #0
        bcc @c
        lda opt_fcol
@c      sec
@x      rts
@fx     clc
        rts

; showl  c set when the loading lines go on through the module or show:
; asked (opt_showl), a module or show there is, and the style has lines
; (or cycles: lined) (keeps x, y)
showl   lda opt_showl
        beq @n
        lda modon
        beq @n
        jmp lined
@n      clc
        rts

; fxon  c set for core_fx: an effect, or black or one colour with the
; cycle (the plain effect, fxplain) (keeps x, y)
fxon    lda opt_lines
        cmp #st_fx
        beq @y
        lda opt_cyc
        beq @n
        jsr flatcol
        bcc @n                  ; (rainbow, a table style: no cycle)
        lda opt_lines
        cmp #st_block
        beq @n
@y      sec
        rts
@n      clc
        rts

; lined  c set when the border has lines (a style, an effect), or cycles
; (keeps x, y)
lined   jsr fxon
        bcs @x
        jsr flatcol
        bcc @y                  ; (rainbow or a table style)
        clc
        rts
@y      sec
@x      rts

; s1col  stage 1's border, for a style: its first colour (a table's),
; or flatcol's
s1col   jsr flatcol
        bcs @x
        ldy opt_lines
        lda #0
        jsr stcol
@x      rts

cmvup   jsr cmv
        jmp mvup
; cmv  move x / 6 of cmtab: from p1 to p2, t0/t1 bytes
cmv     ldy #0
@c      lda cmtab,x
        sta p1,y
        inx
        iny
        cpy #4
        bcc @c
        lda cmtab,x
        sta t0
        lda cmtab+1,x
        sta t1
        rts
cmtab   word coreb+c2p2,coreb+c2p2+15,corelen-c2p2      ; (up) the end
        word coreb+c2p1,coreb+c2p1+3,c2p2-c2p1          ; (up) the middle
        word coreb+c2p1+3,coreb+c2p1,c2p2-c2p1          ; (down) the middle
        word coreb+c2p2+15,coreb+c2p2,corelen-c2p2      ; (down) the end
        word coreb+cfxp+3,coreb+cfxp+8,corelen-cfxp-3   ; (up) core_fx: past the effect's 3rd
        word coreb+cfxp+8,coreb+cfxp+3,corelen-cfxp-3   ; (down)

; ------------------------------------------------------------
; corefx  coreb from the core to core_fx, in place (an effect's loading
; lines: payload.asm's fxd, tools/c64build.py's fx_patch): past the
; effect's 3rd byte moved up 5, then the (gap, xor) pairs; corefxd back
; (the pairs again, then down 5)
;   uses: a, x, y, t0, t1, p1-p3
; ------------------------------------------------------------
corefxs byte 0                  ; coreb: 0 the core, 1 core_fx
corefx  lda corefxs
        bne @x
        inc corefxs
        ldx #24
        jsr cmvup
        lda #0                  ; (the 5 bytes made: as the pairs have them)
        ldx #4
@z      sta coreb+cfxp+3,x
        dex
        bpl @z
        jmp fxflip
@x      rts
corefxd lda corefxs
        beq @x
        dec corefxs
        jsr fxflip
        ldx #30
        jsr cmv
        jsr mvdn
        lda #0                  ; (the 5 past it: zero, as corecp left them)
        ldx #4
@z      sta coreb+corelen,x
        dex
        bpl @z
@x      rts
; fxflip: each pair of fxd: on by its gap, xor its byte
fxflip  lda #<coreb
        sta p1
        lda #>coreb
        sta p1+1
        lda #<fxd
        sta p3
        lda #>fxd
        sta p3+1
        lda #<nfx2
        sta t0
        lda #>nfx2
        sta t1
@l      ldy #0
        lda (p3),y              ; the gap
        clc
        adc p1
        sta p1
        bcc @g
        inc p1+1
@g      iny
        lda (p3),y              ; the xor
        dey
        eor (p1),y
        sta (p1),y
        lda p3
        clc
        adc #2
        sta p3
        bcc @c
        inc p3+1
@c      lda t0
        sec
        sbc #2
        sta t0
        bcs @t
        dec t1
@t      ora t1
        bne @l
        rts

; fxset  coreb (core_fx) set for the effect opt_fx: its 8 bytes (its
; value, for and, ora and eor), the colour it starts from, its stores'
; opcodes on and off, and their places (slopload.py's stripe_fx)
;   uses: a, x, y
fxset   lda opt_fxb             ; the effect and its colour: opt_fx's, or
        sta fxcol               ; the plain one (one colour with the cycle)
        lda opt_fx
        ldx opt_lines
        cpx #st_fx
        beq @e
        jsr flatcol
        sta fxcol
        lda #fxplain
@e      sta fxi
        asl a
        asl a
        asl a
        tax
        ldy #0
@c      lda fxtpl,x
        sta coreb+cfxp,y
        inx
        iny
        cpy #8
        bcc @c
        lda opt_cyc             ; -cycle: inc $d020 at each page
        beq @nc
        lda #$ee
        sta coreb+cfxcyc
        lda #$20
        sta coreb+cfxcyc+1
        lda #$d0
        sta coreb+cfxcyc+2
@nc     ldx fxi
        lda fxval,x
        beq @nv
        lda opt_fxn
        sta coreb+cfxp+4
@nv     lda fxcol
        sta coreb+cfxbc
        lda fxpa,x
        clc
        adc #cfxslo
        sta coreb+cfxs
        lda fxpb,x
        clc
        adc #cfxslo
        sta coreb+cfxs2
        lda fxa1v,x
        sta coreb+cfxa1
        lda fxb1v,x
        sta coreb+cfxb1
        lda fxa0v,x
        sta coreb+cfxa0
        lda fxb0v,x
        sta coreb+cfxb0
        rts
fxi     byte 0                  ; the effect (fxplain: the plain one)
fxcol   byte 0                  ; ... the colour it starts from

; c2fix  core_stripes' moved bytes: a = 0 adds each delta, $ff takes it
; off (as the delta eor $ff, plus 1); each a byte, its gap from the last
; (6 bits) and its delta's code (2 bits: +3, +15, -1, 0)
c2fix   sta t4
        lda #<coreb
        sta p1
        lda #>coreb
        sta p1+1
        ldx #0
@l      lda c2d,x
        lsr a
        lsr a
        clc
        adc p1
        sta p1
        bcc @g
        inc p1+1
@g      lda c2d,x
        and #3
        tay
        lda t4                  ; (c: set to take off)
        cmp #$80
        lda c2dt,y
        eor t4
        ldy #0
        adc (p1),y
        sta (p1),y
        inx
        cpx #nc2b
        bcc @l
        rts
c2dt    byte 3,15,$ff,0

; mvup  t0/t1 bytes from p1 to p2 (above it, overlapping): the last first
mvup    lda t0
        ora t1
        beq @x
        lda t0
        bne @d
        dec t1
@d      dec t0
        lda p1
        clc
        adc t0
        sta t2
        lda p1+1
        adc t1
        sta t3
        ldy #0
        lda (t2),y
        tax
        lda p2
        clc
        adc t0
        sta t2
        lda p2+1
        adc t1
        sta t3
        txa
        sta (t2),y
        jmp mvup
@x      rts

; mvdn  t0/t1 bytes from p1 to p2 (below it, overlapping): the first first
mvdn    lda t0
        ora t1
        beq @x
        ldy #0
        lda (p1),y
        sta (p2),y
        inc p1
        bne @a
        inc p1+1
@a      inc p2
        bne @b
        inc p2+1
@b      lda t0
        bne @d
        dec t1
@d      dec t0
        jmp mvdn
@x      rts

; stcol  style y's colour for timer value a (0-11): rainbow (0) the value
; itself, else its list's (a / 2 mod its length; st_own: ownl)
;   uses: a, y, p3 (keeps x)
stcol   cpy #0
        beq @x
        cpy #st_fx              ; (an effect: the colour it starts from)
        bne @nf
        lda opt_fxb
        rts
@nf     cpy #st_own             ; (your own: its list)
        beq @own
        cpy #st_block           ; (a colour a block: shown as 0, 1, 2 ...;
        bcc @t                  ; one colour: that one)
        bne @one
        lsr a
        rts
@one    lda opt_fcol
        rts
@own    lsr a
        pha
        lda #<ownl
        sta p3
        lda #>ownl
        bne @p
@t      lsr a
        pha
        lda stclo,y
        sta p3
        lda stchi,y
@p      sta p3+1
        pla
        ldy #0
@m      cmp (p3),y
        bcc @i
        sbc (p3),y
        bcs @m
@i      tay
        iny
        lda (p3),y
@x      rts

; ------------------------------------------------------------
; mkhead  the KERNAL header (type, stage 1's start, $0304, the name,
; stage 1's header part, spaces) and stage 1's data block (pl_s1blk,
; patched where it is: both bytes set for every tape)
; ------------------------------------------------------------
mkhead  lda #3
        sta header
        lda #<s1lo
        sta header+1
        lda #>s1lo
        sta header+2
        lda #$04
        sta header+3
        lda #$03
        sta header+4
        ldx #0
@n      lda #' '
        cpx tnlen
        bcs @sp
        lda tname,x
@sp     sta header+5,x
        inx
        cpx #16
        bcc @n
        ldx #0
@h      lda pl_s1hdr,x
        sta header+21,x
        inx
        cpx #s1hdrlen
        bcc @h
        lda #' '
@f      cpx #192-21
        bcs @b
        sta header+21,x
        inx
        bne @f
@b      lda #4
        sta pl_s1blk+s1pages
        ldx #$8e                ; stx $d020: stripes
        lda opt_lines           ; a style: stage 1 at one colour (no stripes
        beq @st                 ; before the core's)
        ldx #$2c                ; bit $d020
@st     stx pl_s1blk+cs1str
        lda opt_lines
        beq @r
        jsr s1col
        sta header+21+cs1bc
@r      rts

; ------------------------------------------------------------
; romexp192 / romexps1  a KERNAL block (the header at x/y / stage 1's
; block, s1blklen bytes) as 2-bit symbols at p1 (S 0, M 1, L 2): the
; countdown from a ($89 or $09), the bytes, their check, L S and two more S
; ------------------------------------------------------------
romexp192
        stx p2
        sty p2+1
        ldx #192
        bne romexp
romexps1
        ldx #<pl_s1blk
        stx p2
        ldx #>pl_s1blk
        stx p2+1
        ldx #s1blklen
romexp  stx t5                  ; bytes
        sta t4                  ; the countdown
        lda #0
        sta symn
        lda #1                  ; (the first symbol, an L, ends the run before)
        sta symskip
        lda #9
        sta t6
@s      lda t4
        jsr rombyte
        dec t4
        dec t6
        bne @s
        lda #0
        sta romchk
        ldy #0
@d      sty t6
        lda (p2),y
        pha
        eor romchk
        sta romchk
        pla
        jsr rombyte
        ldy t6
        iny
        cpy t5
        bne @d
        lda romchk
        jsr rombyte
        lda #2                  ; the end mark, L S, and three more S
        jsr putsym
        lda #0
        jsr putsym
        lda #0
        jsr putsym
        lda #0
        jsr putsym
        lda #0
        jmp putsym
romchk  byte 0
symskip byte 0
symn    byte 0
symacc  byte 0

; rombyte  a: L M, 8 bits (lsb first: 1 = M S, 0 = S M), odd parity
rombyte sta t3
        lda #2
        jsr putsym
        lda #1
        jsr putsym
        lda #1
        sta t2                  ; parity
        ldx #8
@b      lsr t3
        bcc @z
        lda t2
        eor #1
        sta t2
        jsr @one
        jmp @n
@z      jsr @zero
@n      dex
        bne @b
        lda t2
        bne @one
@zero   lda #0
        jsr putsym
        lda #1
        jmp putsym
@one    lda #1
        jsr putsym
        lda #0
        jmp putsym

; putsym  symbol a (0-3) into the bytes at p1, 4 a byte, first at the top
putsym  ldy symskip
        beq @p
        dec symskip
        rts
@p      asl symacc
        asl symacc
        ora symacc
        sta symacc
        inc symn
        lda symn
        cmp #4
        bne @x
        lda #0
        sta symn
        tay
        lda symacc
        sta (p1),y
        inc p1
        bne @x
        inc p1+1
@x      rts

; ------------------------------------------------------------
; tapsize  tapn: every pulse on the tape (the .tap's size); every block
; read and its coding chosen on the way (anablk)
;   out:  c set on an error (said)
; ------------------------------------------------------------
tapsize ldx #<tx_ana
        ldy #>tx_ana
        jsr print
        jsr tapbase
        lda #$ff                ; (the program file: opened at its first block)
        sta rdpos
        sta rdpos+1
        lda #0
        sta blk
@b      lda blk
        cmp nblk
        bcs @x
        lda #'.'                ; (a dot a block)
        jsr chrout
        jsr getblk
        bcs @e
        jsr fast
        jsr anablk
        jsr slow
        bcs @e
        jsr bpulses
        inc blk
        jmp @b
@x      lda #13
        jsr chrout
        jsr closeprg
        clc
        rts
@e      lda #13
        jsr chrout
        jsr closeprg
        sec
        rts
tx_ana  text "choosing each block's coding",0

; tapbase  tapn: the KERNAL file and the core (its pilot, sync, 1025
; bytes, and the bridge written in one go)
tapbase lda #<romtotal
        sta tapn
        lda #>romtotal
        sta tapn+1
        lda #0
        sta tapn+2
        ldx opt_speed
        lda bootsh,x
        sta t7
        lda #<pilcore
        ldx #>pilcore
        jsr pilotn
        lda t0
        ldy t1
        jsr addn
        lda #<4100
        ldy #>4100
        jsr addn
        lda opt_cont
        beq @x
        lda #4
        ldy #0
        jmp addn
@x      rts

; ------------------------------------------------------------
; tapchk  room for the .tap file on its drive: the directory's last
; line (blocks free) against its blocks ((20 + tapn) / 254, rounded up)
;   out:  c set if it doesn't fit (said)
; ------------------------------------------------------------
tapchk  lda tapn                ; its blocks
        clc
        adc #<(20+253)
        sta n24
        lda tapn+1
        adc #>(20+253)
        sta n24+1
        lda tapn+2
        adc #0
        sta n24+2
        lda #0
        sta n24+3
        lda #254
        sta dvs
        lda #0
        sta dvs+1
        jsr divn
        lda q24
        sta tneed
        lda q24+1
        sta tneed+1
        lda #$ff                ; (no directory read: no check)
        sta tfree
        sta tfree+1
        lda #4                  ; the directory, of a name nothing has
        ldx tapdev
        ldy #0
        jsr setlfs
        lda #tx_dirn
        ldx #<tx_dir
        ldy #>tx_dir
        jsr setnam
        jsr open
        bcs @end
        ldx #4
        jsr chkin
        bcs @end
        jsr chrin               ; (its load address)
        jsr chrin
@ln     jsr chrin               ; a line: its link (0: the end)
        sta t0
        jsr chrin
        ora t0
        beq @end
        jsr readst
        bne @end
        jsr chrin               ; its number: the last one's is blocks free
        sta tfree
        jsr chrin
        sta tfree+1
@sk     jsr readst
        bne @end
        jsr chrin
        cmp #0
        bne @sk
        beq @ln
@end    jsr clrchn
        lda #4
        jsr close
        lda tfree
        cmp tneed
        lda tfree+1
        sbc tneed+1
        bcs @ok
        ldx #<tx_room1          ; "not enough room on drive 9:"
        ldy #>tx_room1
        jsr print
        lda tapdev
        ldx #0
        jsr prdec16
        ldx #<tx_room2
        ldy #>tx_room2
        jsr print
        lda tneed
        ldx tneed+1
        jsr prdec16
        ldx #<tx_room3
        ldy #>tx_room3
        jsr print
        lda tfree
        ldx tfree+1
        jsr prdec16
        ldx #<tx_room4
        ldy #>tx_room4
        jsr print
        sec
        rts
@ok     clc
        rts
tneed   word 0
tfree   word 0
tx_dir  text "$:",$5c,"slopload free",$5c
tx_dirn = 17
tx_room1 text "not enough room on drive ",0
tx_room2 text ":",13,0
tx_room3 text " blocks needed, ",0
tx_room4 text " free",13,"(a 1581, a cmd drive or an sd2iec)",13,0
addn    clc
        adc tapn
        sta tapn
        tya
        adc tapn+1
        sta tapn+1
        bcc @x
        inc tapn+2
@x      rts

; pilotn  a pilot for quantum t7: x/a points at seconds x 985248 / 4 (3
; bytes): that / t7, at least 300, 3 more than a multiple of 4, and 1 for
; the sync: t0/t1 (t4-t7 kept)
pilotn  sta p3
        stx p3+1
        ldy #0
        lda (p3),y
        sta n24
        iny
        lda (p3),y
        sta n24+1
        iny
        lda (p3),y
        sta n24+2
        lda #0
        sta n24+3
        lda t7
        sta dvs
        lda #0
        sta dvs+1
        jsr divn
        lda q24                 ; at least 300
        cmp #<300
        lda q24+1
        sbc #>300
        bcs @big
        lda #<300
        sta q24
        lda #>300
        sta q24+1
@big    lda q24                 ; up to 3 mod 4, plus the sync: + (4 - n mod 4)
        and #3                  ; ... = n + (3 - n % 4) % 4 + 1
        eor #3
        clc
        adc #1
        adc q24
        sta t0
        lda q24+1
        adc #0
        sta t1
        rts

; trailn  the trailer for quantum t7, set t6: 98524 / (t6 x t7), rounded
; up, then up to a multiple of 4: t2 its bytes (t0, t1, t4-t7 kept)
trailn  lda #0
        sta dvs
        sta dvs+1
        ldx t6
@m      lda dvs                 ; m x h
        clc
        adc t7
        sta dvs
        bcc @m1
        inc dvs+1
@m1     dex
        bne @m
        lda #$dc                ; 98524 = $0180dc
        sta n24
        lda #$80
        sta n24+1
        lda #$01
        sta n24+2
        lda #0
        sta n24+3
        jsr divn
        lda rem                 ; rounded up
        ora rem+1
        beq @r
        inc q24
        bne @r
        inc q24+1
@r      lda q24                 ; bytes: (n + 3) / 4
        clc
        adc #3
        sta t2
        lda q24+1
        adc #0
        lsr a
        ror t2
        lsr a
        ror t2
        rts

pilcore byte $28,$c2,$03        ; 1.0 s x 985248 / 4 = 246312
pilrest byte $14,$e1,$01        ; 0.5 s: 123156
pilres  byte $50,$84,$07        ; 2.0 s: 492624
pilfirst byte $8a,$f0,$00       ; 0.25 s: 61578 (the first block, in one go)
pilblk  byte $f8,$4c,$00        ; 0.08 s: 19704 (the others)

; ------------------------------------------------------------
; getblk  block blk's data into blkb+10, as it is (from memory: the
; module's parts, prepared; or read from the program)
;   out:  c set on a read error (said)
; ------------------------------------------------------------
getblk  lda #$ff                ; (a block read: pfxs isn't its symbols)
        sta pfxb
        ldx blk
        lda bll,x
        sta t2
        lda blh,x
        sta t3
        lda #<(blkb+10)
        sta p1
        lda #>(blkb+10)
        sta p1+1
        lda bsrc,x
        cmp #1
        beq @disk
        cmp #3                  ; (a chain's second module: its file)
        bne @mem
        jmp readb
@mem    lda bpl,x               ; from memory (the high pool too: all RAM)
        sta p2
        lda bph,x
        sta p2+1
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
@disk   jmp readblk

; copyn  t2/t3 bytes from p2 to p1
copyn   ldy #0
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

; readblk  block blk's bytes from the program file (opened, or opened
; again for a block before where it is), to p1
readblk ldx blk
        lda rdpos+1             ; behind? from the start again
        cmp bah,x
        bne @cmp
        lda rdpos
        cmp bal,x
@cmp    bcc @skip
        beq @skip
        jsr closeprg
        jsr openprg
        bcc @o
        rts
@o      lda paddr
        sta rdpos
        lda paddr+1
        sta rdpos+1
@skip   jsr clrchn              ; (a .tap write left the input elsewhere;
        ldx #2                  ; untalked first: openprg leaves the drive
        jsr chkin               ; talking, and a TALK on top of a TALK
                                ; loses a byte on VICE's host-folder drive)
@sk0    ldx blk                 ; skip to the block
        lda rdpos
        cmp bal,x
        bne @sk
        lda rdpos+1
        cmp bah,x
        beq @rd
@sk     jsr rdbyte
        bcs @err
        inc rdpos
        bne @sk0
        inc rdpos+1
        jmp @sk0
@rd     lda bll,x
        sta t2
        lda blh,x
        sta t3
        ldy #0
@r      lda t2
        ora t3
        beq @ok
        jsr rdbyte
        bcs @err
        ldy #0
        sta (p1),y
        inc p1
        bne @1
        inc p1+1
@1      inc rdpos
        bne @2
        inc rdpos+1
@2      lda t2
        bne @3
        dec t3
@3      dec t2
        jmp @r
@ok     jsr clrchn
        clc
        rts
@err    jsr clrchn
        ldx #<tx_short
        ldy #>tx_short
        lda rderr               ; (a read error, not the file's end)
        beq @es
        ldx #<tx_rderr
        ldy #>tx_rderr
@es
        jsr print
        sec
        rts

freq    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; bdata  p1: the block's data, t2/t3 its length; bnext: on a byte
bdata   lda #<(blkb+10)
        sta p1
        lda #>(blkb+10)
        sta p1+1
        ldx blk
        lda bll,x
        sta t2
        lda blh,x
        sta t3
        rts
bnext   inc p1
        bne @1
        inc p1+1
@1      lda t2
        bne @2
        dec t3
@2      dec t2
        rts

; showblk  "block n of m: $aaaa-$bbbb"
showblk ldx #<tx_blk
        ldy #>tx_blk
        jsr print
        lda blk
        clc
        adc #1
        ldx #0
        jsr prdec16
        ldx #<tx_of
        ldy #>tx_of
        jsr print
        lda nblk
        ldx #0
        jsr prdec16
        lda #':'
        jsr chrout
        lda #' '
        jsr chrout
        ldx blk
        lda bal,x
        clc
        adc bll,x
        sta t0
        lda bah,x
        adc blh,x
        sta t1
        lda bah,x
        pha
        lda bal,x
        pla
        tax
        ldy blk
        lda bal,y
        jsr prhex4
        lda #'-'
        jsr chrout
        lda t0
        sec
        sbc #1
        pha
        lda t1
        sbc #0
        tax
        pla
        jsr prhex4
        lda #13
        jmp chrout

tx_blk  text "block ",0
tx_of   text " of ",0
tx_many text "too many blocks",13,0
tx_short text "the file ended early",13,0
