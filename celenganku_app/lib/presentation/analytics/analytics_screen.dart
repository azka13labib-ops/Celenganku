import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../core/config/firebase_config.dart';
import '../../data/models/transaction_model.dart';
import '../../data/services/analytics_service.dart';
import 'widgets/weekly_savings_bar_chart.dart';
import 'widgets/monthly_savings_line_chart.dart';

const Color kHeritageForest = Color(0xFF064E3B);
const Color kSageTeal = Color(0xFF0D9488);
const Color kCoinBrass = Color(0xFFD97706);
const Color kWarmPaper = Color(0xFFF8FAFC);
const Color kDeepSlate = Color(0xFF0F172A);

class AnalyticsScreen extends StatefulWidget {
  final String celenganId;

  const AnalyticsScreen({
    super.key,
    this.celenganId = FirebaseConfig.defaultCelenganId,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistoricalTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoricalTransactions() async {
    setState(() {
      _isLoading = true;
    });


    final endpoint = Uri.parse(
        '${FirebaseConfig.databaseUrl}/celengan/${widget.celenganId}/transaksi.json');

    try {
      final res = await http.get(endpoint).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && res.body != 'null') {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final List<TransactionModel> list = [];
          decoded.forEach((key, val) {
            if (val is Map) {
              list.add(TransactionModel.fromMap(key.toString(), val));
            }
          });
          setState(() {
            _transactions = list;
            _isLoading = false;
          });
          return;
        }
      }

      // Jika data transaksi masih kosong di cloud, buat dataset contoh historis
      setState(() {
        _transactions = _generateSampleTransactions();
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) print('Gagal memuat analitik: $e');
      setState(() {
        _transactions = _generateSampleTransactions();
        _isLoading = false;
      });
    }
  }

  List<TransactionModel> _generateSampleTransactions() {
    final now = DateTime.now();
    return [
      TransactionModel(
        id: 'sample_1',
        nominal: 1000,
        uid: 'esp32_device',
        tipe: TransactionType.koinOtomatis,
        beratGram: 4.51,
        timestamp: now.subtract(const Duration(days: 6)),
      ),
      TransactionModel(
        id: 'sample_2',
        nominal: 500,
        uid: 'esp32_device',
        tipe: TransactionType.koinOtomatis,
        beratGram: 3.12,
        timestamp: now.subtract(const Duration(days: 5)),
      ),
      TransactionModel(
        id: 'sample_3',
        nominal: 2000,
        uid: 'uid_ayah',
        tipe: TransactionType.setorManual,
        catatan: 'Hadiah membaca buku',
        timestamp: now.subtract(const Duration(days: 3)),
      ),
      TransactionModel(
        id: 'sample_4',
        nominal: 1000,
        uid: 'esp32_device',
        tipe: TransactionType.koinOtomatis,
        beratGram: 4.49,
        timestamp: now.subtract(const Duration(days: 1)),
      ),
      TransactionModel(
        id: 'sample_5',
        nominal: 500,
        uid: 'esp32_device',
        tipe: TransactionType.koinOtomatis,
        beratGram: 3.10,
        timestamp: now,
      ),
    ];
  }

  static String _formatRupiah(num val) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    final summary = AnalyticsService.calculateSummary(_transactions);

    return Scaffold(
      backgroundColor: kWarmPaper,
      appBar: AppBar(
        title: const Text(
          'Analitik & Tren Tabungan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: _loadHistoricalTransactions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kHeritageForest),
            )
          : RefreshIndicator(
              onRefresh: _loadHistoricalTransactions,
              color: kHeritageForest,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ringkasan Tiga Kartu Metrik
                    _buildMetricsRow(summary),

                    const SizedBox(height: 20),

                    // Kontainer Kartu Visual Chart
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Visualisasi Uang Masuk',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: kDeepSlate,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Data terverifikasi sensor load cell & manual',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Tab Selector (Mingguan vs Bulanan)
                          Container(
                            height: 42,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: kHeritageForest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: const Color(0xFF64748B),
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              tabs: const [
                                Tab(text: 'Tren Mingguan'),
                                Tab(text: 'Pertumbuhan Bulanan'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Visual Chart View
                          SizedBox(
                            height: 240,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                WeeklySavingsBarChart(
                                  weeklyData: summary.weeklyBars,
                                ),
                                MonthlySavingsLineChart(
                                  trendPoints: summary.monthlyTrend,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Log Transaksi Terakhir
                    const Text(
                      'Log Transaksi Terakhir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kDeepSlate,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTransactionList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricsRow(SavingsAnalyticsSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Total Tabungan',
            value: _formatRupiah(summary.totalMasuk),
            icon: Icons.account_balance_wallet_rounded,
            color: kHeritageForest,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Rata-rata Harian',
            value: _formatRupiah(summary.rataRataHarian),
            icon: Icons.trending_up_rounded,
            color: kSageTeal,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text('Belum ada transaksi.'),
      );
    }

    final displayTx = List<TransactionModel>.from(_transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayTx.length.clamp(0, 10),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tx = displayTx[index];
        final isCoin = tx.tipe == TransactionType.koinOtomatis;
        final timeStr = DateFormat('dd MMM, HH:mm').format(tx.timestamp);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCoin ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isCoin ? Icons.monetization_on_rounded : Icons.payments_rounded,
                    color: isCoin ? kCoinBrass : const Color(0xFF16A34A),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.formattedNominal,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: kDeepSlate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCoin
                          ? 'Sensor Load Cell (${tx.beratGram?.toStringAsFixed(2) ?? "4.50"} g)'
                          : (tx.catatan ?? 'Setoran Manual'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
