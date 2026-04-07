import 'package:lucide_icons/lucide_icons.dart';
// BLE Sync Screen
//
// Routes: '/sync'

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
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
              LucideIcons.bluetoothSearching,
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
        // Define signal strength variables
        Color signalColor;
        String signalText;
        if (rssi >= -60) {
            signalColor = Colors.green;
            signalText = 'Excellent';
        } else if (rssi >= -75) {
            signalColor = Colors.lightGreen;
            signalText = 'Good';
        } else if (rssi >= -85) {
            signalColor = Colors.orange;
            signalText = 'Fair';
        } else {
            signalColor = Colors.grey;
            signalText = 'Weak';
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(16),
             side: BorderSide(
               color: isTarget ? Colors.green.withOpacity(0.3) : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
               width: isTarget ? 1.5 : 1.0,
             )
          ),
          color: isTarget ? Colors.green.withOpacity(0.05) : Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon Section
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isTarget ? Colors.green.withOpacity(0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTarget ? LucideIcons.bluetoothConnected : LucideIcons.bluetooth,
                    color: isTarget ? Colors.green.shade700 : Theme.of(context).colorScheme.outline,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Details Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: isTarget ? FontWeight.bold : FontWeight.w600,
                                fontSize: 16,
                                color: isTarget ? Colors.green.shade800 : Theme.of(context).colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isTarget) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _l10n?.translate('target') ?? 'TARGET',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.device.remoteId.toString(),
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      // Modern Signal Indicator
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: signalColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: signalColor),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  signalText,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: signalColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$rssi dBm', style: TextStyle(fontSize: 11, color: signalColor, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Action Section
                ElevatedButton(
                  onPressed: () => _showPinDialog(context, ble, result.device),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTarget ? Colors.green : Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: isTarget ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer,
                    elevation: isTarget ? 2 : 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_l10n?.translate('connect') ?? 'Connect'),
                ),
              ],
            ),
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
                child: LoadingAnimationWidget.inkDrop(
                  color: Theme.of(context).colorScheme.primary,
                  size: 50,
                ),
              ),
              Text(
                _syncStatus,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              // Bubble detail track dihapus sesuai permintaan
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

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Device Header Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                               color: Colors.black.withOpacity(0.05),
                               blurRadius: 10,
                               spreadRadius: 2,
                            )
                          ]
                        ),
                        child: const Icon(
                          LucideIcons.cpu,
                          size: 48,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_l10n?.translate('connectedStatus') ?? 'Connected'} to',
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        ble.connectedDevice?.platformName ?? 'ESP32 Device',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      // Bubble 'Sync successful' di tampilan Connected state dihapus sesuai instruksi minimalis
                    ],
                  ),
                ),
              ),
              
              if (ble.lastStatus.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ble.lastStatus.startsWith('OK') ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ble.lastStatus.startsWith('OK') ? Colors.green.withAlpha(50) : Colors.red.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                         ble.lastStatus.startsWith('OK') ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                         color: ble.lastStatus.startsWith('OK') ? Colors.green : Colors.red,
                         size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ble.lastStatus,
                          style: TextStyle(
                            fontSize: 13,
                            color: ble.lastStatus.startsWith('OK') ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                ),
              ],

              const SizedBox(height: 40),
              
              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Primary Action
                  ElevatedButton(
                    onPressed: syncedDerets.isEmpty
                        ? null
                        : () => _startSync(ble, workspace),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 4,
                      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.uploadCloud),
                        const SizedBox(width: 8),
                        Text(
                          _l10n?.translate('syncAllToDevice') ?? 'Sync All to Device',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Secondary Actions Row
                  Row(
                    children: [
                       Expanded(
                         child: OutlinedButton.icon(
                           onPressed: ble.isChecking ? null : () => _triggerCheck(ble),
                           icon: ble.isChecking
                               ? const SizedBox(
                                   width: 16,
                                   height: 16,
                                   child: CircularProgressIndicator(strokeWidth: 2),
                                 )
                               : const Icon(LucideIcons.hardDrive, size: 20),
                           label: Text(ble.isChecking ? 'Checking...' : 'Check Storage', style: const TextStyle(fontSize: 13)),
                           style: OutlinedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(vertical: 12),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           ),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: OutlinedButton.icon(
                           onPressed: () => _confirmReset(context, ble),
                           icon: Icon(LucideIcons.rotateCcw, color: Colors.orange.shade700, size: 20),
                           label: Text(_l10n?.translate('factoryReset') ?? 'Factory Reset', style: TextStyle(color: Colors.orange.shade700, fontSize: 13)),
                           style: OutlinedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(vertical: 12),
                             side: BorderSide(color: Colors.orange.shade300),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           ),
                         ),
                       ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  // Disconnect Button
                  TextButton.icon(
                    onPressed: () => ble.disconnect(),
                    icon: Icon(LucideIcons.bluetoothOff, color: Colors.red.shade400, size: 20),
                    label: Text(_l10n?.translate('disconnect') ?? 'Disconnect Device', style: TextStyle(color: Colors.red.shade400)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
              child: Icon(ble.isScanning ? LucideIcons.square : LucideIcons.search),
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
                ? LucideIcons.bluetoothConnected
                : LucideIcons.bluetoothOff,
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
      _syncStatus = _l10n?.translate('preparingData') ?? 'Preparing data...';
      _syncedDerets = 0;
      _syncedWords = 0;
    });

    try {
      // 1. Build Payload
      final payload = workspace.buildBulkJson();
      
      // 2. Kirim data (Proses pengiriman)
      setState(() {
        _syncStatus = _l10n?.translate('sendingData') ?? 'Sending data to device...';
        _syncProgress = 0.5; // Tandai sudah kirim
      });
      await ble.writeBatchJson(payload);

      // 3. Menunggu Feedback Nyata dari ESP32 (NOTIFY OK:n/n)
      setState(() {
        _syncStatus = _l10n?.translate('waitingForConfirmation') ?? 'Waiting for storage confirmation...';
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
        throw Exception(_l10n?.translate('timeoutStatus') ?? 'Timeout: Device did not respond to storage confirmation.');
      }

      // 4. Selesai
      setState(() {
        _syncProgress = 1.0;
        _syncStatus = _l10n?.translate('doneSync') ?? 'Done!';
        _syncedDerets = syncedDerets.length;
        _syncedWords = totalWords;
      });

      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Popup Snackbar sukses dihapus sesuai permintaan
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
            const Icon(LucideIcons.hardDrive, color: Colors.blue, size: 20),
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
                        Icon(LucideIcons.folderX, size: 48, color: Colors.grey),
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
