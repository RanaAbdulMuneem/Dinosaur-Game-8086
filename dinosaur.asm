;19L-1046 RANA ABDUL MUNEEM
;19L-2320 AARIZ ARQAM
;default scene -> row 3 to row 19 inclusive (scene -> main area of animation)
;Ground at row 20 offset 3200
;default position for dino -> row 17, 18 ,19

[org 0x0100]
jmp start
dino1: db '   []='
dino2: db '__/-/-'
dino3: db '  L L '

dinoPos:	dw 0x0901;		position of dino (mean position: row17 col01)
riseFlag:	db 0;			1 if dino is rising
fallFlag:	db 1;			1 if dino is falling

cactus:	db '{}'

score:	dw 0
		db 'score:'

tickCount: 	dw 0;			stores time elapsed (55ms interval)
endFlag: 	db 0;			0 if game is active
startFlag:	db 0;			0 if on start screen
oldKeyboard:dd 0;
oldTimer: 	dd 0;

rngTick:	dw 0;			tick counter for rng
nextCactus:	dw 5;			ticks until next cactus appears

startGame:	db 'PRESS SPACE TO START'
gameOver:	db 'GAME OVER'

;SCREEN PRINTING FUNCTIONS
clrscreen:;					clears the entire screen
	push ax
	push cx
	push es
	push di
	mov cx, 2000;			for 2000 characters
	mov ax, 0xb800
	mov es, ax;				point es to video memory
	mov ax, 0x0720;			white space
	xor di, di;				start at 0th offset
	rep stosw;				clear offset, move to next offset
	pop di
	pop es
	pop cx
	pop ax
	ret
	
clrString:;					function to clear a string of characters
	push bp;				takes as parameters:
	mov bp, sp;				1)position to print
	push ax;				2)length of string to clear
	push bx
	push cx
	push di
	push es
	
	mov ax, 0xb800
	mov es, ax
	
	mov bx, [bp+6];			get position (row in bh, column in bl)
	mov ax, 80
	mul bh;					multiply row number with 80
	xor bh, bh
	add ax, bx;				add col number to get offset
	shl ax, 1;				get byte offset
	mov di, ax
	
	mov cx, [bp+4];			get string lenght in cx
	mov ax, 0x0720
	rep stosw
	
	pop es
	pop di
	pop cx
	pop bx
	pop ax
	pop bp

	ret 4

clrDino:;					clears the screen that is occupied by dino
	push ax
	push cx
	push es
	push di
	
	mov ax, [dinoPos];		position of dino
	
	push ax
	push 6
	call clrString
	
	inc ah
	push ax
	push 6
	call clrString
	
	inc ah
	push ax
	push 6
	call clrString
	
	
	pop di
	pop es
	pop cx
	pop ax
	ret

printString:;				function to print a string
	push bp;				takes parameters:
	mov bp, sp;				1)offset of string
	push ax;				2)length of string
	push bx;				3)position to print
	push cx;				4)attribute for printing
	push dx
	push es
	push di
	
	mov ah, 0x13;			service 13 - print string
	mov al, 0;				sub service 01 - update cursor
	mov bx, [bp+4];			get attribute
	mov dx, [bp+6];			get position
	mov cx, [bp+8];			get length of string
	push cs
	pop es
	mov bp, [bp+10];		string address
	int 0x10;				BIOS video service
	
	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	
	ret 8
	
