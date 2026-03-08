;VIBRA
;ZX beeper engine by utz 07'2017
;*******************************************************************************

    IFDEF   SPECTRUM

	org #8000

looping equ 1
	include "equates.h"
	
	di
	
;ix,de,bc	accu,base,mod ch1
;iy,de',bc'	accu,base,mod ch2/#fe
;hl		accu/seed noise
;hl'		stack mod
;sp		task stack/data pointer
;a'		prescaler noise
;i		timer hi

	exx
	push hl
	push iy
	ld (oldSP),sp
	
	ld hl,musicData
	ld (seqPointer),hl
	ld sp,stk_idle
	ld ix,0
	ld iy,0
	ld de,0
	ld bc,#fe
	exx
	xor a
	ld h,a
	ld l,a
	ld d,a
	ld e,a
	ld (timerLo),a
	ld (vibrInit1),a
	ld (vibrInit2),a
	ld a,#10
	ld i,a
	jp task_read_seq

;*******************************************************************************
soundLoop
	add ix,de		;15		;update counter ch1
	ld a,ixh		;8		;load output state ch1
	
	exx			;4
	jp nc,skip1		;10
	
	ld hl,task_update_fx1	;10		;push update event on taskStack on counter overflow
	push hl			;11

ret1	
	out (c),a		;12___80	;output ch1
	
	ld hl,timerLo		;10		;update timer lo-byte
	dec (hl)		;11
	jr nz,skip3		;12/7

	inc hl			;6		;= ld hl,task_update_timer
	push hl			;11		;push update event on taskStack if timer lo-byte = 0

ret3	
	add iy,de		;15		;update counter ch2
	ld a,iyh		;8		;load output state ch2
	out (c),a		;11___80	;output ch2
	jr nc,skip2		;12/7
	
	ld hl,task_update_fx2	;10		;push update event on taskStack on counter overflow
	push hl			;11
						
ret2	
	inc hl			;6		;timing
	exx			;4		
