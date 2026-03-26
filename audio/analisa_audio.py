"""
========================================================================
  ANALISA AUDIO v2 - Debug Tool untuk Audio Screening
========================================================================
  Script ini menganalisa file-file audio MP3 dan menampilkan informasi
  detil tentang setiap kata/segmen suara yang terdeteksi.

  v2: Menggunakan ADAPTIVE THRESHOLD berdasarkan noise floor asli
      rekaman, bukan threshold absolut yang fixed.

  Cara penggunaan:
  > cd audio
  > python analisa_audio.py
========================================================================
"""

import os
import sys
import glob
import math
import struct
from pydub import AudioSegment


# ============================================================
#  KONFIGURASI DEFAULT
# ============================================================

# Ukuran window untuk analisa energi (ms)
WINDOW_MS = 50

# Offset dB di atas noise floor untuk threshold adaptive
# Semakin kecil = semakin sensitif (lebih banyak terdeteksi)
# Semakin besar = hanya kata yang jelas yang terdeteksi
DEFAULT_OFFSET_DB = 3.0

# Durasi minimum non-silence agar dianggap sebagai kata (ms)
# Mencegah klik/pop pendek terdeteksi sebagai kata
DEFAULT_MIN_WORD_MS = 200

# Durasi minimum silence agar dianggap sebagai jeda antar kata (ms)
DEFAULT_MIN_SILENCE_MS = 300

# Padding (ms) ditambahkan sebelum & sesudah kata
DEFAULT_KEEP_SILENCE_MS = 200


def print_banner():
    print("=" * 70)
    print("  ANALISA AUDIO v2 - Adaptive Threshold Debug Tool")
    print("  Untuk ESP32-S3 Lirik Player (Audio Screening Device)")
    print("=" * 70)
    print()


