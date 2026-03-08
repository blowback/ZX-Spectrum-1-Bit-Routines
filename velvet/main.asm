;;; VELVET
;;; by utz/irrlicht project 09'2019 * irrlichtproject.de

;;; A pulse-frequency modulating sound engine for the ZX Spectrum beeper with
;;; support for Crushed Additive Random Noise, a type of velvet noise first
;;; described by Kurt James Werner in
;;; http://dafx2019.bcu.ac.uk/papers/DAFx2019_paper_53.pdf

    IFDEF SPECTRUM
LOOPING equ 1

    include "equates.asm"

    org #8000

init_player
    di
    exx
    push hl
    push iy
    ld (_oldSP),sp
    ld sp,music_data
    ld bc,0
    jr _skip_sequence_pointer_update


_read_sequence
_sequence_pointer equ $+1
    ld sp,0
_skip_sequence_pointer_update
    pop hl
    ld a,h
    or l
IF LOOPING = 1
    jr nz,_continue
ELSE
    jp z,_exit_player
ENDIF
    pop hl                      ; fetch loop pointer
    ld sp,hl
    jr _skip_sequence_pointer_update

_continue
    ld (_sequence_pointer),sp
    ld (_pattern_pointer),hl


_read_pattern
    in a,(#fe)
    cpl
    and #1f
    jp nz,_exit_player

_pattern_pointer equ $+1
    ld sp,0
    pop af                      ; F = control bits, A = step length counter high
    jr z,_read_sequence

    jr c,_no_noise_update

    pop hl                      ; noise envelope pointer
    ld (_noise_env_ptr),hl

_no_noise_update
    jp pe,_no_ch1_update

    pop hl
    ld (_ch1_env_ptr),hl
    pop hl
    ld (_fdiv_ch1),hl
    ;; exx
    ;; pop bc                      ; BC' = channel 1 frequency divider
    ;; exx

_no_ch1_update
    jp m,_no_ch2_update

    pop hl
    ld (_ch2_env_ptr),hl
    pop hl                      ; store channel 2 frequency divider in mem
    ld (_fdiv_ch2),hl

_no_ch2_update
    pop af                      ; row length now in A
    jr z,_no_ch3_update

    pop hl
    ld (_ch3_env_ptr),hl
    pop hl
    ld (_fdiv_ch3),hl

_no_ch3_update
    jp m,kick_drum

_drum_return
    dec b                       ; adjust row length to account for loader delay
    dec b
    ld (_pattern_pointer),sp
    ld sp,0                     ; reset PRNG state
    jp _no_timer_update


_update_env
    ex af,af'                   ; update step length counter hi
    dec a
    jr z,_read_pattern

_no_timer_update
    ex af,af'

_noise_env_ptr equ $+1
    ld hl,0
    ld a,(hl)
    or a
    ;; ld (_noise_density),a
    ld c,a
    jr z,_no_noise_env_update

    inc hl
    ld (_noise_env_ptr),hl

_no_noise_env_update
_ch1_env_ptr equ $+1
    ld hl,0
    ld a,(hl)
    or a
    ld (_vol_ch1),a
    jr z,_no_ch1_env_update
    inc hl
    ld (_ch1_env_ptr),hl

_no_ch1_env_update
_ch2_env_ptr equ $+1
    ld hl,0
    ld a,(hl)
    or a
    ld (_vol_ch2),a
    jr z,_no_ch2_env_update
    inc hl
    ld (_ch2_env_ptr),hl

_no_ch2_env_update
_ch3_env_ptr equ $+1
    ld hl,0
    ld a,(hl)
    or a
    ld (_vol_ch3),a
    jr z,_play_note
    inc hl
    ld (_ch3_env_ptr),hl


_play_note
    ld a,e                      ; 4     update next pulse counter
    add a,c                     ; 4
    ld e,a                      ; 4
    jr nc,_wait                 ; 12/7  if counter hasn't expired, do nothing

    ld hl,#2175                 ; 10
    add hl,sp                   ; 11    and calculate next random number
    rlc h                       ; 8
    ld e,h                      ; 4
    ld sp,hl                    ; 6
    exx                         ; 4
    inc c                       ; 4 -- 54    raise output level

_wait_ret
_fdiv_ch1 equ $+1
    ld de,0                     ; 10
    add iy,de                   ; 15
    sbc a,a                     ; 4
_vol_ch1 equ $+1
    and 2                       ; 7
    add a,c                     ; 4
    ld c,a                      ; 4
_fdiv_ch2 equ $+1
    ld de,0                     ; 10
    add hl,de                   ; 11
    sbc a,a                     ; 4
_vol_ch2 equ $+1
    and 2                       ; 7
    add a,c                     ; 4
    ld c,a                      ; 4
_fdiv_ch3 equ $+1
    ld de,0                     ; 10
    add ix,de                   ; 15
    sbc a,a                     ; 4
_vol_ch3 equ $+1
    and 2                       ; 7
    add a,c                     ; 4
    jr z,_no_outp               ; 12/7

    dec a                       ; 4     if output level > 0, decrement it
    ld c,a                      ; 4
    ld a,#10                    ; 7     and switch beeper on
    out (#fe),a                 ; 11
    exx                         ; 4
    djnz _play_note             ; 13 -- 50 --- 240
    jp _update_env

_no_outp                        ; +12   if output level = 0
    ret nz                      ;  5    timing
    ret nz                      ;  5    timing
    out (#fe),a                 ; 11    switch beeper off
    exx                         ; 4
    djnz _play_note             ; 13 -- 47
    jp _update_env

_wait                           ; +12
    exx                         ; 4
    ds 7                        ; 28
    jp _wait_ret                ; 10 -- 54

_exit_player
_oldSP equ $+1
    ld sp,0
    pop iy
    pop hl
    exx
    ei
    ret

DRUM_RETURN_ADDRESS equ _drum_return
kick_drum
    include "kick.asm"

music_data
    include "music.asm"

    ELSE






;******************************************************************
; Ant's notes:
;  
; 3 tone channels + velvet noise, with volume envelopes. PDM mixing.
;
; REGISTER ALLOCATION (during _play_note inner loop):
;   Main set:  B = sample counter (rows), C = mixed output accumulator
;   Alt set:   B' = step counter (note duration), C' = noise density
;              E' = noise pulse counter, SP = PRNG state
;              IY = ch1 phase accumulator
;              HL'= ch2 phase accumulator
;              IX = ch3 phase accumulator

; Now targetting an 8 MHz MicroBeast (with sjasmplus).
;
; Other changes:
;
; 1) different output port for beeper
; 2) different bit (bit 3) in port for beeper
;    The kick drum PWM trick relies on RRCA to progressively clear the 
;    speaker bit (uses bits 1-4 on speccy) - on MicroBeast we'll need
; bits 3-5, so we'll add an SRL C in kick_drum_init
; 3) added delay in wait_ret to compensate for 8 Mhz vs old 3.5 MHz.
;    Speccy was 240T and we need 548.57T to keep the same sample rate
;    That's 77 NOPs, so we can'use DJNZ any more (DEC B:JP NZ instead)
; 4) attempt to keep drum timing accurate also @ 8Mhz
;    Speccy was 120T, we want 274T. Distribute padding in the common
;    output section (after AND C, before the OUT).
;
KB_PORT		EQU	0x00	; 0x0n, A[15:8] = 0xfe, 0xfd, 0xfb, 0xf7
AUDIO_PORT	EQU	0x24	; 16c550 MCR 
AUDIO_BIT	EQU	0x08	; bit 3

