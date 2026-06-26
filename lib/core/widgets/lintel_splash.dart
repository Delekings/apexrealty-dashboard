// lib/core/widgets/lintel_splash.dart
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
    return Scaffold(
      backgroundColor: _green,
      body: Center(
        child: Lottie.asset(
          'assets/lottie/lintel_splash.json',
          controller: _controller,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          onLoaded: (composition) {
            _controller
              ..duration = composition.duration
              ..forward(from: 0);
          },
        ),
      ),
    );
  }
}
