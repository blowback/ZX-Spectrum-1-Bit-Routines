;******************************************************************
; microbeast nanobeep: updated for 8MHz
;
; a port of:
;nanobeep
;77 byte beeper engine by utz 09'2015-04'2016
;******************************************************************
;
    IFDEF ZX_SPECTRUM
;******************************************************************
; Ant's notes:
; Pulse Interleaving / Time Division Multiplexing / XOR mixing 
; 2 channels, 8 bit accumulators + noise
;
; This is designed to be as small as possible.
; It was originally targetted at a 3.5 MHz ZX Spectrum.
;
; the inner loop is 1351 T (see timings below)
; so sample rate = 3,500,000 / 1351 = 2590 Hz 
;
; with 8 bit counters counting up:
; freq_value = (desired_hz * 256) / 2590
; 
;******************************************************************


;******************************************************************
;
;ignores kempston
;only reads keys Space,A,Q,1 (can be fixed with 2 additional bytes)
;
;D - add counter ch1
;E - base freq ch1
;B - internal delay counter
;C - add counter ch2
;HL - data pointer
;IY - timer

	org #8000

init
	di
	ld (oldSP),sp
	ld sp,musicdata+2

;******************************************************************
rdseq
	xor a
	pop hl			;pattern pointer to HL
	or h
	jr nz,rdptn
	;jr exit		;uncomment to disable looping
	
	ld sp,loop
	jr rdseq

drum
    ; the value 0xFE (in E on entry) is doing *triple* duty here!
    ; it's 1) the OUT port (moved to C via L),
    ; 2) the low byte of the source address (0x00FE) in ROM that 
    ; is our "drum sample"
    ; 3) it's the "make a drum sound" marker in the pattern data
    ;
	ex de,hl        ; save HL (data ptr) in DE. E (0xfe) => L
                    ; D (ch1 counter) => H
	ld h,a          ; A = 0, so now H = 0
	ld c,l          ; C = 0xFE
	ld b,h          ; B <- H <- 0 (from tw instructions before)
	otir            ; while B { (HL--) -> (C), B-- } 
                    ; cp 256 bytes from 0x00FE -> port 0xFE
	ex de,hl        ; restore hl (data ptr)

;******************************************************************	
rdptn
	inc hl	
	ld a,(hl)		;base freq ch1		
	ld e,a
	inc a			;if A=#ff, i.e. end of pattern
	jr z,rdseq      ; next pattern
	
	inc a           ; if e was 0xfe (i.e. drum byte)
	jr z,drum       ; do some drumming

	inc hl			;point to base freq ch2	

	ld iy,(musicdata)	;speed

