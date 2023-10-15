BDOS	equ 5
PRINTL	equ 9
READL	equ 10
OPENF	equ 15
READF	equ 20
IBUFLEN equ 100
CR	equ 0Ah
LF	equ 0Dh
MSCNT	equ 132
BUFF	equ 80h
FCB	equ 5Ch
TTYBASE equ 10h
TTYIO	equ TTYBASE + 1
CRTBASE equ 12h
CRTIO	equ CRTBASE + 1

ESC	equ 27

FCBFN	equ FCB+1
FCBFT	equ FCB+9
FCBCR	equ FCB+32

	org	100h
				; set up local stack
start	lxi	h,0		; zero out HL
	dad	sp		; set HL to CCP SP
	shld	OLDSP		; store SP to OLDSP
	lxi	sp,STKTOP	; load local sp to sp reg
				; copy arguments to local area
	lxi	h,BUFF		; set hl to BUFF address
	mov	c,m		; prep for memcpy
				; now ready for memcpy
				; BC is number of bytes to copy
	lxi	d,BUFF		; DE is source address
	lxi	h,args		; HL is target address
	call	memcpy		; call memcpy subroutine

	call	clrscr		; clear screen

	lxi	d,welcome	; load DE with welcome address
	call	printf		; call print routine


loop	in	TTYBASE		; Check for byte on TTY port
	rrc			; Rotate through carry
	jc	tty		; Jump to TTY

	in	CRTBASE		; Check for bye on CRT port
	rrc			; Rotate through carry
	jc	crt		; Jump to CRT
	jmp	loop

tty	in	TTYIO		; Grab incoming TTY byte
	call	ttycheck	; call ttycheck routine
	out	CRTIO		; Push byte out CRT port
	jmp	loop

crt	in	CRTIO		; Grab incoming CRT byte
	out	TTYIO		; Push byte out TTY port
	jmp	loop

ttycheck
	cpi	15		; Check for Ctrl-O
	jz	mmenu		; If Zero is SET, jump to menu
	ret

sfile	call	newline		; Call newline subroutine
	lxi	d,sfltxt	; Load DE with sfltxt address
	mvi	c,PRINTL	; Set up writeline BDOS call
	call	BDOS		; Call BDOS subroutine
	call	rdinbuf		; Call rdinbuf subroutine

	call	initfcb		; call initfcb routine
	call	cpyfcb		; call copyfcb routine
	call	openfcb		; call openfcb routine

	call	newline		; Call newline subroutine
	jmp	loop		; Jump back loop

rfile	call	newline		; Call newline subroutine
	lxi	d,rfltxt	; Load DE with rfltxt address
	call	printf
	call	rdinbuf		; Call rdinbuf subroutine
	call	newline		; Call newline subroutine
	jmp	loop		; Jump back loop

rdinbuf lxi	d,inbuf		; Set DE to inbuf address
	mvi	a,IBUFLEN	; store IBUFLEN to Accumulator
	stax	d		; Set first byte of inbuf to IBUFLEN
	call	readline	; call readline

	lxi	h,inbuf+1	; Set (hl) to start of inbuf string
	call	setendch	; call setendch subroutine
	ret			; Return from subroutine

newline lxi	d,nline		; Load DE to nline address
	call	printf
	ret			; Return from subroutine

exit	lhld	OLDSP		; load OLDSP to HL
	SPHL			; Load HL to SP
	ret			; Return to CP/M

initfcb lxi	h,FCB		; load FCB address to HL
	mvi	a,0		; set byte to set to 0
	mvi	c,36		; set copy length to 36
	call	memset		; call memset routine
	
	; memset FCBFN+FCBFT to ' '
	mvi	a,' '		; load ' ' into accumulator
	mvi	c,8+3		; load 11 into the counter
	lxi	h,FCBFN		; load FCBFN address to HL
	call	memset		; call memset routine
	ret

cpyfcb	lda	inbuf+1		; find number of bytes typed in filename
	cpi	0		; check if empty
	cz	clrscr		; call clrscr routine
	jz	opennok		; if empty, error out
	cpi	8+1+3		; compare against largest filename size
	jz	fchkcnt		; Jump to GOOD if Acc == '9'
	jnc	flnerr		; Jump to ERR if Acc > '9'
	; continue
fchkcnt ; set end char '$'
	lxi	h,inbuf+1	; Set (HL) to char num of inbuf string
	call	setendch	; call setendch

	; copy filename
	lxi	h,inbuf+2	; load (HL) with first byte of filename
	lxi	d,FCBFN		; load DE with FDBFN address
fnloop	mov	a,m		; move M to A
	cpi	'.'		; compare against '.'
	jz	copyext		; if so, copy the extension
	cpi	'a' - 1		; see if lowercase
	jc	notlow		; if not so, pass through
	ani	11011111b	; convert A to uppercase
