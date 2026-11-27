import 'dart:async';
import 'dart:convert';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../protocol/lcars_protocol.dart';

enum LcarsConnectionStatus {
  disconnected,
  connecting,
  connected,
  standbyOffline,
}

class DiscoveredAgent {
  final String name;
  final String host;
  final int port;

  const DiscoveredAgent({
    required this.name,
    required this.host,
    required this.port,
  });

  Uri get wsUri => Uri.parse('ws://$host:$port/ws');
}

/// Abstração multi-transporte (WebSocket Wi-Fi/USB e Bluetooth BLE).
abstract class LcarsTransport {
  String get transportName;
  Stream<ProtocolEnvelope> get messages;
  Stream<LcarsConnectionStatus> get statusStream;
  Future<void> connect(Uri endpoint);
  Future<void> send(ProtocolEnvelope envelope);
  Future<void> disconnect();
}

/// Transporte WebSocket para Wi-Fi LAN ou túnel USB (`ws://127.0.0.1:8765/ws`).
class WebSocketLcarsTransport implements LcarsTransport {
  final _msgController = StreamController<ProtocolEnvelope>.broadcast();
  final _statusController = StreamController<LcarsConnectionStatus>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  @override
  String get transportName => 'websocket';

  @override
  Stream<ProtocolEnvelope> get messages => _msgController.stream;

  @override
  Stream<LcarsConnectionStatus> get statusStream => _statusController.stream;

  @override
  Future<void> connect(Uri endpoint) async {
    await disconnect();
    _statusController.add(LcarsConnectionStatus.connecting);
    try {
      _channel = WebSocketChannel.connect(endpoint);
      await _channel!.ready;
      _statusController.add(LcarsConnectionStatus.connected);

      _sub = _channel!.stream.listen(
        (dynamic event) {
          if (event is String) {
            final decoded = jsonDecode(event) as Map<String, dynamic>;
            _msgController.add(ProtocolEnvelope.fromJson(decoded));
          }
        },
        onError: (_) {
          _statusController.add(LcarsConnectionStatus.standbyOffline);
        },
        onDone: () {
          _statusController.add(LcarsConnectionStatus.standbyOffline);
        },
      );
    } catch (_) {
      _statusController.add(LcarsConnectionStatus.standbyOffline);
      rethrow;
    }
  }

  @override
  Future<void> send(ProtocolEnvelope envelope) async {
    _channel?.sink.add(envelope.encode());
  }

  @override
  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _sub = null;
    _channel = null;
    _statusController.add(LcarsConnectionStatus.disconnected);
  }
}

/// Descoberta automática mDNS/Zeroconf via `bonsoir` para `_lcars-agent._tcp`.
class MdnsDiscoveryService {
  static const String serviceType = '_lcars-agent._tcp';
  BonsoirDiscovery? _discovery;
  final _agentsController = StreamController<List<DiscoveredAgent>>.broadcast();
  final Map<String, DiscoveredAgent> _found = {};

  Stream<List<DiscoveredAgent>> get agents => _agentsController.stream;

  Future<void> start() async {
    await stop();
    _discovery = BonsoirDiscovery(type: serviceType);
    await _discovery!.ready;
    _discovery!.eventStream?.listen((event) {
      final service = event.service;
      if (service == null) return;
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved &&
          service is ResolvedBonsoirService) {
        final host = service.host;
        if (host != null && host.isNotEmpty) {
          _found[service.name] = DiscoveredAgent(
            name: service.name,
            host: host,
            port: service.port,
          );
          _agentsController.add(_found.values.toList());
        }
      } else if (event.type ==
          BonsoirDiscoveryEventType.discoveryServiceLost) {
        _found.remove(service.name);
        _agentsController.add(_found.values.toList());
      }
    });
    await _discovery!.start();
  }

  Future<void> stop() async {
    await _discovery?.stop();
    _discovery = null;
  }
}

/// Estrutura base para transporte Bluetooth Low Energy (GATT) via `flutter_blue_plus`.
/// Utiliza os UUIDs formalizados em `/protocol/PROTOCOL.md`.
class BleLcarsTransport implements LcarsTransport {
  static final Guid serviceUuid =
      Guid('7E1A0001-4C43-4152-5300-000000000001');
  static final Guid txCharUuid =
      Guid('7E1A0002-4C43-4152-5300-000000000001');
  static final Guid rxCharUuid =
      Guid('7E1A0003-4C43-4152-5300-000000000001');

  final _msgController = StreamController<ProtocolEnvelope>.broadcast();
  final _statusController = StreamController<LcarsConnectionStatus>.broadcast();
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;

  @override
  String get transportName => 'ble_gatt';

  @override
  Stream<ProtocolEnvelope> get messages => _msgController.stream;

  @override
  Stream<LcarsConnectionStatus> get statusStream => _statusController.stream;

  Future<void> connectDevice(BluetoothDevice device) async {
    _statusController.add(LcarsConnectionStatus.connecting);
    _device = device;
    await device.connect(autoConnect: false);
    final services = await device.discoverServices();
    for (final svc in services) {
      if (svc.uuid == serviceUuid) {
        for (final ch in svc.characteristics) {
          if (ch.uuid == rxCharUuid) {
            _rxChar = ch;
          } else if (ch.uuid == txCharUuid) {
            await ch.setNotifyValue(true);
            ch.onValueReceived.listen((bytes) {
              try {
                final text = utf8.decode(bytes);
                final decoded = jsonDecode(text) as Map<String, dynamic>;
                _msgController.add(ProtocolEnvelope.fromJson(decoded));
              } catch (_) {}
            });
          }
        }
      }
    }
    _statusController.add(LcarsConnectionStatus.connected);
  }

  @override
  Future<void> connect(Uri endpoint) async {
    // Conexão BLE usa `connectDevice(BluetoothDevice)` após scan `FlutterBluePlus.startScan`.
    _statusController.add(LcarsConnectionStatus.standbyOffline);
  }

  @override
  Future<void> send(ProtocolEnvelope envelope) async {
    final rx = _rxChar;
    if (rx == null) return;
    final data = utf8.encode(envelope.encode());
    await rx.write(data, withoutResponse: rx.properties.writeWithoutResponse);
  }

  @override
  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _rxChar = null;
    _statusController.add(LcarsConnectionStatus.disconnected);
  }
}
