100 rem prg-lm: a loader module (.lm) from the programs an assembler wrote
110 dim g%(999),pa(3),pn(3),pd(3),qd(3),f$(3),l$(3),ha(31),hb(31)
120 z$=chr$(0):h$="0123456789abcdef"
130 print"{clr}{cyn}             *** {wht}prg-lm{cyn} ***"
140 print"{gry1}  a program (.prg) to a loader module{grn}":print
150 rem what to read: the main part, then up to three more
160 q$="drive with the program":dd=8:gosub 870:if d=0 then end
170 pd(0)=d:f$(0)=n$:np=1:print"the same, a vic bank lower (0: none):"
180 q$="drive":dd=0:gosub 870:qd(0)=d:if d then l$(0)=n$:rl=1
190 if np=4 then 250
200 print"another part (0: no more):":q$="drive":dd=0:gosub 870:if d=0 then 250
210 pd(np)=d:f$(np)=n$:np=np+1:if rl=0 then 190
220 print"the same, a vic bank lower (0: none):"
230 q$="drive":dd=0:gosub 870:qd(np-1)=d:l$(np-1)="":if d then l$(np-1)=n$
240 goto 190
250 o$=f$(0):if right$(o$,4)=".prg" then o$=left$(o$,len(o$)-4)
260 o$=left$(o$,13)+".lm"
270 d$=mid$(str$(pd(0)),2):print"drive for the module [";d$;:input"]";d$
280 od=val(d$):if od<8 or od>30 then 270
290 print"the module's name [";o$;:input"]";o$
300 rem each part read: its length counted, the two builds compared
310 for k=0 to np-1:print"reading ";f$(k):t=0:e$=f$(k):open 15,pd(k),15
320 open 2,pd(k),2,e$+",p,r":input#15,e,m$,x,y:if e>19 then 1130
330 get#2,x$,y$:m$="it can't be read":if st then 1130
340 a=asc(x$+z$)+256*asc(y$+z$):pa(k)=a:lw=0:if l$(k)="" then 410
350 e$=l$(k):open 14,qd(k),15:open 3,qd(k),3,e$+",p,r":input#14,e,m$,x,y
360 if e>19 then 1130
370 get#3,x$,y$:m$="it can't be read":if st then 1130
380 lw=1:b=asc(x$+z$)+256*asc(y$+z$):v=a:if a>=49152 then v=a-16384
390 if b=v then 410
400 gosub 1110:m$="a bank lower, it must load at $"+hx$:goto 1130
410 m$="it moves: it needs a build a bank lower"
420 e$=f$(k):if rl and lw=0 and a>=49152 then 1130
430 n=0:p=-1:if k then 490
440 for i=0 to 31:get#2,x$:s=st:ha(i)=asc(x$+z$):hb(i)=ha(i):if lw=0 then 460
450 get#3,y$:t=st:hb(i)=asc(y$+z$):if x$<>y$ then n=i:gosub 1000
460 if s or t then i=99
470 next:m$="not a module (no plg1 at its start)":n=32
480 if s or t or ha(0)<>80 or ha(1)<>76 or ha(2)<>71 or ha(3)<>49 then 1130
490 if lw=0 then 540
500 for n=n to 65535:get#2,x$:s=st:get#3,y$:t=st:if x$<>y$ then gosub 1000
510 if s=0 and t=0 then next
520 m$="a bank lower, it is not as long":if s<>64 or t<>64 then 1130
530 goto 560
540 for n=n to 65535:get#2,x$:if st=0 then next
550 m$="it can't be read to its end":if st<>64 then 1130
560 close 2:close 3:close 14:close 15:pn(k)=n+1:if rl then g%(ng)=0:ng=ng+1
570 next k:if rl=0 then 670
580 rem its claim (+10) must move with it
590 c=ha(10)+256*ha(11):if c=0 then c=65536
600 if pa(0)+pn(0)>c then c=pa(0)+pn(0)
610 w=c:tp=65536:bb=pa(0):if bb<49152 then 630
620 tp=49152:bb=bb-16384:w=c-16384:if c>=65535 then w=49152
630 m=hb(10)+256*hb(11):if m=0 then m=tp
640 if bb+pn(0)>m then m=bb+pn(0)
650 e$="its claim (+10) doesn't move with it:":m$="write it mb+..."
660 if m<>w then 1130
670 rem the module written: each part's address, length and bytes
680 print"writing ";o$:open 15,od,15
690 open 4,od,4,o$+",p,w":input#15,e,e$,x,y:if e<>63 then 730
700 close 4:y$="n":input"it is there already: replace it [n]";y$
710 if y$="y" then print#15,"s0:"+o$:goto 690
720 close 15:end
730 m$="":if e>=20 then 1130
740 tb=0:for k=0 to np-1:v=pa(k):gosub 1100:v=pn(k):gosub 1100:tb=tb+4+pn(k)
750 open 2,pd(k),2,f$(k)+",p,r":get#2,x$,x$:i=0:if k or rl=0 then 780
760 for i=0 to 27:get#2,x$:x=asc(x$+z$):if i=27 then x=x or 128
770 print#4,chr$(x);:next
780 for i=i to pn(k)-1:get#2,x$:if x$="" then x$=z$
790 print#4,x$;:next:close 2:next k:if rl=0 then 820
800 v=0:gosub 1100:v=ng+1:gosub 1100:for i=0 to ng-1:print#4,chr$(g%(i));:next
810 print#4,z$;:tb=tb+5+ng
820 close 4:input#15,e,e$,x,y:m$="":if e>=20 then 1130
830 close 15:print"done:";tb;"bytes"
840 if rl then print nr;"relocations: it can move a bank"
850 if rl=0 then print"no relocations: it can't move"
860 print"choose it in slopload 64: 3, the module":end
870 rem a file: q$ asked, dd the drive offered; d (0: none) and n$ come back
880 d$=mid$(str$(dd),2):print q$;" [";d$;:input"]";d$:d=val(d$)
890 if d=0 then return
900 if d<8 or d>30 then 880
910 n$="":input"its file name ($: files)";n$:if n$="" then 910
920 if n$<>"$" then return
930 open 15,d,15:open 1,d,0,"$":input#15,e,m$,x,y:if e>19 then print m$:goto 990
940 get#1,x$,x$
950 get#1,x$,x$:if st then 990
960 get#1,x$,y$:print asc(x$+z$)+256*asc(y$+z$);
970 get#1,x$:if x$<>"" then print x$;:goto 970
980 print:goto 950
990 close 1:close 15:goto 910
1000 rem a byte that differs a bank lower: a relocation (it must be $40 less)
1010 x=asc(x$+z$):y=asc(y$+z$)
1020 if a>=49152 and ((x-y)and 255)=64 and ng<990 then 1070
1030 v=a+n:gosub 1110:e$=e$+", at $"+hx$+":":m$="over 990 relocations"
1040 if ((x-y)and 255)<>64 then m$="not $40 less (an address not from mb)"
1050 if a<49152 then m$="it stays, but differs a bank lower"
1060 goto 1130
1070 q=n-p:p=n:nr=nr+1
1080 if q>254 then g%(ng)=255:ng=ng+1:q=q-254:goto 1080
1090 g%(ng)=q:ng=ng+1:return
1100 print#4,chr$(v-256*int(v/256));chr$(int(v/256));:return
1110 hx$="":for j=1 to 4:u=int(v/16):hx$=mid$(h$,v-u*16+1,1)+hx$:v=u:next:return
1120 rem e$ and m$ said, and every file closed: the drives' own channels last
1130 print e$:if m$<>"" then print m$
1140 close 1:close 2:close 3:close 4:close 14:close 15:end
