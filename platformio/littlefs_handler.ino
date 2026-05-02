/**
 * LittleFS Handler untuk menyimpan dan membaca data deret dari JSON
 * Includes comprehensive debug logging for development
 */

#include <Arduino.h>
#include <ArduinoJson.h>
#include <FS.h>
#include <LittleFS.h>

// Konstanta baterai dipindahkan ke forward declarations atau diatur dalam
// #ifndef untuk menghindari redefinisi
#ifndef BAT_FULL
#define BAT_FULL 4.2
#endif
#ifndef BAT_EMPTY
#define BAT_EMPTY 3.0
#endif

#define FORMAT_LITTLEFS_IF_FAILED true

// Word struct sudah didefinisikan di ESP32S3lirik2.ino

// Forward declarations
extern Word *getHardcodedWords(int slot);

bool initLittleFS() {
  Serial.println("[LFS] ========================================");
  Serial.println("[LFS] Initializing LittleFS...");

  if (!LittleFS.begin(FORMAT_LITTLEFS_IF_FAILED)) {
    Serial.println("[LFS] ERROR: LittleFS mount FAILED!");
    Serial.println("[LFS] ========================================");
    return false;
  }

  // Print filesystem info
  size_t totalBytes = LittleFS.totalBytes();
  size_t usedBytes = LittleFS.usedBytes();
  Serial.println("[LFS] LittleFS mounted successfully");
  Serial.print("[LFS]   Total space: ");
  Serial.print(totalBytes);
  Serial.println(" bytes");
  Serial.print("[LFS]   Used space:  ");
  Serial.print(usedBytes);
  Serial.println(" bytes");
  Serial.print("[LFS]   Free space:  ");
  Serial.print(totalBytes - usedBytes);
  Serial.println(" bytes");

  // Create lirik directory if not exists
  if (!LittleFS.exists("/lirik")) {
    Serial.println("[LFS] Creating /lirik directory...");
    LittleFS.mkdir("/lirik");
    Serial.println("[LFS] /lirik directory created");
  } else {
    Serial.println("[LFS] /lirik directory already exists");
  }

  // List existing files on boot
  Serial.println("[LFS] --- Existing files on boot ---");
  listLirikFiles();

  Serial.println("[LFS] ========================================");
  return true;
}

String readDeretFile(int slot) {
  String filename = "/lirik/deret_" + String(slot) + ".json";

  if (!LittleFS.exists(filename)) {
    return "";
  }

  File file = LittleFS.open(filename, "r");
  if (!file) {
    Serial.println("[LFS-READ] ERROR: Failed to open file for reading");
    return "";
  }

  String content = "";
  while (file.available()) {
    content += char(file.read());
  }
  file.close();

  return content;
}

bool writeDeretFile(int slot, const String &content) {
  String filename = "/lirik/deret_" + String(slot) + ".json";

  File file = LittleFS.open(filename, FILE_WRITE);
  if (!file) {
    Serial.println("[LFS-WRITE] ERROR: Failed to open file!");
    return false;
  }

  file.print(content);
  file.close();
  return true;
}

void deleteDeretFile(int slot) {
  String filename = "/lirik/deret_" + String(slot) + ".json";

  if (LittleFS.exists(filename)) {
    LittleFS.remove(filename);
    Serial.print("[LFS-DEL] Deleted: ");
    Serial.println(filename);
  }
}

void deleteAllDeretFiles() {
  Serial.println("[LFS-DEL] Deleting ALL deret files...");

  int deleted = 0;
  String paths[60];
  int count = 0;

  File root = LittleFS.open("/lirik");
  if (root && root.isDirectory()) {
      File file = root.openNextFile();
      while (file) {
          String name = String(file.name());
          if (name.indexOf("deret_") != -1 && name.indexOf(".json") != -1) {
              String path = name;
              if (!path.startsWith("/")) path = "/lirik/" + path;
              if (count < 60) {
                  paths[count++] = path;
              }
          }
          file = root.openNextFile();
      }
      root.close();
  }

  for(int i = 0; i < count; i++) {
      LittleFS.remove(paths[i]);
      Serial.print("[LFS-DEL]   Deleted: ");
      Serial.println(paths[i]);
      deleted++;
  }

  Serial.print("[LFS-DEL] Total files deleted: ");
  Serial.println(deleted);
  Serial.println("[LFS-DEL] All deret files deleted");
}

