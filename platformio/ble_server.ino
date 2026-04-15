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
#include <esp_task_wdt.h>
#include <esp_gap_ble_api.h>
#include <Preferences.h>

// ─── NVS Preferences: Menyimpan versi lirik secara permanen ─────────────────
// Terpisah dari LittleFS → aman dari Factory Reset (LittleFS.format())
Preferences versionPrefs;
String deviceLirikVersion = "0";

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
        bleBuffer = ""; // Reset buffer total saat konek baru
        newPayloadAvailable.store(false);
        Serial.println("[BLE] ========================================");
        Serial.println("[BLE] Client CONNECTED");
        Serial.println("[BLE] ========================================");
    }

    void onDisconnect(BLEServer* pServer) {
        bleConnected = false;
        bleBuffer = ""; // Bersihkan buffer sisa
        newPayloadAvailable.store(false);
        Serial.println("[BLE] ========================================");
        Serial.println("[BLE] Client DISCONNECTED");
        Serial.println("[BLE] ========================================");
        // Restart advertising pakai raw ESP-IDF API (bypass crash-prone wrapper)
        esp_ble_adv_params_t adv_params = {};
        adv_params.adv_int_min = 0x20;
        adv_params.adv_int_max = 0x40;
        adv_params.adv_type = ADV_TYPE_IND;
        adv_params.own_addr_type = BLE_ADDR_TYPE_PUBLIC;
        adv_params.channel_map = ADV_CHNL_ALL;
        adv_params.adv_filter_policy = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY;
        esp_ble_gap_start_advertising(&adv_params);
        Serial.println("[BLE] Advertising restarted, waiting for new connection...");
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        std::string value = pCharacteristic->getValue();
        
        if (value.length() > 0) {
            String data = String(value.c_str());
            bleBuffer += data;
            
            int eofPos = bleBuffer.indexOf("[EOF]");
            if (eofPos != -1) {
                String payload = bleBuffer.substring(0, eofPos);
                bleBuffer = bleBuffer.substring(eofPos + 5);
                Serial.println("[BLE-RX] ---- [EOF] DETECTED ----");
                
                // Tunggu jika sedang proses payload sebelumnya
                while (newPayloadAvailable.load()) {
                    esp_task_wdt_reset();
                    vTaskDelay(10 / portTICK_PERIOD_MS);
                }
                
                payloadToProcess = payload;
                newPayloadAvailable.store(true);
            }
        }
    }
};

// Task Khusus FreeRTOS untuk memproses BLE (Memiliki Stack 8192 bytes sendiri)
void bleWorkerTask(void *pvParameters) {
    for(;;) {
        if (newPayloadAvailable.load()) {
            // Berikan waktu sedikit agar sisa paket stabil
            vTaskDelay(200 / portTICK_PERIOD_MS); 
            
            // Reset watchdog sebelum proses berat
            esp_task_wdt_reset();
            
            String tempPayload = payloadToProcess;
            payloadToProcess = ""; // Clear buffer SEGERA
            newPayloadAvailable.store(false);
            
            // Reset watchdog lagi di tengah proses
            esp_task_wdt_reset();
            parseBlePayload(tempPayload);
            esp_task_wdt_reset();
        }
        // Reset watchdog saat idle
        esp_task_wdt_reset();
        vTaskDelay(50 / portTICK_PERIOD_MS); 
    }
}


void initBLE() {
    Serial.println("[BLE] ========================================");
    Serial.println("[BLE] Initializing ESP32 BLE Server...");
    
    // ─── Inisialisasi NVS Preferences untuk versioning ──────────────────
    versionPrefs.begin("lirik_app", false); // false = read-write
    deviceLirikVersion = versionPrefs.getString("version", "0");
    Serial.print("[BLE]   Lirik Version (NVS): ");
    Serial.println(deviceLirikVersion);
    // ────────────────────────────────────────────────────────────────────
    
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
    
    // ★ BYPASS BLEAdvertising wrapper — langsung pakai ESP-IDF raw API
    //   Wrapper Arduino BLE rentan crash (NULL pointer di handleGAPEvent)
    //   karena heap corruption setelah LittleFS scan
    esp_ble_adv_data_t adv_data = {};
    adv_data.set_scan_rsp = false;
    adv_data.include_name = true;
    adv_data.include_txpower = false;
    adv_data.min_interval = 0x20;   // 20ms
    adv_data.max_interval = 0x40;   // 40ms
    adv_data.flag = (ESP_BLE_ADV_FLAG_GEN_DISC | ESP_BLE_ADV_FLAG_BREDR_NOT_SPT);
    
    esp_err_t ret = esp_ble_gap_config_adv_data(&adv_data);
    if (ret) {
        Serial.printf("[BLE]   WARNING: adv_data config failed: %d\n", ret);
    }
    
    esp_ble_adv_params_t adv_params = {};
    adv_params.adv_int_min = 0x20;
    adv_params.adv_int_max = 0x40;
    adv_params.adv_type = ADV_TYPE_IND;
    adv_params.own_addr_type = BLE_ADDR_TYPE_PUBLIC;
    adv_params.channel_map = ADV_CHNL_ALL;
    adv_params.adv_filter_policy = ADV_FILTER_ALLOW_SCAN_ANY_CON_ANY;
    
    delay(50); // Beri waktu BLE stack siap
    
    ret = esp_ble_gap_start_advertising(&adv_params);
    if (ret) {
        Serial.printf("[BLE]   WARNING: start_advertising failed: %d\n", ret);
    } else {
        Serial.println("[BLE]   Advertising started (ESP-IDF raw API)");
    }
    
    // Register task ke watchdog agar tidak trigger
    esp_task_wdt_add(NULL);
    
    // Spawn FreeRTOS Task untuk Background Processing
    // PENTING: Jalankan di Core 0, BUKAN Core 1
    // Core 1 = BLE stack + Arduino loop() → jangan dibebani LittleFS write
    // Core 0 = Bebas untuk JSON parsing + file I/O berat
    xTaskCreatePinnedToCore(
        bleWorkerTask,    // Fungsi Task
        "BLE_Worker",     // Nama Task
        10240,            // Stack 10KB (naik dari 8KB, karena LittleFS butuh ruang stack lebih)
        NULL,             // Parameter
        1,                // Prioritas
        NULL,             // Task Handle
        0                 // Jalankan di Core 0 (pisah dari BLE stack)
    );
    Serial.println("[BLE]   Background Worker Task Started");
}

