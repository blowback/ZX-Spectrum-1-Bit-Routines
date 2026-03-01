clk = 3_500_000  # Spectrum
clk = 8_000_000  # microbeast
tstates = 1351  # utz's original nanobeep
sample_rate = clk / tstates

for octave in range(2, 8):
    for semitone in range(12):
        midi_note = (octave + 1) * 12 + semitone  # C2 = MIDI 36
        hz = 440.0 * (2 ** ((midi_note - 69) / 12))
        freq_value = round(hz * 65536 / sample_rate)
        print(f"  dw {freq_value:5d}  ; {hz:8.2f} Hz")
