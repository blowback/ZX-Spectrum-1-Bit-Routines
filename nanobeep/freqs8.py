clk = 3_500_000  # Spectrum
clk = 8_000_000  # microbeast
tstates = 1351  # utz's original nanobeep
sample_rate = clk / tstates

# output_freq = sample_rate / (2 * counter_value)
#    *2 becausse we need 2 half periods (HIGH and LOW) per cycle
# counter_value = sample_rate / (2 * desired_hz)
for octave in range(2, 8):
    for semitone in range(12):
        midi_note = (octave + 1) * 12 + semitone  # C2 = MIDI 36
        hz = 440.0 * (2 ** ((midi_note - 69) / 12))
        freq_value = 
        freq_value = round(hz * 65536 / sample_rate)
        print(f"  dw {freq_value:5d}  ; {hz:8.2f} Hz")
