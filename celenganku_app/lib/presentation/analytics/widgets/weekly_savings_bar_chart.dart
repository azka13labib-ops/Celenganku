import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/services/analytics_service.dart';

// Palet Warna Anti-Slop (Strict 3 Core + 1 Deliberate Accent)
const Color kHeritageForest = Color(0xFF064E3B); // Bar Color Primer
const Color kSageTeal = Color(0xFF0D9488);       // Bar Hover / Secondary
const Color kCoinBrass = Color(0xFFD97706);      // Aksen Puncak Tertinggi

class WeeklySavingsBarChart extends StatelessWidget {
  final List<DailyAnalyticsData> weeklyData;

  const WeeklySavingsBarChart({
    super.key,
    required this.weeklyData,
  });

  String _formatCurrency(double val) {
    final formatter = NumberFormat.compactCurrency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    double maxY = 10000;
    for (final d in weeklyData) {
      if (d.totalNominal > maxY) {
        maxY = d.totalNominal;
      }
    }
    // Beri buffer 25% di atas nilai tertinggi
    maxY = (maxY * 1.25).ceilToDouble();

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => kHeritageForest,
              tooltipRoundedRadius: 10,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dayData = weeklyData[group.x.toInt()];
                final rupiahFormat = NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                );
                return BarTooltipItem(
                  '${dayData.dayName}\n',
                  const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  children: [
                    TextSpan(
                      text: rupiahFormat.format(dayData.totalNominal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '\n(${dayData.count} transaksi)',
                      style: const TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 10,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < weeklyData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        weeklyData[idx].dayName,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: maxY > 0 ? (maxY / 4) : 2500,
                getTitlesWidget: (val, meta) {
                  if (val == 0) return const SizedBox.shrink();
                  return Text(
                    _formatCurrency(val),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? (maxY / 4) : 2500,
            getDrawingHorizontalLine: (val) {
              return FlLine(
                color: const Color(0xFFE2E8F0),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: weeklyData.map((d) {
            final isPeak = d.totalNominal > 0 && d.totalNominal == maxY / 1.25;
            return BarChartGroupData(
              x: d.dayIndex,
              barRods: [
                BarChartRodData(
                  toY: d.totalNominal,
                  color: isPeak ? kCoinBrass : (d.totalNominal > 0 ? kHeritageForest : const Color(0xFFCBD5E1)),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: const Color(0xFFF1F5F9),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
