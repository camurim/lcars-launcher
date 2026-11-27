import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Feedback sonoro (just_audio) e tátil (HapticFeedback) estilo console LCARS.
class LcarsFeedback {
  final AudioPlayer _player;
  final bool enabled;

  LcarsFeedback({AudioPlayer? player, this.enabled = true})
      : _player = player ?? AudioPlayer();

  Future<void> playTap() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
    await _playAsset('assets/sounds/lcars_beep.wav');
  }

  Future<void> playConfirm() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
    await _playAsset('assets/sounds/lcars_confirm.wav');
  }

  Future<void> playError() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
    await _playAsset('assets/sounds/lcars_error.wav');
  }

  Future<void> playRedAlert() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
    await _playAsset('assets/sounds/lcars_red_alert.wav');
  }

  Future<void> _playAsset(String assetPath) async {
    try {
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (_) {
      // Ignora graciosamente em testes unitários/headless sem engine de áudio.
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
