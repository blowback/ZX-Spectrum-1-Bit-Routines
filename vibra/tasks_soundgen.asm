    IFDEF   SPECTRUM
;*******************************************************************************
task_idle					;update noise and idle

	ex af,af'		;4'		;update noise pitch prescaler
noisePitch equ $+1
	add a,#0		;7
	jr nc,skip4		;12/7
	
	ex af,af'		;4

	add hl,hl		;11		;update noise generator
	sbc a,a			;4
	xor l			;4
	ld l,a			;4 (34)
	
ret4
	ret c			;5		;timing
	ld a,ixh		;8		;load output state ch1
	out (#fe),a		;11__80		;output ch1
	
	exx			;4
	dec sp			;6		;correct stack offset
	dec sp			;6

	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ds 6			;24

	ld a,iyh		;8		;load output state ch2
	out (#fe),a		;11__80		;output state ch2
	
	exx			;4
	ld a,(noiseVolume)	;13		;load output state noise
	cp h			;4
	sbc a,a			;4
	ds 7			;28
	out (#fe),a		;11__64		;output noise state
	jp soundLoop		;10

skip4						;timing adjustment
	ex af,af'		;4'		;swap back to AF
	nop			;4
	xor a			;4		;clear carry for following timing adjustment
	jp ret4			;10 (34)


;*******************************************************************************
timerLo	db 0					;timer lo-byte

task_update_timer				;update timer hi-byte
	xor a			;4
	ret c			;5		;timing
	in a,(#fe)		;11		;read kbd
	cpl			;4
	and #1f			;7
	jp nz,exit		;10
	
	ret nz			;5		;timing
	exx			;4
	ld a,ixh		;8
	out (#fe),a		;11___80
	
 	ld a,i			;9		;I = timer hi-byte
 	dec a			;4
 	ld i,a			;9
	jp nz,skip5		;10
	
	ld hl,task_read_ptn	;10
	push hl			;11
	
ret5	
	ds 2			;8
	ld a,iyh		;8
	out (#fe),a		;11___80
	
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	exx			;4
	ld a,(noiseVolume)	;13
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11___64
	jp soundLoop		;10

skip5
	ld a,r			;9		;timing
	jr ret5			;12


;*******************************************************************************	
task_update_fx1					;update vibrate/slide fx ch1
						;see task_update_fx2 for detailed comments
						
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ds 2			;8
	xor a			;4		;timing + clear carry
	ret c			;5		;timing
	ld a,ixh		;8	
vibrDir1
	inc b			;4		;vibrato initial direction
vibrSpeed1 equ $+1
	bit 2,b			;8		;vibrato speed, (see above, bit 3 -> ld b,4 | bit 2 -> ld b,2...)
	
	out (#fe),a		;11___80
	
	ld a,e			;4
fxType1
	jp z,slideDown1		;10		;jp z = vibrato = #ca, jp = slide down = #c3, jp c = slide up = #da (fx off: C = 0)
	
	add a,c			;4		;DE += C
	ld e,a			;4
	adc a,d			;4
	sub e			;4
	ld d,a			;4 
	
	ds 3			;12
retv1
	ds 2			;8
	ld a,0			;7		;timing
	ld a,iyh		;8
	out (#fe),a		;11___80
	
	ld a,(noiseVolume)	;13
	cp h			;4
	sbc a,a			;4
	ds 8			;32
	out (#fe),a		;11___64
	jp soundLoop		;10


slideDown1
	sub c			;4		;DE -= C
	ld e,a			;4
	sbc a,a			;4    
	add a,d			;4            
	ld d,a			;4
	jr retv1		;12 


;*******************************************************************************	
task_update_fx2					;update vibrate/slide fx ch2
	exx			;4
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	nop			;4
	xor a			;4		;timing + clear carry
	ret c			;5		;timing
	ld a,ixh		;8		;load output state ch2
vibrDir2
	inc b			;4		;initial vibrato direction
vibrSpeed2 equ $+1
	bit 2,b			;8		;bit n = vibrato speed (lower is faster)
						;B must be initialized with (2^n)/2 (so bit 3 -> ld b,4 | bit 2 -> ld b,2...)	
	out (#fe),a		;11___80	;output state ch1
	
	ld a,e			;4
fxDepth2 equ $+1
	ld c,1			;7		;modification amount
fxType2	
	jp z,slideDown2		;10		;jp z = vibrato, jp = slide down, jp c = slide up (carry is always cleared at this point)
						;fx off: C = 0
	add a,c			;4		;base divider ch2 += modification amount (DE += C)
	ld e,a			;4
	adc a,d			;4
	sub e			;4
	ld d,a			;4 
	
	ds 3			;12
retv2
	nop			;4
	exx			;4
	ld a,iyh		;8		;load output state ch2
	out (#fe),a		;11___80	;output ch2
	
	ds 2			;8
	ld a,r			;9		;timing
	exx			;4
	ld c,#fe		;7		;restore C'=#fe (needed by main sound loop)
	exx			;4
	
	ld a,(noiseVolume)	;13		;load output state noise
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11___64	;output noise state
	jp soundLoop		;10


slideDown2
	sub c			;4		;DE -= C
	ld e,a			;4
	sbc a,a			;4    
	add a,d			;4            
	ld d,a			;4
	jr retv2		;12 

;*******************************************************************************






	ELSE


;******************************************************************
; Ant's notes:
;
; TASK: IDLE
; Default task that runs when no other tasks are pending on the stack.
; Updates the noise channel LFSR and prescaler, outputs all 3 channels with
; correct timing, then jumps back to soundLoop.
;
; The noise channel uses a 16-bit LFSR (Linear Feedback Shift Register) in HL.
; The LFSR is clocked by a prescaler in A' - only when the prescaler overflows
; (carry set) does the LFSR advance. This controls the noise pitch: higher
; prescaler value = LFSR advances more often = higher-pitched noise.
;******************************************************************
;
task_idle

		EX	AF, AF'		; 4	; switch to shadow A (noise prescaler)
noisePitch	EQU	$+1
		ADD	A, 0x0		; 7	; add noise pitch to prescaler (self-mod operand)
		JR	NC, skip4	; 12/7	; if no overflow, skip LFSR update

		EX	AF, AF'		; 4	; switch back to main A

		ADD	HL, HL		; 11	; shift LFSR left (HL <<= 1)
		SBC	A, A		; 4	; A = 0xFF if carry (old bit 15) was set, else 0x00
		XOR	L		; 4	; XOR feedback into low byte
		LD	L, A		; 4	; store back - this is the LFSR feedback tap

ret4
		RET	C		; 5	; timing adjustment (carry always clear here, so never taken)
		LD	A, IXH		; 8	; load ch1 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1

		EXX			; 4	; switch to shadow regs for ch2
		DEC	SP		; 6	; correct stack offset - task_idle was called via
		DEC	SP		; 6	; `ret` which popped 2 bytes, but we want to keep
						;stk_idle on the stack for next iteration

		LD	A, 0		; 7	; timing padding (3 x dummy loads)
		LD	A, 0		; 7
		LD	A, 0		; 7
		DS	6		; 24	; more timing padding (6 bytes of nops)

		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		EXX			; 4	; back to main regs
		LD	A, (noiseVolume)	; 13	; load noise volume threshold
		CP	H		; 4	; compare to LFSR high byte
		SBC	A, A		; 4	; gate noise: A = #FF if vol > H, else #00
		DS	7		; 28	; timing padding
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10	; back to main loop

skip4					; prescaler didn't overflow - LFSR not clocked
		EX	AF, AF'		; 4	; swap back to main A
		NOP			; 4	; timing padding
		XOR	A		; 4	; clear carry for ret c timing adjustment below
		JP	ret4		; 10 	; rejoin path (matches the 34T of the LFSR update)


;*******************************************************************************
; TIMER
; timerLo is a single byte counter decremented every soundLoop iteration.
; When it wraps to 0, the main loop pushes task_update_timer (= timerLo+1).
; task_update_timer then decrements the high byte (I register).
; When I reaches 0, the current pattern row is done -> push task_read_ptn.
; Together, timerLo and I form a 16-bit timer controlling note duration.
;*******************************************************************************
timerLo		DB	0		; timer lo-byte (decremented every soundLoop)

task_update_timer			; runs when timerLo wraps to 0
		XOR	A		; 4	; A = 0
		RET	C		; 5	; timing (carry always clear, never taken)
		IN	A, 0xFE		; 11	; read keyboard port
		CPL			; 4	; invert (keys active low on Spectrum)
		AND	0x1F		; 7	; mask lower 5 bits (key columns)
		JP	NZ, exit	; 10	; if any key pressed, exit the engine

		RET	NZ		; 5	; timing (Z is clear from AND, so never taken...
					; unless we just came from the jp nz,exit path)
		EXX			; 4
		LD	A, IXH		; 8	; load ch1 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 

		LD	A, I		; 9	; load timer high byte from I register
		DEC	A		; 4	; decrement it
		LD	I, A		; 9	; store back
		JP	NZ, skip5	; 10	; if not zero, row still playing

		LD	HL, task_read_ptn	; 10	; timer expired! schedule pattern reader task
		PUSH	HL		; 11	; to load next row of note data

ret5
		DS	2		; 8	; timing padding
		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		LD	A, 0		; 7	; timing padding (4 x dummy loads)
		LD	A, 0		; 7
		LD	A, 0		; 7
		LD	A, 0		; 7
		EXX			; 4
		LD	A, (noiseVolume)	; 13	; load noise volume
		CP	H		; 4
		SBC	A, A		; 4	; gate noise output
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10

skip5					; timer hi-byte not zero yet
		LD	A, R		; 9	; timing padding (ld a,r takes 9T like ld a,i)
		JR	ret5		; 12	; matches ld hl,nn (10) + push hl (11) = 21T


;*******************************************************************************
; TASK: UPDATE FX CHANNEL 1
; =========================
; Called when ch1's phase accumulator overflows (once per wave cycle).
; Applies vibrato or slide effect to ch1's base divider (DE).
;
; VIBRATO: B counts up each call. When bit N of B is set (checked via
;   self-modifying `bit N,b` instruction), the modification direction
;   reverses (add vs subtract). The vibrDir1 byte toggles between
;   INC B (#04) and DEC B (#05). The depth is in C.
;
; SLIDE: Simply adds (slide up) or subtracts (slide down) C from DE each
;   cycle, causing a continuous pitch change.
;
; The fxType1 byte is self-modified to select the effect:
;   #CA = JP Z  -> vibrato (reverses direction when bit triggers)
;   #C3 = JP    -> slide down (always subtract)
;   #DA = JP C  -> slide up (always add, carry is cleared before test)
;*******************************************************************************
task_update_fx1

		LD	A, 0		; 7	; timing padding
		LD	A, 0		; 7
		LD	A, 0		; 7
		DS	2		; 8
		XOR	A		; 4	; timing + clear carry (for fxType1 test below)
		RET	C		; 5	; timing (never taken, carry just cleared)
		LD	A, IXH		; 8	; load ch1 output state
vibrDir1
		INC	B		; 4	; vibrato phase counter (self-mod: inc b / dec b)
					; inc b (0x04) or dec b (0x05) toggles vibrato direction
vibrSpeed1	EQU	$+1
		BIT	2, B		; 8	; check vibrato speed bit (self-mod: bit N,b)
					; N is set by task_read_vib1 via bitCmdLookup table
					; lower bit number = faster vibrato

		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 

		LD	A, E		; 4	; A = low byte of ch1 base divider
fxType1
		JP	Z, slideDown1	; 10	; SELF-MODIFYING jump selects effect type:
					;  0xCA (jp z)  = vibrato: on bit trigger, reverse dir
					;  0xC3 (jp)   = slide down: always take jump (subtract)
					;  0xDA (jp c) = slide up: never taken (C cleared above)
					;  If C=0, no modification happens (fx disabled)

		ADD	A, C		; 4	; SLIDE UP PATH: DE += C (add depth to divider)
		LD	E, A		; 4	;  low byte
		ADC	A, D		; 4	;  propagate carry to high byte
		SUB	E		; 4	;  A = new D (high byte of sum)
		LD	D, A		; 4

		DS	3		; 12	; timing padding
retv1
		DS	2		; 8	; timing padding
		LD	A, 0		; 7	; timing
		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		LD	A, (noiseVolume)	; 13	; load noise volume
		CP	H		; 4
		SBC	A, A		; 4	; gate noise
		DS	8		; 32	; timing padding
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10


slideDown1				;SLIDE DOWN / VIBRATO REVERSE PATH
		SUB	C		; 4	; DE -= C (subtract depth from divider)
		LD	E, A		; 4	;  low byte
		SBC	A, A		; 4	;  borrow: A = 0xFF if borrow, else #00
		ADD	A, D		; 4	;  high byte adjusted for borrow
		LD	D, A		; 4
		JR	retv1		; 12	; rejoin common output path


;*******************************************************************************
; TASK: UPDATE FX CHANNEL 2
; Same as task_update_fx1 but for channel 2 (operates on DE' via EXX).
; Also must restore C' = #FE after modifications since ch2's C register
; is used as the output port number in the main loop.
;
; fxType2 controls effect type (same encoding as fxType1).
; fxDepth2 (self-mod in ld c,N) sets the modification amount.
; vibrDir2/vibrSpeed2 control vibrato parameters.
;*******************************************************************************
task_update_fx2
		EXX			; 4	; switch to shadow regs (DE' = ch2 divider)
		LD	A, 0		; 7	; timing padding
		LD	A, 0		; 7
		LD	A, 0		; 7
		NOP			; 4
		XOR	A		; 4	; clear carry for fxType2 test
		RET	C		; 5	; timing (never taken)
		LD	A, IXH		; 8	; load ch1 output state (yes, ch1 - for the
					; interleaved output timing, we output ch1 here)
vibrDir2
		INC	B		; 4	; vibrato phase counter (self-mod: inc/dec)
vibrSpeed2	EQU	$+1
		BIT	2, B		; 8	; check vibrato speed bit (self-mod: bit N,b)
					; B must be init'd to (2^N)/2 for correct phase
					; e.g. bit 3 -> init B=4, bit 2 -> init B=2
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1

		LD	A, E		; 4	; A = low byte of ch2 base divider
fxDepth2	EQU	$+1
		LD	C, 1		; 7	; C = fx depth/modification amount (self-mod)
fxType2
		JP	Z, slideDown2	; 10	; effect type selector (same encoding as fxType1):
					;  jp z (#CA) = vibrato
					;  jp (#C3) = slide down
					;  jp c (#DA) = slide up
					;  fx off when C = 0 (no modification regardless)
		ADD	A, C		; 4	; SLIDE UP: DE' += C
		LD	E, A		; 4
		ADC	A, D		; 4
		SUB	E		; 4
		LD	D, A		; 4

		DS	3		; 12	; timing padding
retv2
		NOP			; 4
		EXX			; 4	; back to main regs
		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	;	; OUTPUT CH2 

		DS	2		; 8	; timing padding
		LD	A, R		; 9	; timing (ld a,r = 9T)
		EXX			; 4	; switch to shadow regs briefly
		LD	C, 0xFE		; 7	; restore C' = #FE (output port, may have been
					; clobbered by ld c,depth above)
		EXX			; 4	; back to main regs

		LD	A, (noiseVolume)	;13	; load noise volume
		CP	H		; 4
		SBC	A, A		; 4	; gate noise
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10


slideDown2				; SLIDE DOWN / VIBRATO REVERSE
		SUB	C		; 4	; DE' -= C
		LD	E, A		; 4
		SBC	A, A		; 4
		ADD	A, D		; 4
		LD	D, A		; 4
		JR	retv2		; 12

;*******************************************************************************
	ENDIF
