"""
========================================================================
  GENERATE STEREO v2 - Full Pipeline Audio Screening
========================================================================
  Alur:
  1. Baca file dari folder audio_ori/ (rekaman mentah, both channel)
  2. Normalisasi volume PER-KATA → simpan ke folder 03/ (ALL/Both)
  3. Dari folder 03/, buat stereo:
     - 01/: Suara di LEFT, Masking Noise di RIGHT
     - 02/: Suara di RIGHT, Masking Noise di LEFT

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
import array
from pydub import AudioSegment


# ============================================================
#  KONFIGURASI
# ============================================================
OUTPUT_BITRATE = "192k"
WINDOW_MS = 50

# Folder
SOURCE_FOLDER = "audio_ori"     # Rekaman asli (mentah)
FOLDER_03 = "03"                # Output: Both channel (normalized per-kata)
FOLDER_01 = "01"                # Output: Suara LEFT, Noise RIGHT
FOLDER_02 = "02"                # Output: Suara RIGHT, Noise LEFT

# Deteksi kata
DEFAULT_OFFSET_DB = 3.0
DEFAULT_MIN_WORD_MS = 250
DEFAULT_MAX_WORD_MS = 10000

def get_expected_words(filename):
    return 20 if "009" in filename else 21

# =============================================================
#  ENGINE: DETEKSI KATA
# =============================================================
def compute_rms_envelope(audio):
    samples = audio.get_array_of_samples()
    sr = audio.frame_rate
    sw = audio.sample_width
    max_val = float(2 ** (sw * 8 - 1))
    ws = int(sr * WINDOW_MS / 1000)
    if ws == 0:
        return []
    step = max(1, ws // 2)
    env = []
    for i in range(0, len(samples) - ws, step):
        chunk = samples[i:i + ws]
        if not chunk:
            continue
        sq = sum(float(s) ** 2 for s in chunk) / len(chunk)
        rms = math.sqrt(sq) if sq > 0 else 0.0001
        db = 20.0 * math.log10(rms / max_val) if rms > 0 else -120.0
        env.append(((i + ws / 2) * 1000.0 / sr, db))
    return env
def detect_words(audio_mono, expected_words=21):
    """Deteksi posisi kata dengan Threshold Absolut khusus file Normalisasi."""
    env = compute_rms_envelope(audio_mono)
    if not env:
        return []

    # Karena seluruh file dicap Peak -1.0 dBFS, suara bicara manusia PASTI memiliki
    # rata-rata RMS di atas -30 dBFS. Suara kosong/hampa akan berada di bawah -40 dBFS.
    thresh = -32.0

    is_sp = [d > thresh for _, d in env]
    
    segs = []
    in_sp = False
    start = 0
    for i, sp in enumerate(is_sp):
        t = env[i][0]
        if sp and not in_sp:
            start = t; in_sp = True
        elif not sp and in_sp:
            segs.append((start, t)); in_sp = False
    if in_sp: segs.append((start, env[-1][0]))

    segs = [(s, e) for s, e in segs if 200 <= (e - s) <= 10000]

    best_result = []
    best_diff = 9999

    for ms in range(250, 2001, 50):
        merged = []
        for seg in segs:
            if merged and (seg[0] - merged[-1][1]) < ms:
                merged[-1] = (merged[-1][0], seg[1])
            else:
                merged.append(seg)
        
        # Saring hasil akhir: buang dengungan panjang & tolak absolut anomali volume hening
        merged = [(int(s), int(e)) for s, e in merged if (e - s) <= 10000 and audio_mono[int(s):int(e)].dBFS > -35.0]
        
        diff = abs(len(merged) - expected_words)
        if diff < best_diff:
            best_diff = diff
            best_result = merged
            
        if diff == 0:
            return best_result

    return best_result


# =============================================================
#  ENGINE: PER-WORD NORMALIZATION
# =============================================================
def normalize_per_word(audio_mono, word_ranges):
    """
    Menyamakan volume setiap kata ke level KATA TERKERAS.
    Semua kata diangkat ke level maksimum agar lantang dan konsisten.
    Bagian antar-kata (noise/jeda) tidak diubah.
    """
    if not word_ranges:
        return audio_mono

    # Cari RMS kata terkeras (paling lantang)
    word_rms_list = []
    for start_ms, end_ms in word_ranges:
        seg = audio_mono[start_ms:end_ms]
        if seg.dBFS != float('-inf'):
            word_rms_list.append(seg.dBFS)

    if not word_rms_list:
        return audio_mono

    # Target = kata terkeras (bukan rata-rata!)
    target_rms = max(word_rms_list)

    # Rakit ulang
    result = AudioSegment.empty()
    prev_end = 0

    for i, (start_ms, end_ms) in enumerate(word_ranges):
        # Jeda sebelum kata → biarkan apa adanya
        if start_ms > prev_end:
            result += audio_mono[prev_end:start_ms]

        # Kata ini — normalisasi ke target RMS
        word = audio_mono[start_ms:end_ms]
        if word.dBFS != float('-inf'):
            gain_needed = target_rms - word.dBFS
            # Batasi gain agar tidak ekstrem, tapi beri ruang boost yang besar (+25.0 dB)
            gain_needed = max(-12.0, min(25.0, gain_needed))
            word = word.apply_gain(gain_needed)

        result += word
        prev_end = end_ms

    # Sisa audio setelah kata terakhir
    if prev_end < len(audio_mono):
        result += audio_mono[prev_end:]

    return result


# =============================================================
#  ENGINE: NOISE GENERATOR
# =============================================================
def generate_white_noise(duration_ms, sample_rate=44100, sample_width=2):
    num_samples = int(sample_rate * duration_ms / 1000)
    max_val = 2 ** (sample_width * 8 - 1) - 1
    noise_samples = array.array('h', [0] * num_samples)
    for i in range(num_samples):
        noise_samples[i] = random.randint(-max_val, max_val)
    return AudioSegment(
        data=noise_samples.tobytes(),
        sample_width=sample_width,
        frame_rate=sample_rate,
        channels=1
    )


def generate_pink_noise(duration_ms, sample_rate=44100, sample_width=2):
    num_samples = int(sample_rate * duration_ms / 1000)
    max_val = 2 ** (sample_width * 8 - 1) - 1
    num_rows = 16
    rows = [0.0] * num_rows
    running_sum = 0.0
    max_possible = num_rows + 1
    noise_samples = array.array('h', [0] * num_samples)
    for i in range(num_samples):
        index = 0
        n = i
        while n > 0 and index < num_rows:
            if n & 1:
                running_sum -= rows[index]
                rows[index] = random.uniform(-1.0, 1.0)
                running_sum += rows[index]
            n >>= 1
            index += 1
        white = random.uniform(-1.0, 1.0)
        value = max(-1.0, min(1.0, (running_sum + white) / max_possible))
        noise_samples[i] = int(value * max_val)
    return AudioSegment(
        data=noise_samples.tobytes(),
        sample_width=sample_width,
        frame_rate=sample_rate,
        channels=1
    )


def generate_speech_noise(speech_audio, duration_ms):
    if len(speech_audio) == 0:
        return generate_pink_noise(duration_ms, speech_audio.frame_rate)
    if speech_audio.channels > 1:
        speech_audio = speech_audio.set_channels(1)
    chunk_size_ms = 50
    chunks = []
    for i in range(0, len(speech_audio) - chunk_size_ms, chunk_size_ms):
        chunks.append(speech_audio[i:i + chunk_size_ms])
    if not chunks:
        return generate_pink_noise(duration_ms, speech_audio.frame_rate)
    random.seed(42)
    random.shuffle(chunks)
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


# =============================================================
#  ENGINE: STEREO BUILDER
# =============================================================
def build_stereo(speech_channel, noise_channel):
    if speech_channel.channels > 1:
        speech_channel = speech_channel.set_channels(1)
    if noise_channel.channels > 1:
        noise_channel = noise_channel.set_channels(1)

    target_rate = speech_channel.frame_rate
    target_width = speech_channel.sample_width
    noise_channel = noise_channel.set_frame_rate(target_rate)
    noise_channel = noise_channel.set_sample_width(target_width)

    # Sinkronisasi panjang di tingkat raw frame
    target_frames = int(speech_channel.frame_count())
    current_frames = int(noise_channel.frame_count())

    if current_frames > target_frames:
        target_bytes = target_frames * noise_channel.frame_width
        noise_channel = noise_channel._spawn(noise_channel.raw_data[:target_bytes])
    elif current_frames < target_frames:
        diff = target_frames - current_frames
        padding = b'\x00' * int(diff * noise_channel.frame_width)
        noise_channel = noise_channel._spawn(noise_channel.raw_data + padding)

    return AudioSegment.from_mono_audiosegments(speech_channel, noise_channel)


# =============================================================
#  INPUT PENGGUNA
# =============================================================
def print_banner():
    print("=" * 65)
    print("  GENERATE STEREO v2 - Full Pipeline Audio Screening")
    print("=" * 65)
    print()
    print("  Alur:")
    print("  audio_ori/ → 03/ (per-word normalized)")
    print("             → 01/ (L=Suara, R=Noise)")
    print("             → 02/ (L=Noise, R=Suara)")
    print()


def get_noise_input():
    print("[1/2] JENIS MASKING NOISE")
    print("   [1] Speech-Shaped Noise (REKOMENDASI)")
    print("   [2] Pink Noise")
    print("   [3] White Noise")
    noise_choice = input("   >> Pilih [1]: ").strip() or "1"
    noise_map = {"1": "speech", "2": "pink", "3": "white"}
    noise_type = noise_map.get(noise_choice, "speech")
    label = {"speech": "Speech-Shaped", "pink": "Pink", "white": "White"}
    print(f"   → {label[noise_type]} Noise")

    print()
    print("[2/2] LEVEL MASKING NOISE (dB relatif terhadap suara)")
    print("   0  = Sama keras dengan suara (sesuai file asli Anda)")
    print("   (File asli Anda menggunakan ~0 dB)")
    while True:
        try:
            val = float(input("   >> Level noise (dB) [0]: ").strip() or "0")
            if -60 <= val <= 10:
                break
            print("   [!] Nilai di luar rentang.")
        except ValueError:
            print("   [!] Masukkan angka.")
    return noise_type, val


# =============================================================
#  MAIN
# =============================================================
def main():
    print_banner()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_path = os.path.join(script_dir, SOURCE_FOLDER)

    if not os.path.isdir(source_path):
        print(f"  [ERROR] Folder '{SOURCE_FOLDER}/' tidak ditemukan!")
        print(f"          Letakkan file MP3 asli di: {source_path}")
        sys.exit(1)

    mp3_files = sorted(glob.glob(os.path.join(source_path, "*.mp3")))
    if not mp3_files:
        print(f"  [ERROR] Tidak ada file MP3 di '{SOURCE_FOLDER}/'!")
        sys.exit(1)

    print(f"  Sumber: {SOURCE_FOLDER}/ ({len(mp3_files)} file)")
    for f in mp3_files:
        print(f"    - {os.path.basename(f)}")
    print()

    noise_type, noise_level_db = get_noise_input()

    print()
    print("=" * 65)
    print("  RINGKASAN")
    print("=" * 65)
    print(f"  Sumber    : {SOURCE_FOLDER}/")
    print(f"  Hasil     : {FOLDER_03}/ (normalized per-kata)")
    print(f"              {FOLDER_01}/ (L=Suara, R=Noise)")
    print(f"              {FOLDER_02}/ (L=Noise, R=Suara)")
    print(f"  Noise     : {noise_type}, level {noise_level_db} dB")
    print("=" * 65)

    confirm = input("\n  Lanjutkan? (y/n): ").strip().lower()
    if confirm not in ("y", "yes", "ya"):
        print("  Dibatalkan.")
        sys.exit(0)

    # Buat folder output
    out_03 = os.path.join(script_dir, FOLDER_03)
    out_01 = os.path.join(script_dir, FOLDER_01)
    out_02 = os.path.join(script_dir, FOLDER_02)
    os.makedirs(out_03, exist_ok=True)
    os.makedirs(out_01, exist_ok=True)
    os.makedirs(out_02, exist_ok=True)

    # =========================================================
    #  TAHAP 1: audio_ori/ → 03/ (per-word normalization)
    # =========================================================
    print()
    print("=" * 65)
    print("  TAHAP 1: Normalisasi Volume Per-Kata")
    print(f"  {SOURCE_FOLDER}/ → {FOLDER_03}/")
    print("=" * 65)

    for mp3_file in mp3_files:
        fname = os.path.basename(mp3_file)
        print(f"\n  🎵 {fname}")

        try:
            audio = AudioSegment.from_mp3(mp3_file)
        except Exception as e:
            print(f"     [ERROR] {e}")
            continue

        mono = audio.set_channels(1)

        # Peak normalize file
        mono = mono.normalize(headroom=1.0)
        print(f"     Peak norm  : {mono.max_dBFS:.1f} dBFS")

        # Deteksi kata
        expected = get_expected_words(fname)
        words = detect_words(mono, expected)
        warning = "" if len(words) == expected else "⚠️"
        print(f"     Kata       : {len(words)} / {expected} target {warning}")

        if words:
            # Volume sebelum
            rms_before = [mono[s:e].dBFS for s, e in words if mono[s:e].dBFS != float('-inf')]
            if rms_before:
                spread_before = max(rms_before) - min(rms_before)
                print(f"     Vol awal   : {min(rms_before):.1f} ~ {max(rms_before):.1f} dBFS (spread {spread_before:.1f} dB)")

            # Normalisasi per-kata ke level TERKERAS
            mono = normalize_per_word(mono, words)

            # Volume sesudah
            rms_after = [mono[s:e].dBFS for s, e in words if mono[s:e].dBFS != float('-inf')]
            if rms_after:
                spread_after = max(rms_after) - min(rms_after)
                print(f"     Vol final  : {min(rms_after):.1f} ~ {max(rms_after):.1f} dBFS (spread {spread_after:.1f} dB) ✅")

        # Simpan ke folder 03/ (tetap mono → stereo both)
        stereo_both = AudioSegment.from_mono_audiosegments(mono, mono)
        out_path_03 = os.path.join(out_03, fname)
        stereo_both.export(out_path_03, format="mp3", bitrate=OUTPUT_BITRATE)
        print(f"     → {FOLDER_03}/{fname} ✅")

    # =========================================================
    #  TAHAP 2: 03/ → 01/ dan 02/ (stereo L/R + noise)
    # =========================================================
    print()
    print("=" * 65)
    print("  TAHAP 2: Generate Stereo L/R")
    print(f"  {FOLDER_03}/ → {FOLDER_01}/ + {FOLDER_02}/")
    print("=" * 65)

    # Baca file dari folder 03 yang baru dibuat
    files_03 = sorted(glob.glob(os.path.join(out_03, "*.mp3")))

    for mp3_file in files_03:
        fname = os.path.basename(mp3_file)
        print(f"\n  🎵 {fname}")

        try:
            audio = AudioSegment.from_mp3(mp3_file)
        except Exception as e:
            print(f"     [ERROR] {e}")
            continue

        mono = audio.set_channels(1)
        duration_ms = len(mono)

        # Generate noise
        print(f"     Generating {noise_type} noise...", end=" ", flush=True)
        if noise_type == "speech":
            raw_noise = generate_speech_noise(mono, duration_ms)
        elif noise_type == "pink":
            raw_noise = generate_pink_noise(duration_ms, mono.frame_rate, mono.sample_width)
        else:
            raw_noise = generate_white_noise(duration_ms, mono.frame_rate, mono.sample_width)
        print("OK")

        # Atur level noise
        target_noise = mono.dBFS + noise_level_db
        if raw_noise.dBFS != float('-inf'):
            noise = raw_noise.apply_gain(target_noise - raw_noise.dBFS)
        else:
            noise = raw_noise
        print(f"     Noise RMS  : {noise.dBFS:.1f} dBFS")

        # 01/: LEFT=Suara, RIGHT=Noise
        stereo_01 = build_stereo(mono, noise)
        path_01 = os.path.join(out_01, fname)
        stereo_01.export(path_01, format="mp3", bitrate=OUTPUT_BITRATE)
        print(f"     → {FOLDER_01}/{fname} (L=Suara, R=Noise) ✅")

        # 02/: LEFT=Noise, RIGHT=Suara
        stereo_02 = build_stereo(noise, mono)
        path_02 = os.path.join(out_02, fname)
        stereo_02.export(path_02, format="mp3", bitrate=OUTPUT_BITRATE)
        print(f"     → {FOLDER_02}/{fname} (L=Noise, R=Suara) ✅")

    print()
    print("=" * 65)
    print("  SELESAI!")
    print("=" * 65)
    print(f"  Output:")
    print(f"    → {out_03}  (Both, normalized per-kata)")
    print(f"    → {out_01}  (L=Suara, R=Noise)")
    print(f"    → {out_02}  (L=Noise, R=Suara)")
    print()
    print("  Langkah selanjutnya:")
    print("  → python standarisasi_audio.py  (atur interval kata)")
    print("=" * 65)


if __name__ == "__main__":
    main()
