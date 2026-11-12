import 'package:flutter/material.dart';

/// Shared Field Work layout based on the FBMN control contract.
/// It lets compact filters share a row without clipping dropdown labels.
class AdaptiveFilterRow extends StatelessWidget {
  final List<Widget> children;
  final double minFieldWidth;
  final double spacing;
  final int maxColumns;

  const AdaptiveFilterRow({
    super.key,
    required this.children,
    this.minFieldWidth = 160,
    this.spacing = 8,
    this.maxColumns = 3,
  }) : assert(minFieldWidth > 0),
       assert(maxColumns > 0);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (children.isEmpty) return const SizedBox.shrink();
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      var columns = ((width + spacing) / (minFieldWidth + spacing)).floor();
      if (columns < 1) columns = 1;
      if (columns > maxColumns) columns = maxColumns;
      if (columns > children.length) columns = children.length;
      final fieldWidth = (width - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: fieldWidth, child: child),
        ],
      );
    },
  );
}

/// Long values (province, district, customer fields) use a full mobile row.
/// Tablet/desktop screens can display two or three columns when room permits.
class ResponsiveFormRow extends StatelessWidget {
  final List<Widget> children;
  const ResponsiveFormRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) => AdaptiveFilterRow(
    minFieldWidth: 260,
    maxColumns: 3,
    children: children,
  );
}
