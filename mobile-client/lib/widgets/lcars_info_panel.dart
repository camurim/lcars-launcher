import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/lcars_theme.dart';

/// Painel de Informação Read-Only estilo LCARS com suporte a 4 modos:
/// `bar` (barra segmentada), `sparkline` (gráfico de linha),
/// `gauge` (medidor radial semicircular) e `value` (numérico clássico).
class LcarsInfoPanel extends StatelessWidget {
  final String label;
  final String value;
  final String sourceTag;
  final Color color;
  final double? progress; // 0.0 a 1.0 opcional
  final String displayFormat;
  final List<double> history;
  final bool alarmActive;
  final double alarmPulse;
  final bool offline;
  final bool blueprintMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const LcarsInfoPanel({
    super.key,
    required this.label,
    required this.value,
    required this.sourceTag,
    required this.color,
    this.progress,
    this.displayFormat = 'bar',
    this.history = const [],
    this.alarmActive = false,
    this.alarmPulse = 0.0,
    this.offline = false,
    this.blueprintMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final redPulseColor = Color.lerp(
      const Color(0xFF991B1B),
      const Color(0xFFFF2B2B),
      alarmPulse,
    )!;
    final accent = alarmActive
        ? redPulseColor
        : (offline ? LcarsColors.offlineGrey : color);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: alarmActive
              ? redPulseColor.withValues(alpha: 0.14 + 0.18 * alarmPulse)
              : LcarsColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: blueprintMode ? LcarsColors.skyBlue : accent,
            width: alarmActive ? 3 : (blueprintMode ? 2.5 : 2),
          ),
          boxShadow: alarmActive
              ? [
                  BoxShadow(
                    color: redPulseColor.withValues(
                      alpha: 0.25 + 0.45 * alarmPulse,
                    ),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: alarmActive
                          ? redPulseColor
                          : (offline ? LcarsColors.redAlert : accent),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Text(
                  blueprintMode
                      ? 'EDIT'
                      : (alarmActive ? 'RED ALERT' : sourceTag),
                  style: TextStyle(
                    color: blueprintMode
                        ? LcarsColors.skyBlue
                        : (alarmActive
                            ? redPulseColor
                            : LcarsColors.textLight.withValues(alpha: 0.65)),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Color accent) {
    if (offline) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'STANDBY / OFFLINE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: LcarsColors.redAlert,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
    }

    if (displayFormat == 'sparkline' && progress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                color: LcarsColors.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: CustomPaint(
              painter: _LcarsSparklinePainter(
                samples: history.isEmpty ? [progress!] : history,
                color: accent,
              ),
            ),
          ),
        ],
      );
    }

    if (displayFormat == 'gauge' && progress != null) {
      return CustomPaint(
        painter: _LcarsGaugePainter(
          value: progress!.clamp(0.0, 1.0),
          color: accent,
        ),
        child: Align(
          alignment: const Alignment(0, 0.55),
          child: Text(
            value,
            style: const TextStyle(
              color: LcarsColors.textLight,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value,
          maxLines: value.length > 14 ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: LcarsColors.textLight,
            fontSize: value.length > 14 ? 15 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        if (displayFormat != 'value' && progress != null) ...[
          const SizedBox(height: 6),
          _LcarsSegmentedMeter(
            value: progress!.clamp(0.0, 1.0),
            color: accent,
          ),
        ],
      ],
    );
  }
}

class _LcarsSegmentedMeter extends StatelessWidget {
  final double value;
  final Color color;

  const _LcarsSegmentedMeter({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    const segments = 10;
    final filled = (value * segments).round();
    return Row(
      children: List.generate(segments, (i) {
        final active = i < filled;
        return Expanded(
          child: Container(
            height: 7,
            margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 3),
            decoration: BoxDecoration(
              color: active ? color : color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class _LcarsSparklinePainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  _LcarsSparklinePainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || samples.isEmpty) return;

    // Linhas sutis de referência (25%, 50%, 75%)
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (final frac in const [0.25, 0.5, 0.75]) {
      final y = size.height * frac;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePath = Path();
    final fillPath = Path();
    final count = samples.length;
    final stepX = count > 1 ? size.width / (count - 1) : size.width;

    for (var i = 0; i < count; i++) {
      final x = count > 1 ? i * stepX : size.width;
      final v = samples[i].clamp(0.0, 1.0);
      final y = size.height - (v * (size.height - 4)) - 2;
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    if (count == 1) {
      final y = size.height - (samples.first.clamp(0.0, 1.0) * (size.height - 4)) - 2;
      linePath.moveTo(0, y);
      linePath.lineTo(size.width, y);
      fillPath
        ..moveTo(0, size.height)
        ..lineTo(0, y)
        ..lineTo(size.width, y)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      fillPath
        ..lineTo(size.width, size.height)
        ..close();
    }

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    // Ponto de destaque na leitura mais recente
    final lastY =
        size.height - (samples.last.clamp(0.0, 1.0) * (size.height - 4)) - 2;
    canvas.drawCircle(
      Offset(size.width - 2, lastY),
      3.2,
      Paint()..color = LcarsColors.textLight,
    );
  }

  @override
  bool shouldRepaint(covariant _LcarsSparklinePainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}

class _LcarsGaugePainter extends CustomPainter {
  final double value;
  final Color color;

  _LcarsGaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width * 0.44, size.height * 0.85);
    if (radius <= 6) return;
    final center = Offset(size.width / 2, size.height * 0.88);
    final rect = Rect.fromCircle(center: center, radius: radius);

    const segments = 12;
    const gapAngle = 0.05;
    final totalSweep = math.pi;
    final segSweep = (totalSweep - gapAngle * (segments - 1)) / segments;
    final filled = (value * segments).round();

    for (var i = 0; i < segments; i++) {
      final startAngle = math.pi + i * (segSweep + gapAngle);
      final paint = Paint()
        ..color = i < filled ? color : color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, segSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LcarsGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}
