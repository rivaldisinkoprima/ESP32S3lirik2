/**
 * File / Deret Menu Display
 * Menampilkan daftar deret dan isi kata-kata per deret di layar TFT.
 * 
 * Optimasi: 10 fungsi displayderet identik dikonsolidasikan menjadi 1 fungsi generik.
 */

const char* menuItems[] = {"DERET 1", "DERET 2", "DERET 3", "DERET 4", "DERET 5", 
                           "DERET 6", "DERET 7", "DERET 8", "DERET 9", "DERET 10"};

// Array pointer ke semua deret (untuk akses generik)
const char** allDerets[] = {deret1, deret2, deret3, deret4, deret5, 
                            deret6, deret7, deret8, deret9, deret10};

// Ukuran masing-masing deret (karena tidak semua sama, misal deret9 = 20 elemen)
const int deretSizes[] = {
    sizeof(deret1) / sizeof(deret1[0]),
    sizeof(deret2) / sizeof(deret2[0]),
    sizeof(deret3) / sizeof(deret3[0]),
    sizeof(deret4) / sizeof(deret4[0]),
    sizeof(deret5) / sizeof(deret5[0]),
    sizeof(deret6) / sizeof(deret6[0]),
    sizeof(deret7) / sizeof(deret7[0]),
    sizeof(deret8) / sizeof(deret8[0]),
    sizeof(deret9) / sizeof(deret9[0]),
    sizeof(deret10) / sizeof(deret10[0])
};

const int menuCount = sizeof(menuItems) / sizeof(menuItems[0]);
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
 * Fungsi generik untuk menampilkan isi deret di layar TFT.
 * @param deretIndex Index 0-based (0 = Deret 1, 9 = Deret 10)
 * @param page Halaman yang ditampilkan
 */
void displayDeretGeneric(int deretIndex, int page) {
    posisi = 5;
    tft.fillScreen(ST77XX_BLACK);
    tft.setTextColor(ST77XX_MAGENTA);
    tft.setCursor(33, 36);
    tft.print("DERET ");
    tft.print(deretIndex + 1); // Tampilkan nomor 1-based
    tft.setTextColor(ST77XX_WHITE);
    
    int totalKataInDeret = deretSizes[deretIndex];
    int startIdx = page * kataPerHalaman;
    int endIdx = min(startIdx + kataPerHalaman, totalKataInDeret);

    for (int i = startIdx; i < endIdx; i++) {
        tft.setCursor(10, 10 + (i - startIdx) * 15 + 45);
        tft.println(allDerets[deretIndex][i]);
    }
    tampiljam();
    bat_cas_move();
}

/**
 * Helper: hitung total halaman untuk deret tertentu.
 */
int getDeretPageCount(int deretIndex) {
    int totalKata = deretSizes[deretIndex];
    return (totalKata + kataPerHalaman - 1) / kataPerHalaman;
}