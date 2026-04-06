/**
 * BLE Server untuk menerima data dari Flutter App
 * Menggunakan ESP32 BLE native (BLEDevice.h)
 * 
 * UUID Service: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
 * UUID Char:   beb5483e-36e1-4688-b7f5-ea07361b26a8
 * 
 * Fitur:
 * - Chunk reassembly dengan delimiter [EOF]
 * - Decoupled processing (callback ringan, proses berat di loop)
 * - NOTIFY capability untuk status feedback ke Flutter (opsional)
 */

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

// UUIDs
#define LIRIK_SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define LIRIK_CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"

#include <atomic>

// Buffer untuk menerima data chunk
String bleBuffer = "";
bool bleConnected = false;
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;

// Decoupling: Gunakan atomic agar aman dibaca antar Core (Core 0 vs Core 1)
String payloadToProcess = "";
std::atomic<bool> newPayloadAvailable(false);
std::atomic<uint32_t> loopCounter(0);

// Forward declarations
void parseBlePayload(const String& payload);
bool saveDeretToLittleFS(int slot, const String& name, const String& jsonWords);
void factoryReset();
void sendCheckPayload();
extern bool writeDeretFile(int slot, const String& content);
extern void deleteAllDeretFiles();
extern void listLirikFiles();
extern String buildCheckPayload();

// Helper: kirim notifikasi status ke Flutter (jika tersambung & subscribed)
void notifyStatus(const char* status) {
    if (bleConnected && pCharacteristic != NULL) {
        pCharacteristic->setValue(status);
        pCharacteristic->notify();
        Serial.print("[BLE-NOTIFY] Sent: ");
        Serial.println(status);
    }
}

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        bleConnected = true;
        Serial.println("[BLE] ========================================");
        Serial.println("[BLE] Client CONNECTED");
        Serial.println("[BLE] ========================================");
    }

    void onDisconnect(BLEServer* pServer) {
        bleConnected = false;
        Serial.println("[BLE] ========================================");
        Serial.println("[BLE] Client DISCONNECTED");
        Serial.println("[BLE] ========================================");
        BLEDevice::startAdvertising();
        Serial.println("[BLE] Advertising restarted, waiting for new connection...");
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        
        if (value.length() > 0) {
            String data = String(value.c_str());
            Serial.print("[BLE-RX] Chunk received: ");
            Serial.print(data.length());
            Serial.print(" bytes | Buffer total: ");
            Serial.print(bleBuffer.length() + data.length());
            Serial.println(" bytes");
            
            bleBuffer += data;
            
            int eofPos = bleBuffer.indexOf("[EOF]");
            if (eofPos != -1) {
                String payload = bleBuffer.substring(0, eofPos);
                bleBuffer = bleBuffer.substring(eofPos + 5);
                
                Serial.println("[BLE-RX] ---- [EOF] DETECTED ----");
                
                if (newPayloadAvailable.load()) {
                   Serial.println("[BLE-RX] WARNING: Previous payload still processing, overwriting!");
                }
                
                payloadToProcess = payload;
                newPayloadAvailable.store(true);
            }
        }
    }
};

