	SECTION TutDemo,CODE

	INCDIR ""
	INCLUDE "Blitter-Register-List.S"

;;    ---  screen buffer dimensions  ---

w	=352
h	=256
bplsize	=w*h/8
ScrBpl	=w/8

;;    ---  logo dimensions  ---

logow		=240
logoh		=62
logomargin	=(320-logow)/2
logobpl		=logow/8
logobwid	=logobpl*3

;;    ---  font dimensions  ---
fontw		=288
fonth		=100
fontbpls	=3
FontBpl		=fontw/8

plotY	=100
plotX	=w-32


Start:

OSoff:
	movem.l d1-a6,-(sp)
	move.l 4.w,a6		;execbase
	move.l #gfxname,a1
	jsr -408(a6)		;oldopenlibrary()
	move.l d0,a1
	move.l 38(a1),d4	;original copper ptr

	jsr -414(a6)		;closelibrary()

	move.w #$4c-6,d7	;start y position
	moveq #1,d6		;y add
	move.w $dff01c,d5
	move.w $dff002,d3

	move.w #$138,d0		;wait for EOFrame
	bsr.w WaitRaster
	move.w #$7fff,$dff09a	;disable all bits in INTENA
	move.w #$7fff,$dff09c	;disable all bits in INTREQ
	move.w #$7fff,$dff09c	;disable all bits in INTREQ
	move.w #$7fff,$dff096	;disable all bits in DMACON
	move.w #$87e0,$dff096

	bsr Init
	bsr mt_init

	move.l #Copper,$dff080
	bsr Main

OSon:

	bsr mt_end

	move.w #$7fff,$dff096
	or.w #$8200,d3
	move.w d3,$dff096
	move.l d4,$dff080
	or #$c000,d5
	move d5,$dff09a
	movem.l (sp)+,d1-a6
	moveq #0,d0
	rts			;end of program return to AmigaOS



********** ROUTINES **********
Main:
	movem.l d0-a6,-(sp)

**************************

MainLoop:
	move.w #$02a,d0		;wait for EOFrame
	bsr.w WaitRaster

;-----frame loop start---
	add.b #1,Spr+1

	add d6,d7		;add "1" to y position

	cmp #$4c+logoh+1,d7	;bottom check
	blo.b ok1
	neg d6			;change direction
ok1:

	cmp.b #$4c-6,d7		;top check
	bhi.b ok2
	neg d6			;change direction
ok2:

	move.l #waitras1,a0
	move d7,d0
	moveq #6-1,d1
.l:
	move.b d0,(a0)
	add.w #1,d0
	add.w #8,a0
	DBF d1,.l

	bsr Scrollit

	moveq #32,d2
	move.b LastChar(PC),d0
	cmp.b #'I',d0
	bne.s .noi
	moveq #16,d2
.noi:
	move.w ScrollCtr(PC),d0
	addq.w #4,d0
	cmp.w d2,d0
	blo.s .nowrap

	move.l ScrollPtr(PC),a0
	cmp.l #ScrollTextWrap,a0
	blo.s .noplot
	lea ScrollText(PC),a0
.noplot:
	bsr PlotChar			;preserves a0

	addq.w #1,a0
	move.l a0,ScrollPtr

	clr.w d0
.nowrap:
	move.w d0,ScrollCtr

;-----frame loop end---

	bsr mt_music

	btst #6,$bfe001
	bne.w MainLoop

**************************

	movem.l (sp)+,d0-a6
	rts

row	=288*3*20/8
col	=4

PlotChar:	;a0=scrollptr
	movem.l d0-a6,-(sp)
	lea $dff000,a6
	bsr BlitWait

	moveq #0,d0
	move.b (a0)+,d0			;ASCII value
	move.b d0,LastChar

	sub.w #32,d0
	lea FontTbl(PC),a0
	move.b (a0,d0.w),d0
	divu #9,d0			;row
	move.l d0,d1
	swap d1				;remainder (column)

	mulu #row,d0
	mulu #col,d1

	add.l d1,d0			;offset into font bitmap
	add.l #Font,d0

	move.l #$09f00000,BLTCON0(a6)
	move.l #$ffffffff,BLTAFWM(a6)
	move.l d0,BLTAPTH(a6)
	move.l #Screen+ScrBpl*3*plotY+plotX/8,BLTDPTH(a6)
	move.w #FontBpl-col,BLTAMOD(a6)
	move.w #ScrBpl-col,BLTDMOD(a6)

	move.w #20*3*64+2,BLTSIZE(a6)
	movem.l (sp)+,d0-a6
	rts

