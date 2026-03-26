"""
========================================================================
  STANDARISASI AUDIO v3 - Stereo-Aware Natural Splicer
========================================================================
  v3 Fitur Baru:
  1. STEREO CHANNEL DETECTION: Otomatis mendeteksi channel mana yang
     berisi suara kata (L/R/Both) agar tidak tercampur noise.
  2. AUTO-TUNING: Menyesuaikan min_silence secara otomatis sampai
     jumlah kata yang terdeteksi sesuai target (21 / 20 untuk file 009).
  3. ROOM TONE SPLICING: Jeda menggunakan noise asli rekaman.
  4. PEAK NORMALIZATION: Menyamakan volume semua file.
========================================================================
"""

import os
import sys
import glob
import math
from pydub import AudioSegment

# ============================================================
#  PARAMETER ENGINE
# ============================================================
OUTPUT_BITRATE = "192k"
WINDOW_MS = 50

# Deteksi
DEFAULT_OFFSET_DB = 3.0
DEFAULT_MIN_WORD_MS = 250
DEFAULT_MIN_SILENCE_MS = 800
DEFAULT_KEEP_SILENCE_MS = 300

# Target jumlah kata per file
EXPECTED_WORDS = 21
EXPECTED_WORDS_FILE_009 = 20

# Auto-tuning: rentang pencarian min_silence
TUNE_MIN_SILENCE_START = 400
TUNE_MIN_SILENCE_END = 2500
TUNE_SILENCE_STEP = 50


def print_banner():
    print("=" * 65)
    print("  STANDARISASI AUDIO v3 - Stereo-Aware Natural Splicer")
    print("  Untuk ESP32-S3 Lirik Player (Audio Screening Device)")
    print("=" * 65)
    print()


# ---------------------------------------------------------
#  ENGINE: STEREO CHANNEL DETECTION
# ---------------------------------------------------------
def split_channels(audio):
    """Memisahkan audio stereo menjadi channel kiri dan kanan."""
    if audio.channels == 1:
        return audio, audio  # mono = keduanya sama
    left = audio.split_to_mono()[0]
    right = audio.split_to_mono()[1]
    return left, right


def compute_channel_dynamics(channel_audio):
    """
    Menghitung 'dinamika' sebuah channel: seberapa besar variasi RMS-nya.
    Channel yang berisi suara kata akan memiliki variasi tinggi
    (diam -> keras -> diam). Channel noise murni variasinya rendah.
    """
    envelope = compute_rms_envelope(channel_audio)
    if not envelope:
        return 0.0
    dbfs_values = [dbfs for _, dbfs in envelope]
    dbfs_values.sort()
    # Dynamic range = perbedaan antara percentile 90 dan percentile 10
    low = dbfs_values[max(0, int(len(dbfs_values) * 0.10))]
    high = dbfs_values[min(len(dbfs_values) - 1, int(len(dbfs_values) * 0.90))]
    return high - low


def detect_speech_channel(audio):
    """
    Auto-detect channel mana yang berisi suara kata.
    Returns: 'left', 'right', atau 'both'
    """
    if audio.channels == 1:
        return 'both'

    left, right = split_channels(audio)
    left_dynamics = compute_channel_dynamics(left)
    right_dynamics = compute_channel_dynamics(right)

    # Jika keduanya memiliki dinamika tinggi (>= 60% dari yang tertinggi),
    # maka keduanya berisi suara (folder 03 / all)
    max_dynamics = max(left_dynamics, right_dynamics)
    if max_dynamics == 0:
        return 'both'

    left_ratio = left_dynamics / max_dynamics
    right_ratio = right_dynamics / max_dynamics

    if left_ratio >= 0.6 and right_ratio >= 0.6:
        return 'both'
    elif left_dynamics > right_dynamics:
        return 'left'
    else:
        return 'right'


