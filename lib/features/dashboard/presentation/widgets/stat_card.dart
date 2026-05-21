// lib/features/dashboard/presentation/widgets/stat_card.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final bool trendPositive;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.text)),
            if (trend != null) ...[
              const SizedBox(height: 4),
              Text(
                trend!,
                style: TextStyle(
                  fontSize: 11,
                  color: trendPositive ? AppColors.brand : AppColors.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
