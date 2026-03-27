const char* menuItems[] = {"DERET 1", "DERET 2", "DERET 3", "DERET 4", "DERET 5", 
                           "DERET 6", "DERET 7", "DERET 8", "DERET 9", "DERET 10"};

// const char* deret1[] = {"1. SABUN", "2. KUDA", "3. DINGIN", "4. BANYAK", "5. GULA", 
//                            "6. PIPI", "7. BESAR", "8. ENAK", "9. LIDAH", "10. KEMBAR",
//                            "11. UMUR", "12. SALON", "13. TIKUS", "14. PANAH", "15. BECAK", 
//                            "16. NASI", "17. ILMU", "18. KAMAR", "19. TELOR", "20. TEMPAT"};

// const char* deret2[] = {"1. WALI", "2. HAKIM", "3. PISTOL", "4. KORBAN", "5. DOSA", "6. BELI", 
//                         "7. MEDAN", "8. KUMAN","9. NAIK", "10. ADIK", "11. IBU", "12. TUGAS", "13. JARUM",
//                         "14. SALEP", "15. KABAR", "16. TOMAT", "17. KAPUR", "18. ANGIN", "19. ENCER", "20. MUSUH"};

// const char* deret3[] = {"1. TULI", "2. PADI", "3. KELAS", "4. RAMBUT", "5. NYAMUK", "6. GARAM",
//                         "7. BIDAN", "8. BUMI","9. KERAS", "10. NIKAH", "11. OBAT", "12. KARCIS", "13. DALANG", "14. MESIN",
//                         "15. KUPON", "16. TAHUN", "17. RESEP", "18. BUKU", "19. MATA", "20. LILIN"};

// const char* deret4[] = {"1. SAYANG", "2. KAMPUS", "3. HARI ", "4. OBRAL", "5. KENAL", "6. HAMIL",
//                         "7. KITAB", "8. GANTI","9. SAPI", "10. JERUK", "11. RINDU", "12. HANTU", "13. MADU", "14. SEMIR",
//                         "15. SAKIT", "16. LOMBA", "17. PENCAK", "18. BATUK", "19. DEBU", "20. BAKMI"};

// const char* deret5[] = {"1. ANAK", "2. DARAH", "3. USUL", "4. TEMBAK", "5. MINUM", "6. API",
//                         "7. BULAN", "8. KILAT","9. BERSIH", "10. KUNCI", "11. SEDAP", "12. PASAR", "13. DOKTER", "14. BETON",
//                         "15. MULUT", "16. PAGI", "17. AKAL", "18. MISKIN", "19. BARU", "20. KENYANG"};

// const char* deret6[] = {"1. IMAN", "2. POLA", "3. BUKIT", "4. LIBUR", "5. GADIS", "6. DAPUR",
//                         "7. JALAN", "8. PENDEK","9. CAMBUK", "10. KEMBANG", "11. HALUS", "12. MUMI", "13. SEMUT", "14. KIRI",
//                         "15. OTAK", "16. PESTA", "17. RUKUN", "18. NASIB", "19. TANAH", "20. AYAM"};

// const char* deret7[] = {"1. SUNTIK", "2. BARU", "3. NYAWA", "4. KECAP", "5. BOLA", "6. MAKAN",
//                         "7. MURID", "8. SAMPAH","9. NENEK", "10. LEHER", "11. ASIN", "12. KABEL", "13. SOAL", "14. KAIN",
//                         "15. TIDUR", "16. BAIK", "17. GURU", "18. RUMPUT", "19. DIAM", "20. PLASTIK"};

// const char* deret8[] = {"1. TAKSI", "2. PERUT", "3. NONA", "4. PISANG", "5. HUKUM", "6. MEJA",
//                         "7. BADAN", "8. LAMPU","9. GAMBAR", "10. LISTRIK", "11. UMUM", "12. PENSIL", "13. BUAH", "14. CINA",
//                         "15. KOREK", "16. BANTAL", "17. MANDI", "18. BAKUL", "19. KURSI", "20. TEKAD"};

// const char* deret9[] = {"1. HATI", "2. KOLAM", "3. BUTA", "4. YAKIN", "5. GEMUK", "6. DINAS",
//                         "7. BUDI", "8. LUPA","9. KERIS", "10. KOPI", "11. AMAL", "12. TAMU", "13. LEMBUR", "14. SANDANG",
//                         "15. KECIL", "16. BANJIR", "17. PANAS", "18. MURAH", "19. TUAN"};

// const char* deret10[] = {"1. TEMPO", "2. PINTU", "3. HOTEL", "4. MINYAK", "5. BASAH", "6. MODAL",
//                         "7. BERAS", "8. DUKUN","9. KULIT", "10. BATIK", "11. IKAN", "12. DESA", "13. AIR", "14. KAMPUNG",
//                         "15. LINTAH", "16. MACAN", "17. SUMUR", "18. BENSIN", "19. PERAK", "20. LAGU"};

const int menuCount = sizeof(menuItems) / sizeof(menuItems[0]);
const int itemsPerPage = 5;
int selectedIndex = 0;
int page = 0;
int displaymenu;

const int totalKata = sizeof(deret1) / sizeof(deret1[0]);
const int kataPerHalaman = 7;
int halaman = 0;

void file(){
  displaymenu = 1; // Set agar hanya menampilkan daftar file
    posisi = 4; // Set posisi ke 4 (mode pemilihan file)
    displayMenu();
}

void displayMenu() {
    // myDFPlayer.stop();
    // isPlaying = true;
    displaymenu = 1;
    tft.fillScreen(ST77XX_BLACK);
    tft.setCursor(45,36);
    tft.print("FILE");
    for (int i = 0; i < itemsPerPage; i++) {
        int index = page * itemsPerPage + i;
        if (index < menuCount) {
            tft.setCursor(10, (i + 2) * 15 + 30); // Geser ke bawah 30 pixel
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

void displayderet1(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layaR
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(35,36);
  tft.print("DERET 1");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret1[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet2(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layar
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(33,36);
  tft.print("DERET 2");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret2[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet3(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layar
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(33,36);
  tft.print("DERET 3");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret3[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet4(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layar
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(33,36);
  tft.print("DERET 4");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret4[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet5(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layar
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(33,36);
  tft.print("DERET 5");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret5[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet6(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layaR
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(35,36);
  tft.print("DERET 6");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret6[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet7(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layar
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(33,36);
  tft.print("DERET 7");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret7[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet8(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layar
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(33,36);
  tft.print("DERET 8");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret8[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet9(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layar
  tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(33,36);
  tft.print("DERET 9");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret9[i]);
  }
    tampiljam();
    bat_cas_move();
}

void displayderet10(int page) {
  posisi = 5;
  tft.fillScreen(ST77XX_BLACK);  // Hapus layar
    tft.setTextColor(ST77XX_MAGENTA);
  tft.setCursor(33,36);
  tft.print("DERET 10");
  tft.setTextColor(ST77XX_WHITE);
  int startIdx = page * kataPerHalaman;
  int endIdx = min(startIdx + kataPerHalaman, totalKata);

  for (int i = startIdx; i < endIdx; i++) {
    tft.setCursor(10, 10 + (i - startIdx) * 15+45);
    tft.println(deret10[i]);
  }
    tampiljam();
    bat_cas_move();
}