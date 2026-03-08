;ntropic
;beeper routine by utz 01'14, revised 08'14 (irrlichtproject.de)
;bugfixes suggested by kphair
;2ch tone, 1ch noise, click drum
;uses ROM data in range #0000-~#3800
;this code is public domain
	IFDEF	SPECTRUM 
	org 32768

begin	di
	;push ix
	push iy
	ld c,0			;initialize speed counter
	ld (oldSP),sp
	ld sp,intStack

reset	ld hl,ptab		;setup pattern sequence table pointer
	
lpt	ld e,(hl)		;read pattern pointer
	inc hl
	ld d,(hl)
	ld a,e
	or d
	jr z,reset		;if d=0, loop to start
	;jr z,exit		;or exit
	inc hl
	push hl			;preserve pattern pointer
	ex de,hl		;put data pointer in hl

	call main
	
	pop hl
	jr z,lpt		;if no key has been pressed, read next pattern
	
exit	ld hl,#2758		;restore hl' for return to BASIC
	exx
	db #31			;ld sp,nn
oldSP
	dw 0
	pop iy
	;pop ix
	ei
	ret

;****************************************************************************************
main	push hl			;preserve data pointer
	ld ix,skip1
	
	
rdata	ld iyh,#10		;output switch mask
	
	pop hl			;restore data pointer
	
	ld a,(hl)		;read drum byte
	inc a			;and exit if it was #ff
	ret z
	
	ld a,(hl)		;read speed
	and %11111110
	ld b,a

	ld a,(hl)
	rra
	call c,drum
	
	inc hl
	xor a
	
	in a,(#fe)		;read keyboard
	cpl
	and #1f
	ret nz
	
	ld a,(hl)		;read counter ch1
	
	or a			;mute switch ch1
	jr nz,rsk1
	ld iyh,a
	
rsk1	ld d,a
	ld e,a
	
	inc hl
		
	push hl			;read counter ch2
	exx
	pop hl
	ld b,#10
	ld a,(hl)
	
	or a			;mute switch ch2
	jr nz,rsk2
	ld b,a
	
rsk2	ld d,a
	ld e,d
	ld hl,skip2
	exx
	
	inc hl
	ld a,(hl)		;read noise length val
	inc hl
	push hl			;preserve data pointer
	ld h,a			;setup ROM pointer for noise, length to h	
	xor a			;mask for ch1
	ld l,a			;and part 2 of ROM pointer setup
	ex af,af'
	xor a			
	push af			;mask for ch2

;****************************************************************************************
sndlp	ex af,af'	;4
	out (#fe),a	;11
	dec d		;4	;decrement counter ch1
	jp nz,wait1	;10	;if counter=0
	
m1 equ $+1
	xor iyh		;8	;flip output mask and reset counter
	ld d,e		;4
skip1	

	ex af,af'	;4
	exx		;4
	pop af		;10	;load output mask ch2
				;44t output for ch1
	
	
	out (#fe),a	;11
	dec d		;4	;decrement counter ch2
	jp nz,wait2	;10	;if counter=0
	
m2 equ $+1
	xor b		;4	;flip output mask and reset counter
	ld d,e		;4
skip2	
	push af		;11	;preserve output mask ch2
	exx		;4
	
	
noise	ld a,(hl)	;7	;read byte from ROM
				;43t output for ch2
	and #10		;7	;waste some time
	
	out (#fe),a	;11	;output whatever
	bit 7,h		;8	;check if ROM pointer has rolled over to #ffxx
	jp nz,wait3	;10
	
	dec hl		;6	;decrement ROM pointer
	nop		;4	;waste some time
	
dtim
	dec bc		;6	;decrement timer
	ld a,b		;4
	or c		;4
	jp nz,sndlp	;10	;repeat sound loop until bc=0
			;184
	
	pop af			;clean stack
	jr rdata		;read next note

;****************************************************************************************
wait1	nop		;4
	jp (ix)		;8

wait2	nop		;4
	jp (hl)		;4
	
wait3	jp dtim		;10

	
drum	push hl			;preserve data pointer
	push bc			;preserve timer
	ld hl,#3000		;setup ROM pointer - change val for different drum sounds
	ld de,#0809		;loopldiloop
	ld b,72
	
dlp3	ld a,(hl)		;read byte from ROM
	out (#fe),a		;output whatever

	dec hl			;decrement ROM pointer #2b/#23 (inc hl)
	;inc hl			;use this instead for quieter click drum
	dec bc			;decrement timer

dlp4	dec d
	jr nz,dlp4
	
	ld d,e
	inc e
	djnz dlp3
	
	pop bc			;restore timer
	pop hl
	dec b			;adjust timing
	ret

;****************************************************************************************
;internal stack

	ds 10			;5 stack locations
intStack

;****************************************************************************************	
;music data

include "music.asm"

	ELSE










	
;******************************************************************
; Ant's notes:
;  
; 2 square wave channels, 1 noise channel (ROM data)
; 
; Music data format is 4 bytes (speed/drum, ch1 pitch, ch2 pitch, noise)
; byte 0: bits 7-1 = speed (loaded into B as high byte of BC duration counter)
;         bit 0 = drum trigger (1 -> play drum before this note)
; byte 1: ch1 pitch counter, lower value = higher pitch, 0 = mute
; byte 2: ch2 pitch counter, as above
; byte 3: noise ROM HI byte. change character of noise
; - 0xFF = end of pattern marker

; Now targetting an 8 MHz MicroBeast (with sjasmplus).
;
; Other changes:
;
; 1) different output port for beeper
; 2) different bit (bit 3) in port for beeper - change masks from 0x10 to AUDIO_BIT
; 3) added delay loop at dtim to compensate for 8 MHz vs 3.5 MHz
;    original: 184T / 3.5 MHz = 52.57 us per iteration
;    target: 52.57 us * 8 MHz = 420.57T per iteration
;    delay loop adds 242T -> 426T total -> 53.25 us (1.3% sharp, close enough)
; 
; Drums aren't compensated, so they'll be pitched up 2.3x, oh well.
;
;******************************************************************
KB_PORT		EQU	0x00	; 0x0n, A[15:8] = 0xfe, 0xfd, 0xfb, 0xf7
AUDIO_PORT	EQU	0x24	; 16c550 MCR 
AUDIO_BIT	EQU	0x08	; bit 3
		ORG	0x0100
		OUTPUT	"ntropic.com"

begin		DI
	;push ix
		PUSH	IY
		LD	C, 0			; initialize speed counter LO
		LD	(oldSP), SP
		LD	SP, intStack		; internal stack

reset		LD	HL, ptab		; point HL to start of pattern table

lpt		LD	E, (hl)			; read pattern pointer
		INC	HL			; into DE
		LD	D, (hl)
		LD	A, E
		OR	D			; test if ptr is 0
		JR	Z, reset		; if so, loop back to start
	;jr z,exit		;or exit
		INC	HL
		PUSH	HL			; preserve pattern pointer
		EX	DE, HL			; put data pointer in hl

		CALL	main			; play pattern. Z = no key, NZ = key

		POP	HL			; restore pattern table position
		JR	Z, lpt			; if no key has been pressed, read next pattern

exit		LD	HL, 0x2758		; restore hl' for return to Sinclair BASIC
		EXX
		DB	0x31			;ld sp,nn
oldSP
		DW	0
		POP	IY
	;pop ix
		EI
		RET

;****************************************************************************************
main		PUSH	HL			; preserve data pointer
		LD	IX, skip1		; IX -> skip1. Used by the wait1 routine.
						; JP (IX) jumps here when ch1's counter hsa
						; NOT reached 0, acting as cycle-counted
						; NOP path.


rdata		LD	IYH, AUDIO_BIT		; output switch mask

		POP	HL			; restore data pointer

		LD	A, (hl)			; read first byte of note data
		INC	A			; and exit if it was #ff
		RET	Z

		LD	A, (hl)			; re-read byte 0
		AND	%11111110		; bits 7:1 -> note speed/duration
		LD	B, A			; B = speed value (high byte of duration counter)

		LD	A, (hl)			; re-read byte 0
		RRA				; shift bit 0 into C
		CALL	C, drum			; if bit 0 was set, play a click drum

		INC	HL			; advance to byte 1
		XOR	A			; A = 0

		IN	A, KB_PORT		; read keyboard
		CPL				; invert (keys are active low)
		AND	0x1F			; mask to 5 key columns
		RET	NZ			; ret with NZ if any key pressed

		LD	A, (hl)			; A = pitch counter for channel 1

		OR	A			; if 0, channel 1 is muted
		JR	NZ, rsk1
		LD	IYH, A			; set ch1 mask to 0 (no speaker toggling)

rsk1		LD	D, A			; D = current counter for ch1
		LD	E, A			; E = reload value for ch1

		INC	HL			; advance to byte 2

		PUSH	HL			; save patter pointer
		EXX 				; switch register bank
		POP	HL                  	; HL' now -> byte 2
		LD	B, AUDIO_BIT		; B' = speaker toggle mask for ch2
		LD	A, (hl)			; A = pitch counter for ch2

		OR	A			; mute switch ch2 if pitch=0
		JR	NZ, rsk2
		LD	B, A			; set ch2 toggle mask to 0

rsk2		LD	D, A			; D' = current counter for ch2
		LD	E, D                    ; E' = reload value for ch2
		LD	HL, skip2               ; HL -> skip2. Used by wait2.
						; JP (HL) jumps here when ch2 counter has
						; NOT reach 0 etc etc
		EXX				; switch register bank

		INC	HL			; advance to byte 3
		LD	A, (hl)			; read noise ROM pointer HI byte
		INC	HL
		PUSH	HL			; preserve data pointer
		LD	H, A			; H = HI byte of ROM ptr for noise
		XOR	A			; A=0, initial output mask for ch1 (silent)
		LD	L, A			; L=0, LO byte of ROM ptr for noise
		EX	AF, AF'			; stash ch1 output mask in AF'
		XOR	A			; A=0
		PUSH	AF			; push ch2 output mask (0) onto stacj
						; sound loop uses push/pop to save/restore
						; ch2's mask since we're out of registers

;****************************************************************************************
sndlp		EX	AF, AF'		; 4	; swap in ch1's output mask
		OUT	AUDIO_PORT, A	; 11
		DEC	D		; 4	; decrement ch1 pitch counter
		JP	NZ, wait1	; 10	; if NZ jump to wait1, which wastes the
						; same number of cycles as the ff reload code
		; ch1 counter reached ZERO
m1		EQU	$+1
		XOR	IYH		; 8	; XOR output mask with AUDIO_BIT or 0 if muted
		LD	D, E		; 4	; reload counter from E
skip1

		EX	AF, AF'		; 4	; stash ch1 mask back, switch to main AF
		EXX			; 4	; change register bank
		POP	AF		; 10	; pop ch2 output mask from the stack
					; 44T output for ch1


		OUT	AUDIO_PORT, A	; 11	; output ch2 state to speaker
		DEC	D		; 4	; decrement ch2 pitch counter
		JP	NZ, wait2	; 10	; if NZ jump t wait2 (same timing balancing trick)

		; ch2 counter reached ZERO
m2		EQU	$+1
		XOR	B		; 4	; toggle ch2's output mask with B' (AUDIO_BIT or 0)
		LD	D, E		; 4	; reload counter from E'
skip2
		PUSH	AF		; 11	; preserve output mask ch2
		EXX			; 4     ; switch register bank


noise		LD	A, (hl)		; 7	; read byte from ROM
					; 43T output for ch2
					;
		AND	AUDIO_BIT	; 7	; isolate audio bit

		OUT	AUDIO_PORT, A	; 11	; output noise
		BIT	7, H		; 8	; check if H has rolled over past 0x7f (into the 
						; 0x80-0xff range which is RAM on the Spectrum)
		JP	NZ, wait3	; 10	; if so, skip the decrement (stops noise)

		DEC	HL		; 6	; decrement ROM pointer (walk backwards thru ROM)
		NOP			; 4	; waste some time

dtim
		LD	A, 15		; 7	; 8 MHz timing compensation
.dly		DEC	A		; 4	; delay loop: 7 + 14*16 + 11 = 242T
		JR	NZ, .dly	; 12/7

		DEC	BC		; 6	; decrement master duration counter
		LD	A, B		; 4
		OR	C		; 4	; check if BC is 0
		JP	NZ, sndlp	; 10	; if not, do another iteration
					; 426T (184 + 242)

		POP	AF		; clean ch2 mask from stack
		JR	rdata		; read next note

;****************************************************************************************
wait1		NOP			; 4     ; matches xor iyh: ld d, e
		JP	(ix)		; 8	; jump to skip1 (NB 8T not 4T, coz I* prefix)

wait2		NOP			; 4	; matches xor b: ld d, e
		JP	(hl)		; 4	; jump to skip2 

wait3		JP	dtim		; 10	; skip the dec hl + nop (10T) matching the 
						; 10T of this jump itself


drum		PUSH	HL		; preserve data pointer
		PUSH	BC		; preserve duration timer
		LD	HL, 0x3000	; setup ROM pointer - change val for different drum sounds
		LD	DE, 0x0809	; D=8 (inner loop counter), E=9 (reload + increment base)
		LD	B, 72		; outer loop: 72 iterations

dlp3		LD	A, (hl)		; read byte from ROM
		OUT	AUDIO_PORT, A	; output to speaker

		DEC	HL		; decrement ROM pointer - walk backwards thru ROM
		;inc hl			; use this instead for quieter click drum
		DEC	BC		; decrement master timer, so drum time counts against
					; note duration, keeping rhythm tight

dlp4		DEC	D		; inner delay loop, creates a falling pitch effect
		JR	NZ, dlp4	; because E (and thus D's reload) increases each iteration

		LD	D, E		; reload inner counter from E
		INC	E		; E increases each time -> longer delay -> pitch drop
		DJNZ	dlp3		; repeat outer loop

		POP	BC		; restore duration timer
		POP	HL		; restore data pointer
		DEC	B		; adjust timing to compensate for time spent in drum routine
		RET

;****************************************************************************************
;internal stack

		DS	10			;5 stack locations
intStack

;****************************************************************************************	
;music data

		INCLUDE	"music.asm"
	ENDIF
end
	