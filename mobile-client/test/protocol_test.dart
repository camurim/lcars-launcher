import 'package:flutter_test/flutter_test.dart';
import 'package:lcars_mobile_client/protocol/lcars_protocol.dart';

void main() {
  group('LCARS Protocol Serialization', () {
    test('ProtocolEnvelope serializa e desserializa corretamente', () {
      final env = ProtocolEnvelope(
        type: 'EXECUTE_ACTION',
        timestamp: DateTime.utc(2026, 11, 27, 11, 20),
        reqId: 'a7f1c2d3-4e5f-4a6b-8c7d-9e0f1a2b3c4d',
        token: 'lcars_tok_live_1234567890abcdef',
        payload: {'action_id': 'act_open_vscode'},
      );

      final decoded = ProtocolEnvelope.fromJson(env.toJson());
      expect(decoded.version, '1.0');
      expect(decoded.type, 'EXECUTE_ACTION');
      expect(decoded.reqId, 'a7f1c2d3-4e5f-4a6b-8c7d-9e0f1a2b3c4d');
      expect(decoded.payload['action_id'], 'act_open_vscode');
    });

    test('PairingQrPayload analisa JSON {ip, port, pin}', () {
      final qr = PairingQrPayload.parse(
        '{"ip":"192.168.1.42","port":8765,"pin":"472905"}',
      );
      expect(qr.ip, '192.168.1.42');
      expect(qr.port, 8765);
      expect(qr.pin, '472905');
    });

    test('TelemetryData extrai CPU, RAM livre, temperatura e discos', () {
      final data = TelemetryData.fromPayload({
        'interval_ms': 750,
        'cpu': {'usage_percent': 38.5},
        'memory': {
          'total_bytes': 17179869184,
          'free_bytes': 8589934592,
          'used_bytes': 8589934592,
          'usage_percent': 50.0,
        },
        'temperature': {'cpu_celsius': 58.0},
        'network': {
          'interface': 'enp4s0',
          'rx_bytes_per_sec': 102400,
          'tx_bytes_per_sec': 20480,
        },
        'disks': [
          {
            'name': '/dev/nvme0n1p2',
            'mount_point': '/',
            'total_bytes': 500000000000,
            'available_bytes': 250000000000,
            'used_bytes': 250000000000,
            'usage_percent': 50.0,
          }
        ],
      });

      expect(data.cpuPercent, 38.5);
      expect(data.memoryFreeGb, closeTo(8.0, 0.01));
      expect(data.cpuTempCelsius, 58.0);
      expect(data.disks.length, 1);
      expect(data.disks.first.mountPoint, '/');
    });

    test('LcarsLayoutConfig realiza roundtrip LAYOUT_SYNC', () {
      const layout = LcarsLayoutConfig(
        layoutVersion: 3,
        profileName: 'BRIDGE OPS',
        blocks: [
          LcarsBlockConfig(
            id: 'blk_1',
            blockType: LcarsBlockType.action,
            label: 'VS CODE',
            colorToken: 'amber',
            actionId: 'act_open_vscode',
          ),
          LcarsBlockConfig(
            id: 'blk_2',
            blockType: LcarsBlockType.info,
            label: 'STARDATE',
            colorToken: 'lavender',
            source: InfoSource.localDevice,
            metricKey: 'stardate',
          ),
        ],
      );

      final payload = layout.toLayoutSyncPayload(direction: 'push');
      final restored = LcarsLayoutConfig.fromLayoutSyncPayload(payload);

      expect(restored.layoutVersion, 3);
      expect(restored.profileName, 'BRIDGE OPS');
      expect(restored.blocks.length, 2);
      expect(restored.blocks[0].actionId, 'act_open_vscode');
      expect(restored.blocks[1].source, InfoSource.localDevice);
      expect(restored.blocks[1].metricKey, 'stardate');
    });
  });
}
