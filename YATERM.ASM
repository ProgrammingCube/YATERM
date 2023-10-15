; YATERM V7
; Patrick Jackson
; Simple terminal for CP/M-80 machines

TRUE	equ	0FFFFH
FALSE	equ	NOT	TRUE

; To use on your machine, change
ZILOG	equ	FALSE
TTYBASE equ	10h
CRTBASE equ	12h
TTYIO	equ	TTYBASE + 1
CRTIO	equ	CRTBASE + 1
CP437	equ	FALSE
; to your respective CPU, ports, codepage and
; assemble with your native CP/M assembler.

; CP/M BDOS routines
BDOS	equ	5
PRINT	equ	9
READ	equ	10
OPENF	equ	15
READF	equ	20

; CP/M arg and file control block
BUFF	equ	80h
FCB	equ	5Ch
FCBFN	equ	FCB+1
FCBFT	equ	FCB+9
FCBCR	equ	FCB+32

; char definitions
CR	equ	0Ah
LF	equ	0Dh
ESC	equ	27
EOL	set	'$'					; CP/M EOL
EOF	equ	1Ah					; CP/M EOF

; Machine delay ~ 2MHz system
MSCNT	equ	132

; stdin buffer
STDINSZ equ	32

; keys
CTRLO	equ	15
KEYS	equ	'S'
KEYR	equ	'R'
KEYO	equ	'O'
KEYE	equ	'E'
KEYQ	equ	'Q'

; menu characters
	IF	CP437
ULCORNR	equ	201
URCORNR	equ	187
LLCORNR	equ	200
LRCORNR	equ	188
VERTCHR	equ	186
HORZCHR	equ	205
LHSIDE	equ	204
RHSIDE	equ	185
	ENDIF
	IF	NOT	CP437
ULCORNR	equ	'+'
URCORNR	equ	'+'
LLCORNR	equ	'+'
LRCORNR	equ	'+'
VERTCHR	equ	'|'
HORZCHR	equ	'-'
LHSIDE	equ	'+'
RHSIDE	equ	'+'
	ENDIF

	org	100h

; -------------------SETUP---------------------

start	lxi	h,0		; set up local stack
	dad	sp
	shld	OLDSP
	lxi	sp,STKTOP	; load new stack ptr

	lxi	h,BUFF		; copy args to ARGS
	mvi	c,m
	lxi	d,BUFF
	lxi	h,ARGS
	call	memcpy
	
	lxi	d,STRBUF	; set up input buffer
	mvi	a,STDINSZ
	stax	d
	
	call	clrscrn		; clear screen

	lxi	d,welcmtxt	; print welcome text
	call	puts

; --------------MAIN PROGRAM-------------------

mainloop
	lda	STATE		; get state of program
	; pseudo-case table
	cpi	0		; get I/O bytes
	push	psw
	cz	getio
	pop	psw

	cpi	1		; main menu entered
	push	psw
	cz	mainmenu
	pop	psw

	cpi	2		; exit to CP/M
	jz	exit

	; end of case table
mainbreak
	jmp	mainloop	; loop

; -------------------EXIT----------------------

exit	lhld	OLDSP		; restore old sp
	SPHL
	ret			; return to CP/M

; --------------YATERM MAIN MENU---------------

; mainmenu
; Sets menu width and height and (ultimately) X/Y screen position

mainmenu
	lxi	d,mmenutxt				; this will ultimately be the
	call	clrscrn					; only thing you need to render
	call	drawmenu				; a menu
	call	getchar
	call	mmenuprs
	ret

; -------------YATERM MENU ROUTINES------------

; drawmenu
; Dynamically draws menus

drawmenu
	push	b
	
	call	getmdim
	shld	MENUWH

	call	shlbc					; first line draw
	mvi	a,ULCORNR
	call	putchar
drwfl	mvi	a,HORZCHR
	call	putchar
	dcr	c
	jnz	drwfl
	mvi	a,URCORNR
	call	putchar
	call	newline

horztxt	lda	MENUWH					; draw text line
	mov	c,a
	mvi	a,VERTCHR
	call	putchar	
	call	puts

	lhld	MENUWH
	mvi	h,0
	inx	d
	dad	d
	mov	e,l
	mov	d,h

	mvi	a,VERTCHR
	call	putchar
	call	newline

	dcr	b					; check if last line
	jz	lastline

	lda	MENUWH					; draw horizontal separator
	mov	c,a
	mvi	a,LHSIDE
	call	putchar
drawhorz
	mvi	a,HORZCHR
	call	putchar
	dcr	c
	jnz	drawhorz
	mvi	a,RHSIDE
	call	putchar
	call	newline
	jmp	horztxt

lastline
	lhld	MENUWH					; last line draw
	call	shlbc
	mvi	a,LLCORNR
	call	putchar
drwll	mvi	a,HORZCHR
	call	putchar
	dcr	c
	jnz	drwll
	mvi	a,LRCORNR
	call	putchar
	call	newline

	pop	b
	ret

; getmdim

