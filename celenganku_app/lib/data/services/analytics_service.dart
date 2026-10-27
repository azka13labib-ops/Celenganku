import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class DailyAnalyticsData {
  final String dayName;   // Sen, Sel, Rab, dll.
  final int dayIndex;     // 0 (Senin) - 6 (Minggu)
  final double totalNominal;
  final int count;

  const DailyAnalyticsData({
    required this.dayName,
    required this.dayIndex,
    required this.totalNominal,
    required this.count,
  });
}

class MonthlyTrendPoint {
  final DateTime date;
  final String label;
  final double cumulativeAmount;

  const MonthlyTrendPoint({
    required this.date,
    required this.label,
    required this.cumulativeAmount,
  });
}

class SavingsAnalyticsSummary {
  final double totalMasuk;
  final double rataRataHarian;
  final int totalTransaksi;
  final List<DailyAnalyticsData> weeklyBars;
  final List<MonthlyTrendPoint> monthlyTrend;

  const SavingsAnalyticsSummary({
    required this.totalMasuk,
    required this.rataRataHarian,
    required this.totalTransaksi,
    required this.weeklyBars,
    required this.monthlyTrend,
  });
}

/// Business Logic Service untuk kalkulasi agregasi analitik tabungan
class AnalyticsService {
  /// Mengolah daftar transaksi mentah menjadi statistik mingguan dan bulanan
  static SavingsAnalyticsSummary calculateSummary(List<TransactionModel> transactions) {
    if (transactions.isEmpty) {
      return _generateEmptySummary();
    }

    // Urutkan transaksi dari terlama ke terbaru
    final sortedTx = List<TransactionModel>.from(transactions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final now = DateTime.now();
    // Awal minggu ini (Senin)
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    // Inisialisasi 7 hari dalam minggu (Senin - Minggu)
    final daysOfWeekLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final Map<int, double> weeklyTotals = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    final Map<int, int> weeklyCounts = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

    double grandTotal = 0;

    for (final tx in sortedTx) {
      grandTotal += tx.nominal;

      // Cek apakah masuk dalam minggu ini
      if (tx.timestamp.isAfter(startOfWeek)) {
        final dayIdx = tx.timestamp.weekday - 1; // 1-7 diubah ke 0-6
        if (dayIdx >= 0 && dayIdx < 7) {
          weeklyTotals[dayIdx] = (weeklyTotals[dayIdx] ?? 0) + tx.nominal;
          weeklyCounts[dayIdx] = (weeklyCounts[dayIdx] ?? 0) + 1;
        }
      }
    }

    final weeklyBars = List.generate(7, (i) {
      return DailyAnalyticsData(
        dayName: daysOfWeekLabels[i],
        dayIndex: i,
        totalNominal: weeklyTotals[i] ?? 0.0,
        count: weeklyCounts[i] ?? 0,
      );
    });

    // Buat data titik pertumbuhan kumulatif (Monthly Trend)
    final List<MonthlyTrendPoint> trendPoints = [];
    double runningSum = 0;

    for (final tx in sortedTx) {
      runningSum += tx.nominal;
      final label = DateFormat('dd/MM').format(tx.timestamp);
      trendPoints.add(MonthlyTrendPoint(
        date: tx.timestamp,
        label: label,
        cumulativeAmount: runningSum,
      ));
    }

    final avgDaily = weeklyTotals.values.reduce((a, b) => a + b) / 7.0;

    return SavingsAnalyticsSummary(
      totalMasuk: grandTotal,
      rataRataHarian: avgDaily,
      totalTransaksi: sortedTx.length,
      weeklyBars: weeklyBars,
      monthlyTrend: trendPoints,
    );
  }

  static SavingsAnalyticsSummary _generateEmptySummary() {
    final daysOfWeekLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return SavingsAnalyticsSummary(
      totalMasuk: 0,
      rataRataHarian: 0,
      totalTransaksi: 0,
      weeklyBars: List.generate(
        7,
        (i) => DailyAnalyticsData(
          dayName: daysOfWeekLabels[i],
          dayIndex: i,
          totalNominal: 0,
          count: 0,
        ),
      ),
      monthlyTrend: [],
    );
  }
}
