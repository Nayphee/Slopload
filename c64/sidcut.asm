; ------------------------------------------------------------
; sidcut.asm  -  one song of a tune over 4 KB cut down for SlopLoad 64,
; on the C64, as tools/sidstrip.py's -cut does (cut_pages and the
; sidreloc.py it uses are the spec; tests/cuttest.py compares the two):
;
;   cuttrace  the whole tune run in trial.asm's emulator (trial, with
;             tr_cut: cuthook before every instruction), noting what
;             sidreloc's TraceSim and sidstrip's CutSim note: the tune's
;             bytes the song runs, reads and writes, and the high bytes of
;             the addresses it uses (followed from where each came: an
;             immediate, a table, through zero page, the stack and memory
;             it wrote: their origins); then
;   cutpost   the code its branches could reach (static_walk), the
;             compares with a page (cmp_marks), the pages kept, packed
;             together in their order at ct_dst, every address byte in
;             them moved with its page
;   cutafter  for a cut over 4096 bytes: the tune as its init leaves it
;             made a tune of its own with a stub for its init
;             (sidstrip's after_init), and traced; then cutpost packs it
;             round its longest run of pages, the stub just after the
;             last byte kept (cut_pages with after)
;
; The includer then tries the cut tune (trial.asm's tstrip): its SID
; writes must be the whole one's (ct_sum), or it can't be cut.
;
; The tune's pages may be anywhere, and need not all be in memory: chome
; says where each is (the includer's), 0 for one that isn't. One that is
; needed then (trial.asm's tr_fetch, and the cut's own reads of the
; tune's bytes) is read in by the includer's ct_read, with the pages after
; it (pgmax at most), into the memory of pages the song hasn't used:
; those leave it (pgvict), to be read again if it uses them later.
;
; Memory: the tables at $c000-$ceff; the origins in pages of ct_low's list
; (then the back of tr_pool's), the flag maps (a byte for each of a tune
; page's bytes) at the back of tr_pool's, and when those are gone, the
; pages of tune pages not used; zero page $60-$72, $02, $8b-$8f and
; $fb-$fe. tr_pool's pages are $80 up (trial.asm's), ct_low's anywhere.
; The includer: trial.asm (and its tables, trpcp ... trrdm), print.
; ------------------------------------------------------------

; ---- zero page
hpcl   = $60                    ; the instruction's pc
hpch   = $61
hy     = $62                    ; the emulator's y (its offset), kept
oal    = $63                    ; where a, x and y came from: a tune byte's
oah    = $64                    ; address (high byte 0: nowhere)
oxl    = $65
oxh    = $66
oyl    = $67
oyh    = $68
eal    = $69                    ; the operand's address
eah    = $6a
orl    = $6b                    ; an origin (org's out, mark's in)
orh    = $6c
fmp    = $6d                    ; (2) the flag map of page fmpg
fmpg   = $6f
cop    = $70                    ; the opcode
cfl    = $71                    ; its flag byte (fl_run: one of the tune's)
tgl    = $72                    ; mark's address reached
tgh    = $02
cp     = $fb                    ; (2) a pointer
ct     = $fd                    ; temporaries
ct2    = $fe
itmp   = $8b                    ; (intun's; $8b-$8f: BASIC's RND seed)
umnl   = $8c                    ; the lowest byte used,
umnh   = $8d
umxl   = $8e                    ; the highest
umxh   = $8f

; ---- the tables
cpg    = $c000                  ; a page each: 0 not the tune's, 1 all of it
                                ; the tune's, 2 part of it
orgl   = $c100                  ; ... its origins' low bytes' page (0: none)
orgh   = $c200                  ; ... and high bytes'
fmap   = $c300                  ; ... its flag map's page (0: none): a byte
                                ; a byte, fl_*
uflag  = $c400                  ; ... 1: a byte of it used
keep   = $c500                  ; ... 1: kept
pmap   = $c600                  ; ... its page in the cut (0: not there)
cmk    = $c700                  ; the compares: 256 places, the immediate's
cmkh   = $c800                  ; address (high 0: an empty place), and
cmv    = $c900                  ; where the register's value came from
cmvh   = $ca00
ctlow  = $cb00                  ; the low list (the includer's): 0 at its end
ctdl   = $cc00                  ; the hook's handler for each opcode, less 1
ctdh   = $cd00
chome  = $ce00                  ; the tune's pages: each one's real page (0:
                                ; not in memory), the includer's
pgmax  = 16                     ; pages read in one go

fl_run  = 1                     ; run (sidreloc's code: known)
fl_mark = 2                     ; an address's high byte (marks)
fl_done = 4                     ; reached by the static walk
fl_pend = 8                     ; ... to walk from
fl_end  = 16                    ; a compare's page: an end (cmp_marks)
fl_mk   = 32                    ; an absolute instruction whose operand's high
                                ; byte is marked (and spans need a page crossed)
fl_nm   = 64                    ; ... whose operand's pages aren't the tune's

; ---- the interface
ct_dst   byte 0                 ; in: the cut's page (its first byte at
                                ; offset first and 255)
ct_err   byte 0                 ; out: 0, or why not: 1 out of room, 2 over
                                ; 4096 bytes, 3 a page it can't place
ct_first word 0                 ; the cut: its load address (the first byte
ct_len   word 0                 ; used), length,
ct_init  word 0                 ; init and play
ct_play  word 0
ct_sum   byte 0,0,0,0           ; the whole tune's SID writes (trial.asm's
                                ; checksum)
ct_of    byte 0                 ; pages: the tune's, kept
ct_kept  byte 0
ct_read  word ctrts             ; in: tune pages pgx on (pgn of them) into
                                ; pgfrm's pages, from the file (c clear;
                                ; uses a, x, y)
ct_abort word ctrts             ; ... no room to read a page in: never
                                ; returns (the includer's way out)
ct_reads byte 0                 ; out: the times ct_read was called
ct_aft   byte 0                 ; 1: cutafter's tune (the includer: 0 before
                                ; cuttrace on a tune of its own)
ct_stp   byte 0                 ; ... its stub's page (0: none)
ct_stn   byte 0                 ; ... the stub's length

; ---- variables
lopg    byte 0                  ; the tune's first page, its first byte's
loadlo  byte 0                  ; low byte; its last page and byte
hipg    byte 0
lastlo  byte 0
mkl     byte 0                  ; the last one marked
mkh     byte 0
spl     byte 0                  ; the last span (its origin and page)
sph     byte 0
spp     byte 0
mkr1    byte 0                  ; (mark: the pages kept)
mkr2    byte 0
cbh     byte 0                  ; an operand's base, high byte
ctli    byte 0                  ; the low list: the next
csx     byte 0                  ; (the allocators' x and y,
csy     byte 0
mcx     byte 0                  ; mkclr's)
mcy     byte 0
wsl     byte 0                  ; the static walk: a way's start,
wsh     byte 0
wfound  byte 0                  ; a pending one walked this time,
wmode   byte 0                  ; 1: noting the way,
wroom   byte 0                  ; out of room,
wlen    byte 0                  ; an instruction's length,
wcnt    byte 0                  ; counts,
woff    byte 0                  ; a branch's offset
cmo     byte 0                  ; an instruction's mode
wbits   byte 0                  ; (pack: a byte's flags,
wv      byte 0                  ; its value)
pglo    byte 0                  ; paging: the tune's first and last pages,
pghi    byte 0
pgx     byte 0                  ; the first page read in, how many,
pgn     byte 0
pgfrm   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                ; their pages (pgmax),
pgsx    byte 0                  ; (pgget's x and y,
pgsy    byte 0
pgox    byte 0                  ; obyte's and wbyte's x,
pgstp   byte 0                  ; pgvict's step)
alo     byte 0                  ; cutafter: the whole tune's first and last
ahi     byte 0                  ; pages, how many,
aof     byte 0
t2lo    byte 0                  ; the after-init tune's first and last,
t2hi    byte 0
ctstbp  byte 0                  ; the stub's real page,
ctov    byte 0                  ; (1: the stub over 255 bytes)
ctsum0  byte 0,0,0,0            ; the whole tune's SID writes (ct_sum)
ctnfh   byte 0                  ; pack: the first byte's page in the cut
ctbx    byte 0                  ; (the bits' x)
ctv     byte 0                  ; (rmval's value)
nk      byte 0                  ; aplace: the pages kept, the last byte's
ixl     byte 0                  ; page's place among them, the longest
bestn   byte 0                  ; run (its length, first page, its place),
bestp   byte 0
besti   byte 0
runn    byte 0                  ; the run now
runp    byte 0
runi    byte 0
ctbase  byte 0                  ; aok: the first kept page's place, the
ctlast  byte 0                  ; last's,
eh      byte 0                  ; the stub's first byte
el      byte 0
ndh     byte 0                  ; ... and past its last
ndl     byte 0
ctpin   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                ; cutafter's pages the pager can't read
                                ; again: a bit each
ctbusy  byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                ; the real pages holding its pages
pmask   byte 1,2,4,8,16,32,64,128
ctslog  byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                ; init's SID writes (trial.asm's tr_slog)
ctpool2 byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                                ; the second trace's pool: tr_pool's pages
                                ; holding none of the tune (0 at its end)

; ------------------------------------------------------------
; cuttrace  the trace run (trial with tr_cut 1)
;   in:   tr_load ... tr_calls, tr_scr, tr_pool, ct_low's list at ctlow,
;         chome (the tune's pages: tr_src isn't used), ct_read, ct_abort
;   out:  tr_err (trial.asm's refusal: 13 out of room), ct_sum
;   uses: a, x, y, the trial's and the cut's memory
; ------------------------------------------------------------
cuttrace
        lda #<ctinit
        sta tr_hook
        lda #>ctinit
        sta tr_hook+1
        jsr ctpage
        lda #1
        sta tr_cut
        jsr trial
        lda #0
        sta tr_cut
        sta tr_home
        ldx #3
@s      lda tr1s,x
        sta ct_sum,x
        dex
        bpl @s
        rts

; ctpage: the pager, for a run of the tune at tr_load (tr_len): its
; pages through chome, read in by pgget
ctpage  lda #>chome             ; the tune's pages: chome's (pgget reads
        sta tr_home             ; them in)
        lda #<pgget
        sta tr_fetch
        lda #>pgget
        sta tr_fetch+1
        lda tr_load+1           ; (the pager's: the first and last pages,
        sta pglo                ; nothing used yet, the low list and the
        lda tr_load             ; pool from their starts)
        clc
        adc tr_len
        lda tr_load+1
        adc tr_len+1
        tax
        lda tr_load
        clc
        adc tr_len
        bne @l
        dex
@l      stx pghi
        ldx #0
        txa
        sta ctli
        sta ct_reads
@z      sta uflag,x
        sta fmap,x
        sta keep,x
        inx
        bne @z
        lda tr_pool
        sta fmget+1
        lda tr_pool+1
        sta fmget+2
        rts

; ------------------------------------------------------------
; cutafter  the tune as its init leaves it made a tune of its own, and
;           traced (sidstrip's after_init, then cut_pages's trace): init
;           alone (trial, no play calls, its SID writes noted), then its
;           pages: those init wrote, and the first and last (copied by
;           the trial), where the trial left them, pinned (the pager
;           can't read them again); the tune's others where chome has
;           them (or read in again); the rest zeros (trzero). From the
;           lower of the tune's first page and the lowest init wrote to
;           the higher of its last and the highest, and on the page
;           after that a stub, its init: the zero page init wrote (lda #v
;           : sta zp), its SID writes in order (lda #v : sta $d4rr), CIA
;           1's timer A latch when it isn't 0, rts. Then cuttrace on it,
;           its pool tr_pool's pages that hold none of it; its SID
;           writes must be the whole tune's (ct_sum)
;   in:   what cuttrace takes, for the whole tune, after its cuttrace
;   out:  c set if it can't be: ct_err 1 (no room), 4 (it would reach
;         $d000-$dfff or past $ffff), 5 (the stub over 255 bytes), 6 (it
;         plays differently), or the trial's refusal (tr_err); else the
;         trace done for cutpost (ct_aft 1, ct_stp, ct_stn)
;   uses: a, x, y, the trial's and the cut's memory
; ------------------------------------------------------------
cutafter
        ldx #3                  ; the whole tune's SID writes, kept
@k      lda ct_sum,x
        sta ctsum0,x
        dex
        bpl @k
        lda lopg                ; its pages
        sta alo
        lda hipg
        sta ahi
        sec
        sbc lopg
        clc
        adc #1
        sta aof
        lda #0
        sta ct_err
        sta ct_aft
        sta ct_stp
        lda tr_calls            ; init alone: no play calls, its SID
        pha                     ; writes noted
        lda tr_calls+1
        pha
        lda #0
        sta tr_calls
        sta tr_calls+1
        lda #<ctslog
        sta tr_slog
        lda #>ctslog
        sta tr_slog+1
        jsr ctpage
        jsr trial
        lda #0
        sta tr_slog+1
        sta tr_home
        pla
        sta tr_calls+1
        pla
        sta tr_calls
        lda tr_err
        bne @x
        php                     ; the tune it left (the pool may be under
        sei                     ; the I/O)
        lda $01
        pha
        lda #$34
        sta $01
        jsr aftt2
        pla                     ; (c kept)
        sta $01
        bcs @no
        plp
        jsr cuttrace            ; its trace
        lda tr_err
        bne @x
        ldx #3                  ; its SID writes: the whole tune's?
@c      lda ct_sum,x
        cmp ctsum0,x
        bne @df
        dex
        bpl @c
        clc
        rts
@df     lda #6
        sta ct_err
@x      sec
        rts
@no     plp
        sec
        rts

; aftt2: (cutafter's) the tune init left: its pages, the stub, chome,
; the pins, the second trace's pool, tr_load ... for it (c set: it can't
; be, ct_err)
aftt2   lda alo                 ; its first and last pages: the tune's,
        sta t2lo                ; or those init wrote ($0200 on, not the
        lda ahi                 ; I/O)
        sta t2hi
        ldx #2
@w      cpx #$d0
        bcc @w1
        cpx #$e0
        bcc @wn
@w1     cpx alo                 ; (not the tune's)
        bcc @w2
        cpx ahi
        bcc @wn
        beq @wn
@w2     lda trrpt,x             ; written: neither zeros nor 0 (the I/O)
        beq @wn
        cmp #>trzero
        beq @wn
        cpx t2lo
        bcs @w3
        stx t2lo
@w3     cpx t2hi
        bcc @wn
        stx t2hi
@wn     inx
        bne @w
        ldx t2hi                ; the stub's page: the one after
        inx
        beq @far                ; (past $ffff)
        stx ct_stp
        cpx #$d0                ; (in or past the I/O: reaching it if the
        bcc @nio                ; first is below it)
        lda t2lo
        cmp #$e0
        bcc @far
@nio    ldx trfi                ; the stub's real page: the pool's next
        cpx trbi
        bcc @sp
        lda #1
        sta ct_err
        sec
        rts
@far    lda #4
        sta ct_err
        sec
        rts
@big    lda #5
        sta ct_err
        sec
        rts
@sp     jsr fmget
        sta ctstbp
        sta stb+2
        ldy #0
@zr     lda #0                  ; (zeroed)
        jsr stb
        cpy #0
        bne @zr
        sty ctov
        ldx #2                  ; the zero page init wrote: lda #v : sta zp
@zp     lda trzpw,x
        beq @zn
        lda #$a9
        jsr stb
        lda trzpg,x
        jsr stb
        lda #$85
        jsr stb
        txa
        jsr stb
@zn     inx
        bne @zp
        lda tr_nslog            ; its SID writes: lda #v : sta $d4rr
        bpl @sn                 ; (over 64: too big)
        jmp @big
@sn
        asl a
        sta wcnt
        ldx #0
@sd     cpx wcnt
        bcs @lt
        lda #$a9
        jsr stb
        lda ctslog+1,x
        jsr stb
        lda #$8d
        jsr stb
        lda ctslog,x
        jsr stb
        lda #$d4
        jsr stb
        inx
        inx
        bne @sd
@lt     lda tr_latch            ; CIA 1's timer A latch, if not 0
        ora tr_latch+1
        beq @rt
        lda #$a9
        jsr stb
        lda tr_latch
        jsr stb
        lda #$8d
        jsr stb
        lda #$04
        jsr stb
        lda #$dc
        jsr stb
        lda #$a9
        jsr stb
        lda tr_latch+1
        jsr stb
        lda #$8d
        jsr stb
        lda #$05
        jsr stb
        lda #$dc
        jsr stb
@rt     lda #$60
        jsr stb
        lda ctov
        beq @sz
        jmp @big
@sz     sty ct_stn
        ldx #31                 ; the pins and the pages holding it: none
        lda #0
@cb     sta ctpin,x
        sta ctbusy,x
        dex
        bpl @cb
        ldx t2lo                ; chome for it, page by page
@ch     cpx ct_stp
        beq @st
        cpx alo
        bcc @tr
        cpx ahi
        beq @tc
        bcs @tr
@tc     lda trwpt,x             ; the tune's, unwritten: where chome has it
        and #$3f                ; (or read in again), not pinned
        cmp #$10
        bne @tr
        lda chome,x
        jmp @bz
@tr     lda trrpt,x             ; else where the trial left it (or zeros),
        sta chome,x             ; pinned
        jsr pin
        jmp @bz
@st     lda ctstbp
        sta chome,x
        jsr pin
@bz     lda chome,x             ; (its real page: busy)
        beq @cn
        jsr busy
@cn     cpx ct_stp
        beq @ce
        inx
        bne @ch
@ce     ldx #0                  ; the second trace's pool: tr_pool's pages
        ldy #0                  ; that hold none of it
@pl     jsr fmget
        beq @pe
        jsr isbusy
        bcs @pn
        sta ctpool2,y
        iny
@pn     inx
        bne @pl
@pe     lda #0
        sta ctpool2,y
        lda #<ctpool2
        sta tr_pool
        lda #>ctpool2
        sta tr_pool+1
        lda t2lo                ; its load address: the tune's, or its
        cmp alo                 ; first page's start
        beq @ld
        sta tr_load+1
        lda #0
        sta tr_load
@ld     lda ct_stn              ; its length: to the stub's end
        sec
        sbc tr_load
        sta tr_len
        lda ct_stp
        sbc tr_load+1
        sta tr_len+1
        lda #0                  ; init: the stub
        sta tr_init
        lda ct_stp
        sta tr_init+1
        lda #1
        sta ct_aft
        clc
        rts

; stb: a into the stub, its byte y (y on; ctov 1 when over 255 bytes)
stb     sta $ff00,y
        iny
        bne @r
        inc ctov
@r      rts

; pin, ispin: page x's bit in ctpin set, or c set if it is; busy,
; isbusy: page a's in ctbusy (x, y kept; a too, but by pin and ispin)
pin     sty ctby
        jsr pbit
        ora ctpin,y
        sta ctpin,y
        ldy ctby
        rts
ispin   sty ctby
        jsr pbit
        and ctpin,y
        cmp #1
        ldy ctby
        rts
busy    pha
        stx ctbx
        sty ctby
        tax
        jsr pbit
        ora ctbusy,y
        sta ctbusy,y
        ldx ctbx
        ldy ctby
        pla
        rts
isbusy  pha
        stx ctbx
        sty ctby
        tax
        jsr pbit
        and ctbusy,y
        cmp #1
        ldx ctbx
        ldy ctby
        pla
        rts
; pbit: y = x / 8, a = its bit's mask (x kept)
pbit    txa
        lsr a
        lsr a
        lsr a
        tay
        txa
        and #7
        stx pgsx2
        tax
        lda pmask,x
        ldx pgsx2
        rts
pgsx2   byte 0
ctby    byte 0

; ctinit: the trace's own setup, after trial.asm's (its tr_hook)
ctinit  ldx #0
        txa
@z      sta cpg,x
        sta orgl,x
        sta orgh,x
        sta fmap,x
        sta uflag,x
        sta keep,x
        sta pmap,x
        sta cmkh,x
        inx
        bne @z
        lda tr_load+1           ; the tune's pages: 1, the first and last
        sta lopg                ; 2 if only part is the tune's
        lda tr_load
        sta loadlo
        lda trlsth
        sta hipg
        lda trlstl
        sta lastlo
        ldx lopg
@p      lda #1
        sta cpg,x
        cpx hipg
        beq @pe
        inx
        bne @p
@pe     lda #2
        ldx loadlo
        beq @f
        ldx lopg
        sta cpg,x
@f      ldx lastlo
        cpx #$ff
        beq @l
        ldx hipg
        sta cpg,x
@l      lda tr_pool             ; the pool's list (fmalloc: from its back)
        sta fmget+1
        lda tr_pool+1
        sta fmget+2
        lda #0
        sta ctli
        sta oah                 ; a, x, y: from nowhere
        sta oxh
        sta oyh
        sta mkh                 ; (nothing marked yet)
        sta spp
        sta fmpg
        sta umxl                ; the lowest and highest used: none yet
        sta umxh
        lda #$ff
        sta umnl
        sta umnh
        ldx #0                  ; zero page and the stack: from nowhere
        jsr shnew
        ldx #1
        jsr shnew
        ldx #0                  ; each opcode's handler: its mode's (memory),
@d      ldy ctop,x              ; its operation's (none, a branch), or the
        lda ctmod,x             ; immediate one's
        beq @d0
        cmp #11
        beq @d0
        cmp #1
        beq @di
        tay
        lda cmjl,y
        sec
        sbc #1
        sta ctdl,x
        lda cmjh,y
        sbc #0
        jmp @dn
@d0     lda cojl,y
        sec
        sbc #1
        sta ctdl,x
        lda cojh,y
        sbc #0
        jmp @dn
@di     lda cijl,y
        sec
        sbc #1
        sta ctdl,x
        lda cijh,y
        sbc #0
@dn     sta ctdh,x
        lda ctdl,x              ; (nothing to note: 0, straight on)
        cmp #<cutdone-1
        bne @dx
        lda ctdh,x
        cmp #>cutdone-1
        bne @dx
        lda #0
        sta ctdh,x
@dx     inx
        bne @d
        lda #$4c                ; the dispatch through cuthook (the edge
        sta trnx2               ; buffer's through cslow)
        lda #<cuthook
        sta trnx2+1
        lda #>cuthook
        sta trnx2+2
        lda #<cslow
        sta tredj+1
        lda #>cslow
        sta tredj+2
        rts

; ------------------------------------------------------------
; cuthook  before each instruction the emulator runs (trnx2 jumps here,
;          y at its opcode in trpcp's page): its notes, then its handler
;          (cutdone). What sidreloc's TraceSim.step and sidstrip's
;          CutSim.step note, from the state before it runs (the same as
;          after, for what they note). The quick way: an instruction run
;          before, in a page with a flag map (fmp: its map, fmpg: its
;          page).
; ------------------------------------------------------------
cuthook ldx trpch               ; (its page's flag map; from the edge
                                ; buffer: cslow, through tredj)
        lda fmap,x
        beq cnomap
        sta fmp+1
        stx fmpg
        lda (fmp),y
        sta cfl
        lsr
        bcc cfirst
        sty hy
        sty hpcl
        stx hpch
cgo     lda (trpcp),y           ; its handler (y = hy): none, on with the
        tax                     ; instruction
        lda ctdh,x
        beq @n
        stx cop
        pha
        lda ctdl,x
        pha
        rts
@n      txa
        asl
        jmp trnx3
; cnomap: in a page without a flag map: not the tune's (code it put
; somewhere: no flags), or a page of it run for the first time (cslow)
cnomap  lda cpg,x
        bne cslow
        sta cfl
        sty hy
        sty hpcl
        stx hpch
        jmp cgo
; cfirst: run for the first time (in fmp's page): one of the tune's, its
; bytes used
cfirst  sty hy
        sty hpcl
        lda trpch
        sta hpch
        lda (trpcp),y
        sta cop
        tax
        tya
        ldx hpch
        jsr intun
        bcc cgo
        lda cfl
        ora #fl_run
        sta (fmp),y
        sta cfl
        jsr xused
        ldy hy
        jmp cgo
; cslow: from the edge buffer, or another page
cslow   sty hy
        ldx trpcp+1
        cpx #>trvp
        beq @edge
        sty hpcl
        lda trpch
        sta hpch
        jmp @pc
@edge   lda tredgy              ; (its own pc)
        sta hpcl
        lda tredgp
        sta hpch
@pc     lda (trpcp),y
        sta cop
        lda #0
        sta cfl
        ldx hpch
        lda cpg,x
        beq @go
        lda hpcl
        jsr intun
        bcc @go
        cpx fmpg
        beq @fm
        jsr fmset
        bcs ctfull
@fm     ldy hpcl
        lda (fmp),y
        sta cfl
        lsr
        bcs @go
        lda cfl
        ora #fl_run
        sta (fmp),y
        sta cfl
        jsr xused
@go     ldy hy
        jmp cgo
ctfull  lda #13                 ; out of room
        jmp trfail

; opgo: the operation's notes, after the mode's; cutdone: the
; instruction's handler
opgo    ldx cop
        lda ctop,x
        tax
        lda cojl,x
        sta @j+1
        lda cojh,x
        sta @j+2
@j      jmp $ffff
cutdone ldy hy
        lda (trpcp),y
        asl
        jmp trnx3

; xused: the instruction's bytes (the tune's) used (y kept)
xused   ldx cop
        lda ctmod,x
        tax
        lda cmlen,x
        sta ct
        lda hpcl
        ldx hpch
@l      jsr usedin
        dec ct
        beq @r
        clc
        adc #1
        bne @l
        inx
        bne @l
@r      rts

; ---- the modes: eal/eah the operand's address, and sidreloc's marks
m_zp    lda #0
        beq mzz
m_zpx   lda trrx
        jmp mzz
m_zpy   lda trry
mzz     ldy hy
        iny
        clc
        adc (trpcp),y
        sta eal
        lda #0
        sta eah
        jmp opgo
m_abs   lda #0
        beq mab
m_abx   lda trrx
        jmp mab
m_aby   lda trry
mab     sta ct2                 ; the index
        ldy hy
        iny
        lda (trpcp),y
        sta ct                  ; the base
        clc
        adc ct2
        sta eal
        iny
        lda (trpcp),y
        sta cbh
        adc #0
        sta eah
        lda cfl                 ; done before (its operand as it was: shnew
        and #fl_mk+fl_nm        ; clears these): only a page crossed needs
        beq @full               ; the rest
        and #fl_nm
        bne @g
        lda eah
        cmp cbh
        beq @g
@full   ldx eah                 ; the address or the base in the tune: the
        lda cpg,x               ; operand's high byte marked
        beq @nb
        lda eal
        jsr intun
        bcs @mk
@nb     ldx cbh
        lda cpg,x
        beq @nm
        lda ct
        jsr intun
        bcs @mk
@nm     lda cfl
        beq @g
        jsr nmnote
        jmp opgo
@mk     jsr p2org
        jsr markea
        jsr mknote
@g      jmp opgo
m_izx   ldy hy
        iny
        lda (trpcp),y
        clc
        adc trrx
        tax
        lda trzpg,x
        sta eal
        inx
        stx ct                  ; (the pointer's high byte)
        lda trzpg,x
        sta eah
        tax
        lda eal
        jsr intun
        bcc @g
        lda ct
        ldx #0
        jsr org
        jsr markea
@g      jmp opgo
m_izy   ldy hy
        iny
        lda (trpcp),y
        tax
        lda trzpg,x
        sta ct2                 ; the pointer
        inx
        stx ct                  ; (its high byte's place)
        lda trzpg,x
        sta cbh
        lda ct2
        clc
        adc trry
        sta eal
        lda cbh
        adc #0
        sta eah
        tax
        lda eal
        jsr intun
        bcs @mk
        ldx cbh
        lda ct2
        jsr intun
        bcc @g
@mk     lda ct
        ldx #0
        jsr org
        jsr markea
@g      jmp opgo
m_ind   ldy hy                  ; jmp (ind): the vector's address
        iny
        lda (trpcp),y
        sta ct2
        iny
        lda (trpcp),y
        sta cbh
        tax
        lda ct2
        jsr intun
        bcc @v
        jsr p2org
        lda ct2
        sta tgl
        lda cbh
        sta tgh
        jsr mark
@v      lda ct2                 ; the vector (the page bug: its high byte
        sta trlo                ; from the same page)
        ldx cbh
        jsr trrdm
        sta eal
        inc trlo
        jsr trrdm
        sta eah
        tax
        lda eal
        jsr intun
        bcc @g
        lda ct2
        clc
        adc #1
        ldx cbh
        jsr org
        jsr markea
@g      jmp opgo
cmjl    byte <m_zp,<m_zp,<m_zp,<m_zpx,<m_zpy,<m_abs,<m_abx,<m_aby,<m_izx,<m_izy,<m_ind,<m_zp
cmjh    byte >m_zp,>m_zp,>m_zp,>m_zpx,>m_zpy,>m_abs,>m_abx,>m_aby,>m_izx,>m_izy,>m_ind,>m_zp
cmlen   byte 1,2,2,2,2,3,3,3,2,2,3,2

; mknote, nmnote: an absolute instruction of the tune's whose operand's
; page has no origins (its own bytes): fl_mk, its operand's high byte
; marked; fl_nm, its operand and the page after not the tune's
mknote  lda #fl_mk
        bne abnote
nmnote  ldx cbh
        lda cpg,x
        bne nnr
        inx
        lda cpg,x
        bne nnr
        lda #fl_nm
abnote  sta ct2
        lda cfl
        lsr
        bcc nnr
        lda hpch
        cmp fmpg
        bne nnr
        ldx hpch
        lda hpcl
        cmp #$fe
        bcc @p
        inx
@p      lda orgl,x
        bne nnr
        lda cfl
        ora ct2
        sta cfl
        ldy hpcl
        sta (fmp),y
nnr     rts

; p1org, p2org: orl/orh = org(pc + 1), org(pc + 2)
p1org   lda #1
        bne pnorg
p2org   lda #2
pnorg   clc
        adc hpcl
        ldx hpch
        bcc org
        inx
; ------------------------------------------------------------
; org     where the value at x:a came from (sidreloc's org): its origin,
;         noted when it was stored, or itself (a tune byte), or nowhere
;   out:  orl/orh (orh 0: nowhere)
;   uses: a, y (x kept)
; ------------------------------------------------------------
org     sta orl
        lda orgl,x
        bne @sh
        lda cpg,x
        beq @no
        lsr
        bcc @pt
        stx orh                 ; (all the tune's: itself)
        rts
@pt     lda orl
        jsr intun
        bcc @no
        stx orh
        rts
@no     lda #0
        sta orh
        rts
@sh     sta @l+2
        lda orgh,x
        sta @h+2
        ldy orl
@l      lda $ff00,y
        sta orl
@h      lda $ff00,y
        sta orh
        rts

; intun: c set when x:a is one of the tune's bytes (a, x, y kept)
intun   sta itmp
        lda cpg,x
        beq @n
        lsr
        bcc @pt
        lda itmp                ; (c set)
        rts
@pt     lda itmp
        cpx lopg
        bne @h
        cmp loadlo
        bcc @no
@h      cpx hipg
        bne @y
        cmp lastlo
        beq @y
        bcs @no
@y      sec
        rts
@n      lda itmp
@no     clc
        rts

; inpg: c set when a is one of the tune's pages (a, x, y kept)
inpg    cmp lopg
        bcc @n
        cmp hipg
        beq @y
        bcs @n
@y      sec
        rts
@n      clc
        rts

; usedea: the operand's address used (a tune byte); usedin: x:a, a tune
; byte, used; used: x:a (in the tune) used: its page, the lowest and
; highest (a, x, y kept)
usedea  ldx eah
        lda eal
usedin  jsr intun
        bcs used
        rts
used    pha
        lda uflag,x             ; (a page used before, not the lowest's or
        beq @u                  ; the highest's: nothing new)
        cpx umnh
        beq @u
        cpx umxh
        beq @u
        pla
        rts
@u      lda #1
        sta uflag,x
        pla
        cpx ct_stp              ; (cutafter's stub: not the cut's first or
        beq @r                  ; last)
        cpx umnh
        bcc @mn
        bne @mx
        cmp umnl
        bcs @mx
@mn     stx umnh
        sta umnl
@mx     cpx umxh
        bcc @r
        bne @nx
        cmp umxl
        bcc @r
@nx     stx umxh
        sta umxl
@r      rts

; ------------------------------------------------------------
; mark    orl/orh (an origin: nowhere with orh 0) is an address's high
;         byte, the address tgl/tgh (markea: eal/eah): marked when it is
;         one of the tune's bytes, and when the address is too, every
;         page from the byte's own (its value in the file) to the
;         address's kept (sidreloc's marks and spans)
;   uses: a, x, y, cp
; ------------------------------------------------------------
markea  lda eal
        sta tgl
        lda eah
        sta tgh
mark    ldx orh
        bne @o1
@x      rts
@o1     lda orl
        jsr intun
        bcc @x
        cmp mkl                 ; (the last one marked: done)
        bne @m
        cpx mkh
        beq @sp
@m      sta mkl
        stx mkh
        lda fmap,x              ; (its flag map: not fmp's, the pc's)
        bne @f
        jsr fmalloc
        bcc @f0
        jmp ctfull
@f0     sta fmap,x
@f      sta @g+2
        sta @s+2
        ldy mkl
@g      lda $ff00,y
        ora #fl_mark
@s      sta $ff00,y
@sp     ldx tgh                 ; the address in the tune: a span
        lda tgl
        jsr intun
        bcc @r
        cpx spp                 ; (the last one: done)
        bne @s1
        lda orl
        cmp spl
        bne @s1
        lda orh
        cmp sph
        beq @r
@s1     stx spp
        lda orl
        sta spl
        lda orh
        sta sph
        jsr obyte               ; its value in the file: a page
        cmp tgh
        beq @r
        jsr inpg
        bcc @r
        sta mkr1                ; keep mkr1 ... mkr2 (the lower first)
        lda tgh
        sta mkr2
        cmp mkr1
        bcs @o
        ldx mkr1
        sta mkr1
        stx mkr2
@o      ldx mkr1
        lda #1
@k      sta keep,x
        cpx mkr2
        beq @r
        inx
        bne @k
@r      rts

; obyte: a = the file's byte at orl/orh (a tune byte; uses y, cp; x kept)
obyte   stx pgox
        ldx orh
        lda chome,x
        bne @h
        jsr pgget
@h      sta cp+1
        lda orl
        sta cp
        ldy #0
        lda (cp),y
        ldx pgox
        rts

; ------------------------------------------------------------
; the operations' notes (sidreloc's TraceSim after the step; CutSim's
; reads and writes); on to cutdone. o_*i: the immediate ones
; ------------------------------------------------------------
o_ldai  jsr p1src
        jmp o_lda2
o_lda   jsr opsrc
o_lda2  lda orl
        sta oal
        lda orh
        sta oah
        jmp cutdone
o_ldxi  jsr p1src
        jmp o_ldx2
o_ldx   jsr opsrc
o_ldx2  lda orl
        sta oxl
        lda orh
        sta oxh
        jmp cutdone
o_ldyi  jsr p1src
        jmp o_ldy2
o_ldy   jsr opsrc
o_ldy2  lda orl
        sta oyl
        lda orh
        sta oyh
        jmp cutdone
o_lax   jsr opsrc
        lda orl
        sta oal
        lda orh
        sta oah
        jmp o_ldx2
; p1src: the immediate's own address; opsrc: org of the operand's
; address (read: used)
p1src   lda hpcl
        clc
        adc #1
        sta orl
        lda hpch
        adc #0
        sta orh
        rts
opsrc   jsr usedea
        ldx eah
        lda eal
        jmp org
o_sta   lda oal
        ldx oah
        jmp ostore
o_stx   lda oxl
        ldx oxh
        jmp ostore
o_sty   lda oyl
        ldx oyh
ostore  jsr setorg
        jsr usedea
        jmp cutdone
o_sax   lda #0                  ; (sax: from nowhere, and not a write
        tax                     ; CutSim sees)
        jsr setorg
        jmp cutdone
o_arii  ldy hy                  ; adc sbc ora eor and: a from the operand
        iny                     ; when it is one of the tune's pages and a
        lda (trpcp),y           ; isn't
        sta ct2
        jsr p1src
        jmp oari2
o_ari   jsr usedea
        lda eal                 ; (its value: memory as it is, no I/O
        sta trlo                ; registers)
        ldx eah
        jsr trrdm
        sta ct2
        lda eal
        jsr org
oari2   lda ct2
        jsr inpg
        bcc @r
        lda trra
        jsr inpg
        bcs @r
        lda orl
        sta oal
        lda orh
        sta oah
@r      jmp cutdone
o_cmpi  lda oal
        ldx oah
        jmp ocmp
o_cpxi  lda oxl
        ldx oxh
        jmp ocmp
o_cpyi  lda oyl
        ldx oyh
ocmp    sta ct2                 ; compare #: noted when the register came
        stx ct                  ; from somewhere, the immediate's origin is
        txa                     ; a tune byte, and its value in the file
        beq @r                  ; one of the tune's pages or the one past
        jsr p1org               ; (cmp_marks keeps no others)
        ldx orh
        beq @r
        lda orl
        jsr intun
        bcc @r
        jsr obyte
        cmp lopg
        bcc @r
        sbc #1
        cmp hipg
        beq @p
        bcs @r
@p      jsr cmput
@r      jmp cutdone
o_rd                            ; bit, a compare in memory, inc dec and the
o_rmw   jsr usedea              ; shifts: a read or write
        jmp cutdone
o_jsr   lda orgh+1              ; the return pushed: from nowhere
        sta cp+1
        lda #0
        sta cp
        ldy trrs
        sta (cp),y
        dey
        sta (cp),y
        jmp cutdone
o_jind  ldx hpch                ; jmp (ind) in the tune: its vector used
        lda hpcl
        jsr intun
        bcc @r
        ldx cbh
        lda ct2
        jsr usedin
        clc
        adc #1
        jsr usedin
@r      jmp cutdone
o_rts   ldx trrs                ; the return: its high byte marked
        inx
        stx ct
        inx
        stx ct2
        lda trstk,x
        sta tgh
        ldx ct
        lda trstk,x
        clc
        adc #1
        sta tgl
        bcc @n
        inc tgh
@n      ldx tgh
        jsr intun
        bcc @r
        lda ct2
        ldx #1
        jsr org
        jsr mark
@r      jmp cutdone
o_pha   lda orgl+1
        sta cp+1
        lda #0
        sta cp
        ldy trrs
        lda oal
        sta (cp),y
        lda orgh+1
        sta cp+1
        lda oah
        sta (cp),y
        jmp cutdone
o_php   lda orgh+1
        sta cp+1
        lda #0
        sta cp
        ldy trrs
        sta (cp),y
        jmp cutdone
o_pla   ldx trrs
        inx
        txa
        ldx #1
        jsr org
        lda orl
        sta oal
        lda orh
        sta oah
        jmp cutdone
o_tax   lda oal
        sta oxl
        lda oah
        sta oxh
        jmp cutdone
o_tay   lda oal
        sta oyl
        lda oah
        sta oyh
        jmp cutdone
o_txa   lda oxl
        sta oal
        lda oxh
        sta oah
        jmp cutdone
o_tya   lda oyl
        sta oal
        lda oyh
        sta oah
        jmp cutdone
o_tsx   lda #0
        sta oxh
        jmp cutdone
cojl    byte <cutdone,<o_lda,<o_ldx,<o_ldy,<o_lax,<o_sta,<o_stx,<o_sty,<o_sax
        byte <o_ari,<o_rd,<o_rd,<o_rd,<o_rd,<o_rmw,<o_jsr,<cutdone,<o_jind
        byte <o_rts,<o_pha,<o_php,<o_pla,<o_tax,<o_tay,<o_txa,<o_tya,<o_tsx
cojh    byte >cutdone,>o_lda,>o_ldx,>o_ldy,>o_lax,>o_sta,>o_stx,>o_sty,>o_sax
        byte >o_ari,>o_rd,>o_rd,>o_rd,>o_rd,>o_rmw,>o_jsr,>cutdone,>o_jind
        byte >o_rts,>o_pha,>o_php,>o_pla,>o_tax,>o_tay,>o_txa,>o_tya,>o_tsx
cijl    byte <cutdone,<o_ldai,<o_ldxi,<o_ldyi,<cutdone,<cutdone,<cutdone,<cutdone,<cutdone
        byte <o_arii,<o_cmpi,<o_cpxi,<o_cpyi
cijh    byte >cutdone,>o_ldai,>o_ldxi,>o_ldyi,>cutdone,>cutdone,>cutdone,>cutdone,>cutdone
        byte >o_arii,>o_cmpi,>o_cpxi,>o_cpyi

; cmput: the compare's immediate (orl/orh) came from the register's origin
; (ct2/ct): into the compares (the last one stays; uses a, x, y)
cmput   lda orl
        clc
        adc orh
        tax
        ldy #0
@p      lda cmkh,x
        beq @new
        cmp orh
        bne @nx
        lda cmk,x
        cmp orl
        beq @set
@nx     inx
        iny
        bne @p
        jmp ctfull              ; (all 256 places taken)
@new    lda orl
        sta cmk,x
        lda orh
        sta cmkh,x
@set    lda ct2
        sta cmv,x
        lda ct
        sta cmvh,x
        rts

; ------------------------------------------------------------
; setorg  the value stored at eal/eah came from x/a (high/low; x 0:
;         nowhere): noted in its page's origins (made when the page is
;         the tune's, or something comes from somewhere)
;   uses: a, x, y, ct, ct2
; ------------------------------------------------------------
setorg  sta ct2
        stx ct
        ldx eah
        lda orgl,x
        bne @w
        lda cpg,x
        bne @new
        lda ct
        beq @r
@new    jsr shnew
        bcc @w
        jmp ctfull
@w      lda orgl,x
        sta @l+2
        lda orgh,x
        sta @h+2
        ldy eal
        lda ct2
@l      sta $ff00,y
        lda ct
@h      sta $ff00,y
@r      rts

; shnew: page x's origins: two pages, each of the tune's bytes from itself,
; the rest from nowhere (c set: out of room; x kept)
shnew   jsr shalloc
        bcs @r
        sta orgl,x
        sta @l+2
        jsr shalloc
        bcs @r
        sta orgh,x
        sta @h+2
        lda cpg,x
        beq @ok
        jsr mkclr
        ldy #0
@b      tya
        jsr intun
        bcc @n
@l      sta $ff00,y
        txa
@h      sta $ff00,y
@n      iny
        bne @b
@ok     clc
@r      rts

; mkclr: fl_mk and fl_nm off everywhere: a page of the tune's has
; origins now, so an operand in it may come from elsewhere (x, y kept)
mkclr   stx mcx
        sty mcy
        ldx lopg
@p      lda fmap,x
        beq @n
        sta @g+2
        sta @s+2
        ldy #0
@g      lda $ff00,y
        and #255-fl_mk-fl_nm
@s      sta $ff00,y
        iny
        bne @g
@n      cpx hipg
        beq @r
        inx
        bne @p
@r      ldx mcx
        ldy mcy
        rts

; fmset: fmp = page x's flag map, made if it has none (c set: out of
; room; x kept)
fmset   lda fmap,x
        bne @h
        jsr fmalloc
        bcs @r
        sta fmap,x
@h      sta fmp+1
        lda #0
        sta fmp
        stx fmpg
        clc
@r      rts

; shalloc: a = a zeroed page for origins: the low list's, then the back
; of the pool's; fmalloc: from the back of the pool (c set: none left;
; x, y kept)
shalloc sty csy
        stx csx
        ldx ctli
        lda ctlow,x
        beq fmal2
        inc ctli
        bne zpage
fmalloc sty csy
        stx csx
fmal2   lda trfi
        cmp trbi
        bcs @full
        dec trbi
        ldx trbi
        jsr fmget
        jmp zpage
@full   jsr pgvict              ; none left: a tune page's the song hasn't
        bcc zpage               ; used (it leaves memory)
        ldx csx
        ldy csy
        sec
        rts
fmget   lda $ffff,x             ; (tr_pool's list)
        rts
zpage   sta @w+2
        pha
        lda #0
        tay
@w      sta $ff00,y
        iny
        bne @w
        pla
        ldx csx
        ldy csy
        clc
        rts

; ------------------------------------------------------------
; pgget   tune page x into memory (chome 0: it isn't), with the pages
;         after it that aren't either (pgmax in all, while there is
;         room): ct_read reads them into the pages of tune pages the song
;         hasn't used (pgvict; page x itself, if there are none, into the
;         back of the pool); trial.asm's tr_fetch, and the cut's reads of
;         the tune's bytes
;   out:  a = its real page (chome's; the trial's read table too)
;   uses: x, y kept
;   note: no room even for it: ct_abort
; ------------------------------------------------------------
pgget   stx pgsx
        sty pgsy
        stx pgx
        lda #0
        sta pgn
@n      lda pgx                 ; the next: in the tune, not in memory,
        clc                     ; and a page for it
        adc pgn
        bcs @rd
        tax
        cpx pghi
        beq @in
        bcs @rd
@in     lda chome,x
        bne @rd
        lda pgn                 ; (the pages after it only into a tune
        cmp #pgmax              ; page's: the pool is the emulator's)
        beq @rd
        cmp #0
        bne @v
        jsr pgframe
        jmp @f
@v      jsr pgvict
@f      bcs @nf
        ldy pgn
        sta pgfrm,y
        inc pgn
        bne @n
@nf     lda pgn
        bne @rd
        jmp (ct_abort)
@rd     lda pgn
        beq @x
        inc ct_reads
        jsr ctrd
        ldy #0                  ; where they are: chome, and the trial's
@s      tya                     ; read table where it reads them (0 there,
        clc                     ; but in the I/O: not in memory)
        adc pgx
        tax
        lda pgfrm,y
        sta chome,x
        cpx #$d0
        bcc @t
        cpx #$e0
        bcc @ns
@t      pha
        lda trrpt,x
        bne @nt
        pla
        sta trrpt,x
        pha
@nt     pla
@ns     iny
        cpy pgn
        bne @s
@x      ldx pgsx
        ldy pgsy
        lda chome,x
        rts
ctrd    jmp (ct_read)

; pgframe: a = a page to read a tune page into: a tune page's the song
; hasn't used (pgvict), else the back of the pool (c set: none; uses x, y)
pgframe jsr pgvict
        bcc @r
        lda trfi
        cmp trbi
        bcs @r
        dec trbi
        ldx trbi
        jsr fmget
        clc
@r      rts

; ------------------------------------------------------------
; pgvict  a = the page of a tune page the song hasn't used (no byte used,
;         no flag map, not kept), not the first or last (partly the
;         tune's), nor one in hand (the emulator's pc's and the next, the
;         page it stores into, the static walk's and the next): it leaves
;         memory (chome 0, and the trial's read table 0 if it read it
;         there), to be read again if it's needed. The farthest from pgx
;         first: from the tune's other end
;   out:  c set: none
;   uses: a, x, y
; ------------------------------------------------------------
pgvict  lda pglo                ; pgx in the tune's top half: from its
        clc                     ; start up, else from its end down
        adc pghi
        ror
        cmp pgx
        bcs @dn
        ldx pglo
        ldy #1
        bne @nx
@dn     ldx pghi
        ldy #$ff
@nx     sty pgstp               ; (the step)
        txa
        clc
        adc pgstp
        tax
        cpx pglo
        beq @no
        cpx pghi
        beq @no
        lda chome,x
        beq @nx2
        lda uflag,x
        ora fmap,x
        ora keep,x
        bne @nx2
        lda ct_aft              ; (cutafter's tune: not a pinned page)
        beq @np
        jsr ispin
        bcs @nx2
@np     cpx trpch
        beq @nx2
        cpx trpg
        beq @nx2
        cpx hpch
        beq @nx2
        dex
        cpx trpch
        beq @nx1
        cpx hpch
        beq @nx1
        inx
        lda chome,x             ; this one
        pha
        cmp trrpt,x
        bne @k
        lda #0
        sta trrpt,x
@k      lda #0
        sta chome,x
        pla
        clc
        rts
@nx1    inx
@nx2    ldy pgstp
        jmp @nx
@no     sec
        rts
ctrts   rts

; ------------------------------------------------------------
; cutpost  after the trace: the static walk, the compares' pages, the
;          pages kept, the cut built at ct_dst (sidstrip's cut_pages)
;   out:  ct_err, ct_first ... ct_play, ct_of, ct_kept
;   uses: a, x, y; runs with $01 = $34 (the flag maps may be under the
;         I/O), interrupts off
; ------------------------------------------------------------
cutpost lda #0
        sta ct_err
        php
        sei
        lda $01
        pha
        lda #$34
        sta $01
        jsr swalk               ; (c: out of room)
        bcs @room
        jsr ends
        bcs @room
        jsr pack
        jmp @x
@room   lda #1
        sta ct_err
@x      pla
        sta $01
        plp
        rts

; fbxy: a = the flag byte of x:y (0: no map; x, y kept)
fbxy    lda fmap,x
        beq @r
        sta @f+2
@f      lda $ff00,y
@r      rts
; fputxy: the flag byte of x:y (it has a map) = a (a, x, y kept)
fputxy  pha
        lda fmap,x
        sta @s+2
        pla
@s      sta $ff00,y
        rts
; fsetxy: a's bits set in the flag byte of x:y, its map made if need be
; (c set: out of room; x, y kept)
fsetxy  sta wv
        lda fmap,x
        bne @h
        jsr fmalloc
        bcs @r
        sta fmap,x
@h      sta @g+2
        sta @s+2
@g      lda $ff00,y
        ora wv
@s      sta $ff00,y
        clc
@r      rts
; wbyte: a = the file's byte at hpcl/hpch + y (x, y kept)
wbyte   stx pgox
        tya
        clc
        adc hpcl
        sta cp
        lda hpch
        adc #0
        tax
        lda chome,x
        bne @h
        jsr pgget
@h      sta cp+1
        sty ct2
        ldy #0
        lda (cp),y
        ldy ct2
        ldx pgox
        rts
; hpcplus: eal/eah = hpcl/hpch + a
hpcplus clc
        adc hpcl
        sta eal
        lda hpch
        adc #0
        sta eah
        rts

; ------------------------------------------------------------
; swalk   sidreloc's static_walk: from each branch, jmp and jsr run, the
;         ways not taken decoded in the file's bytes until they end (rts,
;         rti, jmp) or join code run or walked; in them an absolute
;         operand inside the tune is marked, and their bytes used. A way
;         that runs into a byte no official instruction starts with, a
;         brk, or out of the tune is data: nothing in it noted.
;   out:  c set: out of room
;   uses: a, x, y, hpcl/hpch, eal/eah, cp, ct2
; ------------------------------------------------------------
swalk   ldx lopg                ; the ways on from what ran: pending
@pg     lda fmap,x
        beq @np
        ldy #0
@b      jsr fbxy
        lsr
        bcc @nb
        sty hpcl
        stx hpch
        lda #2                  ; (a + 2 below the tune's end)
        jsr hpcplus
        lda eah
        cmp hipg
        bcc @ex
        bne @nb2
        lda eal
        cmp lastlo
        beq @ex
        bcs @nb2
@ex     jsr exits
        bcs @r
@nb2    ldx hpch
        ldy hpcl
@nb     iny
        bne @b
@np     cpx hipg
        beq @w
        inx
        bne @pg
@w      lda #0                  ; each pending one walked, until none
        sta wfound
        ldx lopg
@wp     lda fmap,x
        beq @wn
        ldy #0
@wb     jsr fbxy
        and #fl_pend
        beq @wnb
        jsr fbxy                ; (off the pending)
        and #255-fl_pend
        jsr fputxy
        and #fl_run+fl_done     ; (run or walked already: nothing)
        bne @wnb
        lda #1
        sta wfound
        jsr walk
        bcs @r
@wnb    iny
        bne @wb
@wn     cpx hipg
        beq @wd
        inx
        bne @wp
@wd     lda wfound
        bne @w
        clc
@r      rts

; exits: the ways on from the instruction at hpcl/hpch (the file's
; bytes): a branch's two, a jmp's, a jsr's and the one after it: pending
; (c set: out of room; uses a, x, y)
exits   ldy #0
        jsr wbyte
        tax
        lda ctmod,x
        cmp #11
        beq @br
        lda ctop,x
        cmp #15
        beq @jsr
        cmp #16
        beq @jmp
        clc
        rts
@br     ldy #1
        jsr wbyte
        sta woff
        lda #2                  ; a + 2
        jsr hpcplus
        jsr pend
        bcs @r
        lda woff                ; + the offset (signed)
        clc
        adc eal
        sta eal
        lda woff
        and #$80
        beq @p
        lda #$ff
@p      adc eah
        sta eah
        jmp pend
@jsr    lda #3                  ; a + 3
        jsr hpcplus
        jsr pend
        bcs @r
@jmp    ldy #1                  ; its target
        jsr wbyte
        sta eal
        iny
        jsr wbyte
        sta eah
        jmp pend
@r      rts
; pend: eal/eah pending, when it is one of the tune's bytes (c set: out
; of room; uses a, x, y)
pend    ldx eah
        lda eal
        jsr intun
        bcc @r
        tay
        lda #fl_pend
        jmp fsetxy
@r      clc
        rts

; walk: the way from x:y (the file's bytes): first to its end, then, when
; it ends well, again noting it (c set: out of room; x, y kept)
walk    stx wsh
        sty wsl
        stx hpch
        sty hpcl
        lda #0
        sta wroom
        jsr wpath
        bcc @x                  ; (data: nothing noted)
        ldx wsh
        ldy wsl
        stx hpch
        sty hpcl
        lda #1
        jsr wpath
@x      ldx wsh
        ldy wsl
        lda wroom
        lsr
        rts
; wpath: along the way from hpcl/hpch; a = 0: c set when it ends well, a
; = 1: each instruction noted (wnote; out of room: wroom)
wpath   sta wmode
@i      ldx hpch                ; joins code run or walked: ends well
        ldy hpcl
        jsr fbxy
        and #fl_run+fl_done
        bne @ok
        lda hpcl                ; out of the tune, a brk, not an official
        jsr intun               ; instruction, or past the tune's end: data
        bcc @bad
        ldy #0
        jsr wbyte
        sta cop
        cmp #0
        beq @bad
        lsr
        lsr
        lsr
        tax
        lda cop
        and #7
        tay
        lda ctoff,x
        and trbit,y
        beq @bad
        ldx cop
        lda ctmod,x
        sta cmo
        tax
        lda cmlen,x
        sta wlen
        sec                     ; its last byte: a + length - 1
        sbc #1
        jsr hpcplus
        bcs @bad                ; (past $ffff)
        lda eah
        cmp hipg
        bcc @in
        bne @bad
        lda eal
        cmp lastlo
        beq @in
        bcs @bad
@in     lda wmode
        beq @nx
        jsr wnote
        bcs @room
@nx     lda cop                 ; rts, rti, jmp: its end
        cmp #$60
        beq @ok
        cmp #$40
        beq @ok
        cmp #$4c
        beq @ok
        cmp #$6c
        beq @ok
        lda wlen
        clc
        adc hpcl
        sta hpcl
        bcc @i
        inc hpch
        jmp @i
@ok     sec
        rts
@room   lda #1
        sta wroom
@bad    clc
        rts
; wnote: the instruction at hpcl/hpch walked (cop, cmo, wlen): done, its
; bytes used, its absolute operand in the tune marked, its ways on pending
; (c set: out of room)
wnote   ldx hpch
        ldy hpcl
        lda #fl_done
        jsr fsetxy
        bcs @r
        lda wlen
        sta wcnt
        lda hpcl
@u      jsr usedin              ; (x = hpch: kept)
        dec wcnt
        beq @m
        clc
        adc #1
        bne @u
        inx
        bne @u
@m      lda cmo                 ; abs, abs,x, abs,y, (ind)
        cmp #5
        bcc @e
        cmp #8
        bcc @mk
        cmp #10
        bne @e
@mk     ldy #1                  ; its operand in the tune: a + 2 marked
        jsr wbyte
        sta eal
        iny
        jsr wbyte
        tax
        lda eal
        jsr intun
        bcc @e
        lda #2
        jsr hpcplus
        ldx eah
        ldy eal
        lda #fl_mark
        jsr fsetxy
        bcs @r
@e      jmp exits
@r      rts

; ------------------------------------------------------------
; ends    each compare whose register came from a marked byte: its
;         immediate a page's end (sidreloc's cmp_marks)
;   out:  c set: out of room
; ------------------------------------------------------------
ends    lda #0
        sta wcnt
@l      ldx wcnt
        lda cmkh,x
        beq @n
        lda cmv,x               ; where the register came from: marked?
        tay
        lda cmvh,x
        tax
        tya
        jsr intun
        bcc @n
        jsr fbxy
        and #fl_mark
        beq @n
        ldx wcnt                ; the immediate: an end
        lda cmk,x
        tay
        lda cmkh,x
        tax
        lda #fl_end
        jsr fsetxy
        bcs @r
@n      inc wcnt
        bne @l
        clc
@r      rts

; ------------------------------------------------------------
; pack    the pages used kept too; each kept page's place in the cut
;         (pmap: in order from the first kept; cutafter's tune: round
;         its longest run, aplace); the bytes from the first used to the
;         last copied to ct_dst; the address bytes moved (remap); init
;         and play (cutafter's: the stub after the last byte, astub)
;   out:  ct_err (2 over 4096 bytes, 3 the first byte's page moved, or
;         cutafter's pages can't be placed), ct_first ... ct_play, ct_of,
;         ct_kept
; ------------------------------------------------------------
pack    ldx lopg                ; the pages used: kept
@k      lda uflag,x
        beq @k1
        cpx ct_stp              ; (cutafter's stub's page: not one)
        beq @k1
        sta keep,x
@k1     cpx hipg
        beq @k2
        inx
        bne @k
@k2     ldx lopg                ; the first kept: their places from it
@f      lda keep,x
        bne @f1
        inx
        bne @f
@f1     stx wv
        lda ct_aft              ; cutafter's: round the longest run
        beq @pl
        jsr aplace
        bcc @pl
        jmp @bad
@pl     lda #0
        sta ct_kept
        ldx lopg
@m      lda keep,x
        beq @m1
        lda wv
        sta pmap,x
        inc wv
        inc ct_kept
@m1     cpx hipg
        beq @m2
        inx
        bne @m
@m2     lda hipg
        sec
        sbc lopg
        clc
        adc #1
        ldx ct_aft              ; (cutafter's: the whole tune's)
        beq @of
        lda aof
@of     sta ct_of
        ldx umnh                ; (the first byte's page where it was,
        lda pmap,x              ; but in cutafter's tune)
        sta ctnfh
        ldx ct_aft
        bne @ln
        cmp umnh
        bne @bad
@ln     lda umxl                ; the length: new(last) + 1 - first (and
        clc                     ; cutafter's stub)
        adc #1
        sta ct_len
        ldx umxh
        lda pmap,x
        adc #0
        sta ct_len+1
        lda ct_len
        sec
        sbc umnl
        sta ct_len
        lda ct_len+1
        sbc ctnfh
        sta ct_len+1
        lda ct_aft
        beq @l2
        lda ct_len
        clc
        adc ct_stn
        sta ct_len
        bcc @l2
        inc ct_len+1
@l2     lda ct_len+1
        cmp #>4096              ; over 4096 bytes: no
        bcc @ok
        bne @big
        lda ct_len
        beq @ok
@big    lda #2
        sta ct_err
        rts
@bad    lda #3
        sta ct_err
        rts
@ok     lda umnl
        sta ct_first
        lda ctnfh
        sta ct_first+1
        ldx umnh                ; each kept page's bytes from the first to
@c      lda keep,x              ; the last: at ct_dst + its place - the
        beq @cn                 ; first's
        lda pmap,x
        clc
        adc ct_dst
        sec
        sbc ctnfh
        sta @d+2
        lda chome,x             ; (read in if need be)
        bne @in
        jsr pgget
@in     sta @s+2
        ldy #0
        cpx umnh
        bne @c1
        ldy umnl
@c1     lda #$ff
        cpx umxh
        bne @c2
        lda umxl
@c2     sta wcnt
@s      lda $ff00,y
@d      sta $ff00,y
        cpy wcnt
        beq @cn
        iny
        bne @s
@cn     cpx umxh
        beq @rm
        inx
        bne @c
@rm     jsr remap
        lda ct_aft              ; cutafter's: init the stub, after the
        beq @ni                 ; last byte
        jsr astub
        jmp @np
@ni     lda tr_init
        ldx tr_init+1
        jsr newa
        sta ct_init
        stx ct_init+1
@np     lda tr_play
        ldx tr_play+1
        jsr newa
        sta ct_play
        stx ct_play+1
        rts
; newa: x:a (high/low) where it is in the cut, a tune byte (else as it is)
newa    jsr intun
        bcc @r
        pha
        lda pmap,x
        tax
        pla
@r      rts

; remap: each marked byte (and each end) from the first to the last, in a
; kept page: in the cut, a page kept becomes its place; an end whose page
; went, but whose page before stayed, the page after that one's place; one
; whose page went but whose next page stayed, the page before that one's
remap   ldx lopg
@p      lda fmap,x
        beq @np
        sta @f+2
        ldy #0
@f      lda $ff00,y
        and #fl_mark+fl_end
        beq @nb
        sta wbits
        lda pmap,x              ; (kept, from the first to the last)
        beq @nb
        cpx umnh
        bcc @nb
        bne @a1
        cpy umnl
        bcc @nb
@a1     cpx umxh
        bcc @a2
        bne @nb
        cpy umxl
        beq @a2
        bcs @nb
@a2     lda pmap,x              ; its byte in the cut
        clc
        adc ct_dst
        sec
        sbc ctnfh
        sta @g+2
        sta @w+2
        stx csx
@g      lda $ff00,y
        sta wv
        tax
        lda pmap,x              ; its page kept
        bne @w
        lda wbits               ; an end: the page before kept
        and #fl_end
        beq @v1
        ldx wv
        beq @v1
        dex
        lda pmap,x
        beq @v1
        clc
        adc #1
        jmp @w
@v1     ldx wv                  ; the page after kept
        inx
        beq @no
        lda pmap,x
        beq @no
        sec
        sbc #1
@w      sta $ff00,y
@no     ldx csx
@nb     iny
        bne @f
@np     cpx hipg
        beq @r
        inx
        jmp @p
@r      rts

; ------------------------------------------------------------
; aplace  (pack, cutafter's tune) the first kept page's place: the
;         longest run of kept pages that follow one another (the first
;         such) keeps its own, the rest round it; or, if that puts a page
;         below $0200, in $d000-$dfff or past $ff, or the stub (after the
;         last byte) in $d000-$dfff or past $ffff, its own (wv); else c
;         set (sidstrip's pack, fits)
;   in:   wv = the first kept page
;   out:  wv = its place; c set: none fits
; ------------------------------------------------------------
aplace  lda #0
        sta nk
        sta bestn
        sta runn
        ldx lopg
@s      lda keep,x
        beq @gap
        cpx umxh                ; (the last byte's page: its place)
        bne @s1
        lda nk
        sta ixl
@s1     lda runn                ; on a run, or a run's first
        bne @on
        stx runp
        lda nk
        sta runi
@on     inc runn
        lda runn                ; the longest yet (the first, if as long)
        cmp bestn
        bcc @s3
        beq @s3
        sta bestn
        lda runp
        sta bestp
        lda runi
        sta besti
@s3     inc nk
        jmp @sn
@gap    lda #0
        sta runn
@sn     cpx hipg
        beq @d
        inx
        bne @s
@d      lda bestp               ; the run's first keeps its place
        sec
        sbc besti
        bcc @own                ; (below page 0)
        jsr aok
        bcc @r
@own    lda wv                  ; else each its own
        jsr aok
@r      rts

; aok: the first kept page at a: the pages and the stub fit? (c clear:
; wv = a)
aok     sta ctbase
        cmp #2                  ; from $0200
        bcc @no
        lda nk                  ; to $ffff
        sec
        sbc #1
        clc
        adc ctbase
        bcs @no
        sta ctlast
        lda ctbase              ; not in $d000-$dfff
        cmp #$e0
        bcs @st
        lda ctlast
        cmp #$d0
        bcs @no
@st     lda ixl                 ; the stub's first byte: new(last) + 1
        clc
        adc ctbase
        sta eh
        lda umxl
        clc
        adc #1
        sta el
        lda eh
        adc #0
        sta eh
        bcs @no
        lda el                  ; ... past its last
        clc
        adc ct_stn
        sta ndl
        lda eh
        adc #0
        sta ndh
        bcc @in
        ora ndl                 ; ($10000 itself: past $dfff, fine)
        bne @no
        beq @ok
@in     lda eh                  ; not in $d000-$dfff: from $e000, or
        cmp #$e0                ; ending by $d000
        bcs @ok
        lda ndh
        cmp #$d0
        bcc @ok
        bne @no
        lda ndl
        bne @no
@ok     lda ctbase
        sta wv
        clc
        rts
@no     sec
        rts

; ------------------------------------------------------------
; astub  (pack) cutafter's stub just after the last byte kept: its bytes
;        into the cut, each marked one (or end) moved as remap moves
;        one (rmval); ct_init there
; ------------------------------------------------------------
astub   lda umxl                ; its place: new(last) + 1
        clc
        adc #1
        sta ct_init
        ldx umxh
        lda pmap,x
        adc #0
        sta ct_init+1
        sec                     ; in the cut: from ct_dst, as the first
        sbc ctnfh               ; byte's page is there
        clc
        adc ct_dst
        sta cp+1
        lda ct_init
        sta cp
        ldx ct_stp
        lda chome,x             ; (its page: pinned, in memory)
        sta @s+2
        lda fmap,x              ; (its flag map, if it has one)
        sta @f+2
        ldy #0
@c      cpy ct_stn
        beq @r
@s      lda $ff00,y
        sta wv
        lda @f+2
        beq @w
@f      lda $ff00,y
        and #fl_mark+fl_end
        beq @w
        sta wbits
        lda wv
        jsr rmval
        sta wv
@w      lda wv
        sta (cp),y
        iny
        bne @c
@r      rts

; rmval: a marked byte's value (a; wbits its flags) moved as remap moves
; one: a page kept, its place; an end whose page went but whose page
; before stayed, the page after that one's place; one whose page went
; but whose next page stayed, the page before that one's; else as it is
; (x, y kept)
rmval   stx csx
        sta ctv
        tax
        lda pmap,x
        bne @r
        lda wbits
        and #fl_end
        beq @v1
        ldx ctv
        beq @v1
        dex
        lda pmap,x
        beq @v1
        clc
        adc #1
        jmp @r
@v1     ldx ctv
        inx
        beq @no
        lda pmap,x
        beq @no
        sec
        sbc #1
        jmp @r
@no     lda ctv
@r      ldx csx
        rts

; ---- the opcodes (sim6502's DECODE; tests/cuttest.py checks them)
; the mode by opcode: 0 none, 1 #, 2 zp, 3 zp,x, 4 zp,y, 5 abs, 6 abs,x, 7 abs,y,
; 8 (zp,x), 9 (zp),y, 10 (ind), 11 a branch (sim6502's DECODE; dop, top: none)
ctmod   byte 0,8,0,8,0,2,2,2,0,1,0,1,0,5,5,5
        byte 11,9,0,9,0,3,3,3,0,7,0,7,0,6,6,6
        byte 5,8,0,8,2,2,2,2,0,1,0,0,5,5,5,5
        byte 11,9,0,9,0,3,3,3,0,7,0,7,0,6,6,6
        byte 0,8,0,8,0,2,2,2,0,1,0,1,5,5,5,5
        byte 11,9,0,9,0,3,3,3,0,7,0,7,0,6,6,6
        byte 0,8,0,8,0,2,2,2,0,1,0,1,10,5,5,5
        byte 11,9,0,9,0,3,3,3,0,7,0,7,0,6,6,6
        byte 0,8,0,8,2,2,2,2,0,0,0,0,5,5,5,5
        byte 11,9,0,0,3,3,4,4,0,7,0,0,0,6,0,0
        byte 1,8,1,8,2,2,2,2,0,1,0,0,5,5,5,5
        byte 11,9,0,9,3,3,4,4,0,7,0,0,6,6,7,7
        byte 1,8,0,8,2,2,2,2,0,1,0,1,5,5,5,5
        byte 11,9,0,9,0,3,3,3,0,7,0,7,0,6,6,6
        byte 1,8,0,8,2,2,2,2,0,1,0,0,5,5,5,5
        byte 11,9,0,9,0,3,3,3,0,7,0,7,0,6,6,6
; the operation by opcode: 1 lda 2 ldx 3 ldy 4 lax 5 sta 6 stx 7 sty 8 sax
; 9 adc sbc ora eor and, 10 cmp 11 cpx 12 cpy 13 bit 14 inc dec and the shifts
; (memory), 15 jsr 16 jmp abs 17 jmp (ind) 18 rts 19 pha 20 php 21 pla 22 tax
; 23 tay 24 txa 25 tya 26 tsx, 0 the rest
ctop    byte 0,9,0,0,0,9,14,0,20,9,0,0,0,9,14,0
        byte 0,9,0,0,0,9,14,0,0,9,0,0,0,9,14,0
        byte 15,9,0,0,13,9,14,0,0,9,0,0,13,9,14,0
        byte 0,9,0,0,0,9,14,0,0,9,0,0,0,9,14,0
        byte 0,9,0,0,0,9,14,0,19,9,0,0,16,9,14,0
        byte 0,9,0,0,0,9,14,0,0,9,0,0,0,9,14,0
        byte 18,9,0,0,0,9,14,0,21,9,0,0,17,9,14,0
        byte 0,9,0,0,0,9,14,0,0,9,0,0,0,9,14,0
        byte 0,5,0,8,7,5,6,8,0,0,24,0,7,5,6,8
        byte 0,5,0,0,7,5,6,8,25,5,0,0,0,5,0,0
        byte 3,1,2,4,3,1,2,4,23,1,22,0,3,1,2,4
        byte 0,1,0,4,3,1,2,4,0,1,26,0,3,1,2,4
        byte 12,10,0,0,12,10,14,0,0,10,0,0,12,10,14,0
        byte 0,10,0,0,0,10,14,0,0,10,0,0,0,10,14,0
        byte 11,9,0,0,11,9,14,0,0,9,0,0,11,9,14,0
        byte 0,9,0,0,0,9,14,0,0,9,0,0,0,9,14,0
; the official opcodes, a bit each (sidreloc's OFFICIAL: the static walk)
ctoff   byte 99,103,99,99,115,119,99,99,99,119,99,99,99,119,99,99
        byte 114,117,115,39,119,119,115,119,115,119,99,99,115,119,99,99
