import 'package:flutter/material.dart';
import '../models/celengan_data.dart';
import '../services/celengan_service.dart';
import '../widgets/saldo_hero_card.dart';
import '../widgets/target_progress_card.dart';
import '../widgets/riwayat_transaksi_card.dart';
import '../widgets/deposit_bottom_sheet.dart';
import '../widgets/edit_target_dialog.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = CelenganService();
  int _lastKnownSaldo = 0;

  @override
  void initState() {
    super.initState();
    _lastKnownSaldo = _service.currentData.saldo;
  }

  void _openDepositSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DepositBottomSheet(),
    );
  }

  void _openEditTarget(CelenganInfo info) {
    showDialog(
      context: context,
      builder: (context) => EditTargetDialog(currentInfo: info),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF0D9488),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Celenganku Pintar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StreamBuilder<ConnectionStatus>(
                  stream: _service.statusStream,
                  initialData: _service.status,
                  builder: (context, snapshot) {
                    final status = snapshot.data ?? ConnectionStatus.demoMode;
                    String text;
                    Color color;
                    switch (status) {
                      case ConnectionStatus.connected:
                        text = 'Terhubung Realtime';
                        color = const Color(0xFF10B981);
                        break;
                      case ConnectionStatus.connecting:
                        text = 'Menghubungkan...';
                        color = Colors.orange;
                        break;
                      case ConnectionStatus.disconnected:
                        text = 'Terputus';
                        color = Colors.red;
                        break;
                      case ConnectionStatus.demoMode:
                        text = 'Mode Demo';
                        color = Colors.blue;
                        break;
                    }
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          text,
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openDepositSheet,
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text(
          'Simulasi Koin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<CelenganData>(
        stream: _service.stream,
        initialData: _service.currentData,
        builder: (context, snapshot) {
          final data = snapshot.data ?? CelenganData.initialDemo();

          // Check if saldo increased to show celebratory toast
          if (data.saldo > _lastKnownSaldo && _lastKnownSaldo > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                    backgroundColor: const Color(0xFF0F766E),
                    duration: const Duration(seconds: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    content: Row(
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Koin baru terdeteksi! Saldo bertambah menjadi Rp ${data.saldo}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            });
          }
          _lastKnownSaldo = data.saldo;

          return RefreshIndicator(
            onRefresh: _service.fetchLatest,
            color: const Color(0xFF0D9488),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Hero Saldo Card
                SaldoHeroCard(
                  data: data,
                  onQuickDeposit: _openDepositSheet,
                ),

                const SizedBox(height: 20),

                // Target Tabungan Progress Card
                TargetProgressCard(
                  data: data,
                  onEditTarget: () => _openEditTarget(data.info),
                ),

                const SizedBox(height: 20),

                // Riwayat Koin Masuk
                RiwayatTransaksiCard(riwayat: data.riwayat),
              ],
            ),
          );
        },
      ),
    );
  }
}