Scrollit:
;;    ---  scroll!  ---
bltoffs	=100*ScrBpl*3

blth	=20
bltw	=w/16
bltskip	=0				;modulo
brcorner=blth*ScrBpl*3-2

	movem.l d0-a6,-(sp)
	lea $dff000,a6
	bsr BlitWait

	move.l #$49f00002,BLTCON0(a6)
	move.l #$ffffffff,BLTAFWM(a6)
	move.l #Screen+bltoffs+brcorner,BLTAPTH(a6)
	move.l #Screen+bltoffs+brcorner,BLTDPTH(a6)
	move.w #bltskip,BLTAMOD(a6)
	move.w #bltskip,BLTDMOD(a6)

	move.w #blth*3*64+bltw,BLTSIZE(a6)
	movem.l (sp)+,d0-a6
	rts

Init:
	movem.l d0-a6,-(sp)

	IF 1=0
	moveq #0,d1
	lea Screen,a1
	move.w #bplsize/2-1,d0
.l:	move.w d1,(a1)+
	addq.w #1,d1
	dbf d0,.l
	ENDC

	lea Logo,a0		;ptr to first bitplane of logo
	lea CopBplP,a1		;where to poke the bitplane pointer words.
	move #3-1,d0
.bpll:
	move.l a0,d1
	swap d1
	move.w d1,2(a1)		;hi word
	swap d1
	move.w d1,6(a1)		;lo word

	addq #8,a1		;point to next bpl to poke in copper
	lea logobpl(a0),a0
	dbf d0,.bpll

	lea Screen,a0		;ptr to first bitplane of font
	lea ScrBplP,a1		;where to poke the bitplane pointer words.
	moveq #fontbpls-1,d0
.bpll2:
	move.l a0,d1
	swap d1
	move.w d1,2(a1)		;hi word
	swap d1
	move.w d1,6(a1)		;lo word

	addq #8,a1		;point to next bpl to poke in copper
	lea ScrBpl(a0),a0
	dbf d0,.bpll2


	lea SprP,a1
	lea Spr,a0
	move.l a0,d1
	swap d1
	move.w d1,2(a1)
	swap d1
	move.w d1,6(a1)


	lea NullSpr,a0
	move.l a0,d1
	moveq #7-1,d0
.sprpl:
	addq.w #8,a1
	swap d1
	move.w d1,2(a1)
	swap d1
	move.w d1,6(a1)
	DBF d0,.sprpl

	lea FontE-8*2,a0
	lea FontPalP+2,a1
	moveq #8-1,d0
.coll:	move.w (a0)+,(a1)+
	addq.w #2,a1
	DBF d0,.coll

	movem.l (sp)+,d0-a6
	rts

CopyB:	;d0,a0,a1=count,source,destination
.l:	move.b (a0)+,(a1)+
	subq.l #1,d0
	bne.s .l
	rts

BlitWait:
	tst DMACONR(a6)			;for compatibility
.waitblit:
	btst #6,DMACONR(a6)
	bne.s .waitblit
	rts

WaitRaster:		;wait for rasterline d0.w. Modifies d0-d2/a0.
	move.l #$1ff00,d2
	lsl.l #8,d0
	and.l d2,d0
	lea $dff004,a0
.wr:	move.l (a0),d1
	and.l d2,d1
	cmp.l d1,d0
	bne.s .wr
	rts

	INCLUDE "ProTracker2.3a-Replay.S"
********** DATA **********
FontTbl:
	dc.b 43,38
	blk.b 5,0
	dc.b 42
	blk.b 4,0
	dc.b 37,40,36,41
	dc.b 26,27,28,29,30,31,32,33,34,35
	blk.b 5,0
	dc.b 39,0
	dc.b 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
	dc.b 22,23,24,25
	EVEN

ScrollPtr:
	dc.l ScrollText
