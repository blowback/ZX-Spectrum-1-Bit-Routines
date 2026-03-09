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
; TASK: IDLE (8MHz MicroBeast version - 512T per iteration)
; Updates noise LFSR/prescaler, outputs all 3 channels, loops back.
; RRCA before tone OUTs rotates bit 4 → bit 3 for AUDIO_BIT.
;******************************************************************
task_idle
		DS	23		; 92T	;\
		LD	A, 0		; 7T	;/ 99T entry padding (noise→ch1 gap)

		EX	AF, AF'		; 4	; switch to shadow A (noise prescaler)
noisePitch	EQU	$+1
		ADD	A, 0x0		; 7	; add noise pitch to prescaler (self-mod)
		JR	NC, skip4	; 12/7	; if no overflow, skip LFSR update

		EX	AF, AF'		; 4	; switch back to main A

		ADD	HL, HL		; 11	; shift LFSR left
		SBC	A, A		; 4	; A = 0xFF if carry (old bit 15), else 0x00
		XOR	L		; 4	; XOR feedback into low byte
		LD	L, A		; 4	; store back - LFSR feedback tap

ret4
		RET	C		; 5	; timing (carry always clear here, never taken)
		LD	A, IXH		; 8	; load ch1 output state
		RRCA			; 4	; bit 4 → bit 3
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 ___183

		EXX			; 4	; switch to shadow regs for ch2
		DEC	SP		; 6	; correct stack offset (undo RET's pop of
		DEC	SP		; 6	; stk_idle, keeping task_idle on stack)
		DS	36		; 144T	; ch1→ch2 gap padding

		LD	A, IYH		; 8	; load ch2 output state
		RRCA			; 4	; bit 4 → bit 3
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2 ___183

		EXX			; 4	; back to main regs
		LD	A, 0		; 7	;\
		LD	A, 0		; 7	;/ 14T padding before noiseVolume load
		LD	A, (noiseVolume)	; 13	; load noise volume threshold
		CP	H		; 4	; compare to LFSR high byte
		SBC	A, A		; 4	; gate noise
		AND	AUDIO_BIT	; 7	; mask to bit 3 only
		DS	22		; 88T	; ch2→noise gap padding
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE ___146
		JP	soundLoop	; 10

skip4					; prescaler didn't overflow - LFSR not clocked
		EX	AF, AF'		; 4	; swap back to main A
		NOP			; 4
		XOR	A		; 4	; clear carry for RET C timing adjust
		JP	ret4		; 10	; rejoin path (matches 34T of LFSR update)


;*******************************************************************************
; TIMER (8MHz version)
;*******************************************************************************
timerLo		DB	0		; timer lo-byte (decremented every soundLoop)

task_update_timer			; runs when timerLo wraps to 0
		DS	23		; 92T	;\
		LD	A, 0		; 7T	;/ 99T entry padding
		XOR	A		; 4	; A = 0
		RET	C		; 5	; timing (never taken)
		IN	A, (KB_PORT)	; 11	; read keyboard port
		CPL			; 4	; invert (keys active low)
		AND	0x1F		; 7	; mask key columns
		JP	NZ, exit	; 10	; if any key pressed, exit

		RET	NZ		; 5	; timing (never taken)
		EXX			; 4
		LD	A, IXH		; 8	; load ch1 output state
		RRCA			; 4	; bit 4 → bit 3
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 ___183

		DS	23		; 92T	;\
		LD	A, 0		; 7T	;/ 99T ch1→ch2 padding
		LD	A, I		; 9	; load timer high byte
		DEC	A		; 4	; decrement it
		LD	I, A		; 9	; store back
		JP	NZ, skip5	; 10	; if not zero, row still playing

		LD	HL, task_read_ptn	; 10	; timer expired! schedule pattern read
		PUSH	HL		; 11

ret5
		DS	2		; 8	; timing padding
		LD	A, IYH		; 8	; load ch2 output state
		RRCA			; 4	; bit 4 → bit 3
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2 ___183

		LD	A, 0		; 7	;\
		LD	A, 0		; 7	;/ 14T padding
		EXX			; 4
		LD	A, (noiseVolume)	; 13	; load noise volume
		CP	H		; 4
		SBC	A, A		; 4	; gate noise
		AND	AUDIO_BIT	; 7	; mask to bit 3 only
		DS	22		; 88T	; ch2→noise padding
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE ___146
		JP	soundLoop	; 10

