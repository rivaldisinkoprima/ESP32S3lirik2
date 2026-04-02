// Main Entry Point
//
// App: Lirik Sync V2
//
// Routes:
// - '/': HomeScreen
// - '/settings': SettingsScreen
// - '/sync': BleSyncScreen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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

class LirikSyncApp extends StatefulWidget {
  const LirikSyncApp({super.key});

  @override
  State<LirikSyncApp> createState() => _LirikSyncAppState();
}

class _LirikSyncAppState extends State<LirikSyncApp> {
  bool _initialized = false;
  String _initStatus = 'Checking Bluetooth...';
  List<String> _permissionStatus = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() => _initStatus = 'Checking Bluetooth...');
      final btAdapterState = await FlutterBluePlus.adapterState.first;
      final btOn = btAdapterState == BluetoothAdapterState.on;
      _permissionStatus.add('Bluetooth: ${btOn ? "ON" : "OFF"}');

      // Tidak perlu check akses penyimpanan otomatis
      _permissionStatus.add('Penyimpanan: Akan dicek saat import');

      setState(() {
        _initialized = true;
        _initStatus = 'Selesai';
      });

      if (!btOn && mounted) {
        _showBluetoothDialog();
      }
    } catch (e) {
      setState(() {
        _initStatus = 'Error: $e';
        _permissionStatus.add('Error: $e');
        _initialized = true;
      });
    }
  }

  void _showBluetoothDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Bluetooth Off')),
          ],
        ),
        content: const Text(
          'Bluetooth needs to be turned on to sync with ESP32 device.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await FlutterBluePlus.turnOn();
              } catch (e) {}
              Navigator.of(ctx).pop();
            },
            child: const Text('Turn On'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lirik Sync V2',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/settings') {
          return MaterialPageRoute(builder: (_) => const SettingsScreen());
        }
        if (settings.name == '/sync') {
          return MaterialPageRoute(builder: (_) => const BleSyncScreen());
        }
        return MaterialPageRoute(
          builder: (_) => _initialized
              ? const HomeScreen()
              : PermissionGateScreen(
                  status: _initStatus,
                  permissions: _permissionStatus,
                  onRetry: _initialize,
                ),
        );
      },
    );
  }
}

class PermissionGateScreen extends StatelessWidget {
  final String status;
  final List<String> permissions;
  final VoidCallback onRetry;

  const PermissionGateScreen({
    super.key,
    required this.status,
    required this.permissions,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                const Text(
                  'Memuat Aplikasi...',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(status, style: const TextStyle(color: Colors.grey)),
                if (permissions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Status Sistem:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...permissions.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(p, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
