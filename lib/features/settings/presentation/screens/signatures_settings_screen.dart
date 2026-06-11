// lib/features/settings/presentation/screens/signatures_settings_screen.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../data/repositories/agency_branding_repository.dart';
import '../../../../data/repositories/signatures_repository.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../documents/widgets/signature_pad.dart';

class SignaturesSettingsScreen extends ConsumerWidget {
  const SignaturesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final agencyId = profile?.agencyId;

    if (agencyId == null) {
      return const Center(
        child: Text('Loading…',
            style: TextStyle(color: AppColors.muted)),
      );
    }

    final async = ref.watch(agencySignaturesProvider(agencyId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Branding section =====
          _BrandingSection(agencyId: agencyId),
          const SizedBox(height: 24),
          // ===== Signatures section header =====
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Signatures',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                      'Signatures used on sale agreements and receipts.',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) =>
                      _AddSignatureDialog(agencyId: agencyId),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add signature'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.brand)),
              error: (e, _) => Center(
                child: Text('Failed: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (sigs) {
                if (sigs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.draw_outlined,
                    title: 'No signatures yet',
                    message:
                    'Add one to start sending contracts for signature.',
                  );
                }
                return GridView.builder(
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 360,
                    childAspectRatio: 1.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: sigs.length,
                  itemBuilder: (_, i) => _SignatureCard(
                    signature: sigs[i],
                    agencyId: agencyId,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureCard extends ConsumerWidget {
  final AgencySignature signature;
  final String agencyId;
  const _SignatureCard(
      {required this.signature, required this.agencyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(signature.label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                if (signature.isDefault)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Default',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.brand,
                            fontWeight: FontWeight.w500)),
                  ),
                if (signature.isReceiptSigner)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Receipts',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${signature.signerName}${signature.signerTitle != null ? ' · ${signature.signerTitle}' : ''}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _SignaturePreview(
                  path: signature.signatureImagePath),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!signature.isDefault)
                  TextButton.icon(
                    icon: const Icon(Icons.star_outline, size: 13),
                    label: const Text('Set default',
                        style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      await ref
                          .read(signaturesRepoProvider)
                          .setDefault(agencyId, signature.id);
                      ref.invalidate(
                          agencySignaturesProvider(agencyId));
                    },
                  ),
                if (!signature.isReceiptSigner)
                  TextButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined, size: 13),
                    label: const Text('Use on receipts',
                        style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      await ref
                          .read(signaturesRepoProvider)
                          .setReceiptSigner(agencyId, signature.id);
                      ref.invalidate(
                          agencySignaturesProvider(agencyId));
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 14, color: AppColors.danger),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete signature?'),
                        content: Text(
                            'Delete "${signature.label}"? '
                                'Documents already signed with it will not be affected.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.danger),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(signaturesRepoProvider)
                          .delete(signature.id);
                      ref.invalidate(
                          agencySignaturesProvider(agencyId));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePreview extends ConsumerWidget {
  final String path;
  const _SignaturePreview({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(signaturesRepoProvider).downloadImage(path),
      builder: (_, snap) {
        if (!snap.hasData) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(6),
          child: Image.memory(snap.data!, fit: BoxFit.contain),
        );
      },
    );
  }
}

class _AddSignatureDialog extends ConsumerStatefulWidget {
  final String agencyId;
  const _AddSignatureDialog({required this.agencyId});

  @override
  ConsumerState<_AddSignatureDialog> createState() =>
      _AddSignatureDialogState();
}

class _AddSignatureDialogState
    extends ConsumerState<_AddSignatureDialog> {
  final _label = TextEditingController();
  final _signerName = TextEditingController();
  final _signerTitle = TextEditingController();
  bool _isDefault = false;
  bool _isReceiptSigner = false;
  SignaturePadResult? _captured;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _signerName.dispose();
    _signerTitle.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_captured == null) {
      setState(() => _error = 'Please draw or upload a signature first');
      return;
    }
    if (_label.text.trim().isEmpty || _signerName.text.trim().isEmpty) {
      setState(() => _error = 'Label and signer name are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(signaturesRepoProvider).create(
        agencyId: widget.agencyId,
        label: _label.text.trim(),
        signerName: _signerName.text.trim(),
        signerTitle: _signerTitle.text.trim().isEmpty
            ? null
            : _signerTitle.text.trim(),
        imageBytes: _captured!.pngBytes,
        method: _captured!.method,
        isDefault: _isDefault,
        isReceiptSigner: _isReceiptSigner,
      );
      ref.invalidate(agencySignaturesProvider(widget.agencyId));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      child: Text('Add signature',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _label2('Label *'),
                TextField(
                  controller: _label,
                  decoration: const InputDecoration(
                    hintText: 'e.g. "MD — Adaeze Okoro"',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label2('Signer name *'),
                          TextField(
                            controller: _signerName,
                            decoration: const InputDecoration(
                              hintText: 'Adaeze Okoro',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label2('Title'),
                          TextField(
                            controller: _signerTitle,
                            decoration: const InputDecoration(
                              hintText: 'Managing Director',
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _label2('Signature *'),
                SignaturePad(
                  onSaved: (r) => setState(() => _captured = r),
                ),
                const SizedBox(height: 8),
                if (_captured != null)
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.brand),
                      const SizedBox(width: 6),
                      Text('Signature captured (${_captured!.method})',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.brand)),
                    ],
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _isDefault,
                      onChanged: (v) =>
                          setState(() => _isDefault = v ?? false),
                    ),
                    const Text('Use as default signature',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _isReceiptSigner,
                      onChanged: (v) =>
                          setState(() => _isReceiptSigner = v ?? false),
                    ),
                    const Text('Use on payment receipts',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
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
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                          : const Text('Save'),
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

  Widget _label2(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500)),
  );
}

// ============================================================================
// Branding section — common seal + style picker for vendor/receipt blocks
// ============================================================================

class _BrandingSection extends ConsumerWidget {
  final String agencyId;
  const _BrandingSection({required this.agencyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(agencyBrandingProvider(agencyId));
    return async.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      ),
      error: (e, _) => Text('Failed to load branding: $e',
          style: const TextStyle(color: AppColors.danger)),
      data: (branding) => _BrandingEditor(agencyId: agencyId, branding: branding),
    );
  }
}

class _BrandingEditor extends ConsumerStatefulWidget {
  final String agencyId;
  final AgencyBranding branding;
  const _BrandingEditor({required this.agencyId, required this.branding});

  @override
  ConsumerState<_BrandingEditor> createState() => _BrandingEditorState();
}

class _BrandingEditorState extends ConsumerState<_BrandingEditor> {
  late VendorBlockStyle _vendorStyle;
  late ReceiptBlockStyle _receiptStyle;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vendorStyle = widget.branding.vendorBlockStyle;
    _receiptStyle = widget.branding.receiptBlockStyle;
  }

  bool get _stylesNeedSeal =>
      _vendorStyle == VendorBlockStyle.sealOnly ||
          _vendorStyle == VendorBlockStyle.directorsAndSeal ||
          _receiptStyle == ReceiptBlockStyle.sealOnly ||
          _receiptStyle == ReceiptBlockStyle.directorAndSeal;

  Future<void> _saveStyles() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(agencyBrandingRepoProvider).updateStyles(
        agencyId: widget.agencyId,
        vendorStyle: _vendorStyle,
        receiptStyle: _receiptStyle,
      );
      ref.invalidate(agencyBrandingProvider(widget.agencyId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Company branding',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text(
            'How your signature blocks appear on contracts and receipts.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _VendorStylePicker(
                  value: _vendorStyle,
                  onChanged: (v) => setState(() => _vendorStyle = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ReceiptStylePicker(
                  value: _receiptStyle,
                  onChanged: (v) => setState(() => _receiptStyle = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_stylesNeedSeal) ...[
            const Divider(height: 24),
            _SealUploader(
              agencyId: widget.agencyId,
              sealUrl: widget.branding.commonSealUrl,
            ),
          ],
          const SizedBox(height: 12),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_error!,
                  style:
                  const TextStyle(fontSize: 12, color: AppColors.danger)),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _saveStyles,
              child: _saving
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Save branding'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorStylePicker extends StatelessWidget {
  final VendorBlockStyle value;
  final ValueChanged<VendorBlockStyle> onChanged;
  const _VendorStylePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contract vendor block',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        _radio('Directors only', VendorBlockStyle.directorsOnly),
        _radio('Common seal only', VendorBlockStyle.sealOnly),
        _radio('Directors + seal', VendorBlockStyle.directorsAndSeal),
      ],
    );
  }

  Widget _radio(String label, VendorBlockStyle v) {
    return InkWell(
      onTap: () => onChanged(v),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Radio<VendorBlockStyle>(
              value: v,
              groupValue: value,
              onChanged: (x) => onChanged(x!),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ReceiptStylePicker extends StatelessWidget {
  final ReceiptBlockStyle value;
  final ValueChanged<ReceiptBlockStyle> onChanged;
  const _ReceiptStylePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Receipt block',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        _radio('Director only', ReceiptBlockStyle.directorOnly),
        _radio('Common seal only', ReceiptBlockStyle.sealOnly),
        _radio('Director + seal', ReceiptBlockStyle.directorAndSeal),
      ],
    );
  }

  Widget _radio(String label, ReceiptBlockStyle v) {
    return InkWell(
      onTap: () => onChanged(v),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Radio<ReceiptBlockStyle>(
              value: v,
              groupValue: value,
              onChanged: (x) => onChanged(x!),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SealUploader extends ConsumerStatefulWidget {
  final String agencyId;
  final String? sealUrl;
  const _SealUploader({required this.agencyId, required this.sealUrl});

  @override
  ConsumerState<_SealUploader> createState() => _SealUploaderState();
}

class _SealUploaderState extends ConsumerState<_SealUploader> {
  bool _busy = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Use the existing FilePicker through SingleFilePicker pattern would be
      // more involved here since SingleFilePicker has a different shape.
      // For simplicity we use FilePicker directly.
      // ignore: import_of_legacy_library_into_null_safe
      final res = await _pickImage();
      if (res == null) {
        setState(() => _busy = false);
        return;
      }
      await ref.read(agencyBrandingRepoProvider).uploadSeal(
        agencyId: widget.agencyId,
        imageBytes: res,
      );
      ref.invalidate(agencyBrandingProvider(widget.agencyId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(agencyBrandingRepoProvider)
          .removeSeal(widget.agencyId);
      ref.invalidate(agencyBrandingProvider(widget.agencyId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: widget.sealUrl == null
              ? const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No seal uploaded',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: AppColors.muted)),
          )
              : _SealPreviewImage(path: widget.sealUrl!),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Common seal',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              const Text(
                'Upload a transparent PNG of your company seal. '
                    'It appears on contracts and/or receipts based on '
                    'the style settings above.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickAndUpload,
                    icon: const Icon(Icons.upload, size: 14),
                    label: Text(widget.sealUrl == null
                        ? 'Upload seal'
                        : 'Replace seal'),
                  ),
                  if (widget.sealUrl != null) ...[
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: _busy ? null : _remove,
                      icon: const Icon(Icons.delete_outline,
                          size: 14, color: AppColors.danger),
                      label: const Text('Remove',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SealPreviewImage extends ConsumerWidget {
  final String path;
  const _SealPreviewImage({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Uint8List?>(
      future: ref.read(agencyBrandingRepoProvider).downloadSeal(path),
      builder: (_, snap) {
        if (!snap.hasData || snap.data == null) {
          return const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.brand),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Image.memory(snap.data!, fit: BoxFit.contain),
        );
      },
    );
  }
}

// File picker for seal images. Returns the picked image bytes, or null
// if the user cancelled or no image was selected.
Future<Uint8List?> _pickImage() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    withData: true,
  );
  if (res == null || res.files.isEmpty) return null;
  return res.files.first.bytes;
}