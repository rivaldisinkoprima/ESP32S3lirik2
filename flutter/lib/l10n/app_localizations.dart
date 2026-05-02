import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [Locale('en'), Locale('id')];

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'Lirik Sync',
      'homeTitle': 'Home',
      'syncTitle': 'Sync',
      'settingsTitle': 'Settings',
      'importFiles': 'Import files',
      'scanAll': 'Scan all',
      'noTracksYet': 'No Tracks Yet',
      'createFirstTrack': 'Create your first track to start syncing lyrics to your ESP32 device',
      'createTrack': 'Create Track',
      'orTapPlus': 'or tap + button below',
      'deleteTrack': 'Delete Track?',
      'deleteConfirmation': 'Are you sure you want to delete "%1"?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'trackDeleted': 'Track %1 deleted',
      'undo': 'Undo',
      'importSuccess': 'Import Success',
      'audioFiles': 'Audio Files',
      'lyrics': 'Lyrics',
      'tracks': 'Tracks',
      'importPreview': 'Import Preview',
      'import': 'Import',
      'processingTrack': 'Processing track %1 of %2',
      'wordsDetected': '%1 words detected',
      'done': 'Done',
      'wordsDetectedIn': '%1 words detected in %2 tracks',
      'ok': 'OK',
      'importFailed': 'Import failed: %1',
      'importing': 'Importing...',
      'failed': 'Failed: %1',
      'noAudioFound': 'No tracks with audio found',
      'enterDevicePin': 'Enter Device PIN',
      'sixDigitPin': '6-digit PIN',
      'pinMustBeSixDigits': 'PIN must be 6 digits',
      'connect': 'Connect',
      'syncToDevice': 'Sync to Device',
      'selectDevice': 'Select Device',
      'connectedStatus': 'Connected',
      'noDevicesFound': 'No devices found',
      'tapScanToSearch': 'Tap scan button to search',
      'searchingForBle': 'Searching for BLE devices...',
      'deviceConnected': 'Device Connected',
      'noDeviceConnected': 'No Device Connected',
      'factoryReset': 'Factory Reset',
      'factoryResetConfirm': 'Factory Reset?',
      'resetCommandSent': 'Reset Command Sent!',
      'disconnect': 'Disconnect',
      'syncAllToDevice': 'Sync All to Device',
      'syncingTrackDetail': 'Syncing Track %1...',
      'doneSync': 'Done!',
      'syncSuccessful': 'Sync successful! %1 tracks, %2 words sent.',
      'syncError': 'Sync Error: %1',
      'waitingForConfirmation': 'Waiting for storage confirmation from device...',
      'timeoutStatus': 'Timeout: Device did not respond to storage confirmation.',
      'settings': 'Settings',
      'delayOffset': 'DELAY OFFSET',
      'hardwareDelayOffset': 'Hardware Delay Offset',
      'positiveOffset': 'Offset Positif (+)',
      'negativeOffset': 'Offset Negatif (-)',
      'reset': 'Reset',
      'offsetResetTo': 'Offset reset to %1 ms',
      'appearance': 'APPEARANCE',
      'darkMode': 'Dark Mode',
      'darkModeEnabled': 'Dark theme enabled',
      'darkModeDisabled': 'Light theme enabled',
      'selectAudio': 'SELECT AUDIO',
      'selectLyrics': 'WORDS',
      'importLyricsJson': 'Import lyrics from JSON file',
      'detectWords': 'Detect Words',
      'addWord': 'Add Word',
      'maxChars': 'MAX-8',
      'trackSaved': 'Track %1 saved successfully',
      'editTrack': 'Edit Track %1',
      'importFromJson': 'Import kata from file JSON untuk Track %1',
      'discardChanges': 'Discard Changes?',
      'unsavedChanges': 'You have unsaved changes. Are you sure you want to go back?',
      'discard': 'Discard',
      'language': 'Language',
      'english': 'English',
      'indonesian': 'Indonesian',
      'ms': 'ms',
      'files': 'files',
      'words': 'words',
      'slots': 'slots',
      'slot': 'slot',
      'trackNum': 'Track %1',
      'audioFilesCount': 'Audio: %1 files',
      'lyricsWordsCount': 'Lyrics: %1 words',
      'tracksSlotsCount': 'Tracks: %1 slots',
      'syncedCount': '%1 synced',
      'noiseWarning': 'Use noise-free MP3 files for best results',
      'tracksAllCaps': 'TRACKS',
      'tapPlusToCreate': 'Tap + to create a new track',
      'hardwareDelayDesc': 'Used to compensate for DFPlayer delay',
      'slower': 'Slower',
      'faster': 'Faster',
      'quickValues': 'Quick Values',
      'explanation': 'Explanation',
      'positiveOffsetDesc': 'Lyrics play earlier than audio. Use if lyrics are late.',
      'negativeOffsetDesc': 'Lyrics play later than audio. Use if lyrics are too fast.',
      'checkBluetooth': 'Checking Bluetooth...',
      'storageInfo': 'Storage: Will be checked on import',
      'bluetoothOff': 'Bluetooth Off',
      'bluetoothNeeded': 'Bluetooth needs to be turned on to sync with ESP32 device.',
      'turnOn': 'Turn On',
      'later': 'Later',
      'loadingApp': 'Loading Application...',
      'systemStatus': 'System Status:',
      'newWordDefault': 'NEW',
      'unknownDevice': 'Unknown Device',
      'target': 'TARGET',
      'preparingData': 'Preparing data...',
      'sendingData': 'Sending data...',
      'languageCaps': 'LANGUAGE',
      'appearanceCaps': 'APPEARANCE',
      'delayOffsetCaps': 'DELAY OFFSET',
      'open': 'Open',
      'save': 'Save',
      'selectAudioFile': 'Select audio file...',
      'importLyricsDesc': 'Track %1: Import lyrics from JSON file',
      'spikeWordMismatch': 'Spike (%1) != Words (%2)',
      'removeExtra': 'Remove extra',
      'wordsCount': '%1 words',
      'notSynced': 'Not synced',
      'processTooLong': 'Process took too long: %1',
      'error': 'Error: %1',
      'factoryResetWarning': 'This will delete all custom files from ESP32 memory and restore to default.',
      'preparing': 'Preparing...',
      'processing': 'Processing...',
      'timeoutDuration': 'Timeout reading duration',
      'invalidDuration': 'Invalid audio duration',
      'validatingAudio': 'Validating audio file...',
      'timeoutValidation': 'Timeout validating file (10s)',
      'failedReadAudio': 'Failed to read audio file. Check format and corruption.',
      'cannotDecodeAudio': 'Audio file cannot be decoded. Try standard MP3/WAV.',
      'decoderIssueAndroid': 'Audio incompatible with Android decoder. Use CBR 128kbps.',
      'extractingWaveform': 'Extracting waveform (%1 samples)...',
      'timeoutWaveform': 'Timeout extracting waveform (30s)',
      'emptyWaveform': 'Waveform data is empty',
      'detectingSpikes': 'Detecting spikes...',
      'timeoutSpikes': 'Timeout detecting spikes (15s)',
      'spikesDetectedDetail': 'Successfully detected %1 spikes',
      'savedSuccessfully': 'Track %1 saved successfully',
      'jsonMissingData': 'File does not contain data for "%1".',
      'wordsImportedToTrack': '%1 words imported to Track %2',
      'failedReadJson': 'Failed to read JSON file: %1',
      'formatNotSupported': 'Format .%1 not supported. Use: %2',
      'audioFileNotFound': 'Audio file not found',
      'fileTooLarge': 'File too large (max 100MB)',

      // ─── Cloud Update Screen ───────────────────────────────────────────
      'updateScreenTitle': 'System Update',
      'updateDeviceConnected': 'Audio Screening Connected',
      'updateEditionLabel': 'Version:',
      'updateNewEditionBadge': 'New Version',
      'updateCheckButton': 'Check for Updates',
      'updateDownloadButton': 'Download Safely',
      'updateOpenSyncMenu': 'Open Sync Menu',
      'updateOpenSyncHint': 'Open the "Sync" tab in the bottom menu.',

      // Status: Idle
      'updateStatusIdleTitle': 'System Ready',
      'updateStatusIdleDesc': 'Tap the button below to check for available data updates for your Audio Screening.',

      // Status: Checking
      'updateStatusCheckingTitle': 'Checking...',
      'updateStatusCheckingDesc': 'Searching for the latest medical instruction data on the central server.',
      'updateLoadingChecking': 'Contacting central server...',

      // Status: Up To Date
      'updateStatusUpToDateTitle': 'System Up to Date',
      'updateStatusUpToDateDesc': 'Your Audio Screening is already using the latest official data.',

      // Status: Update Available
      'updateStatusAvailableTitle': 'Lyric Update Available',
      'updateStatusAvailableDesc': 'A new lyric instruction update from the center is available to improve the quality of your Audio Screening.',

      // Status: Check Failed
      'updateStatusCheckFailedTitle': 'Check Failed',
      'updateStatusCheckFailedDesc': 'Unable to connect to the central network. Please check your WiFi/Mobile internet connection.',

      // Status: Downloading
      'updateStatusDownloadingTitle': 'Downloading...',
      'updateStatusDownloadingDesc': 'Please wait, compiling the medical update data package.',
      'updateLoadingDownloading': 'Downloading data package...',

      // Status: Ready to Sync
      'updateStatusReadyTitle': 'Download Complete',
      'updateStatusReadyDesc': 'The latest data update is ready to be installed for your Audio Screening.',

      // Status: Download Failed
      'updateStatusDownloadFailedTitle': 'Download Failed',
      'updateStatusDownloadFailedDesc': 'An error occurred while downloading the medical data. Please try again.',

      // Import Card
      'updateImportCardTitle': 'Download Complete',
      'updateImportCardDesc': 'The latest lyric texts are ready to be installed into the application before being sent to the device.',
      'updateImportButton': 'Install into System',
      'updateImportSuccess': 'Data ready! Please open the Sync menu to transfer lyrics to the Audio Screening.',

      // Info Footer
      'updateInfoMedicalStdTitle': 'Medical Standard',
      'updateInfoMedicalStdDesc': 'This lyric instruction update is official and has been tested for accuracy.',
      'updateInfoEfficientTitle': 'Efficient',
      'updateInfoEfficientDesc': 'The system will only download data if there is actually a new release available.',

      // Hard-Gate Overlay
      'updateGateTitle': 'Device Not Connected',
      'updateGateDesc': 'Please connect your phone to the Audio Screening device first via the Sync menu to check for the latest updates.',
    },
    'id': {
      'appName': 'Lirik Sync',
      'homeTitle': 'Beranda',
      'syncTitle': 'Sinkron',
      'settingsTitle': 'Pengaturan',
      'importFiles': 'Impor file',
      'scanAll': 'Semua',
      'noTracksYet': 'Belum ada Deret',
      'createFirstTrack': 'Buat deret pertama Anda untuk mulai menyinkronkan lirik ke perangkat ESP32',
      'createTrack': 'Buat Deret',
      'orTapPlus': 'atau ketuk tombol + di bawah',
      'deleteTrack': 'Hapus Deret?',
      'deleteConfirmation': 'Apakah Anda yakin ingin menghapus "%1"?',
      'cancel': 'Batal',
      'delete': 'Hapus',
      'trackDeleted': 'Deret %1 telah dihapus',
      'undo': 'Kembalikan',
      'importSuccess': 'Impor Berhasil',
      'audioFiles': 'File Audio',
      'lyrics': 'Lirik',
      'tracks': 'Deret',
      'importPreview': 'Pratinjau Impor',
      'import': 'Impor',
      'processingTrack': 'Memproses deret %1 dari %2',
      'wordsDetected': '%1 kata terdeteksi',
      'done': 'Selesai',
      'wordsDetectedIn': '%1 kata terdeteksi dalam %2 deret',
      'ok': 'OK',
      'importFailed': 'Impor gagal: %1',
      'importing': 'Mengimpor...',
      'failed': 'Gagal: %1',
      'noAudioFound': 'Tidak ada deret dengan audio',
      'enterDevicePin': 'Masukkan PIN Perangkat',
      'sixDigitPin': 'PIN 6 digit',
      'pinMustBeSixDigits': 'PIN harus 6 digit angka',
      'connect': 'Sambungkan',
      'syncToDevice': 'Sinkronkan ke Perangkat',
      'selectDevice': 'Pilih Perangkat',
      'connectedStatus': 'Terhubung',
      'noDevicesFound': 'Tidak ada perangkat ditemukan',
      'tapScanToSearch': 'Ketuk tombol scan untuk mencari',
      'searchingForBle': 'Mencari perangkat BLE...',
      'deviceConnected': 'Perangkat Terhubung',
      'noDeviceConnected': 'Tidak Ada Perangkat Terhubung',
      'factoryReset': 'Reset Pabrik',
      'factoryResetConfirm': 'Reset Pabrik?',
      'resetCommandSent': 'Perintah Reset Terkirim!',
      'disconnect': 'Putuskan Sambungan',
      'syncAllToDevice': 'Sinkronkan Semua ke Perangkat',
      'syncingTrackDetail': 'Menyinkronkan Deret %1...',
      'doneSync': 'Selesai!',
      'syncSuccessful': 'Sinkron berhasil! %1 deret, %2 kata terkirim.',
      'syncError': 'Kesalahan Sinkron: %1',
      'waitingForConfirmation': 'Menunggu konfirmasi penyimpanan dari alat...',
      'timeoutStatus': 'Waktu habis: Alat tidak merespons konfirmasi penyimpanan.',
      'settings': 'Pengaturan',
      'delayOffset': 'DELAY OFFSET',
      'hardwareDelayOffset': 'OFFSET DELAY HARDWARE',
      'positiveOffset': 'OFFSET POSITIF (+)',
      'negativeOffset': 'OFFSET NEGATIF (-)',
      'reset': 'Reset',
      'offsetResetTo': 'OFFSET DIKEMBALIKAN KE %1 MS',
      'appearance': 'TAMPILAN',
      'darkMode': 'Mode Gelap',
      'darkModeEnabled': 'Tema gelap diaktifkan',
      'darkModeDisabled': 'Tema terang diaktifkan',
      'selectAudio': 'PILIH AUDIO',
      'selectLyrics': 'WORDS',
      'importLyricsJson': 'Impor lirik dari file JSON untuk Deret %1',
      'detectWords': 'Deteksi Kata',
      'addWord': 'Tambah Kata',
      'maxChars': 'MAKS-8',
      'trackSaved': 'Deret %1 berhasil disimpan',
      'editTrack': 'Edit Deret %1',
      'importFromJson': 'Impor kata dari file JSON untuk Deret %1',
      'discardChanges': 'Buang Perubahan?',
      'unsavedChanges': 'Anda memiliki perubahan yang belum disimpan. Apakah Anda yakin ingin kembali?',
      'discard': 'Buang',
      'language': 'Bahasa',
      'english': 'Inggris',
      'indonesian': 'Indonesia',
      'ms': 'ms',
      'files': 'file',
      'words': 'kata',
      'slots': 'slot',
      'slot': 'slot',
      'trackNum': 'Deret %1',
      'audioFilesCount': 'Audio: %1 file',
      'lyricsWordsCount': 'Lirik: %1 kata',
      'tracksSlotsCount': 'Deret: %1 slot',
      'syncedCount': '%1 tersinkron',
      'noiseWarning': 'Gunakan file MP3 bebas noise untuk hasil terbaik',
      'tracksAllCaps': 'DERET',
      'tapPlusToCreate': 'Ketuk + untuk membuat deret baru',
      'hardwareDelayDesc': 'Digunakan untuk kompensasi delay DFPlayer',
      'slower': 'Lebih lambat',
      'faster': 'Lebih cepat',
      'quickValues': 'Nilai Cepat',
      'explanation': 'Penjelasan',
      'positiveOffsetDesc': 'Lirik diputar lebih awal dari audio. Gunakan jika lirik terlambat.',
      'negativeOffsetDesc': 'Lirik diputar lebih lambat dari audio. Gunakan jika lirik terlalu cepat.',
      'checkBluetooth': 'Memeriksa Bluetooth...',
      'storageInfo': 'Penyimpanan: Akan dicek saat impor',
      'bluetoothOff': 'Bluetooth Mati',
      'bluetoothNeeded': 'Bluetooth harus diaktifkan untuk sinkronisasi dengan perangkat ESP32.',
      'turnOn': 'Aktifkan',
      'later': 'Nanti',
      'loadingApp': 'Memuat Aplikasi...',
      'systemStatus': 'Status Sistem:',
      'newWordDefault': 'BARU',
      'unknownDevice': 'Perangkat Tidak Dikenal',
      'target': 'TARGET',
      'preparingData': 'Menyiapkan data...',
      'sendingData': 'Mengirim data...',
      'languageCaps': 'BAHASA',
      'appearanceCaps': 'TAMPILAN',
      'delayOffsetCaps': 'DELAY OFFSET',
      'open': 'Buka',
      'save': 'Simpan',
      'selectAudioFile': 'Pilih file audio...',
      'importLyricsDesc': 'Deret %1: Impor lirik dari file JSON',
      'spikeWordMismatch': 'Spike (%1) != Kata (%2)',
      'removeExtra': 'Hapus kelebihan',
      'wordsCount': '%1 kata',
      'notSynced': 'Belum tersinkron',
      'processTooLong': 'Proses terlalu lama: %1',
      'error': 'Error: %1',
      'factoryResetWarning': 'Ini akan menghapus semua file kustom di memori alat ESP32 dan kembali ke default.',
      'preparing': 'Mempersiapkan...',
      'processing': 'Memproses...',
      'timeoutDuration': 'Timeout membaca durasi',
      'invalidDuration': 'Durasi audio tidak valid',
      'validatingAudio': 'Memvalidasi file audio...',
      'timeoutValidation': 'Timeout validasi file (10 detik)',
      'failedReadAudio': 'Gagal membaca file audio. Pastikan file tidak corrupt dan format didukung.',
      'cannotDecodeAudio': 'File audio tidak bisa di-decode. Coba convert ke WAV atau MP3 standar 128kbps CBR.',
      'decoderIssueAndroid': 'File audio tidak kompatibel dengan decoder Android. Kemungkinan: VBR, corrupt, atau format tidak standar. Solusi: Convert ke WAV atau MP3 128kbps CBR.',
      'extractingWaveform': 'Mengekstrak waveform (%1 samples)...',
      'timeoutWaveform': 'Timeout ekstraksi waveform (30 detik)',
      'emptyWaveform': 'Waveform data kosong',
      'detectingSpikes': 'Mendeteksi spike...',
      'timeoutSpikes': 'Timeout deteksi spike (15 detik)',
      'spikesDetectedDetail': 'Berhasil mendeteksi %1 spike',
      'savedSuccessfully': 'Deret %1 berhasil disimpan',
      'jsonMissingData': 'File tidak berisi data untuk "%1".',
      'wordsImportedToTrack': '%1 kata diimpor ke Deret %2',
      'failedReadJson': 'Gagal membaca file JSON: %1',
      'formatNotSupported': 'Format .%1 tidak didukung. Gunakan: %2',
      'audioFileNotFound': 'File audio tidak ditemukan',
      'fileTooLarge': 'File terlalu besar (maks 100MB)',

      // ─── Cloud Update Screen ───────────────────────────────────────────
      'updateScreenTitle': 'Pembaruan Sistem',
      'updateDeviceConnected': 'Audio Screening Terhubung',
      'updateEditionLabel': 'Versi:',
      'updateNewEditionBadge': 'Versi Baru',
      'updateCheckButton': 'Cek Pembaruan',
      'updateDownloadButton': 'Unduh Secara Aman',
      'updateOpenSyncMenu': 'Buka Menu Sync',
      'updateOpenSyncHint': 'Buka tab "Sync" di menu bawah.',

      // Status: Idle
      'updateStatusIdleTitle': 'Sistem Siap',
      'updateStatusIdleDesc': 'Tekan tombol di bawah untuk memeriksa ketersediaan data pembaruan untuk Audio Screening.',

      // Status: Checking
      'updateStatusCheckingTitle': 'Memeriksa...',
      'updateStatusCheckingDesc': 'Sedang mencari data instruksi medis terbaru di server pusat.',
      'updateLoadingChecking': 'Menghubungi pusat...',

      // Status: Up To Date
      'updateStatusUpToDateTitle': 'Sistem Terupdate',
      'updateStatusUpToDateDesc': 'Audio Screening Anda sudah menggunakan data versi terbaru yang resmi.',

      // Status: Update Available
      'updateStatusAvailableTitle': 'Tersedia Pembaruan Lirik',
      'updateStatusAvailableDesc': 'Ada pembaruan kalimat instruksi lirik baru dari pusat untuk meningkatkan kualitas dari mesin Audio Screening.',

      // Status: Check Failed
      'updateStatusCheckFailedTitle': 'Pengecekan Gagal',
      'updateStatusCheckFailedDesc': 'Tidak dapat terhubung ke jaringan pusat. Periksa koneksi internet WiFi/Seluler Anda.',

      // Status: Downloading
      'updateStatusDownloadingTitle': 'Mengunduh...',
      'updateStatusDownloadingDesc': 'Mohon tunggu, sedang melakukan kompilasi paket data pembaruan medis.',
      'updateLoadingDownloading': 'Mengunduh paket data...',

      // Status: Ready to Sync
      'updateStatusReadyTitle': 'Unduhan Selesai',
      'updateStatusReadyDesc': 'Pembaruan data terbaru sudah siap dipasang untuk digunakan oleh Audio Screening Anda.',

      // Status: Download Failed
      'updateStatusDownloadFailedTitle': 'Gagal Unduh',
      'updateStatusDownloadFailedDesc': 'Terjadi gangguan saat mengunduh data medis. Silakan coba kembali.',

      // Import Card
      'updateImportCardTitle': 'Unduhan Selesai',
      'updateImportCardDesc': 'Teks lirik terbaru sudah siap dipasang ke dalam aplikasi Anda sebelum dikirim ke mesin.',
      'updateImportButton': 'Pasang ke Dalam Sistem',
      'updateImportSuccess': 'Data berhasil disiapkan! Silakan buka menu Sync untuk mentransfer lirik ke Audio Screening.',

      // Info Footer
      'updateInfoMedicalStdTitle': 'Standar Medis',
      'updateInfoMedicalStdDesc': 'Pembaruan kalimat lirik ini resmi dan telah diuji akurasinya.',
      'updateInfoEfficientTitle': 'Efisien',
      'updateInfoEfficientDesc': 'Sistem hanya akan mengunduh data jika benar-benar ada versi rilis terbaru.',

      // Hard-Gate Overlay
      'updateGateTitle': 'Alat Belum Terhubung',
      'updateGateDesc': 'Silakan hubungkan HP Anda ke mesin Audio Screening terlebih dahulu melalui menu Sync untuk mengecek pembaruan versi terbaru.',
    },
  };

  String translate(String key, [List<String> args = const []]) {
    String value = _localizedValues[locale.languageCode]?[key] ?? key;
    for (int i = 0; i < args.length; i++) {
      value = value.replaceAll('%${i + 1}', args[i]);
    }
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'id'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
