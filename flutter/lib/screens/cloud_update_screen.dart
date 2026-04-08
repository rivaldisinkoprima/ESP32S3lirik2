import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/lyric_update_provider.dart';
import '../providers/workspace_provider.dart';

/// Screen yang menampilkan UI untuk fitur Cloud Update Lirik.
///
/// Alur User:
/// 1. Tekan "Periksa Pembaruan" → App download version.txt (beberapa byte)
/// 2. Jika ada update: tombol "Unduh & Proses" menyala
/// 3. Tekan "Unduh & Proses" → App download data.json & audio
/// 4. Setelah download: tombol "Kirim ke Alat" muncul
/// 5. Setelah BLE sync sukses: versi lokal di-commit, tombol kembali disable
class CloudUpdateScreen extends StatelessWidget {
  const CloudUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LyricUpdateProvider(),
      child: const _CloudUpdateView(),
    );
  }
}

class _CloudUpdateView extends StatelessWidget {
  const _CloudUpdateView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LyricUpdateProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembaruan Lirik'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Status Card ──────────────────────────────────────────────────────
          _buildStatusCard(context, provider, colorScheme),
          const SizedBox(height: 24),

          // ─── Version Info Row ─────────────────────────────────────────────────
          _buildVersionInfoRow(context, provider, colorScheme),
          const SizedBox(height: 32),

          // ─── Action Buttons ───────────────────────────────────────────────────
          _buildCheckButton(context, provider, colorScheme),
          const SizedBox(height: 16),
          _buildDownloadButton(context, provider, colorScheme),

          // ─── Ready to Sync Banner ─────────────────────────────────────────────
          if (provider.isReadyToSync) ...[
            const SizedBox(height: 16),
            _buildReadyToSyncBanner(context, provider, colorScheme),
          ],

