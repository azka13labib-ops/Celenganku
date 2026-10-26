import 'package:flutter/material.dart';
import '../services/celengan_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = CelenganService();
  late TextEditingController _urlCtrl;
  late TextEditingController _deviceIdCtrl;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: _service.databaseUrl);
    _deviceIdCtrl = TextEditingController(text: _service.deviceId);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _deviceIdCtrl.dispose();
    super.dispose();
  }

  void _saveConfig() {
    _service.configure(
      databaseUrl: _urlCtrl.text.trim(),
      deviceId: _deviceIdCtrl.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Konfigurasi Firebase diperbarui. Menghubungkan ulang...'),
        backgroundColor: Color(0xFF0D9488),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    await _service.fetchLatest();
    if (mounted) {
      setState(() => _isTesting = false);
      final isConnected = _service.status == ConnectionStatus.connected;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConnected
                ? 'Berhasil terhubung ke Firebase!'
                : 'Status: ${_service.status.name}. Pastikan Firebase URL dan Security Rules dibuka.',
          ),
          backgroundColor:
              isConnected ? const Color(0xFF10B981) : Colors.orange[800],
        ),
      );
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Saldo Celengan?'),
        content: const Text(
          'Saldo akan kembali menjadi Rp 0 dan riwayat transaksi akan dihapus. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.resetSaldo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldo berhasil di-reset.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan & IoT Endpoint'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Connection Card
          StreamBuilder<ConnectionStatus>(
            stream: _service.statusStream,
            initialData: _service.status,
            builder: (context, snapshot) {
              final status = snapshot.data ?? ConnectionStatus.demoMode;
              Color badgeColor;
              String statusText;

              switch (status) {
                case ConnectionStatus.connected:
                  badgeColor = const Color(0xFF10B981);
                  statusText = 'Terhubung ke Firebase Realtime (SSE)';
                  break;
                case ConnectionStatus.connecting:
                  badgeColor = Colors.orange;
                  statusText = 'Sedang Menghubungkan...';
                  break;
                case ConnectionStatus.disconnected:
                  badgeColor = Colors.red;
                  statusText = 'Terputus dari Database';
                  break;
                case ConnectionStatus.demoMode:
                  badgeColor = Colors.blue;
                  statusText = 'Mode Demo / Simulasi Lokal';
                  break;
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering, color: badgeColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status Koneksi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Firebase Database Config
          Text(
            'Konfigurasi Firebase Realtime Database',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: 'Firebase RTDB URL',
              hintText: 'https://[PROJECT-ID].firebaseio.com',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              helperText: 'URL database dari Firebase Console',
              prefixIcon: const Icon(Icons.cloud_outlined),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _deviceIdCtrl,
            decoration: InputDecoration(
              labelText: 'Node Device ID',
              hintText: 'celengan_01',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              helperText: 'Nama root node pada JSON tree',
              prefixIcon: const Icon(Icons.devices_other),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Tes Koneksi'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Simpan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Endpoint Info for ESP32 & Wokwi
          Text(
            'Panduan Endpoint ESP32 (Wokwi / Hardware)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HTTP PATCH URL:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SelectableText(
                  '${_urlCtrl.text.trim()}/${_deviceIdCtrl.text.trim()}.json',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF0D9488),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Payload Atomic Increment:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SelectableText(
                    '{"saldo": {".sv": {"increment": 1000}}, "terakhir_masuk": 1000}',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Danger Zone
          Text(
            'Pengaturan Pengujian',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _confirmReset,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text(
              'Reset Saldo & Riwayat ke Nol',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