// Dipanggil di main loop() - proses data BLE yang masuk
void handleBLE() {
    // Fungsi ini tidak dipakai lagi karena data diproses oleh bleWorkerTask
}

extern bool isSyncing;

void parseBlePayload(const String& payload) {
    // ─── Perintah Khusus Versioning (Non-JSON) ──────────────────────────
    // Diproses SEBELUM JSON parser agar tidak mengganggu alur data lirik.
    if (payload.startsWith("@GET_VERSION")) {
        Serial.println("[BLE-CMD] GET_VERSION request received");
        notifyStatus(deviceLirikVersion.c_str());
        return; // Selesai, tidak perlu proses lebih lanjut
    }
    if (payload.startsWith("@SET_VERSION:")) {
        String newVer = payload.substring(13); // potong prefix "@SET_VERSION:"
        newVer.trim();
        versionPrefs.putString("version", newVer);
        deviceLirikVersion = newVer;
        Serial.print("[BLE-CMD] SET_VERSION: ");
        Serial.println(newVer);
        notifyStatus("ACK_VER");
        return; // Selesai
    }
    if (payload.startsWith("@SET_TIME:")) {
        // Format: "@SET_TIME:14:30:00"
        String timeStr = payload.substring(10); // "14:30:00"
        int firstColon = timeStr.indexOf(':');
        int secondColon = timeStr.lastIndexOf(':');
        
        if (firstColon != -1 && secondColon != -1 && firstColon != secondColon) {
            byte h = timeStr.substring(0, firstColon).toInt();
            byte m = timeStr.substring(firstColon + 1, secondColon).toInt();
            byte s = timeStr.substring(secondColon + 1).toInt();
            
            extern void setRtcTime(byte h, byte m, byte s);
            setRtcTime(h, m, s);
            
            notifyStatus("OK:TIME");
        } else {
            notifyStatus("ERR:TIME_FMT");
        }
        return;
    }
    // ─── Perintah Memory Report (Non-JSON) ───────────────────────────────
    if (payload.startsWith("@GET_MEMORY")) {
        Serial.println("[BLE-CMD] GET_MEMORY request received");
        extern size_t totalPsramSize;
        extern size_t safePsramThreshold;
        extern int activeDaretCount;
        
        String memReport = String("{\"psram_total\":") + String((unsigned long)totalPsramSize) +
                           ",\"psram_free\":" + String((unsigned long)ESP.getFreePsram()) +
                           ",\"psram_gate\":" + String((unsigned long)safePsramThreshold) +
                           ",\"heap_free\":" + String((unsigned long)ESP.getFreeHeap()) +
                           ",\"flash_total\":" + String((unsigned long)LittleFS.totalBytes()) +
                           ",\"flash_free\":" + String((unsigned long)(LittleFS.totalBytes() - LittleFS.usedBytes())) +
                           ",\"slots\":" + String(activeDaretCount) + "}";
        notifyStatus(memReport.c_str());
        return;
    }
    // ────────────────────────────────────────────────────────────────────

    // Ambil alih Layar TFT: Hentikan loop() di Core 1 agar SPI tidak tabrakan
    isSyncing = true;
    
    Serial.print("[BLE-PARSE] Received payload length: ");
    Serial.print(payload.length());
    Serial.println(" bytes");

    // Meningkatkan buffer JSON karena lirik 10 deret butuh memori besar (>12KB)
    // 24KB cukup untuk ~250-300 kata total dengan metadata
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, payload);
    
    if (error) {
        Serial.print("[BLE-PARSE] ERROR: JSON parse failed: ");
        Serial.println(error.c_str());
        notifyStatus("ERR:JSON_PARSE");
        isSyncing = false; // Lepas kunci layar
        return;
    }
    
    // Cek perintah via key "c"
    if (!doc["c"].isNull()) {
        String command = doc["c"].as<String>();
        if (command == "reset") {
            Serial.println("[BLE-CMD] Factory Reset initiated");
            factoryReset();
            notifyStatus("OK:RESET");
            isSyncing = false; // Lepas kunci layar
            return;
        }
        if (command == "check") {
            Serial.println("[BLE-CMD] Check Storage initiated");
            sendCheckPayload();
            isSyncing = false; // Lepas kunci layar
            return;
        }
    }
    
    int successCount = 0;
    int failCount = 0;
    
    if (doc.is<JsonArray>()) {
        JsonArray array = doc.as<JsonArray>();
        int total = array.size();
        int current = 0;
        for (JsonObject deret : array) {
            current++;
            esp_task_wdt_reset(); // Beritahu satpam: "Saya masih hidup!"
            
            showSyncingUI(deret["d"] | current, total);
            if (processDeret(deret)) successCount++;
            else failCount++;
            
            // Berikan napas lebih lega di sela-sela slot yang berat
            vTaskDelay(200 / portTICK_PERIOD_MS); 
        }
    } else if (doc.is<JsonObject>()) {
        esp_task_wdt_reset();
        showSyncingUI(doc["d"] | 1, 1);
        if (processDeret(doc.as<JsonObject>())) successCount++;
        else failCount++;
    }
    
    // Berikan delay final agar file system menutup handle dengan sempurna
    vTaskDelay(500 / portTICK_PERIOD_MS);

    // Kirim status feedback ke Flutter HANYA setelah semua proses TULIS selesai
    String statusMsg = "OK:" + String(successCount) + "/" + String(successCount + failCount);
    notifyStatus(statusMsg.c_str());
    
    // Tampilkan pesan sukses di TFT sebentar sebelum balik ke menu
    tft.fillRect(0, 40, 128, 80, ST77XX_BLACK);
    tft.drawRect(5, 45, 118, 70, ST77XX_GREEN);
    tft.setCursor(15, 75);
    tft.setTextColor(ST77XX_GREEN);
    tft.print("SYNC SUCCESS!");
    vTaskDelay(3000 / portTICK_PERIOD_MS);
    
    // ★ Re-scan slot setelah sinkronisasi selesai
    extern int activeDaretCount;
    extern int scanDeretSlots();
    activeDaretCount = scanDeretSlots();
    Serial.printf("[BLE-SYNC] Updated activeDaretCount: %d\n", activeDaretCount);
    
    hideSyncingUI();
    listLirikFiles();
    isSyncing = false; // Lepas kunci layar: Kembalikan akses ke Core 1
}

