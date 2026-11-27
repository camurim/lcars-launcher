// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sci-Fi Deck Control';

  @override
  String get backButton => '◄ BACK';

  @override
  String get statusOnline => 'ONLINE';

  @override
  String get statusStandalone => 'STANDALONE (LOCAL)';

  @override
  String get statusStandbyOffline => 'STANDBY / OFFLINE';

  @override
  String get sideConnect => 'CONNECT';

  @override
  String get sideStandalone => 'STANDALONE';

  @override
  String get sidePcLink => 'PC LINK';

  @override
  String get sideScreenOn => 'SCREEN ON';

  @override
  String get sideScreenAuto => 'SCREEN AUTO';

  @override
  String get sideEditPanel => 'EDIT PANEL';

  @override
  String get sideDone => 'DONE';

  @override
  String get sideAddBlock => '+ BLOCK';

  @override
  String get blueprintHeader => 'BLUEPRINT';

  @override
  String get connectionHeader => 'SUBSPACE LINK • PAIRING';

  @override
  String get scanQrButton => 'SCAN QR CODE';

  @override
  String get usbModeButton => 'USB MODE (127.0.0.1)';

  @override
  String get testingUsbButton => 'TESTING USB...';

  @override
  String get discoveredAgentsTitle => 'DISCOVERED AGENTS ON NETWORK (mDNS)';

  @override
  String get searchingMdns =>
      'SEARCHING _scifideck-agent._tcp ON LOCAL NETWORK...';

  @override
  String get manualConnectionTitle => 'MANUAL CONNECTION / 6-DIGIT PIN';

  @override
  String get usbPinNotice =>
      'IMPORTANT: EVEN IN USB MODE (127.0.0.1), THE 6-DIGIT PIN SHOWN IN THE DESKTOP AGENT IS REQUIRED TO AUTHORIZE THIS DEVICE.';

  @override
  String get ipAddressLabel => 'IP ADDRESS';

  @override
  String get portLabel => 'PORT';

  @override
  String get pinLabel => 'TEMPORARY PIN (6 DIGITS — REQUIRED)';

  @override
  String get authorizeConnectButton => 'AUTHORIZE & CONNECT';

  @override
  String get connectingButton => 'CONNECTING...';

  @override
  String get qrScannerHeader => 'SCAN DESKTOP AGENT QR CODE';

  @override
  String get invalidIpOrPinError => 'Enter a valid IP and a 6-digit PIN.';

  @override
  String usbTunnelChecking(String host, int port) {
    return 'CHECKING USB TUNNEL AT $host:$port...';
  }

  @override
  String get usbTunnelActiveConnecting => 'USB TUNNEL ACTIVE! CONNECTING...';

  @override
  String usbTunnelActiveEnterPin(String host, int port) {
    return 'USB TUNNEL ACTIVE AT $host:$port! EVEN OVER USB, ENTER THE 6-DIGIT PIN FROM THE DESKTOP AGENT BELOW AND TAP AUTHORIZE.';
  }

  @override
  String usbTunnelNotFound(String host, int port) {
    return 'USB tunnel not detected at $host:$port. On your PC, run:\nadb reverse tcp:$port tcp:$port';
  }

  @override
  String get dialogNewBlockTitle => 'BLUEPRINT • NEW BLOCK';

  @override
  String get dialogEditBlockTitle => 'BLUEPRINT • EDIT BLOCK';

  @override
  String get fieldBlockType => 'BLOCK TYPE';

  @override
  String get blockTypePcAction => 'PC Action (Remote Execution)';

  @override
  String get blockTypeLocalApp => 'Device App (Launch Local App)';

  @override
  String get blockTypeLocalControl => 'Device Control (Brightness/Volume/BT)';

  @override
  String get blockTypeInfo => 'Info Panel (PC / Local)';

  @override
  String get blockTypeHttpJson => 'HTTP / REST Panel (JSON)';

  @override
  String get fieldPcAction => 'SYNCED PC ACTION';

  @override
  String get fieldInstalledApp => 'INSTALLED APP';

  @override
  String get loadingApps => 'LOADING INSTALLED APPS...';

  @override
  String get fieldDeviceControl => 'DEVICE CONTROL';

  @override
  String get fieldDataSource => 'DATA SOURCE';

  @override
  String get sourcePcTelemetry => 'PC Telemetry / Commands';

  @override
  String get sourceLocalDevice => 'Tablet Local Sensor';

  @override
  String get fieldMetric => 'METRIC';

  @override
  String get metricPcCpu => 'PC: CPU Usage (%)';

  @override
  String get metricPcRamFree => 'PC: Free RAM (GB)';

  @override
  String get metricPcTemp => 'PC: CPU Temperature (°C)';

  @override
  String get metricLocalClock => 'Local: Time';

  @override
  String get metricLocalStardate => 'Local: Stardate';

  @override
  String get metricLocalBattery => 'Local: Battery Level';

  @override
  String get fieldHttpUrl => 'REST URL (GET JSON)';

  @override
  String get fieldHttpPath => 'JSON PROPERTY PATH';

  @override
  String get fieldHttpPrefix => 'PREFIX';

  @override
  String get fieldHttpSuffix => 'SUFFIX';

  @override
  String get testRequestButton => 'TEST REQUEST';

  @override
  String get testingRequestButton => 'TESTING...';

  @override
  String get fieldPanelLabel => 'PANEL LABEL';

  @override
  String get fieldLcarsColor => 'PANEL COLOR';

  @override
  String get btnRemove => 'REMOVE';

  @override
  String get btnCancel => 'CANCEL';

  @override
  String get btnSaveSync => 'SAVE & SYNC';

  @override
  String get tapToRefresh => 'TAP TO REFRESH';

  @override
  String get waiting => 'WAITING...';

  @override
  String get ctrlVolumeUp => 'Volume +';

  @override
  String get ctrlVolumeDown => 'Volume -';

  @override
  String get ctrlVolumeMute => 'Mute / Sound';

  @override
  String get ctrlBrightnessUp => 'Brightness +';

  @override
  String get ctrlBrightnessDown => 'Brightness -';

  @override
  String get ctrlBrightnessAuto => 'Brightness Auto';

  @override
  String get ctrlBluetooth => 'Bluetooth (Enable / Panel)';

  @override
  String get ctrlWifiPanel => 'Wi-Fi / Internet (Panel)';

  @override
  String get fieldDisplayFormat => 'DISPLAY STYLE';

  @override
  String get formatBar => 'Segmented Bar';

  @override
  String get formatSparkline => 'Line Chart (Sparkline)';

  @override
  String get formatGauge => 'Radial Gauge';

  @override
  String get formatValue => 'Numeric Only';

  @override
  String get sideAlarmMute => 'MUTE ALERT';

  @override
  String get sideAlarmUnmute => 'SOUND ALERT';

  @override
  String get fieldAlarmMode => 'ALARM MODE (RED ALERT)';

  @override
  String get alarmNone => 'Disabled';

  @override
  String get alarmVisual => 'Visual (Flashing Red Lights)';

  @override
  String get alarmSound => 'Sound (Red Alert Klaxon)';

  @override
  String get alarmBoth => 'Visual + Sound';

  @override
  String get fieldAlarmMin => 'MIN (≤)';

  @override
  String get fieldAlarmMax => 'MAX (≥)';

  @override
  String get sideBackup => 'BACKUP';

  @override
  String get backupDialogTitle => 'BACKUP & RESTORE';

  @override
  String get btnExportFile => 'SAVE .JSON FILE';

  @override
  String get btnCopyJson => 'COPY JSON';

  @override
  String get btnImportFile => 'OPEN .JSON FILE';

  @override
  String get btnPushPc => 'SEND TO PC';

  @override
  String get btnPullPc => 'RESTORE FROM PC';

  @override
  String get fieldPasteBackupJson => 'OR PASTE BACKUP JSON';

  @override
  String get btnRestoreJsonText => 'RESTORE FROM TEXT';

  @override
  String get backupSavedOk => 'Backup file saved successfully!';

  @override
  String get backupCancelled => 'Export cancelled.';

  @override
  String get backupCopiedOk => 'Backup JSON copied to clipboard!';

  @override
  String get backupRestoredOk => 'Backup restored successfully!';

  @override
  String get backupInvalidError => 'Invalid backup JSON';

  @override
  String get backupPushedPc => 'Layout backup sent to PC!';

  @override
  String get backupPulledPc => 'Requesting backup from PC...';
}