# ---------------------------------------------------------
#  ENGINE: ENVELOPE & DETEKSI ADAPTIF
# ---------------------------------------------------------
def compute_rms_envelope(audio, window_ms=WINDOW_MS):
    samples = audio.get_array_of_samples()
    sample_rate = audio.frame_rate
    sample_width = audio.sample_width
    channels = audio.channels

    if channels == 2:
        mono = []
        for i in range(0, len(samples), 2):
            if i + 1 < len(samples):
                mono.append((samples[i] + samples[i + 1]) / 2.0)
        samples = mono
    else:
        samples = list(samples)

    max_val = float(2 ** (sample_width * 8 - 1))
    window_samples = int(sample_rate * window_ms / 1000)
    if window_samples == 0:
        return []

    envelope = []
    step = window_samples // 2
    if step == 0:
        step = 1
    for i in range(0, len(samples) - window_samples, step):
        chunk = samples[i:i + window_samples]
        if not chunk:
            continue
        sum_sq = sum(float(s) ** 2 for s in chunk) / len(chunk)
        rms = math.sqrt(sum_sq) if sum_sq > 0 else 0.0001
        rms_dbfs = 20.0 * math.log10(rms / max_val) if rms > 0 else -120.0
        center_ms = (i + window_samples / 2) * 1000.0 / sample_rate
        envelope.append((center_ms, rms_dbfs))
    return envelope


def estimate_noise_floor(envelope, percentile=10):
    if not envelope:
        return -60.0
    dbfs_values = sorted([dbfs for _, dbfs in envelope])
    idx = max(0, int(len(dbfs_values) * percentile / 100) - 1)
    return dbfs_values[idx]


def detect_words_adaptive(envelope, threshold_dbfs, min_word_ms, min_silence_ms):
    if not envelope:
        return []

    is_speech = [dbfs > threshold_dbfs for _, dbfs in envelope]
    segments = []
    in_speech = False
    seg_start = 0

    for i, speech in enumerate(is_speech):
        time_ms = envelope[i][0]
        if speech and not in_speech:
            seg_start = time_ms
            in_speech = True
        elif not speech and in_speech:
            segments.append((seg_start, time_ms))
            in_speech = False

    if in_speech:
        segments.append((seg_start, envelope[-1][0]))

    # Filter durasi minimum dan MAXIMUM kata (buang noise mic yang berkepanjangan)
    segments = [(s, e) for s, e in segments if (e - s) >= min_word_ms and (e - s) <= 4000]

    # Merge segmen yang jaraknya terlalu dekat
    merged = []
    for seg in segments:
        if merged and (seg[0] - merged[-1][1]) < min_silence_ms:
            merged[-1] = (merged[-1][0], seg[1])
        else:
            merged.append(seg)
    return merged


# ---------------------------------------------------------
#  ENGINE: AUTO-TUNING
# ---------------------------------------------------------
def auto_tune_detection(envelope, noise_floor, expected_words, filename):
    """
    Kecerdasan Buatan (Auto-Tuning 2 Dimensi):
    Mencari kombinasi Offset Threshold (Sensitivitas) & Durasi Jeda
    yang paling presisi untuk menemukan jumlah kata persis sesuai target.
    """
    best_result = None
    best_diff = 9999

    # Coba berbagai tingkat sensitivitas (dari sangat sensitif +2dB, sampai kebal +12dB)
    for offset_db in [2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0]:
        thresh = noise_floor + offset_db
        
        # Coba berbagai jeda pemisah kata (dari 300ms ke 1500ms)
        for ms in range(300, 1501, 100):
            words = detect_words_adaptive(envelope, thresh, DEFAULT_MIN_WORD_MS, ms)
            diff = abs(len(words) - expected_words)

            if diff < best_diff:
                best_diff = diff
                best_result = (ms, thresh, words)

            if diff == 0:
                print(f"      [Auto-Tune] Sukses! (Sensitivitas +{offset_db}dB, Jeda {ms}ms)")
                return best_result

    tuned_ms, best_thresh, tuned_words = best_result
    offset_used = best_thresh - noise_floor
    print(f"      [Auto-Tune] Mentok di Sensitivitas +{offset_used}dB, Jeda {tuned_ms}ms (Selisih {best_diff} kata)")
    return best_result


# ---------------------------------------------------------
#  ENGINE: ROOM TONE
# ---------------------------------------------------------
def extract_room_tone(audio, word_ranges):
    """Ekstrak noise background asli dari jeda terpanjang antar kata."""
    total_ms = len(audio)
    gaps = []

    if word_ranges and word_ranges[0][0] > 0:
        gaps.append((0, word_ranges[0][0]))

    for i in range(len(word_ranges) - 1):
        gaps.append((word_ranges[i][1], word_ranges[i + 1][0]))

    if word_ranges and word_ranges[-1][1] < total_ms:
        gaps.append((word_ranges[-1][1], total_ms))

    longest_gap = (0, 0)
    max_dur = 0
    for s, e in gaps:
        dur = e - s
        if dur > max_dur:
            max_dur = dur
            longest_gap = (s, e)

    s, e = longest_gap
    if max_dur > 500:
        safe_s = s + 200
        safe_e = e - 200
        if safe_e > safe_s:
            return audio[safe_s:safe_e]

    return AudioSegment.silent(duration=500, frame_rate=audio.frame_rate)


