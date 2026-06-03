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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (trend != null) ...[
              const SizedBox(height: 2),
              Text(
                trend!,
                style: TextStyle(
                  fontSize: 11,
                  color: trendPositive ? AppColors.brand : AppColors.danger,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
