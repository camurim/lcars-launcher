import 'package:flutter_test/flutter_test.dart';
import 'package:lcars_mobile_client/protocol/lcars_protocol.dart';
import 'package:lcars_mobile_client/services/http_panel_service.dart';

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

    test('LcarsLayoutConfig realiza roundtrip LAYOUT_SYNC multi-página', () {
      const layout = LcarsLayoutConfig(
        layoutVersion: 3,
        profileName: 'BRIDGE OPS',
        pages: [
          LcarsPageConfig(
            id: 'page_1',
            title: 'OPS DECK 01',
            accentColor: 'amber',
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
          ),
          LcarsPageConfig(
            id: 'page_2',
            title: 'MEDIA DECK',
            accentColor: 'lavender',
            blocks: [],
          ),
        ],
      );

      final payload = layout.toLayoutSyncPayload(direction: 'push');
      final restored = LcarsLayoutConfig.fromLayoutSyncPayload(payload);

      expect(restored.layoutVersion, 3);
      expect(restored.profileName, 'BRIDGE OPS');
      expect(restored.pages.length, 2);
      expect(restored.pages[1].title, 'MEDIA DECK');
      expect(restored.blocks.length, 2);
      expect(restored.blocks[0].actionId, 'act_open_vscode');
      expect(restored.blocks[1].source, InfoSource.localDevice);
      expect(restored.blocks[1].metricKey, 'stardate');
    });

    test('HttpPanelConfig e extractJsonPath extraem propriedades aninhadas e listas', () {
      const cfg = HttpPanelConfig(
        url: 'https://economia.awesomeapi.com.br/json/last/USD-BRL',
        jsonPath: 'USDBRL.bid',
        prefix: 'R\$ ',
      );
      final key = cfg.toMetricKey();
      final parsed = HttpPanelConfig.tryParseMetricKey(key);
      expect(parsed, isNotNull);
      expect(parsed!.url, cfg.url);
      expect(parsed.jsonPath, 'USDBRL.bid');
      expect(parsed.prefix, 'R\$ ');

      final sampleJson = {
        'USDBRL': {'bid': '5.42'},
        'items': [
          {'name': 'Enterprise'},
          {'name': 'Voyager'},
        ],
      };
      expect(extractJsonPath(sampleJson, 'USDBRL.bid'), '5.42');
      expect(extractJsonPath(sampleJson, 'items.1.name'), 'Voyager');
      expect(extractJsonPath(sampleJson, 'items[0].name'), 'Enterprise');
      expect(extractJsonPath(sampleJson, 'inexistente.campo'), isNull);
    });

    test('formatJsonValue suporta caminho simples e templates {{...}}', () {
      final bibleJson = {
        'random_verse': {
          'book': 'Salmos',
          'chapter': 23,
          'verse': 1,
          'text': 'O SENHOR é o meu pastor; nada me faltará.\n',
        },
        'items': [
          {'name': 'Enterprise'},
        ],
      };

      expect(
        formatJsonValue(
          bibleJson,
          '{{random_verse.book}} {{random_verse.chapter}}:{{random_verse.verse}} - {{random_verse.text}}',
        ),
        'Salmos 23:1 - O SENHOR é o meu pastor; nada me faltará.',
      );

      expect(
        formatJsonValue(bibleJson, 'Nave: {{ items[0].name }}'),
        'Nave: Enterprise',
      );

      expect(formatJsonValue(bibleJson, 'random_verse.book'), 'Salmos');
      expect(
        formatJsonValue(bibleJson, '{{nao.existe}} - {{tampouco}}'),
        isNull,
      );
    });

    test('HttpPanelConfig serializa e restaura refreshSeconds personalizado e manual', () {
      const hourly = HttpPanelConfig(
        url: 'https://bible-api.com/data/blivre/random',
        jsonPath: '{{random_verse.book}} {{random_verse.chapter}}:{{random_verse.verse}}',
        refreshSeconds: 3600,
      );
      final parsedHourly = HttpPanelConfig.tryParseMetricKey(hourly.toMetricKey());
      expect(parsedHourly, isNotNull);
      expect(parsedHourly!.refreshSeconds, 3600);

      const manual = HttpPanelConfig(
        url: 'https://bible-api.com/data/blivre/random',
        jsonPath: 'random_verse.text',
        refreshSeconds: 0,
      );
      final parsedManual = HttpPanelConfig.tryParseMetricKey(manual.toMetricKey());
      expect(parsedManual, isNotNull);
      expect(parsedManual!.refreshSeconds, 0);

      // Compatibilidade com blocos antigos sem refresh_seconds
      final legacy = HttpPanelConfig.tryParseMetricKey(
        'http:{"url":"https://example.com","path":"a.b"}',
      );
      expect(legacy, isNotNull);
      expect(legacy!.refreshSeconds, HttpPanelConfig.defaultRefreshSeconds);
      expect(legacy.usePcProxy, isFalse);

      // Proxy via PC (USB)
      const proxied = HttpPanelConfig(
        url: 'https://economia.awesomeapi.com.br/json/last/USD-BRL',
        jsonPath: 'USDBRL.bid',
        prefix: 'R\$ ',
        usePcProxy: true,
      );
      final parsedProxied =
          HttpPanelConfig.tryParseMetricKey(proxied.toMetricKey());
      expect(parsedProxied, isNotNull);
      expect(parsedProxied!.usePcProxy, isTrue);

      final service = HttpPanelService();
      final formatted = service.formatResponseBody(
        '{"USDBRL":{"bid":"5.42"}}',
        proxied,
      );
      expect(formatted, 'R\$ 5.42');
    });
  });
}
