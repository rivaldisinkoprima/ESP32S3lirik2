"""
========================================================================
  GENERATE STEREO - Pembuat Audio Stereo L/R untuk Audiologi
========================================================================
  Script ini mengambil file audio dari folder 03/ (mode ALL/Both)
  dan secara otomatis membuat:
  - Folder 01/: Suara di LEFT, Masking Noise di RIGHT
  - Folder 02/: Suara di RIGHT, Masking Noise di LEFT

  Noise yang digunakan adalah Narrowband Noise yang di-generate
  secara konsisten dan presisi agar hasil tes pendengaran valid.

  Cara penggunaan:
  > cd audio
  > python generate_stereo.py
========================================================================
"""

import os
import sys
import glob
import math
import random
import struct
import array
from pydub import AudioSegment


# ============================================================
#  KONFIGURASI
# ============================================================
OUTPUT_BITRATE = "192k"

# Folder sumber dan target
SOURCE_FOLDER = "03"
TARGET_LEFT_FOLDER = "01"   # Suara di LEFT
TARGET_RIGHT_FOLDER = "02"  # Suara di RIGHT


def print_banner():
    print("=" * 65)
    print("  GENERATE STEREO - Audiological L/R Channel Generator")
    print("  Menghasilkan folder 01/ dan 02/ dari folder 03/")
    print("=" * 65)
    print()
    print("  Folder 03/ (ALL)  →  01/ (Suara LEFT,  Noise RIGHT)")
    print("                    →  02/ (Suara RIGHT, Noise LEFT)")
    print()


# ---------------------------------------------------------
#  ENGINE: NOISE GENERATOR
# ---------------------------------------------------------
def generate_white_noise(duration_ms, sample_rate=44100, sample_width=2):
    """Generate white noise AudioSegment."""
    num_samples = int(sample_rate * duration_ms / 1000)
    max_val = 2 ** (sample_width * 8 - 1) - 1

    # Generate random samples
    noise_samples = array.array('h', [0] * num_samples)
    for i in range(num_samples):
        noise_samples[i] = random.randint(-max_val, max_val)

    # Buat AudioSegment dari array byte
    noise = AudioSegment(
        data=noise_samples.tobytes(),
        sample_width=sample_width,
        frame_rate=sample_rate,
        channels=1
    )
    return noise


def generate_pink_noise(duration_ms, sample_rate=44100, sample_width=2):
    """
    Generate pink noise (1/f noise) menggunakan Voss-McCartney algorithm.
    Pink noise lebih alami untuk audiologi dibanding white noise
    karena energi per oktaf-nya merata.
    """
    num_samples = int(sample_rate * duration_ms / 1000)
    max_val = 2 ** (sample_width * 8 - 1) - 1

    # Voss-McCartney: menggunakan beberapa sumber noise berjalan
    num_rows = 16
    rows = [0.0] * num_rows
    running_sum = 0.0
    max_possible = num_rows + 1  # Normalisasi

    noise_samples = array.array('h', [0] * num_samples)

    for i in range(num_samples):
        # Tentukan baris mana yang perlu di-update (berdasarkan bit)
        # Ini menciptakan distribusi frekuensi 1/f
        index = 0
        n = i
        while n > 0 and index < num_rows:
            if n & 1:
                running_sum -= rows[index]
                rows[index] = random.uniform(-1.0, 1.0)
                running_sum += rows[index]
            n >>= 1
            index += 1

        # Tambahkan white noise layer untuk high frequency
        white = random.uniform(-1.0, 1.0)
        value = (running_sum + white) / max_possible

        # Clamp dan konversi ke integer
        value = max(-1.0, min(1.0, value))
        noise_samples[i] = int(value * max_val)

    noise = AudioSegment(
        data=noise_samples.tobytes(),
        sample_width=sample_width,
        frame_rate=sample_rate,
        channels=1
    )
    return noise


def generate_speech_noise(speech_audio, duration_ms):
    """
    Generate Speech-Shaped Noise.
    Ini adalah noise yang shape spektrumnya mengikuti profil
    frekuensi dari suara bicara asli. Paling akurat untuk audiologi
    karena masking-nya merata di seluruh rentang frekuensi bicara.

    Cara: Mengambil audio suara asli, memotong-motong dan me-shuffle
    secara acak sehingga menjadi tidak bisa dikenali kata-katanya,
    tapi profil frekuensinya tetap identik.
    """
    if len(speech_audio) == 0:
        return generate_pink_noise(duration_ms, speech_audio.frame_rate)

    # Pastikan mono
    if speech_audio.channels > 1:
        speech_audio = speech_audio.set_channels(1)

    # Potong-potong audio menjadi chunks kecil (~30-80ms)
    chunk_size_ms = 50
    chunks = []
    for i in range(0, len(speech_audio) - chunk_size_ms, chunk_size_ms):
        chunks.append(speech_audio[i:i + chunk_size_ms])

    if not chunks:
        return generate_pink_noise(duration_ms, speech_audio.frame_rate)

    # Shuffle chunks secara acak
    random.seed(42)  # Seed tetap untuk konsistensi antar file
    random.shuffle(chunks)

    # Rakit ulang sampai memenuhi durasi yang dibutuhkan
    noise = AudioSegment.empty()
    idx = 0
    crossfade_ms = 10

    while len(noise) < duration_ms:
        chunk = chunks[idx % len(chunks)]
        if len(noise) == 0:
            noise = chunk
        elif len(noise) >= crossfade_ms and len(chunk) >= crossfade_ms:
            noise = noise.append(chunk, crossfade=crossfade_ms)
        else:
            noise += chunk
        idx += 1

    return noise[:duration_ms]