ScrollText:
	dc.b "HELLO AND WELCOME TO THIS NEW RELEASE BY YOUR FAVORITE DEMOGROUP CALLED REAM RIC! THE DEMO WAS DONE BY USING THE ASM SKOOL TECHNIQUE, THANKS FOR THAT PHOTON! THIS IS ALSO OUR FIRST DEMO WITH MY TRASH LOGO APPEARING... I RATHER NOT TALK ABOUT HOW MUCH I'M BAD AT CREATING LOGOS LOL. THAT WAS ENOUGH TALKING! LETS HOP ON TO THE CREDITS TAB!!!       CODED BY KAST601       MUSIC BY KAST601       GRAPHICS BY KAST601              AS YOU COULD TELL I DID THIS DEMO KINDA ALONE... IF SOMEONE WILL WANT TO JOIN REAM RIC MESSAGE ME ON DISCORD   LOSBRTKOS      WE TAKE ANY KIND OF SCENERS. BUT WE ACTUALLY VERY MUCH NEED GRAPHICIAN NOW... SO PLEASE LET ME KNOW ON MY DISCORD! ACTUALLY, I KINDA FEEL BAD FOR THOSE PEOPLE THAT LEFT SCENE, OR ARE NOT ACTIVE LIKE THEY WERE BACK THOSE TIMES... SO I WOULD LIKE TO GREET    MAKTONE/FAIRLIGHT   HOMICIDE/ALPHA FLIGHT   JESTER/SANITY   PHOTON/SCOOPEX    2PAC/ZENITH    TDK/MELON    AND ALL THE REST OF PEOPLE...    AND NOW LETS GREET MY FRIENDS, AND NICE PEOPLE    LFO/TEAM VYRAL    D/V/HOKUTO FORCE    LYNX/ORANGES    PSIONIKAL/ORANGES    FILIPPP/DOT    ENDERBANANA/NEWLINE    AND ALL THE REST OF MY FRIENDS!!!    ALSO, JUST A QUICK REMINDER. THERE ARE MANY DEMOPARTIES ACROSS THE WHOLE WORLD. IF YOU REALLY LIKE TO SUPPORT THE DEMOSCENE, GO TO SOME DEMOPARTIES. THERE WILL BE ONE CALLED FOREVER 2026, THAT I WILL VISIT!!! ALSO REAM RIC IS LOOKING FOR EVERY KIND OF A CODER FOR AMIGA OCS/ECS, SO DON'T HESITATE AND CONTACT ME ON DISCORD LOSBRTKOS!      HAVE A NICE DAY, AND           DEMO LOOP!    DEMO LOOP!    DEMO LOOP!!!          "
	blk.b w/32,' '
ScrollTextWrap:

LastChar:dc.b 0
	EVEN
ScrollCtr:
	dc.w 0

gfxname:
	dc.b "graphics.library",0

	SECTION TutData,DATA_C
Spr:
	dc.w $ec40,$fc00	;Vstart.b,Hstart/2.b,Vstop.b,%A0000SEH
	dc.w %0000000000000000,%0000000000000000
	dc.w %0001001001111000,%0000000000000000
	dc.w %0001001001000000,%0000000000000000
	dc.w %0001001001000000,%0000000000000000
	dc.w %0001110001111000,%0000000000000000
	dc.w %0001001001001000,%0000000000000000
	dc.w %0001001001001000,%0000000000000000
	dc.w %0001001001111000,%0000000000000000
	dc.w %0000000000000000,%0000000000000000
	dc.w %0000000000000000,%0000000000000000
	dc.w %0000000000000000,%0000000000000000
	dc.w %0000000000000000,%0000000000000000
	dc.w %0000000000000000,%0000000000000000
	dc.w %0000000000000000,%0000000000000000
	dc.w %0000000000000000,%0000000000000000
	dc.w %0000000000000000,%0000000000000000
	dc.w 0,0

NullSpr:
	dc.w $2a20,$2b00
	dc.w 0,0
	dc.w 0,0

Copper:
	dc.w $1fc,0			;slow fetch mode, AGA compatibility
	dc.w $100,$0200
	dc.b 0,$8e,$4c,$81
	dc.b 0,$90,$2c,$c1
	dc.w $92,$38+logomargin/2
	dc.w $94,$d0-logomargin/2

	dc.w $108,logobwid-logobpl
	dc.w $10a,logobwid-logobpl

	dc.w $102,0

	dc.w $1a2,$cc5
	dc.w $1a4,0
	dc.w $1a6,$752