printNumber:;				function to print decimal number
	push bp;				takes parameters:
	mov bp, sp;				1)number to print
	push ax;				2)position to print
	push bx;				3)attribute for printing
	push cx
	push dx
	push di
	push es
	
	mov ax, 0xb800
	mov es, ax;				point es to video memory
	
	mov bx, [bp+6];			get position (row in bh, column in bl)
	mov ax, 80
	mul bh;					multiply row number with 80
	xor bh, bh
	add ax, bx;				add col number to get offset
	shl ax, 1;				get byte offset
	mov di, ax
	
	mov cx, [bp+4];			get attribute
	mov ch, cl
	
	xor cl, cl
	xor dx, dx
	mov ax, [bp+8];			get number
	mov bx, 10;				divisor
	cmp ax, 0;				if number is 0
	jne divisionLoop
		mov ah, ch
		mov al, '0'
		push ax;			push ascii of zero on stack
		inc cl
		jmp printNumberLoop
	divisionLoop:
		div bx;				divide by 10, get remainder in dx
		add dl, '0';		convert to ascii
		mov dh, ch;			attribute
		push dx;			push digit onto stack
		xor dx, dx;			clear remainder
		inc cl;				number of digits pushed
		cmp ax, 0
		jne divisionLoop
	printNumberLoop:
		pop ax;				get digit from stack
		stosw;				print to display
		dec cl
		jnz printNumberLoop
		
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 6

printDino:;					function to print dino at position [dinoPos]
	push bp;				takes parameters:
	mov bp, sp;				1)attribute for printing
	push ax
	push bx
	push cx
	push si
	push di
	push es
	push ds
	
	push cs
	pop ds
	
	mov ax, [dinoPos];		get dino position
	push dino1;				offset of string
	push 6;					length of string
	push ax;				postion of string
	push word [bp+4];		attribute
	call printString;		print 1st part of dino
	
	inc ah;					move down one row
	push dino2
	push 6
	push ax
	push word [bp+4]
	call printString;		print 2nd part of dino
	
	mov ax, 0xb800
	mov es, ax
	mov bx, [dinoPos]
	add bh, 2;				position of 3rd part of dino
	
	mov ax, 80
	mul bh
	xor bh, bh
	add ax, bx
	shl ax, 1
	mov di, ax;				get byte offset of 3rd part of dino
	
	;while printing last row of dino, check to see if printing destination
	;is not previously occupied
	mov cx, 6
	mov ax, [bp+4];			attribute
	mov ah, al
	mov bx, dino3
	printPart3:
		cmp byte [bx], ' '
		je safeLanding
		cmp word [es:di], 0x0720;		if space is empty
		je safeLanding;					dino can land safely
			mov byte [cs:endFlag], 1;	otherwise gameover
		safeLanding:
		mov al, [bx]
		stosw
		inc bx
		loop printPart3;				repeat for all char in dino3
		
	pop ds
	pop es
	pop di
	pop si
	pop cx
	pop bx
	pop ax
	pop bp
	ret 2
	
printGround:;				function for printing groun
	push ax
	push cx
	push di
	push es
	mov ax, 0xb800
	mov es, ax;				point es to video memory
	mov di, 3200;			print ground at 20th row
	mov cx, 20;				for entire row
	mov ah, 0x07;			ascii for -
	printGroundLoop:;		print pattern --== for entire row
		mov al, '-'
		stosw;				
		stosw
		mov al, '='
		stosw
		stosw
		loop printGroundLoop
	pop es
	pop di
	pop cx
	pop ax
	ret

printScore:;				function to print score. Takes parameters:
	push bp;				1)position to print
	mov bp, sp;				2)attribute for printing
	push ax
	
	mov ax, score
	add ax, 2
	push ax;				offset of 'score:' string
	push 6;					length of 'score:'
	push word [bp+6];		position to print
	push word [bp+4]
	call printString;		print 'score:'
	
	mov ax, [bp+6]
	add al, 7;				mov 7 columns ahead
	
	push word [score];		value of score
	push ax;				position to print
	push word [bp+4];		attribute
	call printNumber;   	print score
	
	pop ax
	pop bp
	ret 4
	
