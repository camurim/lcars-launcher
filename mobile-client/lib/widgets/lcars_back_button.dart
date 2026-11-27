import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/lcars_theme.dart';
import 'lcars_pill_bar.dart';

/// Botão "VOLTAR" reutilizável no estilo LCARS para telas secundárias.
class LcarsBackButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const LcarsBackButton({
    super.key,
    this.label = '◄ VOLTAR',
    this.color = LcarsColors.redAlert,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: LcarsPillBar(
        color: color,
        height: 30,
        capSide: LcarsCapSide.both,
        label: label,
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
