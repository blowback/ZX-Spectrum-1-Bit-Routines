;AntEater - ZX Spectrum beeper engine
;by utz 08'2014
	IFDEF	SPECTRUM 
		org #8000
		
init
		di
		ld hl,musicdata
		ld (OrderPntr),hl
		call readOrder
		jr z,init
		xor a
		out (#fe),a
		ld hl,#2758			;restore alternative HL to default value
		exx
		ei
		ret

;**************************************************************************************************		
readOrder
		ld hl,(OrderPntr)		;get order pointer
		ld e,(hl)			;read pnt pointer
		inc hl
		ld d,(hl)
		inc hl
		ld (OrderPntr),hl
		ld a,d				;if pattern pointer = #0000, end of song reached
		or e
		ret z
		ld (PtnPntr),de

;**************************************************************************************************		
readPtn
		in a,(#fe)
		cpl
		and #1f
		ret nz
		
		ld a,#10
		ld (switch1),a
		ld (switch2),a
		
		ld hl,(PtnPntr)
		ld a,(hl)			;check for pattern end		
		cp #ff
		jr z,readOrder

		ld a,(hl)
		and %11111100			;mask lowest 2 bits
		ld b,a				;speed
		ld c,b
		
		ld a,(hl)
		and %00000011
		or a				;if !=0, we have drum
		call nz,drums
		

		
drdata		
		inc hl
		xor a
		ld d,(hl)			;counter ch2
		ld e,d
		push hl
		ld h,#10			;output mask ch2
		or d
		jr nz,rdskip1		
		ld h,a				;mute if note byte = 0
rdskip1
		ld l,h				;swap mask
		exx
		pop hl
		inc hl
		ld b,(hl)			;counter A
		or b
		jr nz,rdskip2
		ld (switch1),a
		ld (switch2),a
rdskip2
		ld c,b				;backup counter A/B
		ld d,b				;counter B
		inc hl
		ld (PtnPntr),hl
		ld hl,#1000			;output mask ch1
		exx

;**************************************************************************************************		
play
		ld a,h			;4	;load output mask ch2
		
		exx			;4
		dec b			;4	;dec counter A
		out (#fe),a		;11	;output ch2
		jr nz,wait1		;12/7
		ld a,h			;4	;flip output mask and restore counter
switch1 equ $+1					;mute switch
		xor #10			;7
		ld h,a			;4
		ld b,c			;4
skip1
		dec d			;4	;dec counter B
		ld a,l			;4	;load output mask ch1
		jr nz,wait2		;12/7
		ld d,c			;4	;restore counter
switch2 equ $+1					;mute switch
		xor #10			;7	;swap output mask
		ld l,a			;4
		
		rra			;4	;increment counter to create pwm effect if output mask = #10
		rra			;4
		rra			;4
		rra			;4
		add a,d			;4
		ld d,a			;4
		
skip2
		ld a,l			;4
		and h			;4	;combine output masks
		out (#fe),a		;11	;output ch1
		
		exx			;4
		dec d			;4	;decrement counter ch1
		jp nz,wait3		;10
		ld d,e			;4	;restore counter
		ld a,h			;4	;swap output mask
		xor l			;4
		ld h,a			;4
		
skip3		
		dec bc			;6	;decrement speed counter
		ld a,b			;4
		or c			;4
		nop			;4	;take care of IO contention
		jp nz,play		;10
					;184
		jr readPtn

;**************************************************************************************************

wait1
		nop			;4
		jp skip1		;10

wait2
		sla (hl)		;15
		sla (hl)		;15
		nop			;4
		jr skip2		;12
					;46
		
		;ld (hl),b		;7	;why on earth I can't read the keyboard here
		;in a,(#fe)		;11	;is a mystery to me.
		;cpl			;4
		;and #1f		;7
		;ret nz			;11/5
		;jr skip2		;12
					

wait3
		nop			;4
		jr skip3		;12

;**************************************************************************************************
drums
		push hl

		dec a
		ld hl,switch2
		ld d,#fd
		jr z,drum2
		dec a
		ld d,#bf
		ld hl,drdata+7
		jr z,drumloop3
		
drum1
		ld hl,drdata
		
		ld a,c			;timing correction
		sub #c2
		ld c,a
		jr nc,tskip1
		dec b
tskip1
		push bc
		ld b,12
drum1a
		ld a,#10
		out (#fe),a
		ld a,(hl)
drumloop1
		dec a
		jr nz,drumloop1
		out (#fe),a
		ld a,(hl)
drumloop2
		dec a
		jr nz,drumloop2	
		inc hl
		djnz drum1a
		jr drumret

drum2
		dec b			;timing correction
		ld a,#d9
		ld (switch3),a		;modify end marker value
drumloop3
		ld a,c			;timing correction
		sub d
		jr nc,tskip2
		dec b
tskip2
		push bc
drumloop30
		ld a,#10
		out (#fe),a
switch3 equ $+1
		ld a,6
		ld b,(hl)
		xor b
		jr z,drumret
dl3a
		push hl
		pop hl
		djnz dl3a
		xor a
		out (#fe),a
		ld b,(hl)
dl3b
		push hl
		pop hl
		djnz dl3b
		inc hl
		jr drumloop30
		ld a,6
		ld (switch3),a

drumret
		pop bc
		
		pop hl
		ret
		
;**************************************************************************************************
OrderPntr
		dw 0
		
PtnPntr
		dw 0

musicdata
		include "music.asm"
	ELSE






;******************************************************************
; Ant's notes:
;  
; 1 square wave channel (#1), 1 PWM channel (#2), 3 drums
; 
; channel 1 is the square wave with:
; 	D,E = counter
; 	H, L = masks
;
; channel 2 is the PWM channel with:
;	B = phase counter A
;       D = phase counter B
;       H = counter A mask
;       L = counter B mask
;       output is L AND H (i.e. on when both masks are high)
;
; normally A and B are in phase, but the "PWM" code below adds 1 to
; counter B's reload every time B overflows and L flips to 0x10.
; Thus counter B gradually drifts out of phase with counter A.
;
; Usable range B1-C7 with detuning in upper octaves. Supports some FX:
; (song speed Fxx (1..31), manual detune E5x).

; The three drums are: Snare (1), Hihat (2), Kick (3), or None (0)
; Pattern speeds are 04...fc (must be /4).

; Now targetting an 8 MHz MicroBeast (with sjasmplus).
;
; Other changes:
;
; 1) different output port for beeper
; 2) different bit (bit 3) in port for beeper - added an RRCA to deal with it
; this will affect drum pitch (2.3* higher) - should be ok
; 3) added delay in skip3 to compensate for 8 Mhz vs old 3.5 MHz.
;   this delays an extra 246T taking it from ~200T to ~446T, keeping 56us
; per cycle, more or less.
; 4) remove the IO contention NOP: not needed on microbeast
; 5) fixed the drum bug in the original (moved the restore into drumret)
;
;******************************************************************
KB_PORT		EQU	0x00	; 0x0n, A[15:8] = 0xfe, 0xfd, 0xfb, 0xf7
AUDIO_PORT	EQU	0x24	; 16c550 MCR 
AUDIO_BIT	EQU	0x08	; bit 3
		ORG	0x0100
		OUTPUT	"anteater.com"
init
		DI
		LD	HL, musicdata
		LD	(OrderPntr), HL
		CALL	readOrder
		JR	Z, init
		XOR	A
		OUT	AUDIO_PORT, A
		LD	HL, 0x2758			;restore alternative HL to default value
		EXX
		EI
		RET

;**************************************************************************************************		
readOrder
		LD	HL, (OrderPntr)		;get order pointer
		LD	E, (hl)			;read ptn pointer LO
		INC	HL
		LD	D, (hl)			; read ptn pointer HI
		INC	HL
		LD	(OrderPntr), HL		; save order pointer
		LD	A, D			;if pattern pointer = #0000, end of song reached
		OR	E
		RET	Z
		LD	(PtnPntr), DE	 	; save DE in PtrPntr

;**************************************************************************************************		
readPtn
		IN	A, (KB_PORT)		; read the whole kb port
		CPL				; flip bits, 1 = a key pressed
		AND	0x1F			; mask to 5 keys in column
		RET	NZ			; a key was pressed

		LD	A, 0x10			; 0x10 = spectrum EAR bit
		LD	(switch1), A 		; set ch2 mute switch (counter A mask) to unmuted
		LD	(switch2), A		; set ch2 mute switch (counter B mask) to unmuted

		LD	HL, (PtnPntr)		; get byte of pattern
		LD	A, (hl)			; check for pattern end		
		CP	0xFF
		JR	Z, readOrder		; ptn finished; next in sequence

		LD	A, (hl) 		; redundant (A still has (HL) from above)
		AND	%11111100		; mask OUT lowest 2 bits
		LD	B, A			; speed -> B
		LD	C, B			; speed -> C

		LD	A, (hl)			; reload first ptn byte
		AND	%00000011		; mask OUT upper 6 bits
		OR	A			; if !=0, we have drum
		CALL	NZ, drums



drdata		; because drum routines use this code as data!
		INC	HL			; point to ch1 (square wave) note byte
		XOR	A			; A = 0
		LD	D, (hl)			; ch1 counter -> D
		LD	E, D			; ch1 counter reload -> E
		PUSH	HL			; stack HL (so we can retrieve
						; it after EXX)
		LD	H, 0x10			; ch1 output mask: H = EAR bit
		OR	D			; is ch1 counter == 0?
		JR	NZ, rdskip1		; no
		LD	H, A			; yes: mute ch1: H = 0
rdskip1
		LD	L, H			; ch1 flip mask (XOR target for toggling H)
; bank A
		EXX				; switch reg banks
; bank B
		POP	HL			; retrieve ptn pointer
		INC	HL			; point to ch2 (PWM) note byte
		LD	B, (hl)			; ch2 counter A -> B
		OR	B			; both ch1 AND ch2 counters == 0?
		JR	NZ, rdskip2		; no, at least one channel active
		LD	(switch1), A		; mute ch2 counter A mask flip
		LD	(switch2), A		; mute ch2 counter B mask flip
rdskip2
		LD	C, B			; ch2 counter reload -> C
		LD	D, B			; ch2 counter B -> D
		INC	HL			; update pattern pointer
		LD	(PtnPntr), HL		; and store it
		LD	HL, 0x1000		; ch2 output masks: H = EAR bit, L = 0
; bank B (ch2 regs)
		EXX				; switch back to bank A
; bank A (ch1 regs)

;**************************************************************************************************		
play
		LD	A, H			;4	; load ch1 output mask from bank A's H

; bank A (ch1 regs)
		EXX				;4	; switch to bank B
; bank B (ch2 regs)                                     ; but A still holds CH1 value
		DEC	B			;4	; dec ch2 counter A
		RRCA				;4	; shift bit 4 -> bit 3 for AUDIO_BIT
		OUT	AUDIO_PORT, A		;11	; output ch1 (square wave)
		JR	NZ, wait1		;12/7
		LD	A, H			;4	; ch2 counter A wrapped: flip mask H
switch1		EQU	$+1				; ch2 mute switch (counter A)
		XOR	0x10			;7	; flip bit 4 (or no-op if muted)
		LD	H, A			;4
		LD	B, C			;4	; reload ch2 counter A
skip1
		DEC	D			;4	; dec ch2 counter B
		LD	A, L			;4	; load ch2 mask L
		JR	NZ, wait2		;12/7
		LD	D, C			;4	; reload ch2 counter B
switch2		EQU	$+1				; ch2 mute switch (counter B)
		XOR	0x10			;7	; flip bit 4 (or no-op if muted)
		LD	L, A			;4

		RRA				;4	; PWM: if mask L is 0x10, RRA x4 gives 0x01
		RRA				;4	;   adding 1 to counter B shifts its phase
		RRA				;4	;   relative to counter A, creating a pulse
		RRA				;4	;   width that changes over time
		ADD	A, D			;4	; D += 0 or 1 (phase offset)
		LD	D, A			;4

skip2
		LD	A, L			;4	; ch2 mask L
		AND	H			;4	; AND with ch2 mask H (both must be high)
		RRCA				;4	; shift bit 4 -> bit 3 for AUDIO_BIT
		OUT	AUDIO_PORT, A		;11	; output ch2 (PWM)

; bank B (ch2 regs)
		EXX				;4	; switch back to bank A
; bank A (ch1 regs)
		DEC	D			;4	; dec ch1 counter
		JP	NZ, wait3		;10
		LD	D, E			;4	; reload ch1 counter
		LD	A, H			;4	; flip ch1 output mask
		XOR	L			;4	; toggle via L (XOR 0x10, or 0 if muted)
		LD	H, A			;4

skip3
		LD	A, 15			;7	; 8 MHz timing compensation
.dly		DEC	A			;4	; delay loop: 16*15 + 2 = 242T
		JR	NZ, .dly		;12/7
		NOP				;4	; +4 = 246T total padding
		DEC	BC			;6	; decrement speed counter
		LD	A, B			;4
		OR	C			;4
		JP	NZ, play		;10
		JR	readPtn

;**************************************************************************************************

wait1						; ch2 counter A didn't wrap: 12+4+10 = 26T
		NOP				;4	; (matches wrap path: 7+4+7+4+4 = 26T)
		JP	skip1			;10

wait2						; ch2 counter B didn't wrap: 12+15+15+4+12 = 58T
		SLA	(hl)			;15	; burn 15T (compact 2-byte encoding)
		SLA	(hl)			;15	; (corrupts byte at HL=0x1000, harmless if ROM)
		NOP				;4
		JR	skip2			;12

		;ld (hl),b			;7	; why on earth I can't read the keyboard here
		;in a,(#fe)			;11	; is a mystery to me.
		;cpl				;4
		;and #1f			;7
		;ret nz				;11/5
		;jr skip2			;12


wait3						; ch1 counter didn't wrap: 10+4+12 = 26T
		NOP				;4	; (matches wrap path: 10+4+4+4+4 = 26T)
		JR	skip3			;12

;**************************************************************************************************
drums
		PUSH	HL			; save pattern pointer

		DEC	A			; drum type was 1, 2, or 3
		LD	HL, switch2		; data pointer for type 1 (snare)
		LD	D, 0xFD			; timing correction constant for type 1
		JR	Z, drum2		; type 1 -> snare
		DEC	A
		LD	D, 0xBF			; timing correction constant for type 2
		LD	HL, drdata + 7		; data pointer for type 2 (hihat)
		JR	Z, drumloop3		; type 2 -> hihat

drum1						; type 3 -> kick drum
		LD	HL, drdata		; use code bytes at drdata as pitch table!
						; (opcodes 0x23, 0xAF, 0x56... = varying delays)
		LD	A, C			; timing correction: subtract drum duration
		SUB	0xC2			; from speed counter BC
		LD	C, A
		JR	NC, tskip1
		DEC	B
tskip1
		PUSH	BC			; save speed counter
		LD	B, 12			; 12 pulses of descending pitch
drum1a
		LD	A, AUDIO_BIT		; speaker ON
		OUT	AUDIO_PORT, A
		LD	A, (hl)			; load delay from code-as-data table
drumloop1
		DEC	A			; busy-wait for ON half-cycle
		JR	NZ, drumloop1
		OUT	AUDIO_PORT, A		; speaker OFF (A=0)
		LD	A, (hl)			; reload same delay
drumloop2
		DEC	A			; busy-wait for OFF half-cycle
		JR	NZ, drumloop2
		INC	HL			; next table entry (next opcode byte)
		DJNZ	drum1a			; repeat 12 times
		JR	drumret

drum2						; snare (type 1) entry point
		DEC	B			; timing correction
		LD	A, 0xD9			; set end-marker to 0xD9
		LD	(switch3), A		; (self-modifying: changes LD A,n immediate)
drumloop3					; hihat (type 2) also enters here
		LD	A, C			; timing correction: subtract drum duration
		SUB	D			; D = 0xFD (snare) or 0xBF (hihat)
		JR	NC, tskip2
		DEC	B
tskip2
		PUSH	BC			; save speed counter
drumloop30
		LD	A, AUDIO_BIT		; speaker ON
		OUT	AUDIO_PORT, A
switch3		EQU	$+1			; self-modifying: end-marker value
		LD	A, 6			; load end-marker (6 default, 0xD9 for snare)
		LD	B, (hl)			; load delay from table
		XOR	B			; does delay byte match end-marker?
		JR	Z, drumret		; yes -> drum finished
dl3a
		PUSH	HL			; \  waste 21T per iteration
		POP	HL			; /  (compact cycle-burning trick)
		DJNZ	dl3a			; busy-wait ON half-cycle (B iterations)
		XOR	A
		OUT	AUDIO_PORT, A		; speaker OFF
		LD	B, (hl)			; reload same delay
dl3b
		PUSH	HL			; \  waste 21T per iteration
		POP	HL			; /
		DJNZ	dl3b			; busy-wait OFF half-cycle
		INC	HL			; next table entry
		JR	drumloop30		; next pulse

drumret
		LD	A, 6			; restore switch3 to default
		LD	(switch3), A		; (drum2/snare sets it to 0xD9)
		POP	BC			; restore speed counter

		POP	HL			; restore pattern pointer
		RET

;**************************************************************************************************
OrderPntr
		DW	0

PtnPntr
		DW	0

musicdata
		INCLUDE	"music.asm"
	ENDIF