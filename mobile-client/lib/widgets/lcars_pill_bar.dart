import 'package:flutter/material.dart';

enum LcarsCapSide { left, right, both, none }

/// [CustomClipper] que recorta barras horizontais/verticais com terminações em pílula LCARS.
class LcarsPillClipper extends CustomClipper<Path> {
  final LcarsCapSide capSide;

  const LcarsPillClipper({this.capSide = LcarsCapSide.both});

  @override
  Path getClip(Size size) {
    final radius = size.height / 2;
    final leftRadius =
        (capSide == LcarsCapSide.left || capSide == LcarsCapSide.both)
            ? Radius.circular(radius)
            : Radius.zero;
    final rightRadius =
        (capSide == LcarsCapSide.right || capSide == LcarsCapSide.both)
            ? Radius.circular(radius)
            : Radius.zero;

    return Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, size.width, size.height),
          topLeft: leftRadius,
          bottomLeft: leftRadius,
          topRight: rightRadius,
          bottomRight: rightRadius,
        ),
      );
  }

  @override
  bool shouldReclip(covariant LcarsPillClipper oldClipper) {
    return oldClipper.capSide != capSide;
  }
}

/// Barra LCARS recortada via [ClipPath] com suporte a texto e toque.
class LcarsPillBar extends StatelessWidget {
  final Color color;
  final double height;
  final LcarsCapSide capSide;
  final String? label;
  final VoidCallback? onTap;

  const LcarsPillBar({
    super.key,
    required this.color,
    this.height = 26,
    this.capSide = LcarsCapSide.right,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipPath(
      clipper: LcarsPillClipper(capSide: capSide),
      child: Container(
        height: height,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerRight,
        child: label == null
            ? null
            : Text(
                label!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
