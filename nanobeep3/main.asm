;;; nanobeep3 - 54 byte beeper engine for ZX Spectrum
;;; by utz 11'2022 * irrlichtproject.de

    IFDEF SPECTRUM
    device zxspectrum48
    org #8000

    include "note_names.h"

nanobeep3_init
    di
    ld hl,music_data.pend-1
    ld bc,1
    exx
    push hl
    ld (.old_sp),sp
    ld sp,music_data

    jr .read_sequence

.read_keys
    in a,(#fe)
    rra
    jr nc,.exit

.play
    exx                         ; 4
    ld a,(hl)                   ; 7
    add a,e                     ; 4
    ld e,a                      ; 4
    adc a,d                     ; 4
    sub e                       ; 4
    ld d,a                      ; 4
    out (#fe),a                 ;11

    dec bc                      ; 6
    ld a,b                      ; 4
    or c                        ; 4
    jr nz,.play                 ;12..68

.read_pattern
    inc hl                      ; read next pattern byte (length)
    ld b,(hl)                   ; if it's #ff, end of pattern is reached
    inc hl                      ; point to note byte
    inc b
    jr nz,.read_keys

.read_sequence
    pop hl
    inc h
    jr nz,.read_pattern+1

.exit
.old_sp = $+1
    ld sp,0
    pop hl
    exx
    ei
    ret

    display $-nanobeep3_init

music_data
    include "music.asm"

end
    savetap "main.tap",CODE,"main",nanobeep3_init,end-nanobeep3_init

    ELSE

;******************************************************************
; Ant's notes:
; Pulse Interleaving 
; 2 channels, 8.8 bit accumulators
;
; This is designed to be as small as possible.
; Now targetting an 8 MHz MicroBeast.
;
; Other changes:
;
; 1) different output port for beeper
; 2) different bit (bit 3) in port for beeper - this will affect pitch
;
; For the previous 2 nanobeeps we've tried to compensate by adjusting
; the note values, but this time we'll try something different:
;
; 1. everything will be 8/3.5 = 2.29x too fast (pitch and tempo). Fix by
;    padding the play loop so each iteration takes the same real time
;    original: 68 T / 3.5 Mhz = 19.43 us per iter
;    target: 19.34 us * 8 MHz = 155.4 T per iter
; 2. compensate for the new beeper bit with a simple RRCA before the OUT
;    this comes out of our loop padding allowance.
; 
;******************************************************************
KB_PORT		EQU	0x00	; 0x0n, A[15:8] = 0xfe, 0xfd, 0xfb, 0xf7
AUDIO_PORT	EQU	0x24	; 16c550 MCR 
AUDIO_BIT	EQU	0x08	; bit 3
        ORG	0x0100
        OUTPUT "nbeep3.com"
        INCLUDE	"note_names.h"

nanobeep3_init
        ; register bank A active
        DI
        LD	HL, music_data.pend - 1     ; HL_a -> pattern end
        LD	BC, 1                       ; BC_a <- note length = 1
        EXX                             ; switch to register bank B
        PUSH	HL                      ; save HL_b
        LD	(.old_sp), SP               ; save SP
        LD	SP, music_data              ; SP points to sequence data

        JR	.read_sequence              ; read first sequence

.read_keys
        IN	A, KB_PORT                  ; read all rows
        RRA                             ; check column 0 key press
        JR	NC, .exit                   ; yep - exit

.play
        EXX                             ; 4   swap banks (alternates ch1/ch2 each iter)
        LD	A, (hl)                     ; 7   A <- (HL) = note (freq increment)
        ; 8.8-bit phase accumulator in DE, E is fractional phase
        ADD	A, E                        ; 4   add note to E (lo byte of phase accum)
        LD	E, A                        ; 4   E <- updated accumulator lo byte
        ADC	A, D                        ; 4   A <- E_new + D + carry from ADD
        SUB	E                           ; 4   A <- D + carry (isolate hi byte update)
        LD	D, A                        ; 4   D <- D + carry (hi byte of phase accum)
        RRCA                            ; 4   compensate for new beeper bit
        OUT	AUDIO_PORT, A               ;11   output to speaker (bit 4 = beeper)

        ; timing compensation: a total of 84 T, plus 4T from the RRCA
    DUP 4
        PUSH	AF
        POP AF
    EDUP

        
        DEC	BC                          ; 6  decrement counter
        LD	A, B                        ; 4  16 bit cp #0
        OR	C                           ; 4
        JR	NZ, .play                   ;12..68 not zero, go round again

.read_pattern
        INC	HL                      ; read next pattern byte (length)
        LD	B, (hl)                   ; if it's #ff, end of pattern is reached
        INC	HL                      ; point to note byte
        INC	B                       ; test for #ff end marker (#ff+1=0)
        JR	NZ, .read_keys          ; length wasn't 0xff (end of pattern)

.read_sequence
        POP	HL                      ; HL <- pattern ptr (offset by -#100)
        INC	H                       ; undo -#100 offset / test end (#ff->0)
        JR	NZ, .read_pattern + 1   ; nope, get pattern

.exit
.old_sp = $+1
        LD	SP, 0                   ; 0 gets overwritten by startup code
        POP	HL                      ; POP HL_b
        EXX                         ; switch to register bank X
                                    ; note, no guarantee it's the bank we started with!
        EI                      
        RET                         ; and we're out

        DISPLAY	$-nanobeep3_init    ; print engine size in bytes at assembly time

music_data
        INCLUDE	"music.asm"
end

    ENDIF