notlow	stax	d		; store A to DE address
	inx	h		; increment TEMPBUF address
	inx	d		; increment inbuf address
	jmp	fnloop

	; copy extension
copyext inx	h		; increment HL past the '.'
	lxi	d,FCBFT		; load FCBFT address to DE
extloop mov	a,m		; move M to A
	cpi	'$'		; check if end of line
	rz			; return if so (done)
	cpi	'a' - 1		; check A if uppercase
	jc	notlowe		; if not so, pass through
	ani	11011111b	; convert A to uppercase
notlowe stax	d		; store A to DE address
	inx	h		; increment TEMPBUF address
	inx	d		; increment inbuf address
	jmp	extloop

openfcb call	open		; call open routine
	cpi	255		; check if returned 255
	jnz	openokl		; if not so, open worked
	jmp	opennokl	; jump to open error

openokl call	newline		; print newline
	call	openok		; call openok routine
	ret

opennokl
	call	newline		; print newline
	call	opennok		; call opennok routine
	ret
	
flnerr	lxi	d,flnerrmsg	; load flnerrmsg address to DE
	call	printf		; call printf routine
	call	newline		; print newline
	ret

open	xra	a		; set A to zero
	sta	FCBCR		; store A to FCBCR location
	lxi	d,FCB		; load DE with FCB address
	mvi	c,OPENF		; Prepare for BDOS call
	call	BDOS		; call BDOS routine
	ret

openok	call	newline		; print newline
	call	sendfile	; call sendfile routine
	ret

opennok call	newline		; print newline
	lxi	d,opennokmsg	; set DE to opennokmsg address
	call	printf		; call print routine
	ret

sendfile
freadl	lxi	d,FCB		; load FCB address to DE
	mvi	c,READF		; set up BDOS call
	call	BDOS		; call BDOS routine
	cpi	0		; check return code
	jnz	freaderr	; if not zero, error
	
	mvi	c,128		; set C to 128 (counter)
	lxi	h,BUFF		; set HL to BUFF address
breadl	mov	a,m		; move M to A
	mov	b,a		; back up byte
	cpi	1Ah		; check if EOF byte
	rz			; if so, done
	call	sendbyte	; call sendbyte routine
	inx	h		; increment BUFF address
	dcr	c		; decrement coutner
	jz	freadl		; if zero, read next record
	jmp	breadl

sendbyte
	mov	a,b		; restore byte
	out	CRTIO		; send byte out CRTIO port
	cpi	CR		; check if byte was carriage return
	jz	crdelay		; if so, jump to carriage return routine
	lda	delays		; set A to 20ms
	call	delay		; call delay routine
	jmp	rbytel		; pass through
crdelay	lda	delays+1	; set A to 50ms
	call	delay		; call delay

rbytel	in	CRTBASE		; Check for byte on TTY port
	rrc			; Rotate through carry
	jc	bytein		; Jump to TTY if byte on port
	jmp	rbytel
bytein	in	CRTIO		; read in byte
	out	TTYIO		; print byte to local terminal
	ret

freaderr
	ret			; do nothing on error, return

delay	mvi	b,MSCNT		; set B to MSCNT
dly1	dcr	b		; decrement B
	jnz	dly1		; loop until zero
	dcr	a		; decrement A
	jnz	delay		; loop until zero
	ret                     ; return from subroutine

setendch			; requires hl to be buffer+1
	mvi	d,0		; Reset d to 0
	mov	e,m		; de = length of read (d = 0, e = l)
	dad	d		; Add DE to HL (add IBUFLEN to inbuf
				; start)
	inx	h		; Increment to end of inbuf
	mvi	a,'$'		; String terminator
	mov	m,a		; Append string terminator
	ret

mmenu
	call	drawmmenu	; call drawmenu routine
mmgetc	call	getc		; call getc routine
	cpi	's'
	jz	sfile		; go to sendfile
	cpi	'r'
	jz	rfile		; go to receivefile
	cpi	'o'
	jz	moptions
	cpi     'e'             ; Option e
	cz	clrscr
	rz
	cpi	'q'		; Option q
	cz	clrscr		; call clrscr
	jz	exit		; If option q, exit to CP/M
	jmp	mmgetc

moptions
	call	drawomenu
omgetc	call	getc
	; parse
	cpi     'e'             ; Option e
	cz	retMmenu	; return to main menu
	;cpi	'c'		; Option c
	;cz	charedit
	;cpi	'l'		; Option l
	;cz	lineedit
	jmp	omgetc		; jump in loop

drawmmenu
	call	clrscr		; call clrscr routine
	lxi	d,menumsg	; load menumsg address to DE
	call	printf		; call printf routine
	ret			; return from subroutine

