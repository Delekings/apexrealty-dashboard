// lib/core/responsive/layout_helpers.dart
import 'package:flutter/widgets.dart';

import 'breakpoints.dart';
import 'responsive.dart';

/// Centres page content and caps its width on large screens, while going
/// edge-to-edge with smaller padding on phones. Drop this around the body
/// of any screen so content doesn't stretch to 2000px on wide monitors.
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ??
        EdgeInsets.symmetric(
          horizontal: context.responsive(mobile: 16.0, tablet: 20.0, desktop: 24.0),
          vertical: context.responsive(mobile: 16.0, desktop: 20.0),
        );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );
  }
}

/// Lays children out in a [Row] (each [Expanded]) on tablet/desktop, and
/// stacks them in a [Column] on mobile. Ideal for "two cards side by side
/// on desktop, stacked on phone" without writing the branch yourself.
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  /// If true (default) children stack vertically on mobile. If false they
  /// stay in a row at every breakpoint.
  final bool stackOnMobile;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.stackOnMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    if (stackOnMobile && context.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withGaps(children, vertical: true),
      );
    }
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: _withGaps(
        [for (final c in children) Expanded(child: c)],
        vertical: false,
      ),
    );
  }

  List<Widget> _withGaps(List<Widget> items, {required bool vertical}) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(vertical
            ? SizedBox(height: spacing)
            : SizedBox(width: spacing));
      }
    }
    return out;
  }
}

/// A flow grid whose column count changes per breakpoint. Computes exact
/// item widths from the available width so it nests safely inside scroll
/// views (no GridView intrinsic-height surprises). Great for stat cards.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    final columns = context.responsive(
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (columns - 1);
        final itemWidth =
        ((constraints.maxWidth - totalSpacing) / columns).floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth < 0 ? 0 : itemWidth, child: child),
          ],
        );
      },
    );
  }
}