;;; KICK DRUM SYNTHESIZER
;;; by utz 09'2019 * irrlichtproject.de

;;; USAGE: 1) Define DRUM_RETURN_ADDRESS
;;;        2) Prepare stack
;;;           SP+0 - decay mode (NO_DECAY, LINEAR_DECAY/_X2, EXPONENTIAL_DECAY)
;;;           SP+2 - sweep speed (bit mask, more bits ~ faster speed)
;;;           SP+3 - initial pitch (higher value ~ higher pitch)
;;;           SP+4 - volume ((1..7)<<4)
;;;           SP+5 - length
;;;        3) JP kick_drum_init
;;;
;;; TIMING: ca. (length * 112 * 256 + (length - 1) * 24) cycles
;;;
;;; REGISTER USAGE: F/F' destroyed, SP += 6

    IFDEF SPECTRUM
NO_DECAY equ #5faf              ; xor a; ld e,a
LINEAR_DECAY equ #1d00          ; nop; dec e
LINEAR_DECAY_X2 equ #1d1d       ; dec e; dec e
EXPONENTIAL_DECAY equ #3bcb     ; srl e

kick_drum_init
    rr b                        ; additional half-row adjust
    ld (_oldHL),hl              ; 16
    ld (_oldDE),de              ; 20
    ld (_oldBC),bc              ; 20
    ld (_oldA),a                ; 13
    ex af,af'                   ;  4
    ld (_oldAshadow),a          ; 13

    pop bc                      ; 10    volume|length<<8
    ld a,b                      ;  4
    ex af,af'                   ;  4
    pop de                      ; 10    sweep_speed|initial_pitch<<8
    pop hl                      ; 10
    ld (_end_mode),hl           ; 16
    xor a                       ;  4
    ld h,a                      ;  4
    ld l,a                      ;  4
    ld b,#fe                    ;  7    adjust timer lo
    ex af,af'                   ;  4 -- init 163

    ex af,af'
