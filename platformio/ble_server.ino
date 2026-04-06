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

// Buffer untuk menerima data chunk
String bleBuffer = "";
bool bleConnected = false;
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;

// Decoupling: pindahkan proses berat dari callback ke main loop
String payloadToProcess = "";
volatile bool newPayloadAvailable = false;

// Forward declarations
void parseBlePayload(const String& payload);
bool saveDeretToLittleFS(int slot, const String& name, const String& jsonWords);
void factoryReset();
extern bool writeDeretFile(int slot, const String& content);
extern void deleteAllDeretFiles();
extern void listLirikFiles();

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
                
                if (newPayloadAvailable) {
                   Serial.println("[BLE-RX] WARNING: Previous payload still processing, overwriting!");
                }
                
                payloadToProcess = payload;
                newPayloadAvailable = true;
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
    if (newPayloadAvailable) {
        newPayloadAvailable = false;
        
        Serial.print("[BLE-LOOP] Processing complete payload size: ");
        Serial.print(payloadToProcess.length());
        Serial.println(" bytes");
        
        parseBlePayload(payloadToProcess);
        
        payloadToProcess = "";
        Serial.println("[BLE-LOOP] Done.");
    }
}

void parseBlePayload(const String& payload) {
    Serial.println("[BLE-PARSE] --- Begin JSON parsing ---");
    
    // Parse JSON (ArduinoJson 7 syntax)
    // JsonDocument otomatis mengatur alokasi memori secara dinamis di stack/heap 
    // sesuai besar payload yang diterima (sudah sangat efisien di AJ7)
    JsonDocument doc;
    
    DeserializationError error = deserializeJson(doc, payload);
    
    if (error) {
        Serial.print("[BLE-PARSE] ERROR: JSON parse failed: ");
        Serial.println(error.c_str());
        notifyStatus("ERR:JSON_PARSE");
        return;
    }
    
    Serial.println("[BLE-PARSE] JSON parsed successfully");
    Serial.print("[BLE-PARSE] Memory used: ");
    Serial.print(doc.memoryUsage());
    Serial.println(" bytes");
    
    // Cek factory reset
    if (doc.containsKey("c") && doc["c"] == "reset") {
        Serial.println("[BLE-PARSE] >> FACTORY RESET command received!");
        factoryReset();
        notifyStatus("OK:RESET");
        return;
    }
    
    // Proses array atau single object
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
            Serial.print(idx + 1);
            Serial.print("/");
            Serial.println(array.size());
            if (processDeret(deret)) successCount++;
            else failCount++;
            idx++;
        }
        Serial.println("[BLE-PARSE] Bulk processing complete");
    } else if (doc.is<JsonObject>()) {
        JsonObject deret = doc.as<JsonObject>();
        Serial.println("[BLE-PARSE] Single deret payload detected");
        if (processDeret(deret)) successCount++;
        else failCount++;
    } else {
        Serial.println("[BLE-PARSE] ERROR: Unknown JSON structure");
        notifyStatus("ERR:UNKNOWN_FORMAT");
        return;
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
