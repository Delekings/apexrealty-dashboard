// lib/features/email/presentation/screens/email_campaign_detail_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/repositories/email_repository.dart';
import '../widgets/email_engagement_row.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

/// Fetches all messages (and their events) for one campaign.
final _campaignEngagementProvider =
FutureProvider.family<List<EmailEngagement>, String>(
      (ref, campaignId) async {
    return ref.read(_emailRepoProvider).engagementForCampaign(campaignId);
  },
);

/// Fetches the campaign metadata.
final _campaignProvider =
FutureProvider.family<EmailCampaign?, String>((ref, campaignId) async {
  // Single-campaign fetch — reuse listCampaigns and filter (simple, works
  // until we add a getById method to EmailRepository).
  final all = await ref.read(_emailRepoProvider).listCampaigns(limit: 1000);
  try {
    return all.firstWhere((c) => c.id == campaignId);
  } catch (_) {
    return null;
  }
});

class EmailCampaignDetailScreen extends ConsumerWidget {
  final String campaignId;
  const EmailCampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(_campaignProvider(campaignId));
    final engagement = ref.watch(_campaignEngagementProvider(campaignId));

    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: campaign.when(
          loading: () => const Text('Loading…'),
          error: (_, __) => const Text('Campaign'),
          data: (c) => Text(
            c?.name ?? 'Campaign',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
        ),
      ),
      body: campaign.when(
        loading: () =>
        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load campaign: $e',
                style: const TextStyle(color: AppColors.muted)),
          ),
        ),
        data: (c) {
          if (c == null) {
            return const Center(
              child: Text('Campaign not found',
                  style: TextStyle(color: AppColors.muted)),
            );
          }
          return engagement.when(
            loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load engagement: $e',
                    style: const TextStyle(color: AppColors.muted)),
              ),
            ),
            data: (eng) => _Body(campaign: c, engagement: eng),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final EmailCampaign campaign;
  final List<EmailEngagement> engagement;
  const _Body({required this.campaign, required this.engagement});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(campaign: campaign),
          const SizedBox(height: 16),
          _MetricsRow(engagement: engagement, campaign: campaign),
          const SizedBox(height: 16),
          _EngagementChart(engagement: engagement, campaign: campaign),
          const SizedBox(height: 16),
          _RecipientsList(engagement: engagement),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final EmailCampaign campaign;
  const _Header({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.subject,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(campaign.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 12, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                campaign.sendCompletedAt != null
                    ? 'Sent ${Formatters.dateTime(campaign.sendCompletedAt!)}'
                    : campaign.scheduledFor != null
                    ? 'Scheduled for ${Formatters.dateTime(campaign.scheduledFor!)}'
                    : 'Draft',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.people_outline,
                  size: 12, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                '${campaign.totalRecipients} recipients',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final (bg, fg, label) = switch (status) {
      'completed' => (AppColors.brandLight, AppColors.brand, 'Sent'),
      'sending' => (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'Sending'),
      'scheduled' =>
      (const Color(0xFFE6F2FB), const Color(0xFF1A6FA3), 'Scheduled'),
      'failed' => (const Color(0xFFFFEBEE), const Color(0xFFC62828), 'Failed'),
      'cancelled' => (AppColors.bg2, AppColors.muted, 'Cancelled'),
      _ => (AppColors.bg2, AppColors.muted, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final List<EmailEngagement> engagement;
  final EmailCampaign campaign;
  const _MetricsRow({required this.engagement, required this.campaign});

  @override
  Widget build(BuildContext context) {
    final total = engagement.length;
    final delivered = engagement.where((e) => e.message.wasDelivered).length;
    final opened = engagement.where((e) => e.message.openedAt != null).length;
    final clicked = engagement.where((e) => e.message.clickedAt != null).length;
    final bounced = engagement.where((e) => e.message.bouncedAt != null).length;

    String pct(int n) =>
        total == 0 ? '—' : '${((n / total) * 100).toStringAsFixed(1)}%';

    return Row(
      children: [
        Expanded(child: _metric('Sent', '$total', '100%', AppColors.muted)),
        const SizedBox(width: 8),
        Expanded(
            child: _metric(
                'Delivered', '$delivered', pct(delivered), Colors.green)),
        const SizedBox(width: 8),
        Expanded(
            child: _metric('Opened', '$opened', pct(opened), AppColors.brand)),
        const SizedBox(width: 8),
        Expanded(
            child:
            _metric('Clicked', '$clicked', pct(clicked), AppColors.gold)),
        const SizedBox(width: 8),
        Expanded(
            child:
            _metric('Bounced', '$bounced', pct(bounced), AppColors.danger)),
      ],
    );
  }

  Widget _metric(String label, String count, String rate, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            rate,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RecipientsList extends StatelessWidget {
  final List<EmailEngagement> engagement;
  const _RecipientsList({required this.engagement});

  @override
  Widget build(BuildContext context) {
    if (engagement.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'No emails were sent for this campaign.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mark_email_read_outlined,
                size: 14, color: AppColors.brand),
            const SizedBox(width: 6),
            const Text('Recipients',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(
              '${engagement.length}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...engagement.map((e) => EmailEngagementRow(engagement: e)),
      ],
    );
  }
}

class _EngagementChart extends StatelessWidget {
  final List<EmailEngagement> engagement;
  final EmailCampaign campaign;
  const _EngagementChart({required this.engagement, required this.campaign});

  @override
  Widget build(BuildContext context) {
    // Collect all events of the right types across all messages
    final allOpens = <DateTime>[];
    final allClicks = <DateTime>[];
    for (final e in engagement) {
      for (final ev in e.events) {
        if (ev.eventType == 'opened') allOpens.add(ev.occurredAt);
        if (ev.eventType == 'clicked') allClicks.add(ev.occurredAt);
      }
    }

    // Empty state — no events yet
    if (allOpens.isEmpty && allClicks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: const [
            Icon(Icons.timeline_outlined, size: 28, color: AppColors.muted),
            SizedBox(height: 8),
            Text(
              'No engagement yet',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Opens and clicks will appear here as recipients engage.',
              style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Time range: from send (or earliest event) to latest event
    allOpens.sort();
    allClicks.sort();
    final allEvents = <DateTime>[...allOpens, ...allClicks];
    allEvents.sort();
    final start = campaign.sendCompletedAt ?? allEvents.first;
    final end = allEvents.last;
    final spanMs = end.difference(start).inMilliseconds;
    // Avoid divide-by-zero if all events at the same moment
    final spanSafe = spanMs == 0 ? 1 : spanMs;

    // Build cumulative-count series. We sample at every event timestamp.
    final opensSpots = <FlSpot>[];
    final clicksSpots = <FlSpot>[];
    int opensCount = 0;
    int clicksCount = 0;

    // Start at (0, 0)
    opensSpots.add(const FlSpot(0, 0));
    clicksSpots.add(const FlSpot(0, 0));

    // Merge timestamps in order; bump the appropriate count and emit a spot
    final merged = <(DateTime, String)>[];
    for (final t in allOpens) merged.add((t, 'open'));
    for (final t in allClicks) merged.add((t, 'click'));
    merged.sort((a, b) => a.$1.compareTo(b.$1));

    for (final m in merged) {
      final x = m.$1.difference(start).inMilliseconds / spanSafe;
      if (m.$2 == 'open') {
        opensCount++;
        opensSpots.add(FlSpot(x, opensCount.toDouble()));
      } else {
        clicksCount++;
        clicksSpots.add(FlSpot(x, clicksCount.toDouble()));
      }
    }

    // Always extend both series to x=1 with their current totals
    if (opensSpots.last.x < 1) {
      opensSpots.add(FlSpot(1.0, opensCount.toDouble()));
    }
    if (clicksSpots.last.x < 1) {
      clicksSpots.add(FlSpot(1.0, clicksCount.toDouble()));
    }

    final maxY = (opensCount > clicksCount ? opensCount : clicksCount)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_outlined,
                  size: 14, color: AppColors.brand),
              const SizedBox(width: 6),
              const Text('Engagement over time',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              _legendDot(AppColors.brand, 'Opens'),
              const SizedBox(width: 12),
              _legendDot(AppColors.gold, 'Clicks'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 1,
                minY: 0,
                maxY: maxY < 1 ? 1 : maxY * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY < 5 ? 1 : (maxY / 5).ceilToDouble(),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 0.5,
                      getTitlesWidget: (value, meta) {
                        final t = DateTime.fromMillisecondsSinceEpoch(
                          start.millisecondsSinceEpoch +
                              (spanSafe * value).round(),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _shortTime(t),
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.muted),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: maxY < 5 ? 1 : (maxY / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.muted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: opensSpots,
                    isCurved: false,
                    color: AppColors.brand,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.brand.withOpacity(0.08),
                    ),
                  ),
                  LineChartBarData(
                    spots: clicksSpots,
                    isCurved: false,
                    color: AppColors.gold,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.gold.withOpacity(0.08),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    tooltipBorder: const BorderSide(color: AppColors.border),
                    getTooltipItems: (spots) => spots.map((spot) {
                      final series =
                      spot.barIndex == 0 ? 'Opens' : 'Clicks';
                      return LineTooltipItem(
                        '$series: ${spot.y.toInt()}',
                        TextStyle(
                          fontSize: 11,
                          color: spot.barIndex == 0
                              ? AppColors.brand
                              : AppColors.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
        ),
      ],
    );
  }

  String _shortTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays > 0) {
      return '${t.day}/${t.month}';
    }
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}