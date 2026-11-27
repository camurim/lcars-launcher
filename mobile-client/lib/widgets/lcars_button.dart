import 'package:flutter/material.dart';
import '../theme/lcars_theme.dart';

/// Painel de Execução LCARS vinculado a uma `action_id` do PC.
/// Suporta estado confirmado (animado), modo STANDBY/OFFLINE e Blueprint Mode.
class LcarsButton extends StatelessWidget {
  final String label;
  final String? code;
  final Color color;
  final bool offline;
  final bool confirmed;
  final bool blueprintMode;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  const LcarsButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.code,
    this.offline = false,
    this.confirmed = false,
    this.blueprintMode = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = confirmed
        ? LcarsColors.gold
        : (offline ? LcarsColors.offlineGrey : color);

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: BorderRadius.circular(24),
          border: blueprintMode
              ? Border.all(color: LcarsColors.skyBlue, width: 2.5)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (blueprintMode)
                        const Text(
                          'EDIT',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        )
                      else if (offline)
                        const Text(
                          'STANDBY / OFFLINE',
                          style: TextStyle(
                            color: LcarsColors.redAlert,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        )
                      else if (confirmed)
                        const Text(
                          'EXECUTED',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      if (code != null)
                        Text(
                          code!,
                          style: TextStyle(
                            color: offline
                                ? LcarsColors.textLight.withValues(alpha: 0.6)
                                : LcarsColors.textDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: offline
                          ? LcarsColors.textLight.withValues(alpha: 0.65)
                          : LcarsColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
