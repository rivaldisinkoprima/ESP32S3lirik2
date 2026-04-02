// BLE Sync Screen
//
// Routes: '/sync'

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../providers/workspace_provider.dart';

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

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      color: Colors.blue.shade800,
      padding: const EdgeInsets.all(12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
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
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap scan button to search',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (ble.isScanning && ble.scanResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for BLE devices...'),
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
            : 'Unknown Device';
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
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'TARGET',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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
                    color: i < signalBars ? Colors.green : Colors.grey.shade300,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('$rssi dBm', style: const TextStyle(fontSize: 11)),
            ],
          ),
          trailing: ElevatedButton(
            onPressed: () => _showPinDialog(context, ble, result.device),
            child: const Text('Connect'),
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
              const SizedBox(height: 24),
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
                '$_syncedDerets deret, $_syncedWords kata',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
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
              'Connected to ${ble.connectedDevice?.platformName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$syncedDerets tracks ready, $totalWords words',
                style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 250,
              child: ElevatedButton.icon(
                onPressed: syncedDerets.isEmpty
                    ? null
                    : () => _startSync(ble, workspace),
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Sync All to Device'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: OutlinedButton.icon(
                onPressed: () => _confirmReset(context, ble),
                icon: const Icon(Icons.restore, color: Colors.orange),
                label: const Text('Factory Reset'),
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
                label: const Text('Disconnect'),
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
      appBar: AppBar(title: const Text('Sync to Device')),
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
            ble.isConnected ? 'Device Connected' : 'No Device Connected',
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
              title: const Text('Enter Device PIN'),
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
                      hintText: '6-digit PIN',
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
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
                      pinError = 'PIN must be 6 digits';
                      setDialogState(() {});
                      return;
                    }
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    final success = await ble.connect(device, pin);
                    if (!success) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to connect to Lirik S3 Service!',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Connect'),
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

    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncStatus = 'Menyiapkan data...';
      _syncedDerets = 0;
      _syncedWords = 0;
    });

    try {
      // Simulate progress per deret
      final payload = workspace.buildBulkJson();

      // Update progress during sync
      for (int i = 0; i < syncedDerets.length; i++) {
        if (!mounted) break;
        setState(() {
          _syncedDerets = i + 1;
          _syncedWords = syncedDerets
              .take(i + 1)
              .fold<int>(0, (sum, d) => sum + d.words.length);
          _syncProgress = (i + 1) / syncedDerets.length * 0.8;
          _syncStatus = 'Syncing Track ${syncedDerets[i].slotNumber}...';
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() {
        _syncProgress = 0.9;
        _syncStatus = 'Mengirim data...';
      });

      await ble.writeBatchJson(payload);

      setState(() {
        _syncProgress = 1.0;
        _syncStatus = 'Done!';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sync successful! $_syncedDerets tracks, $_syncedWords words sent.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Sync Error: $e'), backgroundColor: Colors.red),
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
        title: const Text('Factory Reset?'),
        content: const Text(
          'Ini akan menghapus semua file kustom di memori alat ESP32 dan kembali ke default.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await ble.sendReset();
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Reset Command Sent!')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