# ---------------------------------------------------------
#  ENGINE: STEREO BUILDER
# ---------------------------------------------------------
def build_stereo(speech_channel, noise_channel):
    """
    Menggabungkan dua channel mono menjadi satu file stereo.
    """
    # Pastikan keduanya mono
    if speech_channel.channels > 1:
        speech_channel = speech_channel.set_channels(1)
    if noise_channel.channels > 1:
        noise_channel = noise_channel.set_channels(1)

    # Samakan sample rate dan sample width
    target_rate = speech_channel.frame_rate
    target_width = speech_channel.sample_width

    noise_channel = noise_channel.set_frame_rate(target_rate)
    noise_channel = noise_channel.set_sample_width(target_width)

    # Samakan panjang pada tingkat sampel murni (raw binary data)
    # Ini menjamin jumlah selisih byte sama persis tanpa ada error pembulatan MS
    target_frames = int(speech_channel.frame_count())
    current_frames = int(noise_channel.frame_count())

    if current_frames > target_frames:
        # Pangkas di tingkat byte data (raw binary)
        target_bytes = target_frames * noise_channel.frame_width
        noise_data = noise_channel.raw_data[:target_bytes]
        noise_channel = noise_channel._spawn(noise_data)
    elif current_frames < target_frames:
        # Tambahkan silence digital (zero bytes) untuk menambah kepanjangan
        diff_frames = target_frames - current_frames
        padding = b'\x00' * int(diff_frames * noise_channel.frame_width)
        noise_channel = noise_channel._spawn(noise_channel.raw_data + padding)

    # Gabungkan menjadi stereo
    stereo = AudioSegment.from_mono_audiosegments(speech_channel, noise_channel)
    return stereo


# ---------------------------------------------------------
#  ALUR UTAMA
# ---------------------------------------------------------
def get_user_input():
    """Meminta konfigurasi dari pengguna."""

    # Jenis noise
    print("[1/2] JENIS MASKING NOISE")
    print("   [1] Speech-Shaped Noise (REKOMENDASI untuk audiologi)")
    print("       → Profil frekuensi mengikuti suara bicara asli")
    print("       → Masking paling akurat dan natural")
    print()
    print("   [2] Pink Noise (1/f noise)")
    print("       → Energi sama per oktaf, terdengar natural")
    print()
    print("   [3] White Noise")
    print("       → Energi sama di semua frekuensi, terdengar 'tajam'")
    print()
    noise_choice = input("   >> Pilih jenis noise [1]: ").strip() or "1"

    noise_type_map = {"1": "speech", "2": "pink", "3": "white"}
    noise_type = noise_type_map.get(noise_choice, "speech")
    noise_label = {"speech": "Speech-Shaped", "pink": "Pink", "white": "White"}

    print(f"   → Dipilih: {noise_label[noise_type]} Noise")

    # Level noise
    print()
    print("[2/2] LEVEL MASKING NOISE (dB relatif terhadap suara)")
    print("   0  = Noise sama keras dengan suara (sesuai file asli Anda)")
    print("   -5 = Noise 5 dB lebih pelan dari suara")
    print("   -10 = Noise 10 dB lebih pelan (terdengar latar)")
    print("   -20 = Noise 20 dB lebih pelan (hampir tidak terdengar)")
    print("   (File asli Anda menggunakan ~0 dB)")
    while True:
        try:
            level_input = input("   >> Level noise (dB) [0]: ").strip() or "0"
            noise_level_db = float(level_input)
            if noise_level_db > 10:
                print("   [!] Terlalu keras. Maksimal +10 dB.")
                continue
            if noise_level_db < -60:
                print("   [!] Terlalu pelan. Minimal -60 dB.")
                continue
            break
        except ValueError:
            print("   [!] Masukkan angka.")

    print(f"   → Level: {noise_level_db} dB relatif terhadap suara")
    return noise_type, noise_level_db


