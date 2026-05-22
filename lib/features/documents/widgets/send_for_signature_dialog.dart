// lib/features/documents/widgets/send_for_signature_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/contracts_repository.dart';
import '../../../data/repositories/documents_repository.dart';
import '../../../data/repositories/signatures_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../contracts/providers/contracts_providers.dart';
import '../services/sale_agreement_pdf.dart';

class SendForSignatureDialog extends ConsumerStatefulWidget {
  final ContractDetail contractDetail;

  const SendForSignatureDialog({super.key, required this.contractDetail});

  @override
  ConsumerState<SendForSignatureDialog> createState() =>
      _SendForSignatureDialogState();
}

class _SendForSignatureDialogState
    extends ConsumerState<SendForSignatureDialog> {
  AgencySignature? _selectedSignature;

  final _vendorName = TextEditingController();
  final _vendorEmail = TextEditingController();

  final _buyerWitnessName = TextEditingController();
  final _buyerWitnessEmail = TextEditingController();
  bool _buyerWitnessByClient = true;

  bool _submitting = false;
  String? _error;
  SendForSignatureResult? _result;

  @override
  void dispose() {
    _vendorName.dispose();
    _vendorEmail.dispose();
    _buyerWitnessName.dispose();
    _buyerWitnessEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedSignature == null) {
      setState(() => _error = 'Please select an agency signature');
      return;
    }
    if (_vendorName.text.trim().isEmpty ||
        !_vendorEmail.text.contains('@')) {
      setState(() => _error =
      "Vendor's witness needs a full name and a valid email");
      return;
    }
    if (!_buyerWitnessByClient &&
        (_buyerWitnessName.text.trim().isEmpty ||
            !_buyerWitnessEmail.text.contains('@'))) {
      setState(() => _error =
      "Buyer's witness needs a full name and a valid email, "
          "or check the box to let the client add them.");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile?.agencyId == null) {
        throw Exception('No agency on your profile');
      }

      // 1. Download the agency signature image bytes
      final sigBytes = await ref
          .read(signaturesRepoProvider)
          .downloadImage(_selectedSignature!.signatureImagePath);

      // 2. Build the PDF
      final detail = widget.contractDetail;
      final c = detail.contract;

      final pdfBytes = await SaleAgreementPdf.build(SaleAgreementInput(
        agencyName: detail.agencyName ?? 'Agency',
        agencyRcNumber: detail.agencyRcNumber,
        agencyAddress: detail.agencyAddress ?? '',
        agencySignatureImage: sigBytes,
        agencySignerName: _selectedSignature!.signerName,
        agencySignerTitle: _selectedSignature!.signerTitle,
        clientFullName: detail.clientName,
        clientAddress: detail.clientAddress,
        clientPhone: detail.clientPhone,
        clientEmail: detail.clientEmail,
        propertyTitle: detail.propertyTitle,
        propertyLocation: detail.propertyLocation,
        propertyState: detail.propertyState,
        propertyLga: detail.propertyLga ?? '',
        propertySizeSqm: detail.propertySizeSqm,
        unitLabel: c.unitLabel,
        contractNo: c.contractNo,
        totalPriceNgn: c.totalPrice,
        initialDeposit: c.initialDeposit,
        paymentPlanLabel: _planLabel(c.paymentPlan),
        planMonths: c.planMonths,
        startDate: c.startDate,
        agreementDate: DateTime.now(),
        vendorWitnessName: _vendorName.text.trim(),
        buyerWitnessName: _buyerWitnessByClient
            ? null
            : _buyerWitnessName.text.trim(),
      ));

      // 3. Upload to storage
      final pdfPath = await ref
          .read(documentsRepoProvider)
          .uploadUnsignedPdf(
          agencyId: profile!.agencyId!, pdfBytes: pdfBytes);

      // 4. Create the signature request
      final result =
      await ref.read(documentsRepoProvider).createSignatureRequest(
        contractId: c.id,
        agencySignatureId: _selectedSignature!.id,
        unsignedPdfPath: pdfPath,
        vendorWitnessName: _vendorName.text.trim(),
        vendorWitnessEmail: _vendorEmail.text.trim(),
        buyerWitnessName: _buyerWitnessByClient
            ? null
            : _buyerWitnessName.text.trim(),
        buyerWitnessEmail: _buyerWitnessByClient
            ? null
            : _buyerWitnessEmail.text.trim(),
      );

      // Refresh contract detail provider
      ref.invalidate(contractDetailProvider(c.id));
      ref.invalidate(contractSignatureProgressProvider(c.id));

      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _successView();

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final agencyId = profile?.agencyId;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send for signature',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 2),
                          Text(
                              'Generates the sale agreement and emails it to the client.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (agencyId != null) _signaturePicker(agencyId),
                const SizedBox(height: 16),

                _sectionLabel("Vendor's witness *",
                    helper: 'Someone from your side (a colleague, partner)'),
                _twoField(
                    leftLabel: 'Full name',
                    rightLabel: 'Email',
                    leftController: _vendorName,
                    rightController: _vendorEmail),
                const SizedBox(height: 14),

                _sectionLabel("Buyer's witness"),
                Row(
                  children: [
                    Checkbox(
                      value: _buyerWitnessByClient,
                      onChanged: (v) => setState(
                              () => _buyerWitnessByClient = v ?? true),
                    ),
                    const Expanded(
                      child: Text(
                          "Let the client add their own witness when they sign",
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                if (!_buyerWitnessByClient) ...[
                  const SizedBox(height: 4),
                  _twoField(
                      leftLabel: 'Full name',
                      rightLabel: 'Email',
                      leftController: _buyerWitnessName,
                      rightController: _buyerWitnessEmail),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger)),
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 14),
                      label: Text(_submitting
                          ? 'Preparing…'
                          : 'Generate & send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _signaturePicker(String agencyId) {
    final async = ref.watch(agencySignaturesProvider(agencyId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Sign this contract as *'),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Failed: $e',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.danger)),
          data: (sigs) {
            if (sigs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warnLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'No saved signatures yet. Go to Settings → Signatures to add one.',
                  style: TextStyle(fontSize: 12, color: AppColors.warn),
                ),
              );
            }
            _selectedSignature ??=
                sigs.firstWhere((s) => s.isDefault, orElse: () => sigs.first);
            return DropdownButtonFormField<String>(
              isDense: true,
              value: _selectedSignature?.id,
              decoration: const InputDecoration(isDense: true),
              items: [
                for (final s in sigs)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.label} — ${s.signerName}${s.isDefault ? ' (default)' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
              onChanged: (id) {
                final sig = sigs.firstWhere((s) => s.id == id);
                setState(() => _selectedSignature = sig);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, {String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
          if (helper != null)
            Text(helper,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _twoField({
    required String leftLabel,
    required String rightLabel,
    required TextEditingController leftController,
    required TextEditingController rightController,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: leftController,
            decoration: InputDecoration(
                hintText: leftLabel, isDense: true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: rightController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
                hintText: rightLabel, isDense: true),
          ),
        ),
      ],
    );
  }

  Widget _successView() {
    final origin = Uri.base.origin;
    final signLink = '$origin/#/sign/${_result!.clientSigningToken}';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.check_circle,
                    size: 40, color: AppColors.brand),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Sent for signature',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'The contract has been prepared and the client will receive it at ${_result!.clientEmail}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Signing link (for testing in dev):',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    SelectableText(signLink,
                        style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.brand)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _planLabel(PaymentPlan p) => switch (p) {
    PaymentPlan.outright => 'Outright',
    PaymentPlan.monthly => 'Monthly',
    PaymentPlan.quarterly => 'Quarterly',
    PaymentPlan.biannual => 'Biannual',
    PaymentPlan.annual => 'Annual',
    PaymentPlan.custom => 'Custom',
  };
}