          // ─── Error Message ────────────────────────────────────────────────────
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(context, provider, colorScheme),
          ],

          const SizedBox(height: 32),

          // ─── Info Section ─────────────────────────────────────────────────────
          _buildInfoSection(context, colorScheme),
        ],
      ),
    );
  }

  // ─── Widget Builders ──────────────────────────────────────────────────────

  Widget _buildStatusCard(
    BuildContext context,
    LyricUpdateProvider provider,
    ColorScheme colorScheme,
  ) {
    final (icon, color, title, subtitle) = _resolveStatusDisplay(provider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: provider.state == UpdateScreenState.checking ||
                    provider.state == UpdateScreenState.downloading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: color,
                    ),
                  )
                : Icon(icon, key: ValueKey(icon), color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfoRow(
    BuildContext context,
    LyricUpdateProvider provider,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildVersionChip(
            context: context,
            label: 'Versi Alat',
            version: provider.localVersion ?? '0',
            icon: LucideIcons.cpu,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Icon(LucideIcons.arrowRight, color: colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: _buildVersionChip(
            context: context,
            label: 'Versi Server',
            version: provider.serverVersion ?? '—',
            icon: LucideIcons.cloud,
            colorScheme: colorScheme,
            highlight: provider.state == UpdateScreenState.updateAvailable,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionChip({
    required BuildContext context,
    required String label,
    required String version,
    required IconData icon,
    required ColorScheme colorScheme,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            version,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: highlight
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButton(
    BuildContext context,
    LyricUpdateProvider provider,
    ColorScheme colorScheme,
  ) {
    final isLoading = provider.state == UpdateScreenState.checking;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: provider.canCheck
            ? () => context.read<LyricUpdateProvider>().checkForUpdate()
            : null,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : const Icon(LucideIcons.refreshCw),
        label: Text(
          isLoading ? 'Memeriksa...' : 'Periksa Pembaruan',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    LyricUpdateProvider provider,
    ColorScheme colorScheme,
  ) {
    final isDownloading = provider.state == UpdateScreenState.downloading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: provider.canDownload || isDownloading ? 1.0 : 0.4,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          // Tombol HANYA aktif jika ada update tersedia
          onPressed: provider.canDownload
              ? () => context.read<LyricUpdateProvider>().downloadAssets()
              : null,
          icon: isDownloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(LucideIcons.download),
          label: Text(
            isDownloading ? 'Mengunduh...' : 'Unduh & Proses',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildReadyToSyncBanner(
    BuildContext context,
    LyricUpdateProvider provider,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Data Siap Dikirim ke Alat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kata-kata lirik versi ${provider.serverVersion} telah diunduh. '
            'Tekan tombol di bawah untuk mengimpor ke Workspace. '
            'Setelah itu, pilih file audio per deret dan jalankan Auto-Detect.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                // Memasukkan kata-kata ke Workspace
                if (provider.downloadedDataJson != null) {
                  final workspace = context.read<WorkspaceProvider>();
                  workspace.importFromCloudJson(
                    provider.downloadedDataJson!,
                    audioPaths: provider.downloadedAudioPaths.isNotEmpty
                        ? provider.downloadedAudioPaths
                        : null,
                  );
                  
                  // CARA A: Kunci (simpan) versi lokal HARI INI JUGA!
                  provider.commitUpdateSuccess();

                  // Tampilkan notifikasi sukses
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data berhasil diimpor ke Workspace! Buka tab Home untuk melihat.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              icon: const Icon(LucideIcons.folderInput),
              label: const Text(
                'Impor ke Workspace',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    LyricUpdateProvider provider,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle,
              color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.errorMessage ?? '',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoTile(
          LucideIcons.wifiOff,
          'Aman saat Offline',
          'Pemeriksaan update membutuhkan internet, namun alat tetap berfungsi normal tanpa update.',
          colorScheme,
        ),
        const SizedBox(height: 8),
        _buildInfoTile(
          LucideIcons.shieldCheck,
          'Kontrol Penuh di Tangan Anda',
          'Tidak ada yang berubah di alat tanpa konfirmasi eksplisit dari Anda.',
          colorScheme,
        ),
        const SizedBox(height: 8),
        _buildInfoTile(
          LucideIcons.bluetooth,
          'Membutuhkan Koneksi BLE',
          'Untuk mengirim data ke alat, Bluetooth harus terhubung ke perangkat ESP32.',
          colorScheme,
        ),
      ],
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String desc,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status Display Resolver ──────────────────────────────────────────────
  (IconData, Color, String, String) _resolveStatusDisplay(
      LyricUpdateProvider provider) {
    return switch (provider.state) {
      UpdateScreenState.idle => (
          LucideIcons.cloud,
          Colors.blue,
          'Siap Memeriksa',
          'Tekan tombol di bawah untuk memeriksa pembaruan terbaru.',
        ),
      UpdateScreenState.checking => (
          LucideIcons.loader,
          Colors.orange,
          'Memeriksa...',
          'Menghubungi server untuk memeriksa versi terbaru.',
        ),
      UpdateScreenState.upToDate => (
          LucideIcons.checkCircle,
          Colors.green,
          'Sudah Terbaru',
          'Lirik di alat Anda sudah menggunakan versi terbaru.',
        ),
      UpdateScreenState.updateAvailable => (
          LucideIcons.download,
          Colors.blue,
          'Update Tersedia! (${provider.serverVersion})',
          'Ada versi baru. Unduh untuk memperbarui lirik di alat.',
        ),
      UpdateScreenState.checkFailed => (
          LucideIcons.cloudOff,
          Colors.red,
          'Gagal Terhubung',
          'Tidak dapat menghubungi server. Periksa koneksi internet.',
        ),
      UpdateScreenState.downloading => (
          LucideIcons.download,
          Colors.orange,
          'Mengunduh Aset...',
          'Mengunduh data lirik terbaru dari server.',
        ),
      UpdateScreenState.readyToSync => (
          LucideIcons.checkCircle2,
          Colors.green,
          'Unduhan Selesai',
          'Data lirik siap dikirimkan ke alat ESP32 Anda.',
        ),
      UpdateScreenState.downloadFailed => (
          LucideIcons.alertTriangle,
          Colors.red,
          'Unduhan Gagal',
          'Terjadi kesalahan saat mengunduh. Silakan coba lagi.',
        ),
    };
  }
}
