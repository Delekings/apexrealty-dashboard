// lib/features/signing/screens/signing_screen.dart
//
// The public signing page at /sign/:token. No authentication required.
// Flow: load context → OTP step → review document → sign step → done.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/signing_repository.dart';
import '../../documents/widgets/signature_pad.dart';
import '../widgets/typed_signature.dart';

enum SigningStep { otp, review, sign, done }

enum SignatureMethod { drawn, typed, uploaded }

class SigningScreen extends ConsumerStatefulWidget {
  final String token;
  const SigningScreen({super.key, required this.token});

  @override
  ConsumerState<SigningScreen> createState() => _SigningScreenState();
}

class _SigningScreenState extends ConsumerState<SigningScreen> {
  SigningStep _step = SigningStep.otp;

  // OTP state
  final _otpController = TextEditingController();
  OtpRequestResult? _lastOtpRequest;
  bool _requestingOtp = false;
  bool _verifyingOtp = false;
  String? _otpError;

  // Signature state
  Uint8List? _signatureBytes;
  SignatureMethod? _signatureMethod;
  final _occupation = TextEditingController();
  final _address = TextEditingController();
  // Only for client adding buyer witness on the fly
  final _buyerWitnessName = TextEditingController();
  final _buyerWitnessEmail = TextEditingController();

  bool _submitting = false;
  String? _submitError;
  SignResult? _doneResult;

