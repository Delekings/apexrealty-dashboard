// lib/features/contracts/presentation/screens/contract_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/contracts_repository.dart';
import '../../../../data/repositories/documents_repository.dart';
import '../../../documents/widgets/send_for_signature_dialog.dart';
import '../../providers/contracts_providers.dart';
import '../widgets/record_payment_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/services/supabase_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../data/repositories/documents_repository.dart';
import '../../../documents/widgets/send_for_signature_dialog.dart';


class ContractDetailScreen extends ConsumerWidget {
  final String contractId;
  const ContractDetailScreen({super.key, required this.contractId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(contractDetailProvider(contractId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => Center(
          child: Text('Could not load contract: $e',
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (d) => _Body(detail: d, contractId: contractId),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final ContractDetail detail;
  final String contractId;
  const _Body({required this.detail, required this.contractId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = detail.contract;
    final wide = MediaQuery.of(context).size.width >= 1000;
    final progress = ref.watch(contractSignatureProgressProvider(c.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Header row ----
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => context.go('/properties/${c.propertyId}'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c.contractNo,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      _StatusBadge(status: c.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${detail.clientName} · ${detail.propertyTitle}'
                        '${c.unitLabel != null ? " · ${c.unitLabel}" : ""}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            // Sign / status button or chip
            progress.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => _sendButton(context, detail),
              data: (p) {
                if (p != null && p.docStatus != 'draft') {
                  return _SignatureStatusChip(progress: p, contractId: c.id);
                }
                return _sendButton(context, detail);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ---- Main body ----
        Expanded(
          child: wide
              ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 2,
                  child: _LeftColumn(
                      detail: detail, contractId: contractId)),
              const SizedBox(width: 16),
              Expanded(child: _RightColumn(detail: detail)),
            ],
          )
              : SingleChildScrollView(
            child: Column(
              children: [
                _LeftColumn(
                    detail: detail, contractId: contractId),
                const SizedBox(height: 12),
                _RightColumn(detail: detail),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sendButton(BuildContext context, ContractDetail detail) {
    return FilledButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => SendForSignatureDialog(contractDetail: detail),
      ),
      icon: const Icon(Icons.draw, size: 14),
      label: const Text('Send for signature'),
    );
  }
}

class _SignatureStatusChip extends ConsumerStatefulWidget {
  final SignatureProgress progress;
  final String contractId;
  const _SignatureStatusChip(
      {required this.progress, required this.contractId});

  @override
  ConsumerState<_SignatureStatusChip> createState() =>
      _SignatureStatusChipState();
}

class _SignatureStatusChipState
    extends ConsumerState<_SignatureStatusChip> {
  bool _busy = false;
  String? _error;

  Future<void> _downloadOrFinalize() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile?.agencyId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Find the latest document for this contract
      final doc = await SupabaseService.client
          .from('documents')
          .select('id, signed_pdf_path, status')
          .eq('contract_id', widget.contractId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      String? path = doc['signed_pdf_path'] as String?;
      final docId = doc['id'] as String;

      // If not yet finalized, generate now
      if (path == null) {
        path = await ref
            .read(documentsRepoProvider)
            .finalizeSignedDocument(
          documentId: docId,
          agencyId: profile!.agencyId!,
        );
        ref.invalidate(
            contractSignatureProgressProvider(widget.contractId));
      }

      // Get a signed URL and open it
      final url = await ref
          .read(documentsRepoProvider)
          .signedPdfUrl(path);
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final signed = p.signers.where((s) => s.status == 'signed').length;
    final total = p.signers.length;
    final isDone = p.docStatus == 'fully_signed' ||
        p.docStatus == 'completed';

    if (isDone) {
      return Tooltip(
        message: _error ?? 'Download the signed agreement',
        child: FilledButton.icon(
          onPressed: _busy ? null : _downloadOrFinalize,
          icon: _busy
              ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download, size: 14),
          label: Text(_busy
              ? 'Generating…'
              : p.docStatus == 'completed'
              ? 'Download signed agreement'
              : 'Finalize & download'),
        ),
      );
    }

    // In-progress chip
    final color = AppColors.warn;
    final label = 'Signed $signed/$total';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.draw_outlined, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  final ContractDetail detail;
  final String contractId;
  const _LeftColumn({required this.detail, required this.contractId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressCard(detail: detail),
        const SizedBox(height: 12),
        _InstallmentScheduleCard(
            detail: detail, contractId: contractId),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  final ContractDetail detail;
  const _RightColumn({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(detail: detail),
        const SizedBox(height: 12),
        _PaymentHistoryCard(payments: detail.payments),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final ContractDetail detail;
  const _ProgressCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final fraction = detail.progressFraction;
    final pct = (fraction * 100).toStringAsFixed(0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment progress',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('$pct%',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                backgroundColor: AppColors.bg2,
                valueColor: const AlwaysStoppedAnimation(AppColors.brand),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    label: 'Paid',
                    value: Formatters.naira(detail.totalPaid),
                    color: AppColors.brand,
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                Expanded(
                  child: _miniStat(
                    label: 'Remaining',
                    value: Formatters.naira(detail.totalBalance),
                    color: detail.totalBalance > 0
                        ? AppColors.warn
                        : AppColors.brand,
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                Expanded(
                  child: _miniStat(
                    label: 'Total contract',
                    value: Formatters.naira(detail.contract.totalPrice),
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
      {required String label,
        required String value,
        required Color color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ],
    );
  }
}

class _InstallmentScheduleCard extends StatelessWidget {
  final ContractDetail detail;
  final String contractId;
  const _InstallmentScheduleCard(
      {required this.detail, required this.contractId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Installment schedule',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${detail.installments.where((i) => i.status == InstallmentStatus.paid).length} / ${detail.installments.length} paid',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final inst in detail.installments)
              _InstallmentRow(
                installment: inst,
                contractId: contractId,
                total: detail.installments.length,
              ),
          ],
        ),
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final Installment installment;
  final String contractId;
  final int total;
  const _InstallmentRow({
    required this.installment,
    required this.contractId,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final canPay = installment.status != InstallmentStatus.paid &&
        installment.status != InstallmentStatus.waived;
    final label = 'Installment ${installment.sequence} of $total';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          _statusDot(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    _statusChip(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Due ${Formatters.date(installment.dueDate)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.naira(installment.amount),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              if (installment.amountPaid > 0 &&
                  installment.status != InstallmentStatus.paid)
                Text(
                  'Paid ${Formatters.naira(installment.amountPaid)}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.brand),
                ),
            ],
          ),
          if (canPay) ...[
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => RecordPaymentDialog(
                  contractId: contractId,
                  installment: installment,
                  installmentLabel: label,
                ),
              ),
              child: const Text('Record',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusDot() {
    final color = switch (installment.status) {
      InstallmentStatus.paid => AppColors.brand,
      InstallmentStatus.partial => AppColors.gold,
      InstallmentStatus.overdue => AppColors.danger,
      InstallmentStatus.waived => AppColors.muted,
      _ => AppColors.bg,
    };
    final border = switch (installment.status) {
      InstallmentStatus.pending => AppColors.border,
      _ => Colors.transparent,
    };
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
    );
  }

  Widget _statusChip() {
    final (label, bg, fg) = switch (installment.status) {
      InstallmentStatus.paid => ('Paid', AppColors.brandLight, AppColors.brand),
      InstallmentStatus.partial =>
      ('Partial', AppColors.goldLight, AppColors.warn),
      InstallmentStatus.overdue =>
      ('Overdue', AppColors.dangerLight, AppColors.danger),
      InstallmentStatus.waived =>
      ('Waived', AppColors.bg2, AppColors.muted),
      _ => ('Pending', AppColors.bg2, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ContractDetail detail;
  const _SummaryCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final c = detail.contract;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contract details',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _kv('Client', detail.clientName),
            _kv('Phone', detail.clientPhone),
            _kv('Property', detail.propertyTitle),
            if (c.unitLabel != null) _kv('Unit', c.unitLabel!),
            _kv('Location',
                '${detail.propertyLocation}, ${detail.propertyState}'),
            const Divider(height: 20),
            _kv('Total price', Formatters.naira(c.totalPrice)),
            _kv('Initial deposit', Formatters.naira(c.initialDeposit)),
            _kv('Plan', _planLabel(c.paymentPlan, c.planMonths)),
            _kv('Start date', Formatters.date(c.startDate)),
            if (detail.agentName != null)
              _kv('Agent', detail.agentName!),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.text)),
          ),
        ],
      ),
    );
  }

  String _planLabel(PaymentPlan p, int? months) {
    final base = switch (p) {
      PaymentPlan.outright => 'Outright',
      PaymentPlan.monthly => 'Monthly',
      PaymentPlan.quarterly => 'Quarterly',
      PaymentPlan.biannual => 'Biannual',
      PaymentPlan.annual => 'Annual',
      PaymentPlan.custom => 'Custom',
    };
    if (months == null || p == PaymentPlan.outright) return base;
    return '$base · $months installment${months == 1 ? '' : 's'}';
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final List<PaymentRecord> payments;
  const _PaymentHistoryCard({required this.payments});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment history',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No payments recorded yet',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.muted)),
              )
            else
              for (final p in payments) _paymentRow(p),
          ],
        ),
      ),
    );
  }

  Widget _paymentRow(PaymentRecord p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Formatters.naira(p.amount),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                  '${paymentChannelLabel(p.channel)} · ${Formatters.relative(p.paidAt)}'
                      '${p.reference != null ? " · Ref ${p.reference}" : ""}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (p.receiptUrl != null)
            const Icon(Icons.attach_file,
                size: 14, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ContractStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ContractStatus.draft => ('Draft', AppColors.bg2, AppColors.muted),
      ContractStatus.pendingSignature =>
      ('Pending signature', AppColors.warnLight, AppColors.warn),
      ContractStatus.active =>
      ('Active', AppColors.brandLight, AppColors.brand),
      ContractStatus.completed =>
      ('Completed', AppColors.brandLight, AppColors.brand),
      ContractStatus.cancelled =>
      ('Cancelled', AppColors.bg2, AppColors.muted),
      ContractStatus.defaulted =>
      ('Defaulted', AppColors.dangerLight, AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}