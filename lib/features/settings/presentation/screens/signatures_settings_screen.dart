// lib/features/settings/presentation/screens/signatures_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
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
                      'Signatures used on sale agreements and other documents.',
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
            Row(
              children: [
                if (!signature.isDefault)
                  TextButton.icon(
                    icon: const Icon(Icons.star_outline, size: 13),
                    label: const Text('Set default',
                        style: TextStyle(fontSize: 11)),
                    onPressed: () async {
                      await ref
                          .read(signaturesRepoProvider)
                          .setDefault(agencyId, signature.id);
                      ref.invalidate(
                          agencySignaturesProvider(agencyId));
                    },
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 14, color: AppColors.danger),
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