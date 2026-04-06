/**
 * LittleFS Handler untuk menyimpan dan membaca data deret dari JSON
 * Includes comprehensive debug logging for development
 */

#include <FS.h>
#include <LittleFS.h>
#include <Arduino.h>
#include <ArduinoJson.h>

// Konstanta baterai dipindahkan ke forward declarations atau diatur dalam #ifndef untuk menghindari redefinisi
#ifndef BAT_FULL
#define BAT_FULL    4.2
#endif
#ifndef BAT_EMPTY
#define BAT_EMPTY   3.0
#endif

#define FORMAT_LITTLEFS_IF_FAILED true

// Word struct sudah didefinisikan di ESP32S3lirik2.ino

// Forward declarations
extern Word* getHardcodedWords(int slot);

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

bool writeDeretFile(int slot, const String& content) {
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
    for (int i = 1; i <= 20; i++) { // Support up to 20 derets
        String filename = "/lirik/deret_" + String(i) + ".json";
        if (LittleFS.exists(filename)) {
            LittleFS.remove(filename);
            Serial.print("[LFS-DEL]   Deleted: ");
            Serial.println(filename);
            deleted++;
        }
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

// Load deret dari LittleFS ke memory
// Returns: pointer ke array Word atau NULL jika gagal
Word* loadDeretFromLittleFS(int slot) {
    String content = readDeretFile(slot);
    
    if (content.length() == 0) {
        Serial.println("[LFS-LOAD] No data found, returning NULL (will use hardcoded)");
        return NULL;
    }
    
    // Parse JSON (ArduinoJson 7 syntax)
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, content);
    
    if (error) {
        Serial.print("[LFS-LOAD] ERROR: JSON parse failed for slot ");
        Serial.println(slot);
        return NULL;
    }
    
    JsonObject root = doc.as<JsonObject>();
    String deretName = root["name"].as<String>();
    JsonArray wordsArray = root["words"].as<JsonArray>();
    
    // Allocate dynamic array
    int wordCount = wordsArray.size();
    
    Word* loadedWords = new Word[wordCount + 1];
    
    // First entry is deret name
    loadedWords[0].time = 0;
    loadedWords[0].text = strdup(deretName.c_str());
    
    // Load each word
    int i = 1;
    for (JsonObject w : wordsArray) {
        loadedWords[i].time = w["t"].as<float>();
        loadedWords[i].text = strdup(w["w"].as<const char*>());
        i++;
    }
    
    // Set global word count (header + words)
    extern int loadedWordCount;
    loadedWordCount = wordCount + 1;
    
    return loadedWords;
}

// Fallback ke hardcoded jika LittleFS kosong
Word* getHardcodedWords(int slot) {
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
    if (!root) return;
    
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
    
    for (int slot = 1; slot <= 20; slot++) {
        String filename = "/lirik/deret_" + String(slot) + ".json";
        
        if (!LittleFS.exists(filename)) {
            // Serial.print("[LFS-CHECK] Slot "); Serial.print(slot); Serial.println(": EMPTY");
            continue;
        }
        
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
        
        if (!first) result += ",";
        first = false;
        
        result += "{\"d\":" + String(slot);
        result += ",\"name\":\"" + name + "\"";
        result += ",\"w\":[";
        
        int wi = 0;
        for (JsonObject w : wordsArray) {
            if (wi > 0) result += ",";
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
