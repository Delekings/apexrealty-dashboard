// lib/core/responsive/responsive.dart
import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// A value that differs per breakpoint, with a graceful fallback chain:
/// desktop → tablet → mobile, and tablet → mobile. Only [mobile] is required.
///
///   final pad = const ResponsiveValue<double>(
///     mobile: 16, tablet: 20, desktop: 24,
///   ).of(context);
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  T resolve(Breakpoint bp) {
    switch (bp) {
      case Breakpoint.desktop:
        return desktop ?? tablet ?? mobile;
      case Breakpoint.tablet:
        return tablet ?? mobile;
      case Breakpoint.mobile:
        return mobile;
    }
  }

  T of(BuildContext context) => resolve(context.breakpoint);
}

/// Inline helper so you don't have to construct a [ResponsiveValue]:
///
///   padding: EdgeInsets.all(context.responsive(mobile: 16, desktop: 24)),
extension ResponsiveContext on BuildContext {
  T responsive<T>({required T mobile, T? tablet, T? desktop}) =>
      ResponsiveValue<T>(mobile: mobile, tablet: tablet, desktop: desktop)
          .of(this);
}

/// Picks an entirely different widget subtree per breakpoint.
/// Falls back desktop → tablet → mobile.
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    switch (context.breakpoint) {
      case Breakpoint.desktop:
        return desktop ?? tablet ?? mobile;
      case Breakpoint.tablet:
        return tablet ?? mobile;
      case Breakpoint.mobile:
        return mobile;
    }
  }
}

/// Builder form when you need the breakpoint value itself in-line.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Breakpoint breakpoint) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => builder(context, context.breakpoint);
}