void initBLE() {
    Serial.println("[BLE] ========================================");
    Serial.println("[BLE] Initializing ESP32 BLE Server...");
    
    BLEDevice::init("Lirik S3");
    Serial.println("[BLE]   Device name: Lirik S3");
    
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    Serial.println("[BLE]   Server created");
    
    BLEService* pService = pServer->createService(LIRIK_SERVICE_UUID);
    Serial.print("[BLE]   Service UUID: ");
    Serial.println(LIRIK_SERVICE_UUID);
    
    // Characteristic: WRITE + NOTIFY (notify untuk feedback status ke Flutter)
    pCharacteristic = pService->createCharacteristic(
        LIRIK_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE_NR | 
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharacteristic->addDescriptor(new BLE2902()); // Descriptor untuk enable/disable notifications
    Serial.print("[BLE]   Char UUID:    ");
    Serial.println(LIRIK_CHAR_UUID);
    Serial.println("[BLE]   Properties:  WRITE + WRITE_NR + NOTIFY");
    
    pCharacteristic->setCallbacks(new MyCallbacks());
    
    pService->start();
    Serial.println("[BLE]   Service started");
    
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(BLEUUID(LIRIK_SERVICE_UUID));
    pAdvertising->setScanResponse(false);
    BLEDevice::startAdvertising();
    
    Serial.println("[BLE]   Advertising started");
    Serial.println("[BLE] Server READY - Waiting for connections...");
    Serial.println("[BLE] ========================================");
}

// Dipanggil di main loop() - proses data BLE yang masuk
void handleBLE() {
    static uint32_t lastTrace = 0;
    if (millis() - lastTrace >= 5000) {
        lastTrace = millis();
        Serial.print("[BLE-TRACE] handleBLE is active. Flag Status: ");
        Serial.println(newPayloadAvailable.load() ? "TRUE" : "FALSE");
    }

    if (newPayloadAvailable.load()) {
        newPayloadAvailable.store(false);
        
        Serial.print("[BLE-LOOP] Processing data. Size: ");
        Serial.print(payloadToProcess.length());
        Serial.println(" bytes.");
        
        parseBlePayload(payloadToProcess);
        
        payloadToProcess = "";
    }
}

void parseBlePayload(const String& payload) {
    Serial.println("[BLE-PARSE] --- Begin JSON parsing ---");
    Serial.print("[BLE-PARSE] Raw Payload: ");
    Serial.println(payload);
    
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, payload);
    
    if (error) {
        Serial.print("[BLE-PARSE] ERROR: JSON parse failed: ");
        Serial.println(error.c_str());
        notifyStatus("ERR:JSON_PARSE");
        return;
    }
    
    // Cek perintah via key "c"
    if (!doc["c"].isNull()) {
        String command = doc["c"].as<String>();
        Serial.print("[BLE-PARSE] Command key 'c' found: ");
        Serial.println(command);

        if (command == "reset") {
            Serial.println("[BLE-PARSE] >> Executing FACTORY RESET...");
            factoryReset();
            notifyStatus("OK:RESET");
            return;
        }
        
        if (command == "check") {
            Serial.println("[BLE-PARSE] >> Executing CHECK STORAGE...");
            sendCheckPayload();
            return;
        }
    }
    
    // Jika bukan command, proses sebagai data lirik (Array atau Object)
    Serial.println("[BLE-PARSE] Not a command, processing as lyric data...");
    
    int successCount = 0;
    int failCount = 0;
    
    if (doc.is<JsonArray>()) {
        JsonArray array = doc.as<JsonArray>();
        Serial.print("[BLE-PARSE] Bulk payload detected: ");
        Serial.print(array.size());
        Serial.println(" derets");
        
        int idx = 0;
        for (JsonObject deret : array) {
            Serial.print("[BLE-PARSE]   Processing item ");
            Serial.println(idx + 1);
            if (processDeret(deret)) successCount++;
            else failCount++;
            idx++;
        }
    } else if (doc.is<JsonObject>()) {
        Serial.println("[BLE-PARSE] Single object payload detected");
        if (processDeret(doc.as<JsonObject>())) successCount++;
        else failCount++;
    }
    
    // Kirim status feedback ke Flutter
    String statusMsg = "OK:" + String(successCount) + "/" + String(successCount + failCount);
    notifyStatus(statusMsg.c_str());
    
    // Debug: List semua file setelah proses
    Serial.println("[BLE-PARSE] --- Post-process file listing ---");
    listLirikFiles();
    Serial.println("[BLE-PARSE] --- End parsing ---");
}

