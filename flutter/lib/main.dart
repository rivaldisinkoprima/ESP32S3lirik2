// Main Entry Point
//
// App: Lirik Sync V2
// Function: Aplikasi Android untuk sinkronisasi data lirik ke ESP32-S3
// Features:
// - Workspace: Kelola 10 slot deret
// - Audio Spike Detection: Deteksi timing dari waveform
// - BLE Sync: Kirim data ke ESP32 via Bluetooth
// - Settings: Offset delay kompensasi DFPlayer
//
// Routes:
// - '/': HomeScreen (Workspace)
// - '/settings': SettingsScreen
// - '/sync': BleSyncScreen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/workspace_provider.dart';
import 'providers/ble_provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ble_sync_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        ChangeNotifierProvider(create: (_) => BleProvider()),
      ],
      child: const LirikSyncApp(),
    ),
  );
}

class LirikSyncApp extends StatelessWidget {
  const LirikSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lirik Sync V2',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/sync': (context) => const BleSyncScreen(),
      },
    );
  }
}
