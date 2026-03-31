/**
 * LittleFS Handler untuk menyimpan dan membaca data deret dari JSON
 */

#include <FS.h>
#include <LittleFS.h>
#include <Arduino.h>

#define FORMAT_LITTLEFS_IF_FAILED true

// Word struct sudah didefinisikan di ESP32S3lirik2.ino

// Forward declarations
extern Word* getHardcodedWords(int slot);

bool initLittleFS() {
    Serial.println("[LFS] Initializing LittleFS...");
    
    if (!LittleFS.begin(FORMAT_LITTLEFS_IF_FAILED)) {
        Serial.println("[LFS] LittleFS mount failed");
        return false;
    }
    
    Serial.println("[LFS] LittleFS mounted successfully");
    
    // Create lirik directory if not exists
    if (!LittleFS.exists("/lirik")) {
        Serial.println("[LFS] Creating /lirik directory");
        LittleFS.mkdir("/lirik");
    }
    
    return true;
}

String readDeretFile(int slot) {
    String filename = "/lirik/deret_" + String(slot) + ".json";
    
    if (!LittleFS.exists(filename)) {
        Serial.print("[LFS] File not found: ");
        Serial.println(filename);
        return "";
    }
    
    File file = LittleFS.open(filename, "r");
    if (!file) {
        Serial.println("[LFS] Failed to open file");
        return "";
    }
    
    String content = "";
    while (file.available()) {
        content += char(file.read());
    }
    file.close();
    
    Serial.print("[LFS] Read ");
    Serial.print(content.length());
    Serial.println(" bytes from ");
    Serial.println(filename);
    
    return content;
}

bool writeDeretFile(int slot, const String& content) {
    String filename = "/lirik/deret_" + String(slot) + ".json";
    
    File file = LittleFS.open(filename, FILE_WRITE);
    if (!file) {
        Serial.println("[LFS] Failed to open file for writing");
        return false;
    }
    
    file.print(content);
    file.close();
    
    Serial.print("[LFS] Written to ");
    Serial.println(filename);
    
    return true;
}

void deleteDeretFile(int slot) {
    String filename = "/lirik/deret_" + String(slot) + ".json";
    
    if (LittleFS.exists(filename)) {
        LittleFS.remove(filename);
        Serial.print("[LFS] Deleted: ");
        Serial.println(filename);
    }
}

void deleteAllDeretFiles() {
    Serial.println("[LFS] Deleting all deret files...");
    
    for (int i = 1; i <= 20; i++) { // Support up to 20 derets
        deleteDeretFile(i);
    }
    
    Serial.println("[LFS] All deret files deleted");
}

int getDeretCount() {
    int count = 0;
    File root = LittleFS.open("/lirik");
    
    if (!root) {
        return 0;
    }
    
    File file = root.openNextFile();
    while (file) {
        String name = file.name();
        if (name.startsWith("/lirik/deret_")) {
            count++;
        }
        file = root.openNextFile();
    }
    
    Serial.print("[LFS] Found ");
    Serial.print(count);
    Serial.println(" deret files");
    
    return count;
}

// Load deret dari LittleFS ke memory
// Returns: pointer ke array Word atau NULL jika gagal
Word* loadDeretFromLittleFS(int slot) {
    String content = readDeretFile(slot);
    
    if (content.length() == 0) {
        Serial.println("[LFS] Using fallback (hardcoded) data");
        return getHardcodedWords(slot);
    }
    
    // Parse JSON
    DynamicJsonDocument doc(2048);
    DeserializationError error = deserializeJson(doc, content);
    
    if (error) {
        Serial.print("[LFS] JSON parse error: ");
        Serial.println(error.c_str());
        return getHardcodedWords(slot);
    }
    
    JsonObject root = doc.as<JsonObject>();
    JsonArray wordsArray = root["words"].as<JsonArray>();
    
    // Allocate dynamic array
    int wordCount = wordsArray.size();
    Word* loadedWords = new Word[wordCount + 1];
    
    // First entry is deret name
    loadedWords[0].time = 0;
    loadedWords[0].text = strdup(root["name"].as<const char*>());
    
    // Load each word
    int i = 1;
    for (JsonObject w : wordsArray) {
        loadedWords[i].time = w["t"].as<float>();
        loadedWords[i].text = strdup(w["w"].as<const char*>());
        i++;
    }
    
    Serial.print("[LFS] Loaded ");
    Serial.print(wordCount);
    Serial.println(" words");
    
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
    return LittleFS.exists(filename);
}

// List semua file di LittleFS
void listLirikFiles() {
    Serial.println("[LFS] Listing /lirik directory:");
    
    File root = LittleFS.open("/lirik");
    if (!root) {
        Serial.println("[LFS] Failed to open directory");
        return;
    }
    
    File file = root.openNextFile();
    while (file) {
        Serial.print("  - ");
        Serial.print(file.name());
        Serial.print(" (");
        Serial.print(file.size());
        Serial.println(" bytes)");
        file = root.openNextFile();
    }
}