def generate_noise_filler(room_tone, duration_ms, crossfade=50):
    """Membuat blok background noise dengan durasi tertentu."""
    if duration_ms <= 0:
        return AudioSegment.empty()

    filler = AudioSegment.empty()
    while len(filler) < duration_ms:
        if len(filler) == 0:
            filler = room_tone
        else:
            chunk = room_tone
            if len(filler) >= crossfade and len(chunk) >= crossfade:
                filler = filler.append(chunk, crossfade=crossfade)
            else:
                filler += chunk

    return filler[:duration_ms]


# ---------------------------------------------------------
#  ALUR UTAMA
# ---------------------------------------------------------
def get_user_input():
    print("[1/2] DELAY ANTAR KATA")
    print("   Berapa detik jarak antar kata yang diinginkan?")
    print("   (Rekomendasi audiologi: 5-7 detik)")
    while True:
        try:
            val = float(input("   >> Delay antar kata (detik): ").strip())
            if val < 1:
                print("   [!] Minimal 1 detik.")
                continue
            break
        except ValueError:
            print("   [!] Masukkan angka.")
    delay_sec = val

    print()
    print("[2/2] DELAY AWAL (sebelum kata pertama)")
    while True:
        try:
            val = float(input("   >> Delay awal (detik): ").strip())
            if val < 0:
                print("   [!] Tidak boleh negatif.")
                continue
            break
        except ValueError:
            print("   [!] Masukkan angka.")
    initial_sec = val

    return delay_sec, initial_sec


def get_expected_words(filename):
    """Mengembalikan jumlah kata yang diharapkan untuk file tertentu."""
    basename = os.path.splitext(filename)[0]  # "009"
    if basename == "009":
        return EXPECTED_WORDS_FILE_009  # 20
    return EXPECTED_WORDS  # 21


def process_single_file(filepath, delay_ms, initial_delay_ms, output_path):
    filename = os.path.basename(filepath)
    expected = get_expected_words(filename)

    try:
        audio = AudioSegment.from_mp3(filepath)
    except Exception as e:
        print(f"      [ERROR] Gagal membaca {filename}: {e}")
        return False

    # 1. Normalisasi Volume
    audio = audio.normalize(headroom=1.0)

    # 2. Deteksi Channel Suara (Stereo-Aware)
    speech_channel_name = detect_speech_channel(audio)
    if speech_channel_name == 'left':
        analysis_audio = split_channels(audio)[0]
        ch_label = "LEFT"
    elif speech_channel_name == 'right':
        analysis_audio = split_channels(audio)[1]
        ch_label = "RIGHT"
    else:
        # Both atau mono → gunakan mono mix
        if audio.channels == 2:
            analysis_audio = audio.set_channels(1)
        else:
            analysis_audio = audio
        ch_label = "BOTH"

    print(f"      Channel suara  : {ch_label}")

    # 3. Analisa Envelope pada CHANNEL SUARA saja
    envelope = compute_rms_envelope(analysis_audio)
    noise_floor = estimate_noise_floor(envelope, 10)

    # 4. Auto-Tuning 2-Dimensi: Cari sensitivitas dan min_silence yang menghasilkan target
    tuned_ms, tuned_thresh, word_ranges = auto_tune_detection(envelope, noise_floor, expected, filename)
    num_words = len(word_ranges)

    status = "✅" if num_words == expected else "⚠️"
    print(f"      Auto-tuning    : min_silence={tuned_ms}ms")
    print(f"      Kata terdeteksi: {num_words} / {expected} target {status}")

    if num_words == 0:
        print(f"      [ERROR] Tidak ada kata terdeteksi! Lewati file ini.")
        return False

    if num_words != expected:
        print(f"      [WARNING] Jumlah kata tidak sesuai target!")
        print(f"                Akan tetap diproses dengan {num_words} kata.")

    # 5. Ekstrak Room Tone dari AUDIO ASLI (full stereo)
    room_tone = extract_room_tone(audio, word_ranges)

    # 6. Splicing: Rakit ulang dengan interval presisi
    output_audio = AudioSegment.empty()

    # Delay awal
    if initial_delay_ms > 0:
        output_audio += generate_noise_filler(room_tone, initial_delay_ms)

    for i, (start_ms, end_ms) in enumerate(word_ranges):
        # Ambil DARI AUDIO ASLI (stereo, sudah dinormalisasi)
        padded_start = max(0, start_ms - DEFAULT_KEEP_SILENCE_MS)
        padded_end = min(len(audio), end_ms + DEFAULT_KEEP_SILENCE_MS)
        chunk = audio[padded_start:padded_end]
        chunk_duration = len(chunk)

        if chunk_duration > delay_ms:
            print(f"         [!] Kata ke-{i+1}: {chunk_duration}ms > interval {delay_ms}ms")

        # Tambahkan kata
        output_audio += chunk

        # Isi sisa interval dengan room tone
        if i < num_words - 1:
            gap_needed = delay_ms - chunk_duration
            if gap_needed > 0:
                output_audio += generate_noise_filler(room_tone, gap_needed)

    # 7. Export
    try:
        output_audio.export(output_path, format="mp3", bitrate=OUTPUT_BITRATE)
        dur = len(output_audio) / 1000.0
        print(f"      -> Output: {output_path}")
        print(f"         Durasi: {dur:.1f}s | {num_words} kata | interval {delay_ms/1000:.1f}s")
        return True
    except Exception as e:
        print(f"      [ERROR] Gagal menyimpan: {e}")
        return False