int getDeretCount() {
  int count = 0;
  File root = LittleFS.open("/lirik");

  if (!root) {
    Serial.println("[LFS] ERROR: Cannot open /lirik directory");
    return 0;
  }

  File file = root.openNextFile();
  while (file) {
    String name = file.name();
    if (name.startsWith("/lirik/deret_") || name.startsWith("deret_")) {
      count++;
    }
    file = root.openNextFile();
  }

  Serial.print("[LFS] Deret count: ");
  Serial.println(count);

  return count;
}

/**
 * Scan LittleFS untuk menemukan slot deret tertinggi yang terisi.
 * Return: nomor slot tertinggi (bukan jumlah total file).
 *
 * Contoh:
 *   File: deret_3.json, deret_7.json → return 7
 *   File: kosong                      → return 10 (default minimum)
 */
int scanDeretSlots() {
    int maxSlot = 0;
    int fileCount = 0;

    File root = LittleFS.open("/lirik");
    if (root && root.isDirectory()) {
        File file = root.openNextFile();
        while (file) {
            String name = String(file.name());
            int start = name.indexOf("deret_");
            int end = name.indexOf(".json");
            
            if (start != -1 && end != -1 && end > start) {
                String numStr = name.substring(start + 6, end);
                int slot = numStr.toInt();
                if (slot > 0) {
                    if (slot > maxSlot) maxSlot = slot;
                    fileCount++;
                }
            }
            file = root.openNextFile();
        }
        root.close();
    }

    // Minimum 10 agar navigasi UI tetap konsisten saat LittleFS kosong
    if (maxSlot < 10) maxSlot = 10;

    Serial.printf("[LFS-SCAN] Files found: %d, Highest slot: %d\n", fileCount, maxSlot);
    return maxSlot;
}

/**
 * Cek apakah memori masih aman untuk operasi berat (load deret, parse JSON).
 *
 * Threshold dihitung DINAMIS dari initMemoryProfile():
 *   - safePsramThreshold = 10% dari PSRAM fisik (dicadangkan)
 *   - SAFE_HEAP_MIN = 32KB internal heap minimum
 *   - SAFE_FLASH_MIN = 50KB flash minimum
 *
 * Jika PSRAM 8MB  → cadangan 800KB, boleh pakai 7.2MB
 * Jika PSRAM 16MB → cadangan 1.6MB, boleh pakai 14.4MB
 *
 * Returns: true = aman, false = berbahaya (jangan alokasi!)
 */
bool checkMemorySafety() {
    extern size_t totalPsramSize;
    extern size_t safePsramThreshold;
    extern const size_t SAFE_HEAP_MIN;
    extern const size_t SAFE_FLASH_MIN;

    size_t freePsram = ESP.getFreePsram();
    size_t freeHeap = ESP.getFreeHeap();
    size_t freeFlash = LittleFS.totalBytes() - LittleFS.usedBytes();

    Serial.println("[MEM-CHECK] === Safety Gate ===");
    Serial.printf("[MEM-CHECK]   PSRAM Free : %u / Min Reserved: %u\n", freePsram, safePsramThreshold);
    Serial.printf("[MEM-CHECK]   Heap Free  : %u / Min: %u\n", freeHeap, SAFE_HEAP_MIN);
    Serial.printf("[MEM-CHECK]   Flash Free : %u / Min: %u\n", freeFlash, SAFE_FLASH_MIN);

    if (freePsram < safePsramThreshold) {
        Serial.println("[MEM-CHECK] BLOCKED: PSRAM usage > 90%!");
        return false;
    }
    if (freeHeap < SAFE_HEAP_MIN) {
        Serial.println("[MEM-CHECK] BLOCKED: Internal heap critical!");
        return false;
    }
    if (freeFlash < SAFE_FLASH_MIN) {
        Serial.println("[MEM-CHECK] BLOCKED: Flash storage almost full!");
        return false;
    }

    Serial.println("[MEM-CHECK] Memory OK.");
    return true;
}

