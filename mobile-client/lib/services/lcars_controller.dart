import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../protocol/lcars_protocol.dart';
import 'http_panel_service.dart';
import 'lcars_feedback.dart';
import 'lcars_transport.dart';
import 'local_device_service.dart';

/// Controlador principal de estado do Mobile Client LCARS:
/// gerencia transporte, reconexão automática, sensores locais, layout e feedback.
class LcarsController extends ChangeNotifier {
  static const _kTokenKey = 'lcars_auth_token';
  static const _kEndpointKey = 'lcars_last_endpoint';
  static const _kDeviceIdKey = 'lcars_device_id';
  static const _kLayoutKey = 'lcars_saved_layout_v1';
  static const _kKeepScreenOnKey = 'lcars_keep_screen_on';
  static const _kStandaloneModeKey = 'lcars_standalone_mode';
  static const List<int> _reconnectBackoffSeconds = [4, 10, 20, 40, 60];

  final LcarsTransport transport;
  final LcarsFeedback feedback;
  LocalDeviceService? _localDevice;
  HttpPanelService? _httpPanelService;
  final FlutterSecureStorage _secureStorage;
  final Battery _battery;
  final Uuid _uuid = const Uuid();

  LocalDeviceService get localDevice => _localDevice ??= LocalDeviceService();
  HttpPanelService get httpPanelService =>
      _httpPanelService ??= HttpPanelService();

  LcarsConnectionStatus status = LcarsConnectionStatus.standbyOffline;
  TelemetryData telemetry = TelemetryData.empty;
  List<ActionDescriptor> availableActions = const [
    ActionDescriptor(
      id: 'act_open_vscode',
      name: 'VS CODE',
      category: 'apps',
      commandType: 'app_launch',
      colorToken: 'amber',
    ),
    ActionDescriptor(
      id: 'act_open_terminal',
      name: 'TERMINAL',
      category: 'apps',
      commandType: 'app_launch',
      colorToken: 'peach',
    ),
    ActionDescriptor(
      id: 'act_open_docs',
      name: 'LCARS DOCS',
      category: 'web',
      commandType: 'app_launch',
      colorToken: 'cyan',
    ),
  ];

  LcarsLayoutConfig layout = const LcarsLayoutConfig(
    layoutVersion: 1,
    profileName: 'OPS DECK 01',
    blocks: [
      LcarsBlockConfig(
        id: 'blk_cpu',
        blockType: LcarsBlockType.info,
        label: 'PC CPU LOAD',
        colorToken: 'cyan',
        source: InfoSource.pcTelemetry,
        metricKey: 'cpu.usage_percent',
      ),
      LcarsBlockConfig(
        id: 'blk_ram',
        blockType: LcarsBlockType.info,
        label: 'PC RAM FREE',
        colorToken: 'lavender',
        source: InfoSource.pcTelemetry,
        metricKey: 'memory.free_gb',
      ),
      LcarsBlockConfig(
        id: 'blk_temp',
        blockType: LcarsBlockType.info,
        label: 'CORE TEMP',
        colorToken: 'gold',
        source: InfoSource.pcTelemetry,
        metricKey: 'temperature.cpu_celsius',
      ),
      LcarsBlockConfig(
        id: 'blk_vscode',
        blockType: LcarsBlockType.action,
        label: 'VS CODE',
        colorToken: 'amber',
        actionId: 'act_open_vscode',
      ),
      LcarsBlockConfig(
        id: 'blk_terminal',
        blockType: LcarsBlockType.action,
        label: 'TERMINAL',
        colorToken: 'peach',
        actionId: 'act_open_terminal',
      ),
      LcarsBlockConfig(
        id: 'blk_stardate',
        blockType: LcarsBlockType.info,
        label: 'STARDATE',
        colorToken: 'lavender',
        source: InfoSource.localDevice,
        metricKey: 'stardate',
      ),
      LcarsBlockConfig(
        id: 'blk_clock',
        blockType: LcarsBlockType.info,
        label: 'SHIP TIME',
        colorToken: 'cyan',
        source: InfoSource.localDevice,
        metricKey: 'clock',
      ),
      LcarsBlockConfig(
        id: 'blk_battery',
        blockType: LcarsBlockType.info,
        label: 'TABLET POWER',
        colorToken: 'gold',
        source: InfoSource.localDevice,
        metricKey: 'battery_level',
      ),
    ],
  );