def compute_rms_envelope(audio, window_ms=WINDOW_MS):
    """
    Menghitung RMS envelope dari audio dalam window kecil.
    Mengembalikan list of (center_time_ms, rms_dbfs) tuples.
    """
    samples = audio.get_array_of_samples()
    sample_rate = audio.frame_rate
    channels = audio.channels
    sample_width = audio.sample_width

    # Jika stereo, ambil rata-rata per frame
    if channels == 2:
        mono_samples = []
        for i in range(0, len(samples), 2):
            if i + 1 < len(samples):
                mono_samples.append((samples[i] + samples[i + 1]) / 2.0)
        samples = mono_samples
    else:
        samples = list(samples)

    max_val = float(2 ** (sample_width * 8 - 1))
    window_samples = int(sample_rate * window_ms / 1000)

    envelope = []
    for i in range(0, len(samples) - window_samples, window_samples // 2):
        chunk = samples[i:i + window_samples]
        if len(chunk) == 0:
            continue
        # RMS
        sum_sq = sum(float(s) ** 2 for s in chunk) / len(chunk)
        rms = math.sqrt(sum_sq) if sum_sq > 0 else 0.0001
        rms_dbfs = 20.0 * math.log10(rms / max_val) if rms > 0 else -120.0
        center_ms = (i + window_samples / 2) * 1000.0 / sample_rate
        envelope.append((center_ms, rms_dbfs))

    return envelope


def estimate_noise_floor(envelope, percentile=10):
    """
    Estimasi noise floor menggunakan percentile rendah dari envelope.
    percentile=10 berarti ambil 10% segmen paling pelan sebagai noise.
    """
    if not envelope:
        return -60.0
    dbfs_values = sorted([dbfs for _, dbfs in envelope])
    idx = max(0, int(len(dbfs_values) * percentile / 100) - 1)
    return dbfs_values[idx]


def estimate_speech_level(envelope, percentile=80):
    """
    Estimasi level suara bicara menggunakan percentile tinggi dari envelope.
    """
    if not envelope:
        return -20.0
    dbfs_values = sorted([dbfs for _, dbfs in envelope])
    idx = min(len(dbfs_values) - 1, int(len(dbfs_values) * percentile / 100))
    return dbfs_values[idx]


def detect_words_adaptive(envelope, threshold_dbfs, min_word_ms, min_silence_ms, window_ms=WINDOW_MS):
    """
    Deteksi kata menggunakan energi envelope dan adaptive threshold.
    Mengembalikan list of (start_ms, end_ms) tuples.
    """
    if not envelope:
        return []

    step_ms = window_ms / 2  # karena kita overlap 50%

    # Label setiap window sebagai speech/silence
    is_speech = [dbfs > threshold_dbfs for _, dbfs in envelope]

    # Cari contiguous speech segments
    segments = []
    in_speech = False
    seg_start = 0

    for i, speech in enumerate(is_speech):
        time_ms = envelope[i][0]
        if speech and not in_speech:
            seg_start = time_ms
            in_speech = True
        elif not speech and in_speech:
            seg_end = time_ms
            segments.append((seg_start, seg_end))
            in_speech = False

    # Tangani jika speech sampai akhir file
    if in_speech:
        segments.append((seg_start, envelope[-1][0]))

    # Filter: buang segmen yang terlalu pendek (bukan kata, mungkin klik/pop)
    segments = [(s, e) for s, e in segments if (e - s) >= min_word_ms]

    # Merge: gabungkan segmen yang jaraknya terlalu dekat (bagian dari kata yang sama)
    merged = []
    for seg in segments:
        if merged and (seg[0] - merged[-1][1]) < min_silence_ms:
            # Gabungkan dengan segmen sebelumnya
            merged[-1] = (merged[-1][0], seg[1])
        else:
            merged.append(seg)

    return merged


def discover_audio_folders(base_dir):
    """Mencari semua subfolder yang berisi file MP3."""
    results = []
    for entry in sorted(os.listdir(base_dir)):
        folder_path = os.path.join(base_dir, entry)
        if os.path.isdir(folder_path) and entry not in ("output", "__pycache__", ".git"):
            mp3_files = sorted(glob.glob(os.path.join(folder_path, "*.mp3")))
            if mp3_files:
                results.append((folder_path, mp3_files))
    return results


def draw_timeline(total_ms, word_ranges, width=60):
    """Visualisasi timeline: █ = Suara, · = Silence"""
    timeline = ['·'] * width
    for start_ms, end_ms in word_ranges:
        start_pos = int((start_ms / total_ms) * width)
        end_pos = int((end_ms / total_ms) * width)
        start_pos = max(0, min(start_pos, width - 1))
        end_pos = max(0, min(end_pos, width - 1))
        for p in range(start_pos, end_pos + 1):
            timeline[p] = '█'
    return ''.join(timeline)


def get_user_input():
    """Meminta parameter dari pengguna."""

    print("[1/3] OFFSET dB DI ATAS NOISE FLOOR")
    print("   Berapa dB di atas noise floor agar dianggap sebagai suara?")
    print("   Semakin kecil = semakin sensitif")
    print(f"   (Default: {DEFAULT_OFFSET_DB} dB, Rekomendasi: 2-5 dB)")
    offset_input = input(f"   >> Offset [{DEFAULT_OFFSET_DB} dB]: ").strip()
    if offset_input == "":
        offset_db = DEFAULT_OFFSET_DB
    else:
        try:
            offset_db = float(offset_input)
        except ValueError:
            offset_db = DEFAULT_OFFSET_DB

    print()
    print("[2/3] DURASI MINIMUM KATA (ms)")
    print("   Segmen suara lebih pendek dari ini akan diabaikan (bukan kata)")
    print(f"   (Default: {DEFAULT_MIN_WORD_MS}ms)")
    min_word_input = input(f"   >> Min kata [{DEFAULT_MIN_WORD_MS}ms]: ").strip()
    if min_word_input == "":
        min_word_ms = DEFAULT_MIN_WORD_MS
    else:
        try:
            min_word_ms = int(min_word_input)
        except ValueError:
            min_word_ms = DEFAULT_MIN_WORD_MS

    print()
    print("[3/3] DURASI MINIMUM JEDA ANTAR KATA (ms)")
    print("   Jeda lebih pendek dari ini akan dianggap masih kata yang sama")
    print(f"   (Default: {DEFAULT_MIN_SILENCE_MS}ms)")
    min_sil_input = input(f"   >> Min jeda [{DEFAULT_MIN_SILENCE_MS}ms]: ").strip()
    if min_sil_input == "":
        min_silence_ms = DEFAULT_MIN_SILENCE_MS
    else:
        try:
            min_silence_ms = int(min_sil_input)
        except ValueError:
            min_silence_ms = DEFAULT_MIN_SILENCE_MS

    return offset_db, min_word_ms, min_silence_ms


def analyze_single_file(filepath, offset_db, min_word_ms, min_silence_ms):
    """Menganalisa satu file MP3 menggunakan adaptive threshold."""
    filename = os.path.basename(filepath)

    try:
        audio = AudioSegment.from_mp3(filepath)
    except Exception as e:
        print(f"      [ERROR] Gagal membaca {filename}: {e}")
        return None

    total_ms = len(audio)
    total_sec = total_ms / 1000.0

    # Amplitudo asli
    peak_dbfs = audio.max_dBFS
    rms_dbfs = audio.dBFS

    # Hitung envelope energi
    envelope = compute_rms_envelope(audio, WINDOW_MS)

    # Estimasi noise floor dan speech level secara otomatis
    noise_floor = estimate_noise_floor(envelope, percentile=10)
    speech_level = estimate_speech_level(envelope, percentile=85)

    # Hitung threshold adaptive
    adaptive_thresh = noise_floor + offset_db

    # SNR (Signal-to-Noise Ratio)
    snr = speech_level - noise_floor

    # Deteksi kata menggunakan envelope + adaptive threshold
    word_ranges = detect_words_adaptive(
        envelope, adaptive_thresh, min_word_ms, min_silence_ms, WINDOW_MS
    )

    num_words = len(word_ranges)

    # Detail setiap kata
    word_details = []
    for i, (start_ms, end_ms) in enumerate(word_ranges):
        duration_ms = end_ms - start_ms
        padded_start = max(0, start_ms - DEFAULT_KEEP_SILENCE_MS)
        padded_end = min(total_ms, end_ms + DEFAULT_KEEP_SILENCE_MS)
        padded_duration_ms = padded_end - padded_start

        if i < len(word_ranges) - 1:
            gap_ms = word_ranges[i + 1][0] - end_ms
        else:
            gap_ms = total_ms - end_ms

        word_details.append({
            'index': i + 1,
            'start_ms': start_ms,
            'end_ms': end_ms,
            'duration_ms': duration_ms,
            'padded_start': padded_start,
            'padded_end': padded_end,
            'padded_duration_ms': padded_duration_ms,
            'gap_after_ms': gap_ms,
        })

    return {
        'filename': filename,
        'total_ms': total_ms,
        'total_sec': total_sec,
        'peak_dbfs': peak_dbfs,
        'rms_dbfs': rms_dbfs,
        'noise_floor': noise_floor,
        'speech_level': speech_level,
        'snr': snr,
        'adaptive_thresh': adaptive_thresh,
        'num_words': num_words,
        'word_ranges': word_ranges,
        'word_details': word_details,
    }


def print_file_analysis(data):
    """Mencetak hasil analisa detail satu file."""
    print(f"\n    {'=' * 62}")
    print(f"    🎵 {data['filename']}")
    print(f"    {'=' * 62}")

    print(f"    Durasi total     : {data['total_sec']:.2f} detik ({data['total_ms']} ms)")
    print(f"    Kata terdeteksi  : {data['num_words']} segmen")
    print()

    print(f"    --- Amplitudo ---")
    print(f"    Peak Amplitude   : {data['peak_dbfs']:.2f} dBFS")
    print(f"    RMS Amplitude    : {data['rms_dbfs']:.2f} dBFS")
    print()
    print(f"    --- Deteksi Otomatis ---")
    print(f"    Noise Floor      : {data['noise_floor']:.2f} dBFS  (otomatis)")
    print(f"    Speech Level     : {data['speech_level']:.2f} dBFS  (otomatis)")
    print(f"    SNR              : {data['snr']:.1f} dB")
    print(f"    Threshold        : {data['adaptive_thresh']:.2f} dBFS  (noise + offset)")
    print()

    if data['snr'] < 3:
        print(f"    ⚠️  SNR SANGAT RENDAH ({data['snr']:.1f} dB)!")
        print(f"        Suara bicara hampir sama kerasnya dengan noise.")
        print(f"        Deteksi mungkin tidak akurat.")
        print()

    # Timeline
    timeline = draw_timeline(data['total_ms'], data['word_ranges'])
    print(f"    Timeline: |{timeline}|")
    print(f"              0s{' ' * 25}{data['total_sec']:.0f}s")
    print(f"              █ = Suara   · = Jeda")
    print()

    # Tabel detail kata
    if data['word_details']:
        print(f"    {'No':<4} {'Mulai':>8} {'Selesai':>9} {'Durasi':>8} {'+Padding':>10} {'Jeda Stlh':>10}")
        print(f"    {'--':<4} {'------':>8} {'-------':>9} {'------':>8} {'--------':>10} {'---------':>10}")
        for w in data['word_details']:
            start_s = w['start_ms'] / 1000.0
            end_s = w['end_ms'] / 1000.0
            dur_s = w['duration_ms'] / 1000.0
            padded_s = w['padded_duration_ms'] / 1000.0
            gap_s = w['gap_after_ms'] / 1000.0

            flag = ""
            if w['duration_ms'] < 150:
                flag = " ⚠️ SANGAT PENDEK"
            elif w['duration_ms'] > 3000:
                flag = " ⚠️ TERLALU PANJANG"
            elif w['gap_after_ms'] < 200 and w['index'] < data['num_words']:
                flag = " ⚠️ JEDA SEMPIT"

            print(f"    {w['index']:<4} {start_s:>7.2f}s {end_s:>8.2f}s {dur_s:>7.2f}s {padded_s:>9.2f}s {gap_s:>9.2f}s{flag}")

        durations = [w['duration_ms'] for w in data['word_details']]
        gaps = [w['gap_after_ms'] for w in data['word_details'][:-1]]

        print()
        print(f"    --- Statistik Durasi Kata ---")
        print(f"    Terpendek : {min(durations)}ms ({min(durations)/1000:.2f}s)")
        print(f"    Terpanjang: {max(durations)}ms ({max(durations)/1000:.2f}s)")
        print(f"    Rata-rata : {sum(durations)/len(durations):.0f}ms ({sum(durations)/len(durations)/1000:.2f}s)")

        if gaps:
            print()
            print(f"    --- Statistik Jeda Antar Kata ---")
            print(f"    Terpendek : {min(gaps):.0f}ms ({min(gaps)/1000:.2f}s)")
            print(f"    Terpanjang: {max(gaps):.0f}ms ({max(gaps)/1000:.2f}s)")
            print(f"    Rata-rata : {sum(gaps)/len(gaps):.0f}ms ({sum(gaps)/len(gaps)/1000:.2f}s)")
    else:
        print(f"    [!] TIDAK ADA KATA TERDETEKSI!")
        print(f"        Coba kurangi offset dB (lebih sensitif).")


def main():
    print_banner()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    audio_folders = discover_audio_folders(script_dir)

    if not audio_folders:
        print("[ERROR] Tidak ditemukan subfolder berisi file MP3!")
        sys.exit(1)

    total_files = 0
    for folder_path, mp3_files in audio_folders:
        folder_name = os.path.basename(folder_path)
        print(f"  [{folder_name}] -> {len(mp3_files)} file MP3")
        total_files += len(mp3_files)
    print(f"\n  Total: {len(audio_folders)} folder, {total_files} file MP3")
    print("-" * 70)

    # Pilihan mode
    print()
    print("  Pilihan mode analisa:")
    print("  [1] Analisa SEMUA file (ringkasan)")
    print("  [2] Analisa SATU file tertentu (detail)")
    print("  [3] Analisa SATU FOLDER tertentu (detail)")
    mode_input = input("  >> Pilih mode [1]: ").strip() or "1"

    print()
    offset_db, min_word_ms, min_silence_ms = get_user_input()

    if mode_input == "2":
        print()
        print("  Masukkan path file (contoh: 01/001.mp3):")
        file_input = input("  >> ").strip()
        target_path = os.path.join(script_dir, file_input)
        if not os.path.exists(target_path):
            print(f"  [ERROR] File tidak ditemukan: {target_path}")
            sys.exit(1)
        data = analyze_single_file(target_path, offset_db, min_word_ms, min_silence_ms)
        if data:
            print_file_analysis(data)

    elif mode_input == "3":
        print()
        print("  Folder yang tersedia:")
        for i, (folder_path, _) in enumerate(audio_folders):
            print(f"    [{i+1}] {os.path.basename(folder_path)}/")
        folder_choice = input("  >> Pilih nomor folder: ").strip()
        try:
            idx = int(folder_choice) - 1
            if 0 <= idx < len(audio_folders):
                folder_path, mp3_files = audio_folders[idx]
                folder_name = os.path.basename(folder_path)
                print(f"\n  📁 Menganalisa folder: {folder_name}/")
                for mp3_file in mp3_files:
                    data = analyze_single_file(mp3_file, offset_db, min_word_ms, min_silence_ms)
                    if data:
                        print_file_analysis(data)
            else:
                print("  [ERROR] Nomor tidak valid.")
        except ValueError:
            print("  [ERROR] Input tidak valid.")

    else:
        # Ringkasan semua
        print()
        print("=" * 70)
        print("  RINGKASAN ANALISA SEMUA FILE")
        print("=" * 70)

        issues = []
        for folder_path, mp3_files in audio_folders:
            folder_name = os.path.basename(folder_path)
            print(f"\n  📁 Folder: {folder_name}/")
            print(f"  {'File':<12} {'Durasi':>8} {'Kata':>6} {'NFloor':>8} {'Speech':>8} {'SNR':>6} {'Thresh':>8} {'DurAvg':>8} {'JedaAvg':>9}")
            print(f"  {'----':<12} {'------':>8} {'----':>6} {'------':>8} {'------':>8} {'---':>6} {'------':>8} {'------':>8} {'-------':>9}")

            for mp3_file in mp3_files:
                data = analyze_single_file(mp3_file, offset_db, min_word_ms, min_silence_ms)
                if data:
                    fname = data['filename']
                    dur = f"{data['total_sec']:.1f}s"
                    nw = data['num_words']
                    nf = f"{data['noise_floor']:.1f}"
                    sl = f"{data['speech_level']:.1f}"
                    snr = f"{data['snr']:.1f}"
                    th = f"{data['adaptive_thresh']:.1f}"

                    if data['word_details']:
                        durations = [w['duration_ms'] for w in data['word_details']]
                        gaps = [w['gap_after_ms'] for w in data['word_details'][:-1]]
                        d_avg = f"{sum(durations)//len(durations)}ms"
                        g_avg = f"{sum(gaps)//len(gaps)}ms" if gaps else "N/A"

                        if nw < 19:
                            issues.append(f"  ❌ {folder_name}/{fname}: Hanya {nw} kata (seharusnya 19-21)")
                        if nw > 22:
                            issues.append(f"  ⚠️  {folder_name}/{fname}: {nw} kata (terlalu banyak)")
                        if data['snr'] < 3:
                            issues.append(f"  ⚠️  {folder_name}/{fname}: SNR rendah ({data['snr']:.1f} dB)")
                    else:
                        d_avg = g_avg = "N/A"
                        issues.append(f"  ❌ {folder_name}/{fname}: 0 kata terdeteksi!")

                    print(f"  {fname:<12} {dur:>8} {nw:>6} {nf:>8} {sl:>8} {snr:>6} {th:>8} {d_avg:>8} {g_avg:>9}")

        if issues:
            print()
            print("=" * 70)
            print("  MASALAH YANG DITEMUKAN")
            print("=" * 70)
            for issue in issues:
                print(issue)

        print()
        print("=" * 70)
        print("  TIPS")
        print("=" * 70)
        print("  • Kata terlalu SEDIKIT  -> kurangi offset dB (lebih sensitif)")
        print("  • Kata terlalu BANYAK   -> naikkan offset dB")
        print("  • Kata TERGABUNG        -> kurangi min jeda (ms)")
        print("  • Noise ikut terdeteksi -> naikkan min durasi kata (ms)")
        print("  • Gunakan mode [2]/[3] untuk debug detail per file/folder")
        print()


if __name__ == "__main__":
    main()
