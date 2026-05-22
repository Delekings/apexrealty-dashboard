// lib/features/contracts/presentation/widgets/signature_progress_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/repositories/documents_repository.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../data/services/supabase_service.dart';

class SignatureProgressCard extends ConsumerStatefulWidget {
  final SignatureProgress progress;
  final String contractId;
  const SignatureProgressCard({
    super.key,
    required this.progress,
    required this.contractId,
  });

  @override
  ConsumerState<SignatureProgressCard> createState() =>
      _SignatureProgressCardState();
}

class _SignatureProgressCardState
    extends ConsumerState<SignatureProgressCard> {
  bool _busyFinalize = false;
  String? _error;

  Future<void> _downloadOrFinalize() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile?.agencyId == null) return;

    setState(() {
      _busyFinalize = true;
      _error = null;
    });

    try {
      final doc = await SupabaseService.client
          .from('documents')
          .select('id, signed_pdf_path, status')
          .eq('contract_id', widget.contractId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      String? path = doc['signed_pdf_path'] as String?;
      final docId = doc['id'] as String;

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

      final url = await ref
          .read(documentsRepoProvider)
          .signedPdfUrl(path);
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _error =
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyFinalize = false);
    }
  }

  void _copyLink(SignerInfo s) {
    if (s.signingToken == null) return;
    final url = '${Uri.base.origin}/#/sign/${s.signingToken}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Signing link for ${s.roleLabel} copied'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final signed = p.signers.where((s) => s.isSigned).length;
    final total = p.signers.length + 1; // +1 for agency
    final agencyDone = p.agencySignedAt != null;
    final agencySigned = agencyDone ? 1 : 0;
    final totalSigned = signed + agencySigned;

    final isDone =
        p.docStatus == 'fully_signed' || p.docStatus == 'completed';

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
          // Header
          Row(
            children: [
              const Icon(Icons.draw_outlined,
                  size: 16, color: AppColors.brand),
              const SizedBox(width: 8),
              const Text('Signature progress',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.brandLight
                      : AppColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isDone
                      ? 'All signed'
                      : '$totalSigned / $total signed',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color:
                      isDone ? AppColors.brand : AppColors.warn),
                ),
              ),
              const Spacer(),
              if (isDone)
                FilledButton.icon(
                  onPressed:
                  _busyFinalize ? null : _downloadOrFinalize,
                  icon: _busyFinalize
                      ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download, size: 14),
                  label: Text(_busyFinalize
                      ? 'Generating…'
                      : p.docStatus == 'completed'
                      ? 'Download signed PDF'
                      : 'Finalize & download'),
                ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.danger)),
            ),
          ],

          const SizedBox(height: 16),

          // Agency row first
          _SignerRow(
            order: 1,
            roleLabel: 'Vendor (Agency)',
            name: p.agencySignerName ?? 'Agency',
            email: null,
            status: agencyDone ? 'signed' : 'pending',
            signedAt: p.agencySignedAt,
            signatureMethod: 'Saved signature',
            isLast: false,
            onCopyLink: null,
            missingDetails: false,
          ),

          // Then each signer
          for (var i = 0; i < p.signers.length; i++)
            _SignerRow(
              order: i + 2,
              roleLabel: p.signers[i].roleLabel,
              name: p.signers[i].fullName,
              email: p.signers[i].email,
              status: p.signers[i].status,
              signedAt: p.signers[i].signedAt,
              signatureMethod: p.signers[i].signatureMethod,
              isLast: i == p.signers.length - 1,
              onCopyLink: (p.signers[i].isCurrentlyWaiting &&
                  p.signers[i].signingToken != null)
                  ? () => _copyLink(p.signers[i])
                  : null,
              missingDetails: p.signers[i].isMissingDetails,
            ),

          if (p.expiresAt != null && !isDone) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 12, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  'Expires ${Formatters.date(p.expiresAt!)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SignerRow extends StatelessWidget {
  final int order;
  final String roleLabel;
  final String? name;
  final String? email;
  final String status;
  final DateTime? signedAt;
  final String? signatureMethod;
  final bool isLast;
  final VoidCallback? onCopyLink;
  final bool missingDetails;

  const _SignerRow({
    required this.order,
    required this.roleLabel,
    required this.name,
    required this.email,
    required this.status,
    required this.signedAt,
    required this.signatureMethod,
    required this.isLast,
    required this.onCopyLink,
    required this.missingDetails,
  });

  @override
  Widget build(BuildContext context) {
    final isSigned = status == 'signed';
    final isCurrent = status == 'awaiting_signer' || status == 'otp_verified';

    final (Color circleColor, IconData? icon) = switch (status) {
      'signed' => (AppColors.brand, Icons.check),
      'awaiting_signer' || 'otp_verified' => (AppColors.warn, null),
      _ => (AppColors.bg2, null),
    };

    final statusLabel = switch (status) {
      'signed' => signedAt != null
          ? 'Signed ${Formatters.date(signedAt!)}'
          : 'Signed',
      'awaiting_signer' => 'Awaiting signature',
      'otp_verified' => 'Verified, awaiting signature',
      _ => 'Waiting in queue',
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number circle + connector line
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent ? AppColors.warn : circleColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: Colors.white, size: 14)
                      : Text(
                    '$order',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSigned || isCurrent
                          ? Colors.white
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isSigned
                        ? AppColors.brand
                        : AppColors.border,
                    margin:
                    const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name?.isNotEmpty == true
                            ? name!
                            : 'Not yet provided',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: name?.isNotEmpty == true
                              ? AppColors.text
                              : AppColors.muted,
                          fontStyle: name?.isNotEmpty == true
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          roleLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (email != null && email!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(email!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted)),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isSigned
                            ? Icons.check_circle
                            : isCurrent
                            ? Icons.hourglass_top
                            : Icons.access_time,
                        size: 11,
                        color: isSigned
                            ? AppColors.brand
                            : isCurrent
                            ? AppColors.warn
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSigned
                              ? AppColors.brand
                              : isCurrent
                              ? AppColors.warn
                              : AppColors.muted,
                        ),
                      ),
                      if (isSigned &&
                          signatureMethod != null) ...[
                        const Text(' · ',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted)),
                        Text(
                          signatureMethod!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                  if (missingDetails && !isSigned) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.goldLight,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'No name/email — link cannot be delivered',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.warn),
                      ),
                    ),
                  ],
                  if (onCopyLink != null) ...[
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: onCopyLink,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 28),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      icon: const Icon(Icons.link, size: 12),
                      label: const Text('Copy signing link'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}