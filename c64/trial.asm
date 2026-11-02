; ------------------------------------------------------------
; trial.asm  -  a .sid tune's trial run, in a 6502 emulator
;
; SlopLoad 64 vets a tune as tools/sidstrip.py does (strip(), TuneSim
; and StripSim are the spec): init once, the play routine tr_calls
; times, noting what the tune touches. The tune runs in an emulated
; 6510 with a memory of its own: its tables in $a000-$aaff, and the
; pages of tr_pool's list ($ab-$bf by default) for what it writes:
;   - each virtual page has a real page to read (trrpt): the tune's
;     bytes at tr_src (or where tr_home's table says: a tune page not in
;     memory reads 0 there, and is read in at its first use, tr_fetch),
;     a scratch copy once it writes the page (its bytes stay as they
;     are), RAM it wrote, or zeros; 0 for the I/O (trrdio);
;   - and to write (trwpt): a scratch page written straight ($80 up),
;     or a class for trws: RAM never written, workspace and the tune's
;     first and last pages (a map page beside each: a byte a byte), zero
;     page, stack, SID, VIC/CIAs, and the loader's places (sidstrip's
;     harmful);
;   - the pc is a page (trpch, real page in trpcp) and an offset in y;
;     an instruction at a page's last 3 bytes runs from a copy (tredge);
;     a jump out of the tune's whole pages is checked (trchk);
;   - the commonest opcodes have handlers of their own, the rest are
;     decoded (trgen); cycles are the real NMOS counts, added after.
;     Of the illegal opcodes sim6502 runs, only lax, sax and the nops run
;     here (the others are refused, 12: one tune in 400 in HVSC ran any:
;     lax).
; Flags: z and n as bytes (trnzl, trnzh), c in trrc; adc/sbc run on the
; real cpu with the tune's c, d and v (i set).
; trial: one run. tstrip: the whole check. Called with interrupts on
; and $01 = $36; they run with $01 = $34 (all RAM), interrupts off, and
; put both back. tr_stop: RUN/STOP stops a run (16); tr_cut: tr_hook is
; called after each run's setup (sidcut.asm's trace).
; ------------------------------------------------------------

; ---- zero page ($40-$5f)
trpcp  = $40                    ; (2) the real page of the pc's page (low byte 0)
trptr  = $42                    ; (2) a pointer
trra   = $44                    ; the tune's a, x, y, s
trrx   = $45
trry   = $46
trrs   = $47
trnzl  = $48                    ; its flags: z set when this is 0,
trnzh  = $49                    ; n is bit 7 of this,
trrc   = $4a                    ; c is bit 0 of this,
trrp   = $4b                    ; v (bit 6) and d (bit 3)
trclk  = $4c                    ; (3) cycles since the call began
trpcl  = $4f                    ; a store's opcode offset (for its pc), and
trpch  = $50                    ; the pc's page
trlo   = $51                    ; an address read or written: low byte (page in x)
trv    = $52                    ; the value written
trt    = $53                    ; temporaries
trt2   = $54
trt3   = $55
trt4   = $56
tredgy = $57                    ; the instruction run from the edge buffer: offset
tredgp = $58                    ; ... and page (as trpcl, trpch)
trcol  = $59                    ; trgen: the mode
trfrm  = $5a                    ; (2) play calls done (0 during init)
trpg   = $5c                    ; the slow path's page
trcl   = $5d                    ; ... and its class
trcls  = $5e                    ; trgen: the operation's place in trops (its class)
trstr  = $5f                    ; 1: tstrip (0: trial)

; ---- scratch ($a000-$bfff)
trrpt  = $a000                  ; read page table: real page, 0 = I/O
trwpt  = $a100                  ; write page table: $a0-$bf a real page, else a class:
                                ;   +$40 when the loader minds some addresses in it, and
                                ;   $00 RAM never written, $01 workspace (map: the next page),
                                ;   $10 a tune page not copied yet, $11 copied,
                                ;   $20 zero page, $21 stack, $22 SID, $23 VIC/CIAs/...
trzpg  = $a200                  ; the tune's zero page
trstk  = $a300                  ; its stack page
trzpw  = $a400                  ; zero page written: not 0 per address
trzero = $a500                  ; zeros: RAM never written reads these
trtab  = $a600                  ; the dispatch: a handler per opcode (2 pages)
trgmt  = $a800                  ; trgen: each opcode's addressing mode
trgot  = $a900                  ; ... and operation (its place in trops)
trvp   = $aa00                  ; variables (trrnd ...); the edge buffer at its end
trtb   = $aafc                  ; the edge buffer: an instruction's 3 bytes
                                ; the pool: tr_pool's pages ($ab-$bf if no other)
