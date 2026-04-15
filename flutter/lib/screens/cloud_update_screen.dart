import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/lyric_update_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/ble_provider.dart';
import '../l10n/app_localizations.dart';

/// Screen yang menampilkan UI untuk fitur Cloud Update Lirik.
///
/// Versi 2.0: Desain Premium ala OS Update (Android/iOS)
/// - Teks sepenuhnya dilokalisasi (EN/ID) via AppLocalizations
/// - Menghilangkan terminologi teknis "Versi Server/Alat", "ESP32", "Workspace"
/// - Fokus pada status kemajuan perangkat medis (Audio Screening)
/// - Arsitektur Hard-Gate tetap aktif sebagai pengaman
class CloudUpdateScreen extends StatelessWidget {
  const CloudUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CloudUpdateView();
  }
}

class _CloudUpdateView extends StatelessWidget {
  const _CloudUpdateView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LyricUpdateProvider>();
    final ble = context.watch<BleProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isConnected = ble.isConnected;

    // Sinkronkan hardware version dari BleProvider ke LyricUpdateProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.hardwareVersion != ble.hardwareVersion) {
        provider.setHardwareVersion(ble.hardwareVersion);
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Image.asset('assets/logo1.png'),
        ),
        title: Text(l10n.translate('updateScreenTitle')),
        centerTitle: true,
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 20),
              onPressed: provider.canCheck
                  ? () => provider.checkForUpdate()
                  : null,
            ),
        ],
      ),
      body: Stack(
        children: [
          // ─── BACKGROUND DECORATION ────────────────────────────────────
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.03),
              ),
            ),
          ),

          // ─── MAIN CONTENT ─────────────────────────────────────────────
          Column(
            children: [
              // Device Info Header
              if (isConnected) _buildDeviceHeader(ble, colorScheme, l10n),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // MAIN ICON AREA
                      _buildMainIllustration(provider, colorScheme),

                      const SizedBox(height: 48),

                      // STATUS INFO
                      _buildStatusInfo(provider, colorScheme, l10n),

                      const SizedBox(height: 48),

                      // ACTION AREA
                      _buildActionArea(
                          context, provider, colorScheme, isConnected, l10n),

                      const SizedBox(height: 40),

                      // INFO FOOTER
                      _buildInfoFooter(colorScheme, l10n),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── HARD-GATE OVERLAY (BLE Guard) ──────────────────────────
          if (!isConnected) _buildHardGateOverlay(context, colorScheme, l10n),
        ],
      ),
    );
  }

  // ─── Helper Builders ──────────────────────────────────────────────────────

  Widget _buildDeviceHeader(
      BleProvider ble, ColorScheme colorScheme, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.cpu, size: 14, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            l10n.translate('updateDeviceConnected'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.outlineVariant)),
          const SizedBox(width: 12),
          Text(
            '${l10n.translate('updateEditionLabel')} ${ble.hardwareVersion ?? "..."}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainIllustration(
      LyricUpdateProvider provider, ColorScheme colorScheme) {
    final (icon, color, glowColor) = _resolveIllustration(provider);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow Effect
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
        // Icon Container
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          ),
          child: Center(
            child: Icon(icon, size: 48, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(LyricUpdateProvider provider, ColorScheme colorScheme,
      AppLocalizations l10n) {
    final (titleKey, subtitleKey, showVersion) = _resolveTextKeys(provider);

    return Column(
      children: [
        Text(
          l10n.translate(titleKey),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (showVersion && provider.serverVersion != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${l10n.translate('updateNewEditionBadge')} ${provider.serverVersion}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.translate(subtitleKey),
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(
      BuildContext context,
      LyricUpdateProvider provider,
      ColorScheme colorScheme,
      bool isConnected,
      AppLocalizations l10n) {
    if (provider.state == UpdateScreenState.checking ||
        provider.state == UpdateScreenState.downloading) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            provider.state == UpdateScreenState.checking
                ? l10n.translate('updateLoadingChecking')
                : l10n.translate('updateLoadingDownloading'),
            style: TextStyle(
                fontSize: 14,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    if (provider.state == UpdateScreenState.readyToSync) {
      return _buildImportCard(context, provider, colorScheme, l10n);
    }

    if (provider.state == UpdateScreenState.updateAvailable) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: () => provider.downloadAssets(),
          icon: const Icon(LucideIcons.download),
          label: Text(l10n.translate('updateDownloadButton'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    // Default: Check Button
    return SizedBox(
      width: 220,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => provider.checkForUpdate(),
        icon: const Icon(LucideIcons.search),
        label: Text(l10n.translate('updateCheckButton')),
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildImportCard(BuildContext context, LyricUpdateProvider provider,
      ColorScheme colorScheme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(l10n.translate('updateImportCardTitle'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 8),
          Text(
            l10n.translate('updateImportCardDesc'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                if (provider.downloadedDataJson != null) {
                  context.read<WorkspaceProvider>().importFromCloudJson(
                        provider.downloadedDataJson!,
                        audioPaths: provider.downloadedAudioPaths,
                      );
                  provider.commitUpdateSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.translate('updateImportSuccess')),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.translate('updateImportButton'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoFooter(ColorScheme colorScheme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            LucideIcons.shieldCheck,
            l10n.translate('updateInfoMedicalStdTitle'),
            l10n.translate('updateInfoMedicalStdDesc'),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            LucideIcons.wifiOff,
            l10n.translate('updateInfoEfficientTitle'),
            l10n.translate('updateInfoEfficientDesc'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHardGateOverlay(
      BuildContext context, ColorScheme colorScheme, AppLocalizations l10n) {
    return Positioned.fill(
      child: Container(
        color: colorScheme.surface.withValues(alpha: 0.98),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.bluetoothOff,
                    color: Colors.red, size: 64),
                const SizedBox(height: 32),
                Text(
                  l10n.translate('updateGateTitle'),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('updateGateDesc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text(l10n.translate('updateOpenSyncHint'))));
                  },
                  icon: const Icon(LucideIcons.bluetooth),
                  label: Text(l10n.translate('updateOpenSyncMenu')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Data Resolvers ─────────────────────────────────────────────────────────

  (IconData, Color, Color) _resolveIllustration(LyricUpdateProvider p) {
    return switch (p.state) {
      UpdateScreenState.idle ||
      UpdateScreenState.upToDate =>
        (LucideIcons.checkCircle2, Colors.green, Colors.green),
      UpdateScreenState.updateAvailable ||
      UpdateScreenState.readyToSync =>
        (LucideIcons.download, Colors.blue, Colors.blue),
      UpdateScreenState.checkFailed ||
      UpdateScreenState.downloadFailed =>
        (LucideIcons.alertTriangle, Colors.orange, Colors.red),
      UpdateScreenState.checking ||
      UpdateScreenState.downloading =>
        (LucideIcons.loader, Colors.blue, Colors.blue),
    };
  }

  /// Mengembalikan key lokalisasi untuk title, subtitle, dan flag showVersion
  (String, String, bool) _resolveTextKeys(LyricUpdateProvider p) {
    return switch (p.state) {
      UpdateScreenState.idle => (
          'updateStatusIdleTitle',
          'updateStatusIdleDesc',
          false
        ),
      UpdateScreenState.checking => (
          'updateStatusCheckingTitle',
          'updateStatusCheckingDesc',
          false
        ),
      UpdateScreenState.upToDate => (
          'updateStatusUpToDateTitle',
          'updateStatusUpToDateDesc',
          false
        ),
      UpdateScreenState.updateAvailable => (
          'updateStatusAvailableTitle',
          'updateStatusAvailableDesc',
          true
        ),
      UpdateScreenState.checkFailed => (
          'updateStatusCheckFailedTitle',
          'updateStatusCheckFailedDesc',
          false
        ),
      UpdateScreenState.downloading => (
          'updateStatusDownloadingTitle',
          'updateStatusDownloadingDesc',
          true
        ),
      UpdateScreenState.readyToSync => (
          'updateStatusReadyTitle',
          'updateStatusReadyDesc',
          true
        ),
      UpdateScreenState.downloadFailed => (
          'updateStatusDownloadFailedTitle',
          'updateStatusDownloadFailedDesc',
          false
        ),
    };
  }
}
