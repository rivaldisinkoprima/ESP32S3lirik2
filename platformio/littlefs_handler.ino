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
    
    Serial.print("[LFS-READ] Reading file: ");
    Serial.println(filename);
    
    if (!LittleFS.exists(filename)) {
        Serial.print("[LFS-READ] File NOT FOUND: ");
        Serial.println(filename);
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
    
    Serial.print("[LFS-READ] Read ");
    Serial.print(content.length());
    Serial.print(" bytes from ");
    Serial.println(filename);
    Serial.print("[LFS-READ] Content preview: ");
    Serial.println(content.substring(0, min((int)content.length(), 150)));
    
    return content;
}

bool writeDeretFile(int slot, const String& content) {
    String filename = "/lirik/deret_" + String(slot) + ".json";
    
    Serial.print("[LFS-WRITE] Writing to: ");
    Serial.print(filename);
    Serial.print(" (");
    Serial.print(content.length());
    Serial.println(" bytes)");
    
    File file = LittleFS.open(filename, FILE_WRITE);
    if (!file) {
        Serial.println("[LFS-WRITE] ERROR: Failed to open file for writing!");
        return false;
    }
    
    size_t bytesWritten = file.print(content);
    file.close();
    
    Serial.print("[LFS-WRITE] Bytes written: ");
    Serial.println(bytesWritten);
    
    // Verify by reading back
    if (LittleFS.exists(filename)) {
        File verify = LittleFS.open(filename, "r");
        if (verify) {
            Serial.print("[LFS-WRITE] Verify: file size on disk = ");
            Serial.print(verify.size());
            Serial.println(" bytes ✓");
            verify.close();
        }
    }
    
    // Print updated space info
    Serial.print("[LFS-WRITE] Space remaining: ");
    Serial.print(LittleFS.totalBytes() - LittleFS.usedBytes());
    Serial.println(" bytes");
    
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
    Serial.println("[LFS-LOAD] --------------------------------");
    Serial.print("[LFS-LOAD] Loading deret slot ");
    Serial.print(slot);
    Serial.println(" from LittleFS...");
    
    String content = readDeretFile(slot);
    
    if (content.length() == 0) {
        Serial.println("[LFS-LOAD] No data found, returning NULL (will use hardcoded)");
        return NULL;
    }
    
    // Parse JSON (ArduinoJson 7 syntax)
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, content);
    
    if (error) {
        Serial.print("[LFS-LOAD] ERROR: JSON parse failed: ");
        Serial.println(error.c_str());
        Serial.println("[LFS-LOAD] Returning NULL (will use hardcoded)");
        return NULL;
    }
    
    JsonObject root = doc.as<JsonObject>();
    String deretName = root["name"].as<String>();
    JsonArray wordsArray = root["words"].as<JsonArray>();
    
    // Allocate dynamic array
    int wordCount = wordsArray.size();
    Serial.print("[LFS-LOAD] Deret name: ");
    Serial.println(deretName);
    Serial.print("[LFS-LOAD] Word count: ");
    Serial.println(wordCount);
    Serial.print("[LFS-LOAD] Allocating Word array: ");
    Serial.print((wordCount + 1) * sizeof(Word));
    Serial.println(" bytes");
    
    Word* loadedWords = new Word[wordCount + 1];
    
    // First entry is deret name
    loadedWords[0].time = 0;
    loadedWords[0].text = strdup(deretName.c_str());
    
    // Load each word
    int i = 1;
    for (JsonObject w : wordsArray) {
        loadedWords[i].time = w["t"].as<float>();
        loadedWords[i].text = strdup(w["w"].as<const char*>());
        
        // Debug: print first 3 and last word
        if (i <= 3 || i == wordCount) {
            Serial.print("[LFS-LOAD]   [");
            Serial.print(i);
            Serial.print("] t=");
            Serial.print((int)loadedWords[i].time);
            Serial.print("ms -> \"");
            Serial.print(loadedWords[i].text);
            Serial.println("\"");
        } else if (i == 4) {
            Serial.println("[LFS-LOAD]   ... (truncated)");
        }
        i++;
    }
    
    Serial.print("[LFS-LOAD] Successfully loaded ");
    Serial.print(wordCount);
    Serial.println(" words from LittleFS ✓");
    Serial.println("[LFS-LOAD] --------------------------------");
    
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
    String filename = "/lirik/deret_" + String(slot) + ".json";
    bool exists = LittleFS.exists(filename);
    Serial.print("[LFS-CHK] Slot ");
    Serial.print(slot);
    Serial.print(" (");
    Serial.print(filename);
    Serial.print("): ");
    Serial.println(exists ? "EXISTS ✓" : "NOT FOUND");
    return exists;
}

// List semua file di LittleFS
void listLirikFiles() {
    Serial.println("[LFS-LIST] Contents of /lirik:");
    
    File root = LittleFS.open("/lirik");
    if (!root) {
        Serial.println("[LFS-LIST] (empty or cannot open directory)");
        return;
    }
    
    int count = 0;
    File file = root.openNextFile();
    while (file) {
        Serial.print("[LFS-LIST]   ");
        Serial.print(count + 1);
        Serial.print(". ");
        Serial.print(file.name());
        Serial.print(" (");
        Serial.print(file.size());
        Serial.println(" bytes)");
        count++;
        file = root.openNextFile();
    }
    
    if (count == 0) {
        Serial.println("[LFS-LIST]   (no files found)");
    } else {
        Serial.print("[LFS-LIST] Total: ");
        Serial.print(count);
        Serial.println(" files");
    }
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
            Serial.print("[LFS-CHECK] ERROR: Cannot open slot ");
            Serial.println(slot);
            continue;
        }
        
        size_t fileSize = f.size();
        Serial.print("[LFS-CHECK] Found Slot ");
        Serial.print(slot);
        Serial.print(" (");
        Serial.print(fileSize);
        Serial.println(" bytes). Parsing...");

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
        
        Serial.print("[LFS-CHECK] >> Slot ");
        Serial.print(slot);
        Serial.print(" OK: \"");
        Serial.print(name);
        Serial.print("\" with ");
        Serial.print(wi);
        Serial.println(" words added to payload.");
        
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