  bool blueprintMode = false;
  bool keepScreenOn = true;
  bool standaloneMode = false;
  int _reconnectAttempts = 0;
  int batteryLevel = 100;
  DateTime now = DateTime.now();
  String statusLog = 'STANDBY / OFFLINE — CONECTE A UM DESKTOP AGENT';
  String? _authToken;
  Uri? _lastEndpoint;
  String? _deviceId;
  String? confirmedActionId;
  final Map<String, String> commandOutputs = {};
  final Map<String, String> httpOutputs = {};
  final Map<String, List<double>> _metricHistory = {};
  static const int _maxHistorySamples = 30;

  final Set<String> activeAlarmBlockIds = {};
  bool hasVisualAlarm = false;
  bool hasSoundAlarm = false;
  bool alarmMuted = false;
  DateTime? _lastAlarmSoundAt;

  bool get hasAnyAlarm => activeAlarmBlockIds.isNotEmpty;

  void toggleAlarmMute() {
    alarmMuted = !alarmMuted;
    unawaited(feedback.playTap());
    notifyListeners();
  }

  double? _numericValueForBlock(LcarsBlockConfig blk) {
    if (blk.source == InfoSource.pcTelemetry && !isPcOnline) return null;
    return switch (blk.metricKey) {
      'cpu.usage_percent' => telemetry.cpuPercent,
      'memory.free_gb' => telemetry.memoryFreeGb,
      'temperature.cpu_celsius' => telemetry.cpuTempCelsius,
      'battery_level' => batteryLevel.toDouble(),
      _ => null,
    };
  }

  void _evaluateAlarms() {
    activeAlarmBlockIds.clear();
    var visual = false;
    var sound = false;

    for (final blk in layout.blocks) {
      if (blk.blockType != LcarsBlockType.info || blk.alarmMode == 'none') {
        continue;
      }
      final val = _numericValueForBlock(blk);
      if (val == null) continue;
      final hitMin = blk.alarmMin != null && val <= blk.alarmMin!;
      final hitMax = blk.alarmMax != null && val >= blk.alarmMax!;
      if (hitMin || hitMax) {
        activeAlarmBlockIds.add(blk.id);
        if (blk.alarmMode == 'visual' || blk.alarmMode == 'both') {
          visual = true;
        }
        if (blk.alarmMode == 'sound' || blk.alarmMode == 'both') {
          sound = true;
        }
      }
    }

    hasVisualAlarm = visual;
    hasSoundAlarm = sound;

    if (activeAlarmBlockIds.isEmpty) {
      alarmMuted = false;
      return;
    }

    if (hasSoundAlarm && !alarmMuted) {
      final current = DateTime.now();
      if (_lastAlarmSoundAt == null ||
          current.difference(_lastAlarmSoundAt!) >=
              const Duration(seconds: 3)) {
        _lastAlarmSoundAt = current;
        unawaited(feedback.playRedAlert());
      }
    }
  }

  List<double> historyFor(String? metricKey) {
    if (metricKey == null) return const [];
    return _metricHistory[metricKey] ?? const [];
  }

  void _pushHistory(String key, double normalizedValue) {
    final list = _metricHistory.putIfAbsent(key, () => <double>[]);
    list.add(normalizedValue.clamp(0.0, 1.0));
    if (list.length > _maxHistorySamples) {
      list.removeAt(0);
    }
  }

  StreamSubscription<ProtocolEnvelope>? _msgSub;
  StreamSubscription<LcarsConnectionStatus>? _statusSub;
  Timer? _clockTimer;
  Timer? _commandPollTimer;
  Timer? _httpPollTimer;
  Timer? _reconnectTimer;

  LcarsController({
    LcarsTransport? transport,
    LcarsFeedback? feedback,
    LocalDeviceService? localDevice,
    HttpPanelService? httpPanelService,
    FlutterSecureStorage? secureStorage,
    Battery? battery,
  })  : transport = transport ?? WebSocketLcarsTransport(),
        feedback = feedback ?? LcarsFeedback(),
        _localDevice = localDevice,
        _httpPanelService = httpPanelService,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _battery = battery ?? Battery();

