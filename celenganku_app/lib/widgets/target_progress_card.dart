import 'package:flutter/material.dart';
import '../models/celengan_data.dart';
import '../utils/formatters.dart';

class TargetProgressCard extends StatelessWidget {
  final CelenganData data;
  final VoidCallback? onEditTarget;

  const TargetProgressCard({
    super.key,
    required this.data,
    this.onEditTarget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = data.sudahTercapai;
    final progress = data.persentaseTarget;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withOpacity(0.5)
              : theme.dividerColor.withOpacity(0.1),
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFFF59E0B).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDone
                          ? Icons.stars_rounded
                          : Icons.flag_rounded,
                      color: isDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFFD97706),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.info.targetNama,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Target: ${Formatters.rupiah(data.info.targetNominal)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Ubah Target Tabungan',
                onPressed: onEditTarget,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress Bar with Percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDone ? '🎉 Target Tercapai!' : 'Progres Pengumpulan',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                Formatters.persentase(progress),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDone ? const Color(0xFF10B981) : const Color(0xFF0D9488),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Custom Animated Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDone ? const Color(0xFF10B981) : const Color(0xFF0D9488),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Sisa nominal info
          Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 16,
                color: isDone
                    ? const Color(0xFF10B981)
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isDone
                      ? 'Hebat! Uang tabungan sudah cukup untuk membeli ${data.info.targetNama}.'
                      : 'Kurang ${Formatters.rupiah(data.sisaTarget)} lagi untuk mencapai target.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDone
                        ? const Color(0xFF10B981)
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
