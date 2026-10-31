import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Technical dot-grid canvas background giving the editorial ideation / research notebook aesthetic.
class DotGridBackground extends StatelessWidget {
  const DotGridBackground({
    super.key,
    required this.child,
    this.spacing = 20.0,
    this.dotRadius = 1.0,
    this.dotColor,
    this.backgroundColor,
  });

  final Widget child;
  final double spacing;
  final double dotRadius;
  final Color? dotColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedDotColor = dotColor ??
        (isDark
            ? AppTheme.dotGridDark.withValues(alpha: 0.7)
            : AppTheme.dotGrid.withValues(alpha: 0.85));
    final resolvedBg = backgroundColor ??
        (isDark ? const Color(0xFF101216) : const Color(0xFFFBFBFB));

    return ColoredBox(
      color: resolvedBg,
      child: CustomPaint(
        painter: DotGridPainter(
          spacing: spacing,
          dotRadius: dotRadius,
          dotColor: resolvedDotColor,
        ),
        child: child,
      ),
    );
  }
}

class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    required this.spacing,
    required this.dotRadius,
    required this.dotColor,
  });

  final double spacing;
  final double dotRadius;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Center grid offset slightly for symmetry
    final startX = (size.width % spacing) / 2;
    final startY = (size.height % spacing) / 2;

    for (double x = startX; x < size.width; x += spacing) {
      for (double y = startY; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) {
    return oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.dotColor != dotColor;
  }
}
