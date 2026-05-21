// lib/features/dashboard/presentation/widgets/activity_timeline.dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';

class ActivityTimeline extends StatelessWidget {
  final List<ActivityEntry> entries;
  const ActivityTimeline({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  decoration: BoxDecoration(
                    color: _colorFor(e.action),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.description ?? _defaultLabel(e),
                        style: const TextStyle(fontSize: 13, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.relative(e.createdAt),
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _colorFor(String action) {
    switch (action) {
      case 'paid':
      case 'payment_received':
      case 'created':
        return AppColors.brand;
      case 'reminder_sent':
        return AppColors.gold;
      case 'sent':
      case 'sent_for_signature':
        return AppColors.info;
      case 'overdue':
        return AppColors.danger;
      default:
        return AppColors.muted;
    }
  }

  String _defaultLabel(ActivityEntry e) =>
      '${e.action.replaceAll('_', ' ')} — ${e.entityType}';
}