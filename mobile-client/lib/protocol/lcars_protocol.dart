import 'dart:convert';

const String kProtocolVersion = '1.0';

class ProtocolEnvelope {
  final String version;
  final String type;
  final DateTime timestamp;
  final String? reqId;
  final String? token;
  final Map<String, dynamic> payload;

  const ProtocolEnvelope({
    this.version = kProtocolVersion,
    required this.type,
    required this.timestamp,
    this.reqId,
    this.token,
    required this.payload,
  });

  factory ProtocolEnvelope.fromJson(Map<String, dynamic> json) {
    return ProtocolEnvelope(
      version: json['version'] as String? ?? kProtocolVersion,
      type: json['type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      reqId: json['req_id'] as String?,
      token: json['token'] as String?,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'type': type,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (reqId != null) 'req_id': reqId,
      if (token != null) 'token': token,
      'payload': payload,
    };
  }

  String encode() => jsonEncode(toJson());
}

class PairingQrPayload {
  final String ip;
  final int port;
  final String pin;

  const PairingQrPayload({
    required this.ip,
    required this.port,
    required this.pin,
  });

  factory PairingQrPayload.parse(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return PairingQrPayload(
      ip: decoded['ip'] as String,
      port: (decoded['port'] as num).toInt(),
      pin: decoded['pin'].toString(),
    );
  }
}

class ActionDescriptor {
  final String id;
  final String name;
  final String category;
  final String commandType;
  final String colorToken;
  final bool confirmRequired;

  const ActionDescriptor({
    required this.id,
    required this.name,
    required this.category,
    required this.commandType,
    this.colorToken = 'amber',
    this.confirmRequired = false,
  });

