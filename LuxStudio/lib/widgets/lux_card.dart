import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

/// The mockup's `.card`: surface fill, 1px border, 16px radius.
class LuxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const LuxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.backgroundColor,
    this.borderWidth = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? LuxColors.surface,
        border: Border.all(color: borderColor ?? LuxColors.border, width: borderWidth),
        borderRadius: BorderRadius.circular(LuxRadii.card),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(LuxRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(LuxRadii.card),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// The mockup's `.card-dashed`: a dashed-outline drop-zone card. Flutter
/// has no built-in dashed border, so this paints one directly.
class LuxDashedCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const LuxDashedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _DashedBorderPainter(radius: LuxRadii.dashedCard),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: LuxColors.surfaceDashed,
            borderRadius: BorderRadius.circular(LuxRadii.dashedCard),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final double radius;
  const _DashedBorderPainter({required this.radius});

  static const _dashWidth = 6.0;
  static const _dashSpace = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = LuxColors.borderDashed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
