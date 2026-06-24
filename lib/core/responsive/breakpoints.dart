// lib/core/responsive/breakpoints.dart
import 'package:flutter/widgets.dart';

/// The three deliberate, equal-priority form factors for Lintel.
///
///   mobile  : < 600px   → bottom nav + drawer (phones, field agents)
///   tablet  : 600–1023  → compact icon rail (iPads, small laptops)
///   desktop : >= 1024   → full labelled sidebar (office machines)
enum Breakpoint { mobile, tablet, desktop }

class Breakpoints {
  const Breakpoints._();

  /// Width at/above which we switch from mobile → tablet.
  static const double tablet = 600;

  /// Width at/above which we switch from tablet → desktop.
  static const double desktop = 1024;

  static Breakpoint fromWidth(double width) {
    if (width >= desktop) return Breakpoint.desktop;
    if (width >= tablet) return Breakpoint.tablet;
    return Breakpoint.mobile;
  }
}

/// Ergonomic access to the current breakpoint from any [BuildContext].
///
/// Uses [MediaQuery.sizeOf] so a widget only rebuilds when the size
/// metric actually changes (cheaper than `MediaQuery.of`).
extension BreakpointContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  Breakpoint get breakpoint => Breakpoints.fromWidth(screenWidth);

  bool get isMobile => breakpoint == Breakpoint.mobile;
  bool get isTablet => breakpoint == Breakpoint.tablet;
  bool get isDesktop => breakpoint == Breakpoint.desktop;

  /// True for phones AND tablets — handy for "stack it / hide it" decisions.
  bool get isCompact => breakpoint != Breakpoint.desktop;
}