drawomenu
	call	clrscr		; call clrscr routine
	lxi	d,omenumsg	; load omenumsg address to DE
	call	printf		; call printf routine
	ret			; return from subroutine

retMmenu
	call	clrscr		; call clrscr
	;rz
	pop	h		; pop out last memory location
	jmp	mmenu		; return to main menu

readline
	mvi	c,READL		; Set up readline BDOS call
	call	BDOS		; Call BDOS routine
	ret

gloop	call	clrscr		; call clrscr routine
	lxi	sp,STKTOP	; Reset the stack (prevent overflow)
	jmp	loop		; Go back to main loop

sendcr	mvi	a,CR		; move CR to A
	out	CRTIO		; send CR out CRTIO
	ret			; return from subroutine

clrscr	lxi	d,clrmsg	; load clrmsg address to DE
	call	printf		; call print routine'
	ret                     ; return from subroutine

printf	mvi	c,PRINTL	; set up BDOS call
	call	BDOS		; call BDOS routine
	ret			; return from subroutine

getc	mvi	b,0
	mvi	c,1		; move 1 to BC
	call	BDOS		; call BDOS routine
	ret			; return from subroutine

memcpy	mov	a,b		; memcpy subroutine (copied from wikipedia)
	ora	c		; compare low BC byte to high BC byte
	rz			; if zero, return
mcloop	ldax	d		; load first source byte to A
	mov	m,a		; store byte to target address
	inx	d		; increment source address
	inx	h		; increment target address
	dcx	b		; decrement byte counter
	mov	a,b		; prep compare
	ora	c		; compare low BC byte to high BC byte
	jnz	mcloop		; if not zero, continue memcpy loop
	ret			; return from subroutine

memset	mov	m,a		; load accumulator into hl location
	inx	h		; increment hl
	dcr	c		; decrement counter
	jnz	memset		; if not zero, loop
	ret                     ; return from subroutine

welcome db	'YATERM 1.1',CR,LF,'Patrick Jackson'
	db	CR,LF,'Ctrl-O for Options',CR,LF,'$'
sfltxt	db	'File to send: ','$'
rfltxt	db	'File to receive: ','$'
opennokmsg
	db	'File not found!','$'
flnerrmsg
	db	'Filename too long!','$'
clrmsg	db	ESC,'[2J',ESC,'[H','$'
menumsg
	db	ESC,'[5;33H'
	db	201,205,205,205,205,205,205,205,205,205,205,205,205,205,187
	db	ESC,'[6;33H'
	db	186,'S Send...    ',186,CR,LF
	db	ESC,'[7;33H'
	db	204,205,205,205,205,205,205,205,205,205,205,205,205,205,185
	db	ESC,'[8;33H'
	db	186,'R Recieve... ',186,CR,LF
        db	ESC,'[9;33H'
	db	204,205,205,205,205,205,205,205,205,205,205,205,205,205,185
	db	ESC,'[10;33H'
	db	186,'O Options... ',186,CR,LF
        db	ESC,'[11;33H'
	db	204,205,205,205,205,205,205,205,205,205,205,205,205,205,185
	db	ESC,'[12;33H'
	db	186,'E Exit Menu  ',186,CR,LF
        db	ESC,'[13;33H'
	db	204,205,205,205,205,205,205,205,205,205,205,205,205,205,185
        db	ESC,'[14;33H'
	db	186,'Q Quit YaTerm',186,CR,LF
	db	ESC,'[15;33H'
	db	200,205,205,205,205,205,205,205,205,205,205,205,205,205,188
mmend	db	ESC,'[16;33H'
	db	'$'
	
	; To change numbers, hit character
	; then do (+) or (-) to change value
	; then do itoa
omenumsg
	db	ESC,'[6;33H'
	db	201,205,205,205,205,205,205,205,205,205,205,205,205,205,187
	db	ESC,'[7;33H'
	db	186,'Chr Delay  20',186,CR,LF
	db	ESC,'[8;33H'
	db	204,205,205,205,205,205,205,205,205,205,205,205,205,205,185
	db	ESC,'[9;33H'
	db	186,'Ln  Delay  50',186,CR,LF
        db	ESC,'[10;33H'
	db	204,205,205,205,205,205,205,205,205,205,205,205,205,205,185
	db	ESC,'[11;33H'
	db	186,'E Exit Menu  ',186,CR,LF
        db	ESC,'[12;33H'
	db	200,205,205,205,205,205,205,205,205,205,205,205,205,205,188
omend	db	ESC,'[13;33H'
	db	'$'
nline	db	CR,LF,'$'
inbuf	ds	IBUFLEN+2
delays	db	20,50
args	ds	32
OLDSP	ds	2
	ds	64
STKTOP