printCactus:;				function to print cactus
	push bp;				prints cactus from given row, down till row 20
	mov bp, sp;				takes parameters:
	push ax;				1)position to print
	push bx
	push cx
	push dx
	push di
	push es
	
	mov ax, 0xb800
	mov es, ax;				point es to video memory
	
	mov ax, [bp+4];			get position
	
	printCactusLoop:
		cmp ah, 20;			compare with ground row
		jge endPrintCactus;	if equal or below ground row, dont print cactus
		push cactus;		offset of cactus string
		push 2;				length of cactus string
		push ax;			position to print
		push 0x0007
		call printString;	print cactus
		
		inc ah;				move down one row
		jmp printCactusLoop
		
	endPrintCactus:
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret 2

;GAME MECHANIC FUNCTIONS
jump:;						function to move dino up and down
	checkRiseFlag:;			if rise flag is set
		cmp byte [cs:riseFlag], 1
		jne checkFallFlag
			call rise
	checkFallFlag:;			if fall flag is set
		cmp byte [cs:fallFlag], 1
		jne skipJump
			call fall
	skipJump:;				if neither flag is set
	ret
	
rise:;						function to move dino up until a max height
	push ax
	mov ax, [cs:dinoPos];				get dino position
	sub ah, 1;							move up one row
	cmp ah, 4;							compare with max row no
	jg endRiseSBR;						if still on a lower row, end SBR
		mov byte [cs:riseFlag], 0;		clear riseFlag
		mov byte [cs:fallFlag], 1;		set fallFlag
	endRiseSBR:
	mov [cs:dinoPos], ax;	update dino position
	pop ax
	ret
fall:;						function to move dino down until min height 
	push ax
	mov ax, [cs:dinoPos];				get dino position
	add ah, 1;							move down one row
	cmp ah, 17;							compare with min row no
	jl endFallSBR;						if still on a higher row, end SBR
		mov byte [cs:fallFlag], 0;		clear fallFlag
	endFallSBR:
	mov [cs:dinoPos], ax
	pop ax
	ret
	
shiftGround:;				function to shift ground row left by 1
	push ax
	push cx
	push si
	push di
	push es
	push ds
	
	mov ax, 0xb800
	mov es, ax;				point es to video memory
	mov ds, ax
	
	mov di, 3200;			point di to row 20 col 0
	mov si, 3202;			point si to row 20 col 1
	
	push word [es:di];		save overwritten word
	
	mov cx, 79;				for 79 remaining rows
	rep movsw;				shift columns left
	
	pop word [es:di];		wraparound overwritten word
	
	pop ds
	pop es
	pop di
	pop si
	pop cx
	pop ax
	ret

shiftScene:;				function to shift active part of screen left
	push bp;				active part of screen = row 3 to row 19
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push es
	push ds
	
	mov ax, 0x0300;			start at row 19
	shiftSceneLoop:
		push ax;			push row number
		call shiftSceneRow;	shift row left
		inc ah;				move to next row
		
		cmp ah, 20;			for all active rows
		jne shiftSceneLoop
	
	endShiftScene:
	pop ds
	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	pop bp
	ret

shiftSceneRow:;				function to shift row of screen left by 1
	push bp;				takes parameter:
	mov bp, sp;				1)row number
	push ax
	push bx
	push si
	push di
	push es
	push ds
	
	mov ax, 0xb800
	mov es, ax;				point es to video memory
	mov ds, ax;				point ds to video memory
	mov bx, [bp+4];			get row number
	mov ax, 160
	mul bh;					get byte offset of row
	
	mov di, ax;				point di to 0th column of row
	add ax, 2
	mov si, ax;				point di to 1st column of row
	
	;check column for cactus
	increaseScore:;						check to see if a cactus has passed
		cmp word [es:di], 0x077D;		check for '{'
		jne skipIncreaseScore
			inc word [cs:score];		increase the score
	skipIncreaseScore:
	mov word [es:di], 0x0720;			clear first column
	
	mov cx, 79;							for 79 remaining columns
	shiftSceneRowLoop:
		lodsw;							get character
		shiftCMP1:	cmp al, '{';		if its cactus {
					je checkAndShift;	check if shifting to empty space
		shiftCMP2:	cmp al, '}';		if its cactus }
					je shiftLeft;		shift to left
					
				add di, 2
				jmp endShiftCMP
				
		checkAndShift:;					check for collision
			cmp word [es:di], 0x0720;	if shifting to empty space
			je shiftLeft;				continue with shifting
				mov byte [cs:endFlag], 1;	if shifting to non empty space, set endFlag
				
		shiftLeft:
			stosw;						place character to the left
			mov word [es:di], 0x0720;	replace original character with empty space
		
		endShiftCMP:
		loop shiftSceneRowLoop
	
	endShiftSceneRow:
	
	pop ds
	pop es
	pop di
	pop si
	pop bx
	pop ax
	pop bp

	ret 2
	