bool processDeret(JsonObject deret) {
    int slot = deret["d"];
    String name = deret["name"].as<String>();
    JsonArray wordsArr = deret["v"].as<JsonArray>();
    
    Serial.println("[BLE-PROC] --------------------------------");
    Serial.print("[BLE-PROC] Deret Slot: ");
    Serial.println(slot);
    Serial.print("[BLE-PROC] Deret Name: ");
    Serial.println(name);
    Serial.print("[BLE-PROC] Word Count: ");
    Serial.println(wordsArr.size());
    
    // Build JSON untuk LittleFS
    String output = "{";
    output += "\"name\":\"" + name + "\",";
    output += "\"words\":[";
    
    int i = 0;
    for (JsonObject w : wordsArr) {
        if (i > 0) output += ",";
        int t = w["t"].as<int>();
        String word = w["w"].as<String>();
        output += "{\"t\":" + String(t) + ",\"w\":\"" + word + "\"}";
        
        if (i < 3 || i == (int)wordsArr.size() - 1) {
            Serial.print("[BLE-PROC]   Word[");
            Serial.print(i);
            Serial.print("]: t=");
            Serial.print(t);
            Serial.print("ms, w=\"");
            Serial.print(word);
            Serial.println("\"");
        } else if (i == 3) {
            Serial.println("[BLE-PROC]   ... (truncated for brevity)");
        }
        i++;
    }
    output += "]}";
    
    Serial.print("[BLE-PROC] JSON output size: ");
    Serial.print(output.length());
    Serial.println(" bytes");
    
    return saveDeretToLittleFS(slot, name, output);
}

void factoryReset() {
    Serial.println("[BLE-RESET] ========================================");
    Serial.println("[BLE-RESET] Performing FACTORY RESET...");
    deleteAllDeretFiles();
    Serial.println("[BLE-RESET] Factory reset COMPLETE");
    Serial.println("[BLE-RESET] ========================================");
}

bool saveDeretToLittleFS(int slot, const String& name, const String& jsonWords) {
    Serial.print("[BLE-SAVE] Saving Deret ");
    Serial.print(slot);
    Serial.print(" (\"");
    Serial.print(name);
    Serial.print("\") to LittleFS... ");
    
    bool success = writeDeretFile(slot, jsonWords);
    
    if (success) {
        Serial.println("SUCCESS");
        Serial.print("[BLE-SAVE] File: /lirik/deret_");
        Serial.print(slot);
        Serial.print(".json (");
        Serial.print(jsonWords.length());
        Serial.println(" bytes)");
    } else {
        Serial.println("FAILED");
        Serial.println("[BLE-SAVE] ERROR: Could not write to LittleFS!");
    }
    return success;
}

/**
 * Baca semua file LittleFS, bangun JSON ringkas (tanpa timestamp),
 * kirim ke Flutter via NOTIFY dalam chunk, diakhiri [DATA_EOF].
 * 
 * Format tiap chunk: text biasa (bagian dari JSON)
 * Akhir data: "[DATA_EOF]" (tanpa newline)
 */
void sendCheckPayload() {
    if (!bleConnected || pCharacteristic == NULL) {
        Serial.println("[BLE-CHECK] ERROR: Cannot send: client NOT connected");
        return;
    }
    
    Serial.println("[BLE-CHECK] Building check payload...");
    String payload = buildCheckPayload();
    String full = payload + "[DATA_EOF]";
    
    Serial.println("[BLE-CHECK] --------------------------------");
    Serial.print("[BLE-CHECK] Final payload size: ");
    Serial.print(full.length());
    Serial.println(" bytes");
    Serial.print("[BLE-CHECK] MTU Status: ");
    Serial.println(pServer->getPeerMTU(pServer->getConnId()));
    
    // Kirim dalam chunk 490 bytes (BLE NOTIFY limit ~512 bytes, sisakan buffer)
    const int CHUNK_SIZE = 490;
    int totalChunks = (full.length() + CHUNK_SIZE - 1) / CHUNK_SIZE;
    
    for (int i = 0; i < (int)full.length(); i += CHUNK_SIZE) {
        String chunk = full.substring(i, min(i + CHUNK_SIZE, (int)full.length()));
        pCharacteristic->setValue(chunk.c_str());
        pCharacteristic->notify();
        
        Serial.print("[BLE-CHECK] SENDING Chunk ");
        Serial.print((i / CHUNK_SIZE) + 1);
        Serial.print("/");
        Serial.print(totalChunks);
        Serial.print(": ");
        Serial.print(chunk.length());
        Serial.println(" bytes.");
        
        // Preview content
        Serial.print("[BLE-CHECK] Content preview: ");
        Serial.println(chunk.substring(0, min((int)chunk.length(), 40)) + "...");
        
        delay(50); // Tambahkan sedikit jeda agar tidak menjebol buffer BLE stack
    }
    
    Serial.println("[BLE-CHECK] SUCCESS: All chunks delivered.");
    Serial.println("[BLE-CHECK] --------------------------------");
}