skip5					; timer hi-byte not zero yet
		LD	A, R		; 9	; timing (matches LD HL,nn + PUSH = 21T)
		JR	ret5		; 12


;*******************************************************************************
; TASK: UPDATE FX CHANNEL 1 (8MHz version)
; Vibrato/slide on ch1's base divider (DE).
; fxType1: #CA=vibrato, #C3=slide down, #DA=slide up
;*******************************************************************************
task_update_fx1
		DS	32		; 128T	; entry padding (replaces 29T original)
		XOR	A		; 4	; clear carry for fxType1 test
		RET	C		; 5	; timing (never taken)
		LD	A, IXH		; 8	; load ch1 output state
vibrDir1
		INC	B		; 4	; vibrato phase counter (self-mod: inc/dec)
vibrSpeed1	EQU	$+1
		BIT	2, B		; 8	; vibrato speed bit (self-mod: bit N,b)
		RRCA			; 4	; bit 4 → bit 3
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 ___183

		LD	A, E		; 4	; A = low byte of ch1 base divider
fxType1
		JP	Z, slideDown1	; 10	; self-mod jump: vibrato/slide down/slide up

		ADD	A, C		; 4	; SLIDE UP: DE += C
		LD	E, A		; 4
		ADC	A, D		; 4
		SUB	E		; 4
		LD	D, A		; 4
		DS	3		; 12	; timing (matches JR retv1 in slideDown1)
retv1
		LD	A, 0		; 7	;\
		LD	A, 0		; 7	;/ 14T padding
		DS	25		; 100T	; ch1→ch2 padding
		LD	A, IYH		; 8	; load ch2 output state
		RRCA			; 4	; bit 4 → bit 3
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2 ___183

		LD	A, 0		; 7	;\
		LD	A, 0		; 7	;/ 14T padding
		LD	A, (noiseVolume)	; 13	; load noise volume
		CP	H		; 4
		SBC	A, A		; 4	; gate noise
		AND	AUDIO_BIT	; 7	; mask to bit 3 only
		DS	23		; 92T	; ch2→noise padding
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE ___146
		JP	soundLoop	; 10


slideDown1				; SLIDE DOWN / VIBRATO REVERSE
		SUB	C		; 4	; DE -= C
		LD	E, A		; 4
		SBC	A, A		; 4
		ADD	A, D		; 4
		LD	D, A		; 4
		JR	retv1		; 12


;*******************************************************************************
; TASK: UPDATE FX CHANNEL 2 (8MHz version)
; Same as fx1 but for ch2 (shadow DE' via EXX).
; C' no longer used for OUT port, so no restore needed.
;*******************************************************************************
task_update_fx2
		EXX			; 4	; switch to shadow regs (DE' = ch2 divider)
		DS	31		; 124T	; entry padding
		XOR	A		; 4	; clear carry for fxType2 test
		RET	C		; 5	; timing (never taken)
		LD	A, IXH		; 8	; load ch1 output state
vibrDir2
		INC	B		; 4	; vibrato phase counter (self-mod: inc/dec)
vibrSpeed2	EQU	$+1
		BIT	2, B		; 8	; vibrato speed bit (self-mod: bit N,b)
		RRCA			; 4	; bit 4 → bit 3
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 ___183

		LD	A, E		; 4	; A = low byte of ch2 base divider
fxDepth2	EQU	$+1
		LD	C, 1		; 7	; fx depth (self-mod)
fxType2
		JP	Z, slideDown2	; 10	; self-mod jump: vibrato/slide down/slide up

		ADD	A, C		; 4	; SLIDE UP: DE' += C
		LD	E, A		; 4
		ADC	A, D		; 4
		SUB	E		; 4
		LD	D, A		; 4
		DS	3		; 12	; timing (matches JR retv2 in slideDown2)
retv2
		LD	A, 0		; 7	;\
		DS	24		; 96T	;/ 103T ch1→ch2 padding
		EXX			; 4	; back to main regs
		LD	A, IYH		; 8	; load ch2 output state
		RRCA			; 4	; bit 4 → bit 3
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2 ___183

		LD	A, 0		; 7	;\
		LD	A, 0		; 7	;/ 14T padding
		LD	A, (noiseVolume)	; 13	; load noise volume
		CP	H		; 4
		SBC	A, A		; 4	; gate noise
		AND	AUDIO_BIT	; 7	; mask to bit 3 only
		DS	23		; 92T	; ch2→noise padding
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE ___146
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