SprP:
	dc.w $120,0
	dc.w $122,0
	dc.w $124,0
	dc.w $126,0
	dc.w $128,0
	dc.w $12a,0
	dc.w $12c,0
	dc.w $12e,0
	dc.w $130,0
	dc.w $132,0
	dc.w $134,0
	dc.w $136,0
	dc.w $138,0
	dc.w $13a,0
	dc.w $13c,0
	dc.w $13e,0

CopBplP:
	dc.w $e0,0
	dc.w $e2,0
	dc.w $e4,0
	dc.w $e6,0
	dc.w $e8,0
	dc.w $ea,0
		
	dc.w $180,$000
	dc.w $2a07,$fffe
	dc.w $180,$111
	dc.w $2c07,$fffe
	dc.w $180,$222
	dc.w $2e07,$fffe
	dc.w $180,$333
	dc.w $3007,$fffe
	dc.w $180,$444
	dc.w $3207,$fffe

LogoPal:
	dc.w $0180,$0000,$0182,$022f,$0184,$033f,$0186,$044f
	dc.w $0188,$033d,$018a,$066f,$018c,$0000,$018e,$0fff

	dc.w $100,$3200
waitras1:
	dc.w $8007,$fffe
	dc.w $180,$000
waitras2:
	dc.w $8103,$fffe
	dc.w $180,$000
waitras3:
	dc.w $8207,$fffe
	dc.w $180,$000
waitras4:
	dc.w $8307,$fffe
	dc.w $180,$000
waitras5:
	dc.w $8407,$fffe
	dc.w $180,$000
waitras6:
	dc.w $8507,$fffe
	dc.w $180,$000

	dc.w $9507,$fffe
	dc.w $100,$0200
	dc.w $95df,$fffe
ScrBplP:
	dc.w $e0,0
	dc.w $e2,0
	dc.w $e4,0
	dc.w $e6,0
	dc.w $e8,0
	dc.w $ea,0
	dc.w $108,ScrBpl*3-320/8
	dc.w $10a,ScrBpl*3-320/8
	dc.w $92,$38
	dc.w $94,$d0
	dc.w $100,fontbpls*$1000+$200

FontPalP:
	dc.w $0180,$0667,$0182,$0ddd,$0184,$0833,$0186,$0334
	dc.w $0188,$0a88,$018a,$099a,$018c,$0556,$018e,$0633

	dc.w $ffdf,$fffe

	dc.w $1007,$fffe
	dc.w $180,$11f
	dc.w $1207,$fffe
	dc.w $180,$11f
	dc.w $1407,$fffe
	dc.w $180,$22f
	dc.w $1607,$fffe
	dc.w $180,$22f
	dc.w $1807,$fffe
	dc.w $180,$33f
	dc.w $1a07,$fffe
	dc.w $180,$33f
	dc.w $1c07,$fffe
	dc.w $180,$44f
	dc.w $1e07,$fffe
	dc.w $180,$44f
	dc.w $2107,$fffe
	dc.w $180,$55f
	dc.w $2307,$fffe
	dc.w $180,$55f
	dc.w $2507,$fffe
	dc.w $180,$66f
	dc.w $2707,$fffe
	dc.w $180,$66f
	dc.w $2907,$fffe
	dc.w $180,$77f
	dc.w $2b07,$fffe
	dc.w $180,$77f
	dc.w $2d07,$fffe

	dc.w $ffff,$fffe
CopperE:


Font:
	INCBIN "font1"
FontE:

Logo:	INCBIN "logo1"
LogoE:
	dcb.b logobwid*6,0

	SECTION TutBSS,BSS_C
Screen:
	ds.b bplsize*fontbpls

	SECTION TutBSSMod,DATA_C
mt_data:
	INCBIN "Singularity.mod"

	END


Bit	Channel


	1001
	ABCD -> D

0	000	0
1	001	0
2	010	0
3	011	0
4	100	1
5	101	1
6	110	1
7	111	1


%11110000	=$f0

