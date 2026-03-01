#!/usr/bin/env python3
"""
Z80 Beeper Engine Note Table Generator

Generates 8-bit frequency values for use in pulse-interleaving beeper engines
with 8-bit phase accumulators. Outputs 12 semitones × 8 octaves with tuning
error analysis.

The inner loop timing model:
  T_loop = (T_channel × num_channels) + T_timer + (T_djnz × num_channels)

where T_djnz = 13 × (hold_value - 1) + 8  (the DJNZ $ spin loop)
"""

import argparse
import sys

NOTE_NAMES = ['C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-']

# MIDI note 69 = A4 = 440 Hz
A4_MIDI = 69
A4_HZ = 440.0


def midi_to_hz(midi_note):
    """Convert MIDI note number to frequency in Hz."""
    return A4_HZ * (2 ** ((midi_note - A4_MIDI) / 12))


def note_name(midi_note):
    """Return human-readable note name from MIDI number."""
    octave = (midi_note // 12) - 1
    name = NOTE_NAMES[midi_note % 12]
    return f"{name}{octave}"


def djnz_tstates(hold_value):
    """Calculate T-states consumed by DJNZ $ with given B value.
    
    DJNZ takes 13 T per iteration, 8 T on the final iteration.
    With B=N: (N-1)*13 + 8 = 13N - 5 T-states.
    Special case: B=0 means 256 iterations.
    """
    if hold_value == 0:
        n = 256
    else:
        n = hold_value
    return 13 * (n - 1) + 8


def calculate_loop_timing(clock_hz, num_channels, hold_value,
                          t_channel, t_timer):
    """Calculate total loop T-states and sample rate.
    
    Args:
        clock_hz: CPU clock frequency in Hz
        num_channels: number of interleaved channels
        hold_value: the B value used in DJNZ $ pulse hold
        t_channel: T-states per channel excluding DJNZ
        t_timer: T-states for the timer/loop control section
    
    Returns:
        (t_loop, sample_rate) tuple
    """
    t_hold = djnz_tstates(hold_value)
    t_loop = (t_channel + t_hold) * num_channels + t_timer
    sample_rate = clock_hz / t_loop
    return t_loop, sample_rate


def generate_table(clock_hz, sample_rate, start_octave, num_octaves):
    """Generate frequency values and error analysis for all notes.
    
    Returns list of (midi_note, name, target_hz, freq_value, actual_hz, 
                      cents_error) tuples.
    """
    results = []
    
    for octave in range(start_octave, start_octave + num_octaves):
        for semitone in range(12):
            midi_note = (octave + 1) * 12 + semitone
            target_hz = midi_to_hz(midi_note)
            
            # freq_value = round(target_hz * 256 / sample_rate)
            freq_raw = (target_hz * 256) / sample_rate
            freq_value = round(freq_raw)
            
            # Clamp to valid 8-bit range
            if freq_value < 1:
                freq_value = 1
            elif freq_value > 255:
                freq_value = 255
            
            # Calculate actual frequency produced
            actual_hz = (freq_value * sample_rate) / 256
            
            # Error in cents: 1200 * log2(actual/target)
            if actual_hz > 0 and target_hz > 0:
                import math
                cents_error = 1200 * math.log2(actual_hz / target_hz)
            else:
                cents_error = 0.0
            
            results.append((midi_note, note_name(midi_note), target_hz,
                          freq_value, actual_hz, cents_error))
    
    return results


def print_table(results, sample_rate, format_style='human'):
    """Print the note table in the requested format."""
    
    if format_style == 'human':
        print(f"{'Note':>4s}  {'Target Hz':>10s}  {'Value':>5s}  "
              f"{'Hex':>5s}  {'Actual Hz':>10s}  {'Error':>8s}  "
              f"{'Cents':>7s}")
        print("-" * 68)
        
        for midi, name, target, val, actual, cents in results:
            err_pct = ((actual - target) / target) * 100 if target > 0 else 0
            
            # Flag unusable notes
            flag = ""
            if abs(cents) > 50:     # more than a quarter-tone out
                flag = " **"
            elif abs(cents) > 25:   # more than an eighth-tone
                flag = " *"
            
            print(f"{name:>4s}  {target:10.2f}  {val:5d}  "
                  f"  ${val:02X}  {actual:10.2f}  "
                  f"{err_pct:+7.1f}%  {cents:+7.1f}{flag}")
            
            # Visual separator between octaves
            if name.startswith('B-'):
                print()
    
    elif format_style == 'asm':
        print("; Note frequency table for 8-bit phase accumulator engine")
        print(f"; Sample rate: {sample_rate:.1f} Hz")
        print(f"; freq_value = round(note_hz * 256 / {sample_rate:.1f})")
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
        print(f"; Sample rate: {sample_rate:.1f} Hz")
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
        description="Generate Z80 beeper engine note frequency tables",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
Examples:
  # NanoBeep-style 2ch engine at 8 MHz with DJNZ hold of $48 (72):
  %(prog)s --clock 8000000 --channels 2 --hold 72

  # 3-channel engine with shorter hold, assembly output:
  %(prog)s --clock 8000000 --channels 3 --hold 48 --format asm

  # Spectrum-compatible (3.5 MHz, hold=$30):
  %(prog)s --clock 3500000 --channels 2 --hold 48

  # Custom channel timing:
  %(prog)s --clock 8000000 --channels 2 --hold 72 --t-channel 38

  # Output just the db lines for inclusion in source:
  %(prog)s --clock 8000000 --channels 2 --hold 72 --format db

Tuning quality indicators:
  *   = 25-50 cents error (noticeable)
  **  = >50 cents error (unusable for tonal music)

Timing model:
  T_loop = (T_channel + T_djnz) × num_channels + T_timer
  T_djnz = 13 × (hold - 1) + 8
  sample_rate = clock / T_loop
  freq_value = round(note_hz × 256 / sample_rate)
""")
    
    parser.add_argument('--clock', type=int, default=8_000_000,
                        help='CPU clock in Hz (default: 8000000)')
    parser.add_argument('--channels', type=int, default=2,
                        help='Number of channels (default: 2)')
    parser.add_argument('--hold', type=int, default=72,
                        help='DJNZ hold value / B register (default: 72 = $48)')
    parser.add_argument('--t-channel', type=int, default=38,
                        help='T-states per channel excluding DJNZ (default: 38)')
    parser.add_argument('--t-timer', type=int, default=34,
                        help='T-states for timer/loop section (default: 34)')
    parser.add_argument('--start-octave', type=int, default=1,
                        help='Starting octave number (default: 1)')
    parser.add_argument('--num-octaves', type=int, default=8,
                        help='Number of octaves to generate (default: 8)')
    parser.add_argument('--format', choices=['human', 'asm', 'db'],
                        default='human',
                        help='Output format (default: human)')
    parser.add_argument('--t-loop', type=int, default=None,
                        help='Override total loop T-states directly '
                             '(bypasses calculation from components)')
    
    args = parser.parse_args()
    
    # Calculate or use override for loop timing
    if args.t_loop is not None:
        t_loop = args.t_loop
        sample_rate = args.clock / t_loop
    else:
        t_loop, sample_rate = calculate_loop_timing(
            args.clock, args.channels, args.hold,
            args.t_channel, args.t_timer
        )
    
    t_hold = djnz_tstates(args.hold)
    
    # Print header info
    if args.format == 'human':
        print("=" * 68)
        print("Z80 Beeper Engine Note Table")
        print("=" * 68)
        print(f"  Clock:        {args.clock:,} Hz")
        print(f"  Channels:     {args.channels}")
        print(f"  DJNZ hold:    {args.hold} (${args.hold:02X})"
              f"  = {t_hold} T-states"
              f"  = {t_hold/args.clock*1e6:.1f} µs")
        print(f"  T/channel:    {args.t_channel} T (excl. DJNZ)")
        print(f"  T/timer:      {args.t_timer} T")
        if args.t_loop is not None:
            print(f"  T/loop:       {t_loop} T (manual override)")
        else:
            print(f"  T/loop:       {t_loop} T (calculated)")
        print(f"  Sample rate:  {sample_rate:,.1f} Hz")
        print(f"  Nyquist:      {sample_rate/2:,.1f} Hz")
        print(f"  Max note:     freq_value=255 → {255*sample_rate/256:.1f} Hz")
        print(f"  Min note:     freq_value=1   → {sample_rate/256:.1f} Hz")
        print()
    
    # Generate and print
    results = generate_table(args.clock, sample_rate, args.start_octave,
                            args.num_octaves)
    print_table(results, sample_rate, args.format)
    
    # Print summary
    if args.format == 'human':
        usable = sum(1 for _, _, _, _, _, c in results if abs(c) <= 50)
        total = len(results)
        print()
        print(f"Usable notes (≤50 cents error): {usable}/{total}")
        
        # Find the lowest usable note
        for _, name, _, val, _, cents in results:
            if abs(cents) <= 50:
                print(f"Lowest usable note: {name} (freq_value={val})")
                break


if __name__ == '__main__':
    main()
