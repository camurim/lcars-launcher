// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Sci-Fi Deck Control';

  @override
  String get backButton => '◄ VOLVER';

  @override
  String get statusOnline => 'EN LÍNEA';

  @override
  String get statusStandalone => 'AUTÓNOMO (LOCAL)';

  @override
  String get statusStandbyOffline => 'ESPERA / DESCONECTADO';

  @override
  String get sideConnect => 'CONECTAR';

  @override
  String get sideStandalone => 'AUTÓNOMO';

  @override
  String get sidePcLink => 'ENLACE PC';

  @override
  String get sideScreenOn => 'PANTALLA ACTIVA';

  @override
  String get sideScreenAuto => 'PANTALLA AUTO';

  @override
  String get sideEditPanel => 'EDITAR PANEL';

  @override
  String get sideDone => 'LISTO';

  @override
  String get sideAddBlock => '+ BLOQUE';

  @override
  String get blueprintHeader => 'BLUEPRINT';

  @override
  String get connectionHeader => 'ENLACE SUBESPACIAL • EMPAREJAMIENTO';

  @override
  String get scanQrButton => 'ESCANEAR QR';

  @override
  String get usbModeButton => 'MODO USB (127.0.0.1)';

  @override
  String get testingUsbButton => 'PROBANDO USB...';

  @override
  String get discoveredAgentsTitle => 'AGENTES DETECTADOS EN LA RED (mDNS)';

  @override
  String get searchingMdns =>
      'BUSCANDO _scifideck-agent._tcp EN LA RED LOCAL...';

  @override
  String get manualConnectionTitle => 'CONEXIÓN MANUAL / PIN DE 6 DÍGITOS';

  @override
  String get usbPinNotice =>
      'IMPORTANTE: INCLUSO EN MODO USB (127.0.0.1), EL PIN DE 6 DÍGITOS MOSTRADO EN EL DESKTOP AGENT ES OBLIGATORIO PARA AUTORIZAR EL DISPOSITIVO.';

  @override
  String get ipAddressLabel => 'DIRECCIÓN IP';

  @override
  String get portLabel => 'PUERTO';

  @override
  String get pinLabel => 'PIN TEMPORAL (6 DÍGITOS — OBLIGATORIO)';

  @override
  String get authorizeConnectButton => 'AUTORIZAR Y CONECTAR';

  @override
  String get connectingButton => 'CONECTANDO...';

  @override
  String get qrScannerHeader => 'ESCANEAR CÓDIGO QR DEL DESKTOP AGENT';

  @override
  String get invalidIpOrPinError =>
      'Ingrese una IP válida y un PIN de 6 dígitos.';

  @override
  String usbTunnelChecking(String host, int port) {
    return 'VERIFICANDO TÚNEL USB EN $host:$port...';
  }

  @override
  String get usbTunnelActiveConnecting => '¡TÚNEL USB ACTIVO! CONECTANDO...';

  @override
  String usbTunnelActiveEnterPin(String host, int port) {
    return '¡TÚNEL USB ACTIVO EN $host:$port! INCLUSO POR USB, INGRESE EL PIN DE 6 DÍGITOS DEL DESKTOP AGENT ABAJO Y TOQUE AUTORIZAR.';
  }

  @override
  String usbTunnelNotFound(String host, int port) {
    return 'Túnel USB no detectado en $host:$port. En su PC, ejecute:\nadb reverse tcp:$port tcp:$port';
  }

  @override
  String get dialogNewBlockTitle => 'BLUEPRINT • NUEVO BLOQUE';

  @override
  String get dialogEditBlockTitle => 'BLUEPRINT • EDITAR BLOQUE';

  @override
  String get fieldBlockType => 'TIPO DE BLOQUE';

  @override
  String get blockTypePcAction => 'Acción de PC (Ejecución Remota)';

  @override
  String get blockTypeLocalApp => 'App del Dispositivo (Abrir App Local)';

  @override
  String get blockTypeLocalControl =>
      'Control del Dispositivo (Brillo/Volumen/BT)';

  @override
  String get blockTypeInfo => 'Panel de Información (PC / Local)';

  @override
  String get blockTypeHttpJson => 'Panel HTTP / REST (JSON)';

  @override
  String get fieldPcAction => 'ACCIÓN SINCRONIZADA DEL PC';

  @override
  String get fieldInstalledApp => 'APLICACIÓN INSTALADA';

  @override
  String get loadingApps => 'CARGANDO APLICACIONES...';

  @override
  String get fieldDeviceControl => 'CONTROL DEL DISPOSITIVO';

  @override
  String get fieldDataSource => 'FUENTE DE DATOS';

  @override
  String get sourcePcTelemetry => 'Telemetría / Comandos del PC';

  @override
  String get sourceLocalDevice => 'Sensor Local de la Tablet';

  @override
  String get fieldMetric => 'MÉTRICA';

  @override
  String get metricPcCpu => 'PC: Uso de CPU (%)';

  @override
  String get metricPcRamFree => 'PC: RAM Libre (GB)';

  @override
  String get metricPcTemp => 'PC: Temperatura CPU (°C)';

  @override
  String get metricLocalClock => 'Local: Hora';

  @override
  String get metricLocalStardate => 'Local: Fecha Estelar (Stardate)';

  @override
  String get metricLocalBattery => 'Local: Nivel de Batería';

  @override
  String get fieldHttpUrl => 'URL REST (GET JSON)';

  @override
  String get fieldHttpPath => 'RUTA DE PROPIEDAD JSON';

  @override
  String get fieldHttpPrefix => 'PREFIJO';

  @override
  String get fieldHttpSuffix => 'SUFIJO';

  @override
  String get testRequestButton => 'PROBAR SOLICITUD';

  @override
  String get testingRequestButton => 'PROBANDO...';

  @override
  String get fieldPanelLabel => 'ETIQUETA DEL PANEL';

  @override
  String get fieldLcarsColor => 'COLOR DEL PANEL';

  @override
  String get btnRemove => 'ELIMINAR';

  @override
  String get btnCancel => 'CANCELAR';

  @override
  String get btnSaveSync => 'GUARDAR Y SINCRONIZAR';

  @override
  String get tapToRefresh => 'TOCAR P/ ACTUALIZAR';

  @override
  String get waiting => 'ESPERANDO...';

  @override
  String get ctrlVolumeUp => 'Volumen +';

  @override
  String get ctrlVolumeDown => 'Volumen -';

  @override
  String get ctrlVolumeMute => 'Silencio / Sonido';

  @override
  String get ctrlBrightnessUp => 'Brillo +';

  @override
  String get ctrlBrightnessDown => 'Brillo -';

  @override
  String get ctrlBrightnessAuto => 'Brillo Auto';

  @override
  String get ctrlBluetooth => 'Bluetooth (Activar / Panel)';

  @override
  String get ctrlWifiPanel => 'Wi-Fi / Internet (Panel)';

  @override
  String get fieldDisplayFormat => 'ESTILO DE VISUALIZACIÓN';

  @override
  String get formatBar => 'Barra Segmentada';

  @override
  String get formatSparkline => 'Gráfico de Línea (Sparkline)';

  @override
  String get formatGauge => 'Medidor Radial (Gauge)';

  @override
  String get formatValue => 'Solo Numérico';

  @override
  String get sideAlarmMute => 'SILENCIAR';

  @override
  String get sideAlarmUnmute => 'SONIDO ALERTA';

  @override
  String get fieldAlarmMode => 'MODO DE ALARMA (RED ALERT)';

  @override
  String get alarmNone => 'Desactivado';

  @override
  String get alarmVisual => 'Visual (Luces Rojas)';

  @override
  String get alarmSound => 'Sonoro (Klaxon Red Alert)';

  @override
  String get alarmBoth => 'Visual + Sonoro';

  @override
  String get fieldAlarmMin => 'MÍNIMO (≤)';

  @override
  String get fieldAlarmMax => 'MÁXIMO (≥)';

  @override
  String get sideBackup => 'RESPALDO';

  @override
  String get backupDialogTitle => 'RESPALDO Y RESTAURACIÓN';

  @override
  String get btnExportFile => 'GUARDAR ARCHIVO .JSON';

  @override
  String get btnCopyJson => 'COPIAR JSON';

  @override
  String get btnImportFile => 'ABRIR ARCHIVO .JSON';

  @override
  String get btnPushPc => 'ENVIAR AL PC';

  @override
  String get btnPullPc => 'RESTAURAR DESDE PC';

  @override
  String get fieldPasteBackupJson => 'O PEGUE EL JSON DE RESPALDO';

  @override
  String get btnRestoreJsonText => 'RESTAURAR DESDE TEXTO';

  @override
  String get backupSavedOk => '¡Archivo de respaldo guardado con éxito!';

  @override
  String get backupCancelled => 'Exportación cancelada.';

  @override
  String get backupCopiedOk => '¡JSON de respaldo copiado al portapapeles!';

  @override
  String get backupRestoredOk => '¡Respaldo restaurado con éxito!';

  @override
  String get backupInvalidError => 'JSON de respaldo inválido';

  @override
  String get backupPushedPc => '¡Respaldo enviado al PC!';

  @override
  String get backupPulledPc => 'Solicitando respaldo guardado en el PC...';
}
