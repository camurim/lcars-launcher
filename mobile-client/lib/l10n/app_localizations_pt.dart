// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Sci-Fi Deck Control';

  @override
  String get backButton => '◄ VOLTAR';

  @override
  String get statusOnline => 'ONLINE';

  @override
  String get statusStandalone => 'STANDALONE (LOCAL)';

  @override
  String get statusStandbyOffline => 'STANDBY / OFFLINE';

  @override
  String get sideConnect => 'CONECTAR';

  @override
  String get sideStandalone => 'STANDALONE';

  @override
  String get sidePcLink => 'PC LINK';

  @override
  String get sideScreenOn => 'TELA ATIVA';

  @override
  String get sideScreenAuto => 'TELA AUTO';

  @override
  String get sideEditPanel => 'EDITAR PAINEL';

  @override
  String get sideDone => 'CONCLUIR';

  @override
  String get sideAddBlock => '+ BLOCO';

  @override
  String get blueprintHeader => 'BLUEPRINT';

  @override
  String get connectionHeader => 'SUBSPACE LINK • PAREAMENTO';

  @override
  String get scanQrButton => 'LER QR CODE';

  @override
  String get usbModeButton => 'MODO USB (127.0.0.1)';

  @override
  String get testingUsbButton => 'TESTANDO USB...';

  @override
  String get discoveredAgentsTitle => 'AGENTES DESCOBERTOS NA REDE (mDNS)';

  @override
  String get searchingMdns =>
      'PROCURANDO _scifideck-agent._tcp NA REDE LOCAL...';

  @override
  String get manualConnectionTitle => 'CONEXÃO MANUAL / PIN DE 6 DÍGITOS';

  @override
  String get usbPinNotice =>
      'IMPORTANTE: MESMO NO MODO USB (127.0.0.1), O PIN DE 6 DÍGITOS EXIBIDO NO DESKTOP AGENT É OBRIGATÓRIO PARA AUTORIZAR O DISPOSITIVO.';

  @override
  String get ipAddressLabel => 'ENDEREÇO IP';

  @override
  String get portLabel => 'PORTA';

  @override
  String get pinLabel => 'PIN TEMPORÁRIO (6 DÍGITOS — OBRIGATÓRIO)';

  @override
  String get authorizeConnectButton => 'AUTORIZAR E CONECTAR';

  @override
  String get connectingButton => 'CONECTANDO...';

  @override
  String get qrScannerHeader => 'ESCANEAR QR CODE DO DESKTOP AGENT';

  @override
  String get invalidIpOrPinError =>
      'Informe um IP válido e um PIN de 6 dígitos.';

  @override
  String usbTunnelChecking(String host, int port) {
    return 'VERIFICANDO TÚNEL USB EM $host:$port...';
  }

  @override
  String get usbTunnelActiveConnecting => 'TÚNEL USB ATIVO! CONECTANDO...';

  @override
  String usbTunnelActiveEnterPin(String host, int port) {
    return 'TÚNEL USB ATIVO EM $host:$port! MESMO VIA USB, DIGITE O PIN DE 6 DÍGITOS DO DESKTOP AGENT ABAIXO E TOQUE EM AUTORIZAR.';
  }

  @override
  String usbTunnelNotFound(String host, int port) {
    return 'Túnel USB não detectado em $host:$port. No PC, execute:\nadb reverse tcp:$port tcp:$port';
  }

  @override
  String get dialogNewBlockTitle => 'BLUEPRINT • NOVO BLOCO';

  @override
  String get dialogEditBlockTitle => 'BLUEPRINT • EDITAR BLOCO';

  @override
  String get fieldBlockType => 'TIPO DE BLOCO';

  @override
  String get blockTypePcAction => 'Ação do PC (Execução Remota)';

  @override
  String get blockTypeLocalApp => 'App do Dispositivo (Abrir App Local)';

  @override
  String get blockTypeLocalControl =>
      'Controle do Dispositivo (Brilho/Volume/BT)';

  @override
  String get blockTypeInfo => 'Painel de Informação (PC / Local)';

  @override
  String get blockTypeHttpJson => 'Painel HTTP / REST (JSON)';

  @override
  String get fieldPcAction => 'AÇÃO SINCRONIZADA DO PC';

  @override
  String get fieldInstalledApp => 'APLICATIVO INSTALADO';

  @override
  String get loadingApps => 'CARREGANDO APPS INSTALADOS...';

  @override
  String get fieldDeviceControl => 'CONTROLE DO DISPOSITIVO';

  @override
  String get fieldDataSource => 'FONTE DE DADOS';

  @override
  String get sourcePcTelemetry => 'Telemetria / Comandos do PC';

  @override
  String get sourceLocalDevice => 'Sensor Local do Tablet';

  @override
  String get fieldMetric => 'MÉTRICA';

  @override
  String get metricPcCpu => 'PC: Uso de CPU (%)';

  @override
  String get metricPcRamFree => 'PC: RAM Livre (GB)';

  @override
  String get metricPcTemp => 'PC: Temperatura CPU (°C)';

  @override
  String get metricLocalClock => 'Local: Data/Hora';

  @override
  String get metricLocalStardate => 'Local: Data Estelar (Stardate)';

  @override
  String get metricLocalBattery => 'Local: Nível de Bateria';

  @override
  String get fieldHttpUrl => 'URL REST (GET JSON)';

  @override
  String get fieldHttpPath => 'CAMINHO DA PROPRIEDADE JSON';

  @override
  String get fieldHttpPrefix => 'PREFIXO';

  @override
  String get fieldHttpSuffix => 'SUFIXO';

  @override
  String get testRequestButton => 'TESTAR REQUISIÇÃO';

  @override
  String get testingRequestButton => 'TESTANDO...';

  @override
  String get fieldPanelLabel => 'RÓTULO NO PAINEL';

  @override
  String get fieldLcarsColor => 'COR DO PAINEL';

  @override
  String get btnRemove => 'REMOVER';

  @override
  String get btnCancel => 'CANCELAR';

  @override
  String get btnSaveSync => 'SALVAR E SINCRONIZAR';

  @override
  String get tapToRefresh => 'TOQUE P/ ATUALIZAR';

  @override
  String get waiting => 'AGUARDANDO...';

  @override
  String get ctrlVolumeUp => 'Volume +';

  @override
  String get ctrlVolumeDown => 'Volume -';

  @override
  String get ctrlVolumeMute => 'Mudo / Som';

  @override
  String get ctrlBrightnessUp => 'Brilho +';

  @override
  String get ctrlBrightnessDown => 'Brilho -';

  @override
  String get ctrlBrightnessAuto => 'Brilho Auto';

  @override
  String get ctrlBluetooth => 'Bluetooth (Ligar / Painel)';

  @override
  String get ctrlWifiPanel => 'Wi-Fi / Internet (Painel)';

  @override
  String get fieldDisplayFormat => 'ESTILO DE EXIBIÇÃO';

  @override
  String get formatBar => 'Barra Segmentada';

  @override
  String get formatSparkline => 'Gráfico de Linha (Sparkline)';

  @override
  String get formatGauge => 'Medidor Radial (Gauge)';

  @override
  String get formatValue => 'Somente Numérico';

  @override
  String get sideAlarmMute => 'SILENCIAR';

  @override
  String get sideAlarmUnmute => 'SOM ALERTA';

  @override
  String get fieldAlarmMode => 'MODO DE ALARME (RED ALERT)';

  @override
  String get alarmNone => 'Desativado';

  @override
  String get alarmVisual => 'Visual (Luzes Vermelhas)';

  @override
  String get alarmSound => 'Sonoro (Klaxon Red Alert)';

  @override
  String get alarmBoth => 'Visual + Sonoro';

  @override
  String get fieldAlarmMin => 'MÍNIMO (≤)';

  @override
  String get fieldAlarmMax => 'MÁXIMO (≥)';

  @override
  String get sideBackup => 'BACKUP';

  @override
  String get backupDialogTitle => 'BACKUP & RESTAURAÇÃO';

  @override
  String get btnExportFile => 'SALVAR ARQUIVO .JSON';

  @override
  String get btnCopyJson => 'COPIAR JSON';

  @override
  String get btnImportFile => 'ABRIR ARQUIVO .JSON';

  @override
  String get btnPushPc => 'ENVIAR P/ PC';

  @override
  String get btnPullPc => 'RESTAURAR DO PC';

  @override
  String get fieldPasteBackupJson => 'OU COLE O JSON DE BACKUP';

  @override
  String get btnRestoreJsonText => 'RESTAURAR DO TEXTO';

  @override
  String get backupSavedOk => 'Arquivo de backup salvo com sucesso!';

  @override
  String get backupCancelled => 'Exportação cancelada.';

  @override
  String get backupCopiedOk =>
      'JSON de backup copiado para a área de transferência!';

  @override
  String get backupRestoredOk => 'Backup restaurado com sucesso!';

  @override
  String get backupInvalidError => 'JSON de backup inválido';

  @override
  String get backupPushedPc => 'Backup enviado para o PC!';

  @override
  String get backupPulledPc => 'Solicitando backup salvo no PC...';
}