bool processDeret(JsonObject deret) {
    // ★ Memory Safety Gate sebelum proses write
    extern bool checkMemorySafety();
    if (!checkMemorySafety()) {
        Serial.println("[BLE-PROC] BLOCKED: Memory full, skipping slot!");
        notifyStatus("ERR:MEM_FULL");
        return false;
    }
    
    int slot = deret["d"];
    String name = deret["name"].as<String>();
    JsonArray wordsArr = deret["v"].as<JsonArray>(); // Flutter pakai key "v" untuk array lirik
    
    Serial.println("[BLE-PROC] --------------------------------");
    Serial.print("[BLE-PROC] Slot: ");
    Serial.print(slot);
    Serial.print(" | Name: ");
    Serial.print(name);
    Serial.print(" | Words: ");
    Serial.println(wordsArr.size());
    
    // Build JSON untuk LittleFS
    String output = "{";
    output += "\"name\":\"" + name + "\",";
    output += "\"words\":[";
    
    int i = 0;
    for (JsonObject w : wordsArr) {
        if (i > 0) output += ",";
        int t = w["t"].as<int>();
        String wordText = w["w"].as<String>();
        
        output += "{\"t\":" + String(t) + ",\"w\":\"" + wordText + "\"}";
        i++;
    }
    output += "]}";
    
    Serial.print("[BLE-PROC] JSON output size: ");
    Serial.print(output.length());
    Serial.println(" bytes");
    
    bool result = saveDeretToLittleFS(slot, name, output);
    
    // Memberikan napas bagi core 0 dan LittleFS antar deret (pengereman sengaja)
    vTaskDelay(100 / portTICK_PERIOD_MS); 
    
    return result;
}

void factoryReset() {
    Serial.println("[BLE-RESET] ========================================");
    Serial.println("[BLE-RESET] Performing FACTORY RESET...");
    deleteAllDeretFiles();
    
    // ★ Reset dynamic slot count ke default
    extern int activeDaretCount;
    activeDaretCount = 10;
    
    Serial.println("[BLE-RESET] activeDaretCount reset to 10");
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

