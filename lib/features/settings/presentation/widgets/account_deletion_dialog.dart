// lib/features/settings/presentation/widgets/account_deletion_dialog.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/supabase_service.dart';

/// Dialog for requesting account deletion. Records the request in
/// account_deletion_requests; the Lintel team processes it per the Account
/// Deletion Policy. Uses a controller-free field to avoid disposal races.
class AccountDeletionDialog extends StatefulWidget {
  final String? agencyId;
  final String? email;

  const AccountDeletionDialog({super.key, this.agencyId, this.email});

  @override
  State<AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<AccountDeletionDialog> {
  String _reason = '';
  bool _submitting = false;
  bool _done = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid == null) {
        throw Exception('You are not signed in.');
      }
      final inserted = await SupabaseService.client
          .from('account_deletion_requests')
          .insert({
            'agency_id': widget.agencyId,
            'requested_by': uid,
            'requester_email': widget.email,
            'reason': _reason.trim().isEmpty ? null : _reason.trim(),
          })
          .select('id')
          .single();

      // Best-effort: alert the Lintel team. The request is already safely
      // recorded above, so a notification failure must never block the user.
      try {
        await SupabaseService.client.functions.invoke(
          'account-deletion-notify',
          body: {'requestId': inserted['id']},
        );
      } catch (_) {}

      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not submit your request. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return AlertDialog(
        title: const Text('Request received'),
        content: const Text(
          'Your account deletion request has been recorded. Our team will '
          'process it in line with our Account Deletion Policy and contact you '
          'at your registered email. You can continue using Lintel until the '
          'request is completed.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Delete account'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This requests deletion of your Lintel account. Our team will '
              'review and process it under our Account Deletion Policy, which '
              'sets out what is removed and the retention periods that apply. '
              'Some records may be kept where the law requires.',
              style: TextStyle(height: 1.5, color: AppColors.text),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/legal/account-deletion');
                },
                child: const Text('Read the Account Deletion Policy'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _reason,
              minLines: 2,
              maxLines: 4,
              onChanged: (v) => _reason = v,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Anything you would like us to know',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Request deletion'),
        ),
      ],
    );
  }
}