;******************************************************************
play            ; CH 1 [657 T]
	ld a,d      ; d += e (add freq to acc) [4T]
	add a,e     ; carry SET on overflow    [4T]
	ld d,a                                 [4T]
	
    ; this is an optimisation: B is doing double duty,
    ; it's both the mask to select the EAR bit (bit 4, 0x10) in 
    ; port 0xFE, and the DJNZ counter used to set the minimum 
    ; pulse width (which we need to give the speaker a chance 
    ; to move).
	ld b,48     ; b = inner delay &  ear mask  [7T]
	
	sbc a,a     ; did the previous add overflow? Y: A=0xff, N: A=0x00 [4T]
	and b       ; mask to ear bit + don't care bit  [4T]
	out (#fe),a ; [11T]

	djnz $      ; hold for pulse width [13 * 47 + 8 = 619 T]

                ; CH2  [660 T] 
	ld a,c      ; c += (hl) (add freq to acc) [4T]
	add a,(hl)  ; carry SET on overflow [7T]
	ld c,a      ; [4T]
	
	ld b,48     ; inner delay & ear mask [7T]

	sbc a,a     ; did the previous add overflow? Y: A=0xff, N: A=0x00 [4T]
	and b       ; mask to ear bit + don't care bit [4T]
	out (#fe),a ; [11T]
	
	djnz $      ; hold for pulse width [13 * 47 + 8 = 619T]

                ; timer / loop - 34 T
	dec iy      ; decrement timer [10T]
	ld a,iyh    ; [8T]
	or b        ; b is zero, so it's fancy CP 0 [4T]
	jr nz,play  ; not zero, go round again [12T]

    ; total inner loop: [1351 T]
	
	;in a,(#fe)		;read kbd
	;rra
	;jr c,rdptn		;only space,a,q,1 will exit
	;cpl			;comment out the 2 lines above and uncomment this for full keyboard scan
	;and #1f
	;jr nz,rdptn
    jr rdptn
	
;******************************************************************			
exit
oldSP equ $+1       ; genius!
	ld sp,0
	ei
	ret
;******************************************************************

musicdata
	include "music.asm"

    ELSE 

;******************************************************************
; Ant's notes:
; Pulse Interleaving / Time Division Multiplexing / XOR mixing 
; 2 channels, 8 bit accumulators + noise
;
; This is designed to be as small as possible.
; 
; Now targetting 8 MHz MICROBEAST. The beast's beeper is bit 3 (0x08) 
; of port 0x24 (the 16C550 UART's Modem Control Register - OUT2)
;
; We can't use the same B=48 trick because we're on a different bit.
; We need B to satisfy two conditions:
;   1) the bit corresponding to the beeper
;   2) a numeric value to give the desired pulse width
;
; Bits we *can* drive are 2, 3, 6 and 7, and we must not touch the
; rest.
; Value     Bits set    Decimal     DJNZ time
; 0x08       3           8           99 T
; 0x0C       3,2         12          151 T
; 0x48       6,3         72          931 T
; 0x4C       6,3,2       76          983 T
; 0x88       7,3         136         1763 T
; 0x8C       7,3,2       140         1815 T
; 0xC8       7,6,3       200         2595 T
; 0xCC       7,6,3,2     204         2647 T
;
; sweet spot is 0x48 or 0x4c. The 0x88+ values are too slow - the 
; loop time balloons and the sample rate drops below 3kHz, which 
; destroys tuning resolution.
;
; 0x48 gives 931 T per DJNZ, pulse width of 116 us.
;
; the inner loop is 1975 T (see timings below)
; so sample rate = 8,000,000 / 1975 = 4051 Hz 
;
; with 8 bit counters counting up:
; freq_value = (desired_hz * 256) / 4051
;
; Should be usable from C2 upwards altho low octaves will be coarse.
; 4kHz mixing rate will be audible on anything with decent treble 
; response (which maybe excludes the microbeast's speaker?)
;
; We could drop B to 0x0c for a much faster loop (715 T, 11 kHz) but 
; the 151 T pulse hold might not be enough for decent volume from 
; the speaker. 
; 
;******************************************************************
;
;D - add counter ch1
;E - base freq ch1
;B - internal delay counter
;C - add counter ch2
;HL - data pointer
;IY - timer

		ORG	0x0100
		OUTPUT	"nanobeep.com"

PORT		EQU	0x24	; 16c550 MCR 
AUDIO		EQU	0x08	; bit 3
MINPULSE	EQU	0x0c	; 0x48
init
	di
	ld (oldSP),sp
	ld sp,musicdata+2

;******************************************************************
rdseq
	xor a
	pop hl			;pattern pointer to HL
	or h
	jr nz,rdptn
	jr exit		;uncomment to disable looping
	
	ld sp,loop
	jr rdseq

drum
    ; the value 0xFE (in E on entry) is doing *triple* duty here!
    ; it's 1) the OUT port (moved to C via L),
    ; 2) the low byte of the source address (0x00FE) in ROM that 
    ; is our "drum sample"
    ; 3) it's the "make a drum sound" marker in the pattern data
    ;
	ex de,hl        ; save HL (data ptr) in DE. E (0xfe) => L
                    ; D (ch1 counter) => H
	ld h,a          ; A = 0, so now H = 0
	ld c,l          ; C = 0xFE
	ld b,h          ; B <- H <- 0 (from tw instructions before)
	otir            ; while B { (HL--) -> (C), B-- } 
                    ; cp 256 bytes from 0x00FE -> port 0xFE
	ex de,hl        ; restore hl (data ptr)

;******************************************************************	
rdptn
	inc hl	
	ld a,(hl)		;base freq ch1		
	ld e,a
	inc a			;if A=#ff, i.e. end of pattern
	jr z,rdseq      ; next pattern
	
	inc a           ; if e was 0xfe (i.e. drum byte)
	jr z,drum       ; do some drumming

	inc hl			;point to base freq ch2	

	ld iy,(musicdata)	;speed

;******************************************************************
play            ; CH 1 [969 T]
	ld a,d      ; d += e (add freq to acc) [4T]
	add a,e     ; carry SET on overflow    [4T]
	LD	D, A      ;                    [4T]
	
    ; this is an optimisation: B is doing double duty,
    ; it's both the mask to select the AUDIO bit (bit 3, 0x08) in 
    ; port 0x24, and the DJNZ counter used to set the minimum 
    ; pulse width (which we need to give the speaker a chance 
    ; to move).
	ld b,MINPULSE     ; b = inner delay &  beeper mask  [7T]
	
	sbc a,a     ; did the previous add overflow? Y: A=0xff, N: A=0x00 [4T]
	and b       ; mask to ear bit + don't care bit  [4T]
	out (PORT),a ; [11T]

	djnz $      ; hold for pulse width [13 * 71 + 8 = 931 T]

                ; CH2  [972 T] 
	ld a,c      ; c += (hl) (add freq to acc) [4T]
	add a,(hl)  ; carry SET on overflow [7T]
	ld c,a      ; [4T]
	
	ld b,MINPULSE     ; inner delay & ear mask [7T]

	sbc a,a     ; did the previous add overflow? Y: A=0xff, N: A=0x00 [4T]
	and b       ; mask to ear bit + don't care bit [4T]
	out (PORT),a ; [11T]
	
	djnz $      ; hold for pulse width [13 * 71 + 8 = 931T]

                ; timer / loop - 34 T
	dec iy      ; decrement timer [10T]
	ld a,iyh    ; [8T]
	or b        ; b is zero, so it's fancy CP 0 [4T]
	jr nz,play  ; not zero, go round again [12T]

    ; total inner loop: [1975 T]
	
	;in a,(#fe)		;read kbd
	;rra
	;jr c,rdptn		;only space,a,q,1 will exit
	;cpl			;comment out the 2 lines above and uncomment this for full keyboard scan
	;and #1f
	;jr nz,rdptn
    jr rdptn
	
;******************************************************************			
exit
oldSP equ $+1       ; genius!
	ld sp,0
	ei
	ret
;******************************************************************

musicdata
	include "music.asm"
;******************************************************************
    ENDIF
