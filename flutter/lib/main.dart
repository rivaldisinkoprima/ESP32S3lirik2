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
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/main_shell.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        ChangeNotifierProvider(create: (_) => BleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
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
  String _initStatus = 'checkBluetooth';
  List<String> _permissionStatus = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() => _initStatus = 'checkBluetooth');
      final btAdapterState = await FlutterBluePlus.adapterState.first;
      final btOn = btAdapterState == BluetoothAdapterState.on;
      _permissionStatus.add('Bluetooth: ${btOn ? "ON" : "OFF"}');

      // Tidak perlu check akses penyimpanan otomatis
      _permissionStatus.add('storageInfo');

      setState(() {
        _initialized = true;
        _initStatus = 'done';
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
        title: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.of(ctx)?.translate('bluetoothOff') ?? 'Bluetooth Off')),
          ],
        ),
        content: Text(
          AppLocalizations.of(ctx)?.translate('bluetoothNeeded') ?? 'Bluetooth needs to be turned on to sync with ESP32 device.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await FlutterBluePlus.turnOn();
              } catch (e) {}
              Navigator.of(ctx).pop();
            },
            child: Text(AppLocalizations.of(ctx)?.translate('turnOn') ?? 'Turn On'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx)?.translate('later') ?? 'Later'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lirik Sync V2',
      locale: localeProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => _initialized
              ? MainShell(key: ValueKey(localeProvider.locale.languageCode))
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)?.translate('loadingApp') ?? 'Loading Application...',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)?.translate(status) ?? status, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (permissions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)?.translate('systemStatus') ?? 'System Status:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...permissions.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(AppLocalizations.of(context)?.translate(p) ?? p, style: const TextStyle(fontSize: 12)),
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
