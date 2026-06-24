// lib/core/widgets/cookie_consent_banner.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

const _consentKey = 'lintel_cookie_consent_v1';

/// A lightweight bottom consent banner shown until the user accepts. Persists
/// the choice locally via shared_preferences so it does not reappear. Rendered
/// once at the app root so it covers both public and signed-in screens.
class CookieConsentBanner extends StatefulWidget {
  const CookieConsentBanner({super.key});

  @override
  State<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends State<CookieConsentBanner> {
  // null = still loading, true = accepted (hide), false = show banner
  bool? _accepted;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool(_consentKey) ?? false;
      if (mounted) setState(() => _accepted = v);
    } catch (_) {
      if (mounted) setState(() => _accepted = true); // fail closed: don't nag
    }
  }

  Future<void> _accept() async {
    if (mounted) setState(() => _accepted = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_consentKey, true);
    } catch (_) {
      // best-effort; UI already hidden for this session
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted != false) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.text,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const SizedBox(
                    width: 460,
                    child: Text(
                      'Lintel uses essential cookies to keep you signed in and '
                      'to run the app. By continuing, you agree to this. See our '
                      'Privacy Policy under Legal & policies for details.',
                      style: TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.5),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _accept,
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