LOOPING EQU	1

        INCLUDE	"equates.asm"

        ORG	0x0100
        OUTPUT  "velvet.com"

; PLAYER INIT - save state and begin playback
init_player
        DI                              ; disable interrupts (we're taking over SP)
        EXX
        PUSH	HL                      ; save HL' and IY on the stack since the
        PUSH	IY                      ; player uses them as phase accumulators
        LD	(_oldSP), SP                ; save original SP so we can restore it
        LD	SP, music_data              ; point SP at the start of the music data
        LD	BC, 0                       ; B'=0 (step counter), C'=0 (noise density)
        JR	_skip_sequence_pointer_update


; SEQUENCE READER - walks the list of pattern pointers
; The sequence is a list of 16-bit pointers to patterns, terminated by 0.
; After the 0 terminator, a loop-back address follows.
_read_sequence
_sequence_pointer
        EQU	$+1                         ; self-mod: operand patched with current pos
        LD	SP, 0                       ; restore SP to current sequence position
_skip_sequence_pointer_update
        POP	HL                          ; read next pattern pointer from sequence
        LD	A, H
        OR	L                           ; is it 0 (end of sequence)?
IF      LOOPING	= 1
        JR	NZ, _continue               ; no: continue to this pattern
ELSE
        JP	Z, _exit_player             ; yes: stop playback
ENDIF
        POP	HL                          ; yes: fetch the loop-back address
        LD	SP, HL                      ; rewind SP to the loop point
        JR	_skip_sequence_pointer_update ; and re-read

_continue
        LD	(_sequence_pointer), SP     ; save sequence position (self-mod)
        LD	(_pattern_pointer), HL      ; save pattern data pointer (self-mod)


; PATTERN READER - decodes per-row control data
; Each row begins with a control word, followed by variable-length data.
; The low byte contains flag bits that indicate which fields follow.
; The high byte holds the step length counter (number of sample frames).
;
; Control byte 1 (flags in F register after POP AF):
;   bit 0 (C flag):  0 = noise envelope pointer follows, 1 = skip
;   bit 2 (P flag):  0 = ch1 envelope + freq follows,    1 = skip
;   bit 6 (Z flag):  1 = end of pattern (go to next in sequence)
;   bit 7 (S flag):  0 = ch2 envelope + freq follows,    1 = skip
;
; Control byte 2 (second POP AF):
;   bit 0 (C flag):  row length adjustment (half-speed)
;   bit 2 (P flag):  noise drum trigger
;   bit 6 (Z flag):  0 = ch3 envelope + freq follows,    1 = skip
;   bit 7 (S flag):  1 = kick drum, drum parameters follow on stack
_read_pattern
        IN	A, KB_PORT                  ; read keyboard port
        CPL                             ; invert (keys active-low)
        AND	0x1F                        ; mask key bits
        JP	NZ, _exit_player            ; any key pressed? exit playback

_pattern_pointer
        EQU	$+1                         ; self-mod: patched with current pattern pos
        LD	SP, 0                       ; point SP at current pattern position
        POP	AF                          ; F = control bits, A = step length high
        JR	Z, _read_sequence           ; Z set (bit 6) = end of pattern marker

        JR	C, _no_noise_update         ; C set (bit 0) = skip noise envelope update

        POP	HL                          ; read noise envelope pointer
        LD	(_noise_env_ptr), HL        ; patch it into the envelope reader (self-mod)

_no_noise_update
        JP	PE, _no_ch1_update          ; P/V set (bit 2) = skip ch1 update

        POP	HL
        LD	(_ch1_env_ptr), HL          ; patch ch1 volume envelope pointer
        POP	HL
        LD	(_fdiv_ch1), HL             ; patch ch1 frequency divider
    ;; exx
    ;; pop bc                           ; BC' = channel 1 frequency divider
    ;; exx

_no_ch1_update
        JP	M, _no_ch2_update           ; S set (bit 7) = skip ch2 update

        POP	HL
        LD	(_ch2_env_ptr), HL          ; patch ch2 volume envelope pointer
        POP	HL
        LD	(_fdiv_ch2), HL             ; patch ch2 frequency divider

_no_ch2_update
        POP	AF                          ; second control byte: A = row length
        JR	Z, _no_ch3_update           ; Z set (bit 6) = skip ch3 update

        POP	HL
        LD	(_ch3_env_ptr), HL          ; patch ch3 volume envelope pointer
        POP	HL
        LD	(_fdiv_ch3), HL             ; patch ch3 frequency divider

_no_ch3_update
        JP	M, kick_drum                ; S set (bit 7) = trigger kick drum

_drum_return
        DEC	B                           ; adjust row length to account for the
        DEC	B                           ; overhead of the pattern loader
        LD	(_pattern_pointer), SP      ; save pattern read position (self-mod)
        LD	SP, 0                       ; reset PRNG state for noise generator
        JP	_no_timer_update


; ENVELOPE UPDATER - runs once per row (every B'*256 samples)
; Each envelope is a byte array of volume values. A 0 value means "hold"
; (stop advancing the pointer). Non-zero values advance the read pointer
; by one each row, creating a volume shape over time.
_update_env
        EX	AF, AF'                     ; swap to get step length counter in A
        DEC	A                           ; decrement it
        JR	Z, _read_pattern            ; if zero, this note is done — read next row

_no_timer_update
        EX	AF, AF'                     ; swap back (A' = remaining step count)

    ;; --- Noise envelope ---
_noise_env_ptr
        EQU	$+1                         ; self-mod: noise envelope read position
        LD	HL, 0
        LD	A, (hl)                     ; read current noise density value
        OR	A
        LD	C, A                        ; C = noise density (used in _play_note)
        JR	Z, _no_noise_env_update     ; 0 = envelope finished, hold at 0

        INC	HL                          ; advance to next envelope entry
        LD	(_noise_env_ptr), HL

_no_noise_env_update
                                        ; --- Channel 1 volume envelope ---
_ch1_env_ptr
        EQU	$+1
        LD	HL, 0
        LD	A, (hl)
        OR	A
        LD	(_vol_ch1), A               ; patch ch1 volume into the AND mask (self-mod)
        JR	Z, _no_ch1_env_update
        INC	HL
        LD	(_ch1_env_ptr), HL

_no_ch1_env_update
                                        ; --- Channel 2 volume envelope ---
_ch2_env_ptr
        EQU	$+1
        LD	HL, 0
        LD	A, (hl)
        OR	A
        LD	(_vol_ch2), A               ; patch ch2 volume into the AND mask (self-mod)
        JR	Z, _no_ch2_env_update
        INC	HL
        LD	(_ch2_env_ptr), HL

_no_ch2_env_update
    ;; --- Channel 3 volume envelope ---
_ch3_env_ptr
        EQU	$+1
        LD	HL, 0
        LD	A, (hl)
        OR	A
        LD	(_vol_ch3), A               ; patch ch3 volume into the AND mask (self-mod)
        JR	Z, _play_note
        INC	HL
        LD	(_ch3_env_ptr), HL


; SAMPLE GENERATION LOOP - cycle-counted inner loop
; runs B (256) times per envelope tick and generates one beeper sample per iteration.
; Every code path through this loop takes exactly 240 T-states to maintain stable pitch.
;
; The mixing strategy: each channel contributes to the accumulator C.
; Noise adds +1, each tone channel adds its volume (0..8) when its phase
; accumulator overflows. If the total > 0, the beeper is switched ON;
; otherwise OFF. This is pulse-density modulation — louder sounds produce
; more ON samples per unit time.
_play_note
    ; --- Velvet noise channel ---
    ; E (in alt set) is a counter. Adding noise density C to it each sample
    ; causes it to overflow at a rate proportional to C. On overflow, we
    ; generate a new random pulse and bump the output level.
        LD	A, E                        ; 4     load noise pulse counter
        ADD	A, C                        ; 4     add noise density
        LD	E, A                        ; 4     store back
        JR	NC, _wait                   ; 12/7  no overflow? skip noise, go to timing pad

    ; Noise pulse triggered — run PRNG
    ; This is a quick-and-dirty linear congruential PRNG using SP itself.
    ; SP += #2175, then rotate the high byte for extra scrambling.
        LD	HL, 0x2175                  ; 10    PRNG increment constant
        ADD	HL, SP                      ; 11    advance PRNG state
        RLC	H                           ; 8     rotate high byte for better distribution
        LD	E, H                        ; 4     feed back into noise counter
        LD	SP, HL                      ; 6     store new PRNG state
        EXX                             ; 4     switch to main register set
        INC	C                           ; 4 -- 54    raise output level (noise contributes +1)

    ; --- Tone channel processing (main register set) ---
    ; Each channel: add frequency divider to phase accumulator. If it
    ; overflows (carry), the channel's square wave is in its "high" half.
    ; "sbc a,a" converts carry to #FF or #00, then AND with volume gives
    ; the channel's contribution, which is added to the mix accumulator C.
_wait_ret
_fdiv_ch1
        EQU	$+1                         ; self-mod: ch1 frequency divider
        LD	DE, 0                       ; 10
        ADD	IY, DE                      ; 15    advance ch1 phase accumulator
        SBC	A, A                        ; 4     A = #FF if overflow, #00 if not
_vol_ch1
        EQU	$+1                         ; self-mod: ch1 volume (patched by envelope)
        AND	2                           ; 7     mask with volume level
        ADD	A, C                        ; 4     add to mix accumulator
        LD	C, A                        ; 4

_fdiv_ch2
        EQU	$+1                         ; self-mod: ch2 frequency divider
        LD	DE, 0                       ; 10
        ADD	HL, DE                      ; 11    advance ch2 phase accumulator (HL')
        SBC	A, A                        ; 4
_vol_ch2
        EQU	$+1                         ; self-mod: ch2 volume
        AND	2                           ; 7
        ADD	A, C                        ; 4
        LD	C, A                        ; 4

_fdiv_ch3
        EQU	$+1                         ; self-mod: ch3 frequency divider
        LD	DE, 0                       ; 10
        ADD	IX, DE                      ; 15    advance ch3 phase accumulator
        SBC	A, A                        ; 4
_vol_ch3
        EQU	$+1                         ; self-mod: ch3 volume
        AND	2                           ; 7
        ADD	A, C                        ; 4     C now holds total mixed output level
        JR	Z, _no_outp                 ; 12/7  if zero, go to silence path

    ; --- Output ON path (50 T-states to end of loop) ---
        DEC	A                           ; 4     consume one "unit" of output level
        LD	C, A                        ; 4     store reduced level for next sample
        LD	A, AUDIO_BIT                ; 7     bit 3 = beeper ON
        OUT	AUDIO_PORT, A               ; 11    toggle speaker ON
        EXX                             ; 4     switch back to alt set for next iteration
        DJNZ	_play_note              ; 13 -- 50 --- 240 total T-states
        JP	_update_env

    ; --- Output OFF path (47 T-states + 3 padding = 50) ---
_no_outp                                ; +12   (jr z taken = 12, vs 7 not taken = +5 diff)
        RET	NZ                          ;  5    timing padding (condition never true:
        RET	NZ                          ;  5    SP is music data, not a return address)
        OUT	AUDIO_PORT, A               ; 11    A=0, so beeper OFF
        EXX                             ; 4     switch back to alt set
        DJNZ	_play_note              ; 13 -- 47 (+ 3 from jr z taken vs not = 50)
        JP	_update_env

    ; --- No-noise timing pad (54 T-states to match noise path) ---
_wait                                   ; +12   (jr nc taken = 12, vs 7 = +5)
        EXX                             ; 4     switch to main set (no noise contribution)
        DS	7                           ; 28    7 bytes of padding (7 × NOP = 28 T-states)
        JP	_wait_ret                   ; 10 -- 54 total (matches noise-active path)

; EXIT - restore machine state
_exit_player
_oldSP  EQU	$+1
        LD	SP, 0                       ; restore original stack pointer
        POP	IY                          ; restore saved registers
        POP	HL
        EXX
        EI                              ; re-enable interrupts
        RET

DRUM_RETURN_ADDRESS
        EQU	_drum_return
kick_drum
        INCLUDE	"kick.asm"

music_data
        INCLUDE	"music.asm"
    ENDIF
