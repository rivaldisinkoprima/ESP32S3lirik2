# ESP32-S3 Lirik Player - Complete Project Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Hardware Specification](#hardware-specification)
3. [Pin Configuration](#pin-configuration)
4. [Software Architecture](#software-architecture)
5. [File Structure](#file-structure)
6. [Features](#features)
7. [BLE Communication Protocol](#ble-communication-protocol)
8. [Memory Management](#memory-management)
9. [LittleFS Data Structure](#littlefs-data-structure)
10. [State Machine](#state-machine)
11. [Troubleshooting](#troubleshooting)
12. [Future Improvements](#future-improvements)
13. [Development Notes](#development-notes)

---

## Project Overview

**Project Name:** ESP32-S3 Lirik Player  
**Purpose:** MP3 player with LCD display for lyrics/song synchronization via Bluetooth  
**Target Hardware:** ESP32-S3 with TFT 1.8" display, DFPlayer Mini, DS3231 RTC  
**Framework:** Arduino/PlatformIO  
**Last Updated:** April 2026

### What This Device Does
This device is an MP3 player specifically designed for medical/speech therapy applications. It plays audio from an SD card via DFPlayer Mini, displays synchronized lyrics on a TFT screen, and receives lyric data from a Flutter mobile app via Bluetooth Low Energy (BLE).

---

## Hardware Specification

### Main Components

| Component | Model | Notes |
|-----------|-------|-------|
| Microcontroller | ESP32-S3 | N16R8 variant (16MB Flash, 8MB PSRAM) |
| Display | TFT 1.8" ST7735 | 128x160 pixels, SPI interface |
| Audio Player | DFPlayer Mini | Supports 3 folders, max 255 files/folder |
| RTC | DS3231 | Battery backup (CR2032) |
| Battery Management | TP4056 | USB-C charging with protection |
| Power Regulator | AMS1117-3.3 | 3.3V for ESP32 |

### Physical Dimensions
- **PCB Size:** ~85mm x 55mm (custom designed)
- **Display:** 1.8" TFT mounted on front panel
- **Battery:** 18650 Li-ion (optional, under PCB)

### Power Requirements
| Mode | Current | Notes |
|------|---------|-------|
| Playing | ~150mA | With speaker output |
| Idle/Standby | ~50mA | Screen on, no playback |
| Deep Sleep | ~5mA | Future feature |
| Charging | ~500mA | Via USB-C |

---

## Pin Configuration

### 1. TFT Display (SPI)
```
TFT_CS   → GPIO 13   (Chip Select)
TFT_RST  → GPIO 12   (Reset)
TFT_DC   → GPIO 11   (Data/Command)
TFT_MOSI → GPIO 10   (MOSI)
TFT_SCK  → GPIO 15   (Clock)
TFT_MISO → GPIO -1   (Not used)
```

### 2. DFPlayer Mini (UART)
```
DFPlayer TX → GPIO 16  (TX → ESP32 RX)
DFPlayer RX → GPIO 7   (RX → ESP32 TX)
```

### 3. Buttons (Input with Pull-up - Active LOW)
| Button | GPIO | Function |
|--------|------|----------|
| Next | 4 | Navigate forward / Next track |
| Pause/OK | 3 | Pause/Play or Confirm |
| Home | 1 | Return to main menu |
| Previous | 2 | Navigate backward / Prev track |
| Vol Up | 18 | Increase volume |
| Vol Down | 9 | Decrease volume |
| Mode | 6 | Switch playback mode |
| Mic Trigger | 19 | External mic trigger |
| Power | 46 | Power on/off |

### 4. RTC (I2C)
```
SDA → GPIO 41 (Hardware default)
SCL → GPIO 42 (Hardware default)
Address: 0x68 (DS3231 default)
```

### 5. Power & Battery Management
| Pin | GPIO | Function |
|-----|------|-----------|
| BAT_ADC | 5 | Battery voltage sense |
| PIN_CHRG | 45 | Charging status (LOW = charging) |
| PIN_STBY | 48 | Standby/Full status (LOW = full) |

### 6. Trigger Outputs
| Pin | GPIO | Function |
|-----|------|-----------|
| TrigMic | 8 | Microphone relay control |
| TrigPower | 21 | Power relay control |
| TrigRlyDF | 20 | Audio module relay control |

### 7. Other
| Pin | GPIO | Function |
|-----|------|-----------|
| pinLED | 55 | Status LED |
| GPIO 14 | 14 | Spare input |
| GPIO 17 | 17 | Spare output |

---

## Software Architecture

### System Flow Diagram
```
┌──────────────────────────────────────────────────────────────────┐
│                         BOOT SEQUENCE                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. initMemoryProfile() - Get PSRAM/Heap size                    │
│  2. Serial.begin(115200) - Start debug serial                    │
│  3. initLittleFS() - Mount filesystem                            │
│  4. initBLE() - Start BLE GATT server                            │
│  5. initTFT() - Initialize display                               │
│  6. scanDeretSlots() - Count available deret                    │
│  7. Start main loop()                                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                          MAIN LOOP                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │ esp_task_wdt    │    │ handleBLE()     │ ← Decoupled        │
│  │ reset           │    │ Process payload │   processing       │
│  └─────────────────┘    └─────────────────┘                     │
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │ drawBTIcon()    │    │ button handlers │ ← Debounced        │
│  │ (every 1s)      │    │ oke/next/prev   │   250ms delay      │
│  └─────────────────┘    └─────────────────┘                     │
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐                     │
│  │ autodetect_df() │    │ readRTC()       │ ← Every 30 min     │
│  │ Lyrics sync     │    │ Battery check   │                     │
│  └─────────────────┘    └─────────────────┘                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Memory Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    ESP32-S3 MEMORY MAP                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  FLASH (16MB)                                                   │
│  ├─ Bootloader                                                  │
│  ├─ Partition Table                                            │
│  ├─ NVS (4KB)                                                  │
│  ├─ App (1.5MB)                                                │
│  ├─ LittleFS (1MB) ← /lirik/deret_*.json files                 │
│  └─ Spiffs                                                    │
│                                                                 │
│  RAM                                                            │
│  ├─ DRAM (520KB)                                               │
│  │  ├─ Heap (Free: >200KB)                                    │
│  │  │  ├─ Global variables                                    │
│  │  │  ├─ BLE buffer (String)                                 │
│  │  │  └─ JSON doc (12KB)                                     │
│  │  └─ Stack                                                   │
│  │     ├─ Core 0 (Main loop)                                   │
│  │     └─ Core 1 (BLE/WiFi)                                    │
│  │                                                            │
│  └─ PSRAM (8MB - N16R8)                                        │
│     └─ Reserved (800KB for system)                             │
│        └─ Available (~7.2MB)                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Structure

### Main Program Files

| File | Lines | Purpose |
|------|-------|---------|
| `ESP32S3lirik2.ino` | 720 | Main entry, setup(), loop(), core logic |
| `ble_server.ino` | 528 | BLE GATT server, chunk reassembly, NOTIFY |
| `littlefs_handler.ino` | 431 | LittleFS CRUD, JSON parsing |
| `file.ino` | 160 | TFT FILE menu, displayDeretGeneric() |
| `tampiljam.ino` | 4 | Time display on TFT |
| `readRTC.ino` | 21 | DS3231 reading |
| `bat_cas.ino` | 28 | Battery charging detection |
| `tampilbattery.ino` | - | Battery UI |
| `mode.ino` | 35 | Mode switching (Left/Right/All) |
| `volume.ino` | - | Volume control |
| `nextp.ino` | 70 | Next track logic |
| `previouse.ino` | 25 | Previous track logic |
| `home.ino` | 15 | Home button |
| `mic.ino` | - | Mic trigger |
| `begin.ino` | 19 | Hardware init, splash |
| `oke.ino` | 60 | OK/Pause button |
| `aturjam.ino` | - | Time setting UI |
| `readButtonState.ino` | - | Button state reading |
| `new_bat.ino` | - | Battery calculation |
| `sesion.ino` | - | Session management |
| `autodetect_state_df.ino` | - | DFPlayer state detection |
| `bmpDraw.ino` | - | Bitmap drawing |

### External Dependencies (platformio.ini)
```
Adafruit ST7735 Library
Adafruit GFX Library
DFRobotDFPlayerMini
RTClib
ArduinoJson
esp32-wifi-manager (BLE native)
```

---

## Features

### Current Features (v1.0+)

#### Audio Playback
- [x] Play MP3 from SD card via DFPlayer Mini
- [x] Support 3 folders (01, 02, 03)
- [x] Up to 255 files per folder
- [x] 3 playback modes: Right channel, Left channel, Both
- [x] Volume control (0-30)
- [x] Track navigation (next/previous)

#### Data Management
- [x] 10 lyric deret slots (1-10)
- [x] BLE sync from Flutter app
- [x] LittleFS persistence
- [x] JSON format storage
- [x] Factory reset capability

#### Display (TFT 1.8")
- [x] Main menu with 3 options
- [x] FILE menu (deret selection)
- [x] Lyrics display with timing
- [x] Time display (RTC)
- [x] Battery indicator
- [x] Bluetooth status icon
- [x] "KOSONG" empty state display

#### Power Management
- [x] Battery voltage monitoring
- [x] Charging status detection
- [x] Battery percentage display
- [x] Low battery warning

#### Controls
- [x] 9-button input system
- [x] Debounced button handling (250ms)
- [x] Active LOW detection
- [x] Internal pull-up configuration

#### System
- [x] Memory profiling at boot
- [x] Dynamic memory management
- [x] Error recovery
- [x] Watchdog timer
- [x] Debug serial logging

### BLE Commands

| Command | Format | Description |
|---------|--------|-------------|
| SET_TIME | `@SET_TIME|HH:MM:SS` | Set RTC time |
| SYNC_START | `@SYNC_START` | Begin lyrics sync |
| SYNC_DATA | `@SYNC_DATA|{json}` | Lyrics payload (chunked) |
| SYNC_END | `@SYNC_END` | Complete sync |
| CHECK | `@CHECK` | Request current status |
| RESET | `@RESET` | Factory reset |

---

## BLE Communication Protocol

### Service & Characteristic UUIDs
```
Service UUID:   4fafc201-1fb5-459e-8fcc-c5c9c331914b
Characteristic: beb5483e-36e1-4688-b7f5-ea07361b26a8
               (Notify + Write)
```

### Incoming Data Format
```json
// Single deret payload
{
  "d": 1,                    // Deret number (1-10)
  "n": "Nama Lagu",         // Song title
  "w": [                    // Words array
    {"t": 0.0, "l": "Word 1"},
    {"t": 2.5, "l": "Word 2"},
    {"t": 4.0, "l": "Word 3"},
    {"t": 5.5, "l": "Word 4"}
  ]
}

// Bulk payload (multiple derets)
[
  {"d":1,"n":"Lagu 1","w":[...]},
  {"d":2,"n":"Lagu 2","w":[...]},
  ...
]
```

### Chunk Reassembly
- **Max chunk size:** ~512 bytes
- **Delimiter:** `[EOF]`
- **Buffer:** String concatenation until delimiter found

### Outgoing Notifications
```
OK:10/10     - Sync complete (10 of 10 slots)
OK:RESET     - Factory reset complete
ERR:JSON     - JSON parse error
ERR:WRITE    - LittleFS write error
ERR:MEM      - Memory insufficient
```

---

## Memory Management

### Dynamic Allocation Flow
```cpp
// 1. Boot: Calculate memory profile
void initMemoryProfile() {
  totalPsramSize = ESP.getPsramSize();      // e.g., 8MB
  safePsramThreshold = totalPsramSize / 10;  // 800KB reserved
}

// 2. Load deret: Allocate memory
Word* loadDeretFromLittleFS(int slot) {
  String json = readDeretFile(slot);
  DynamicJsonDocument doc(12288);
  deserializeJson(doc, json);
  
  Word* words = new Word[count];
  for (int i = 0; i < count; i++) {
    words[i].text = strdup(doc["w"][i]["l"]);
    words[i].time = doc["w"][i]["t"];
  }
  return words;
}

// 3. Cleanup: Free memory on deret change
void freeLoadedWords() {
  if (wordsFromLittleFS && words != NULL) {
    for (int i = 0; i < loadedWordCount; i++) {
      free((void*)words[i].text);
    }
    delete[] words;
    words = NULL;
  }
}
```

### Memory Safety Checks
```cpp
bool checkMemorySafety() {
  if (ESP.getFreeHeap() < 32768) return false;     // <32KB
  if (ESP.getFreePsram() < safePsramThreshold) return false;
  if (LittleFS.totalBytes() - LittleFS.usedBytes() < 51200) return false;
  return true;
}
```

---

## LittleFS Data Structure

### Directory Layout
```
/littlefs/
└── /lirik/
    ├── deret_1.json   (max ~4KB)
    ├── deret_2.json
    ├── deret_3.json
    ├── deret_4.json
    ├── deret_5.json
    ├── deret_6.json
    ├── deret_7.json
    ├── deret_8.json
    ├── deret_9.json
    └── deret_10.json
```

### File Content Example
```json
{
  "d": 1,
  "n": "Contoh Lagu",
  "w": [
    {"t": 0.0, "l": "Kata Pertama"},
    {"t": 1.5, "l": "Kata Kedua"},
    {"t": 3.0, "l": "Kata Ketiga"}
  ]
}
```

### Scan Function
```cpp
int scanDeretSlots() {
  int count = 0;
  for (int i = 1; i <= 10; i++) {
    if (deretExistsInLittleFS(i)) count++;
  }
  return count;
}
```

---

## State Machine

### Main States
```
┌─────────────────────────────────────────────────────────────┐
│                      STATE DIAGRAM                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────┐   Button:FILE      ┌─────────────┐           │
│  │  HOME   │ ────────────────►  │  FILE MENU  │           │
│  │ SCREEN  │                    │ (deret 1-10)│           │
│  └─────────┘                    └─────────────┘           │
│       ▲                                │                   │
│       │                                │ Select deret      │
│       │        Button:HOME             ▼                   │
│       └───────────────────────────────┐                   │
│                                        │                    │
│    ┌─────────┐   Button:OK      ┌─────────────────┐       │
│    │PLAYING │ ────────────────► │   SCREENING     │       │
│    │MODE    │                   │ (lyrics display)│       │
│    └─────────┘                  └─────────────────┘       │
│         │                                  │                 │
│         │      Mic trigger / Song end     │                 │
│         └──────────────────────────────────┘                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Position Codes
| Posisi | Meaning |
|--------|---------|
| 1 | Home screen (main menu) |
| 2 | Screening mode (playing) |
| 3 | Settings |
| 4 | FILE menu |
| 5 | Deret detail view |

---

## Troubleshooting

### Common Issues & Solutions

#### Display Issues
| Problem | Cause | Solution |
|---------|-------|----------|
| TFT no display | SPI conflict | Check CS pin, use FSPI |
| Display flicker | Buffer collision | Use GFXcanvas16 |
| "KOSONG" showing | Empty deret | Sync via BLE |

#### Audio Issues
| Problem | Cause | Solution |
|---------|-------|----------|
| DFPlayer silent | UART mismatch | Check baud 9600 |
| No sound | Relay off | Check TrigRlyDF |
| Skipping tracks | Buffer timeout | Increase delay |

#### BLE Issues
| Problem | Cause | Solution |
|---------|-------|----------|
| Not connecting | UUID mismatch | Verify UUIDs |
| Disconnecting | RSSI weak | Move closer |
| Data corruption | Chunk error | Check [EOF] |

#### Memory Issues
| Problem | Cause | Solution |
|---------|-------|----------|
| Crash on load | Memory leak | Call freeLoadedWords() |
| Slow response | Heap full | Check ESP.getFreeHeap() |
| Boot fail | LittleFS corrupt | Format LittleFS |

### Debug Serial Tags

| Tag | Source | Information |
|-----|--------|-------------|
| `[LFS]` | littlefs_handler.ino | Init, space, listing |
| `[LFS-READ]` | littlefs_handler.ino | File read |
| `[LFS-WRITE]` | littlefs_handler.ino | File write |
| `[LFS-LOAD]` | littlefs_handler.ino | JSON parse |
| `[BLE]` | ble_server.ino | Connect/disconnect |
| `[BLE-RX]` | ble_server.ino | Chunk received |
| `[BLE-LOOP]` | ble_server.ino | Payload process |
| `[DERET]` | ESP32S3lirik2.ino | Load LittleFS |
| `[MEM]` | ESP32S3lirik2.ino | Heap status |
| `[SETUP]` | ESP32S3lirik2.ino | System init |

---

## Future Improvements

### Priority 1 - Critical
- [ ] **OTA Updates** - Firmware update via BLE
- [ ] **Error Recovery** - Auto-retry on failures
- [ ] **Watchdog Timeout** - Prevent system hang

### Priority 2 - Important
- [ ] **Volume Memory** - Remember last volume
- [ ] **Resume Play** - Continue after reboot
- [ ] **DFPlayer Hot-swap** - Detect insert/remove

### Priority 3 - Enhancement
- [ ] **Splash Screen** - Boot animation
- [ ] **Progress Bar** - Sync indicator
- [ ] **Dark Mode** - Alternative colors

### Priority 4 - Advanced
- [ ] **WiFi Capability** - Cloud sync ready
- [ ] **Audio FFT** - Visualizer
- [ ] **Custom Fonts** - Better typography

---

## Development Notes

### Build Command
```bash
pio run
```

### Upload Command
```bash
pio run --target upload
```

### Serial Monitor
```bash
pio device monitor --baud 9600
```

### Partition Configuration
```
Name       | Type | SubType | Offset   | Size
------------|------|---------|----------|------
nvs         | data | nvs     | 0x9000   | 0x5000
app         | app  | spiffs  | 0x14000  | 0x1E0000
spiffs      | data | spiffs  | 0x1F4000 | 0xC000
```

---

## References

- [ESP32-S3 Datasheet](https://espressif.com)
- [Adafruit ST7735 Library](https://github.com/adafruit/Adafruit-ST7735-Library)
- [DFPlayer Mini Wiki](https://wiki.dfrobot.com/DFPlayer_Mini_SKU_DFR0201)
- [LittleFS Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/storage/littlefs.html)
- [ArduinoJson](https://arduinojson.org)

---

*Documentation generated for ESP32-S3 Lirik Player Project*
*Version: 1.0*
*Last updated: April 2026*