rng:;						function for random number generation
	push bp;				takes parameter:
	mov bp, sp;				1)range. Example 0x640A generates from 10 to 100
	push ax
	push bx
	push dx
	
	xor ax, ax;				clear ax
	xor dx, dx;				clear dx
	mov bx, [bp+4];			get range of rng in bx; bh upper bound, bl lower bound
	mov al, bh
	sub al, bl
	inc ax;					get range of values
	mov bx, ax
	mov ax, [cs:rngTick]; 	get time
	div bx;					get random remainder in dx
	
	mov bx, [bp+4]
	xor bh, bh;				get start of range
	add dx, bx;				add to remainder
	
	mov [bp+6], dx;			place random number in return space
	
	pop dx
	pop bx
	pop ax
	pop bp
	ret 2

setRNG:;					function to initialize rngTick
	push ax;				for random numbers across multiple games
	push bx
	push cx
	push dx
	
	xor ax, ax
	int 0x1A;				get system time since midnight in cx:dx
	
	mov [rngTick], dx;		initialize rngTick with random value
	
	mov ax, dx
	xor dx, dx
	mov bx, 9
	div bx
	add [nextCactus], dx
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret

diag:
	push word [cs:tickCount]
	push 0x0200
	push 0x0007
	call printNumber
	push word [cs:rngTick]
	push 0x0207
	push 0x0002
	call printNumber
	push word [cs:nextCactus]
	push 0x020E
	push 0x0004
	call printNumber
	ret

;INTERRUPT FUNCTIONS
keyboard:;					ISR for keyboard
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push sp
	push bp
	push ds
	push es
	
	in al, 0x60;						read key
	
	keys0:	cmp al, 1;					if escape key
			jne keys1
				inc byte [endFlag];		set endFlag
				jmp endKeyboard
	keys1:	cmp al, 57;					if space key
			jne endKeyboard
				cmp byte [startFlag], 0;if on start screen
				jne processJump
					mov byte [startFlag], 1
				processJump:
				cmp byte [fallFlag], 1;	if already falling, dont jump
				je endKeyboard
					mov byte [riseFlag], 1; set riseFlag
				jmp endKeyboard
	endKeyboard:
	
	mov al, 0x20;			end of interrupt
	out 0x20, al
	
	pop es
	pop ds
	pop bp
	pop sp
	pop di
	pop si
	pop dx
	pop cx
	pop dx
	pop ax
	iret
	