def discover_audio_folders(base_dir):
    results = []
    for entry in sorted(os.listdir(base_dir)):
        folder_path = os.path.join(base_dir, entry)
        if os.path.isdir(folder_path) and entry not in ("output", "__pycache__", ".git"):
            mp3_files = sorted(glob.glob(os.path.join(folder_path, "*.mp3")))
            if mp3_files:
                results.append((folder_path, mp3_files))
    return results


def main():
    print_banner()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    audio_folders = discover_audio_folders(script_dir)

    if not audio_folders:
        print("[ERROR] Tidak ditemukan subfolder MP3!")
        sys.exit(1)

    total_files = 0
    for folder_path, mp3_files in audio_folders:
        folder_name = os.path.basename(folder_path)
        print(f"  [{folder_name}] -> {len(mp3_files)} file")
        total_files += len(mp3_files)
    print(f"  Total: {total_files} file")
    print("-" * 65)

    print()
    print("  Konfigurasi per file:")
    print(f"    - Target kata   : {EXPECTED_WORDS} kata (file 009: {EXPECTED_WORDS_FILE_009} kata)")
    print(f"    - Auto-tuning   : ON (otomatis cari parameter terbaik)")
    print(f"    - Stereo-aware  : ON (otomatis deteksi channel suara)")
    print(f"    - Normalisasi   : ON (semua file disamakan volumenya)")
    print(f"    - Room Tone     : ON (noise asli dipertahankan)")
    print()

    delay_sec, initial_sec = get_user_input()
    delay_ms = delay_sec * 1000
    initial_delay_ms = initial_sec * 1000

    output_base = os.path.join(script_dir, "output")
    os.makedirs(output_base, exist_ok=True)

    print()
    print("=" * 65)
    print("  MEMPROSES...")
    print("=" * 65)

    success = 0
    fail = 0
    warnings = 0

    for folder_path, mp3_files in audio_folders:
        folder_name = os.path.basename(folder_path)
        output_folder = os.path.join(output_base, folder_name)
        os.makedirs(output_folder, exist_ok=True)

        print(f"\n  📁 Folder: {folder_name}/")
        print(f"  {'-' * 55}")

        for mp3_file in mp3_files:
            mp3_filename = os.path.basename(mp3_file)
            output_filepath = os.path.join(output_folder, mp3_filename)
            expected = get_expected_words(mp3_filename)

            print(f"\n    🎵 {mp3_filename} (target: {expected} kata)")

            ok = process_single_file(mp3_file, delay_ms, initial_delay_ms, output_filepath)
            if ok:
                success += 1
            else:
                fail += 1

    print()
    print("=" * 65)
    print(f"  SELESAI!")
    print(f"  Berhasil: {success}  |  Gagal: {fail}")
    print(f"  Output : {output_base}")
    print("=" * 65)


if __name__ == "__main__":
    main()