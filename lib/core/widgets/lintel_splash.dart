// lib/core/widgets/lintel_splash_v2.dart
//
// Animated splash screen for the Lintel app.
// Plays lintel_splash.json once, then calls [onComplete] (e.g. to navigate home).

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LintelSplashScreen extends StatefulWidget {
  const LintelSplashScreen({
    super.key,
    this.onComplete,
    this.minDisplay = Duration.zero,
  });

  /// Called once the animation finishes (and [minDisplay] has elapsed).
  final VoidCallback? onComplete;

  /// Optional floor on how long the splash stays up, useful if you need a
  /// moment to warm up the app while the ~3s animation plays.
  final Duration minDisplay;

  @override
  State<LintelSplashScreen> createState() => _LintelSplashScreenState();
}

class _LintelSplashScreenState extends State<LintelSplashScreen>
    with SingleTickerProviderStateMixin {
  // Brand palette — must match the JSON so there is no color flash.
  static const Color _green = Color(0xFF0F4F37); // background

  late final AnimationController _controller;
  late final DateTime _start;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    // Real duration is applied in onLoaded, once the composition is known.
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_onStatus);
  }

  Future<void> _onStatus(AnimationStatus status) async {
    if (status != AnimationStatus.completed) return;
    final remaining = widget.minDisplay - DateTime.now().difference(_start);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (mounted) widget.onComplete?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cap the logo to a sensible size and keep it centered on every screen.
    // Use the shorter screen dimension so it stays balanced on tall phones
    // and wide tablets alike, then clamp so it never gets too big or too small.
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = (shortestSide * 0.5).clamp(160.0, 320.0);

    return Scaffold(
      backgroundColor: _green,
      body: Center(
        child: SizedBox(
          width: logoSize,
          height: logoSize,
          child: Lottie.asset(
            'assets/lottie/lintel_splash.json',
            controller: _controller,
            fit: BoxFit.contain, // was BoxFit.cover — that cropped & oversized it
            onLoaded: (composition) {
              _controller
                ..duration = composition.duration
                ..forward(from: 0);
            },
          ),
        ),
      ),
    );
  }
}