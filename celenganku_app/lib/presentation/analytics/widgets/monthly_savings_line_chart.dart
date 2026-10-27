import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/services/analytics_service.dart';

const Color kHeritageForest = Color(0xFF064E3B);
const Color kSageTeal = Color(0xFF0D9488);
const Color kCoinBrass = Color(0xFFD97706);

class MonthlySavingsLineChart extends StatelessWidget {
  final List<MonthlyTrendPoint> trendPoints;

  const MonthlySavingsLineChart({
    super.key,
    required this.trendPoints,
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
    if (trendPoints.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          'Belum ada transaksi historis yang tercatat.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    double maxY = 10000;
    for (final p in trendPoints) {
      if (p.cumulativeAmount > maxY) {
        maxY = p.cumulativeAmount;
      }
    }
    maxY = (maxY * 1.2).ceilToDouble();

    final spots = List.generate(trendPoints.length, (i) {
      return FlSpot(i.toDouble(), trendPoints[i].cumulativeAmount);
    });

    return AspectRatio(
      aspectRatio: 1.6,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (trendPoints.length - 1).toDouble().clamp(1.0, 100.0),
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => kHeritageForest,
              tooltipRoundedRadius: 10,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final label = idx < trendPoints.length ? trendPoints[idx].label : '';
                  final rupiahFormat = NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  );
                  return LineTooltipItem(
                    '$label\n',
                    const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    children: [
                      TextSpan(
                        text: rupiahFormat.format(spot.y),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? (maxY / 4) : 2500,
            getDrawingHorizontalLine: (val) {
              return const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (trendPoints.length / 4).clamp(1.0, 10.0),
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < trendPoints.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        trendPoints[idx].label,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
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
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: kHeritageForest,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2.5,
                    strokeColor: kSageTeal,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    kHeritageForest.withValues(alpha: 0.25),
                    kSageTeal.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