; Gets menu dimensions
; Stores height in H and width in L

getmdim
	lxi	h,0
	ldax	d					; get height
	mov	h,a
	call	calcmwdt				; get width
	ret

; calcmwdt
; Calcuates menu width given menu structure at DE
; Puts length in L

calcmwdt
	inx	d
	mvi	l,0
	push	d
clcl	ldax	d
	cpi	EOL
	jz	clend
	inr	l
	inx	d
	jmp	clcl
clend	pop	d
	ret

; mmenuprs
; Parses input from main menu as uppercase

mmenuprs
	ani	11011111b
	cpi	'Q'
	cz	STATE2
	cpi	'S'
	push	psw
	cz	sendfile
	pop	psw
	call	getchar
	rz
	cpi	'E'
	jnz	mmnuprsn
	call	clrscrn
	call	STATE0
mmnuprsn
	ret

; ------------YATERM FILE ROUTINES-------------

; sendfile
; Reads input string and attempts to open and send
; file out CRTIO with character and line delay

sendfile
	call	newline
	lxi	d,sfiletxt
	call	puts
	lxi	d,STRBUF
	call	gets
	lxi	h,STRBUF
	call	setendch

	call	initfcb
	call	copyfcb
	call	openfcb

	cpi	255		; check if opened correctly
	push	psw
	cz	openntok	; if failed, show error then exit out
	pop	psw
	rz
	
	call	openok		; if successful, go here
	call	printdbg
	ret

	call	sendfcb		; send file over serial

	ret

; initfcb
; Initializes FCB (File Command Block) space to prep for opening files

initfcb	push	h
	push	b
	push	d
	lxi	h,FCB
	xra	a
	mvi	c,36
	call	memset
	mvi	a,' '
	mvi	c,8+3
	lxi	h,FCBFN
	call	memset
	pop	d
	pop	b
	pop	h
	ret

; copyfcb
; Copies filename in STRBUF to FCBFN and FCBFT
; Any unused spaces of FCBFN and FCBFT are filled with ' 's

copyfcb	lda	STRBUF+1				; get num bytes
	cpi	0					; check if empty
	rz						; return 0 if empty
	cpi	8+1+3+1					; compare against max filename len
	rz						; return 0 if true

	lxi	h,STRBUF+2				; get first char of STRBUF
	lxi	d,FCBFN					; get first char of FCBFN
fnloop	mov	a,m					; grab STRBUF char
	cpi	'.'					; see if '.'
	jz	copyext					; start copying extension
	ani	11011111b				; convert to uppercase
	stax	d					; store to FCBFN+inc
	inx	h					; increment STRBUF ptr
	inx	d					; increment FCBFN ptr
	jmp	fnloop					; loop

copyext	inx	h					; skip over '.'
	lxi	d,FCBFT					; get first char of FCBFT
extloop	mov	a,m					; get char at STRBUF
	cpi	EOL					; see if EOL char
	rz						; if so, done!
	ani	11011111b				; convert to uppercase
	stax	d					; store FCBFT+inc
	inx	h					; increment STRBUF ptr
	inx	d					; increment FCBFT ptr
	jmp	extloop					; loop

; openfcb
; Opens file in FCB

openfcb	call	open
	ret

; sendfcb
; Sends file opened with openfcb
; Sends as normal text, no encoding

sendfcb	
freadl	lxi	d,FCB
	mvi	c,READF
	cpi	0
	push	psw
	cnz	freaderr
	pop	psw
	rnz
	mvi	c,128
	lxi	h,BUFF
breadl	mov	a,m
	mov	b,a
	cpi	1Ah
	rz
	call	sendbyte
	inx	h
	dcr	c
	jz	freadl
	jmp	breadl

sendbyte
	mov	a,b
	out	CRTIO
	cpi	CR
	jz	crdelay		; if so, jump to carriage return routine
	lda	delayms		; set A to 20ms
	call	delay		; call delay routine
	jmp	rbytel		; pass through
crdelay	lda	delayms+1	; set A to 50ms
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
	

; openok
; Called if opening FCB succeeded

openok	call	newline
	push	d
	lxi	d,fileok
	call	BDOS
	pop	d
	;call	getchar
	ret

; openntok
; Called if opening FCB failed

openntok
	call	newline
	push	d
	lxi	d,ffopntxt
	call	BDOS
	pop	d
	;call	getchar
	ret

; setendch
; Sets end character of string at (HL) to EOL char
; Appends

setendch
	push	d
	push	h
	inx	d
	mvi	d,0
	mov	e,m
	dad	d
	inx	h
	mvi	m,'$'
	pop	h
	pop	d
	ret

; open
; Opens FCB and loads FCB with contents if initialized correctly

open	xra	a
	sta	FCBCR
	push	b
	push	d
	lxi	d,FCB
	mvi	c,OPENF
	call	BDOS
	pop	d
	pop	b
	ret

; ------------YATERM I/O ROUTINES--------------

; getio
; Determines if I/O byte is ready on SIO/2 card