_play_kick
    nop
    out (#fe),a                 ; 11__29
    add hl,de                   ; 11
    jr nc,_wait                 ; 12/7

    rlc e                       ;  8
    jr nc,_no_sweep_update      ; 12/7
    srl d                       ;  8 -- 30

    ld a,h                      ;  4
    rlca                        ;  4
    sbc a,a                     ;  4
    and c                       ;  4
    nop
    out (#fe),a                 ; 11__68
    rrca                        ;  4
    out (#fe),a                 ; 11__15
    rrca                        ;  4
    dec b                       ;  4
    jp nz,_play_kick            ; 10 --- 112

    ex af,af'
    dec a
    jr nz,_play_kick - 1
    jr _exit

_wait                           ;+12
    ld a,d                      ;  4
    or a                        ;  4
    jr z,_play_kick_end0        ; 12/7

_no_sweep_update
    nop                         ;  4
    ld a,h                      ;  4
    rlca                        ;  4
    sbc a,a                     ;  4
    and c                       ;  4
    nop
    out (#fe),a                 ; 11
    rrca                        ;  4
    out (#fe),a                 ; 11
    rrca                        ;  4
    djnz _play_kick             ; 13 --- 112

    ex af,af'
    dec a
    jr nz,_play_kick - 1
    jr _exit


_play_kick_end0
    ld e,#80
    jp _wait_return_end

    ex af,af'
_play_kick_end
    nop
    out (#fe),a                 ; 11__29
    add hl,de                   ; 11
    jr nc,_wait_end             ; 12/7

_end_mode
    ds 2                        ;  8
    ld a,0                      ;  7    timing
    ds 2                        ;  8 -- 30

_wait_return_end
    ld a,h                      ;  4
    rlca                        ;  4
    sbc a,a                     ;  4
    and c                       ;  4
    nop
    out (#fe),a                 ; 11__68
    rrca                        ;  4
    out (#fe),a                 ; 11__15
    rrca                        ;  4
    dec b                       ;  4
    jp nz,_play_kick_end        ; 10

    ex af,af'
    dec a
    jr nz,_play_kick_end - 1

_exit
_oldHL equ $+1
    ld hl,0                     ; 10
_oldDE equ $+1
    ld de,0                     ; 10
_oldBC equ $+1
    ld bc,0                     ; 10
_oldAshadow equ $+1
    ld a,0                      ;  7
    ex af,af'                   ;  4
_oldA equ $+1
    ld a,0                      ;  7
    jp DRUM_RETURN_ADDRESS      ; 10 -- exit 58, init+exit 221

_wait_end                       ;+12
    ds 2                        ;  8
    jp _wait_return_end         ; 10 -- 30









    ELSE

;******************************************************************
; Ant's notes:

; Generates a kick drum sound by sweeping a square wave from high to low
; pitch. The sound is produced entirely through the 1-bit beeper using a
; phase accumulator (HL) with a frequency divider (DE). The pitch sweeps
; downward by halving D (the coarse pitch byte) whenever the sweep timer
; (E, used as a rotating bit mask) triggers.
;
; The output uses a 2-level PWM trick: each sample outputs the
; volume value, then immediately outputs it right-shifted (RRCA) twice,
; creating 3 output pulses of decreasing width within a single sample
; period. This gives a richer sound than a simple on/off square wave.
;
; The drum has two phases:
;   1. SWEEP phase: pitch descends until D reaches 0
;   2. END phase: pitch is frozen, volume decays according to the
;      chosen decay mode (self-modifying code patches the instructions)
;
; USAGE: 1) Define DRUM_RETURN_ADDRESS
;        2) Prepare stack (parameters read via POP):
;           SP+0 - decay mode (NO_DECAY, LINEAR_DECAY/_X2, EXPONENTIAL_DECAY)
;           SP+2 - sweep speed (low byte = bit mask, more bits = faster)
;                  initial pitch (high byte, higher = higher starting pitch)
;           SP+4 - volume (low nybble, bits 4-6) | length (high byte)
;        3) JP kick_drum_init
;
; TIMING: ca. (length * 112 * 256 + (length - 1) * 24) cycles
;KB_PORT		EQU	0x00	; 0x0n, A[15:8] = 0xfe, 0xfd, 0xfb, 0xf7
;AUDIO_PORT	EQU	0x24	; 16c550 MCR 
;AUDIO_BIT	EQU	0x08	; bit 3


; Decay mode constants — these are actually Z80 instruction bytes that get
; written into _end_mode via self-modifying code.
NO_DECAY            EQU	0x5FAF          ; encodes "ld e,a; xor a" — zeroes the pitch,
                                        ; effectively silencing immediately
LINEAR_DECAY        EQU	0x1D00          ; encodes "dec e; nop" — subtracts 1 from E
                                        ; (volume counter) each overflow
LINEAR_DECAY_X2     EQU	0x1D1D          ; encodes "dec e; dec e" — subtracts 2
EXPONENTIAL_DECAY   EQU	0x3BCB          ; encodes "srl e" — halves E for exponential
                                        ; decay (fast at first, slow tail)

    MODULE  Kick
kick_drum_init
        RR	B                           ; additional half-row adjust (carry from
                                        ; control byte bit 0 shifts into B)
    ; Save all registers
        LD	(_oldHL), HL                ; 16    save via self-modifying code
        LD	(_oldDE), DE                ; 20
        LD	(_oldBC), BC                ; 20
        LD	(_oldA), A                  ; 13
        EX	AF, AF'                     ;  4
        LD	(_oldAshadow), A            ; 13

    ; Read drum parameters from the music data stream (via SP/POP)
        POP	BC                          ; 10    C = volume (bits 4-6), B = length
        SRL	C                           ;  8    shift volume down 1 bit (bit 4→bit 3 for AUDIO_BIT)
        LD	A, B                        ;  4    length → A
        EX	AF, AF'                     ;  4    stash length in A'
        POP	DE                          ; 10    E = sweep speed mask, D = initial pitch
        POP	HL                          ; 10    HL = decay mode (2 instruction bytes)
        LD	(_end_mode), HL             ; 16    patch decay instructions into end phase
        XOR	A                           ;  4
        LD	H, A                        ;  4    HL = 0 (reset phase accumulator)
        LD	L, A                        ;  4
        LD	B, 0xFE                     ;  7    B = sample counter (254, adj. for init)
        EX	AF, AF'                     ;  4 -- init 163

; SWEEP PHASE - pitch descends while D > 0
; Each iteration is ~272-276 T-states at 8 MHz (matching ~120T at 3.5 MHz).
; The phase accumulator HL has the frequency divider DE added to it.
; When HL overflows, we check if the pitch should sweep down.
        EX	AF, AF'                     ; bring length counter back into A'
_play_kick
        NOP                             ; timing padding
        OUT	AUDIO_PORT, A               ; 11    output current sample (from prev iter)
        ADD	HL, DE                      ; 11    advance phase accumulator
        JR	NC, _wait                   ; 12/7  no overflow — skip to output section

    ; Phase accumulator overflowed — check if we should sweep the pitch down.
    ; E serves double duty: it's the low byte of the freq divider AND a
    ; rotating bit mask that controls sweep speed. Each overflow, we rotate
    ; E left. If a 1 bit rotates into carry, we halve D (the pitch).
        RLC	E                           ;  8    rotate sweep speed mask
        JR	NC, _no_sweep_update        ; 12/7  no carry = don't sweep yet
        SRL	D                           ;  8    halve the coarse pitch (sweep down!)

    ; Generate audio output using the PWM trick:
    ; H contains the high byte of the phase accumulator. RLCA moves its top
    ; bit into carry, then SBC A,A converts that to #FF or #00. ANDing with
    ; C (volume) gives the output level. Two RRCA + OUT pairs follow,
    ; creating a quick burst of decreasing pulse widths within one sample.
        LD	A, H                        ;  4    \
        RLCA                            ;  4     | convert phase accumulator overflow
        SBC	A, A                        ;  4     | into square wave: #FF or #00
        AND	C                           ;  4    /  mask with volume
        NOP                             ;   timing
        DS	38                          ; 152T padding (8 MHz timing)
        OUT	AUDIO_PORT, A               ; 11  first (widest) output pulse
        RRCA                            ;  4    halve the value
        OUT	AUDIO_PORT, A               ; 11  second (narrower) output pulse
        RRCA                            ;  4    halve again (this becomes next iter's out)
        DEC	B                           ;  4    decrement sample counter
        JP	NZ, _play_kick              ; 10

    ; Inner loop done (256 samples) — decrement length counter
        EX	AF, AF'                     ; get length counter from A'
        DEC	A                           ; one fewer outer loop iteration
        JP	NZ, _play_kick - 1          ; -1 to include the ex af,af' before _play_kick
        JP	_exit                       ; length exhausted, we're done

    ; --- No-overflow path: phase didn't wrap, just output audio ---
_wait                                   ; +12   (jr nc taken adds 5 extra T-states)
        LD	A, D                        ;  4    check if pitch has swept down to 0
        OR	A                           ;  4
        JR	Z, _play_kick_end0          ; 12/7  D=0: pitch is zero, switch to end phase

_no_sweep_update
    ; Same PWM output as above (common path for both sweep and no-sweep)
        NOP                             ;  4    timing
        LD	A, H                        ;  4    convert phase acc to square wave
        RLCA                            ;  4
        SBC	A, A                        ;  4
        AND	C                           ;  4    mask with volume
        NOP
        DS	38                          ; 152T padding (8 MHz timing)
        OUT	AUDIO_PORT, A               ; 11    first pulse
        RRCA                            ;  4
        OUT	AUDIO_PORT, A               ; 11    second pulse
        RRCA                            ;  4    (carried into next iteration)
        DEC	B                           ;  4
        JP	NZ, _play_kick              ; 10

        EX	AF, AF'
        DEC	A
        JP	NZ, _play_kick - 1
        JP	_exit

_play_kick_end0
        LD	E, 0x80
        JP	_wait_return_end

        EX	AF, AF'
_play_kick_end
        NOP
        OUT	AUDIO_PORT, A               ; 11
        ADD	HL, DE                      ; 11
        JR	NC, _wait_end               ; 12/7

_end_mode
        DS	2                           ;  8
        LD	A, 0                        ;  7    timing
        DS	2                           ;  8 -- 30

_wait_return_end
        DS	38                          ; 152T padding (8 MHz timing)
        LD	A, H                        ;  4
        RLCA                            ;  4
        SBC	A, A                        ;  4
        AND	C                           ;  4
        NOP
        OUT	AUDIO_PORT, A               ; 11
        RRCA                            ;  4
        OUT	AUDIO_PORT, A               ; 11
        RRCA                            ;  4
        DEC	B                           ;  4
        JP	NZ, _play_kick_end          ; 10

        EX	AF, AF'
        DEC	A
        JR	NZ, _play_kick_end - 1

_exit
_oldHL  EQU	$+1
        LD	HL, 0                       ; 10
_oldDE  EQU	$+1
        LD	DE, 0                       ; 10
_oldBC  EQU	$+1
        LD	BC, 0                       ; 10
_oldAshadow EQU	$+1
        LD	A, 0                        ;  7
        EX	AF, AF'                     ;  4
_oldA   EQU	$+1
        LD	A, 0                        ;  7
        JP	DRUM_RETURN_ADDRESS         ; 10 -- exit 58, init+exit 221

_wait_end                               ;+12
        DS	2                           ;  8
        JP	_wait_return_end            ; 10 -- 30



    ENDMODULE
    ENDIF