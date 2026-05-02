/**
 * File / Deret Menu Display
 * Menampilkan daftar deret dan isi kata-kata per deret di layar TFT.
 * 
 * Fully Dynamic: Menu menyesuaikan jumlah file aktual di LittleFS
 * Batas maks: 255 (sesuai limit DFPlayer Mini per folder)
 */

// extern variabel dari main
extern int activeDaretCount;

// Buffer untuk label menu dinamis (max 255 slot sesuai limit DFPlayer)
#define MAX_DERET_SLOTS 50
char menuLabelBuffer[MAX_DERET_SLOTS][16];

const char* getMenuItem(int index) {
    if (index < 0 || index >= MAX_DERET_SLOTS) return "DERET ?";
    return menuLabelBuffer[index];
}

void updateMenuLabels() {
    // Build label berdasarkan activeDaretCount
    for (int i = 0; i < MAX_DERET_SLOTS; i++) {
        snprintf(menuLabelBuffer[i], sizeof(menuLabelBuffer[i]), "DERET %d", i + 1);
    }
}

int getMenuCount() {
    int count = activeDaretCount;
    if (count < 1) count = 1;
    if (count > MAX_DERET_SLOTS) count = MAX_DERET_SLOTS;
    return count;
}

const int itemsPerPage = 5;
int selectedIndex = 0;
int page = 0;
int displaymenu;

const int kataPerHalaman = 7;
int halaman = 0;

void file(){
  displaymenu = 1;
  posisi = 4;
  updateMenuLabels(); // Refresh label berdasarkan activeDaretCount terkini
  displayMenu();
}

void displayMenu() {
    displaymenu = 1;
    // Gunakan GFXcanvas16 untuk buffering agar tidak flicker (Mulus tanpa berkedip)
    GFXcanvas16 canvas(128, 140);
    canvas.setFont(&FreeSans9pt7b);
    canvas.fillScreen(ST77XX_BLACK);
    canvas.setCursor(45, 16); // offset -20
    canvas.print("FILE");
    for (int i = 0; i < itemsPerPage; i++) {
        int index = page * itemsPerPage + i;
        if (index < getMenuCount()) {
            canvas.setCursor(10, (i + 2) * 15 + 10); // offset -20
            if (index == selectedIndex) {
                canvas.setTextColor(ST77XX_YELLOW, ST77XX_BLACK);
            } else {
                canvas.setTextColor(ST77XX_WHITE, ST77XX_BLACK);
            }
            canvas.print(getMenuItem(index));
            posisi = 4;
        }
    } 
    canvas.setTextColor(ST77XX_WHITE);
    
    // Push buffer ke layar
    tft.drawRGBBitmap(0, 20, canvas.getBuffer(), 128, 140);

    Serial.println(selectedIndex);
    tampiljam();
    bat_cas_move();
}

/**
 * Fungsi generik untuk menampilkan isi deret di layar TFT menggunakan LittleFS.
 */
void displayDeretGeneric(int deretIndex, int page) {
    posisi = 5;
    
    GFXcanvas16 canvas(128, 140);
    canvas.fillScreen(ST77XX_BLACK);
    
    int currentSlot = deretIndex + 1;
    
    if (!deretExistsInLittleFS(currentSlot)) {
        canvas.drawRect(10, 30, 108, 80, ST77XX_YELLOW);
        
        canvas.setTextColor(ST77XX_YELLOW);
        canvas.setCursor(30, 65);
        canvas.setTextSize(2);
        canvas.print("KOSONG");
        
        tft.drawRGBBitmap(0, 20, canvas.getBuffer(), 128, 140);
        tampiljam();
        bat_cas_move();
        return;
    }

    canvas.setTextColor(ST77XX_MAGENTA);
    canvas.setCursor(33, 16); // offset -20
    canvas.print("DERET ");
    canvas.print(currentSlot); 

    // Muat sementara hanya untuk ditampilkan di menu File
    Word* tempWords = loadDeretFromLittleFS(currentSlot);
    if (tempWords == NULL) {
        tft.drawRGBBitmap(0, 20, canvas.getBuffer(), 128, 140);
        tampiljam();
        bat_cas_move();
        return;
    }

    canvas.setTextColor(ST77XX_WHITE);
    int totalWordsInSlot = loadedWordCount; 
    int startIdx = page * kataPerHalaman;
    int endIdx = min(startIdx + kataPerHalaman, totalWordsInSlot);

    for (int i = startIdx; i < endIdx; i++) {
        canvas.setCursor(10, 10 + (i - startIdx) * 15 + 25); // offset -20
        if (tempWords[i].text != NULL) {
            canvas.println(tempWords[i].text);
        }
    }
    
    // Bersihkan memori sementara
    for (int i = 0; i < totalWordsInSlot; i++) {
        if (tempWords[i].text != NULL) free((void*)tempWords[i].text);
    }
    delete[] tempWords;

    tft.drawRGBBitmap(0, 20, canvas.getBuffer(), 128, 140);
    tampiljam();
    bat_cas_move();
}

int getDeretPageCount(int deretIndex) {
    // Return default atau bisa dioptimasi dengan load file sesaat
    return 3; 
}