getio	in	TTYBASE
	rrc
	cc	ttyin
	in	CRTBASE
	rrc
	cc	crtin
	ret

; ttyin
; Pulls in byte from TTYIO and outputs to CRTIO
; Returns byte to A

ttyin	in	TTYIO
	out	CRTIO
	call	ttypars
	ret

; ttyparse
; Parses the incoming TTYIO byte in A

ttypars	cpi	CTRLO
	cz	STATE1
	ret

; crtin
; Pulls in byte from CRTIO and outputs to TTYIO
; Returns byte to A

crtin	in	CRTIO
	out	TTYIO
	ret

; crtparse

; clrscrn
; Clears screen using VT100 Esc[2JEsc[H

clrscrn	push	d
	lxi	d,vt100clr
	call	puts
	pop	d
	ret

; ------------STATE MACHINE CHECK--------------

; STATE0
; Sets state machine to 0

STATE0	xra	a
	sta	STATE
	ret

; STATE1
; Sets state machine to 1

STATE1	mvi	a,1
	sta	STATE
	ret

; STATE2
; Sets state machine to 2

STATE2	mvi	a,2
	sta	STATE
	ret

; -----------------DEBUG/QOL-------------------

; printdbg
; Prints out a debug message

printdbg
	push	d
	lxi	d,debugtxt
	call	puts
	pop	d
	ret

; shlbc
; Stores H->B L->C

shlbc	mov	c,l
	mov	b,h
	ret

; newline
; Prints a newline (CR/LF)

newline	push	d
	lxi	d,nltxt
	call	puts
	pop	d
	ret

; --------------C-LIKE ROUTINES----------------

; puts()
; Prints string to stdout
; Does NOT produce newline like stdlib.c

puts	push	d
	push	b
	mvi	c,PRINT
	call	BDOS
	pop	b
	pop	d
	ret

; gets()
; Gets string from stdin and copies it to STRBUF
; Max STDINSZ chars

gets	push	d
	push	b
	mvi	c,READ
	call	BDOS
	pop	b
	pop	d
	ret

; getchar()
; Follows C getchar() on stdin
; Does NOT return int, returns uint8_t to A

getchar	push	b
	mvi	c,1
	call	BDOS
	pop	b
	ret

; putchar()
; Follows C putchar() on stdout
; Does not return char pushed to int

putchar	push	b
	push	d
	mvi	c,2
	mov	e,a
	call	BDOS
	pop	d
	pop	b
	ret

; memcpy(dest, src, len)
; Follows string.h
; dest      : (HL)
; src       : (DE)
; len       :  BC
; Returns pointer to dest (HL)
 
memcpy  push    h		; preserve (HL) to stack
	mov 	a,b     	; prep BC to see if BC == 0
	ora 	c       	; check if BC == 0
	jz	memcpy+16	; isz then end
	ldax    d       	; load (DE) to A
	mov 	m,a     	; store A to (HL)
	inx 	d       	; increment (DE)
	inx 	h       	; increment (HL)
	dcx 	b       	; decrement BC
	mov 	a,b     	; prep BC to see if BC == 0
	ora 	c       	; check if BC == 0
	jnz 	memcpy+6	; loop if BC > 0
	pop 	h       	; return (HL)
	ret

; memset(dest, byte, len)
; 256 max memset
; dest		: (HL)
; byte		: A
; len		: C
; Returns pointer to dest (HL)

memset	push	h
	push	b
	mov	m,a		; load accumulator into hl location
	inx	h		; increment hl
	dcr	c		; decrement counter
	jnz	memset		; if not zero, loop
	pop	b
	pop	h
	ret                     ; return from subroutine

; -------------STRING CONSTANTS----------------

welcmtxt
	db	'YATERM 2.0',CR,LF,'Patrick Jackson'
	db	CR,LF,'Ctrl-O for Menu',CR,LF,EOL

sfiletxt
	db	'File to send: ',EOL

rfiletxt
	db	'File to receive: ',EOL

fileok
	db	'File found!',EOL

ffopntxt
	db	'File not found!',EOL

nltxt	db	CR,LF,EOL

vt100clr
	db	ESC,'[2J',ESC,'[H',EOL

mmenutxt
	db	5
	db	'S Send       ',EOL
	db	'R Recieve    ',EOL
	db	'O Options    ',EOL
	db	'E Exit Menu  ',EOL
	db	'Q Quit YaTerm',EOL

omenutxt
	db	3
	db	'Chr Delay  20',EOL
	db	'Ln Delay   50',EOL
	db	'E Exit Menu  ',EOL

debugtxt
	db	'Made it here...',CR,LF,EOL

; -------------OTHER VARIABLES-----------------

; state machine var
STATE	db	0

; menu w/h value
MENUWH	db	0,0

; menu x/y value
MENUXY	db	0,0

; delay ms
delayms	db	50,100
; ---------------BUFFER SPACE------------------

STRBUF	ds	STDINSZ+2
ARGS	ds	32
OLDSP	ds	2
	ds	128
STKTOP
HEAPSTRT
