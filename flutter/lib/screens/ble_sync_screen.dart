// BLE Sync Screen
//
// Routes: '/sync'

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/workspace_provider.dart';
import '../l10n/app_localizations.dart';

class BleSyncScreen extends StatefulWidget {
  const BleSyncScreen({super.key});

  @override
  _BleSyncScreenState createState() => _BleSyncScreenState();
}

class _BleSyncScreenState extends State<BleSyncScreen> {
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  int _syncedDerets = 0;
  int _syncedWords = 0;
  bool _checkDialogOpen = false;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ble = Provider.of<BleProvider>(context);
    
    // Pemicu popup: Jika data sudah ada (bukan null) dan isChecking sudah false
    if (!ble.isChecking && ble.checkResults != null && !_checkDialogOpen) {
      final results = ble.checkResults!;
      // Segera bersihkan results di provider agar notifikasi OK lainnya tidak memunculkan dialog lagi
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ble.clearCheckResults();
        _showCheckDialog(results);
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.all(12),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDeviceList(BleProvider ble) {
    if (ble.scanResults.isEmpty && !ble.isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 60,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _l10n?.translate('noDevicesFound') ?? 'No devices found',
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              _l10n?.translate('tapScanToSearch') ?? 'Tap scan button to search',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (ble.isScanning && ble.scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_l10n?.translate('searchingForBle') ?? 'Searching for BLE devices...'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: ble.scanResults.length,
      itemBuilder: (context, index) {
        final result = ble.scanResults[index];
        final name = result.device.platformName.isNotEmpty
            ? result.device.platformName
            : _l10n?.translate('unknownDevice') ?? 'Unknown Device';
        final rssi = result.rssi;
        final isTarget =
            name.toLowerCase().contains('lirik') ||
            name.toLowerCase().contains('s3');
        final signalBars = rssi >= -60 ? 3 : (rssi >= -75 ? 2 : 1);

        return ListTile(
          leading: Icon(
            Icons.bluetooth,
            color: isTarget ? Colors.green : Colors.grey,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isTarget)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _l10n?.translate('target') ?? 'TARGET',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(child: Text(result.device.remoteId.toString())),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Icon(
                    Icons.signal_cellular_alt,
                    size: 14,
                    color: i < signalBars ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('$rssi dBm', style: const TextStyle(fontSize: 11)),
            ],
          ),
          trailing: ElevatedButton(
            onPressed: () => _showPinDialog(context, ble, result.device),
            child: Text(_l10n?.translate('connect') ?? 'Connect'),
          ),
        );
      },
    );
  }

  Widget _buildConnectedContent(BleProvider ble, WorkspaceProvider workspace) {
    if (_isSyncing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _syncProgress,
                      strokeWidth: 6,
                    ),
                    Text(
                      '${(_syncProgress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _syncStatus,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _l10n?.translate('syncingTrackDetail', ['$_syncedDerets', '$_syncedWords']) ?? '$_syncedDerets deret, $_syncedWords kata',
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (ble.lastStatus.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ble.lastStatus.startsWith('OK') 
                        ? Colors.green.withAlpha(30) 
                        : Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Device Response: ${ble.lastStatus}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ble.lastStatus.startsWith('OK') ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final syncedDerets = workspace.derets.where((d) => d.isSynced).toList();
    final totalWords = syncedDerets.fold<int>(
      0,
      (sum, d) => sum + d.words.length,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              '${_l10n?.translate('connectedStatus') ?? 'Connected'} to ${ble.connectedDevice?.platformName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _l10n?.translate('syncSuccessful', ['${syncedDerets.length}', '$totalWords']) ?? '${syncedDerets.length} tracks ready, $totalWords words',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSecondaryContainer),
                textAlign: TextAlign.center,
              ),
            ),
            if (ble.lastStatus.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Last Device Status: ${ble.lastStatus}',
                style: TextStyle(
                  fontSize: 12,
                  color: ble.lastStatus.startsWith('OK') ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: 250,
              child: ElevatedButton.icon(
                onPressed: syncedDerets.isEmpty
                    ? null
                    : () => _startSync(ble, workspace),
                icon: const Icon(Icons.cloud_upload),
                label: Text(_l10n?.translate('syncAllToDevice') ?? 'Sync All to Device'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: OutlinedButton.icon(
                onPressed: ble.isChecking ? null : () => _triggerCheck(ble),
                icon: ble.isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.storage, color: Colors.blue),
                label: Text(ble.isChecking ? 'Checking...' : 'Check Device Storage'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ble.isChecking ? Colors.grey : Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: OutlinedButton.icon(
                onPressed: () => _confirmReset(context, ble),
                icon: const Icon(Icons.restore, color: Colors.orange),
                label: Text(_l10n?.translate('factoryReset') ?? 'Factory Reset'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: OutlinedButton.icon(
                onPressed: () => ble.disconnect(),
                icon: const Icon(Icons.bluetooth_disabled, color: Colors.red),
                label: Text(_l10n?.translate('disconnect') ?? 'Disconnect'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleProvider>(context);
    final workspace = Provider.of<WorkspaceProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(_l10n?.translate('syncToDevice') ?? 'Sync to Device')),
      body: Column(
        children: [
          _buildStatusHeader(ble),
          if (!ble.isConnected) ...[
            _buildSectionHeader('SELECT DEVICE'),
            Expanded(child: _buildDeviceList(ble)),
          ] else ...[
            _buildSectionHeader('CONNECTED'),
            Expanded(child: _buildConnectedContent(ble, workspace)),
          ],
        ],
      ),
      floatingActionButton: !ble.isConnected
          ? FloatingActionButton(
              onPressed: ble.isScanning ? ble.stopScan : ble.startScan,
              child: Icon(ble.isScanning ? Icons.stop : Icons.search),
            )
          : null,
    );
  }

  Widget _buildStatusHeader(BleProvider ble) {
    return Container(
      width: double.infinity,
      color: ble.isConnected
          ? Colors.green.withAlpha(25)
          : Colors.red.withAlpha(25),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ble.isConnected
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            color: ble.isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            ble.isConnected
                ? (_l10n?.translate('deviceConnected') ?? 'Device Connected')
                : (_l10n?.translate('noDeviceConnected') ?? 'No Device Connected'),
            style: TextStyle(
              color: ble.isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(BuildContext context, BleProvider ble, var device) {
    String pin = "123456";
    String? pinError;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_l10n?.translate('enterDevicePin') ?? 'Enter Device PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (v) {
                      pin = v;
                      if (pinError != null) {
                        pinError = null;
                        setDialogState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      hintText: _l10n?.translate('sixDigitPin') ?? '6-digit PIN',
                      errorText: pinError,
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_l10n?.translate('cancel') ?? 'Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
                      pinError = _l10n?.translate('pinMustBeSixDigits') ?? 'PIN must be 6 digits';
                      setDialogState(() {});
                      return;
                    }
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final success = await ble.connect(device, pin);
                    if (!success) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            _l10n?.translate('failed', ['Lirik S3 Service']) ?? 'Failed to connect to Lirik S3 Service!',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(_l10n?.translate('connect') ?? 'Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startSync(BleProvider ble, WorkspaceProvider workspace) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final syncedDerets = workspace.derets.where((d) => d.isSynced).toList();
    final totalWords = syncedDerets.fold<int>(
      0,
      (sum, d) => sum + d.words.length,
    );

    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatus = _l10n?.translate('preparingData') ?? 'Menyiapkan data...';
      _syncedDerets = 0;
      _syncedWords = 0;
    });

    try {
      // 1. Build Payload
      final payload = workspace.buildBulkJson();
      
      // 2. Kirim data (Proses pengiriman)
      setState(() {
        _syncStatus = 'Mengirim data ke alat...';
        _syncProgress = 0.5; // Tandai sudah kirim
      });
      await ble.writeBatchJson(payload);

      // 3. Menunggu Feedback Nyata dari ESP32 (NOTIFY OK:n/n)
      setState(() {
        _syncStatus = 'Menunggu konfirmasi penyimpanan dari alat...';
        _syncProgress = 0.8;
      });

      // Polling/Waiting loop untuk menunggu status berubah (max 15 detik)
      int retry = 0;
      bool success = false;
      while (retry < 150) { // 150 * 100ms = 15 detik
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (ble.lastStatus.startsWith('OK:')) {
          success = true;
          break;
        }
        if (ble.lastStatus.startsWith('ERR:')) {
          throw Exception('ESP32 Error: ${ble.lastStatus}');
        }
        retry++;
      }

      if (!success) {
        throw Exception('Timeout: Alat tidak merespons konfirmasi penyimpanan.');
      }

      // 4. Selesai
      setState(() {
        _syncProgress = 1.0;
        _syncStatus = _l10n?.translate('done') ?? 'Done!';
        _syncedDerets = syncedDerets.length;
        _syncedWords = totalWords;
      });

      await Future.delayed(const Duration(milliseconds: 1000));
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            _l10n?.translate('syncSuccessful', ['${syncedDerets.length}', '$totalWords']) ?? 'Sync successful! ${syncedDerets.length} tracks, $totalWords words sent.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(_l10n?.translate('syncError', [e.toString()]) ?? 'Sync Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _confirmReset(BuildContext context, BleProvider ble) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n?.translate('factoryResetConfirm') ?? 'Factory Reset?'),
        content: Text(
          _l10n?.translate('factoryResetWarning') ?? 'Ini akan menghapus semua file kustom di memori alat ESP32 dan kembali ke default.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l10n?.translate('cancel') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await ble.sendReset();
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text(_l10n?.translate('resetCommandSent') ?? 'Reset Command Sent!')),
              );
            },
            child: Text(_l10n?.translate('reset') ?? 'Reset', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerCheck(BleProvider ble) async {
    setState(() => _checkDialogOpen = false);

    // Tampilkan loading dialog sementara menunggu ESP32 merespons
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          title: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Checking Device...'),
            ],
          ),
          content: Text('Sedang membaca isi penyimpanan ESP32, mohon tunggu...'),
        ),
      );
    }

    await ble.sendCheck();

    // Tutup loading dialog setelah perintah terkirim
    // (popup hasil akan muncul otomatis via didChangeDependencies setelah data masuk)
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _showCheckDialog(List<DeretCheckResult> results) {
    setState(() => _checkDialogOpen = true);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            const Icon(Icons.storage, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'ESP32 Storage (${results.length} deret)',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_off, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'Tidak ada deret tersimpan di ESP32.\nSilakan sync terlebih dahulu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final deret = results[i];
                    return ExpansionTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          '${deret.slot}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(
                        deret.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${deret.words.length} kata',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: deret.words.asMap().entries.map((e) {
                            return Chip(
                              label: Text(
                                e.value,
                                style: const TextStyle(fontSize: 11),
                              ),
                              avatar: CircleAvatar(
                                radius: 8,
                                child: Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(fontSize: 8),
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _checkDialogOpen = false);
              Navigator.pop(dialogContext);
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _checkDialogOpen = false);
    });
  }
}