noiseVolume equ $+1
	ld a,#0			;7		;load output state noise channel	TODO: if we do ld a,(noiseVolume), we don't need timing adjust and can
						;						save 6t elsewhere
	cp h			;4
	sbc a,a			;4
	out (#fe),a		;11___64
	
	ret			;11		;fetch next task from taskStack
				;224

skip1						;timing adjustments
	nop
	ld l,0
	jp ret1
skip2
	nop
	jr ret2
skip3
	jr ret3

;*******************************************************************************
taskStack
	ds 30
stk_idle
	dw task_idle
;*******************************************************************************
exit
oldSP equ $+1
	ld sp,0
	pop iy
	pop hl
	exx
	ei
	ret	

;*******************************************************************************	

	include "tasks_soundgen.asm"
	include "tasks_data.asm"

;*******************************************************************************
musicData
	include "music.asm"
	
    ELSE    

;******************************************************************
; Ant's notes:
;  
; Vibra: 3-channel PIN engine:
;   - 2 tone channels (ch1, ch2) using phase accumulator synthesis
;   - 1 noise channel using a linear feedback shift register (LFSR)
;   - Vibrato and slide (portamento) effects on both tone channels
;   
; NB no click drums, should be able to achieve realistic drum noises
; with noise gen.
;
; Each tone channel has a 16-bit accumulator (IX for ch1, IY for ch2) and a
; 16-bit "base divider" (DE for ch1, DE' for ch2). Each iteration of the main
; sound loop adds the divider to the accumulator. The high bit of the
; accumulator (bit 15, i.e. IXH/IYH bit 7) determines the output state -
; when it's set, the speaker is pulled high. The frequency is proportional to
; the divider value: larger divider = higher pitch.
;
; The engine uses the Z80 hardware stack (SP) as a cooperative task scheduler!
; Reminds me of a FORTH intrepreter...
; The main sound loop ends with a `ret`, which pops the next task address from
; the stack and jumps to it. Tasks are pushed onto the stack when events occur:
;   - Counter overflow on ch1 -> push task_update_fx1
;   - Counter overflow on ch2 -> push task_update_fx2
;   - Timer lo-byte reaches 0 -> push task_update_timer
; When no tasks are pending, the stack points to `stk_idle` which holds the
; address of `task_idle` - the default handler that updates noise and loops.
;
; Each task must maintain the same cycle timing as the main loop (outputting
; audio samples at the correct intervals: 80/80/64 T-states apart) and then
; either `jp soundLoop` or `ret` to chain to the next task.
;
; The main loop outputs 3 samples per iteration:
;   1. Channel 1 output via OUT (C),A  (port #FE, C register = #FE)
;   2. Channel 2 output via OUT (#FE),A
;   3. Noise output via OUT (#FE),A
; These outputs are spaced at regular intervals (80, 80, and 64 T-states)
; creating a PIN (Pulse Interleaving) mixing scheme that interleaves the
; three channels on the single-bit speaker output.
;
;
; REGISTER ALLOCATION
; -------------------
;   IX      - phase accumulator ch1 (IXH bit 7 = output state)
;   DE      - base frequency divider ch1 (added to IX each loop)
;   BC      - B = vibrato counter ch1, C = fx depth ch1
;
;   IY      - phase accumulator ch2 (IYH bit 7 = output state)
;   DE'     - base frequency divider ch2 (added to IY each loop)
;   BC'     - B' = vibrato counter ch2, C' = #FE (port number for OUT)
;
;   HL      - noise LFSR seed / accumulator
;   HL'     - (used as scratch in tasks)
;   SP      - task stack pointer / data pointer (dual use)
;   A'      - noise pitch prescaler
;   I       - timer high byte (counts down rows/pattern steps)
;

; Now targetting an 8 MHz MicroBeast (with sjasmplus).
;
; Other changes:
;
; 1) different output port for beeper
; 2) different bit (bit 3) in port for beeper
;
KB_PORT		EQU	0x00	; 0x0n, A[15:8] = 0xfe, 0xfd, 0xfb, 0xf7
AUDIO_PORT	EQU	0x24	; 16c550 MCR 
AUDIO_BIT	EQU	0x08	; bit 3


		ORG	0x0100
		OUTPUT	"vibra.com"

looping		EQU	1		; 1 = loop song, 0 = play once then exit
		INCLUDE	"equates.h"	; note frequency divider lookup table

		DI			; disable interrupts - we need precise timing
					; and SP is repurposed as a data/task pointer

; INITIALIZATION
		EXX			; switch to shadow registers
		PUSH	HL		; save HL' on system stack (to restore on exit)
		PUSH	IY		; save IY on system stack
		LD	(oldSP), SP	; save system stack pointer for clean exit

		LD	HL, musicData	; point sequence reader to start of song data
		LD	(seqPointer), HL
		LD	SP, stk_idle	; init task stack - bottom holds task_idle address
		LD	IX, 0		; clear ch1 phase accumulator
		LD	IY, 0		; clear ch2 phase accumulator
		LD	DE, 0		; clear ch2 base divider (DE' since we EXX'd)
		LD	BC, AUDIO_PORT	; B'=0 (vibrato counter), C'= 0xFE (output port)
		EXX			; switch back to main registers
		XOR	A		; A = 0
		LD	H, A		; clear noise LFSR seed (HL = 0)
		LD	L, A
		LD	D, A		; clear ch1 base divider (DE = 0 = silence)
		LD	E, A
		LD	(timerLo), A	; clear timer low byte
		LD	(vibrInit1), A	; clear vibrato init values for ch1
		LD	(vibrInit2), A	; clear vibrato init values for ch2
		LD	A, 0x10		; initial timer hi-byte (will count down to 0)
		LD	I, A		; I register doubles as timer high byte
		JP	task_read_seq	; begin by reading the first sequence entry

; MAIN SOUND LOOP
; Core audio loop. Runs continuously, outputting 3 interleaved samples per
; iteration (ch1, ch2, noise). Total loop = 224 T-states.
;
; Checks for phase accumulator overflows and timer expiry, pushing task
; addresses onto the stack when events occur. The final `ret` pops and
; executes the next pending task (or task_idle if none pending).
;
; Output spacing: ch1 OUT at +80T, ch2 OUT at +80T, noise OUT at +64T
soundLoop
		ADD	IX, DE		; 15		; add frequency divider to ch1 phase accumulator
		LD	A, IXH		; 8		; A = hi byte of ch1 accu (bit 7 = speaker state)

		EXX			; 4		; switch to shadow regs (C' = 0xFE = output port)
		JP	NC, skip1	; 10		; no carry = no overflow, skip fx task push

		LD	HL, task_update_fx1	;10	; ch1 accu overflowed: completed one full wave cycle
		PUSH	HL		; 11		; schedule fx update task on the task stack

ret1
		OUT	(c), A		; 12		; OUTPUT CH1 port C' = 0xFE, bit 4 of A drives speaker

		LD	HL, timerLo	; 10		; point HL at timer low byte counter
		DEC	(hl)		; 11		; decrement timer low byte
		JR	NZ, skip3	; 12/7		; if not zero yet, skip timer task

		INC	HL		; 6		; HL now = timerLo+1 = address of task_update_timer
							; (clever trick: task_update_timer label is placed
							; right after the timerLo byte in memory)
		PUSH	HL		; 11		; schedule timer update task

ret3
		ADD	IY, DE		;15		; add frequency divider to ch2 phase accumulator
		LD	A, IYH		;8		; A = hi byte of ch2 accu
		OUT	(c), A		;11		; OUTPUT CH2
		JR	NC, skip2	;12/7		; no overflow, skip fx task push

		LD	HL, task_update_fx2	;10	; ch2 accu overflowed
		PUSH	HL		;11		; schedule ch2 fx update task

ret2
		INC	HL		;6		; timing padding (result discarded)
		EXX			;4		; switch back to main regs (HL = noise LFSR)
noiseVolume	EQU	$+1
		LD	A, 0x0		;7		; A = noise volume threshold (self-modifying code:
							; the 0x0 operand is patched at runtime by task_read_noise)
							; TODO: if we do ld a,(noiseVolume), we don't need
							; timing adjust and can save 6t elsewhere
		CP	H		;4		; compare volume threshold to noise LFSR high byte
		SBC	A, A		;4		; A = 0xFF if threshold > H (noise on), else #00
							; this gates the noise output by volume level
		OUT	AUDIO_PORT, A	;11		; OUTPUT NOISE

		RET			;11		; pop next task from stack and jump to it
					;224		; (default: task_idle when stack is at stk_idle)

; TIMING EQUALIZATION STUBS
; When a counter does NOT overflow, these stubs burn the same T-states as
; the overflow path (ld hl,imm16 + push hl) to keep output timing constant.
skip1					 		; ch1 didn't overflow
		NOP			;4		; \
		LD	L, 0		;7		;  > 21T = matches ld hl,nn (10) + push hl (11)
		JP	ret1		;10		; /
skip2							; ch2 didn't overflow
		NOP			;4		; \  16T (close match)
		JR	ret2		;12		; /
skip3							; timer didn't expire
		JR	ret3		;12		; matches the inc+push path timing
							; (jr taken=12 vs jr nz not-taken=7, inc=6, push=11)

; TASK STACK
; 30 bytes of stack space for pending task addresses (up to 15 entries).
; Bottom of stack always holds address of task_idle - the fallback handler.
taskStack
		DS	30		; task stack space
stk_idle
		DW	task_idle	; default task: update noise + loop back to soundLoop

; EXIT - restore system state and return to caller
exit
oldSP		EQU	$+1		; self-mod: operand patched at init with saved SP
		LD	SP, 0		; restore original stack pointer
		POP	IY		; restore IY (saved at init)
		POP	HL		; restore HL' (saved at init via exx)
		EXX			; swap back so caller sees correct register set
		EI			; re-enable interrupts
		RET			; return to caller


		INCLUDE	"tasks_soundgen.asm"
		INCLUDE	"tasks_data.asm"

musicData
		INCLUDE	"music.asm"
	ENDIF

