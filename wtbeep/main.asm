	IFDEF 	SPECTRUM
; wtbeep 0.3
; experimental beeper engine for ZX Spectrum
; by utz 11'2016 * www.irrlichtproject.de
; bugfixes by Shiru 01'2018
; updated 03'2022 - sound improvements, +2A/+3 compatibility, unbalanced channel volumes


	include "equates.h"

	org #8000

	di
	exx
	ld b,0			;timer lo
	push hl			;preserve HL' for return to BASIC
	ld (oldSP),sp
	ld hl,musicData
	ld (seqpntr),hl
	ld ix,0
	ld iy,0

;*******************************************************************************
rdseq
seqpntr equ $+1
	ld sp,0
	xor a
	pop de			;pattern pointer to DE
	or d
	ld (seqpntr),sp
	jr nz,rdptn0

	ld sp,mLoop		;get loop point		;comment out to disable looping
	jr rdseq+3					;comment out to disable looping

;*******************************************************************************
exit
oldSP equ $+1
	ld sp,0
	pop hl
	exx
	ei
	ret

;*******************************************************************************
rdptn0
	ld (ptnpntr),de

readPtn
	in a,(#fe)		;read kbd
	cpl
	and #1f
	jr nz,exit


ptnpntr equ $+1
	ld sp,0

	pop af			;timer + ctrl
	jr z,rdseq

	ld c,a			;timer (# ticks)

	jr c,_noUpd1

	ex af,af'

	ld h,HIGH(mixAlgo)
	pop de
	ld a,d

	and #f8
	ld l,a

	ld a,(hl)
	ld (algo1),a
	inc l
	ld a,(hl)
	ld (algo1+1),a
	inc l
	ld a,(hl)
	ld (algo1+2),a
	inc l
	ld a,(hl)
	ld (algo1+3),a
	inc l
	ld a,(hl)
	ld (algo1+4),a

	ld hl,0

	ld a,d
	and #7
	ld d,a

	ex af,af'

_noUpd1
	jp pe,_noUpd2

	exx
	ex af,af'

	ld h,HIGH(mixAlgo)
	pop bc
	ld a,b

	and #f8
	ld l,a

	ld a,(hl)
	ld (algo2),a
	inc l
	ld a,(hl)
	ld (algo2+1),a
	inc l
	ld a,(hl)
	ld (algo2+2),a
	inc l
	ld a,(hl)
	ld (algo2+3),a
	inc l
	ld a,(hl)
	ld (algo2+4),a

	ld hl,0

	ld a,b
	and #7
	ld b,a

	ex af,af'
	exx

_noUpd2
	jp m,_noUpd3

	exx

	pop de
	ld a,d
	ex af,af'
	ld a,d
	and #7
	ld d,a
	ld (fdiv3),de

	ex af,af'
	and #f8
	ld e,a
	ld d,HIGH(mixAlgo)

	ld a,(de)
	ld (algo3),a
	inc e
	ld a,(de)
	ld (algo3+1),a
	inc e
	ld a,(de)
	ld (algo3+2),a
	inc e
	ld a,(de)
	ld (algo3+3),a
	inc e
	ld a,(de)
	ld (algo3+4),a

	ld de,0
	exx

_noUpd3
	pop af
	jp po,_noSweepReset

	ld iy,0					;reset sweep registers
	ld ixh,0
_noSweepReset
	jr c,drum1
	jr z,drum2
	dec sp
drumRet

	ld (ptnpntr),sp

fdiv3 equ $+1
	ld sp,0

        ld a,c
        ld c,#10
playNote0
        ex af,af'
        xor a
;*******************************************************************************
playNote
	add hl,de               ;11
	out (#fe),a             ;11___72??

	ld a,h                  ; 4

algo1
	ds 5                    ;20

        and c                   ; 4
        ret c                   ; 5
        nop                     ; 4
	out (#fe),a             ;11___48

	exx                     ; 4

	add hl,bc               ;11
	ld a,h                  ; 4

algo2
	ds 5                    ;20

        and #10                 ; 7

	ex de,hl                ; 4

	add hl,sp               ;11

	out (#fe),a             ;11___72

	ld a,h                  ; 4

algo3
	ds 5                    ;20

	ex de,hl                ; 4
        exx                     ; 4

        and c                   ; 4

        dec b                   ; 4
        jp nz,playNote          ;10
			        ;192

	inc iyl				;update sweep counters
	ld a,iyl
	rrca
	rrca
	ld iyh,a
	rrca
	ld ixh,a

	ex af,af'
        dec a
	jp nz,playNote0

	jp readPtn

;*******************************************************************************
drum2						;noise
	ld (hlRest),hl
	ld (bcRest),bc

	ld b,a
	ex af,af'

	ld a,b
	ld hl,1					;#1 (snare) <- 1011 -> #1237 (hat)
	rrca
	jr c,setVol
	ld hl,#1237

setVol
	and #7f
	ld (dvol),a

	ld bc,#a803				;length
sloop
	add hl,hl		;11
	sbc a,a			;4
	xor l			;4
	ld l,a			;4

dvol equ $+1
	cp #80			;7		;volume
	sbc a,a			;4

	;; or #7			;7		;border
        and #f8
	out (#fe),a		;11
	djnz sloop		;13/8

	dec c			;4
	jr nz,sloop		;12

	jr drumEnd

drum1						;kick
	ld (deRest),de
	ld (bcRest),bc
	ld (hlRest),hl

	ld d,a					;A = start_pitch<<1
	ld e,0					;B = 0
	ld h,e
	ld l,e

	ex af,af'

	srl d					;set start pitch
	rl e

	ld c,#3					;length

xlllp
	add hl,de
	jr c,_noUpd
	ld a,e
_slideSpeed equ $+1
	sub #10					;speed
	ld e,a
	sbc a,a
	add a,d
	ld d,a
_noUpd
	ld a,h
	;; or #7					;border
        and #f8
	out (#fe),a
	djnz xlllp
	dec c
	jr nz,xlllp

						;45680 (/192 = 237)
deRest equ $+1
	ld de,0


drumEnd
hlRest equ $+1
	ld hl,0
bcRest equ $+1
	ld bc,0

	ld b,18					;adjust timer
	jp drumRet

;*******************************************************************************
IF (LOW($))!=0
	org 256*(1+(HIGH($)))
ENDIF

mixAlgo

	ds 8			;00	50% square

	daa			;02	32% square
	and h
	ds 6

	rlca			;01	25% square
	and h
	ds 6

	daa			;03	19% square
	cpl
	and h
	ds 5

	inc a			;04	12.5% square
	inc a
	xor h
	rrca
	ds 4

	inc a			;05	6.25% square
	xor h
	rrca
	ds 5

	add a,iyl		;06	duty sweep (fast) (cpl, dec a is not needed, but makes for a nicer attack env)
	cpl
	dec a
	or h
	ds 3

	add a,iyh		;07	duty sweep (slow)
	cpl
	dec a
	or h
	ds 3

	add a,ixh		;08	duty sweep (very slow, start lo)
	cpl
	dec a
	and h
	ds 3

	add a,ixh		;09	duty sweep (very slow, start hi)
	and h
	ds 5


	add a,iyh		;0a	duty sweep (slow) + oct
	rlca
	xor h
	ds 4

	add a,iyh		;0b	duty sweep (slow) - oct
	rrca
	xor h
	ds 4

	add a,iyl		;0c	duty sweep (fast) - oct
	rrca
	xor h
	ds 4

	daa			;0d	vowel 1
	rlca
	cpl
	xor h
	ds 4

	daa			;0e	vowel 2
	rlca
	rlca
	cpl
	xor h
	ds 3

	daa			;0f	vowel 3
	cpl
	xor h
	ds 5

	rrca			;10	vowel 4
	rrca
	sbc a,a
	and h
	rlca
	ds 3

	rlca			;11	vowel 5
	rlca
	xor h
	rlca
	ds 4

	rrca			;12	vowel 6
	sbc a,a
	and h
	rlca
	ds 4

	cpl			;13	rasp 1
	daa
	sbc a,a
	rlca
	and h
	ds 3

	rlca			;14	rasp 2
	rlca
	sbc a,a
	and h
	ds 4

	daa			;15	phat rasp
	rrca
	rrca
	cpl
	or h
	ds 3

	daa			;16	phat 2
	rrca
	rrca
	cpl
	and h
	ds 3

	daa			;17	phat 3
	rlca
	rlca
	cpl
	and h
	ds 3

	daa			;18	phat 4
	rlca
	cpl
	and h
	ds 4

	daa			;19	phat 5
	rrca
	rrca
	cpl
	xor h
	ds 3

	cpl			;1a	phat 6
	daa
	sbc a,a
	rlca
	xor h
	ds 3

	rlca			;1b	phat 7
	rlca
	sbc a,a
	and h
	rlca
	ds 3

	rlc h			;1c	noise 1
	and h
	ds 5

	rlc h			;1e	noise 2
	sbc a,a
	or h
	ds 4

	rlc h			;1d	noise 3
	ds 6

	rlc h			;1f	noise 4
	or h
	xor l
	ds 5

;*******************************************************************************
musicData
	include "music.asm"








	ELSE

;
;******************************************************************
; Ant's notes:
;
; wtbeep is a 3-channel 1-bit beeper engine
;  -  pin-pulse interleaving
;  - 32 different timbres without branching in inner loop thanks to
;    per-channel 5-byte self-modifying slot (algo1/algo2/algo3) patched
;    at runtime with a waveform shaping algo from the mixAlgo LUT.
;  - 2 different click drums
;  - unbalanced channels (3 is quieter)
;  - 1tracker support!
;
; REGISTER ALLOCATION (during playNote inner loop):
;   Main set:
;     HL  = channel 1 phase accumulator
;     DE  = channel 1 frequency divider (added to HL each sample)
;     B   = tick counter (low byte, counts samples per tick)
;     C   = 0x10 (internal audio bitmask - RRCA shifts to AUDIO_BIT before OUT)
;   Alt set (EXX):
;     HL  = channel 2 phase accumulator
;     BC  = channel 2 frequency divider
;     DE  = channel 3 phase accumulator (swapped via EX DE,HL)
;     SP  = channel 3 frequency divider (ADD HL,SP for ch3)
;   AF'  = tempo counter (number of ticks per row)
;   IX   = sweep counter (very slow) - ixh used in algo
;   IY   = sweep counter - iyl (fast), iyh (slow) used in algos
;
; PORTING NOTES (ZX Spectrum 3.5MHz -> MicroBeast 8MHz):
; - move to KB_PORT and AUDIO_PORT
; - RRCA before each out to bring bit 4 -> bit 3
; - change drum masks from AND 0xf8 to AND 0x10; RRCA
; - melody timing pad: inner loop 190T -> 449T (DS NOPs)
;               distributed for even PPI spacing
; - drum timing pad: noise drum 65T -> 149T (2o NOPs)
;                    kick drum non-slide 134T, slide 184 T

KB_PORT		EQU	0x00	; 0x0n, A[15:8] = 0xfe, 0xfd, 0xfb, 0xf7
AUDIO_PORT	EQU	0x24	; 16c550 MCR
AUDIO_BIT	EQU	0x08	; bit 3



		INCLUDE	"equates.h"

		ORG	0x0100
		OUTPUT	"wtbeep.com"

; INITIALIZATION
		DI			; disable interrupts (timing-critical code)
		EXX			; switch to alt registers
		LD	B, 0		; B' will become the tick counter (lo byte = 0)
		PUSH	HL		; preserve HL' so we can return to BASIC later
		LD	(oldSP), SP	; save SP for exit
		LD	HL, musicData	; point to start of sequence
		LD	(seqpntr), HL	; store as current sequence pointer
		LD	IX, 0		; clear sweep counter (very slow)
		LD	IY, 0		; clear sweep counters (fast + slow)

; READ SEQUENCE - fetch next pattern pointer from the sequence list
; SP is (ab)used as a fast data pointer; POP reads 2 bytes at once.
rdseq
seqpntr		EQU	$+1		; self-modifying: operand patched in place
		LD	SP, 0		; SP = current sequence read position
		XOR	A		; A = 0 (used to test if pattern pointer is 0)
		POP	DE		; DE = next pattern pointer (read 2 bytes)
		OR	D		; test if high byte is 0 (D=0 means end of seq)
		LD	(seqpntr), SP	; save updated sequence position
		JR	NZ, rdptn0	; if pointer != 0, go read the pattern

	; End of sequence reached - loop back
		LD	SP, mLoop	; reset sequence pointer to loop point
		JR	rdseq + 3	; re-read (skip the LD SP instruction)
					; comment out these 2 lines to disable looping

; EXIT - restore state and return to BASIC
exit
oldSP		EQU	$+1		; self-modifying: patched with saved SP
		LD	SP, 0		; restore original stack pointer
		POP	HL		; restore HL' (was pushed during init)
		EXX			; switch back to main register set
		EI			; re-enable interrupts
		RET			; return to BASIC

; READ PATTERN - process rows of note/drum data from the current pattern
rdptn0
		LD	(ptnpntr), DE	; store pattern pointer

readPtn
		IN	A, (KB_PORT)	; read keyboard port
		CPL			; invert (keys active-low)
		AND	0x1F		; mask key bits (bottom 5 bits)
		JR	NZ, exit	; if any key pressed, exit


ptnpntr		EQU	$+1		; self-modifying: current pattern read position
		LD	SP, 0		; SP = pattern data pointer

	; --- WORD 0: Tempo + control flags ---
	; POP AF loads: A = high byte (tempo), F = low byte (flags)
	; Flag bits map to Z80 flag register positions:
	;   bit 0 (C flag)  = skip channel 1 update
	;   bit 2 (PV flag) = skip channel 2 update
	;   bit 6 (Z flag)  = end of pattern marker
	;   bit 7 (S flag)  = skip channel 3 update

		POP	AF		; A = tempo (ticks per row), F = control flags
		JR	Z, rdseq	; Z set (bit 6) = end of pattern, go read next

		LD	C, A		; C = tempo counter (# of ticks for this row)

	; --- WORD 1: Channel 1 frequency + waveform (if bit 0 clear) ---

		JR	C, _noUpd1	; C set (bit 0) = skip ch1 update

		EX	AF, AF'		; save flags to AF'

	; Decode waveform + frequency from 16-bit word:
	;   bits 15-11 (top 5 bits of D) = waveform index (x8 byte offset)
	;   bits 10-0  (low 3 bits of D + all of E) = frequency divider

		LD	H, HIGH(mixAlgo)	; H = high byte of mixAlgo table address
		POP	DE		; DE = waveform|frequency word for ch1
		LD	A, D		; A = high byte

		AND	0xF8		; isolate top 5 bits = waveform table offset
		LD	L, A		; HL now points to waveform entry in mixAlgo

	; Copy 5 bytes of waveform code into the algo1 slot (self-modifying)
		LD	A, (hl)
		LD	(algo1), A
		INC	L
		LD	A, (hl)
		LD	(algo1 + 1), A
		INC	L
		LD	A, (hl)
		LD	(algo1 + 2), A
		INC	L
		LD	A, (hl)
		LD	(algo1 + 3), A
		INC	L
		LD	A, (hl)
		LD	(algo1 + 4), A

		LD	HL, 0		; reset ch1 phase accumulator

		LD	A, D		; recover high byte of freq|wave word
		AND	0x7		; keep only low 3 bits = true high byte of freq
		LD	D, A		; DE = 11-bit frequency divider for ch1

		EX	AF, AF'		; restore flags

_noUpd1
	; --- WORD 2: Channel 2 frequency + waveform (if bit 2 clear) ---

		JP	PE, _noUpd2	; PV set (bit 2) = skip ch2 update

		EXX			; switch to alt register set (ch2 regs)
		EX	AF, AF'

		LD	H, HIGH(mixAlgo)
		POP	BC		; BC' = waveform|frequency word for ch2
		LD	A, B

		AND	0xF8		; waveform table offset
		LD	L, A

	; Copy 5 bytes of waveform code into algo2 slot
		LD	A, (hl)
		LD	(algo2), A
		INC	L
		LD	A, (hl)
		LD	(algo2 + 1), A
		INC	L
		LD	A, (hl)
		LD	(algo2 + 2), A
		INC	L
		LD	A, (hl)
		LD	(algo2 + 3), A
		INC	L
		LD	A, (hl)
		LD	(algo2 + 4), A

		LD	HL, 0		; reset ch2 phase accumulator

		LD	A, B
		AND	0x7		; isolate frequency high bits
		LD	B, A		; BC' = 11-bit frequency divider for ch2

		EX	AF, AF'
		EXX			; back to main register set

_noUpd2
	; --- WORD 3: Channel 3 frequency + waveform (if bit 7 clear) ---

		JP	M, _noUpd3	; S set (bit 7) = skip ch3 update

		EXX			; switch to alt set

		POP	DE		; DE' = waveform|frequency word for ch3
		LD	A, D
		EX	AF, AF'
		LD	A, D
		AND	0x7
		LD	D, A
		LD	(fdiv3), DE	; store ch3 frequency divider (loaded into SP later)

		EX	AF, AF'
		AND	0xF8		; waveform table offset
		LD	E, A
		LD	D, HIGH(mixAlgo)

	; Copy 5 bytes of waveform code into algo3 slot
		LD	A, (de)
		LD	(algo3), A
		INC	E
		LD	A, (de)
		LD	(algo3 + 1), A
		INC	E
		LD	A, (de)
		LD	(algo3 + 2), A
		INC	E
		LD	A, (de)
		LD	(algo3 + 3), A
		INC	E
		LD	A, (de)
		LD	(algo3 + 4), A

		LD	DE, 0		; reset ch3 phase accumulator
		EXX

_noUpd3
	; --- WORD 4: Drum trigger ---
	; POP AF reads drum control byte + parameter byte.
	; If no drum, data is just db 0 (1 byte); we compensate with DEC SP.

		POP	AF		; A = drum param, F = drum flags
		JP	PO, _noSweepReset	; PV clear (bit 2 = 0) = don't reset sweep

		LD	IY, 0		; reset sweep registers (used by duty sweep waveforms)
		LD	IXH, 0
_noSweepReset
		JP	C, drum1	; C set (bit 0) = trigger kick drum
		JP	Z, drum2	; Z set (bit 6) = trigger noise/hihat drum
		DEC	SP		; no drum: only 1 byte was data (the 0),
					; POP read 2, so back up SP by 1
drumRet
	; --- Row fully parsed, now play the note ---

		LD	(ptnpntr), SP	; save pattern position for next row

fdiv3		EQU	$+1		; self-modifying: ch3 frequency divider
		LD	SP, 0		; SP = ch3 freq div (used by ADD HL,SP in loop)

		LD	A, C		; A = tempo counter (ticks remaining)
		LD	C, 0x10		; C = internal audio bitmask (bit 4)
					; (RRCA before each OUT shifts to AUDIO_BIT)

; SAMPLE GENERATION LOOP
; Each iteration produces 3 output samples (one per channel) by:
;   1. Advancing the channel's phase accumulator (ADD HL,freq)
;   2. Taking H (high byte of accumulator) as the "phase" value
;   3. Running the waveform algorithm on it (5 bytes of self-modified code)
;   4. Masking with 0x10 to extract bit 4, RRCA to shift to bit 3 (AUDIO_BIT)
;   5. OUT to AUDIO_PORT
;
; Inner loop = 440 t-states (vs 192 on Spectrum) to match sample rate
; at 8 MHz. Sections between OUTs: 144 + 148 + 148 = 440.
playNote0
		EX	AF, AF'		; save tick count in AF'
		XOR	A		; A = 0 (initial output state)

playNote
	; --- Channel 1 output ---
		ADD	HL, DE		; 11  advance ch1 phase accumulator
		RRCA			;  4  shift bit 4 -> bit 3 (AUDIO_BIT)
		OUT	(AUDIO_PORT), A	; 11  OUT1: ch3 from prev iteration (or 0 first time)

		LD	A, H		;  4  A = ch1 phase (high byte of accumulator)

algo1					;     5 bytes of self-modifying waveform code for ch1
		DS	5		; 20  (patched from mixAlgo table at row parse time)

		AND	C		;  4  mask with 0x10 to isolate audio bit
		RET	C		;  5  (C flag never set here; acts as 5-cycle NOP)
		NOP			;  4  timing padding (original)
		DS	23		; 92  timing padding (8 MHz)
		RRCA			;  4  shift bit 4 -> bit 3 (AUDIO_BIT)
		OUT	(AUDIO_PORT), A	; 11  OUT2: ch1 sample
					;----
					;144  (OUT1 -> OUT2)

	; --- Channel 2 output ---
		EXX			;  4  switch to alt registers (ch2/ch3)

		ADD	HL, BC		; 11  advance ch2 phase accumulator
		LD	A, H		;  4  A = ch2 phase

algo2					;     5 bytes of self-modifying waveform code for ch2
		DS	5		; 20

		AND	0x10		;  7  mask audio bit (immediate)

		EX	DE, HL		;  4  swap: DE'=ch2 accum, HL'=ch3 accum

	; --- Channel 3 output ---
		ADD	HL, SP		; 11  advance ch3 phase accumulator (SP = ch3 freq!)

		DS	18		; 72  timing padding (8 MHz)
		RRCA			;  4  shift bit 4 -> bit 3 (AUDIO_BIT)
		OUT	(AUDIO_PORT), A	; 11  OUT3: ch2 sample
					;----
					;148  (OUT2 -> OUT3)

		LD	A, H		;  4  A = ch3 phase

algo3					;     5 bytes of self-modifying waveform code for ch3
		DS	5		; 20

		EX	DE, HL		;  4  swap back: HL'=ch2 accum, DE'=ch3 accum
		EXX			;  4  back to main register set

		AND	C		;  4  mask ch3 output with audio bit

		DS	18		; 72  timing padding (8 MHz)
		DEC	B		;  4  decrement sample counter (B = tick length lo)
		JP	NZ, playNote	; 10  loop until tick complete
					;----
					;148  (OUT3 -> next OUT1, incl ADD+RRCA+OUT)
					;====
					;440  total per iteration (vs 192 @ 3.5 MHz)

	; --- End of tick: update sweep counters ---
	; The sweep counters provide slowly-changing values used by
	; duty-sweep waveforms to evolve the timbre over time.
	; IYL increments every tick, IYH = IYL>>2, IXH = IYL>>3.

		INC	IYL		; advance fast sweep counter
		LD	A, IYL
		RRCA
		RRCA
		LD	IYH, A		; IYH = IYL >> 2 (slow sweep)
		RRCA
		LD	IXH, A		; IXH = IYL >> 3 (very slow sweep)

		EX	AF, AF'		; retrieve tempo counter from AF'
		DEC	A		; decrement row tick count
		JP	NZ, playNote0	; if ticks remaining, play another tick

		JP	readPtn		; row complete, read next pattern row

; DRUM 2 - NOISE (hihat / snare)
; Generates noise using a linear feedback shift register (LFSR).
; A = parameter byte:
;   bit 0: drum type (0 = hihat with higher LFSR seed, 1 = snare with seed=1)
;   bits 1-7: volume threshold (higher = louder)
drum2
		LD	(hlRest), HL	; save main regs (restored after drum)
		LD	(bcRest), BC

		LD	B, A		; save param byte
		EX	AF, AF'

		LD	A, B
		LD	HL, 1		; LFSR seed for snare
		RRCA			; test bit 0 (drum type)
		JR	C, setVol	; if set, use seed=1 (snare)
		LD	HL, 0x1237	; LFSR seed for hihat (higher = more metallic)

setVol
		AND	0x7F		; isolate volume bits (7 bits)
		LD	(dvol), A	; store as comparison threshold

		LD	BC, 0xA803	; B=#a8 (168 samples), C=#03 (3 outer loops)
					; total = 168*3 = 504 samples
sloop
	; LFSR noise generation (Galois LFSR)
		ADD	HL, HL		; 11  shift LFSR left
		SBC	A, A		;  4  A = #FF if carry was set, else 0
		XOR	L		;  4  XOR feedback into low byte
		LD	L, A		;  4  update LFSR

dvol		EQU	$+1
		CP	0x80		;  7  compare with volume threshold
		SBC	A, A		;  4  A = #FF if below threshold (noise on), else 0

		AND	0x10		;  7  isolate audio bit (bit 4)
		RRCA			;  4  shift bit 4 -> bit 3 (AUDIO_BIT)
		OUT	(AUDIO_PORT), A	; 11  output noise sample
		DS	20		; 80  timing padding (8 MHz)
		DJNZ	sloop		; 13  inner loop
					;----
					;149  per iteration (vs 65 @ 3.5 MHz)

		DEC	C		;4	; outer loop
		JR	NZ, sloop	;12

		JR	drumEnd

; DRUM 1 - KICK
; Generates a pitch-descending pulse wave.
; A = initial pitch (higher value = higher starting pitch)
; The pitch slides down over time to create a "kick" sound.
drum1
		LD	(deRest), DE	; save registers
		LD	(bcRest), BC
		LD	(hlRest), HL

		LD	D, A		; D = start pitch parameter (A = param<<1)
		LD	E, 0
		LD	H, E		; HL = 0 (phase accumulator)
		LD	L, E

		EX	AF, AF'

		SRL	D		; convert pitch param: shift right into...
		RL	E		; ...E's high bit. DE = frequency divider

		LD	C, 0x3		; outer loop count (3 iterations)

xlllp
		ADD	HL, DE		; 11  advance phase accumulator
		JR	C, _noUpd	;12/7 if overflow, skip pitch slide this sample
		LD	A, E		;  4  reduce frequency (pitch slides down)
_slideSpeed	EQU	$+1
		SUB	0x10		;  7  slide speed (self-modifiable)
		LD	E, A		;  4
		SBC	A, A		;  4  propagate borrow to D
		ADD	A, D		;  4
		LD	D, A		;  4
		DS	7		; 28  extra padding for slide path (8 MHz)
_noUpd
		LD	A, H		;  4  output high byte of phase accumulator
		AND	0x10		;  7  isolate audio bit (bit 4)
		RRCA			;  4  shift bit 4 -> bit 3 (AUDIO_BIT)
		OUT	(AUDIO_PORT), A	; 11  output kick sample
		DS	18		; 72  timing padding (8 MHz)
		DJNZ	xlllp		; 13  inner loop (B starts at 0, wraps to 256)
		DEC	C		;  4
		JR	NZ, xlllp	; 12  outer loop
					; non-slide: 134, slide: 184 t-states per sample
					; (vs 58/80 @ 3.5 MHz, ratio ~2.3x ≈ 8/3.5)
deRest		EQU	$+1
		LD	DE, 0		; restore registers

drumEnd
hlRest		EQU	$+1
		LD	HL, 0
bcRest		EQU	$+1
		LD	BC, 0

		LD	B, 18		; adjust timer to compensate for drum duration
					; (drum took ~237 samples, so subtract from tick)
		JP	drumRet		; return to note playback

; WAVEFORM ALGORITHM LOOKUP TABLE (mixAlgo)
; This table must be page-aligned (start at a 256-byte boundary).
; It contains 32 entries of 8 bytes each. The first 5 bytes of each entry
; are executable Z80 code that gets copied into the algo1/algo2/algo3
; self-modifying slots in the inner loop.
;
; Each algorithm receives:
;   A = H = high byte of phase accumulator (0-255 sawtooth ramp)
; And must produce:
;   A = output sample (only bit 4 matters, masked by AND C / AND #10 after)
;
; The algorithms create different timbres by manipulating the phase value
; using combinations of rotates, complements, DAA, and boolean ops.
; The unused bytes (ds padding) are NOPs in the copied code.
;
; Some algorithms reference IXH/IYH/IYL (sweep counters) to create
; evolving duty cycles over time.

;IF		(LOW($))!=0
;		ORG	256 * (1 + (HIGH($)))		; align to next 256-byte page boundary
;ENDIF
	ALIGN	256

mixAlgo

	; --- #00: 50% square ---
	; 5 NOPs: A=H passes through unchanged. AND C tests bit 4 of the
	; raw sawtooth phase -> toggles halfway = 50% duty cycle.
		DS	8		;00

	; --- #01: 32% square ---
	; DAA shifts the threshold, AND H re-tests -> narrower pulse
		DAA			;01
		AND	H
		DS	6

	; --- #02: 25% square ---
	; RLCA shifts phase left, AND H -> 25% duty
		RLCA			;02
		AND	H
		DS	6

	; --- #03: 19% square ---
	; DAA + CPL + AND H -> ~19% duty cycle
		DAA			;03
		CPL
		AND	H
		DS	5

	; --- #04: 12.5% square ---
	; INC A twice shifts threshold, XOR H + RRCA -> narrow 12.5% pulse
		INC	A		;04
		INC	A
		XOR	H
		RRCA
		DS	4

	; --- #05: 6.25% square ---
	; INC A + XOR H + RRCA -> very narrow 6.25% pulse
		INC	A		;05
		XOR	H
		RRCA
		DS	5

	; --- #06: duty sweep (fast) ---
	; ADD A,IYL adds fast sweep counter -> duty cycle evolves quickly
	; CPL+DEC A inverts + shifts, OR H combines
		ADD	A, IYL		;06
		CPL
		DEC	A
		OR	H
		DS	3

	; --- #07: duty sweep (slow) ---
	; Same idea but ADD A,IYH (slower sweep counter)
		ADD	A, IYH		;07
		CPL
		DEC	A
		OR	H
		DS	3

	; --- #08: duty sweep (very slow, start low) ---
	; ADD A,IXH (slowest sweep counter), AND H (start with narrow duty)
		ADD	A, IXH		;08
		CPL
		DEC	A
		AND	H
		DS	3

	; --- #09: duty sweep (very slow, start high) ---
	; ADD A,IXH but AND H without CPL -> starts with wide duty
		ADD	A, IXH		;09
		AND	H
		DS	5


	; --- #0a: duty sweep (slow) + octave ---
	; RLCA doubles frequency (octave up), sweep modulates duty
		ADD	A, IYH		;0a
		RLCA
		XOR	H
		DS	4

	; --- #0b: duty sweep (slow) - octave ---
	; RRCA halves frequency (octave down)
		ADD	A, IYH		;0b
		RRCA
		XOR	H
		DS	4

	; --- #0c: duty sweep (fast) - octave ---
		ADD	A, IYL		;0c
		RRCA
		XOR	H
		DS	4

	; --- #0d: vowel 1 ---
	; DAA + RLCA + CPL + XOR H creates formant-like harmonics
		DAA			;0d
		RLCA
		CPL
		XOR	H
		DS	4

	; --- #0e: vowel 2 ---
		DAA			;0e
		RLCA
		RLCA
		CPL
		XOR	H
		DS	3

	; --- #0f: vowel 3 ---
		DAA			;0f
		CPL
		XOR	H
		DS	5

	; --- #10: vowel 4 ---
		RRCA			;10
		RRCA
		SBC	A, A
		AND	H
		RLCA
		DS	3

	; --- #11: vowel 5 ---
		RLCA			;11
		RLCA
		XOR	H
		RLCA
		DS	4

	; --- #12: vowel 6 ---
		RRCA			;12
		SBC	A, A
		AND	H
		RLCA
		DS	4

	; --- #13: rasp 1 ---
	; CPL + DAA + SBC A,A creates harsh, buzzy harmonics
		CPL			;13
		DAA
		SBC	A, A
		RLCA
		AND	H
		DS	3

	; --- #14: rasp 2 ---
		RLCA			;14
		RLCA
		SBC	A, A
		AND	H
		DS	4

	; --- #15: phat rasp ---
	; DAA + shifts + CPL + OR H -> thick, raspy tone
		DAA			;15
		RRCA
		RRCA
		CPL
		OR	H
		DS	3

	; --- #16: phat 2 ---
		DAA			;16
		RRCA
		RRCA
		CPL
		AND	H
		DS	3

	; --- #17: phat 3 ---
		DAA			;17
		RLCA
		RLCA
		CPL
		AND	H
		DS	3

	; --- #18: phat 4 ---
		DAA			;18
		RLCA
		CPL
		AND	H
		DS	4

	; --- #19: phat 5 ---
		DAA			;19
		RRCA
		RRCA
		CPL
		XOR	H
		DS	3

	; --- #1a: phat 6 ---
		CPL			;1a
		DAA
		SBC	A, A
		RLCA
		XOR	H
		DS	3

	; --- #1b: phat 7 ---
		RLCA			;1b
		RLCA
		SBC	A, A
		AND	H
		RLCA
		DS	3

	; --- #1c: noise 1 ---
	; RLC H rotates phase accumulator IN PLACE (destructive!),
	; creating pseudo-random noise-like tones
		RLC	H		;1c
		AND	H
		DS	5

	; --- #1d: noise 2 ---
		RLC	H		;1d
		SBC	A, A
		OR	H
		DS	4

	; --- #1e: noise 3 ---
		RLC	H		;1e
		DS	6

	; --- #1f: noise 4 ---
		RLC	H		;1f
		OR	H
		XOR	L
		DS	5

musicData
		INCLUDE	"music.asm"
	ENDIF
