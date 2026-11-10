; ------------------------------------------------------------
; abi.asm  -  SlopLoad shared definitions
;
; Included (by tools/build.py, which expands incasm lines) at the
; top of stage1.asm, core.asm and every module, so all three
; agree on zero page, block flags and tape timing.
; ------------------------------------------------------------

; ---- zero page shared with modules (read-only for games) ----
ld_state = $02          ; bit7 main data loaded (wrap up, then return
                        ;      carry set from frame)
                        ; bit6 tape error: rewind a little and press play
                        ; bit5 the border is the loader's (-showstripes:
                        ;      its stripes): leave $d020 alone
                        ; bit1 autorun (the game will be cut off at bit7)
                        ; bit0 ntsc machine (1) / pal (0)
ld_progress = $03       ; 0-255 share of the main program loaded

; ---- zero page private to the loader ($04-$0f) ----
ld_sa = $04             ; irq: saved a
ld_sx = $05             ; irq: saved x
ld_sr = $06             ; byte being assembled, marker bit on top
ld_chk = $07            ; running xor of the block's data
ld_cnt = $08            ; bytes left in block (2 bytes, dec-to-zero form)
ld_key = $0a            ; block's xor key
ld_pages = $0b          ; the page the game loop's progress has reached
ld_pcount = $0c         ; pilot pulses counted
ld_cal = $0d            ; non-zero once the pilot has been measured
ld_seq = $0e            ; sequence number of the next block wanted
ld_ev = $0f             ; flags of blocks completed (or-ed together)

; games may use $10-$8f
gm_zp = $10

; ---- block flags (header byte 5) ----
f_gameready = $01       ; the module is complete: start it
f_mainend = $02         ; all data loaded while the game runs is in
f_chain = $04           ; a chain's second module is in: switch to it (src/chain.asm)
f_last = $80            ; final block: start the program

; ---- tape timing ----
; a pulse of class k lasts (4 + 2k) * h cycles, h being the block's
; quantum (from the tool's speed setting). the decoder counts quanta
; with cia2 timer b counting timer a underflows: 11 - quanta is read
; at each edge. the pilot is class 0 pulses, the sync one class 3.
h_def = 122             ; quantum assumed while looking for a pilot: a
                        ; pilot pulse of 122-609 cycles counts. the tool's
                        ; pilots are 176-496 (h = 44-124); with a game's
                        ; edge jitter (64 at most), a deck 3% off speed and
                        ; an ntsc machine's 3.8% more cycles a pulse, every
                        ; one stays 30 cycles or more inside
tb_start = 11
cia_tb_count = $59      ; crb: start, one-shot, force load, count ta
cia_ta_run = $11        ; cra: start, continuous, force load
cal_start = 16          ; pilot pulse that starts the stopwatch
cal_end = 144           ; stage 1: the one 128 pulses later that reads it
cal_len = 64            ; core: reads it 64 pulses later, then measures
                        ; again (stopwatch latch $ff7f: rounds h)
; speed tracking moves h by a cycle after a net 32 votes (see core.asm)

; ---- processor port values while loading ----
port_io = $15           ; ram / i/o / ram, cassette motor on
port_ram = $14          ; all ram, motor on (stores under i/o)
port_off = $35          ; ram / i/o / ram, motor off

; Games: no decimal mode (sed): the loader's interrupt doesn't clear it.

s1ioi = $02f9           ; stage 1's last 7 bytes, kept to the end: ioinit, then
                        ; $dd0d read (the RESTORE lock off: the core's exit)

; ---- game module header (at the game's load address) ----
; +0 "plg1"   +4 init   +6 frame   +8 stop   (words)
; +10 end of claimed memory (word)  +12 worst edge jitter in cycles
; +13 song (set by the tool, $ff none)  +14 most of the cpu (%) the
; loader may take while the game runs (the tool keeps every frame's
; worth of tape within it; 0: 35)  +15 (show module: the picture's
; background)  +16 music init, +18 play (words, the tool's: a game with
; music calls them; init takes a = byte 13)  +20/+22 raster lines
; between play calls on pal/ntsc, in 1/64 lines  +24 music: 1 the
; built-in player (stop $c006, flags $c009), 2 a sid tune (all three
; voices; to stop it, clear the sid)  +25 (show module: vic bank)
; +26 the program's size in disk blocks (set by the tool, for a game)
gh_init = 4
gh_frame = 6
gh_stop = 8
