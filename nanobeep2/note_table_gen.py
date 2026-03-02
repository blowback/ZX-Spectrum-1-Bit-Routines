#!/usr/bin/env python3
"""
Nanobeep2 Note Table Generator

Generates phase accumulator increment values for the nanobeep2 DDS beeper
engine. The engine adds an 8-bit increment E to a 16-bit phase accumulator
(HL) each loop iteration. The speaker is driven by a specific bit of H
(the high byte of the accumulator).

Frequency formula:
  f = E * f_cpu / (T_loop * 2^(bit + 9 + prescale))

Solving for E:
  E = round(f * T_loop * 2^(bit + 9 + prescale) / f_cpu)

Where:
  E           = phase accumulator increment (1-255)
  f_cpu       = CPU clock frequency in Hz
  T_loop      = sound loop period in T-states
  bit         = speaker bit position within output port byte
  prescale    = 0 (NOP), +1 (RRCA = octave down), -1 (RLCA = octave up)

The original Spectrum equates.h was calculated for:
  f_cpu=3500000, T_loop~87, bit=4, prescale=+1 (RRCA)
"""

import argparse
import math
import sys

NOTE_NAMES = ['C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-']

# For equates.h compatible output (German notation: sharp = "is")
EQU_NOTE_NAMES = ['c', 'cis', 'd', 'dis', 'e', 'f', 'fis', 'g', 'gis', 'a', 'ais', 'b']

# MIDI note 69 = A4 = 440 Hz
A4_MIDI = 69
A4_HZ = 440.0

PRESCALE_NAMES = {-1: 'RLCA', 0: 'NOP', 1: 'RRCA'}


def midi_to_hz(midi_note):
    """Convert MIDI note number to frequency in Hz."""
    return A4_HZ * (2 ** ((midi_note - A4_MIDI) / 12))


