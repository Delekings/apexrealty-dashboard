// lib/core/widgets/lintel_loader.dart
//
// A branded loading indicator for the Lintel app: the portal mark sits in the
// centre while an arc sweeps around it (with a gentle breathing pulse). Drawn
// entirely with CustomPainter — no image assets, crisp at any size.
//
// USAGE
//   // Inline / full-area (e.g. while a list or detail screen loads):
//   const LintelLoader(size: 48)
//
//   // White mark on the brand green (for dark surfaces):
//   const LintelLoader(size: 64, color: Color(0xFFF4F8F6))
//
//   // Full-screen placeholder INSTEAD of a blank screen while a page loads:
//   if (isLoading) const LintelLoadingScreen() else MyContent()
//
//   // Block the UI with a branded overlay while an action runs (send, upload):
//   await showLintelLoadingWhile(context, repo.sendBulk(...), message: 'Sending…');

import 'dart:math' as math;
import 'package:flutter/material.dart';

class LintelLoader extends StatefulWidget {
  const LintelLoader({
    super.key,
    this.size = 56,
    this.color = const Color(0xFF0F4F37), // brand green (good on light surfaces)
    this.trackColor, // faint ring; defaults to color @ 15%
    this.duration = const Duration(milliseconds: 1200),
    this.strokeWidth, // ring thickness; defaults to size/14
  });

  final double size;
  final Color color;
  final Color? trackColor;
  final Duration duration;
  final double? strokeWidth;

  @override
  State<LintelLoader> createState() => _LintelLoaderState();
}

class _LintelLoaderState extends State<LintelLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stroke = widget.strokeWidth ?? widget.size / 14;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _LintelLoaderPainter(
            t: _c.value,
            color: widget.color,
            trackColor: widget.trackColor ?? widget.color.withOpacity(0.15),
            stroke: stroke,
          ),
        ),
      ),
    );
  }
}

class _LintelLoaderPainter extends CustomPainter {
  _LintelLoaderPainter({
    required this.t,
    required this.color,
    required this.trackColor,
    required this.stroke,
  });

  final double t; // 0..1 animation progress
  final Color color;
  final Color trackColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;

    // 1) Faint full track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );

    // 2) Sweeping arc (rotates once per cycle).
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    final start = t * 2 * math.pi; // rotation
    const sweep = math.pi * 0.62; // arc length (~110°)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arc,
    );

    // 3) Portal mark in the centre, with a subtle breathing pulse.
    final pulse = 0.96 + 0.04 * math.sin(t * 2 * math.pi);
    final box = size.shortestSide * 0.42 * pulse;
    _drawMark(canvas, center, box, color);
  }

  // The Lintel mark in a 0..100 coordinate box, centred on [center].
  void _drawMark(Canvas canvas, Offset center, double box, Color c) {
    final s = box / 100.0;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    Offset pt(double x, double y) =>
        Offset(center.dx - box / 2 + x * s, center.dy - box / 2 + y * s);

    canvas.drawLine(pt(28, 29), pt(28, 71), p); // left post
    canvas.drawLine(pt(72, 29), pt(72, 71), p); // right post
    canvas.drawLine(pt(20, 29), pt(80, 29), p); // top beam (overhangs)
    canvas.drawLine(pt(28, 71), pt(72, 71), p); // threshold
  }

  @override
  bool shouldRepaint(_LintelLoaderPainter old) =>
      old.t != t || old.color != color || old.stroke != stroke;
}

/// Full-screen branded placeholder — use this instead of a blank screen while
/// a route or its data is loading.
class LintelLoadingScreen extends StatelessWidget {
  const LintelLoadingScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F4F37), // brand green
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LintelLoader(size: 72, color: Color(0xFFF4F8F6)), // white on green
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: const TextStyle(
                  color: Color(0xFFF4F8F6),
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Runs [future] while showing a branded modal overlay that blocks input, then
/// dismisses it. Use for actions where the user would otherwise stare at a
/// frozen or blank screen — sending email, uploading, saving large forms.
///
/// Returns the future's value (and rethrows its error after dismissing), so
/// callers keep their existing try/catch:
///
///   final result = await showLintelLoadingWhile(
///     context, repo.sendBulk(campaignId), message: 'Sending campaign…');
Future<T> showLintelLoadingWhile<T>(
  BuildContext context,
  Future<T> future, {
  String? message,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
  // ignore: unawaited_futures
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LintelLoader(size: 64, color: Color(0xFFF4F8F6)),
            if (message != null) ...[
              const SizedBox(height: 18),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFF4F8F6),
                  fontSize: 14.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ).then((_) => dialogOpen = false);

  try {
    return await future;
  } finally {
    if (dialogOpen && navigator.canPop()) navigator.pop();
  }
}
