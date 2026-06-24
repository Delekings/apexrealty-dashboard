// lib/features/email/presentation/screens/unsubscribe_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/supabase_service.dart';

/// Public page reached from the unsubscribe link in campaign email footers.
/// Reads the signed token from the query string, calls the email-unsubscribe
/// edge function, and shows a branded confirmation. No login required.
class UnsubscribeScreen extends StatefulWidget {
  final String? a;
  final String? e;
  final String? s;

  const UnsubscribeScreen({super.key, this.a, this.e, this.s});

  @override
  State<UnsubscribeScreen> createState() => _UnsubscribeScreenState();
}

class _UnsubscribeScreenState extends State<UnsubscribeScreen> {
  bool _loading = true;
  bool _success = false;
  String? _email;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (widget.a == null || widget.e == null || widget.s == null) {
      setState(() {
        _loading = false;
        _error = 'This unsubscribe link is incomplete.';
      });
      return;
    }
    try {
      final res = await SupabaseService.client.functions.invoke(
        'email-unsubscribe',
        body: {'a': widget.a, 'e': widget.e, 's': widget.s},
      );
      final data = res.data;
      if (res.status == 200 && data is Map && data['ok'] == true) {
        setState(() {
          _loading = false;
          _success = true;
          _email = data['email']?.toString();
        });
      } else {
        final msg = (data is Map ? data['error']?.toString() : null) ??
            'We could not process this request.';
        setState(() {
          _loading = false;
          _error = msg;
        });
      }
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again later.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _content(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (_loading) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(),
          ),
        ),
        SizedBox(height: 8),
        Center(child: Text('Processing your request…')),
      ];
    }
    if (_success) {
      return [
        const Icon(Icons.check_circle, color: AppColors.brand, size: 44),
        const SizedBox(height: 14),
        const Text(
          'You have been unsubscribed',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _email == null
              ? 'You will no longer receive marketing emails from this sender.'
              : '$_email will no longer receive marketing emails from this sender.',
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Important account and transaction messages may still be sent where required.',
          style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.5),
        ),
      ];
    }
    return [
      const Icon(Icons.error_outline, color: AppColors.danger, size: 44),
      const SizedBox(height: 14),
      const Text(
        'Unable to unsubscribe',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        _error ?? 'We could not process this request.',
        style: const TextStyle(color: AppColors.muted, height: 1.5),
      ),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Go to Lintel'),
        ),
      ),
    ];
  }
}