def note_name(midi_note):
    """Return human-readable note name from MIDI number."""
    octave = (midi_note // 12) - 1
    name = NOTE_NAMES[midi_note % 12]
    return f"{name}{octave}"


def equ_name(midi_note):
    """Return equates.h compatible name (e.g., 'cis3', 'a4')."""
    octave = (midi_note // 12) - 1
    name = EQU_NOTE_NAMES[midi_note % 12]
    return f"{name}{octave}"


def dds_divisor(t_loop, output_bit, prescale_shift):
    """Calculate the DDS frequency divisor.

    This is the constant D such that f = E * f_cpu / D.
    """
    effective_bit = output_bit + 8 + prescale_shift
    return (2 ** (effective_bit + 1)) * t_loop


def generate_table(f_cpu, t_loop, output_bit, prescale_shift,
                   start_octave, num_octaves):
    """Generate phase accumulator increment values for nanobeep2.

    Returns list of (midi_note, name, target_hz, e_value, actual_hz,
                      cents_error) tuples.
    """
    divisor = dds_divisor(t_loop, output_bit, prescale_shift)

    results = []

    for octave in range(start_octave, start_octave + num_octaves):
        for semitone in range(12):
            midi_note = (octave + 1) * 12 + semitone
            target_hz = midi_to_hz(midi_note)

            e_raw = (target_hz * divisor) / f_cpu
            e_value = round(e_raw)

            if e_value < 1:
                e_value = 1
            elif e_value > 255:
                e_value = 255

            actual_hz = (e_value * f_cpu) / divisor

            if actual_hz > 0 and target_hz > 0:
                cents_error = 1200 * math.log2(actual_hz / target_hz)
            else:
                cents_error = 0.0

            results.append((midi_note, note_name(midi_note), target_hz,
                          e_value, actual_hz, cents_error))

    return results


def print_table(results, format_style, f_cpu, t_loop, output_bit,
                prescale_shift):
    """Print the note table in the requested format."""

    divisor = dds_divisor(t_loop, output_bit, prescale_shift)
    effective_bit = output_bit + 8 + prescale_shift

    if format_style == 'human':
        print(f"{'Note':>4s}  {'Target Hz':>10s}  {'Value':>5s}  "
              f"{'Hex':>5s}  {'Actual Hz':>10s}  {'Error':>8s}  "
              f"{'Cents':>7s}")
        print("-" * 68)

        for midi, name, target, val, actual, cents in results:
            err_pct = ((actual - target) / target) * 100 if target > 0 else 0

            flag = ""
            if abs(cents) > 50:
                flag = " **"
            elif abs(cents) > 25:
                flag = " *"

            print(f"{name:>4s}  {target:10.2f}  {val:5d}  "
                  f"  ${val:02X}  {actual:10.2f}  "
                  f"{err_pct:+7.1f}%  {cents:+7.1f}{flag}")

            if name.startswith('B-'):
                print()

    elif format_style == 'equ':
        pname = PRESCALE_NAMES.get(prescale_shift, str(prescale_shift))
        print(f"; nanobeep2 note table")
        print(f"; f_cpu={f_cpu} Hz, T_loop={t_loop}, "
              f"bit={output_bit}, prescale={pname}")
        print(f"; f = E * {f_cpu} / {divisor} "
              f"(T_loop * 2^{effective_bit + 1})")
        print()
        print(f"rest\t equ #00")
        print(f"hhat\t equ #fe")
        print(f"ptnEnd\t equ #ff")

        for midi, name, target, val, actual, cents in results:
            if val < 1 or val > 253:
                continue
            ename = equ_name(midi)
            flag = "\t; *** POOR" if abs(cents) > 50 else ""
            print(f"{ename}\t equ #{val:02x}{flag}")

    elif format_style == 'asm':
        pname = PRESCALE_NAMES.get(prescale_shift, str(prescale_shift))
        print(f"; nanobeep2 note table")
        print(f"; f_cpu={f_cpu} Hz, T_loop={t_loop}, "
              f"bit={output_bit}, prescale={pname}")
        print()

        current_octave = None
        for midi, name, target, val, actual, cents in results:
            octave = (midi // 12) - 1
            if octave != current_octave:
                if current_octave is not None:
                    print()
                current_octave = octave
                print(f"; --- Octave {octave} ---")

            flag = "  ; *** POOR TUNING" if abs(cents) > 50 else ""
            print(f"    db ${val:02X}"
                  f"    ; {name} = {target:8.2f} Hz "
                  f"(actual {actual:.2f}, {cents:+.1f} cents){flag}")

    elif format_style == 'db':
        print("; Compact note table (frequency values only)")
        print()

        current_octave = None
        line_values = []

        for midi, name, target, val, actual, cents in results:
            octave = (midi // 12) - 1
            if octave != current_octave:
                if line_values:
                    print("    db " + ",".join(line_values))
                line_values = []
                current_octave = octave
                print(f"; Octave {octave}: {note_name(octave*12+12+12)}"
                      f" - {note_name(octave*12+12+23)}")

            line_values.append(f"${val:02X}")

        if line_values:
            print("    db " + ",".join(line_values))


def main():
    parser = argparse.ArgumentParser(
        description="Generate nanobeep2 DDS note frequency tables",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
Examples:
  # Microbeast (8 MHz, bit 3, 102T loop, no prescale):
  %(prog)s --clock 8000000 --bit 3 --t-loop 102

  # Same but with RRCA prescale (octave down):
  %(prog)s --clock 8000000 --bit 3 --t-loop 102 --prescale 1

  # Original Spectrum (3.5 MHz, bit 4, ~87T, RRCA):
  %(prog)s --clock 3500000 --bit 4 --t-loop 87 --prescale 1

  # Generate equates.h-compatible output:
  %(prog)s --clock 8000000 --bit 3 --t-loop 102 --format equ

  # Assembly output with error analysis:
  %(prog)s --clock 8000000 --bit 3 --t-loop 102 --format asm

Prescale values:
   0 = NOP  (no shift)
   1 = RRCA (octave down: effective bit += 1)
  -1 = RLCA (octave up:  effective bit -= 1)

Tuning quality indicators:
  *   = 25-50 cents error (noticeable)
  **  = >50 cents error (unusable for tonal music)

Formula:
  f = E * f_cpu / (T_loop * 2^(bit + 9 + prescale))
  E = round(f * T_loop * 2^(bit + 9 + prescale) / f_cpu)
""")

    parser.add_argument('--clock', type=int, default=8_000_000,
                        help='CPU clock in Hz (default: 8000000)')
    parser.add_argument('--t-loop', type=int, default=102,
                        help='Sound loop period in T-states (default: 102)')
    parser.add_argument('--bit', type=int, default=3,
                        help='Speaker bit position in output byte (default: 3)')
    parser.add_argument('--prescale', type=int, default=0, choices=[-1, 0, 1],
                        help='Prescale shift: 0=NOP, 1=RRCA, -1=RLCA (default: 0)')
    parser.add_argument('--start-octave', type=int, default=1,
                        help='Starting octave number (default: 1)')
    parser.add_argument('--num-octaves', type=int, default=5,
                        help='Number of octaves to generate (default: 5)')
    parser.add_argument('--format', choices=['human', 'equ', 'asm', 'db'],
                        default='human',
                        help='Output format (default: human)')

    args = parser.parse_args()

    effective_bit = args.bit + 8 + args.prescale
    divisor = dds_divisor(args.t_loop, args.bit, args.prescale)
    pname = PRESCALE_NAMES[args.prescale]

    if args.format == 'human':
        print("=" * 68)
        print("Nanobeep2 DDS Note Table")
        print("=" * 68)
        print(f"  Clock:          {args.clock:,} Hz")
        print(f"  T/loop:         {args.t_loop} T-states")
        print(f"  Output bit:     {args.bit} (bit {args.bit} of port byte)")
        print(f"  Prescale:       {pname} (shift={args.prescale:+d})")
        print(f"  Effective bit:  {effective_bit} of 16-bit accumulator "
              f"(bit {args.bit}{args.prescale:+d} of H)")
        print(f"  Divisor:        {divisor} "
              f"({args.t_loop} * 2^{effective_bit + 1})")
        print(f"  Max freq:       E=253 -> {253 * args.clock / divisor:.1f} Hz "
              f"(254/255 reserved)")
        print(f"  Min freq:       E=1   -> {args.clock / divisor:.1f} Hz")
        print()

    results = generate_table(args.clock, args.t_loop, args.bit,
                            args.prescale, args.start_octave,
                            args.num_octaves)
    print_table(results, args.format, args.clock, args.t_loop,
                args.bit, args.prescale)

    if args.format == 'human':
        usable = sum(1 for _, _, _, v, _, c in results
                     if abs(c) <= 50 and 1 <= v <= 253)
        total = len(results)
        print()
        print(f"Usable notes (<=50 cents, E in 1..253): {usable}/{total}")

        for _, name, _, val, _, cents in results:
            if abs(cents) <= 50 and 1 <= val <= 253:
                print(f"Lowest usable note: {name} (E={val})")
                break


if __name__ == '__main__':
    main()