  factory ActionDescriptor.fromJson(Map<String, dynamic> json) {
    return ActionDescriptor(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      commandType: json['command_type'] as String,
      colorToken: json['color_token'] as String? ?? 'amber',
      confirmRequired: json['confirm_required'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'command_type': commandType,
        'color_token': colorToken,
        'confirm_required': confirmRequired,
      };
}

class DiskTelemetry {
  final String name;
  final String mountPoint;
  final int totalBytes;
  final int availableBytes;
  final double usagePercent;

  const DiskTelemetry({
    required this.name,
    required this.mountPoint,
    required this.totalBytes,
    required this.availableBytes,
    required this.usagePercent,
  });

  factory DiskTelemetry.fromJson(Map<String, dynamic> json) {
    return DiskTelemetry(
      name: json['name'] as String? ?? '',
      mountPoint: json['mount_point'] as String? ?? '',
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      availableBytes: (json['available_bytes'] as num?)?.toInt() ?? 0,
      usagePercent: (json['usage_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TelemetryData {
  final double cpuPercent;
  final double memoryPercent;
  final int memoryFreeBytes;
  final int memoryUsedBytes;
  final int memoryTotalBytes;
  final double? cpuTempCelsius;
  final int rxBytesPerSec;
  final int txBytesPerSec;
  final List<DiskTelemetry> disks;

  const TelemetryData({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.memoryFreeBytes,
    required this.memoryUsedBytes,
    required this.memoryTotalBytes,
    this.cpuTempCelsius,
    required this.rxBytesPerSec,
    required this.txBytesPerSec,
    this.disks = const [],
  });

  static const TelemetryData empty = TelemetryData(
    cpuPercent: 0,
    memoryPercent: 0,
    memoryFreeBytes: 0,
    memoryUsedBytes: 0,
    memoryTotalBytes: 0,
    cpuTempCelsius: null,
    rxBytesPerSec: 0,
    txBytesPerSec: 0,
  );

  double get memoryFreeGb => memoryFreeBytes / (1024 * 1024 * 1024);
  double get memoryTotalGb => memoryTotalBytes / (1024 * 1024 * 1024);

  factory TelemetryData.fromPayload(Map<String, dynamic> payload) {
    final cpu = payload['cpu'] as Map<String, dynamic>? ?? {};
    final mem = payload['memory'] as Map<String, dynamic>? ?? {};
    final temp = payload['temperature'] as Map<String, dynamic>?;
    final net = payload['network'] as Map<String, dynamic>? ?? {};
    final rawDisks = payload['disks'] as List<dynamic>? ?? [];

    return TelemetryData(
      cpuPercent: (cpu['usage_percent'] as num?)?.toDouble() ?? 0.0,
      memoryPercent: (mem['usage_percent'] as num?)?.toDouble() ?? 0.0,
      memoryFreeBytes: (mem['free_bytes'] as num?)?.toInt() ?? 0,
      memoryUsedBytes: (mem['used_bytes'] as num?)?.toInt() ?? 0,
      memoryTotalBytes: (mem['total_bytes'] as num?)?.toInt() ?? 0,
      cpuTempCelsius: (temp?['cpu_celsius'] as num?)?.toDouble(),
      rxBytesPerSec: (net['rx_bytes_per_sec'] as num?)?.toInt() ?? 0,
      txBytesPerSec: (net['tx_bytes_per_sec'] as num?)?.toInt() ?? 0,
      disks: rawDisks
          .map((d) => DiskTelemetry.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
    );
  }
}

enum LcarsBlockType { action, info }

enum InfoSource { pcTelemetry, localDevice }

class LcarsBlockConfig {
  final String id;
  final LcarsBlockType blockType;
  final String label;
  final String colorToken;
  final String? actionId;
  final InfoSource? source;
  final String? metricKey;
  final String displayFormat;
  final String alarmMode; // none | visual | sound | both
  final double? alarmMin;
  final double? alarmMax;

  const LcarsBlockConfig({
    required this.id,
    required this.blockType,
    required this.label,
    required this.colorToken,
    this.actionId,
    this.source,
    this.metricKey,
    this.displayFormat = 'bar',
    this.alarmMode = 'none',
    this.alarmMin,
    this.alarmMax,
  });

  bool get isLocalAppAction =>
      blockType == LcarsBlockType.action &&
      (actionId?.startsWith('local_app:') ?? false);

  bool get isLocalControlAction =>
      blockType == LcarsBlockType.action &&
      (actionId?.startsWith('local_ctrl:') ?? false);

  bool get isLocalAction => isLocalAppAction || isLocalControlAction;

  bool get dependsOnPc {
    if (blockType == LcarsBlockType.action) {
      return !isLocalAction;
    }
    return source == InfoSource.pcTelemetry;
  }

  LcarsBlockConfig copyWith({
    String? id,
    LcarsBlockType? blockType,
    String? label,
    String? colorToken,
    String? actionId,
    InfoSource? source,
    String? metricKey,
    String? displayFormat,
    String? alarmMode,
    double? alarmMin,
    double? alarmMax,
  }) {
    return LcarsBlockConfig(
      id: id ?? this.id,
      blockType: blockType ?? this.blockType,
      label: label ?? this.label,
      colorToken: colorToken ?? this.colorToken,
      actionId: actionId ?? this.actionId,
      source: source ?? this.source,
      metricKey: metricKey ?? this.metricKey,
      displayFormat: displayFormat ?? this.displayFormat,
      alarmMode: alarmMode ?? this.alarmMode,
      alarmMin: alarmMin ?? this.alarmMin,
      alarmMax: alarmMax ?? this.alarmMax,
    );
  }

  Map<String, dynamic> toProtocolJson(int index) {
    return {
      'id': id,
      'block_type': blockType == LcarsBlockType.action ? 'action' : 'info',
      'label': label,
      'col': index % 3,
      'row': index ~/ 3,
      'col_span': 1,
      'row_span': 1,
      'color_token': colorToken,
      if (blockType == LcarsBlockType.action && actionId != null)
        'action_id': actionId,
      if (blockType == LcarsBlockType.info && source != null)
        'source': source == InfoSource.pcTelemetry
            ? 'pc_telemetry'
            : 'local_device',
      if (blockType == LcarsBlockType.info && metricKey != null)
        'metric_key': metricKey,
      if (blockType == LcarsBlockType.info) 'display_format': displayFormat,
      if (blockType == LcarsBlockType.info && alarmMode != 'none')
        'alarm_mode': alarmMode,
      if (blockType == LcarsBlockType.info && alarmMin != null)
        'alarm_min': alarmMin,
      if (blockType == LcarsBlockType.info && alarmMax != null)
        'alarm_max': alarmMax,
    };
  }

  factory LcarsBlockConfig.fromProtocolJson(Map<String, dynamic> json) {
    final isAction = json['block_type'] == 'action';
    return LcarsBlockConfig(
      id: json['id'] as String,
      blockType: isAction ? LcarsBlockType.action : LcarsBlockType.info,
      label: json['label'] as String,
      colorToken: json['color_token'] as String? ?? 'amber',
      actionId: json['action_id'] as String?,
      source: json['source'] == null
          ? null
          : (json['source'] == 'pc_telemetry'
              ? InfoSource.pcTelemetry
              : InfoSource.localDevice),
      metricKey: json['metric_key'] as String?,
      displayFormat: json['display_format'] as String? ?? 'bar',
      alarmMode: json['alarm_mode'] as String? ?? 'none',
      alarmMin: (json['alarm_min'] as num?)?.toDouble(),
      alarmMax: (json['alarm_max'] as num?)?.toDouble(),
    );
  }
}

class LcarsLayoutConfig {
  final int layoutVersion;
  final String profileName;
  final List<LcarsBlockConfig> blocks;

  const LcarsLayoutConfig({
    required this.layoutVersion,
    required this.profileName,
    required this.blocks,
  });

  Map<String, dynamic> toLayoutSyncPayload({String direction = 'push'}) {
    return {
      'direction': direction,
      'layout_version': layoutVersion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'profile_name': profileName,
      'grid': {
        'columns': 3,
        'rows': 3,
        'orientation': 'landscape',
      },
      'pages': [
        {
          'id': 'page_main',
          'title': 'OPS DECK 01',
          'accent_color': 'amber',
          'blocks': [
            for (var i = 0; i < blocks.length; i++) blocks[i].toProtocolJson(i),
          ],
        },
      ],
    };
  }

  factory LcarsLayoutConfig.fromLayoutSyncPayload(Map<String, dynamic> json) {
    final pages = json['pages'] as List<dynamic>? ?? [];
    final firstPage = pages.isNotEmpty
        ? Map<String, dynamic>.from(pages.first as Map)
        : <String, dynamic>{};
    final rawBlocks = firstPage['blocks'] as List<dynamic>? ?? [];
    return LcarsLayoutConfig(
      layoutVersion: (json['layout_version'] as num?)?.toInt() ?? 1,
      profileName: json['profile_name'] as String? ?? 'OPS DECK 01',
      blocks: rawBlocks
          .map((b) => LcarsBlockConfig.fromProtocolJson(
              Map<String, dynamic>.from(b as Map)))
          .toList(),
    );
  }
}
