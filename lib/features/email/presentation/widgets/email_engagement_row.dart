// lib/features/email/presentation/widgets/email_engagement_row.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/repositories/email_repository.dart';

/// One row in an email engagement panel. Renders the recipient,
/// status badge, send time, and engagement summary (opens/clicks).
/// Tapping expands to show the full event timeline.
///
/// Used by:
///   - The signature progress card on contract detail
///   - The campaign detail screen
///   - The global email activity feed
class EmailEngagementRow extends StatefulWidget {
  final EmailEngagement engagement;
  const EmailEngagementRow({super.key, required this.engagement});

  @override
  State<EmailEngagementRow> createState() => _EmailEngagementRowState();
}

class _EmailEngagementRowState extends State<EmailEngagementRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.engagement;
    final m = e.message;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: e.events.isEmpty ? null : () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----- Top row: recipient + status badge + time -----
              Row(
                children: [
                  _statusDot(m.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.toName ?? m.toEmail,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (m.toName != null)
                          Text(
                            m.toEmail,
                            style: const TextStyle(
                                fontSize: 10.5, color: AppColors.muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusChip(m.status),
                  if (e.events.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ],
                ],
              ),
              // ----- Engagement summary -----
              if (e.openCount > 0 || e.clickCount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (e.openCount > 0) ...[
                      const Icon(Icons.visibility_outlined,
                          size: 12, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        'Opened ${e.openCount}x',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                      if (e.clickCount > 0) const SizedBox(width: 12),
                    ],
                    if (e.clickCount > 0) ...[
                      const Icon(Icons.touch_app_outlined,
                          size: 12, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        '${e.clickCount} click${e.clickCount == 1 ? "" : "s"}'
                            '${e.uniqueLinksClicked.length > 1 ? " on ${e.uniqueLinksClicked.length} links" : ""}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ],
              // ----- Bounce / error info if applicable -----
              if (m.bouncedAt != null || m.errorMessage != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 12, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        m.errorMessage ?? 'Bounced (${m.bounceType ?? "unknown reason"})',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
              // ----- Send time -----
              if (m.sentAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Sent ${Formatters.date(m.sentAt!)}',
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.muted),
                ),
              ],
              // ----- Expanded event timeline -----
              if (_expanded && e.events.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                ...e.events.map((ev) => _eventRow(ev)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDot(String status) {
    final color = switch (status) {
      'opened' || 'clicked' => AppColors.brand,
      'delivered' => Colors.green,
      'sent' || 'sending' || 'queued' => Colors.orange,
      'bounced' || 'failed' || 'complained' => Colors.red,
      _ => AppColors.muted,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _statusChip(String status) {
    final (bg, fg, label) = switch (status) {
      'clicked' => (AppColors.brandLight, AppColors.brand, 'Clicked'),
      'opened' => (AppColors.brandLight, AppColors.brand, 'Opened'),
      'delivered' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), 'Delivered'),
      'sent' => (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'Sent'),
      'queued' || 'sending' => (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'Sending'),
      'bounced' => (const Color(0xFFFFEBEE), const Color(0xFFC62828), 'Bounced'),
      'complained' => (const Color(0xFFFFEBEE), const Color(0xFFC62828), 'Spam'),
      'failed' => (const Color(0xFFFFEBEE), const Color(0xFFC62828), 'Failed'),
      _ => (AppColors.bg2, AppColors.muted, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _eventRow(EmailMessageEvent ev) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ev.eventLabel} • ${Formatters.dateTime(ev.occurredAt)}',
                  style: const TextStyle(fontSize: 10.5),
                ),
                if (ev.linkUrl != null)
                  Text(
                    ev.linkUrl!,
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                        decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}