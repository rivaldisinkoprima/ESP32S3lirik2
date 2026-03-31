// BLE Sync Screen
//
// Fungsi:
// - Scan device BLE "Lirik S3"
// - Connect dengan PIN (123456)
// - Sync All: Kirim semua data deret ke ESP32 via BLE
// - Factory Reset: Reset ESP32 ke default
// - Disconnect: Putus koneksi BLE
//
// Routes: '/sync'

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
    return ListView.builder(
      itemCount: ble.scanResults.length,
      itemBuilder: (context, index) {
        final result = ble.scanResults[index];
        final name = result.device.platformName.isNotEmpty
            ? result.device.platformName
            : 'Unknown Device';
        return ListTile(
          title: Text(name),
          subtitle: Text(result.device.remoteId.toString()),
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
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text('Connected to ${ble.connectedDevice?.platformName}'),
          const SizedBox(height: 32),
          SizedBox(
            width: 250,
            child: ElevatedButton.icon(
              onPressed: () => _startSync(ble, workspace),
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
            _buildSectionHeader('PILIH PERANGKAT'),
            Expanded(child: _buildDeviceList(ble)),
          ] else ...[
            _buildSectionHeader('TERHUBUNG'),
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Device PIN'),
          content: TextField(
            onChanged: (v) => pin = v,
            decoration: const InputDecoration(hintText: '123456'),
            keyboardType: TextInputType.number,
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
                final success = await ble.connect(device, pin);
                if (!success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to connect to Lirik S3 Service!'),
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
  }

  Future<void> _startSync(BleProvider ble, WorkspaceProvider workspace) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isSyncing = true);
    try {
      final payload = workspace.buildBulkJson();
      await ble.writeBatchJson(payload);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Sync Successful!')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Sync Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
