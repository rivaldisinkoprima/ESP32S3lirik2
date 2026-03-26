"""
========================================================================
  CEK VOLUME - Per-Word Volume Checker untuk Folder 03/
========================================================================
  Menampilkan volume (dBFS) setiap kata yang terdeteksi dalam
  setiap file MP3 di folder 03/.
========================================================================
"""

import os
import sys
import glob
import math
from pydub import AudioSegment

WINDOW_MS = 50
OFFSET_DB = 3.0
MIN_WORD_MS = 250
MAX_WORD_MS = 10000

def get_expected_words(filename):
    return 20 if "009" in filename else 21


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


def main():
    print("=" * 70)
    print("  CEK VOLUME PER-KATA - Folder 03/")
    print("=" * 70)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    folder_03 = os.path.join(script_dir, "03")

    if not os.path.isdir(folder_03):
        print(f"  [ERROR] Folder 03/ tidak ditemukan di: {script_dir}")
        sys.exit(1)

    mp3_files = sorted(glob.glob(os.path.join(folder_03, "*.mp3")))
    if not mp3_files:
        print("  [ERROR] Tidak ada file MP3 di folder 03/")
        sys.exit(1)

    print(f"  Ditemukan {len(mp3_files)} file MP3\n")

    for mp3_file in mp3_files:
        fname = os.path.basename(mp3_file)
        print(f"  {'=' * 66}")
        print(f"  🎵 {fname}")
        print(f"  {'=' * 66}")

        try:
            audio = AudioSegment.from_mp3(mp3_file)
        except Exception as e:
            print(f"     [ERROR] {e}")
            continue

        mono = audio.set_channels(1)

        print(f"  Durasi      : {len(mono)/1000:.1f}s")
        print(f"  Peak        : {mono.max_dBFS:.2f} dBFS")
        print(f"  RMS (file)  : {mono.dBFS:.2f} dBFS")
        print()

        expected = get_expected_words(fname)
        words = detect_words(mono, expected)
        if not words:
            print("  [!] Tidak ada kata terdeteksi!")
            continue

        rms_list = []
        peak_list = []
        for s, e in words:
            seg = mono[s:e]
            if seg.dBFS != float('-inf'):
                rms_list.append(seg.dBFS)
            if seg.max_dBFS != float('-inf'):
                peak_list.append(seg.max_dBFS)

        # Statistik
        if rms_list:
            avg_rms = sum(rms_list) / len(rms_list)
            spread = max(rms_list) - min(rms_list)
            print()
            print(f"  --- Statistik Volume Kata ---")
            print(f"  Kata terdeteksi : {len(words)}")
            print(f"  RMS rata-rata   : {avg_rms:.2f} dBFS")
            print(f"  RMS terkecil    : {min(rms_list):.2f} dBFS")
            print(f"  RMS terbesar    : {max(rms_list):.2f} dBFS")
            print(f"  Spread (variasi): {spread:.2f} dB", end="")
            if spread > 6:
                print("  ⚠️ VARIASI TINGGI!")
            elif spread > 3:
                print("  ⚠️ Perlu normalisasi")
            else:
                print("  ✅ Konsisten")
        print()


if __name__ == "__main__":
    main()
