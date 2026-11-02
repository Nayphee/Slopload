; ------------------------------------------------------------
; slopload64.asm  -  SlopLoad 64: SlopLoad tapes mastered on the C64
;
; LOAD"SLOPLOAD64",8 and RUN. A menu of the settings: the program on
; disk, what shows while it loads (a module, a picture, music, or
; nothing: the game, the tune and the picture read from disk by name),
; the speed, how it starts, and where to; return writes the tape: to the
; cassette, or as a .tap file to a drive with room for it (1581, CMD,
; SD2IEC). The tape is the format
; tools/slopload.py writes, made the way tools/c64model.py describes
; (each block 2 bits a pulse, in the speed's set, keyed); the model's
; .tap and this tool's are the same, byte for byte.
;
; Memory: the tool and what it writes to tape (the core, stage 1, the
; show module) $0801 on; its buffers after them (bss), then the tune's
; bytes (the music pool, 17 pages), below $a000; a tune's file as read,
; the trial's scratch, and while writing a block in the prefix code, at
; $a000-$c0ff (the BASIC rom switched out); the sections and the pulse
; tables at $c100-$c5ff; a tune's relocations $c700, the show module
; moved $cb00, listed names $cd00; the module or the picture in the RAM
; under the I/O and the KERNAL, $d000-$fff9 (files.asm).
; Zero page $02-$8f (BASIC's: the tool doesn't go back to BASIC).
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
wnlo = $02                      ; writer: the next half's latch
wnhi = $03
sr = $04                        ; the byte being written, 2 bits a pulse
dcnt = $05                      ; ... symbols left in it
bptr = $06                      ; the next byte (2)
bend = $08                      ; the section's end (2)
rcnt = $0a                      ; a run's pulses left (2)
rlo = $0c                       ; a run's half
rhi = $0d
secp = $0e                      ; the next section (2)
hvec = $10                      ; handler (2)
houvec = $12                    ; house (2)
tsel = $14                      ; table * 4
tselb = $15                     ; ... after the switch
swc = $16                       ; bytes before the switch
porth = $17                     ; $01, the write line high
portl = $18                     ; ... and low
rlast = $1a                     ; a run's last pulse's half (2)
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
blk = $2e                       ; the block being written
n24 = $30                       ; division: dividend (4), quotient (4),
q24 = $34                       ; remainder (2)
rem = $38
bcnt = $3a                      ; writer: a stream section's bytes left (2)
xp = $3c                        ; SuperRAM pointer, bank in its third byte

reumax = 255                    ; REU banks sized (to 16 MB: its size said; a tape needs far less)
reusav = $c600                  ; (their first bytes, kept while sizing)
f_gameready = $01
f_mainend = $02
f_underio = $08
f_last = $80
maxblk = 40

*=$0801
        byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
*=$080d
        jmp main

        incasm "writer.asm"
        incasm "io.asm"
        incasm "plan.asm"
        incasm "ui.asm"
        incasm "disk.asm"
        incasm "coding.asm"
        incasm "machine.asm"
        incasm "xmem.asm"
        incasm "files.asm"
        incasm "setup.asm"
        incasm "math.asm"

; ------------------------------------------------------------
; main  ask, read the program, plan, write; again
; ------------------------------------------------------------
main    ldx #$ff
        txs
        lda #$36                ; the BASIC rom out: ram at $a000-$bfff
        sta $01
        jsr startup             ; (once: from what becomes the buffers)
        jsr uinit
again   ldx #$ff
        txs
        jsr clrchn
        lda #2                  ; every file closed: a fresh start
        jsr close
        lda #3
        jsr close
        jsr cmdclose
        lda #<rtiv              ; restore: nothing (the nmi vector)
        sta $0318
        lda #>rtiv
        sta $0319
        jsr ui                  ; the menu, until return
        jsr prepare             ; what goes on the tape with the program
        bcs @no                 ; (no: said under the menu)
        jsr plan
        bcc @w
@no     jsr anykey
        jmp again
@w      lda #147
        jsr chrout
        jsr master
        bcs mfail
mdone   ldx #<tx_done           ; (tests stop here: done
        ldy #>tx_done
        jsr print
        jmp mnext
mfail   ldx #<tx_fail           ; ... or here: stopped)
        ldy #>tx_fail
        jsr print
mnext   ldx #<tx_again
        ldy #>tx_again
        jsr print
@k      jsr getin
        beq @k
        jsr uinit
        jmp again
rtiv    rti
; ------------------------------------------------------------
; master  stage 1, the core and every block, to the cassette or a file:
; a block at a time to the cassette (the motor stopped while each is
; read and coded), or in one go (a .tap file; or from expansion memory)
;   out:  c set on an error (said)
; ------------------------------------------------------------
master  jsr mkcore
        jsr mkhead
        lda #<romh1             ; the KERNAL file, both copies of each block
        sta p1
        lda #>romh1
        sta p1+1
        lda #$89
        ldx #<header
        ldy #>header
        jsr romexp192
        lda #<romh2
        sta p1
        lda #>romh2
        sta p1+1
        lda #$09
        ldx #<header
        ldy #>header
        jsr romexp192
        lda #<romd1
        sta p1
        lda #>romd1
        sta p1+1
        lda #$89
        jsr romexp58
        lda #<romd2
        sta p1
        lda #>romd2
        sta p1+1
        lda #$09
        jsr romexp58
        lda opt_out             ; in one go?
        ora xmem
        beq @c
        lda #1
@c      sta opt_cont
        lda #$0f                ; (then the core ends on the bridge)
        sta coreb+1025
        jsr tables
        bcc @t
        rts
@t      jsr mkfirst             ; the sections: KERNAL file and core
        lda xmem
        beq @nx
        jmp xmaster
@nx     lda opt_out
        beq @tape
        jmp tmaster
@tape   jsr secend              ; to the cassette, a block at a time
        jsr presspl
        bcc @w
        rts
@w      ldx #<tx_wcore
        ldy #>tx_wcore
        jsr print
        jsr motoron
        jsr blank
        lda #<seclist
        ldx #>seclist
        jsr wtape
        jsr unblank
        jsr blocks
        php
        jsr motoroff
        plp
        rts

; presspl  "press record and play": waits for the cassette's sense line
; (the cassette is the tool's own: its lines driven here, the KERNAL's
; tape code never used, so any KERNAL will do, one without tape routines
; too: see cirq)
;   out:  c set if run/stop was pressed instead
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

; cirq  the interrupt, all the time the tool runs: the KERNAL's clock (and
; the STOP key) and its keyboard, through the jump table; never the rest
; of the KERNAL's interrupt, whose tape motor code (where a KERNAL has it:
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
; tmaster  a .tap file, the program read twice: first every block's
; coding chosen (the file's size), then each written
; ------------------------------------------------------------
tmaster jsr secend
        jsr tapsize
        bcs @x
        jsr tapchk              ; room for it?
        bcs @x
        jsr tapopen
        bcs @x
        jsr taphead
        ldx #<tx_wcore
        ldy #>tx_wcore
        jsr print
        jsr tapout
        lda #<seclist
        ldx #>seclist
        jsr wtap
        jsr clrchn
        jsr blocks
        php
        jsr tapclose            ; (an error at the close: the drive's, the
        bcs @e                  ; tape not whole)
        plp
        rts
@e      plp
        sec
@x      rts

; ------------------------------------------------------------
; xmaster  from expansion memory: the program read once, every block
; coded into the stream and its sections added to the list; then the
; whole tape written in one go, to the cassette or the .tap file
; ------------------------------------------------------------
xmaster lda p2                  ; (the list's end, kept: coding uses p2)
        sta xsecp
        lda p2+1
        sta xsecp+1
        jsr xinit
        jsr tapbase
        lda #$ff                ; (the program file: opened at its first block)
        sta rdpos
        sta rdpos+1
        lda #0
        sta blk
@b      lda blk
        cmp nblk
        bcs @all
        jsr showblk
        jsr getblk
        bcc @fz0
        jmp @err
@fz0
        jsr fast
        jsr anablk
        bcc @fz1
        jmp @errf
@fz1
        jsr layblk
        jsr slow
        jsr xput
        bcc @in
        beq @fz2                ; (z set: no room)
        jmp @err
@fz2    jmp @full
@in     lda xsecp               ; its sections after the last block's
        sta p2
        lda xsecp+1
        sta p2+1
        jsr secblk
        bcc @fy0
        jmp @err
@fy0
        lda p2
        sta xsecp
        lda p2+1
        sta xsecp+1
        jsr bpulses
        inc blk
        jmp @b
@all    lda xsecp
        sta p2
        lda xsecp+1
        sta p2+1
        jsr secend
        jsr closeprg
        jsr xrdinit
        lda opt_out
        beq @tape
        jsr tapchk              ; a .tap file
        bcs @err2
        jsr tapopen
        bcs @err2
        jsr taphead
        ldx #<tx_wall
        ldy #>tx_wall
        jsr print
        jsr tapout
        lda #<seclist
        ldx #>seclist
        jsr wtap
        jsr tapclose            ; (c set: an error at the close)
        php
        jsr xdone
        plp
        rts
@tape   jsr presspl             ; the cassette
        bcs @err2
        ldx #<tx_wall
        ldy #>tx_wall
        jsr print
        jsr motoron
        jsr blank
        lda #<seclist
        ldx #>seclist
        jsr wtape
        jsr unblank
        jsr motoroff
        jsr xdone
        clc
        rts
@full   jsr closeprg            ; it doesn't fit: a block at a time
        ldx #<tx_xfull
        ldy #>tx_xfull
        jsr print
        lda #0
        sta xmem
        jmp master
@errf   jsr slow
@err    jsr closeprg
@err2   jsr xdone
        sec
        rts

; ------------------------------------------------------------
; blocks  every block: read, coded and laid out (the motor stopped), then
; written; a .tap file's codings were chosen while sizing it
; ------------------------------------------------------------
blocks  lda #0
        sta blk
        lda #$ff                ; (the program file: opened at its first block)
        sta rdpos
        sta rdpos+1
@b      lda blk
        cmp nblk
        bcs @x
        lda opt_out
        bne @r
        jsr motoroff
@r      jsr showblk
        jsr getblk              ; read
        bcs @err
        jsr fast
        lda opt_out
        bne @e
        jsr anablk              ; its coding chosen
        bcs @errf
@e      jsr layblk              ; laid out
        lda #<seclist
        sta p2
        lda #>seclist
        sta p2+1
        jsr secblk
        bcs @errf
        jsr secend
        jsr slow
        lda opt_out
        beq @t
        jsr tapout
        lda #<seclist
        ldx #>seclist
        jsr wtap
        jsr clrchn
        jmp @n
@t      jsr motoron
        jsr blank
        lda #<seclist
        ldx #>seclist
        jsr wtape
        jsr unblank
@n      inc blk
        jmp @b
@x      jsr closeprg
        clc
        rts
@errf   jsr slow
@err    jsr closeprg
        sec
        rts

motoron lda $01
        and #$df
        sta $01
        rts
motoroff
        lda $01
        ora #$20
        sta $01
        rts

; blank  the screen off from the next frame (no bad lines while writing)
blank   lda $d011
        and #$ef
        sta $d011
@w      bit $d011               ; a whole frame: its line $30 without
        bpl @w                  ; the display
@w2     bit $d011
        bmi @w2
@w3     bit $d011
        bpl @w3
        rts
unblank lda $d011
        ora #$10
        sta $d011
        cli
        rts

; ------------------------------------------------------------
; tables  the KERNAL's pulses (table 0) and the core's (table 1: set 4
; at the boot set's h); the blocks' made as they come (gettab)
;   out:  c set if not made (never)
; ------------------------------------------------------------
tables  jsr romtab
        lda #1
        sta ntab
        ldx opt_speed
        lda bootsh,x
        ldy #4
        jmp gettab

; ------------------------------------------------------------
; mkfirst  the sections of the KERNAL file and the core
; ------------------------------------------------------------
mkfirst lda #<seclist
        sta p2
        lda #>seclist
        sta p2+1
        lda #<27137             ; the leader, then the first L
        ldx #>27137
        jsr secroml
        lda #<romh1
        ldx #>romh1
        jsr secromd
        lda #77                 ; 79 S after the block's end mark (3 in it)
        ldx #0
        jsr secroml
        lda #<romh2
        ldx #>romh2
        jsr secromd
        lda #<5453              ; and the 0x1500 between the blocks
        ldx #>5453
        jsr secroml
        lda #<romd1
        ldx #>romd1
        jsr secromd2
        lda #77
        ldx #0
        jsr secroml
        lda #<romd2
        ldx #>romd2
        jsr secromd2
        lda #75                 ; 78 after the last
        ldx #0
        jsr secrom
        ldx opt_speed           ; the core: its pilot and sync, its bytes
        lda bootsh,x
        sta t7
        lda #<pilcore
        ldx #>pilcore
        jsr pilotn              ; t0/t1: the pulses
        lda #1
        jsr secpil
        lda #<coreb             ; (and the bridge, written in one go)
        sta t0
        lda #>coreb
        sta t1
        lda #<1025
        clc
        adc opt_cont
        sta t2
        lda #>1025
        sta t3
        lda #1
        sta t4
        sta t6
        lda #0
        sta t5
        jmp secdib

; secrom  a run of a/x KERNAL short pulses; secroml  ... the last an L
secrom  ldy #191
        sty t4
        ldy #0
        sty t5
        beq secrs
secroml ldy #343-256
        sty t4
        ldy #1
        sty t5
secrs   sta t0
        stx t1
        lda #191
        sta t2
        lda #0
        sta t3
        jmp secrunt
; secromd / secromd2  a KERNAL block's symbols (1011 / 341 bytes) at a/x
secromd sta t0
        stx t1
        lda #<1011
        sta t2
        lda #>1011
        sta t3
        jmp secromc
secromd2
        sta t0
        stx t1
        lda #<341
        sta t2
        lda #>341
        sta t3
secromc lda #0
        sta t4
        sta t5
        sta t6
        jmp secdib
; secpil  a pilot: t0/t1 pulses of table a's symbol 0, the last its
; symbol 3 (the sync)
secpil  asl a
        asl a
        tax
        lda htlo,x
        sta t2
        lda hthi,x
        sta t3
        lda htlo+3,x
        sta t4
        lda hthi+3,x
        sta t5
; secrunt  a run: t0/t1 pulses of the half t2/t3, the last t4/t5
secrunt ldy #0
        lda #1
        sta (p2),y
        iny
        lda t0
        sta (p2),y
        iny
        lda t1
        sta (p2),y
        iny
        lda t2
        sta (p2),y
        iny
        lda t3
        sta (p2),y
        iny
        lda t4
        sta (p2),y
        iny
        lda t5
        sta (p2),y
        jmp secadv
; secdib  dibits: t0/t1 pointer, t2/t3 bytes, table t4, t5 bytes of it
; then table t6
secdib  ldy #0
        lda dibtype
        sta (p2),y
        iny
        lda t2
        sta (p2),y
        iny
        lda t3
        sta (p2),y
        iny
        lda t0
        sta (p2),y
        iny
        lda t1
        sta (p2),y
        iny
        lda t4
        sta (p2),y
        iny
        lda t5
        sta (p2),y
        iny
        lda t6
        sta (p2),y
secadv  lda p2
        clc
        adc #8
        sta p2
        bcc @x
        inc p2+1
@x      rts
secend  ldy #0
        tya
        sta (p2),y
        rts
dibtype byte 2                  ; 2: in memory, 3: from the stream
xsecp   word 0                  ; the whole tape's list: its end so far
opt_cont byte 0                 ; 1: the tape written in one go

; ------------------------------------------------------------
; texts
; ------------------------------------------------------------
tx_done text "done.",13,0
tx_fail text "stopped.",13,0
tx_again text "press a key for the menu.",13,13,0
tx_press text 13,"press record and play on tape",13,0
tx_wcore text "writing the loader...",13,0
tx_wall text "writing the tape in one go...",13,0
tx_xfull text "too big to write in one go:",13,"a block at a time",13,0

        incasm "payload.asm"

; ------------------------------------------------------------
; startup  once, at the start, from what becomes the buffers (bss): the
; tool's interrupt, the core to coreb, core_stripes' patch and the
; styles' colours to the cassette buffer, an rti under the KERNAL's
; vectors, what the machine has, dibsum
; ------------------------------------------------------------
startup
        sei                     ; the tool's interrupt (cirq)
        lda #<cirq
        sta $0314
        lda #>cirq
        sta $0315
        cli
        ldx #0                  ; the core (4 pages, zero beyond it) to coreb
@c      lda pl_core,x
        sta coreb,x
        lda pl_core+256,x
        sta coreb+256,x
        lda pl_core+512,x
        sta coreb+512,x
        lda #0
        cpx #<corelen
        bcs @z
        lda pl_core+768,x
@z      sta coreb+768,x
        inx
        bne @c
        ldx #0                  ; core_stripes' patch and the colours to $033c
@c2     lda pl_c2,x
        sta c2ins,x
        inx
        cpx #c2n
        bcc @c2
        ldx #5                  ; the RAM under the KERNAL's vectors: an
@v      lda rtivs,x             ; rti (for a NMI while it is switched out)
        sta $fffa,x
        dex
        bpl @v
        jsr detect              ; an accelerator, expansion memory
        lda xkind               ; (expansion memory there: a tape in one go
        sta xmem                ; from it, unless 9 says no)
        ldx #0                  ; dibsum: each byte's 2-bit pairs summed
@ds     txa                     ; (in the page detect borrowed)
        and #3
        sta t0
        txa
        lsr a
        lsr a
        tay
        and #3
        clc
        adc t0
        sta t0
        tya
        lsr a
        lsr a
        tay
        and #3
        clc
        adc t0
        sta t0
        tya
        lsr a
        lsr a
        clc
        adc t0
        sta dibsum,x
        inx
        bne @ds
        rts
rtivs   word rtiv,rtiv,rtiv

; ------------------------------------------------------------
; buffers: from the payload's core on (it is at coreb by then)
; ------------------------------------------------------------
bss     = pl_core
romh1 = bss                     ; the KERNAL header block's symbols
romh2 = romh1 + 1011            ; ... its repeat
romd1 = romh2 + 1011            ; the data block's
romd2 = romd1 + 341
blkb = romd2 + 341              ; header, pad, data, check, trailer
btab = blkb + 4300              ; the blocks (maxblk each)
bal = btab
bah = bal + maxblk
bll = bah + maxblk
blh = bll + maxblk
bsrc = blh + maxblk             ; 0: from memory (bpl/bph), 1: the program
bpl = bsrc + maxblk
bph = bpl + maxblk
bfl = bph + maxblk
bset = bfl + maxblk             ; 0: boot set, 1: the game's
bprog = bset + maxblk
bh = bprog + maxblk             ; each block's coding: quantum, set,
bm = bh + maxblk                ; prefix code (1) or 2 bits, key
bpf = bm + maxblk
bk = bpf + maxblk
bssend = bk + maxblk

coreb = $cb00                   ; the core (4 pages), its check, the bridge
header = coreb + 1026           ; the KERNAL header (192)
s1blk = header + 192            ; stage 1's block (58: to $cffb)
mpoolp  = (bssend+255)/256       ; the music pool: 17 pages (4096 + a page's offset)
mpoolend = mpoolp*256+$1100

; past a block in the prefix code ($a000 to $c0ff at most)
seclist = $c100                 ; sections (96: the whole tape's at most)
htlo = $c400                    ; the half-pulse tables (64 x 4)
hthi = $c500