  bool get isPcOnline => status == LcarsConnectionStatus.connected;

  String get stardateFormatted {
    final yearOffset = (now.year - 2000) * 1000.0;
    final dayOfYear =
        now.difference(DateTime(now.year, 1, 1)).inDays.toDouble();
    final fraction = (dayOfYear / 365.25) * 1000.0;
    return (yearOffset + fraction).toStringAsFixed(1);
  }

  String get clockFormatted {
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<void> initialize() async {
    await _loadLocalLayout();
    await _loadPreferences();
    await _loadSecureCredentials();

    _msgSub = transport.messages.listen(_handleMessage);
    _statusSub = transport.statusStream.listen((newStatus) {
      if (standaloneMode &&
          newStatus == LcarsConnectionStatus.standbyOffline) {
        status = LcarsConnectionStatus.disconnected;
        notifyListeners();
        return;
      }
      final wasOnline = status == LcarsConnectionStatus.connected;
      status = newStatus;
      if (newStatus == LcarsConnectionStatus.standbyOffline) {
        if (wasOnline || _reconnectAttempts == 0) {
          statusLog = 'CONEXÃO PERDIDA — STANDBY / OFFLINE (RECONECTANDO...)';
        }
        _scheduleReconnect();
      } else if (newStatus == LcarsConnectionStatus.connected) {
        _reconnectAttempts = 0;
      }
      notifyListeners();
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      now = DateTime.now();
      try {
        batteryLevel = await _battery.batteryLevel;
        if (now.second % 5 == 0 ||
            (_metricHistory['battery_level']?.isEmpty ?? true)) {
          _pushHistory('battery_level', batteryLevel / 100.0);
        }
      } catch (_) {}
      _evaluateAlarms();
      notifyListeners();
    });

    _commandPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (isPcOnline && !standaloneMode) {
        unawaited(refreshCommandPanels());
      }
    });