timer:;						ISR for timer
	push ax
	push bx
	push cx
	push dx
	push si
	push di
	push sp
	push bp
	push ds
	push es
	
	push cs
	pop ds
	
	inc word [cs:tickCount];increment tickCount
	inc word [cs:rngTick],;	increment rngTick
	
			
	mov ax, [cs:tickCount];	get tickCount
	cmp ax, [nextCactus];	check to see if time to print new cactus
	jne skipNewCactus
	newCactus:;				print a new cactus
			;generate random number for height of cactus
			sub sp, 2
			push 0x0802;	random height 2-8
			call rng
			pop dx
			
			mov ax, 0x144E;	move to last column
			sub ah, dl;		getting starting coords to print cactus
			
			push word ax;	random row col 78
			call printCactus;	print cactus
			
			;generate random time interval till next cactus
			sub sp, 2
			push 0x3E19;	range 25-50
			call rng
			pop ax
			
			mov [cs:nextCactus], ax;	set tick count for next cactus
			mov word [cs:tickCount], 0;	reset tickCount
	skipNewCactus:
	
	;call diag
	call clrDino;			clear previous frame of dino
	call jump;				complete jump actions
	
	push 0x0007
	call printDino;			print dino on screen
	
	call shiftGround;		shift ground left
	call shiftScene;		shift active part of screen left
	
	push 0x023C;			position to print
	push 0x0007;			attribute for printing
	call printScore;		print score in top right
	
	mov al, 0x20;		
	out 0x20, al
	
	
	pop es
	pop ds
	pop bp
	pop sp
	pop di
	pop si
	pop dx
	pop cx
	pop dx
	pop ax
	iret
	
hookKeyboard:
	push ax
	push es
	
	xor ax, ax
	mov es, ax
	
	;hook keyboard (INT 9)
	;save old ISR
	mov ax, [es:9*4]
	mov [oldKeyboard], ax
	mov ax, [es:9*4+2]
	mov [oldKeyboard+2], ax
	;hook new ISR
	cli
	mov word [es:9*4], keyboard
	mov [es:9*4+2], cs
	sti
	
	pop es
	pop ax
	ret
hookTimer:
	push ax
	push es
	
	xor ax, ax
	mov es, ax
	
	;hook timer (INT 9)
	;save old ISR
	mov ax, [es:8*4]
	mov [oldTimer], ax
	mov ax, [es:8*4+2]
	mov [oldTimer+2], ax
	;hook new ISR
	cli
	mov word [es:8*4], timer
	mov [es:8*4+2], cs
	sti
	
	pop es
	pop ax
	ret	
	
unhookInterrupts:;			function for unhooking interrupts
	push ax
	push es
	xor ax, ax
	mov es, ax
	
	;unhook keyboard
	cli
	mov ax, [oldKeyboard]
	mov [es:9*4], ax
	mov ax, [oldKeyboard+2]
	mov [es:9*4+2], ax
	sti
	;unhook timer
	cli
	mov ax, [oldTimer]
	mov [es:8*4], ax
	mov ax, [oldTimer+2]
	mov [es:8*4+2], ax
	sti
	
	pop es
	pop ax
	ret

start:
	call setRNG;			initialize random values
	call hookKeyboard
	call clrscreen;			clear the screen
	
	push 0x0007;			standard attribute
	call printDino;			print dino
	
	call printGround;		print ground row (row 20)
	
	push 0x023C;			position to print
	push 0x0082;			standard attribute
	call printScore;		print score
	
	push startGame;			offset of start message
	push 20;				length of string
	push 0x0B1C;			position to print
	push 0x0087;			attribute
	call printString;		print start message
	
	startScreen:
		cmp byte [startFlag], 0
		je startScreen
	
	push 0x0B1C;			clear the start message
	push 20
	call clrString
	
	call hookTimer
	
	mainEventLoop:;			repeat until game over
	
		cmp byte [endFlag], 0
		je mainEventLoop
	
	;GAME OVER
	call clrDino;			clear dino
	push 0x0084;			blinking red attribute
	call printDino;			print dino
	
	push 0x023C;			clear score from top right
	push 10
	call clrString
	
	push 0x0C23;			position of middle of screen
	push 0x0082;			blinking green attribute
	call printScore;		print score
	
	push gameOver;			offset for 'GAME OVER' string
	push 9;					length of string
	push 0x0B23;			position of middle of screen (above score)
	push 0x0007;			standard attribute
	call printString;		print game over string
		
		
	call unhookInterrupts;	unhook keyboard and timer
	
mov ax, 0x4c00;				terminate program
int 0x21