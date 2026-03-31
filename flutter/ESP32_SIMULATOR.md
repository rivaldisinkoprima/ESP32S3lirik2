# ESP32 Simulator

Simulasi perangkat ESP32 menggunakan Python untuk menguji koneksi BLE dari Flutter App sebelum diterapkan ke hardware nyata.

## Requirements

```bash
pip install bleak
```

## Cara Menjalankan

### 1. Install Dependencies

```bash
pip install bleak
```

### 2. Jalankan Simulator

```bash
python esp32_simulator.py
```

### 3. Di Flutter App

1. Buka menu Sync (icon Bluetooth)
2. Scan perangkat - cari `Lirik S3`
3. Connect dan masukkan PIN (default: `123456`)
4. Tekan "Sync All" untuk mengirim data

## Fitur yang Diuji

| Fitur | Status | Deskripsi |
|-------|--------|-----------|
| BLE Connection | ✅ | Scan, connect, disconnect |
| JSON Receive | ✅ | Parse bulk payload |
| Data Chunking | ✅ | Terima data 512 bytes |
| Factory Reset | ✅ | Reset via `{"c": "reset"}` |
| Memory Storage | ✅ | Simpan data ke dict |

## Format JSON yang Diterima

### Single Deret
```json
{
  "d": 1,
  "name": "Deret Satu",
  "v": [
    {"t": 13000, "w": "SABUN"},
    {"t": 20000, "w": "KUDA"}
  ]
}
```

### Bulk Payload (Array)
```json
[
  {"d":1,"name":"Deret 1","v":[{"t":13000,"w":"SABUN"},...]},
  {"d":2,"name":"Deret 2","v":[{"t":12000,"w":"WALI"},...]}
]
```

### Factory Reset
```json
{"c": "reset"}
```

## Output Simulator

```
============================================================
  ESP32 Simulator - Lirik S3
============================================================
Service UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
Char UUID:    beb5483e-36e1-4688-b7f5-ea07361b26a8
============================================================

✓ Server started. Waiting for connections...
  - Buka Flutter App
  - Scan untuk device: Lirik S3
  - Connect dan Sync All

Tekan Ctrl+C untuk exit

[RECEIVED 256 bytes]: [{"d":1,"name":"Deret Satu"...
[DATA] Received 2 derets (bulk payload)

  └─ Deret 1: Deret Satu
     Kata: 20 words
        1. [13000ms] SABUN
        2. [20000ms] KUDA
        ...
```

## Troubleshooting

### Error: No Bluetooth adapter

```bash
# Untuk Linux, install bluez
sudo apt install bluez

# Enable Bluetooth
sudo systemctl enable bluetooth
sudo systemctl start bluetooth
```

### Error: Permission denied

```bash
# Linux: perlu root atau set capability
sudo setcap cap-net-admin+eip $(which python3)
```

### Error: bleak not found

```bash
# Upgrade pip dan install
pip install --upgrade pip
pip install bleak
```
