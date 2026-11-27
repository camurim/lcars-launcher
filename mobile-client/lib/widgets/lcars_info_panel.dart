import 'package:flutter/material.dart';
import '../theme/lcars_theme.dart';

/// Painel de Informação Read-Only estilo LCARS com barra de nível segmentada.
/// Exibe "STANDBY / OFFLINE" para métricas do PC quando desconectado,
/// mantendo widgets locais do tablet sempre ativos.
class LcarsInfoPanel extends StatelessWidget {
  final String label;
  final String value;
  final String sourceTag;
  final Color color;
  final double? progress; // 0.0 a 1.0 opcional
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
    this.offline = false,
    this.blueprintMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final accent = offline ? LcarsColors.offlineGrey : color;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: LcarsColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: blueprintMode ? LcarsColors.skyBlue : accent,
            width: blueprintMode ? 2.5 : 2,
          ),
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
                      color: offline ? LcarsColors.redAlert : accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Text(
                  blueprintMode ? 'EDIT' : sourceTag,
                  style: TextStyle(
                    color: blueprintMode
                        ? LcarsColors.skyBlue
                        : LcarsColors.textLight.withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              offline ? 'STANDBY / OFFLINE' : value,
              maxLines: value.length > 14 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: offline ? LcarsColors.redAlert : LcarsColors.textLight,
                fontSize: offline ? 14 : (value.length > 14 ? 15 : 22),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              _LcarsSegmentedMeter(
                value: offline ? 0.0 : progress!.clamp(0.0, 1.0),
                color: accent,
              ),
            ],
          ],
        ),
      ),
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
