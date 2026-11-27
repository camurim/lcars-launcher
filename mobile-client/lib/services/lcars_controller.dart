import 'dart:async';
import 'dart:convert';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../protocol/lcars_protocol.dart';
import 'lcars_feedback.dart';
import 'lcars_transport.dart';

/// Controlador principal de estado do Mobile Client LCARS:
/// gerencia transporte, reconexão automática, sensores locais, layout e feedback.
class LcarsController extends ChangeNotifier {
  static const _kTokenKey = 'lcars_auth_token';
  static const _kEndpointKey = 'lcars_last_endpoint';
  static const _kDeviceIdKey = 'lcars_device_id';
  static const _kLayoutKey = 'lcars_saved_layout_v1';
  static const _kKeepScreenOnKey = 'lcars_keep_screen_on';

  final LcarsTransport transport;
  final LcarsFeedback feedback;
  final FlutterSecureStorage _secureStorage;
  final Battery _battery;
  final Uuid _uuid = const Uuid();

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
  int batteryLevel = 100;
  DateTime now = DateTime.now();
  String statusLog = 'STANDBY / OFFLINE — CONECTE A UM DESKTOP AGENT';
  String? _authToken;
  Uri? _lastEndpoint;
  String? _deviceId;
  String? confirmedActionId;
  final Map<String, String> commandOutputs = {};

  StreamSubscription<ProtocolEnvelope>? _msgSub;
  StreamSubscription<LcarsConnectionStatus>? _statusSub;
  Timer? _clockTimer;
  Timer? _commandPollTimer;
  Timer? _reconnectTimer;

  LcarsController({
    LcarsTransport? transport,
    LcarsFeedback? feedback,
    FlutterSecureStorage? secureStorage,
    Battery? battery,
  })  : transport = transport ?? WebSocketLcarsTransport(),
        feedback = feedback ?? LcarsFeedback(),
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
    await _loadKeepScreenOnPreference();
    await _loadSecureCredentials();

    _msgSub = transport.messages.listen(_handleMessage);
    _statusSub = transport.statusStream.listen((newStatus) {
      status = newStatus;
      if (newStatus == LcarsConnectionStatus.standbyOffline) {
        statusLog = 'CONEXÃO PERDIDA — STANDBY / OFFLINE (RECONECTANDO...)';
        _scheduleReconnect();
      }
      notifyListeners();
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      now = DateTime.now();
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (_) {}
      notifyListeners();
    });

    _commandPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (isPcOnline) {
        unawaited(refreshCommandPanels());
      }
    });

    if (_lastEndpoint != null && _authToken != null) {
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

  Future<void> _loadKeepScreenOnPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      keepScreenOn = prefs.getBool(_kKeepScreenOnKey) ?? true;
    } catch (_) {
      keepScreenOn = true;
    }
    await _applyWakelock();
    notifyListeners();
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
    _reconnectTimer?.cancel();
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
    if (_lastEndpoint == null || _authToken == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (status != LcarsConnectionStatus.connected && _lastEndpoint != null) {
        unawaited(connectWithSavedToken(_lastEndpoint!));
      }
    });
  }

  Future<void> executeAction(String actionId, {bool silent = false}) async {
    if (!silent) {
      await feedback.playTap();
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
    }
  }

  Future<void> removeBlock(String blockId) async {
    final updated = layout.blocks.where((b) => b.id != blockId).toList();
    await _commitLayout(updated);
  }

  Future<void> _commitLayout(List<LcarsBlockConfig> updatedBlocks) async {
    layout = LcarsLayoutConfig(
      layoutVersion: layout.layoutVersion + 1,
      profileName: layout.profileName,
      blocks: updatedBlocks,
    );
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
        notifyListeners();
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
    _reconnectTimer?.cancel();
    unawaited(_msgSub?.cancel());
    unawaited(_statusSub?.cancel());
    unawaited(transport.disconnect());
    unawaited(feedback.dispose());
    super.dispose();
  }
}
