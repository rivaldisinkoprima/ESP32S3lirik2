=================================================================
  GENERATE STEREO v2 - Full Pipeline Audio Screening
=================================================================

  Alur:
  audio_ori/ → 03/ (per-word normalized)
             → 01/ (L=Suara, R=Noise)
             → 02/ (L=Noise, R=Suara)

  Sumber: audio_ori/ (10 file)
    - 001.mp3
    - 002.mp3
    - 003.mp3
    - 004.mp3
    - 005.mp3
    - 006.mp3
    - 007.mp3
    - 008.mp3
    - 009.mp3
    - 010.mp3

[1/2] JENIS MASKING NOISE
   [1] Speech-Shaped Noise (REKOMENDASI)
   [2] Pink Noise
   [3] White Noise
   >> Pilih [1]: 1
   → Speech-Shaped Noise

[2/2] LEVEL MASKING NOISE (dB relatif terhadap suara)
   0  = Sama keras dengan suara (sesuai file asli Anda)
   (File asli Anda menggunakan ~0 dB)
   >> Level noise (dB) [0]:

=================================================================
  RINGKASAN
=================================================================
  Sumber    : audio_ori/
  Hasil     : 03/ (normalized per-kata)
              01/ (L=Suara, R=Noise)
              02/ (L=Noise, R=Suara)
  Noise     : speech, level 0.0 dB
=================================================================

  Lanjutkan? (y/n): y

=================================================================
  TAHAP 1: Normalisasi Volume Per-Kata
  audio_ori/ → 03/
=================================================================

  🎵 001.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 21 / 21 target
     Vol awal   : -16.9 ~ -13.5 dBFS (spread 3.5 dB)
     Vol final  : -13.6 ~ -13.5 dBFS (spread 0.1 dB) ✅
     → 03/001.mp3 ✅

  🎵 002.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 21 / 21 target
     Vol awal   : -19.3 ~ -12.0 dBFS (spread 7.3 dB)
     Vol final  : -12.1 ~ -12.0 dBFS (spread 0.1 dB) ✅
     → 03/002.mp3 ✅

  🎵 003.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 21 / 21 target
     Vol awal   : -21.3 ~ -11.8 dBFS (spread 9.5 dB)
     Vol final  : -12.1 ~ -11.8 dBFS (spread 0.3 dB) ✅
     → 03/003.mp3 ✅

  🎵 004.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 21 / 21 target
     Vol awal   : -20.1 ~ -13.3 dBFS (spread 6.8 dB)
     Vol final  : -13.4 ~ -13.3 dBFS (spread 0.1 dB) ✅
     → 03/004.mp3 ✅

  🎵 005.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 21 / 21 target
     Vol awal   : -19.8 ~ -13.2 dBFS (spread 6.5 dB)
     Vol final  : -13.4 ~ -13.2 dBFS (spread 0.2 dB) ✅
     → 03/005.mp3 ✅

  🎵 006.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 19 / 21 target ⚠️
     Vol awal   : -19.4 ~ -11.6 dBFS (spread 7.8 dB)
     Vol final  : -11.7 ~ -11.6 dBFS (spread 0.1 dB) ✅
     → 03/006.mp3 ✅

  🎵 007.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 21 / 21 target
     Vol awal   : -17.1 ~ -11.4 dBFS (spread 5.7 dB)
     Vol final  : -11.6 ~ -11.4 dBFS (spread 0.2 dB) ✅
     → 03/007.mp3 ✅

  🎵 008.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 21 / 21 target
     Vol awal   : -19.0 ~ -12.2 dBFS (spread 6.8 dB)
     Vol final  : -12.4 ~ -12.2 dBFS (spread 0.1 dB) ✅
     → 03/008.mp3 ✅

  🎵 009.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 20 / 20 target
     Vol awal   : -18.8 ~ -11.8 dBFS (spread 7.0 dB)
     Vol final  : -11.8 ~ -11.8 dBFS (spread 0.1 dB) ✅
     → 03/009.mp3 ✅

  🎵 010.mp3
     Peak norm  : -1.0 dBFS
     Kata       : 21 / 21 target
     Vol awal   : -19.6 ~ -12.9 dBFS (spread 6.7 dB)
     Vol final  : -13.0 ~ -12.9 dBFS (spread 0.0 dB) ✅
     → 03/010.mp3 ✅

=================================================================
  TAHAP 2: Generate Stereo L/R
  03/ → 01/ + 02/
=================================================================

  🎵 001.mp3
     Generating speech noise... OK
     Noise RMS  : -24.2 dBFS
     → 01/001.mp3 (L=Suara, R=Noise) ✅
     → 02/001.mp3 (L=Noise, R=Suara) ✅

  🎵 002.mp3
     Generating speech noise... OK
     Noise RMS  : -22.3 dBFS
     → 01/002.mp3 (L=Suara, R=Noise) ✅
     → 02/002.mp3 (L=Noise, R=Suara) ✅

  🎵 003.mp3
     Generating speech noise... OK
     Noise RMS  : -22.8 dBFS
     → 01/003.mp3 (L=Suara, R=Noise) ✅
     → 02/003.mp3 (L=Noise, R=Suara) ✅

  🎵 004.mp3
     Generating speech noise... OK
     Noise RMS  : -24.2 dBFS
     → 01/004.mp3 (L=Suara, R=Noise) ✅
     → 02/004.mp3 (L=Noise, R=Suara) ✅

  🎵 005.mp3
     Generating speech noise... OK
     Noise RMS  : -24.2 dBFS
     → 01/005.mp3 (L=Suara, R=Noise) ✅
     → 02/005.mp3 (L=Noise, R=Suara) ✅

  🎵 006.mp3
     Generating speech noise... OK
     Noise RMS  : -23.2 dBFS
     → 01/006.mp3 (L=Suara, R=Noise) ✅
     → 02/006.mp3 (L=Noise, R=Suara) ✅

  🎵 007.mp3
     Generating speech noise... OK
     Noise RMS  : -22.5 dBFS
     → 01/007.mp3 (L=Suara, R=Noise) ✅
     → 02/007.mp3 (L=Noise, R=Suara) ✅

  🎵 008.mp3
     Generating speech noise... OK
     Noise RMS  : -23.4 dBFS
     → 01/008.mp3 (L=Suara, R=Noise) ✅
     → 02/008.mp3 (L=Noise, R=Suara) ✅

  🎵 009.mp3
     Generating speech noise... OK
     Noise RMS  : -23.0 dBFS
     → 01/009.mp3 (L=Suara, R=Noise) ✅
     → 02/009.mp3 (L=Noise, R=Suara) ✅

  🎵 010.mp3
     Generating speech noise... OK
     Noise RMS  : -24.4 dBFS
     → 01/010.mp3 (L=Suara, R=Noise) ✅
     → 02/010.mp3 (L=Noise, R=Suara) ✅

=================================================================
  SELESAI!
=================================================================
  Output:
    → F:\val\audio\try2\03  (Both, normalized per-kata)
    → F:\val\audio\try2\01  (L=Suara, R=Noise)
    → F:\val\audio\try2\02  (L=Noise, R=Suara)

  Langkah selanjutnya:
  → python standarisasi_audio.py  (atur interval kata)
=================================================================