    _httpPollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(refreshHttpPanels());
    });
    unawaited(refreshHttpPanels());

    if (standaloneMode) {
      status = LcarsConnectionStatus.disconnected;
      statusLog = 'MODO STANDALONE ATIVO — OPERAÇÃO LOCAL';
      notifyListeners();
    } else if (_lastEndpoint != null && _authToken != null) {
      unawaited(connectWithSavedToken(_lastEndpoint!));
    }
  }

  Future<void> _loadSecureCredentials() async {
    try {
      _authToken = await _secureStorage.read(key: _kTokenKey);
      _deviceId = await _secureStorage.read(key: _kDeviceIdKey);
      if (_deviceId == null) {
        _deviceId = _uuid.v4();
        await _secureStorage.write(key: _kDeviceIdKey, value: _deviceId);
      }
      final savedEndpoint = await _secureStorage.read(key: _kEndpointKey);
      if (savedEndpoint != null) {
        _lastEndpoint = Uri.tryParse(savedEndpoint);
      }
    } catch (_) {
      _deviceId ??= _uuid.v4();
    }
  }

  Future<void> _loadLocalLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLayoutKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        layout = LcarsLayoutConfig.fromLayoutSyncPayload(decoded);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveLocalLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kLayoutKey,
        jsonEncode(layout.toLayoutSyncPayload()),
      );
    } catch (_) {}
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      keepScreenOn = prefs.getBool(_kKeepScreenOnKey) ?? true;
      standaloneMode = prefs.getBool(_kStandaloneModeKey) ?? false;
    } catch (_) {
      keepScreenOn = true;
      standaloneMode = false;
    }
    await _applyWakelock();
    notifyListeners();
  }

  Future<void> toggleStandaloneMode() async {
    standaloneMode = !standaloneMode;
    unawaited(feedback.playTap());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kStandaloneModeKey, standaloneMode);
    } catch (_) {}

    if (standaloneMode) {
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      await transport.disconnect();
      status = LcarsConnectionStatus.disconnected;
      statusLog = 'MODO STANDALONE ATIVO — SEM CONEXÃO COM PC';
      notifyListeners();
    } else {
      _reconnectAttempts = 0;
      statusLog = 'PC LINK REATIVADO';
      notifyListeners();
      if (_lastEndpoint != null && _authToken != null) {
        unawaited(connectWithSavedToken(_lastEndpoint!));
      }
    }
  }

  Future<void> _applyWakelock() async {
    try {
      await WakelockPlus.toggle(enable: keepScreenOn);
    } catch (_) {
      // Ignora em ambiente de testes sem platform channel.
    }
  }

  Future<void> toggleKeepScreenOn() async {
    keepScreenOn = !keepScreenOn;
    unawaited(feedback.playTap());
    await _applyWakelock();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kKeepScreenOnKey, keepScreenOn);
    } catch (_) {}
    statusLog = keepScreenOn
        ? 'MANTER TELA LIGADA: ATIVADO'
        : 'MANTER TELA LIGADA: DESATIVADO (AUTO)';
    notifyListeners();
  }

  Future<void> connectAndPair({
    required Uri endpoint,
    required String pin,
    String deviceName = 'LCARS Tablet Console',
  }) async {
    standaloneMode = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kStandaloneModeKey, false);
    } catch (_) {}
    _lastEndpoint = endpoint;
    statusLog = 'CONECTANDO A ${endpoint.host}:${endpoint.port}...';
    notifyListeners();

    await transport.connect(endpoint);
    await transport.send(
      ProtocolEnvelope(
        type: 'PAIR_REQUEST',
        timestamp: DateTime.now(),
        reqId: _uuid.v4(),
        payload: {
          'method': 'pin',
          'pin': pin,
          'device_id': _deviceId ?? _uuid.v4(),
          'device_name': deviceName,
          'platform': 'android',
          'app_version': '0.1.0',
        },
      ),
    );
  }

  Future<void> connectWithSavedToken(Uri endpoint) async {
    _lastEndpoint = endpoint;
    try {
      await transport.connect(endpoint);
      if (_authToken != null) {
        await transport.send(
          ProtocolEnvelope(
            type: 'CAPABILITIES_SYNC',
            timestamp: DateTime.now(),
            reqId: _uuid.v4(),
            token: _authToken,
            payload: const {},
          ),
        );
      }
      statusLog = 'RECONECTADO A ${endpoint.host}:${endpoint.port}';
      notifyListeners();
    } catch (_) {
      status = LcarsConnectionStatus.standbyOffline;
      _scheduleReconnect();
      notifyListeners();
    }
  }

  void _scheduleReconnect() {
    if (standaloneMode || _lastEndpoint == null || _authToken == null) return;
    _reconnectTimer?.cancel();
    final idx = _reconnectAttempts.clamp(0, _reconnectBackoffSeconds.length - 1);
    final delaySec = _reconnectBackoffSeconds[idx];
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!standaloneMode &&
          status != LcarsConnectionStatus.connected &&
          _lastEndpoint != null) {
        unawaited(connectWithSavedToken(_lastEndpoint!));
      }
    });
  }

  Future<void> executeAction(String actionId, {bool silent = false}) async {
    if (!silent) {
      await feedback.playTap();
    }

    // Ações locais do próprio dispositivo funcionam mesmo com o PC offline
    if (actionId.startsWith('local_app:') ||
        actionId.startsWith('local_ctrl:')) {
      try {
        final msg = actionId.startsWith('local_app:')
            ? await localDevice.launchApp(actionId.substring('local_app:'.length))
            : await localDevice.runControl(actionId.substring('local_ctrl:'.length));
        confirmedActionId = actionId;
        statusLog = 'DISPOSITIVO: $msg';
        if (!silent) unawaited(feedback.playConfirm());
        notifyListeners();
        Timer(const Duration(milliseconds: 700), () {
          if (confirmedActionId == actionId) {
            confirmedActionId = null;
            notifyListeners();
          }
        });
      } catch (err) {
        statusLog = 'ERRO LOCAL: $err';
        if (!silent) unawaited(feedback.playError());
        notifyListeners();
      }
      return;
    }

    if (!isPcOnline) {
      if (!silent) {
        await feedback.playError();
        statusLog = 'PC OFFLINE — AÇÃO $actionId NÃO ENVIADA';
        notifyListeners();
      }
      return;
    }

    await transport.send(
      ProtocolEnvelope(
        type: 'EXECUTE_ACTION',
        timestamp: DateTime.now(),
        reqId: _uuid.v4(),
        token: _authToken,
        payload: {'action_id': actionId},
      ),
    );
    if (!silent) {
      statusLog = 'DISPARANDO $actionId...';
      notifyListeners();
    }
  }

  /// Atualiza todos os painéis de informação vinculados à saída de comandos `shell` (`cmd:<action_id>`).
  Future<void> refreshCommandPanels() async {
    if (!isPcOnline) return;
    for (final blk in layout.blocks) {
      if (blk.blockType == LcarsBlockType.info &&
          blk.metricKey != null &&
          blk.metricKey!.startsWith('cmd:')) {
        final actionId = blk.metricKey!.substring(4);
        await executeAction(actionId, silent: true);
      }
    }
  }

  /// Atualiza todos os painéis HTTP/REST (`http:{...}`) de forma independente do PC.
  Future<void> refreshHttpPanels() async {
    for (final blk in layout.blocks) {
      if (blk.blockType == LcarsBlockType.info &&
          (blk.metricKey?.startsWith('http:') ?? false)) {
        await refreshSingleHttpPanel(blk, silent: true);
      }
    }
  }

  Future<void> refreshSingleHttpPanel(
    LcarsBlockConfig blk, {
    bool silent = false,
  }) async {
    final cfg = HttpPanelConfig.tryParseMetricKey(blk.metricKey);
    if (cfg == null) return;
    if (!silent) {
      unawaited(feedback.playTap());
      httpOutputs[blk.id] = 'CARREGANDO...';
      notifyListeners();
    }
    try {
      final value = await httpPanelService.fetchValue(cfg);
      httpOutputs[blk.id] = value;
      if (!silent) {
        statusLog = 'HTTP [${blk.label}]: $value';
        unawaited(feedback.playConfirm());
      }
    } catch (err) {
      httpOutputs[blk.id] = 'ERRO HTTP';
      if (!silent) {
        statusLog = 'ERRO HTTP [${blk.label}]: $err';
        unawaited(feedback.playError());
      }
    }
    notifyListeners();
  }

  void toggleBlueprintMode() {
    blueprintMode = !blueprintMode;
    unawaited(feedback.playTap());
    notifyListeners();
  }

  Future<void> addOrUpdateBlock(LcarsBlockConfig block) async {
    final updated = List<LcarsBlockConfig>.from(layout.blocks);
    final idx = updated.indexWhere((b) => b.id == block.id);
    if (idx >= 0) {
      updated[idx] = block;
    } else {
      updated.add(block);
    }
    await _commitLayout(updated);
    if (block.blockType == LcarsBlockType.info &&
        block.metricKey != null &&
        block.metricKey!.startsWith('cmd:') &&
        isPcOnline) {
      unawaited(executeAction(block.metricKey!.substring(4), silent: true));
    } else if (block.blockType == LcarsBlockType.info &&
        (block.metricKey?.startsWith('http:') ?? false)) {
      unawaited(refreshSingleHttpPanel(block, silent: true));
    }
  }

  Future<void> removeBlock(String blockId) async {
    final updated = layout.blocks.where((b) => b.id != blockId).toList();
    await _commitLayout(updated);
  }

  Future<void> reorderBlock(int fromIndex, int toIndex) async {
    final blocks = layout.blocks;
    if (fromIndex < 0 ||
        fromIndex >= blocks.length ||
        toIndex < 0 ||
        toIndex >= blocks.length ||
        fromIndex == toIndex) {
      return;
    }
    unawaited(feedback.playTap());
    final updated = List<LcarsBlockConfig>.from(blocks);
    final moved = updated.removeAt(fromIndex);
    updated.insert(toIndex, moved);
    await _commitLayout(updated);
  }

  Future<void> moveBlockByDelta(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= layout.blocks.length) return;
    await reorderBlock(index, target);
  }

  /// Exporta layout completo, alarmes, gráficos, HTTP panels e preferências em JSON legível.
  String exportBackupJson() {
    final data = {
      'schema': 'lcars_mobile_backup_v1',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'preferences': {
        'keep_screen_on': keepScreenOn,
        'standalone_mode': standaloneMode,
      },
      'layout': layout.toLayoutSyncPayload(direction: 'push'),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Importa backup JSON (aceita `lcars_mobile_backup_v1` ou payload direto de `LAYOUT_SYNC`).
  Future<void> importBackupJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Formato JSON inválido');
    }

    final Map<String, dynamic> layoutMap;
    if (decoded['layout'] is Map) {
      layoutMap = Map<String, dynamic>.from(decoded['layout'] as Map);
    } else if (decoded['pages'] is List) {
      layoutMap = decoded;
    } else {
      throw const FormatException('Backup sem definição de layout/pages');
    }

    final restoredLayout = LcarsLayoutConfig.fromLayoutSyncPayload(layoutMap);
    if (decoded['preferences'] is Map) {
      final prefsMap = Map<String, dynamic>.from(decoded['preferences'] as Map);
      if (prefsMap['keep_screen_on'] is bool) {
        keepScreenOn = prefsMap['keep_screen_on'] as bool;
        await _applyWakelock();
      }
      if (prefsMap['standalone_mode'] is bool) {
        standaloneMode = prefsMap['standalone_mode'] as bool;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kKeepScreenOnKey, keepScreenOn);
        await prefs.setBool(_kStandaloneModeKey, standaloneMode);
      } catch (_) {}
    }

    layout = LcarsLayoutConfig(
      layoutVersion: restoredLayout.layoutVersion + 1,
      profileName: restoredLayout.profileName,
      blocks: restoredLayout.blocks,
    );
    _evaluateAlarms();
    notifyListeners();
    await _saveLocalLayout();

    if (isPcOnline && _authToken != null) {
      await pushLayoutBackupToPc();
    }
    unawaited(refreshHttpPanels());
    unawaited(refreshCommandPanels());
    statusLog = 'BACKUP RESTAURADO (${layout.blocks.length} BLOCOS)';
    unawaited(feedback.playConfirm());
    notifyListeners();
  }

  Future<void> pushLayoutBackupToPc() async {
    if (!isPcOnline || _authToken == null) return;
    await transport.send(
      ProtocolEnvelope(
        type: 'LAYOUT_SYNC',
        timestamp: DateTime.now(),
        reqId: _uuid.v4(),
        token: _authToken,
        payload: layout.toLayoutSyncPayload(direction: 'push'),
      ),
    );
    statusLog = 'BACKUP ENVIADO AO PC (REV ${layout.layoutVersion})';
    notifyListeners();
  }

  Future<void> pullLayoutBackupFromPc() async {
    if (!isPcOnline || _authToken == null) return;
    await transport.send(
      ProtocolEnvelope(
        type: 'LAYOUT_SYNC',
        timestamp: DateTime.now(),
        reqId: _uuid.v4(),
        token: _authToken,
        payload: {'direction': 'pull_request'},
      ),
    );
    statusLog = 'SOLICITANDO BACKUP DO PC...';
    notifyListeners();
  }

  Future<void> _commitLayout(List<LcarsBlockConfig> updatedBlocks) async {
    layout = LcarsLayoutConfig(
      layoutVersion: layout.layoutVersion + 1,
      profileName: layout.profileName,
      blocks: updatedBlocks,
    );
    _evaluateAlarms();
    notifyListeners();
    await _saveLocalLayout();

    if (isPcOnline && _authToken != null) {
      await transport.send(
        ProtocolEnvelope(
          type: 'LAYOUT_SYNC',
          timestamp: DateTime.now(),
          reqId: _uuid.v4(),
          token: _authToken,
          payload: layout.toLayoutSyncPayload(direction: 'push'),
        ),
      );
      statusLog = 'LAYOUT SINCRONIZADO (REV ${layout.layoutVersion})';
      notifyListeners();
    }
  }

  void _handleMessage(ProtocolEnvelope env) {
    switch (env.type) {
      case 'PAIR_CONFIRM':
        if (env.payload['status'] == 'approved') {
          _authToken = env.payload['auth_token'] as String?;
          if (_authToken != null) {
            unawaited(_secureStorage.write(key: _kTokenKey, value: _authToken));
          }
          if (_lastEndpoint != null) {
            unawaited(_secureStorage.write(
              key: _kEndpointKey,
              value: _lastEndpoint.toString(),
            ));
          }
          status = LcarsConnectionStatus.connected;
          statusLog = 'PAREADO COM ${env.payload['agent_name']}';
          unawaited(feedback.playConfirm());
        } else {
          statusLog =
              'PAREAMENTO REJEITADO: ${env.payload['error_message'] ?? 'PIN INVÁLIDO'}';
          unawaited(feedback.playError());
        }
        notifyListeners();
      case 'CAPABILITIES_SYNC':
        final rawActions = env.payload['actions'] as List<dynamic>? ?? [];
        availableActions = rawActions
            .map((a) => ActionDescriptor.fromJson(
                Map<String, dynamic>.from(a as Map)))
            .toList();
        final validIds = availableActions.map((a) => a.id).toSet();
        final filteredBlocks = layout.blocks
            .where((b) =>
                !b.dependsOnPc ||
                b.blockType != LcarsBlockType.action ||
                (b.actionId != null && validIds.contains(b.actionId)))
            .toList();
        final removedCount = layout.blocks.length - filteredBlocks.length;
        if (removedCount > 0) {
          layout = LcarsLayoutConfig(
            layoutVersion: layout.layoutVersion + 1,
            profileName: layout.profileName,
            blocks: filteredBlocks,
          );
          unawaited(_saveLocalLayout());
          statusLog =
              'SINCRONIZADO: ${availableActions.length} AÇÕES ($removedCount BLOCO(S) REMOVIDO(S))';
        } else {
          statusLog = 'SINCRONIZADO: ${availableActions.length} AÇÕES DO PC';
        }
        unawaited(refreshCommandPanels());
        notifyListeners();
      case 'TELEMETRY':
        telemetry = TelemetryData.fromPayload(env.payload);
        _pushHistory('cpu.usage_percent', telemetry.cpuPercent / 100.0);
        _pushHistory('memory.free_gb', telemetry.memoryPercent / 100.0);
        if (telemetry.cpuTempCelsius != null) {
          _pushHistory(
            'temperature.cpu_celsius',
            telemetry.cpuTempCelsius! / 100.0,
          );
        }
        _evaluateAlarms();
        notifyListeners();
      case 'LAYOUT_SYNC':
        if (env.payload['direction'] == 'pull_response') {
          try {
            final restored =
                LcarsLayoutConfig.fromLayoutSyncPayload(env.payload);
            layout = restored;
            _evaluateAlarms();
            unawaited(_saveLocalLayout());
            unawaited(refreshHttpPanels());
            unawaited(refreshCommandPanels());
            statusLog =
                'BACKUP RESTAURADO DO PC (${layout.blocks.length} BLOCOS)';
            unawaited(feedback.playConfirm());
            notifyListeners();
          } catch (_) {}
        }
      case 'ACTION_RESULT':
        final ok = env.payload['status'] == 'ok';
        final actionId = env.payload['action_id'] as String?;
        final message = env.payload['message'] as String?;
        if (actionId != null && message != null) {
          commandOutputs[actionId] = message;
        }
        if (ok) {
          final isShell = availableActions
              .any((a) => a.id == actionId && a.commandType == 'shell');
          if (!isShell) {
            confirmedActionId = actionId;
            statusLog = 'CONFIRMADO: ${message ?? actionId}';
            unawaited(feedback.playConfirm());
            Timer(const Duration(milliseconds: 900), () {
              if (confirmedActionId == actionId) {
                confirmedActionId = null;
                notifyListeners();
              }
            });
          }
        } else {
          statusLog = 'FALHA: ${message ?? actionId}';
          unawaited(feedback.playError());
        }
        notifyListeners();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _commandPollTimer?.cancel();
    _httpPollTimer?.cancel();
    _reconnectTimer?.cancel();
    unawaited(_msgSub?.cancel());
    unawaited(_statusSub?.cancel());
    unawaited(transport.disconnect());
    unawaited(feedback.dispose());
    super.dispose();
  }
}
