import 'package:flutter/services.dart';

class InstalledApp {
  final String name;
  final String packageName;

  const InstalledApp({
    required this.name,
    required this.packageName,
  });
}

/// Catálogo de controles locais suportados no dispositivo Android.
const Map<String, String> kLocalDeviceControls = {
  'volume_up': 'Volume +',
  'volume_down': 'Volume -',
  'volume_mute': 'Mudo / Som',
  'brightness_up': 'Brilho +',
  'brightness_down': 'Brilho -',
  'brightness_auto': 'Brilho Auto',
  'bluetooth': 'Bluetooth (Ligar / Painel)',
  'wifi_panel': 'Wi-Fi / Internet (Painel)',
};

/// Serviço nativo (via MethodChannel) para abrir apps instalados e controlar
/// volume, brilho, Bluetooth e Wi-Fi diretamente no tablet/smartphone.
class LocalDeviceService {
  static const MethodChannel _channel =
      MethodChannel('dev.carlosamorim.scifideck.mobile/device_control');

  Future<List<InstalledApp>> listInstalledApps() async {
    try {
      final raw =
          await _channel.invokeListMethod<dynamic>('listInstalledApps');
      if (raw == null) return const [];
      return raw
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return InstalledApp(
              name: map['name'] as String? ?? '',
              packageName: map['package'] as String? ?? '',
            );
          })
          .where((a) => a.name.isNotEmpty && a.packageName.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String> launchApp(String packageName) async {
    final res = await _channel.invokeMethod<String>(
      'launchApp',
      {'packageName': packageName},
    );
    return res ?? 'Abrindo $packageName';
  }

  Future<String> runControl(String control) async {
    final res = await _channel.invokeMethod<String>(
      'deviceControl',
      {'control': control},
    );
    return res ?? 'Controle $control executado';
  }

  /// Abre o seletor nativo do Android (SAF) para salvar o JSON de backup.
  Future<bool> saveBackupFile(String content, {String fileName = 'scifi-deck-mobile-backup.json'}) async {
    final ok = await _channel.invokeMethod<bool>(
      'saveBackupFile',
      {'content': content, 'fileName': fileName},
    );
    return ok ?? false;
  }

  /// Abre o seletor nativo do Android (SAF) para ler um arquivo JSON de backup.
  Future<String?> openBackupFile() async {
    return _channel.invokeMethod<String>('openBackupFile');
  }
}
