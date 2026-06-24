// lib/features/auth/presentation/widgets/policy_acceptance_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/theme/app_theme.dart';
import '../../../legal/legal_docs.dart';
import '../../../legal/markdown_view.dart';

/// Policies a new user must read and accept before creating an account.
/// Add a slug here (and drop its asset in assets/legal/) to require more.
const List<String> _requiredPolicySlugs = ['terms', 'privacy'];

/// Shows a modal that displays the Terms of Service and Privacy Policy
/// (and any other required policies) in full, with an Accept action.
/// Returns true only if the user pressed "I Accept".
Future<bool> showPolicyAcceptanceDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PolicyAcceptanceDialog(),
  );
  return result ?? false;
}

class _PolicyAcceptanceDialog extends StatefulWidget {
  const _PolicyAcceptanceDialog();

  @override
  State<_PolicyAcceptanceDialog> createState() =>
      _PolicyAcceptanceDialogState();
}

class _PolicyAcceptanceDialogState extends State<_PolicyAcceptanceDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final List<LegalDoc> _docs = [
    for (final s in _requiredPolicySlugs)
      if (legalDocBySlug(s) != null) legalDocBySlug(s)!,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _docs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.gavel, color: AppColors.brand, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Before you continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Please review and accept the following to create your account.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppColors.brand,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.brand,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [for (final d in _docs) Tab(text: d.title)],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [for (final d in _docs) _PolicyBody(doc: d)],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('I Accept'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyBody extends StatelessWidget {
  final LegalDoc doc;
  const _PolicyBody({required this.doc});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(doc.asset),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Could not load this policy.'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            Text(
              'Version ${doc.version} · Effective ${doc.effectiveDate}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            ...markdownToWidgets(snap.data!),
          ],
        );
      },
    );
  }
}
