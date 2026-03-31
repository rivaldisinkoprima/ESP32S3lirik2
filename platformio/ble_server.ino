/**
 * BLE Server untuk menerima data dari Flutter App
 * Menggunakan ESP32 BLE native (BLEDevice.h)
 * 
 * UUID Service: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
 * UUID Char:   beb5483e-36e1-4688-b7f5-ea07361b26a8
 */

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// UUIDs
#define LIRIK_SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define LIRIK_CHAR_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Buffer untuk menerima data chunk
String bleBuffer = "";
bool bleConnected = false;
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;

// Forward declarations
void parseBlePayload(const String& payload);
void saveDeretToLittleFS(int slot, const String& name, const String& jsonWords);
void factoryReset();

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        bleConnected = true;
        Serial.println("[BLE] Client connected");
    }

    void onDisconnect(BLEServer* pServer) {
        bleConnected = false;
        Serial.println("[BLE] Client disconnected");
        // Restart advertising
        BLEDevice::startAdvertising();
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        
        if (value.length() > 0) {
            String data = String(value.c_str());
            Serial.print("[BLE] Received: ");
            Serial.print(data.length());
            Serial.println(" bytes");
            
            // Tambah ke buffer
            bleBuffer += data;
            
            // Cek delimiter [EOF]
            int eofPos = bleBuffer.indexOf("[EOF]");
            if (eofPos != -1) {
                String payload = bleBuffer.substring(0, eofPos);
                bleBuffer = bleBuffer.substring(eofPos + 5); // Clear buffer after [EOF]
                
                Serial.println("[BLE] Processing payload...");
                parseBlePayload(payload);
            }
        }
    }
};

void initBLE() {
    Serial.println("[BLE] Initializing ESP32 BLE...");
    
    // Create device
    BLEDevice::init("Lirik S3");
    
    // Get server
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    
    // Create service
    BLEService* pService = pServer->createService(LIRIK_SERVICE_UUID);
    
    // Create characteristic (write only)
    pCharacteristic = pService->createCharacteristic(
        LIRIK_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE_NR | BLECharacteristic::PROPERTY_WRITE
    );
    
    pCharacteristic->setCallbacks(new MyCallbacks());
    
    // Start service
    pService->start();
    
    // Start advertising
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(BLEUUID(LIRIK_SERVICE_UUID));
    pAdvertising->setScanResponse(false);
    BLEDevice::startAdvertising();
    
    Serial.println("[BLE] Server started - Waiting for connections...");
    Serial.println("[BLE] Device Name: Lirik S3");
    Serial.print("[BLE] Service UUID: ");
    Serial.println(LIRIK_SERVICE_UUID);
}

void parseBlePayload(const String& payload) {
    // Parse JSON menggunakan ArduinoJson
    DynamicJsonDocument doc(4096);
    
    DeserializationError error = deserializeJson(doc, payload);
    
    if (error) {
        Serial.print("[BLE] JSON parse error: ");
        Serial.println(error.c_str());
        return;
    }
    
    // Cek factory reset
    if (doc.containsKey("c") && doc["c"] == "reset") {
        Serial.println("[BLE] Factory Reset command received!");
        factoryReset();
        return;
    }
    
    // Proses array atau single object
    if (doc.is<JsonArray>()) {
        JsonArray array = doc.as<JsonArray>();
        Serial.print("[BLE] Bulk payload: ");
        Serial.print(array.size());
        Serial.println(" derets");
        
        for (JsonObject deret : array) {
            processDeret(deret);
        }
    } else if (doc.is<JsonObject>()) {
        JsonObject deret = doc.as<JsonObject>();
        Serial.println("[BLE] Single deret received");
        processDeret(deret);
    }
}

void processDeret(JsonObject deret) {
    int slot = deret["d"];
    String name = deret["name"].as<String>();
    JsonArray words = deret["v"].as<JsonArray>();
    
    Serial.print("[BLE] Processing Deret ");
    Serial.println(slot);
    
    // Build JSON untuk LittleFS
    String output = "{";
    output += "\"name\":\"" + name + "\",";
    output += "\"words\":[";
    
    int i = 0;
    for (JsonObject w : words) {
        if (i > 0) output += ",";
        output += "{\"t\":" + String(w["t"].as<int>()) + ",\"w\":\"" + w["w"].as<String>() + "\"}";
        i++;
    }
    output += "]}";
    
    // Simpan ke LittleFS
    saveDeretToLittleFS(slot, name, output);
}

void factoryReset() {
    Serial.println("[BLE] Performing factory reset...");
    
    // Hapus semua file deret (anggil fungsi dari littlefs_handler.ino)
    // deleteAllDeretFiles(); // Uncomment after LittleFS init
    
    Serial.println("[BLE] Factory reset complete");
}

void saveDeretToLittleFS(int slot, const String& name, const String& jsonWords) {
    // NOTE: LittleFS belum di-init di file ini
    // Akan diimplementasikan di littlefs_handler.ino
    
    Serial.print("[BLE] Would save Deret ");
    Serial.print(slot);
    Serial.print(" (");
    Serial.print(name);
    Serial.println(") to LittleFS");
    
    // Contoh cara simpan (uncomment setelah LittleFS ready):
    // writeDeretFile(slot, jsonWords);
}

// Handle BLE di loop
void handleBLE() {
    // BLE runs async, no need to call anything here
}