  @override
  void dispose() {
    _otpController.dispose();
    _occupation.dispose();
    _address.dispose();
    _buyerWitnessName.dispose();
    _buyerWitnessEmail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(signingContextProvider(widget.token));

    return Scaffold(
      backgroundColor: AppColors.bg2,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => _errorState(e.toString()),
        data: (ctx) {
          if (ctx == null) return _expiredState();
          return _buildContent(ctx);
        },
      ),
    );
  }

  Widget _buildContent(SigningContext ctx) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _header(ctx),
              const SizedBox(height: 20),
              _progressBar(ctx),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: switch (_step) {
                    SigningStep.otp => _otpStep(ctx),
                    SigningStep.review => _reviewStep(ctx),
                    SigningStep.sign => _signStep(ctx),
                    SigningStep.done => _doneStep(ctx),
                  },
                ),
              ),
              const SizedBox(height: 24),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // ----- Header -----

  Widget _header(SigningContext ctx) {
    return Card(
      elevation: 0,
      color: AppColors.brand,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.home_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  ctx.agencyName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _summaryLine(ctx),
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              'You are signing as: ${ctx.roleLabel}'
                  '${ctx.signerFullName != null ? " (${ctx.signerFullName})" : ""}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _summaryLine(SigningContext ctx) {
    final price = ctx.contractTotalNgn != null
        ? Formatters.naira(ctx.contractTotalNgn!)
        : '';
    final property = ctx.propertyTitle != null
        ? ' "${ctx.propertyTitle}"'
        : '';
    final loc = ctx.propertyLocation != null
        ? ' in ${ctx.propertyLocation}, ${ctx.propertyState}'
        : '';

    return switch (ctx.signerRole) {
      'client' =>
      '${ctx.agencyName} is selling$property$loc to you for $price. '
          'Please review and sign the sale agreement.',
      'vendor_witness' =>
      '${ctx.agencyName} is selling$property$loc to '
          '${ctx.clientFullName ?? "the purchaser"} for $price. '
          "You're witnessing on the vendor's behalf.",
      'buyer_witness' =>
      '${ctx.agencyName} is selling$property$loc to '
          '${ctx.clientFullName ?? "the purchaser"} for $price. '
          "You're witnessing on the purchaser's behalf.",
      _ => 'Please review and sign the document.',
    };
  }

  Widget _progressBar(SigningContext ctx) {
    final steps = [
      ('Verify', SigningStep.otp),
      ('Review', SigningStep.review),
      ('Sign', SigningStep.sign),
      ('Done', SigningStep.done),
    ];
    final currentIdx = steps.indexWhere((s) => s.$2 == _step);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                  i <= currentIdx ? AppColors.brand : AppColors.bg2,
                  border: Border.all(
                    color: i <= currentIdx
                        ? AppColors.brand
                        : AppColors.border,
                  ),
                ),
                child: i < currentIdx
                    ? const Icon(Icons.check,
                    size: 12, color: Colors.white)
                    : Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                        fontSize: 10,
                        color: i <= currentIdx
                            ? Colors.white
                            : AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(steps[i].$1,
                  style: TextStyle(
                      fontSize: 10,
                      color: i <= currentIdx
                          ? AppColors.brand
                          : AppColors.muted)),
            ],
          ),
          if (i < steps.length - 1)
            Container(
              width: 40,
              height: 1,
              margin: const EdgeInsets.only(bottom: 16),
              color: i < currentIdx ? AppColors.brand : AppColors.border,
            ),
        ],
      ],
    );
  }

  // ----- OTP step -----

  Widget _otpStep(SigningContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verify your email',
            style:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          _lastOtpRequest == null
              ? 'For security, we need to confirm your email before you can sign.'
              : 'We sent a 6-digit code to ${_lastOtpRequest!.maskedEmail}. '
              'Enter it below to continue.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        if (_lastOtpRequest == null)
          FilledButton.icon(
            onPressed: _requestingOtp ? null : _requestOtp,
            icon: _requestingOtp
                ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.email_outlined, size: 14),
            label: Text(_requestingOtp ? 'Sending…' : 'Send code'),
          )
        else ...[
          // Dev banner (visible because OTPs are not really emailed yet)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.goldLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gold),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined,
                    size: 14, color: AppColors.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'Dev mode: code is ${_lastOtpRequest!.devCode}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.warn),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(
                fontSize: 22, letterSpacing: 8, fontFeatures: []),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '000000',
              counterText: '',
            ),
          ),
          if (_otpError != null) ...[
            const SizedBox(height: 6),
            Text(_otpError!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.danger)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: _requestingOtp ? null : _requestOtp,
                child: Text(_requestingOtp ? 'Sending…' : 'Resend code',
                    style: const TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: (_otpController.text.length == 6 &&
                    !_verifyingOtp)
                    ? _verifyOtp
                    : null,
                child: _verifyingOtp
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Text('Verify'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _requestOtp() async {
    setState(() {
      _requestingOtp = true;
      _otpError = null;
    });
    try {
      final res = await ref
          .read(signingRepoProvider)
          .requestOtp(widget.token);
      setState(() => _lastOtpRequest = res);
    } catch (e) {
      setState(() =>
      _otpError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _requestingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _verifyingOtp = true;
      _otpError = null;
    });
    try {
      final ok = await ref
          .read(signingRepoProvider)
          .verifyOtp(widget.token, _otpController.text);
      if (ok) {
        setState(() => _step = SigningStep.review);
      } else {
        setState(() =>
        _otpError = 'Incorrect code. Please try again.');
      }
    } catch (e) {
      setState(() =>
      _otpError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  // ----- Review step -----

  Widget _reviewStep(SigningContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review the document',
            style:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
          'Please review the sale agreement carefully before signing.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        if (ctx.currentPdfPath != null)
          FutureBuilder<String>(
            future: ref
                .read(signingRepoProvider)
                .getSignedPdfUrl(ctx.currentPdfPath!),
            builder: (_, snap) {
              if (!snap.hasData) {
                return Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brand),
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.picture_as_pdf,
                        size: 40, color: AppColors.danger),
                    const SizedBox(height: 8),
                    const Text('Sale Agreement',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Contract ${ctx.contractNo ?? ""}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(snap.data!),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Open document'),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => setState(() => _step = SigningStep.sign),
            child: const Text('Continue to sign'),
          ),
        ),
      ],
    );
  }

  // ----- Sign step -----

  Widget _signStep(SigningContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add your signature',
            style:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
          'Choose how you want to sign. By signing, you agree to the terms of this document.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 16),

        // Witness fields (occupation + address) — only for witnesses
        if (ctx.signerRole == 'vendor_witness' ||
            ctx.signerRole == 'buyer_witness') ...[
          const Text('Your details',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _occupation,
                  decoration: const InputDecoration(
                      hintText: 'Occupation', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _address,
                  decoration: const InputDecoration(
                      hintText: 'Address', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Buyer-witness mini-form for the client step
        if (ctx.signerRole == 'client') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Your witness (optional)",
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Provide a witness on your side. They will receive their own '
                      'email to sign after you and the vendor witness have signed. '
                      'Leave blank to skip.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buyerWitnessName,
                        decoration: const InputDecoration(
                            hintText: 'Full name', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _buyerWitnessEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            hintText: 'Email', isDense: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Text('Signature',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        _SignatureMethodPicker(
          onDrawn: (bytes) {
            setState(() {
              _signatureBytes = bytes;
              _signatureMethod = SignatureMethod.drawn;
            });
          },
          onTyped: (bytes, _) {
            setState(() {
              _signatureBytes = bytes;
              _signatureMethod = SignatureMethod.typed;
            });
          },
          onUploaded: (bytes) {
            setState(() {
              _signatureBytes = bytes;
              _signatureMethod = SignatureMethod.uploaded;
            });
          },
        ),

        if (_signatureBytes != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 14, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                'Signature ready (${_signatureMethod!.name})',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.brand),
              ),
            ],
          ),
        ],

        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_submitError!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.danger)),
          ),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _step = SigningStep.review),
              child: const Text('Back'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed:
              (_signatureBytes != null && !_submitting) ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 14),
              label: Text(_submitting ? 'Signing…' : 'Sign document'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_signatureBytes == null || _signatureMethod == null) return;

    final ctx = ref.read(signingContextProvider(widget.token)).valueOrNull;
    if (ctx == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final sigPath = await ref.read(signingRepoProvider).uploadSignature(
        documentId: ctx.documentId,
        signerRole: ctx.signerRole,
        bytes: _signatureBytes!,
      );

      final result = await ref.read(signingRepoProvider).recordSignature(
        token: widget.token,
        signaturePath: sigPath,
        signatureMethod: _signatureMethod!.name,
        occupation: _occupation.text.trim().isEmpty
            ? null
            : _occupation.text.trim(),
        address: _address.text.trim().isEmpty
            ? null
            : _address.text.trim(),
        buyerWitnessFullName:
        _buyerWitnessName.text.trim().isEmpty
            ? null
            : _buyerWitnessName.text.trim(),
        buyerWitnessEmail:
        _buyerWitnessEmail.text.trim().isEmpty
            ? null
            : _buyerWitnessEmail.text.trim(),
      );

      setState(() {
        _doneResult = result;
        _step = SigningStep.done;
      });
    } catch (e) {
      setState(() =>
      _submitError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ----- Done step -----

  Widget _doneStep(SigningContext ctx) {
    final r = _doneResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle,
            color: AppColors.brand, size: 48),
        const SizedBox(height: 8),
        const Text('Document signed',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          r.needsBuyerWitness
              ? "Thank you. ${ctx.agencyName} will add your witness's details, "
              "and you'll receive an update once the document is fully signed."
              : r.isLastSigner
              ? 'All parties have now signed. A copy will be sent to your email.'
              : 'Thank you. The next signer '
              '(${_nextRoleLabel(r.nextSignerRole)}) has been notified.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),

        // Dev helper: show the next signer's link
        if (!r.isLastSigner && r.nextSignerToken != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.goldLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gold),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Dev mode: next signer link (would be emailed in production):',
                    style: TextStyle(fontSize: 11, color: AppColors.warn)),
                const SizedBox(height: 4),
                SelectableText(
                  '${Uri.base.origin}/#/sign/${r.nextSignerToken}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.warn),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _nextRoleLabel(String? role) => switch (role) {
    'vendor_witness' => "Vendor's witness",
    'buyer_witness' => "Buyer's witness",
    _ => 'next party',
  };

  // ----- Error / expired states -----

  Widget _errorState(String e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.danger, size: 48),
          const SizedBox(height: 8),
          const Text('Something went wrong',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(e,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.muted)),
        ],
      ),
    ),
  );

  Widget _expiredState() => const Center(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock,
              color: AppColors.muted, size: 48),
          SizedBox(height: 8),
          Text('This link has expired or already been used',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            'Please contact the agency that sent this document to request a new link.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );

  Widget _footer() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Icon(Icons.home_rounded,
                color: Colors.white, size: 10),
          ),
          const SizedBox(width: 6),
          const Text(
            'Secured by Lintel',
            style: TextStyle(
                fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Lets the user pick: Draw / Type / Upload
class _SignatureMethodPicker extends StatefulWidget {
  final void Function(Uint8List bytes) onDrawn;
  final void Function(Uint8List bytes, String typedName) onTyped;
  final void Function(Uint8List bytes) onUploaded;

  const _SignatureMethodPicker({
    required this.onDrawn,
    required this.onTyped,
    required this.onUploaded,
  });

  @override
  State<_SignatureMethodPicker> createState() =>
      _SignatureMethodPickerState();
}

class _SignatureMethodPickerState
    extends State<_SignatureMethodPicker> {
  String _method = 'drawn';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _tab('drawn', 'Draw', Icons.gesture),
            const SizedBox(width: 6),
            _tab('typed', 'Type', Icons.keyboard_outlined),
            const SizedBox(width: 6),
            _tab('uploaded', 'Upload', Icons.upload),
          ],
        ),
        const SizedBox(height: 12),
        if (_method == 'drawn')
          SignaturePad(
            onSaved: (r) {
              if (r.method == 'drawn') {
                widget.onDrawn(r.pngBytes);
              } else {
                widget.onUploaded(r.pngBytes);
              }
            },
          )
        else if (_method == 'typed')
          TypedSignaturePad(
            onSaved: (bytes, name) => widget.onTyped(bytes, name),
          )
        else
          SignaturePad(
            // Force upload mode by using SignaturePad's upload tab
            onSaved: (r) {
              if (r.method == 'uploaded') {
                widget.onUploaded(r.pngBytes);
              } else {
                widget.onDrawn(r.pngBytes);
              }
            },
          ),
      ],
    );
  }

  Widget _tab(String value, String label, IconData icon) {
    final selected = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandLight : AppColors.bg,
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? AppColors.brand : AppColors.muted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? AppColors.brand
                          : AppColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}