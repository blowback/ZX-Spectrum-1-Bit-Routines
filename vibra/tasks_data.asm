    IFDEF   SPECTRUM
;*******************************************************************************
task_read_seq
	ld (taskPointer_rs),sp	;20
seqPointer equ $+1
	ld sp,0			;10
	exx			;4
	inc hl			;6		;timing
	pop hl			;10
	
	ld a,ixh		;8		;load output state ch1
	out (#fe),a		;11___80
	
	ld a,h			;4
	or l			;4
IF looping = 0
	jp z,exit		;10
ELSE
	jp z,doLoop		;10
ENDIF
	ld (ptnPointer),hl	;16
	ld hl,task_read_ptn	;10
	
	ld a,0			;7		;timing
	ld a,iyh		;8		;load output state ch2
	out (#fe),a		;11___80
	
	ld (seqPointer),sp	;20
taskPointer_rs equ $+1
	ld sp,0			;10
	
	push hl			;11		;push event on task stack
	
	exx			;4
	nop			;4
	ld a,h			;4		;cheating a bit with noise output
	out (#fe),a		;11___64
	jp soundLoop		;10		;-1t, oh well


doLoop
	ld hl,mloop		;10
	ld (seqPointer),hl	;16
	
	exx			;4
	nop			;4
	ld a,iyh		;8
	out (#fe),a		;11___81 (+1)
	
	ld sp,(taskPointer_rs)	;20
	dec sp			;6		;task_read_seq is already on stack, just need to adjust pos
	dec sp			;6
	
	ld a,(noiseVolume)	;13		;load noise output state
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11___64
	jp soundLoop		;10
check
;*******************************************************************************
IF (LOW($))!=0
	org 256*(1+(HIGH($)))
ENDIF
bitCmdLookup
	db 0
	db #48					;bit 1,b
	ds 2,#50				;bit 2,b
	ds 4,#58				;bit 3,b
	ds 8,#60				;bit 4,b
	ds #10,#68				;bit 5,b
	ds #20,#70				;bit 6,b
	db #78					;bit 7,b (engine will crash if B < #48)
	
;*******************************************************************************	
task_read_ptn					;determine which channels will be reloaded, and push events to taskStack accordingly
						;btw if possible, saving sp to hl' (ld hl,0, add hl,sp : ld sp,hl) is slightly faster than via mem (27t vs 30t)
						;also, ld hl,mem_addr, ld a,(hl), ld (hl),a is faster than ld a,(mem_addr), ld (mem_addr),a (24 vs 26t)
	ld (taskPointer_rp),sp	;20
ptnPointer equ $+1
	ld sp,0			;10
	pop af			;11
	ld i,a			;9		;timer hi
	
	ld a,ixh		;8
	out (#fe),a		;11___80
	
	jr z,prepareSeqRead	;12/7
	
	ld (ptnPointer),sp	;20		;TODO unaccounted for timing
	
taskPointer_rp equ $+1
	ld sp,0			;10
	exx			;4
	
	jp m,noUpdateNoise	;10
	
	ld hl,task_read_noise	;10
	push hl			;11
	jp pe,noUpdateCh2	;10
	
	ld a,iyh		;8
	out (#fe),a		;11__81 hmmok
	
	ld hl,task_read_ch2	;10
	push hl			;11
	jp c,noUpdateCh1	;10

	ld hl,task_read_ch1	;10
	push hl			;11
	exx			;4
	
	ld a,h			;4		;fake noise output
	out (#fe),a		;11__71 hmmmm
	jp soundLoop		;10
	
		
prepareSeqRead
	ld sp,(taskPointer_rp)	;20
	exx			;4
	ld hl,task_read_seq	;10
	push hl			;11
	exx			;4
	
	ld a,iyh		;8
	out (#fe),a		;11___80
	
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	ld a,0			;7		;timing
	nop			;4
	ld a,(noiseVolume)	;13
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11__64
	jp soundLoop		;10
	

noUpdateNoise
	jp pe,noUpdateCh2	;10
	ld hl,task_read_ch2	;10
	push hl			;11
	
	ld a,iyh		;8
	out (#fe),a		;11__81
	
	jp c,noUpdateCh1	;10
	
	ld hl,task_read_ch1	;10
	push hl			;11
	exx			;4
	ld a,(noiseVolume)	;13
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11__67
	jp soundLoop		;10

	
noUpdateCh2
	ld a,iyh		;8
	out (#fe),a		;11__81
	
	jp c,noUpdateCh1	;10
	
	ld hl,task_read_ch1	;10
	push hl			;11
	exx			;4
	ld a,(noiseVolume)	;13
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11__67
	jp soundLoop		;10	
	
	

noUpdateCh1
	ld a,r			;9	;timing
	ld a,r			;9	;timing
	exx			;4
	ld a,(noiseVolume)	;13
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11__64
	jp soundLoop		;10

;*******************************************************************************
task_read_ch1				;update ch1 data
	ld (taskPointer_c1),sp	;20
	ld sp,(ptnPointer)	;20
	pop de			;11	;fetch note divider ch1
	ld a,ixh		;8
	out (#fe),a		;11___81
	
	ld a,d			;4
	add a,a			;4
	jr c,noFxReloadCh1	;12/7	;if MSB of divider was set, skip fx
	
	pop bc			;11	;retrieve fx setting
	ld (ptnPointer),sp	;20
	
	ld a,b			;4
	add a,a			;4
	ld a,iyh		;8
	jr z,doSlideCh1		;12/7	;if (B != 0) && (B != #80) do vibrato
	
	out (#fe),a		;11___80

	ld ix,0			;14	;reset channel accu
	
taskPointer_c1 equ $+1
	ld sp,0			;10

	exx			;4
	ld hl,task_read_vib1	;10	;we can't complete vibrato setup in this round,
	push hl			;11	;so let's push another task
	exx			;4
	
	out (#fe),a		;11___64
	jp soundLoop		;10


noFxReloadCh1
	ccf			;4	;clear bit 15 of base divider
	rrca			;4
	ld d,a			;4
	
	ld a,r			;9	;timing
	ld (ptnPointer),sp	;20
	ld a,iyh		;8
	out (#fe),a		;11___80
	
	ld sp,(taskPointer_c1)	;20
	ld ix,0			;14	;reset channel accu
	
vibrInit1 equ $+1
	ld b,0			;7	;reset vibrato init value
	ld a,0			;7	;timing
	nop			;4

	ld a,h			;4	;fake noise
	out (#fe),a		;11___64	
	jp soundLoop		;10


doSlideCh1
	out (#fe),a		;11___85 cough cough
	
	ld sp,(taskPointer_c1)	;20	
	jp c,doSlideUpCh1	;10	;determine slide direction
	
	ld a,#c3		;7	;jp = slide down
	ld (fxType1),a		;13

	ld a,h			;4	
	out (#fe),a		;11___65 fake noise
	jp soundLoop		;10
	
	
doSlideUpCh1
	ld a,#da		;7	;jp c = slide up
	ld (fxType1),a		;13
	
	ld a,h			;4	
	out (#fe),a		;11___65 fake noise
	jp soundLoop		;10	

;*******************************************************************************
task_read_vib1
	ld a,#ca		;7	;jp z = vibrato
	ld (fxType1),a		;13
	
	exx			;4
	dec hl			;6	;timing
	ld hl,(ptnPointer)	;16
	
	nop			;4
	ld a,ixh		;8
	out (#fe),a		;11___80
	
	dec hl			;6
	ld a,(hl)		;7	;peek at vibrato init setting
	ld h,HIGH(bitCmdLookup)	;7	;look up bit x,b command patch
	ld l,a			;4
	
	ld (vibrInit1),a	;13	;store vibrato init setting for later
	ld a,(hl)		;7
	ld (vibrSpeed1),a	;13
	
	exx			;4
	ld a,iyh		;8
	out (#fe),a		;11___80
	
	ds 8			;32
	ld a,(noiseVolume)	;13
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11___64
	jp soundLoop		;10

;*******************************************************************************
task_read_ch2				;update ch2 data
	ld (taskPointer_c2),sp	;20
	ld sp,(ptnPointer)	;20
	exx			;4
	pop de			;11	;fetch note divider ch2
	ld a,ixh		;8
	out (#fe),a		;11___85
	
	ld a,d			;4
	add a,a			;4
	jr c,noFxReloadCh2	;12/7	;if MSB of divider was set, skip fx
	
	pop hl			;11	;retrieve fx setting
	ld (ptnPointer),sp	;20
	
	ld a,h			;4
	ld b,a			;4
	add a,a			;4
	ld a,iyh		;8
	jr z,doSlideCh2		;12/7	;if (B != 0) && (B != #80) do vibrato
	
	out (#fe),a		;11___84

	ld a,l			;4
	ld (fxDepth2),a		;13
	ld iyh,0		;11	;el cheapo accu reset
	
taskPointer_c2 equ $+1
	ld sp,0			;10

	ld hl,task_read_vib2	;10	;we can't complete vibrato setup in this round,
	push hl			;11	;so let's push another task
	exx			;4
	
	out (#fe),a		;11___74 hrrm
	jp soundLoop		;10


noFxReloadCh2
	ccf			;4	;clear bit 15 of base divider
	rrca			;4
	ld d,a			;4
	
	ld a,r			;9	;timing
	ld (ptnPointer),sp	;20
	ld a,iyh		;8
	out (#fe),a		;11___80
	
	ld sp,(taskPointer_c2)	;20
	ld iy,0			;14	;reset channel accu
	
vibrInit2 equ $+1
	ld b,0			;7	;reset vibrato init value
	ld a,0			;7	;timing
	exx			;4

	ld a,h			;4	;fake noise
	out (#fe),a		;11___64	
	jp soundLoop		;10


doSlideCh2
	out (#fe),a		;11___85 cough cough
	
	exx			;4
	ld sp,(taskPointer_c2)	;20	
	jr nc,doSlideDownCh2	;12/7	;determine slide direction
	ld a,#da		;7	;jp c = slide up
	ld (fxType2),a		;13
	
	ld a,h			;4	
	out (#fe),a		;11___66 fake noise
	jp soundLoop		;10

doSlideDownCh2	
	ld a,#c3		;7	;jp = slide down
	ld (fxType2),a		;13
	
	out (#fe),a		;11___67 fake noise (A = #c3, so will always output 0)
	jp soundLoop		;10	

;*******************************************************************************
task_read_vib2
	ld a,#ca		;7	;jp z = vibrato
	ld (fxType2),a		;13
	
	exx			;4
	dec hl			;6	;timing
	ld hl,(ptnPointer)	;16
	
	nop			;4
	ld a,ixh		;8
	out (#fe),a		;11___80
	
	dec hl			;6
	ld a,(hl)		;7	;peek at vibrato init setting
	ld h,HIGH(bitCmdLookup)	;7	;look up bit x,b command patch
	ld l,a			;4
	
	ld (vibrInit2),a	;13	;store vibrato init setting for later
	ld a,(hl)		;7
	ld (vibrSpeed2),a	;13
	
	exx			;4
	ld a,iyh		;8
	out (#fe),a		;11___80
	
	ds 8			;32
	ld a,(noiseVolume)	;13
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11___64
	jp soundLoop		;10

;*******************************************************************************
task_read_noise
	ld (taskPointer_n),sp	;20
	ld sp,(ptnPointer)	;20
	pop hl			;11
	ld a,ixh		;8
	out (#fe),a		;11___81
	
	ld (ptnPointer),sp	;20
	ld a,h			;4
	ld (noisePitch),a	;13
	
	ld a,l			;4
	ld (noiseVolume),a	;13
	
	ld a,0			;7	;timing
	ld a,iyh		;8
	out (#fe),a		;11___80
	
	ld a,0			;7	;timing
	ex af,af'		;4
	ld a,h			;4	;update prescaler
	ex af,af'		;4
taskPointer_n equ $+1
	ld sp,0			;10	
	ld hl,1			;10
	
	xor a			;4
	out (#fe),a		;11___64
	jp soundLoop		;10

;*******************************************************************************




    
    ELSE


;******************************************************************
; Ant's notes:
;  
; TASK: READ SEQUENCE
; Reads the next entry from the sequence table (song order list).
; The sequence is a list of 16-bit pattern pointers, terminated by 0000.
;
; Sequence format:
;   dw ptn0_addr, ptn1_addr, ..., 0   (0 = end of sequence)
;
; On end-of-sequence:
;   - If looping=0: exits the engine
;   - If looping=1: jumps back to the `mloop` label in music data
;
; Uses SP to read sequence data (saves/restores task stack pointer).
;******************************************************************

task_read_seq
		LD	(taskPointer_rs), SP	; 20	; save current task stack pointer
seqPointer	EQU	$+1
		LD	SP, 0		; 10	; load sequence pointer into SP (self-mod)
		EXX			; 4	; switch to shadow regs
		INC	HL		; 6	; timing padding
		POP	HL		; 10	; HL' = next pattern address from sequence

		LD	A, IXH		;8	; load ch1 output state
		OUT	AUDIO_PORT, A	;11	; OUTPUT CH1 

		LD	A, H		;4	; check if pattern address is 0 (end of sequence)
		OR	L		;4
IF		looping	= 0
		JP	Z, exit		;10	; if end of sequence and not looping, exit
ELSE
		JP	Z, doLoop	; 10	; if end of sequence, jump to loop handler
ENDIF
		LD	(ptnPointer), HL	; 16	; store pattern address for pattern reader
		LD	HL, task_read_ptn	; 10	; prepare to schedule pattern reader task

		LD	A, 0		; 7	; timing padding
		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2 

		LD	(seqPointer), SP	; 20	; save updated sequence pointer (SP advanced by POP)
taskPointer_rs	EQU	$+1
		LD	SP, 0			; 10	; restore task stack pointer (self-mod)

		PUSH	HL			; 11	; push task_read_ptn onto task stack

		EXX			; 4	; back to main regs
		NOP			; 4	; timing
		LD	A, H		; 4	; fake noise output (use LFSR high byte directly)
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE (approximate)
		JP	soundLoop	; 10	; -1t, oh well


;*******************************************************************************
; LOOP HANDLER
; Resets the sequence pointer to `mloop` and re-runs task_read_seq.
;*******************************************************************************
doLoop
		LD	HL, mloop	; 10	; reset sequence pointer to loop start
		LD	(seqPointer), HL	; 16

		EXX			; 4	; timing
		NOP			; 4
		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	; 11 	; OUTPUT CH2  (1T over budget)

		LD	SP, (taskPointer_rs)	; 20	; restore task stack pointer
		DEC	SP		; 6	; task_read_seq is already on the stack from the
		DEC	SP		; 6	; previous call - adjust SP to re-expose it

		LD	A, (noiseVolume)	; 13	; load noise volume
		CP	H		; 4
		SBC	A, A		; 4	; gate noise
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop		; 10
check

;*******************************************************************************
; BIT COMMAND LOOKUP TABLE
; ========================
; Maps vibrato init values (0..#40+) to the CB-prefix opcode for `bit N,b`.
; The vibrato speed is controlled by which bit of B is tested:
;   bit 1,b (#48) = fastest, bit 7,b (#78) = slowest
;
; The table is page-aligned (starts at a 256-byte boundary) so only L needs
; to be set for lookup - H is loaded with HIGH(bitCmdLookup).
;
; Index:  0    1     2-3    4-7    8-15   16-31  32-63  64+
; Opcode: 0   #48   #50    #58    #60    #68    #70    #78
;         off  bit1  bit2   bit3   bit4   bit5   bit6   bit7
;
; The vibrato init value also serves as the initial B counter value,
; which must be (2^N)/2 for correct vibrato phase (e.g. bit 3 -> B=4).
; The engine will crash if B < #48 (table underflow).
;*******************************************************************************

;IF		(LOW($))!=0
;		ORG	256 * (1 + (HIGH($)))		; align to next 256-byte page boundary
;ENDIF
		ALIGN	256
bitCmdLookup
		DB	0		; index 0: fx off
		DB	0x48		; index 1: bit 1,b (fastest)
		DS	2, 0x50		; index 2-3: bit 2,b
		DS	4, 0x58		; index 4-7: bit 3,b
		DS	8, 0x60		; index 8-15: bit 4,b
		DS	0x10, 0x68	; index 16-31: bit 5,b
		DS	0x20, 0x70	; index 32-63: bit 6,b
		DB	0x78		; index 64: bit 7,b (slowest)

;*******************************************************************************
; TASK: READ PATTERN
; ==================
; Reads the pattern header for the current row and determines which channels
; need their data reloaded. Pushes the appropriate read tasks onto the stack.
;
; Pattern row header format (first word popped as AF):
;   A = timer high byte (I register, controls note duration)
;       when A = 0, this signals end-of-pattern -> read next sequence entry
;   F = flags register, individual flag bits select which channels to reload:
;       bit 7 (S flag) = update noise channel
;       bit 2 (P/V flag) = update channel 2
;       bit 0 (C flag) = update channel 1
;
; After the header, the pattern data contains channel-specific data words
; that will be read by the individual channel read tasks (task_read_ch1/ch2/noise).
; Tasks are pushed in reverse order (noise first, then ch2, then ch1) so that
; ch1 executes first when popped (LIFO stack order).
;*******************************************************************************
task_read_ptn
		LD	(taskPointer_rp), SP	;20		;save task stack pointer
ptnPointer	EQU	$+1
		LD	SP, 0		; 10	; load pattern data pointer into SP (self-mod)
		POP	AF		; 11	; A = timer hi-byte, F = channel update flags
		LD	I, A		; 9	; set timer high byte

		LD	A, IXH		; 8	; load ch1 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 

		JR	Z, prepareSeqRead	;12/7	; if A (timer hi) was 0, end of pattern

		LD	(ptnPointer), SP	;20	; save pattern pointer (SP may advance via POPs)
						;TODO: unaccounted timing in this path

taskPointer_rp	EQU	$+1
		LD	SP, 0		; 10	; restore task stack pointer
		EXX			; 4	; switch to shadow regs for flag testing

	; Now we test the flags in F to decide which channels to update.
	; The flags were loaded by `pop af` above.
	; S flag (bit 7) -> noise, P/V flag (bit 2) -> ch2, C flag (bit 0) -> ch1

		JP	M, noUpdateNoise	; 10	; S flag set = DON'T update noise (jump if minus)
							; (S flag set means bit 7 of F = 1)

		LD	HL, task_read_noise	; 10	; S flag clear = update noise
		PUSH	HL			; 11	; push noise read task
		JP	PE, noUpdateCh2		; 10	; P/V set = DON'T update ch2

		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2 (1T over)

		LD	HL, task_read_ch2	; 10	; P/V clear = update ch2
		PUSH	HL		; 11	; push ch2 read task
		JP	C, noUpdateCh1	; 10	; C flag set = DON'T update ch1

		LD	HL, task_read_ch1	; 10	; C flag clear = update ch1
		PUSH	HL			; 11	 ;push ch1 read task
		EXX			; 4

		LD	A, H		; 4	; fake noise output (LFSR high byte)
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE (timing not ideal)
		JP	soundLoop	; 10


;*******************************************************************************
; PREPARE SEQUENCE READ
; Called when timer hi-byte = 0 (end of pattern).
; Pushes task_read_seq to load the next pattern from the sequence.
;*******************************************************************************
prepareSeqRead
		LD	SP, (taskPointer_rp)	;20	; restore task stack
		EXX			;4
		LD	HL, task_read_seq	;10	;schedule sequence reader
		PUSH	HL		;11
		EXX			;4

		LD	A, IYH		;8	; load ch2 output state
		OUT	AUDIO_PORT, A	;11	; OUTPUT CH2 

		LD	A, 0		; 7	; timing padding (x4)
		LD	A, 0		; 7
		LD	A, 0		; 7
		LD	A, 0		; 7
		NOP			; 4
		LD	A, (noiseVolume)	; 13	; load noise volume
		CP	H		; 4
		SBC	A, A		; 4	; gate noise
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10


;*******************************************************************************
; PATTERN READER FLAG DISPATCH
; ----------------------------
; These are alternate paths through the flag-testing logic above, for cases
; where fewer channels need updating. Each path pushes only the needed tasks
; and fills remaining time with output and timing padding.
;*******************************************************************************

noUpdateNoise					; noise not updated, check ch2 and ch1
		JP	PE, noUpdateCh2		; 10	; P/V set = skip ch2
		LD	HL, task_read_ch2	; 10	; update ch2
		PUSH	HL			; 11

		LD	A, IYH		; 8
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		JP	C, noUpdateCh1	; 10	; C set = skip ch1

		LD	HL, task_read_ch1	; 10	; update ch1
		PUSH	HL		; 11
		EXX			; 4
		LD	A, (noiseVolume)	; 13
		CP	H		; 4
		SBC	A, A		; 4
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10


noUpdateCh2				; ch2 not updated, check ch1
		LD	A, IYH		; 8
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		JP	C, noUpdateCh1	; 10	; C set = skip ch1

		LD	HL, task_read_ch1	; 10	; update ch1
		PUSH	HL		; 11
		EXX			; 4
		LD	A, (noiseVolume)	; 13
		CP	H		; 4
		SBC	A, A		; 4
		OUT	AUDIO_PORT, A		; 11	; OUTPUT NOISE
		JP	soundLoop	; 10


noUpdateCh1				; no ch1 update needed
		LD	A, R		; 9	; timing padding
		LD	A, R		; 9
		EXX			; 4
		LD	A, (noiseVolume)	; 13
		CP	H		; 4
		SBC	A, A		; 4
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10

;*******************************************************************************
; TASK: READ CHANNEL 1 DATA
; =========================
; Reads note divider and optional fx parameters for channel 1 from pattern data.
;
; Pattern data format for ch1:
;   dw divider          ; 16-bit frequency divider for DE
;                       ; if bit 15 set: no fx change (just reload note)
;   			; if bit 15 clear, followed by:
;   dw fx_params        ; B = vibrato init / slide direction, C = fx depth
;                       ; B=0: slide (direction determined by carry from ADD A,A)
;                       ; B=0x80: also slide (after ADD A,A, zero + carry)
;                       ; B=other: vibrato (init value determines speed via lookup)
;
; After reading, pushes task_read_vib1 if vibrato needs further setup.
;*******************************************************************************
task_read_ch1
		LD	(taskPointer_c1), SP	; 20	; save task stack pointer
		LD	SP, (ptnPointer)	; 20	; load pattern data pointer
		POP	DE			; 11	; DE = note frequency divider for ch1
		LD	A, IXH		; 8	; load ch1 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 (1T over)

		LD	A, D		; 4	; check bit 15 of divider (MSB of D)
		ADD	A, A		; 4	; shift bit 7 of D into carry
		JR	C, noFxReloadCh1	; 12/7	; if set: no fx data follows, skip fx reload

		POP	BC			; 11	; BC = fx parameters (B=type/init, C=depth)
		LD	(ptnPointer), SP	; 20	; save advanced pattern pointer

		LD	A, B		; 4	; check fx type via B value
		ADD	A, A		; 4	; shift B left - tests for B=0 and B=#80
		LD	A, IYH		; 8	; load ch2 output state (for timing)
		JR	Z, doSlideCh1	; 12/7	; if B was 0 or #80 after shift: it's a slide

		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		LD	IX, 0		; 14	; reset ch1 phase accumulator (new note)

taskPointer_c1	EQU	$+1
		LD	SP, 0		; 10	; restore task stack pointer

		EXX			; 4
		LD	HL, task_read_vib1	; 10	; vibrato needs more setup than fits in this task
		PUSH	HL		; 11	; schedule vibrato setup as another task
		EXX			; 4

		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE (A still has IYH value - fake)
		JP	soundLoop	; 10


noFxReloadCh1				; bit 15 was set: just reload note, no fx change
		CCF			; 4	; complement carry (was set, now clear)
		RRCA			; 4	; rotate right: clears bit 7 of A (was D shifted)
		LD	D, A		; 4	; D now has bit 15 cleared = actual divider MSB

		LD	A, R		; 9	; timing padding
		LD	(ptnPointer), SP	; 20	; save pattern pointer (only 1 word consumed)
		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		LD	SP, (taskPointer_c1)	; 20	; restore task stack pointer
		LD	IX, 0			; 14	; reset ch1 phase accumulator

vibrInit1	EQU	$+1
		LD	B, 0		; 7	; reset vibrato counter to init value (self-mod)
		LD	A, 0		; 7	; timing
		NOP			; 4

		LD	A, H		; 4	; fake noise output
		OUT	AUDIO_PORT, A	; 11
		JP	soundLoop	; 10


doSlideCh1				; B was 0 or 0x80: configure slide effect
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2 (5T over budget, oops)

		LD	SP, (taskPointer_c1)	;20	; restore task stack pointer
		JP	C, doSlideUpCh1	; 10	; carry from ADD A,A above: B=#80 = slide up

		LD	A, 0xC3		; 7	; 0xC3 = JP opcode = slide down
		LD	(fxType1), A	; 13	; patch fxType1 to unconditional JP (always subtract)

		LD	A, H		; 4	; fake noise output
		OUT	AUDIO_PORT, A	; 11
		JP	soundLoop	;10


doSlideUpCh1
		LD	A, 0xDA		; 7	; 0xDA = JP C opcode = slide up
		LD	(fxType1), A	; 13	; patch fxType1 (carry is always clear at test point,
						; so JP C is never taken -> falls through to add path)

		LD	A, H		; 4	; fake noise output
		OUT	AUDIO_PORT, A	; 11
		JP	soundLoop	; 10

;*******************************************************************************
; TASK: READ VIBRATO SETUP CH1
; =============================
; Completes vibrato configuration that couldn't fit in task_read_ch1.
; Patches fxType1 to JP Z (0xCA = vibrato mode), looks up the `bit N,b`
; opcode from bitCmdLookup table, and sets the vibrato init counter.
;*******************************************************************************
task_read_vib1
		LD	A, 0xCA		; 7	; 0xCA = JP Z opcode = vibrato mode
		LD	(fxType1), A	; 13	; patch fxType1

		EXX			; 4
		DEC	HL		; 6	; timing padding
		LD	HL, (ptnPointer)	; 16	; load pattern data pointer

		NOP			; 4	; timing
		LD	A, IXH		; 8	; load ch1 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1

		DEC	HL		; 6	; back up 1 byte to peek at vibrato init byte
						;(it's the last byte of the fx params word we
						; already consumed - we peek without advancing)
		LD	A, (hl)		; 7	; A = vibrato init value (also = initial B counter)
		LD	H, HIGH(bitCmdLookup)	; 7	; H = high byte of lookup table (page-aligned)
		LD	L, A			; 4	; L = vibrato init value = table index

		LD	(vibrInit1), A	; 13	; store init value for B counter resets
		LD	A, (hl)		; 7	; look up bit command opcode from table
		LD	(vibrSpeed1), A	; 13	; patch vibrSpeed1 (the `bit N,b` instruction)

		EXX			; 4
		LD	A, IYH		; 8	; load ch2 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		DS	8		; 32	; timing padding
		LD	A, (noiseVolume)	; 13
		CP	H		; 4
		SBC	A, A		; 4
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10

;*******************************************************************************
; TASK: READ CHANNEL 2 DATA
; =========================
; Same structure as task_read_ch1 but for channel 2.
; Operates on DE' (shadow registers) and IY accumulator.
;
; Pattern data format for ch2:
;   dw divider          ;16-bit frequency divider for DE'
;                       ;bit 15 set = no fx change
;   If bit 15 clear, followed by:
;   dw fx_params        ;H = vibrato init / slide direction
;                       ;L = fx depth (stored to fxDepth2)
;*******************************************************************************
task_read_ch2
		LD	(taskPointer_c2), SP	; 20	; save task stack pointer
		LD	SP, (ptnPointer)	; 20	; load pattern data pointer
		EXX			; 4	; switch to shadow regs (DE' = ch2 divider)
		POP	DE		; 11	; DE' = note frequency divider for ch2
		LD	A, IXH		; 8	; load ch1 output state
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1 (5T over)

		LD	A, D		; 4	; check bit 15 of divider
		ADD	A, A		; 4
		JR	C, noFxReloadCh2	; 12/7	; bit 15 set: no fx data, skip

		POP	HL		; 11	; HL = fx parameters (H=type/init, L=depth)
		LD	(ptnPointer), SP	; 20	; save advanced pattern pointer

		LD	A, H		; 4	; B = fx type/init value (same role as B in ch1)
		LD	B, A		; 4
		ADD	A, A		; 4	; test for 0 or #80
		LD	A, IYH		; 8	; load ch2 output state
		JR	Z, doSlideCh2	; 12/7	; if 0 or #80: slide effect

		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		LD	A, L		; 4	; L = fx depth
		LD	(fxDepth2), A	; 13	; patch self-mod depth value
		LD	IYH, 0		; 11	; reset ch2 accu high byte (cheap partial reset)

taskPointer_c2	EQU	$+1
		LD	SP, 0		; 10		; restore task stack pointer

		LD	HL, task_read_vib2	; 10	; schedule vibrato setup task
		PUSH	HL		; 11
		EXX			; 4	; back to main regs

		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE (timing rough)
		JP	soundLoop	; 10


noFxReloadCh2					; bit 15 set: just reload note
		CCF			; 4	; clear bit 15
		RRCA			; 4
		LD	D, A		; 4	; D' now has actual divider MSB

		LD	A, R		; 9	; timing
		LD	(ptnPointer), SP	; 20	; save pattern pointer
		LD	A, IYH		; 8
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		LD	SP, (taskPointer_c2)	;20	; restore task stack pointer
		LD	IY, 0		; 14	; reset ch2 phase accumulator fully

vibrInit2	EQU	$+1
		LD	B, 0		; 7	; reset vibrato counter (self-mod)
		LD	A, 0		; 7	; timing
		EXX			; 4	; back to main regs

		LD	A, H		; 4	; fake noise output
		OUT	AUDIO_PORT, A	; 11
		JP	soundLoop	; 10


doSlideCh2					; configure slide effect for ch2
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2 (over budget)

		EXX			; 4	; back to main regs
		LD	SP, (taskPointer_c2)	; 20	; restore task stack pointer
		JR	NC, doSlideDownCh2	; 12/7	; no carry from ADD = B was 0 = slide down
		LD	A, 0xDA		; 7	; 0xDA = JP C = slide up
		LD	(fxType2), A	; 13

		LD	A, H		; 4	; fake noise output
		OUT	AUDIO_PORT, A	; 11
		JP	soundLoop	; 10

doSlideDownCh2
		LD	A, 0xC3		; 7	; 0xC3 = JP = slide down
		LD	(fxType2), A	; 13

		OUT	AUDIO_PORT, A	; 11	; fake noise (A=0xC3, bit 4 clear -> speaker off)
		JP	soundLoop	; 10

;*******************************************************************************
; TASK: READ VIBRATO SETUP CH2
; Completes vibrato configuration for channel 2.
; Same logic as task_read_vib1 but patches ch2's parameters.
;*******************************************************************************
task_read_vib2
		LD	A, 0xCA		; 7	; 0xCA = JP Z = vibrato mode
		LD	(fxType2), A	; 13	; patch fxType2

		EXX			; 4
		DEC	HL		; 6	; timing
		LD	HL, (ptnPointer)	; 16	; load pattern data pointer

		NOP			; 4
		LD	A, IXH		; 8
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1

		DEC	HL		; 6	; peek back at vibrato init byte
		LD	A, (hl)		; 7	; A = vibrato init value
		LD	H, HIGH(bitCmdLookup)	; 7	; lookup table high byte
		LD	L, A			; 4	; table index

		LD	(vibrInit2), A	; 13	; store init value for B counter resets
		LD	A, (hl)		; 7	; look up bit N,b opcode
		LD	(vibrSpeed2), A	; 13	; patch vibrSpeed2

		EXX			; 4
		LD	A, IYH		; 8
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		DS	8		; 32	; timing padding
		LD	A, (noiseVolume)	; 13
		CP	H		; 4
		SBC	A, A		; 4
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10

;*******************************************************************************
; TASK: READ NOISE DATA
; =====================
; Reads noise channel parameters from pattern data.
;
; Pattern data format for noise:
;   dw params           ;H = noise pitch (prescaler add value)
;                       ;L = noise volume (threshold for LFSR comparison)
;
; Also resets the noise LFSR seed (HL = 1) and updates the prescaler in A'.
;*******************************************************************************
task_read_noise
		LD	(taskPointer_n), SP	; 20	; save task stack pointer
		LD	SP, (ptnPointer)	; 20	; load pattern data pointer
		POP	HL		; 11		; HL = noise params (H=pitch, L=volume)
		LD	A, IXH		; 8
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH1

		LD	(ptnPointer), SP	; 20	; save advanced pattern pointer
		LD	A, H		; 4	; A = noise pitch value
		LD	(noisePitch), A	; 13	; patch noise pitch prescaler add value

		LD	A, L		; 4	; A = noise volume threshold
		LD	(noiseVolume), A	; 13	; patch noise volume in main loop

		LD	A, 0		; 7	; timing
		LD	A, IYH		; 8
		OUT	AUDIO_PORT, A	; 11	; OUTPUT CH2

		LD	A, 0		; 7	; timing
		EX	AF, AF'		; 4	; switch to noise prescaler
		LD	A, H		; 4	; initialize prescaler with pitch value
		EX	AF, AF'		; 4	; switch back
taskPointer_n	EQU	$+1
		LD	SP, 0		; 10	; restore task stack pointer
		LD	HL, 1		; 10	; reset noise LFSR seed to 1
						;(0 would produce no noise - LFSR needs a seed)

		XOR	A		; 4	; A = 0 (noise output will be silent this cycle)
		OUT	AUDIO_PORT, A	; 11	; OUTPUT NOISE
		JP	soundLoop	; 10

;*******************************************************************************
    ENDIF
