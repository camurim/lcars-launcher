import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../theme/lcars_theme.dart';
import 'lcars_pill_bar.dart';

/// Botão "VOLTAR" reutilizável no estilo LCARS para telas secundárias.
class LcarsBackButton extends StatelessWidget {
  final String? label;
  final Color color;
  final VoidCallback? onPressed;

  const LcarsBackButton({
    super.key,
    this.label,
    this.color = LcarsColors.redAlert,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabel =
        label ?? AppLocalizations.of(context)?.backButton ?? '◄ BACK';
    return SizedBox(
      width: 118,
      child: LcarsPillBar(
        color: color,
        height: 30,
        capSide: LcarsCapSide.both,
        label: effectiveLabel,
        onTap: () {
          HapticFeedback.lightImpact();
          if (onPressed != null) {
            onPressed!();
          } else {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }
}