// Load deret dari LittleFS ke memory
// Returns: pointer ke array Word atau NULL jika gagal
Word *loadDeretFromLittleFS(int slot) {
  // ★ Memory Safety Gate — cek sebelum alokasi berat
  if (!checkMemorySafety()) {
    Serial.println("[LFS-LOAD] BLOCKED: Insufficient memory!");
    return NULL;
  }

  String content = readDeretFile(slot);

  if (content.length() == 0) {
    Serial.println(
        "[LFS-LOAD] No data found, returning NULL (will use hardcoded)");
    return NULL;
  }

  // Parse JSON (ArduinoJson 7 syntax)
  // Gunakan buffer yang cukup besar untuk menampung lirik satu deret penuh
  // (~150-200 kata)
  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, content);

  if (error) {
    Serial.print("[LFS-LOAD] ERROR: JSON parse failed for slot ");
    Serial.println(slot);
    Serial.print("[LFS-LOAD] Log: ");
    Serial.println(error.c_str());
    return NULL;
  }

  JsonObject root = doc.as<JsonObject>();
  String deretName = root["name"].as<String>();
  JsonArray wordsArray = root["words"].as<JsonArray>();
  // Allocate dynamic array based strictly ON the array size
  int wordCount = wordsArray.size();

  Word *loadedWords = new Word[wordCount];

  // Load each word directly (1:1 with Flutter's payload)
  int i = 0;
  for (JsonObject w : wordsArray) {
    loadedWords[i].time = w["t"].as<float>();
    loadedWords[i].text = strdup(w["w"].as<const char *>());
    i++;
  }

  // Set global word count (exactly matches array size)
  extern int loadedWordCount;
  loadedWordCount = wordCount;

  return loadedWords;
}

// Fallback ke hardcoded jika LittleFS kosong
Word *getHardcodedWords(int slot) {
  // Return NULL agar menggunakan listderet() yang ada di ESP32S3lirik2.ino
  return NULL;
}

// Check apakah deret ada di LittleFS
bool deretExistsInLittleFS(int slot) {
  return LittleFS.exists("/lirik/deret_" + String(slot) + ".json");
}

// List semua file di LittleFS
void listLirikFiles() {
  File root = LittleFS.open("/lirik");
  if (!root)
    return;

  int count = 0;
  File file = root.openNextFile();
  while (file) {
    count++;
    file = root.openNextFile();
  }
  Serial.print("[LFS] Total files: ");
  Serial.println(count);
}

/**
 * Build payload JSON untuk dikirim ke Flutter via BLE NOTIFY.
 * Format: [{"d":1,"name":"Deret 1","w":["KATA1","KATA2",...]},...]
 * Tanpa timestamp, hanya nomor slot, nama, dan kata-kata.
 *
 * @return String JSON yang siap dikirim, diakhiri [DATA_EOF]
 */
String buildCheckPayload() {
  Serial.println("[LFS-CHECK] ========================================");
  Serial.println("[LFS-CHECK] Building check payload from LittleFS...");

  String result = "[";
  bool first = true;
  int deretFound = 0;

  bool existsArr[21] = {false};
  File root = LittleFS.open("/lirik");
  if (root && root.isDirectory()) {
      File file = root.openNextFile();
      while (file) {
          String name = String(file.name());
          int start = name.indexOf("deret_");
          int end = name.indexOf(".json");
          if (start != -1 && end != -1 && end > start) {
              int slot = name.substring(start + 6, end).toInt();
              if (slot >= 1 && slot <= 20) existsArr[slot] = true;
          }
          file = root.openNextFile();
      }
      root.close();
  }

  for (int slot = 1; slot <= 20; slot++) {
    if (!existsArr[slot]) continue;

    String filename = "/lirik/deret_" + String(slot) + ".json";
    File f = LittleFS.open(filename, "r");
    if (!f) {
      continue;
    }

    String content = "";
    while (f.available()) {
      content += char(f.read());
    }
    f.close();

    // Parse: ambil name + kata-kata saja (tanpa timestamp)
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, content);
    if (err) {
      Serial.print("[LFS-CHECK] ERROR in Slot ");
      Serial.print(slot);
      Serial.print(": JSON error: ");
      Serial.println(err.c_str());
      continue;
    }

    String name = doc["name"].as<String>();
    JsonArray wordsArray = doc["words"].as<JsonArray>();

    if (!first)
      result += ",";
    first = false;

    result += "{\"d\":" + String(slot);
    result += ",\"name\":\"" + name + "\"";
    result += ",\"w\":[";

    int wi = 0;
    for (JsonObject w : wordsArray) {
      if (wi > 0)
        result += ",";
      result += "\"" + w["w"].as<String>() + "\"";
      wi++;
    }

    result += "]}";
    deretFound++;
  }

  result += "]";

  Serial.print("[LFS-CHECK] Total derets: ");
  Serial.println(deretFound);
  Serial.print("[LFS-CHECK] Payload size: ");
  Serial.print(result.length());
  Serial.println(" bytes");
  Serial.println("[LFS-CHECK] ========================================");

  return result;
}