trrnd  = $aa01                  ; oscillator 3
trrun  = $aa02                  ; 1, or 2 (tstrip's second run)
trsp0  = $aa03                  ; the host's stack pointer in trcall
trxpc  = $aa04                  ; (2) the current instruction's pc
trlstl = $aa06                  ; the tune's last byte
trlsth = $aa07
trdlt  = $aa08                  ; tr_src's page less tr_load's
trlln  = $aa09                  ; (2) the raster: its line,
trlc   = $aa0b                  ; ... and cycle in it
tr1s   = $aa0c                  ; (4) run 1's checksum (tstrip)
trz0   = $aa10                  ; from here to trz1: zero at each run's start
trios  = $aa10                  ; I/O page $d0+i: its shadow, 0 = never written (16)
trerr  = $aa20                  ; the run's own refusal (10-13), its pc in trxpc
trlimo = $aa21                  ; the call's limit: trlimt+this (0 init, 3 play)
trxof  = $aa22                  ; 1: code run outside the tune, in memory it didn't write
trxo   = $aa23                  ; (2) ... the first such pc
trbadv = $aa25                  ; the lowest $01 value with I/O out, eor $ff (0: none)
trmirf = $aa26                  ; 3: wrote a second SID's registers while playing
trmir  = $aa27                  ; (2) ... the first
trstkm = $aa29                  ; the highest stack byte stored to directly ($80+), 0 none
trlftf = $aa2a                  ; run 2: 14 when it still wrote what the loader can't allow
trlft  = $aa2b                  ; (2) ... the first
trdig  = $aa2d                  ; (5) play calls done: a digit a byte (trprog)
trmax  = $aa32                  ; (3) the longest play call
trs1   = $aa35                  ; (2) the SID writes' checksum
trs2   = $aa37                  ; (2)
trcs   = $aa39                  ; (2) the play call's start: low 16 bits of the clock
trln0  = $aa3b                  ; (2) the play calls' start: the line,
trr0   = $aa3d                  ; ... and cycle in it
tri    = $aa3e                  ; the tune's i flag (bit 2)
trhov  = $aa3f                  ; more than 32 stores to patch
trz1   = $aa40
trfi   = $aa40                  ; the pool: the next page from the list's front,
trbi   = $aa41                  ; ... and past the last one free at its back
trpa   = $aa42                  ; trpair's first page

; ---- the interface
tr_load  word 0                 ; in: the tune's load address,
tr_len   word 0                 ; its length,
tr_src   word 0                 ; where its bytes are now (low byte as tr_load's),
tr_init  word 0                 ; init and play,
tr_play  word 0
tr_song  byte 0                 ; a for init,
tr_calls word 0                 ; the play calls,
tr_scr   word 0                 ; screen RAM for the count (0: none)
tr_pool  word trpdef            ; the pages it may use ($80 up: a page below
                                ; would read as a class): a list, 0 at its end
tr_stop  byte 0                 ; 1: RUN/STOP stops it (refusal 16)
tr_cut   byte 0                 ; 1: tr_hook called after each run's setup
tr_hook  word trrts             ; (the cut's trace: sidcut.asm)
tr_home  byte 0                 ; 0: the tune's bytes at tr_src; else the page
                                ; of a table: each tune page's real page, 0
                                ; when not in memory (trial only, not tstrip)
tr_fetch word trrts             ; ... page x into memory: a = its real page
                                ; (x, y kept; sidcut.asm's pgget)
tr_slog  word 0                 ; init's SID writes noted here (0: not): a
                                ; register (0-31) and its value each, 64 at
                                ; most (sidcut.asm's after-init stub)
tr_nslog byte 0                 ; out: how many ($ff: more than 64)
tr_err   byte 0                ; out: 0, or why it is refused (1-15),
tr_erra  word 0                 ; the address involved,
tr_errv  byte 0                 ; a value ($01's),
tr_nws   byte 0                 ; workspace runs (tr_ws),
tr_cyc   word 0                 ; the longest play call, cycles (jsr+rts included),
tr_latch word 0                 ; CIA 1 timer A's latch as the tune left it,
tr_zp    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tr_ws    byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
         byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
tr_npat  byte 0                 ; the stores to patch (tr_pat, ascending)
tr_pat   byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
         byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; ------------------------------------------------------------
; trial   one run: init once (a = tr_song), then tr_calls play calls
; tstrip  the whole check: trial, then (no refusal, stores to patch)
;         the patches into the tune's bytes at tr_src (nop #, and a nop
;         for a 3-byte store) and a second run: it must write nothing
;         the loader can't allow (14), the same SID writes (15)
;   in:   tr_load ... tr_scr
;   out:  tr_err ... tr_pat (the first run's; tr_pat the stores to
;         patch: patched by tstrip, and left so when it refuses 14/15)
;   uses: a, x, y, $40-$5f, $a000-$bfff
;   note: a store that writes both what the loader can't allow and
;         other memory (sidstrip's 6) is refused only when it does it
;         through a pointer (8) or the patched tune plays differently;
;         an odd store (9: the tune rewrote its own store's opcode) is
;         left to the second run (14, 15)
; ------------------------------------------------------------
trial   lda #0
        byte $2c                ; (bit abs: skips the lda)
tstrip  lda #1
        php
        sei
        cld
        sta trstr
        lda $01
        pha
        lda #$34                ; (all RAM: the pool may be under the I/O)
        sta $01
        lda #0
        sta tr_npat
        lda #1
        jsr trgo
        ldx #3                  ; run 1's checksum (sidcut.asm's too)
@s      lda trs1,x
        sta tr1s,x
        dex
        bpl @s
        jsr trfin
        lda trstr
        beq @x
        lda tr_err
        bne @x
        ora tr_npat
        beq @x
        jsr trpatch
        lda #2
        jsr trgo
        jsr trfin2
@x      pla
        sta $01
        plp
        rts

; ------------------------------------------------------------
; trgo    one run: init, then the play calls
;   in:   a = 1, or 2 (tstrip's second run)
;   out:  trerr (0, 10-13), trxpc; the run's notes
;   uses: a, x, y
; ------------------------------------------------------------
trgo    sta trrun
        lda #0                  ; (init's SID writes: none noted yet)
        sta tr_nslog
        jsr trsetup             ; (init: trlimo 0)
        lda tr_cut              ; the cut's trace: its own setup
        beq @nc
        jsr trhk
@nc     lda tr_song
        ldx #0
        jsr trcall
        bne @err
        jsr trline              ; play calls start where init ended,
        ldx #2                  ; a frame apart
@t      lda trlln,x
        sta trln0,x
        dex
        bpl @t
        lda trclk
        sta trcs
        lda trclk+1
        sta trcs+1
        lda #3                  ; a play call's limit
        sta trlimo
@call   lda trfrm
        cmp tr_calls
        lda trfrm+1
        sbc tr_calls+1
        bcs @done
        inc trfrm
        bne @f
        inc trfrm+1
@f      lda #0                  ; the SID log: a new call
        ldy #$40
        jsr trsum
        lda #0
        ldx #2
        jsr trcall
        bne @err
        lda trmax               ; the longest
        cmp trclk
        lda trmax+1
        sbc trclk+1
        lda trmax+2
        sbc trclk+2
        bcs @nl
        ldx #2
@m      lda trclk,x
        sta trmax,x
        dex
        bpl @m
@nl     lda trcs                ; the next call a PAL frame on: 19656 cycles
        clc
        adc #<19656
        sta trcs
        lda trcs+1
        adc #>19656
        sta trcs+1
        jsr trprog
        bcc @call
        lda #16                 ; run/stop
        bne @err
@done   lda #0
@err    sta trerr
        rts
trhk    jmp (tr_hook)
; ------------------------------------------------------------
; trcall  one call of the tune, as sim6502's: s = $ff with a return to
;         $fffe pushed, x = y = 0, the flags as they were
;   in:   x = 0 (init) or 2 (play): the address at tr_init+x, a = the
;         tune's a, trlimo
;   out:  a = 0 (it returned) or a refusal (10-13), z set by a
;   uses: a, x, y
; ------------------------------------------------------------
trcall  sta trra
        ldy tr_init,x
        lda tr_init+1,x
        sta trpch
        tsx
        stx trsp0
        lda #$ff
        sta trstk+$ff
        lda #$fd
        sta trstk+$fe
        sta trrs
        lda #0
        sta trrx
        sta trry
        sta trclk
        sta trclk+1
        sta trclk+2
        jsr trnorm
        jsr trmapc
        jmp trnext
; trdone: the call returned to $fffe (or ran a brk); trfail: a refusal
; in a (10-13), from anywhere in the run: back to trcall's caller
trdone  lda #0
trfail  ldx trsp0
        txs
        cmp #0
        rts

; ------------------------------------------------------------
; the dispatch, and the cycles: trnN adds N cycles (trn4c 4 + c,
; trnadd a)
; ------------------------------------------------------------
trn6    lda #6
        bne trnadd
trn5    lda #5
        bne trnadd
trn3    lda #3
        bne trnadd
trn7    lda #7
        bne trnadd
trn2    lda #2
trnadd  clc
        adc trclk
        sta trclk
        bcc trnext
        bcs trcarj
trn4    clc
trn4c   lda trclk
        adc #4
        sta trclk
        bcc trnext
trcarj  jsr trcarry
; trnext: y = the next opcode's offset. Its first 3 bytes become jmp
; trdone when the tune has returned to $fffe
trnext  cpy #$fd
        bcs tredge
trnx2   lda (trpcp),y           ; (sidcut.asm puts a jmp to its hook
        asl                     ; over these 3 bytes)
trnx3   bcc @l
        sta @h+1
@h      jmp (trtab+256)
@l      sta @lj+1
@lj     jmp (trtab)

; ------------------------------------------------------------
; tredge  the instruction at a page's last 3 bytes: its bytes into the
;         edge buffer (from the next page as needed) and run there;
;         after it (y past the buffer's start, $fd-$ff too), trfix:
;         the pc after it
;   in:   y = $fd-$ff
; ------------------------------------------------------------
tredge  lda trpcp+1
        cmp #>trvp
        beq trfix
        sty tredgy
        lda trpch
        sta tredgp
        ldx #0
@c      lda (trpcp),y           ; its 3 bytes, from the next page past
        sta trtb,x              ; the end
        inx
        cpx #3
        beq @d
        iny
        bne @c
        stx trt
        ldx trpch
        inx
        jsr trcpage
        sta trpcp+1
        ldx trt
        bne @c
@d      lda #>trvp
        sta trpcp+1
        ldy #<trtb
tredj   jmp trnx2               ; (sidcut.asm: to its hook's edge way)
trfix   tya                     ; on: the edge pc + its length
        sbc #<trtb+1            ; (c set)
        adc tredgy
        tay
        lda tredgp
        adc #0
        sta trpch
        jsr trmapc
        jmp trnext
; trnorm: trnext as it is; trjmp: trnext jumps to a/x
trnorm  lda #$c0                ; cpy #$fd : bcs
        sta trnext
        lda #$fd
        ldx #$b0
        bne trjmp2
trjmp   pha
        lda #$4c
        sta trnext
        pla
trjmp2  sta trnext+1
        stx trnext+2
        rts

; ------------------------------------------------------------
; trmapc  the pc's page changed: its real page; out of the tune's
;         whole pages, trchk: the call's end ($fffe), or code outside
;         the tune: in memory it wrote, or the pc noted (refusal 1:
;         the first)
;   in:   trpch, y
;   uses: a, x (y kept)
; ------------------------------------------------------------
trmapc  ldx trpch
        jsr trcpage
        sta trpcp+1
        lda trwpt,x             ; a whole tune page: copied, or not yet
        bmi @t
        and #$3e
        cmp #$10
        bne trchk
@t      cpx #$ff
        beq trchk
        rts
trchk   cpx #$ff
        bne @t
        cpy #$fd
        beq @r
        bcc @t
        cpy #$fe
        bne @t
        lda #<trdone            ; after this instruction
        ldx #>trdone
        jmp trjmp
@t      sty trxpc
        stx trxpc+1
        jsr trintun
        bcs @r
        txa
        bne @n1
        lda trzpw,y             ; zero page: that byte written?
        bne @r
        beq @no
@n1     lda trwpt,x             ; workspace: its map
        and #$3f
        cmp #1
        bne @no
        lda trrpt,x
        tax
        inx
        stx @m+2
        ldx trpch
@m      lda $ff00,y
        lsr
        bcs @r
@no     lda trxof
        bne @r
        sty trxo
        stx trxo+1
        lda #1
        sta trxof
@r      rts

; trcpage: a = the real page to run code from in virtual page x (x, y
; kept; z clear). Out of the I/O, 0 is a tune page not in memory (tr_home):
; read in now
trcpage lda trrpt,x
        bne @r
        cpx #$d0
        bcc @f
        cpx #$e0
        bcs @f
        lda trios-$d0,x         ; I/O: its shadow, or zeros
        bne @r
        lda #>trzero
@r      rts
@f      jsr trfetch
        sta trrpt,x
        cmp #0
        rts
; trfetch: tune page x into memory: a = its real page (tr_fetch: x, y
; kept); trhome: a = the table's entry for page x (its page: trsetup)
trfetch jmp (tr_fetch)
trhome  lda $ff00,x
        rts

; ------------------------------------------------------------
; trcarry the clock's low byte carried: the rest, and the limit
;   uses: a, x
; ------------------------------------------------------------
trcarry inc trclk+1
        bne @c
        inc trclk+2
@c      ldx trlimo
        lda trclk+1
        cmp trlimt,x
        lda trclk+2
        sbc trlimt+1,x
        bcs @over
        rts
@over   sty trxpc
        lda trpch
        sta trxpc+1
        lda trlimt+2,x
        jmp trfail
; the limits, in 256 cycles, and the refusals: init 1,000,000 (10), a
; play call 200,000 (11)
trlimt  byte $43,$0f,10,$0e,$03,11

; ------------------------------------------------------------
; tre_xx  a memory operand's address: x = page, trlo = low byte; y past
;         the instruction; trpcl = the opcode's offset
; ------------------------------------------------------------
tre_zp  sty trpcl
        iny
        lda (trpcp),y
        jmp trez2
tre_zx  lda trrx
        byte $2c
tre_zy  lda trry
        sty trpcl
        iny
        clc
        adc (trpcp),y
trez2   sta trlo
        ldx #0
        iny
        rts
tre_ab  sty trpcl
        iny
        lda (trpcp),y
        sta trlo
        iny
        lda (trpcp),y
        tax
        iny
        rts
tre_ax  lda trrx
        byte $2c
tre_ay  lda trry
        sty trpcl
        iny
        clc
        adc (trpcp),y
        sta trlo
        iny
        lda (trpcp),y
        adc #0
        tax
        iny
        rts
tre_ix  sty trpcl
        iny
        lda (trpcp),y
        clc
        adc trrx
        tax
        lda trzpg,x
        sta trlo
        inx
        lda trzpg,x
        tax
        iny
        rts
tre_iy  sty trpcl
        iny
        lda (trpcp),y
        tax
        lda trzpg,x
        clc
        adc trry
        sta trlo
        inx
        lda trzpg,x
        adc #0
        tax
        iny
        rts

; ------------------------------------------------------------
; trrd    read x:trlo as the tune does (the I/O through trrdio)
; trrdm   ... as a read-modify-write does (sim6502: no I/O registers)
;   out:  a; x, y kept
; ------------------------------------------------------------
trrdm   jsr trcpage
        bne trrd2
trrd    lda trrpt,x
        beq trrdio
trrd2   sta @r+2
        lda trlo
        sta @r+1
@r      lda $ffff
        rts

; ------------------------------------------------------------
; trrdio  what the tune reads in the I/O: the raster ($d011/$d012),
;         oscillator and envelope 3 ($d41b/$d41c) and the CIAs' timers
;         ($dc04-$dc07, $dd04-$dd07) move; the rest reads as last
;         written (0 if never), as TuneSim.io
;   in:   x = page ($d0-$df), trlo
;   out:  a; y and c kept (x too but for the raster and the timers)
;   uses: trt, trt2, trt4
; ------------------------------------------------------------
trrdio  php
        lda trlo
        cpx #$d0
        bne @s
        cmp #$11
        beq @ras
        cmp #$12
        bne @sh
@ras    jsr trline              ; the raster: $d012 its line, $d011 $1b
        lda trlo                ; and bit 7 its line's bit 8
        lsr
        lda trlln
        bcc @ret
        lda trlln+1
        lsr
        ror
        ora #$1b
        bne @ret
@s      cpx #$d4
        bne @c
        cmp #$1b
        beq @rnd
        cmp #$1c
        bne @sh
@rnd    lda trrnd               ; oscillator 3
        asl
        bcc @r1
        eor #$1d
@r1     sta trrnd
        bne @ret
@sh     jsr trcpage             ; the rest: as last written
        jsr trrd2
        jmp @ret
@c      cpx #$dc
        beq @cia
        cpx #$dd
        bne @sh
@cia    cmp #4                  ; the timers: 65535 less the clock
        bcc @sh
        cmp #8
        bcs @sh
        and #1
        tax
        lda trclk
        clc
        adc trcs
        sta trt
        lda trclk+1
        adc trcs+1
        sta trt2
        lda trt,x
        eor #$ff
@ret    plp
        rts

; trline: the raster now: trlln, the line, (line0 + (r0 + clk) div 63)
; mod 312, and trlc, the cycle in it (y kept; uses a, x, trt, trt2,
; trt4)
trline  lda trclk               ; r0 + clk
        clc
        adc trr0
        sta trt
        lda trclk+1
        adc #0
        sta trt2
        lda trclk+2
        adc #0
        sta trt4
        ldx #24                 ; div 63
        lda #0
@d      asl trt
        rol trt2
        rol trt4
        rol
        cmp #63
        bcc @n
        sbc #63
        inc trt
@n      dex
        bne @d
        sta trlc
        lda trt                 ; + line0, mod 312
        clc
        adc trln0
        sta trlln
        lda trt2
        adc trln0+1
        sta trlln+1
@m      lda trlln
        sec
        sbc #<312
        tax
        lda trlln+1
        sbc #>312
        bcc @x
        stx trlln
        sta trlln+1
        bcs @m
@x      rts

; ------------------------------------------------------------
; trwio   trv into I/O page x's shadow (a page at the first write)
; trwpg   trv into page a at trlo
; trwr    the tune stores trv at x:trlo (trpcl set): straight into a
;         scratch page (trwpg), else trws
; trws    a store that isn't straight into a scratch page
;   in:   a = the page's class (trwpt), x = page, trlo, trv, trpcl
;   uses: a, x, trt-trt4, trpg, trcl (y kept)
; ------------------------------------------------------------
trwio   lda trios-$d0,x
        bne trwpg
        jsr tralloc
        sta trios-$d0,x
trwpg   sta @w+2
        lda trlo
        sta @w+1
        lda trv
@w      sta $ffff
        rts
trwr    lda trwpt,x
        bmi trwpg
trws    stx trpg
        sta trcl
        and #$40
        beq @nh
        jsr trhchk              ; the loader minds part of this page
        ldx trpg
@nh     lda trcl
        and #$3f
        beq @new
        cmp #$10
        bcc trwtrk
        beq @cow
        cmp #$20
        bcc @cpd
        beq @zp
        cmp #$22
        bcc @stk
        bne trwio               ; VIC, CIAs, colour RAM, I/O expansion: the shadow
        jmp trwsid
@zp     ldx trlo                ; (an absolute store into zero page)
        lda trv
        sta trzpg,x
        lda #1
        sta trzpw,x
        rts
@stk    ldx trlo                ; into the stack page (not a push)
        lda trv
        sta trstk,x
        cpx #$80
        bcc @r
        cpx trstkm
        bcc @r
        stx trstkm
@r      rts
@cow    jsr trcow               ; the tune's page: copy it first
        ldx trpg
@cpd    lda trrpt,x             ; (a copied page the loader minds)
        bne trwpg
@new    jsr trpair              ; RAM never written: a page, and the next
        sta trrpt,x             ; for its map
        lda trwpt,x
        and #$40
        ora #1
        sta trwpt,x
; trwtrk: workspace, or the tune's partial page: the byte, and bit 0 in
; its map (a byte each: 1 written, 2 a tune byte)
trwtrk  lda trrpt,x
        pha
        jsr trwpg
        pla
        tax
        inx
        stx @m+2
        stx @n+2
        ldx trlo
@m      lda $ff00,x
        ora #1
@n      sta $ff00,x
        rts
; trcow: copy the tune's page x into a scratch page (x kept; one not in
; memory read in first)
trcow   lda trrpt,x
        bne @c
        jsr trfetch
@c      jsr trcopy
        sta trrpt,x
        tay
        lda trwpt,x
        and #$40
        beq @f
        ldy #$51                ; the loader minds it: copied, still slow
@f      tya
        sta trwpt,x
        cpx trpch               ; the pc's page: run the copy
        bne @r
        ldy trpcp+1
        cpy #>trvp
        beq @r
        lda trrpt,x
        sta trpcp+1
@r      ldy trt
        rts

; tralloc: a = a zeroed page from the front of the pool (refusal 13
; when none is left; x, y kept)
tralloc txa
        pha
        ldx trfi
        cpx trbi
        bcc trpl1
        pla
        lda #13
        jmp trfail
trpl1   lda $ffff,x             ; (tr_pool's list)
        inx
        stx trfi
        sta @w+2
        sty trt
        ldy #0
        tya
@w      sta $ff00,y
        iny
        bne @w
        ldy trt
        pla
        tax
        lda @w+2
        rts
; trpair: two pages side by side from the front of the pool, zeroed (a
; page and its map): a = the first (refusal 13 when none are left; x, y
; kept; a page before a gap in the list is left out)
trpair  jsr tralloc
        sta trpa
        txa
        pha
        ldx trfi
        cpx trbi
        bcc trpl2
trpnx   pla                     ; (not side by side: from the next; none
        tax                     ; left: tralloc refuses)
        jmp trpair
trpl2   lda $ffff,x
        sec
        sbc trpa
        cmp #1
        bne trpnx
        pla
        tax
        jsr tralloc
        lda trpa
        rts
; trcopy: a page from the pool with page a's bytes (a: it; trt: y)
trcopy  sta @s+2
        jsr tralloc
        sta @d+2
        ldy #0
@s      lda $ff00,y
@d      sta $ff00,y
        iny
        bne @s
        lda @d+2
        rts

; trwsid: a SID write: the checksum, and a second chip's registers
; written while playing (the first: refusal 3)
trwsid  lda trv                 ; the checksum: s1 += reg * 256 + value,
        clc                     ; s2 += s1
        adc trs1
        sta trs1
        lda trlo
        and #$1f
        adc trs1+1
        sta trs1+1
        jsr trsum2
        cpx #$d4
        bne @m
        lda trlo
        cmp #$20
        bcc @n
@m      lda trfrm
        ora trfrm+1             ; (init may clear them all)
        beq @n
        lda trmirf
        bne @n
        lda #3
        sta trmirf
        stx trmir+1
        lda trlo
        sta trmir
@n      lda tr_slog+1           ; init's: noted, if asked
        beq @w
        lda trfrm
        ora trfrm+1
        bne @w
        jsr trslg
@w      jmp trwio
; trslg: init's SID write (trlo's register, trv) into tr_slog's list, 64
; at most (more: tr_nslog $ff; x, y kept)
trslg   lda tr_nslog
        cmp #64
        bcs @f
        tya
        pha
        lda tr_nslog
        asl a
        tay
        lda tr_slog
        sta @r+1
        sta @v+1
        lda tr_slog+1
        sta @r+2
        sta @v+2
        lda trlo
        and #$1f
@r      sta $ffff,y
        iny
        lda trv
@v      sta $ffff,y
        inc tr_nslog
        pla
        tay
        rts
@f      lda #$ff
        sta tr_nslog
        rts
; trsum: y*256 + a into the SID writes' checksum (x kept)
trsum   clc
        adc trs1
        sta trs1
        tya
        adc trs1+1
        sta trs1+1
trsum2  lda trs1
        clc
        adc trs2
        sta trs2
        lda trs1+1
        adc trs2+1
        sta trs2+1
        rts

; ------------------------------------------------------------
; trhchk  a store into a page the loader minds part of: that address?
; trharm  ... it is: note the store's pc ($01: the value too); in the
;         second run, the address (refusal 14: the first)
;   in:   x = page, trlo, trv
;   uses: a, x, trt, trt2
; ------------------------------------------------------------
trhchk  txa
        bne @n1
        lda trlo
        cmp #2
        bcc trharm
        rts
@n1     cpx #$ff
        bne trharm
        lda trlo
        cmp #$fa
        bcs trharm
        rts
trharm  txa
        bne @np
        lda trlo
        cmp #1
        bne @np
        lda trv                 ; $01: I/O banked out? (the lowest value)
        and #7
        cmp #5
        bcs @np
        lda trv
        eor #$ff
        cmp trbadv
        bcc @np
        sta trbadv
@np     lda trrun
        lsr
        bcc @r2
        jsr trcurpc             ; into tr_pat, ascending, once
        lda tr_npat
        asl
        sta trt
        ldx #0
@f      cpx trt
        beq @ins
        lda tr_pat,x
        sec
        sbc trxpc
        sta trt2
        lda tr_pat+1,x
        sbc trxpc+1
        bcs @ge
        inx
        inx
        bne @f
@ge     ora trt2                ; (there already)
        beq @r
@ins    lda tr_npat
        cmp #32
        bcs @over
        stx trt2
        ldx trt
@sh     cpx trt2                ; the rest up a place
        beq @put
        lda tr_pat-1,x
        sta tr_pat+1,x
        dex
        bne @sh
@put    lda trxpc
        sta tr_pat,x
        lda trxpc+1
        sta tr_pat+1,x
        inc tr_npat
@r      rts
@over   sta trhov
        rts
@r2     lda trlo                ; the second run: still writes there
        sta trxpc
        lda trpg
        sta trxpc+1
        jsr trintun
        bcs @r                  ; (one of the tune's own bytes)
        lda trlftf
        bne @r
        lda #14
        sta trlftf
        lda trxpc
        sta trlft
        lda trxpc+1
        sta trlft+1
        rts

; trcurpc: the current instruction's pc into trxpc (its opcode at trpcl;
; uses a, x)
trcurpc ldx #0
        lda trpcp+1
        cmp #>trvp
        bne @n
        ldx #tredgy-trpcl
@n      lda trpcl,x
        sta trxpc
        lda trpch,x
        sta trxpc+1
        rts

; trintun: c = 1 when trxpc is one of the tune's bytes (x, y kept)
trintun lda trxpc
        cmp tr_load
        lda trxpc+1
        sbc tr_load+1
        bcc @r
        lda trlstl
        cmp trxpc
        lda trlsth
        sbc trxpc+1
@r      rts

; ------------------------------------------------------------
; trgen   an opcode without a handler of its own: its addressing mode
;         (trgmt) and operation (trgot: its routine's place in trops,
;         where the reads come first, then the stores, then the ones
;         that read, change and write back)
; ------------------------------------------------------------
trgen   lda (trpcp),y
        tax
        lda trgmt,x
        sta trcol
        lda trgot,x
        sta trcls
        clc
        adc #<trops
        sta trgo1+1
        lda #>trops
        adc #0
        sta trgo1+2
        ldx trcol
        lda trcls
        cmp #trgrw-trops
        bcs @rw
        cmp #trgst-trops
        bcs @st
        jsr trgrd               ; read: the value to the operation
        jsr trgo1
        ldx trcol
        lda trcyr,x
        jmp trnadd
@st     jsr trgo1               ; store: the value from it
        sta trv
        jsr trgea
        jsr trwr
        ldx trcol
        lda trcys,x
        jmp trnadd
@rw     jsr trgea               ; read, change, write back
        jsr trgo1
        ldx trcol
        lda trcys,x
        clc
        adc #2
        jmp trnadd
; trgo1: the operation
trgo1   jmp $ffff
; trgea: the operand's address by the mode x: x:trlo
trgea   lda trealo,x
        sta @j+1
        lda treahi,x
        sta @j+2
@j      jmp $ffff
; trgrd: the operand's value by the mode x, a crossed page's cycle after
trgrd   cpx #2
        bne @m
        iny                     ; immediate
        lda (trpcp),y
        iny
        rts
@m      jsr trgea
        jsr trrd
        ldx trcol
        cpx #4
        beq @y
        cpx #8
        beq @y
        cpx #7
        bne @r
        ldx trrx
        byte $2c
@y      ldx trry
        cpx trlo                ; crossed when the low byte came out below the index
        beq @r
        bcc @r
        inc trclk
        bne @r
        pha
        jsr trcarry
        pla
@r      rts
; the modes: 0 (zp,x) 1 zp 2 # 3 abs 4 (zp),y 5 zp,x 6 zp,y 7 abs,x 8 abs,y
trealo  byte <tre_ix,<tre_zp,<tre_zp,<tre_ab,<tre_iy,<tre_zx,<tre_zy,<tre_ax,<tre_ay
treahi  byte >tre_ix,>tre_zp,>tre_zp,>tre_ab,>tre_iy,>tre_zx,>tre_zy,>tre_ax,>tre_ay
trcyr   byte 6,3,2,4,5,4,4,4,4  ; cycles: a read,
trcys   byte 6,3,2,4,6,4,4,5,5  ; a store (a read-write: 2 more)
; the mode by the opcode's cc and bbb (cc 0 and 2 alike, 1 and 3 alike)
trgmd   byte 2,1,2,3,2,5,2,7
        byte 0,1,2,3,4,5,8,7
; the operations by cc and aaa (of the illegal ones, cc 3: sax, lax)
trgol   byte trgnop-trops,trgbit-trops,trgnop-trops,trgnop-trops
        byte trgsty-trops,trgldy-trops,trcmpy-trops,trcmpx-trops
        byte trgora-trops,trgand-trops,trgeor-trops,tradc-trops
        byte trgsta-trops,trga-trops,trcmpa-trops,trsbc-trops
        byte trmasl-trops,trmrol-trops,trmlsr-trops,trmror-trops
        byte trgstx-trops,trgldx-trops,trmdec-trops,trminc-trops
        byte trgnop-trops,trgnop-trops,trgnop-trops,trgnop-trops
        byte trisax-trops,trilax-trops

; the operations: the reads (the value in a), the stores (they return
; it in a, x kept), the ones that read, change and write back (x:trlo)
trops
trgora  ora trra
        jmp trga
trgand  and trra
        jmp trga
trgeor  eor trra
trga    sta trra
trgnz   sta trnzl
        sta trnzh
trgnop  rts
trgldx  sta trrx
        jmp trgnz
trgldy  sta trry
        jmp trgnz
trilax  sta trrx
        jmp trga
trcmpa  sta trt
        lda trra
trcmp2  sec
        sbc trt
trcmp3  sta trnzl
        sta trnzh
        rol trrc
        rts
trcmpx  sta trt
        lda trrx
        jmp trcmp2
trcmpy  sta trt
        lda trry
        jmp trcmp2
tradc   sta trt                 ; adc, sbc: with the tune's c, d and v,
        jsr trpin               ; on the real cpu
        adc trt
        jmp trpout
trsbc   sta trt
        jsr trpin
        sbc trt
        jmp trpout
trgbit  sta trnzh               ; bit
        and trra
        sta trnzl
        lda trnzh
        and #$40
        sta trt
        lda trrp
        and #$bf
        ora trt
        sta trrp
        rts
trgst                           ; ---- the stores
trgsta  lda trra
        rts
trgstx  lda trrx
        rts
trgsty  lda trry
        rts
trisax  lda trra
        and trrx
        rts
trgrw                           ; ---- read, change, write back
trmasl  jsr trrdm
        asl
        jmp trmsh
trmlsr  jsr trrdm
        lsr
        jmp trmsh
trmrol  jsr trrdm
        lsr trrc
        rol
        jmp trmsh
trmror  jsr trrdm
        lsr trrc
        ror
        jmp trmsh
trminc  jsr trrdm
        clc
        adc #1
        jmp trmnz
trmdec  jsr trrdm
        sec
        sbc #1
        jmp trmnz
; tradc/trsbc's: the tune's c, d, v into the real cpu's flags, a = its a
trpin   lda trrc
        and #1
        ora trrp
        ora #4                  ; (i set: interrupts stay off)
        pha
        lda trra
        plp
        rts
; ... and back: a and the flags (i as it was)
trpout  sta trra
        php
        cld
        pla
        and #$fb
        ora tri
        jmp trsetp
; a shift's result: c, then n z, then written back
trmsh   sta trv
        rol trrc
        lda trv
trmnz   sta trv
        sta trnzl
        sta trnzh
        jmp trwr

; ------------------------------------------------------------
; the opcodes with handlers of their own: y at the opcode, on to trnext
; with y at the next one (trsaN: a = the tune's a, n z, N cycles); the
; slow cases go back to the opcode and on to trgen
; ------------------------------------------------------------
trsa2   ldx #2
        byte $2c
trsa3   ldx #3
        sta trra
        sta trnzl
        sta trnzh
        txa
        jmp trnadd

troad   iny                     ; lda abs (lda abs,x with x = 0)
        lda #0
        beq trobd1
trobd   iny                     ; lda abs,x
        lda trrx
trobd1  clc
        adc (trpcp),y
        sta @r+1
        iny
        lda (trpcp),y
        bcs @x
@b      tax
        iny
        lda trrpt,x
        beq @io
        sta @r+2
@r      lda $ffff
        sta trra
        sta trnzl
        sta trnzh
        jmp trn4c               ; (c: a page crossed)
@x      adc #0
        sec
        bcs @b
@io     dey                     ; (the I/O: trgen)
        dey
        dey
        jmp trgen
trob9   iny                     ; lda abs,y
        lda trry
        jmp trobd1
troa5   iny                     ; lda zp
        lda (trpcp),y
        tax
        iny
        lda trzpg,x
        jmp trsa3
troa9   iny                     ; lda #
        lda (trpcp),y
        iny
        jmp trsa2
tro29   iny                     ; and #
        lda (trpcp),y
        iny
        and trra
        jmp trsa2
troa2   iny                     ; ldx #
        lda (trpcp),y
        sta trrx
        jmp trnz2
troc9   iny                     ; cmp #
        lda trra
        sec
        sbc (trpcp),y
        sta trnzl
        sta trnzh
        rol trrc
        iny
        jmp trn2

tro9d   iny                     ; sta abs,x
        lda trrx
tro9d1  clc
        adc (trpcp),y
        sta @w+1
        iny
        lda (trpcp),y
        adc #0
        tax
        iny
        lda trwpt,x
        bpl @s
        sta @w+2
        lda trra
@w      sta $ffff
        jmp trn5
@s      cmp #$22                ; (the SID: the quick way)
        bne @g
        lda @w+1
        sta trlo
        lda trra
        sta trv
        jsr trwsid
        jmp trn5
@g      dey                     ; (the rest: trgen)
        dey
        dey
        jmp trgen
tro99   iny                     ; sta abs,y
        lda trry
        jmp tro9d1
tro85   iny                     ; sta zp
        lda (trpcp),y
        tax
        iny
        cpx #2
        bcc @g
        lda trra
        sta trzpg,x
        txa
        sta trzpw,x
        jmp trn3
@g      dey                     ; ($00, $01: trgen)
        dey
        jmp trgen
; ---- the accumulator, registers, flags, no-ops
tro0a   asl trra                ; asl
trsh    rol trrc
        lda trra
trnz2   sta trnzl
        sta trnzh
        iny
        jmp trn2
tro4a   lsr trra                ; lsr
        jmp trsh
tro2a   lsr trrc                ; rol
        rol trra
        jmp trsh
tro6a   lsr trrc                ; ror
        ror trra
        jmp trsh
troaa   lda trra                ; tax
        sta trrx
        jmp trnz2
troa8   lda trra                ; tay
        sta trry
        jmp trnz2
tro8a   lda trrx                ; txa
        sta trra
        jmp trnz2
tro98   lda trry                ; tya
        sta trra
        jmp trnz2
troba   lda trrs                ; tsx
        sta trrx
        jmp trnz2
troe8   inc trrx                ; inx
        lda trrx
        jmp trnz2
troc8   inc trry                ; iny
        lda trry
        jmp trnz2
troca   dec trrx                ; dex
        lda trrx
        jmp trnz2
tro88   dec trry                ; dey
        lda trry
        jmp trnz2
tro9a   lda trrx                ; txs
        sta trrs
        jmp troea
tro18   lda #0                  ; clc
        byte $2c
tro38   lda #1                  ; sec
        sta trrc
        jmp troea
tro58   lda #0                  ; cli
        byte $2c
tro78   lda #4                  ; sei
        sta tri
        jmp troea
trob8   lda #$bf                ; clv
        byte $2c
trod8   lda #$f7                ; cld
        and trrp
        sta trrp
        jmp troea
trof8   lda #8                  ; sed
        ora trrp
        sta trrp
troea   iny                     ; nop (and $1a $3a $5a $7a $da $fa)
        jmp trn2
tro0c   iny                     ; nop abs (top)
        iny
        iny
        jmp trn4
tro80   iny                     ; nop # (dop)
        iny
        jmp trn2

; ---- the stack
tro48   lda trra                ; pha
tropu   jsr trpush
        iny
        jmp trn3
tro08   jsr trgetp              ; php
        ora #$10
        bne tropu
tro68   jsr trpull              ; pla
        jsr trga
        iny
        jmp trn4
tro28   jsr trpull              ; plp
        jsr trsetp
        iny
        jmp trn4
trpull  ldx trrs
        inx
        lda trstk,x
        stx trrs
        rts
trpush  ldx trrs
        sta trstk,x
        dex
        stx trrs
        rts
; trgetp: a = the tune's flags (bit 5 set, b clear; uses x)
trgetp  jsr trpin               ; (c, d and v on the real cpu)
        php
        cld
        pla
        and #$49
        ora tri
        ora #$20
        ldx trnzh
        bpl @p
        ora #$80
@p      ldx trnzl
        bne @r
        ora #2
@r      rts
; trsetp: the tune's flags from a (uses x)
trsetp  sta trnzh
        sta trrc
        tax
        and #4
        sta tri
        txa
        and #$48
        sta trrp
        txa
        and #2
        eor #2
        sta trnzl
        rts

; ---- branches
tro10   bit trnzh               ; bpl
        bpl trbt
        bmi trbn
tro30   bit trnzh               ; bmi
        bmi trbt
        bpl trbn
tro50   bit trrp                ; bvc
        bvc trbt
        bvs trbn
tro70   bit trrp                ; bvs
        bvs trbt
        bvc trbn
tro90   lda trrc                ; bcc
        lsr
        bcc trbt
        bcs trbn
trob0   lda trrc                ; bcs
        lsr
        bcs trbt
        bcc trbn
trod0   lda trnzl               ; bne
        bne trbt
        beq trbn
trof0   lda trnzl               ; beq
        beq trbt
trbn    iny                     ; not taken
        iny
        jmp trn2
trbt    lda trpcp+1             ; taken
        cmp #>trvp
        beq trbte
        iny
        lda (trpcp),y
        iny
; trbo: a = the offset, trpch:y = the next pc
trbo    tax
        sty trt
        clc
        adc trt
        tay
        txa
        bmi @b
        bcs @up
@s      jmp trn3
@b      bcs @s
        dec trpch
        bcc @m
@up     inc trpch
@m      jsr trmapc
        jmp trn4
trbte   lda tredgy              ; from the edge buffer: the next pc
        clc
        adc #2
        tay
        lda tredgp
        adc #0
        sta trpch
        jsr trmapc
        lda trtb+1
        jmp trbo

; ---- jumps
tro4c   iny                     ; jmp abs
        lda (trpcp),y
        tax
        iny
        lda (trpcp),y
        sta trpch
        txa
        tay
        jsr trmapc
        jmp trn3
tro6c   iny                     ; jmp (ind): the page bug; no I/O registers
        lda (trpcp),y
        sta trlo
        iny
        lda (trpcp),y
        tax
        jsr trrdm
        sta trt
        inc trlo
        jsr trrdm
        sta trpch
        ldy trt
        jsr trmapc
        jmp trn5
tro20   sty trpcl               ; jsr
        iny
        lda (trpcp),y
        sta trt3
        iny
        lda (trpcp),y
        sta trt2
        jsr trcurpc             ; the return: the jsr's last byte
        lda trxpc
        clc
        adc #2
        sta trt4
        lda trxpc+1
        adc #0
        jsr trpush
        lda trt4
        jsr trpush
        lda trt2
        sta trpch
        ldy trt3
        jsr trmapc
        jmp trn6
tro60   jsr trpull              ; rts
        tay
        jsr trpull
        iny
        bne trret
        clc
        adc #1
trret   sta trpch               ; (a: the page)
        jsr trmapc
        jmp trn6
tro40   jsr trpull              ; rti
        jsr trsetp
        jsr trpull
        tay
        jsr trpull
        jmp trret
tro00   lda #<trdone            ; brk: the call ends (as sim6502's)
        ldx #>trdone
        jsr trjmp
        jmp trn7
trbad   sty trpcl               ; an opcode it can't run (12)
        jsr trcurpc
        lda #12
        jmp trfail

; the opcodes with handlers of their own: a bit each, and the handlers
; (the other one-byte opcodes are nops: troea)
trspb   byte $01,$15,$01,$01,$01,$07,$01,$01,$01,$15,$01,$01,$01,$15,$01,$01
        byte $21,$05,$01,$27,$24,$27,$01,$27,$00,$07,$01,$01,$00,$01,$01,$01
trspw   word tro00,tro08,tro0a,tro0c,tro10,tro18,tro20,tro28
        word tro29,tro2a,tro30,tro38,tro40,tro48,tro4a,tro4c
        word tro50,tro58,tro60,tro68,tro6a,tro6c,tro70,tro78
        word tro80,tro85,tro88,tro8a,tro90,tro98,tro99,tro9a
        word tro9d,troa2,troa5,troa8,troa9,troaa,troad,trob0
        word trob8,trob9,troba,trobd,troc8,troc9,troca,trod0
        word trod8,troe8,trof0,trof8

; ------------------------------------------------------------
; trsetup the emulated machine for a run: memory all zero but the
;         tune ($00 = $2f, $01 = $15), the flags clear, the page
;         tables, the dispatch (the tune's first and last pages are
;         copied, the rest read from tr_src until written)
;   uses: a, x, y
; ------------------------------------------------------------
trsetup ldy #0
        sty trt4
@z      lda #0
        sta trzpg,y
        sta trstk,y
        sta trzpw,y
        sta trzero,y
        sta trwpt,y
        lda #>trzero
        sta trrpt,y
        jsr trdec               ; the dispatch, the decoding
        ldy trt3
        iny
        bne @z
        tya
        ldx #trz1-trz0-1        ; the notes, the I/O's shadows
@v      sta trz0,x
        dex
        bpl @v
        sta trrp                ; the flags: all clear (z: nzl not 0)
        sta trnzh
        sta trrc
        sta trfrm               ; (the play calls done)
        sta trfrm+1
        ldx #15                 ; the pages with a class
@pc     ldy trpgc,x
        lda trpgc+1,x
        sta trt
@pp     lda trpgc+2,x
        sta trwpt,y
        and #2                  ; (the I/O: read through trrdio)
        beq @n
        lda #0
        sta trrpt,y
@n      iny
        dec trt
        bne @pp
        dex
        dex
        dex
        bpl @pc
        lda #>trzpg
        sta trrpt
        lda #>trstk
        sta trrpt+1
        lda #$2f
        sta trzpg
        lda #$15
        sta trzpg+1
        lda #1
        sta trnzl
        sta trrnd
        lda tr_home             ; (the tune's page table, if any)
        sta trhome+2
        lda tr_pool             ; the pool: the list's pages, front to back
        sta trpl1+1
        sta trpl2+1
        sta @pl+1
        lda tr_pool+1
        sta trpl1+2
        sta trpl2+2
        sta @pl+2
        ldx #0
@pl     lda $ffff,x
        beq @pe
        inx
        bne @pl
@pe     stx trbi
        lda #0
        sta trfi
        lda #$b1                ; the dispatch as it is (lda (trpcp),y : asl)
        sta trnx2
        lda #trpcp
        sta trnx2+1
        lda #$0a
        sta trnx2+2
        lda #<trnx2
        sta tredj+1
        lda #>trnx2
        sta tredj+2
; the tune's pages: the whole ones read from tr_src (copied when
; written), the first and last copied now with zeros round the tune
        lda tr_load
        clc
        adc tr_len
        tax
        lda tr_load+1
        adc tr_len+1
        sta trlsth
        txa
        bne @l1
        dec trlsth
@l1     dex
        stx trlstl
        lda tr_src+1
        sec
        sbc tr_load+1
        sta trdlt
        ldx tr_load+1
@pg     cpx #$d0                ; (none in the I/O)
        bcc @io
        cpx #$e0
        bcc @nx
@io     lda tr_home             ; (its bytes' real page: tr_src's, or the
        beq @src                ; table's: 0 when not in memory, read in
        jsr trhome              ; at its first use: trcpage)
        jmp @hm
@src    txa
        clc
        adc trdlt
@hm     cpx tr_load+1           ; the first and last: a copy, and its map
        beq @part
        cpx trlsth
        beq @part
        sta trrpt,x             ; the rest: tr_src (or the table's)
        lda #$10
        bne @cl
@part   cmp #0
        bne @pin
        jsr trfetch
@pin    jsr trpart
        sta trrpt,x
        lda #1
@cl     ora trwpt,x             ; (+$40: the loader minds part of it)
        sta trwpt,x
@nx     cpx trlsth
        beq @r
        inx
        bne @pg
@r      rts
; the pages with a class of their own: first, count, class (trwpt); the
; last first
trpgc   byte $00,1,$60          ; zero page: $00/$01 minded
        byte $01,1,$21          ; the stack
        byte $04,4,$40          ; the loader's $0400-$07ff
        byte $d4,4,$22          ; the SID (after the rest of the I/O)
        byte $d0,16,$63         ; the VIC, colour RAM, CIAs ... (minded)
        byte $ff,1,$40          ; the vectors
; trdec: opcode y's mode (trgmt) and operation (trgot) for trgen, and
; its dispatch entry: a handler of its own (trspb, the next in trspw),
; trbad for what it doesn't run (trbadb), troea for the other one-byte
; ones (the $xa nops), else trgen; trt3 = y (uses a, x, y, trt, trt4,
; trv)
trdec   sty trt3
        tya                     ; the operation by cc and aaa
        and #3
        asl
        asl
        asl
        sta trt
        tya
        lsr
        lsr
        lsr
        lsr
        lsr
        ora trt
        tax
        lda trgol,x             ; (its place in trops: its class too)
        sta trgot,y
        tya                     ; the mode by cc and bbb
        lsr
        lsr
        and #7
        sta trv
        lda trt
        and #8
        ora trv
        tax
        lda trgmd,x
        tax
        tya                     ; (stx ldx sax lax: zp,y and abs,y for
        and #$d6                ; zp,x and abs,x)
        cmp #$96
        bne @md
        inx
@md     txa
        sta trgmt,y
        tya                     ; its handler
        and #7
        tax
        lda trbit,x
        sta trt
        tya
        lsr
        lsr
        lsr
        tay
        lda trspb,y
        and trt
        beq @g
        ldx trt4                ; its own
        lda trspw,x
        inx
        inx
        stx trt4
        ldy trspw-1,x
        tax
        tya
        jmp trtw
@g      ldx #0                  ; (trbad)
        lda trbadb,y
        and trt
        bne @w
        inx                     ; (troea)
        lda trt3
        and #$0f
        cmp #$0a
        beq @w
        inx                     ; (trgen)
@w      ldy trdhi,x
        lda trdlo,x
        tax
        tya
; trtw: dispatch entry trt3 = handler a/x (hi/lo)
trtw    pha
        lda trt3
        asl
        tay
        pla
        bcs @h
        sta trtab+1,y
        txa
        sta trtab,y
        rts
@h      sta trtab+257,y
        txa
        sta trtab+256,y
        rts
trdlo   byte <trbad,<troea,<trgen
trdhi   byte >trbad,>troea,>trgen
trbit   byte 1,2,4,8,16,32,64,128
; trpart: a copy of the tune's bytes in page x (at real page a), zeros
; round them, and the next page its map (2 for the tune's bytes): a =
; the copy (x kept)
trpart  sta @s+2
        jsr trpair
        sta @d+2
        clc
        adc #1
        sta @m+2
        lda #0
        cpx tr_load+1
        bne @f
        lda tr_load
@f      sta trt
        lda #$ff
        cpx trlsth
        bne @t
        lda trlstl
@t      sta trt2
        ldy trt
@s      lda $ff00,y
@d      sta $ff00,y
        lda #2
@m      sta $ff00,y
        cpy trt2
        beq @r
        iny
        bne @s
@r      lda @d+2
        rts

; ------------------------------------------------------------
; trfin   the outputs after the first run, then its refusals in
;         sidstrip's order
;   uses: a, x, y
; ------------------------------------------------------------
trfin   ldx #tr_ws-tr_err-1     ; the outputs: zero
        lda #0
@c      sta tr_err,x
        dex
        bpl @c
        ldy #2                  ; zero page written ($02-$ff): a bit each
@z      tya
        lsr
        lsr
        lsr
        tax
        lda trzpw,y
        cmp #1                  ; (c: written)
        ror tr_zp,x
        iny
        bne @z
        lda trmax               ; the longest play call, +6 for the jsr
        clc
        adc #6
        sta tr_cyc
        lda trmax+1
        adc #0
        sta tr_cyc+1
        lda trmax+2
        adc #0
        beq @lat
        lda #$ff
        sta tr_cyc
        sta tr_cyc+1
@lat    ldx #$dc                ; CIA 1 timer A's latch
        lda #4
        sta trlo
        jsr trrdm
        sta tr_latch
        inc trlo
        jsr trrdm
        sta tr_latch+1
        jsr trrun0              ; the run's own refusal (10-13)
        bne trref
        ldx trxo                ; 1: code outside it (the ROMs)
        ldy trxo+1
        lda trxof
        bne trref
        lda trbadv              ; 2: banks I/O out
        beq @n3
        eor #$ff
        sta tr_errv
        lda #2
        bne trref0
@n3     ldx trmir               ; 3: a second SID
        ldy trmir+1
        lda trmirf
        bne trref
        ldx #2                  ; 4: the loader's zero page
        ldy #0
@n4l    lda trzpw,x
        bne @n4r
        inx
        cpx #$10
        bne @n4l
        ldx trstkm              ; 5: stores into the stack
        iny
        lda #5
        cpx #0
        bne trref
        jsr trpats              ; 7, 8: the stores to patch
        bne trref0
        lda trhov               ; 13: too many
        bne @n13
        jsr trwsout             ; the workspace (13: too many runs)
        bne @n13
        rts
@n13    lda #13
        bne trref0
@n4r    lda #4
; trref: refused a, the address y/x
trref   stx tr_erra
        sty tr_erra+1
trref0  sta tr_err
        rts

; trfin2: tstrip's second run: its own refusal, still writes what the
; loader can't allow (14), plays differently (15)
trfin2  jsr trrun0              ; its own refusal
        bne trref
        ldx trlft               ; still writes what the loader can't allow
        ldy trlft+1
        lda trlftf
        bne trref
        ldx #3                  ; plays differently
@c      lda trs1,x
        cmp tr1s,x
        bne @n15
        dex
        bpl @c
        rts
@n15    lda #15
        bne trref
; trrun0: a = the run's own refusal, y/x its address
trrun0  ldx trxpc
        ldy trxpc+1
        lda trerr
        rts


; trpats: the stores the loader can't allow (tr_pat), ascending: one
; refused (a = 7 or 8, tr_erra its pc), or a = 0 (9, an odd store, can't
; come up: every store the emulator runs is 2 or 3 bytes long)
trpats  ldx #0
@l      txa
        lsr
        cmp tr_npat
        beq @ok
        lda tr_pat,x
        sta trxpc
        sta tr_erra
        lda tr_pat+1,x
        sta trxpc+1
        sta tr_erra+1
        stx trt3
        jsr trintun             ; 7: not the tune's code
        lda #7
        bcc @no
        jsr trorig              ; 8: through a pointer
        cmp #$81
        beq @8
        cmp #$91
        beq @8
        ldx trt3
        inx
        inx
        bne @l
@ok     lda #0
@no     rts
@8      lda #8
        rts

; trorig: a = the tune's own byte at trxpc (trptr its address; y = 0;
; x kept)
trorig  lda trxpc
        sta trptr
        lda tr_home
        beq @s
        stx trt
        ldx trxpc+1
        jsr trhome
        bne @h
        jsr trfetch
@h      ldx trt
        jmp @p
@s      lda trxpc+1
        clc
        adc trdlt
@p      sta trptr+1
        ldy #0
        lda (trptr),y
        rts

; trwsout: the workspace runs (RAM outside the tune it wrote, $0200-
; $cfff and $e000-$ffff: the maps' 1s), byte exact; z clear when more
; than 16
trwsout ldx #2
@p      stx trpg
        lda trwpt,x             ; workspace, or the tune's first or last
        and #$3f                ; page: its map
        cmp #1
        bne @nx
        ldy trrpt,x
        iny
        sty @m+2
        ldy #0
@m      lda $ff00,y
        cmp #1                  ; (written, not a tune byte)
        bne @nb
        lda tr_nws
        asl
        asl
        tax
        beq @new
        tya                     ; the last run ends here: on with it
        cmp tr_ws-2,x
        bne @new
        lda trpg
        cmp tr_ws-1,x
        beq @end
@new    cpx #64                 ; a new run
        bcs @ov
        tya
        sta tr_ws,x
        lda trpg
        sta tr_ws+1,x
        inc tr_nws
        inx
        inx
        inx
        inx
@end    tya                     ; its end: here + 1
        sec
        adc #0
        sta tr_ws-2,x
        lda trpg
        adc #0
        sta tr_ws-1,x
@nb     iny
        bne @m
        ldx trpg
@nx     inx
        bne @p
@ov     txa
        rts

; ------------------------------------------------------------
; trpatch tstrip: each store in tr_pat becomes nop # (and a nop after
;         it for a 3-byte one) in the tune's bytes
;   uses: a, x, y
; ------------------------------------------------------------
trpatch ldx #0
@l      txa
        lsr
        cmp tr_npat
        beq @r
        lda tr_pat,x
        sta trxpc
        lda tr_pat+1,x
        sta trxpc+1
        jsr trorig              ; (y = 0)
        and #8                  ; abs, abs,x, abs,y: a nop after
        beq @n
        ldy #2
        lda #$ea
        sta (trptr),y
        ldy #0
@n      lda #$80
        sta (trptr),y
        inx
        inx
        bne @l
@r      rts

; ------------------------------------------------------------
; trprog  the play calls done, in 5 digits at tr_scr (counted in trdig,
;         a digit a byte); with tr_stop, RUN/STOP held: c set
;   uses: a, x, y, trptr
; ------------------------------------------------------------
trprog  ldx #4
@i      inc trdig,x
        lda trdig,x
        cmp #10
        bcc @o
        lda #0
        sta trdig,x
        dex
        bpl @i
@o      lda tr_scr+1
        beq @r
        sta trptr+1
        lda tr_scr
        sta trptr
        ldy #4
@p      lda trdig,y
        ora #$30
        sta (trptr),y
        dey
        bpl @p
@r      lda tr_stop             ; run/stop: the keyboard's column 7, row 7
        beq @c                  ; (the I/O in for it)
        lda $01
        pha
        lda #$35
        sta $01
        lda #$7f
        sta $dc00
        lda $dc01
        tax
        pla
        sta $01
        txa
        eor #$80                ; (0 when held: c set)
        asl
        rts
@c      clc
        rts

; the pool when the includer gives none: $ab-$bf
trpdef  byte $ab,$ac,$ad,$ae,$af,$b0,$b1,$b2,$b3,$b4,$b5,$b6,$b7,$b8,$b9,$ba
        byte $bb,$bc,$bd,$be,$bf,0
trrts   rts

; what it doesn't run (refusal 12): a bit an opcode (sim6502 doesn't, or an
; illegal one other than lax, sax and the nops)
trbadb  byte $9c,$88,$9c,$98,$8c,$88,$9c,$98,$9c,$88,$9c,$98,$9c,$88,$9c,$98
        byte $04,$0a,$0c,$d8,$00,$08,$04,$08,$8c,$88,$9c,$98,$8c,$88,$9c,$98
