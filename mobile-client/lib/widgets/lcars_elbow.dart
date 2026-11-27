import 'package:flutter/material.dart';

enum LcarsElbowCorner { topLeft, bottomLeft }

/// Desenha o clássico "cotovelo" (elbow) assimétrico LCARS usando [CustomPainter].
class LcarsElbow extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final double barThickness;
  final LcarsElbowCorner corner;
  final String? label;

  const LcarsElbow({
    super.key,
    required this.color,
    this.width = 148,
    this.height = 76,
    this.barThickness = 26,
    this.corner = LcarsElbowCorner.topLeft,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LcarsElbowPainter(
                color: color,
                barThickness: barThickness,
                corner: corner,
              ),
            ),
          ),
          if (label != null)
            Positioned(
              left: 12,
              bottom: corner == LcarsElbowCorner.topLeft ? 8 : null,
              top: corner == LcarsElbowCorner.bottomLeft ? 8 : null,
              child: Text(
                label!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LcarsElbowPainter extends CustomPainter {
  final Color color;
  final double barThickness;
  final LcarsElbowCorner corner;

  _LcarsElbowPainter({
    required this.color,
    required this.barThickness,
    required this.corner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final outerRadius = size.height * 0.62;
    const innerRadius = 20.0;
    final leftColumnWidth = size.width * 0.62;

    final path = Path();
    if (corner == LcarsElbowCorner.topLeft) {
      path
        ..moveTo(0, size.height)
        ..lineTo(0, outerRadius)
        ..quadraticBezierTo(0, 0, outerRadius, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, barThickness)
        ..lineTo(leftColumnWidth + innerRadius, barThickness)
        ..quadraticBezierTo(
          leftColumnWidth,
          barThickness,
          leftColumnWidth,
          barThickness + innerRadius,
        )
        ..lineTo(leftColumnWidth, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(leftColumnWidth, 0)
        ..lineTo(leftColumnWidth, size.height - barThickness - innerRadius)
        ..quadraticBezierTo(
          leftColumnWidth,
          size.height - barThickness,
          leftColumnWidth + innerRadius,
          size.height - barThickness,
        )
        ..lineTo(size.width, size.height - barThickness)
        ..lineTo(size.width, size.height)
        ..lineTo(outerRadius, size.height)
        ..quadraticBezierTo(0, size.height, 0, size.height - outerRadius)
        ..close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LcarsElbowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.barThickness != barThickness ||
        oldDelegate.corner != corner;
  }
}