def main():
    print_banner()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_path = os.path.join(script_dir, SOURCE_FOLDER)

    # Cek folder sumber
    if not os.path.isdir(source_path):
        print(f"  [ERROR] Folder sumber '{SOURCE_FOLDER}/' tidak ditemukan!")
        print(f"          Path: {source_path}")
        sys.exit(1)

    mp3_files = sorted(glob.glob(os.path.join(source_path, "*.mp3")))
    if not mp3_files:
        print(f"  [ERROR] Tidak ada file MP3 di folder '{SOURCE_FOLDER}/'!")
        sys.exit(1)

    print(f"  Folder sumber: {SOURCE_FOLDER}/ ({len(mp3_files)} file)")
    for f in mp3_files:
        print(f"    - {os.path.basename(f)}")
    print()

    # Input pengguna
    noise_type, noise_level_db = get_user_input()

    # Ringkasan
    print()
    print("=" * 65)
    print("  RINGKASAN")
    print("=" * 65)
    print(f"  Sumber          : {SOURCE_FOLDER}/")
    print(f"  Target          : {TARGET_LEFT_FOLDER}/ (L=Suara, R=Noise)")
    print(f"                    {TARGET_RIGHT_FOLDER}/ (L=Noise, R=Suara)")
    print(f"  Jenis Noise     : {noise_type}")
    print(f"  Level Noise     : {noise_level_db} dB")
    print(f"  File diproses   : {len(mp3_files)}")
    print("=" * 65)

    confirm = input("\n  Lanjutkan? (y/n): ").strip().lower()
    if confirm not in ("y", "yes", "ya"):
        print("  Dibatalkan.")
        sys.exit(0)

    # Buat folder output
    out_left = os.path.join(script_dir, TARGET_LEFT_FOLDER)
    out_right = os.path.join(script_dir, TARGET_RIGHT_FOLDER)
    os.makedirs(out_left, exist_ok=True)
    os.makedirs(out_right, exist_ok=True)

    print()
    print("=" * 65)
    print("  MEMPROSES...")
    print("=" * 65)

    success = 0
    fail = 0

    for mp3_file in mp3_files:
        fname = os.path.basename(mp3_file)
        print(f"\n  🎵 {fname}")

        try:
            audio = AudioSegment.from_mp3(mp3_file)
        except Exception as e:
            print(f"     [ERROR] Gagal membaca: {e}")
            fail += 1
            continue

        # Konversi ke mono (karena folder 03 kedua channel sama)
        mono = audio.set_channels(1)
        duration_ms = len(mono)

        print(f"     Durasi     : {duration_ms/1000:.1f}s")
        print(f"     RMS        : {mono.dBFS:.1f} dBFS")

        # Generate noise sesuai pilihan
        print(f"     Generating {noise_type} noise...", end=" ", flush=True)
        if noise_type == "speech":
            raw_noise = generate_speech_noise(mono, duration_ms)
        elif noise_type == "pink":
            raw_noise = generate_pink_noise(duration_ms, mono.frame_rate, mono.sample_width)
        else:
            raw_noise = generate_white_noise(duration_ms, mono.frame_rate, mono.sample_width)
        print("OK")

        # Atur level noise relatif terhadap suara
        # Target: noise_rms = speech_rms + noise_level_db
        target_noise_dbfs = mono.dBFS + noise_level_db
        current_noise_dbfs = raw_noise.dBFS
        if current_noise_dbfs != float('-inf'):
            adjustment = target_noise_dbfs - current_noise_dbfs
            noise = raw_noise.apply_gain(adjustment)
        else:
            noise = raw_noise

        print(f"     Noise RMS  : {noise.dBFS:.1f} dBFS (target: {target_noise_dbfs:.1f})")

        # Bangun stereo untuk folder 01 (LEFT = suara, RIGHT = noise)
        stereo_left = build_stereo(mono, noise)
        out_path_left = os.path.join(out_left, fname)

        try:
            stereo_left.export(out_path_left, format="mp3", bitrate=OUTPUT_BITRATE)
            print(f"     → {TARGET_LEFT_FOLDER}/{fname}  (L=Suara, R=Noise) ✅")
        except Exception as e:
            print(f"     [ERROR] Gagal menyimpan {TARGET_LEFT_FOLDER}/{fname}: {e}")
            fail += 1
            continue

        # Bangun stereo untuk folder 02 (LEFT = noise, RIGHT = suara)
        stereo_right = build_stereo(noise, mono)
        out_path_right = os.path.join(out_right, fname)

        try:
            stereo_right.export(out_path_right, format="mp3", bitrate=OUTPUT_BITRATE)
            print(f"     → {TARGET_RIGHT_FOLDER}/{fname}  (L=Noise, R=Suara) ✅")
        except Exception as e:
            print(f"     [ERROR] Gagal menyimpan {TARGET_RIGHT_FOLDER}/{fname}: {e}")
            fail += 1
            continue

        success += 1

    print()
    print("=" * 65)
    print(f"  SELESAI!")
    print(f"  Berhasil: {success} file  |  Gagal: {fail} file")
    print(f"  Output:")
    print(f"    → {out_left}")
    print(f"    → {out_right}")
    print()
    print("  Alur selanjutnya:")
    print("  1. Jalankan standarisasi_audio.py untuk mengatur interval kata")
    print("  2. Salin folder output/ ke SD Card DFPlayer")
    print("=" * 65)


if __name__ == "__main__":
    main()
