/**
 * File / Deret Menu Display
 * Menampilkan daftar deret dan isi kata-kata per deret di layar TFT.
 * 
 * Optimasi: 10 fungsi displayderet identik dikonsolidasikan menjadi 1 fungsi generik.
 */

const char* menuItems[] = {"DERET 1", "DERET 2", "DERET 3", "DERET 4", "DERET 5", 
                           "DERET 6", "DERET 7", "DERET 8", "DERET 9", "DERET 10"};

const int menuCount = 10;
const int itemsPerPage = 5;
int selectedIndex = 0;
int page = 0;
int displaymenu;

const int kataPerHalaman = 7;
int halaman = 0;

void file(){
  displaymenu = 1;
  posisi = 4;
  displayMenu();
}

void displayMenu() {
    displaymenu = 1;
    tft.fillScreen(ST77XX_BLACK);
    tft.setCursor(45,36);
    tft.print("FILE");
    for (int i = 0; i < itemsPerPage; i++) {
        int index = page * itemsPerPage + i;
        if (index < menuCount) {
            tft.setCursor(10, (i + 2) * 15 + 30);
            if (index == selectedIndex) {
                tft.setTextColor(ST77XX_YELLOW, ST77XX_BLACK);
            } else {
                tft.setTextColor(ST77XX_WHITE, ST77XX_BLACK);
            }
            tft.print(menuItems[index]);
            posisi = 4;
        }
    } 
    tft.setTextColor(ST77XX_WHITE);
    Serial.println(selectedIndex);
    tampiljam();
    bat_cas_move();
}

/**
 * Fungsi generik untuk menampilkan isi deret di layar TFT menggunakan LittleFS.
 */
void displayDeretGeneric(int deretIndex, int page) {
    posisi = 5;
    tft.fillScreen(ST77XX_BLACK);
    
    int currentSlot = deretIndex + 1;
    
    if (!deretExistsInLittleFS(currentSlot)) {
        tft.setTextColor(ST77XX_RED);
        tft.setCursor(10, 80);
        tft.print("DATA KOSONG");
        tft.setCursor(10, 100);
        tft.setTextSize(1);
        tft.print("Kirim dari aplikasi");
        tampiljam();
        return;
    }

    tft.setTextColor(ST77XX_MAGENTA);
    tft.setCursor(33, 36);
    tft.print("DERET ");
    tft.print(currentSlot); 

    // Muat sementara hanya untuk ditampilkan di menu File
    Word* tempWords = loadDeretFromLittleFS(currentSlot);
    if (tempWords == NULL) return;

    tft.setTextColor(ST77XX_WHITE);
    int totalWordsInSlot = loadedWordCount; 
    int startIdx = page * kataPerHalaman;
    int endIdx = min(startIdx + kataPerHalaman, totalWordsInSlot);

    for (int i = startIdx; i < endIdx; i++) {
        tft.setCursor(10, 10 + (i - startIdx) * 15 + 45);
        if (tempWords[i].text != NULL) {
            tft.println(tempWords[i].text);
        }
    }
    
    // Bersihkan memori sementara
    for (int i = 0; i < totalWordsInSlot; i++) {
        if (tempWords[i].text != NULL) free((void*)tempWords[i].text);
    }
    delete[] tempWords;

    tampiljam();
    bat_cas_move();
}

int getDeretPageCount(int deretIndex) {
    // Return default atau bisa dioptimasi dengan load file sesaat
    return 3; 
}