;nanobeep2
;tiny ZX Spectrum beeper engine
;by utz 08'2017 * www.irrlichtproject.de

	IFDEF	SPECTRUM

;******************************************************************
; Ant's notes:
; DDS / Time Division Multiplexing / XOR mixing 
; 2 channels, 16 bit accumulators + noise
;
; This is designed to be as small as possible.
; It was originally targetted at a 3.5 MHz ZX Spectrum.
;
; the inner loop is NNNN T (see timings below)
; so sample rate = 3,500,000 / NNNN = MMMM Hz 
;
; with 16 bit counters counting up:
; freq_value = 
; 
;******************************************************************
	org #8000

borderMasking equ 0
fullKeyboardCheck equ 0
useDrum equ 1
loopToStart equ 1
usePatternSpeed equ 0
pwmSweep equ 1
usePrescaling equ 1
include "equates.h"	
	
;new tiny engine: 64-99 bytes
;fullKeyboardCheck +1 bytes
;borderMasking = +4/+6 bytes
;useDrum = +11 bytes
;loopToStart = +0
;variable pattern speed = +4
;pwmSweep +2
;usePrescaling +11 (down = #f, up = #7)


init
	di
	
	ld d,0
	ld c,d
	exx
	push hl
	ld (_oldSP),sp
IF fullKeyboardCheck = 0
	ld d,0
ENDIF
_initSeq
	ld bc,musicData

;*******************************************************************************	
_readSeq
	ld a,(bc)
	ld l,a
	inc bc
	ld a,(bc)
	or a
IF loopToStart = 0
	jr z,_exit
ELSE
	jr z,_initSeq
ENDIF
	inc bc
	ld h,a
	ld sp,hl

;*******************************************************************************
IF usePatternSpeed = 1
	pop af
	ld (_ptnSpeed),a
ENDIF
IF usePrescaling = 1
	pop hl
	ld a,h
	ld (_prescale1),a
	ld a,l
	ld (_prescale2),a
ENDIF
_readPtn
	in a,(#fe)
IF fullKeyboardCheck = 1
	cpl
	and #1f
	ld d,a
	jr z,_cont	
ELSE
	rra
	jr c,_cont
ENDIF
_exit	
_oldSP equ $+1
	ld sp,0
	pop hl
	exx
	ei
	ret

IF useDrum = 1
_drum
	ld h,l
	dec sp
_drumlp
	ld a,(hl)
IF borderMasking = 1
	and #10
ENDIF
	out (#fe),a
	dec l
	jr nz,_drumlp
ENDIF
_cont	
	pop hl
	ld a,l
	inc l
	jr z,_readSeq
IF useDrum = 1
	inc l
	jr z,_drum
ENDIF

	ld e,h
	exx
	ld e,a

IF usePatternSpeed = 1
_ptnSpeed equ $+1
	ld b,0
ELSE
	ld b,speed
ENDIF
;*******************************************************************************	
_soundloop
	
	ld a,h			;4	;load ch1 osc state
IF pwmSweep = 1
	add a,b
	and h
ENDIF
IF usePrescaling = 1
_prescale1
	nop
ENDIF
IF borderMasking = 1
	and #10
ENDIF
	out (#fe),a		;11
	exx			;4
	add hl,de		;11	;update ch2 osc
	ld a,h			;4
IF usePrescaling = 1
_prescale2
	nop
ENDIF
	exx			;4
	dec bc			;6
IF borderMasking = 1
	and #10
ENDIF
	add hl,de		;11	;update ch1 osc (moved here for better volume balance)
	
	out (#fe),a		;11
	ld a,b			;4
	or c			;4
	jr nz,_soundloop	;12
				;86	
	exx
	jr _readPtn

;*******************************************************************************
musicData
	include "music.asm"








	ELSE

;******************************************************************
; Ant's notes:
; DDS / Time Division Multiplexing / XOR mixing 
; 2 channels, 16 bit accumulators + noise
;
; This is designed to be as small as possible.
; Now targetting a * MHz MicroBeast.
;
; Other changes:
;
; 1) different output port for beeper
; 2) different bit (bit 3) in port for beeper - this will affect pitch
;    - bit 4 completed a whole cycle every 32 increments of H
;    - bit 3 completes a whole cycle every 16 increments of H
;    => everything plays one octave higher. we'll have to compensate in note defs
;
; can generate new equates with:
;   python3 note_table_gen.py --clock 8000000 --bit 3 --t-loop 116 --prescale 1 --format equ
;
; the inner loop is 116 T (see timings below)
; so sample rate = 8, 000,000 / 116 = 68, 965 Hz 
;
; with 16 bit counters counting up:
; note_feq = (E * f_cpu) / (116 * 2^(bit + 9))  // bit = 3 for the Beast
; 
;******************************************************************
KB_PORT		EQU	0x00	; 0x0n, A[15:8] = 0xfe, 0xfd, 0xfb, 0xf7
AUDIO_PORT	EQU	0x24	; 16c550 MCR 
AUDIO_BIT	EQU	0x08	; bit 3

		ORG	0x0100
		OUTPUT	"nbeep2.com"

borderMasking	EQU	1	; MUST have this for MicroBeast
fullKeyboardCheck EQU	0
useDrum		EQU	1
loopToStart	EQU	1
usePatternSpeed	EQU	0
pwmSweep	EQU	1
usePrescaling	EQU	1
	INCLUDE		"equates_microbeast.h"

;new tiny engine: 64-99 bytes
;fullKeyboardCheck +1 bytes
;borderMasking = +4/+6 bytes
;useDrum = +11 bytes
;loopToStart = +0
;variable pattern speed = +4
;pwmSweep +2
;usePrescaling +11 (down = #f, up = #7)


init				; register bank A active (HL, BC, DE)
		DI

		LD	D, 0	; D_a  = 0
		LD	C, D	; C_a = 0 
		EXX		; register bank B active (HL, BC, DE)
		PUSH	HL      ; save HL_b?
		LD	(_oldSP), SP ; then save SP
	IF		fullKeyboardCheck	= 0
		LD	D, 0    ; because a fill kb check leaves D_b = 0
	ENDIF
_initSeq
		LD	BC, musicData	; BC_b -> pattern list

;*******************************************************************************	
_readSeq
		LD	A, (BC)
		LD	L, A            ; Lb = pattern low byte
		INC	BC
		LD	A, (BC)         ; A = pattern high byte
		OR	A		; high byte is zero? end of pat list
	IF		loopToStart	= 0
		JR	Z, _exit
	ELSE
		JR	Z, _initSeq
	ENDIF
		INC	BC
		LD	H, A		; H_b = pattern high byte
		LD	SP, HL          ; SP -> pattern data

;*******************************************************************************
	IF		usePatternSpeed	= 1
		POP	AF		; read 2 bytes from pattern
		LD	(_ptnSpeed), A  ; high byte -> speed
	ENDIF
	IF		usePrescaling	= 1
		; prescaling values (one per channel) are:
		; 0xf (scale down), 0x0 (nowt), 0x7 (scale up)
		; these are opcodes (rrca, nop, rlca) that are
		; stored in preScale1 and preScale2 and executed in
		; tone loop.
		POP	HL 		; read 2 bytes from pattern
		LD	A, H            ; 
		LD	(_prescale1), A ; high byte -> prescale1
		LD	A, L		;
		LD	(_prescale2), A	; low byte -> prescale2
	ENDIF
_readPtn
		; A could be 0x0f, 0x00, 0x07 (valid prescale2 values)
		; this means that A[15:8] for the IN is also 0x0f, 0x00, or 0x07 
		; so we're scanning 4 rows, 8 rows, or 7 rows ???
		; Actually that's only true for the first check per pattern,
		; on subsequent iterations we arrive at _readPtn from the
		; sound loop so A=0 (from LD A,B: OR C testing zero).
		IN	A, KB_PORT
	IF		fullKeyboardCheck	= 1
		CPL			; invert, so 1 bit -> pressed
		AND	0x1F            ; mask to 5 cols
		LD	D, A		; anything pressed?
		JR	Z, _cont        ; no; also note D_b <= 0
	ELSE
		RRA                     ; check for any col0 in all enabled rows
		JR	C, _cont	; nope
	ENDIF
_exit
_oldSP		EQU	$+1		; nice
		LD	SP, 0		; restore SP
		POP	HL		; restore HL
		EXX			; register bank A active (HL, BC, DE)
		EI			; interrupts back on
		RET			; out we pop

	IF		useDrum	= 1
_drum
		LD	H, L            ; L was 0x0 so now H is 0x0 also
		DEC	SP		; back the SP up one byte (i.e. just
					; after the drum byte that caused us
					; to be here)
_drumlp
		LD	A, (hl)		; get some ROM
	IF		borderMasking	= 1
		AND	AUDIO_BIT
	ENDIF
		OUT	AUDIO_PORT, A
		DEC	L		; punt out 256 bytes of ROM noise
		JR	NZ, _drumlp
		; fall thru to re-reading pattern bytes
	ENDIF


		; resume here if no key pressed, or just done drums
_cont
		POP	HL		; read next 2 bytes from pattern
		LD	A, L 		; was the first byte 0xff?
		INC	L 		; i.e. end of pattern?
		JR	Z, _readSeq     ; yes, on to next pattern
	IF		useDrum	= 1
		INC	L               ; was that first byte 0xfe?
		JR	Z, _drum 	; yes, do drums
	ENDIF

		LD	E, H		; E_b <- H_b <- ch2 byte
		EXX                     ; register bank A active
		LD	E, A            ; E_a <- A <- ch1 byte (not 0xff, 0xfe)

		; so it looks like reg bank A => channel 1
		;              and reg bank B => channel 2
		; in each bank:
		;    D = 0
		;    E = note          DE is value added every tick
		;    HL = phase acc    H is used to drive speaker bit
		;    
		; in Bank A:
		;    BC = main counter
		;    
		; in Bank B:
		;    BC = pattern sequence pointer

		; note that a rest works because E=0 means DE=0 which
		; means that the phase accumulator never advances, so the
		; output freezes and there is no toggling.


	IF		usePatternSpeed	= 1
_ptnSpeed	EQU	$+1		; per-pattern speed stored here
		LD	B, 0 		; at top of readSeq, B_a = spd
					; C always 0
	ELSE
		LD	B, speed        ; this is defined globally in music.asm, B_a = spd
					; C always 0
	ENDIF
;*******************************************************************************	
_soundloop
						; bank A is active
		LD	A, H			;4	; A <- H_a (ch1 phase acc high byte)
	IF		pwmSweep	= 1
		; as B_a counts down from speed to 0 the ADD shifts the duty
		; cycle threshold each iteration, producing a timbral sweep
		; over the duration of the note.
		ADD	A, B			;4	; A += B_a (loop counter)
		AND	H			;4	; A &= H_a (ch1 phase acc)
	ENDIF
	IF		usePrescaling	= 1
_prescale1
		NOP 				;4	; rlca/rrca/nop, all 4T
	ENDIF
	IF		borderMasking	= 1
		AND	AUDIO_BIT		;7
	ENDIF
		OUT	AUDIO_PORT, A		;11	; output ch1
		EXX				;4	; bank B active
		ADD	HL, DE			;11	; update ch2 accumulator
		LD	A, H			;4	; A <- H_b (ch2 phase acc high byte)
	IF		usePrescaling	= 1
_prescale2
		NOP				;4	; rlca/rrca/nop, all 4T
	ENDIF
		EXX				;4	; bank A active
		DEC	BC			;6	; decrement loop counter
	IF		borderMasking	= 1
		AND	AUDIO_BIT		;7
	ENDIF
		ADD	HL, DE			;11	; update ch1 accumulator

		OUT	AUDIO_PORT, A		;11	; output ch2
		LD	A, B			;4	; test loop counter
		OR	C			;4	; BC_a == 0?
		JR	NZ, _soundloop		;12/7	; 12T taken, 7T not taken
					; loop total: 116T
					; (base=86, +8 pwmSweep, +8 prescaling, +14 borderMasking)
		EXX				;4	; bank B active
		JR	_readPtn		;12

;*******************************************************************************
musicData
		INCLUDE	"music.asm"
	ENDIF