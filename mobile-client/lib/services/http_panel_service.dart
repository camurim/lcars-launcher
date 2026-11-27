import 'dart:convert';
import 'dart:io';

/// Configuração serializada no `metricKey` de blocos HTTP/REST (`http:{...}`).
class HttpPanelConfig {
  final String url;
  final String jsonPath;
  final String prefix;
  final String suffix;

  const HttpPanelConfig({
    required this.url,
    required this.jsonPath,
    this.prefix = '',
    this.suffix = '',
  });

  String toMetricKey() {
    return 'http:${jsonEncode({
          'url': url,
          'path': jsonPath,
          if (prefix.isNotEmpty) 'prefix': prefix,
          if (suffix.isNotEmpty) 'suffix': suffix,
        })}';
  }

  static HttpPanelConfig? tryParseMetricKey(String? metricKey) {
    if (metricKey == null || !metricKey.startsWith('http:')) return null;
    try {
      final raw = jsonDecode(metricKey.substring(5)) as Map<String, dynamic>;
      final url = raw['url'] as String? ?? '';
      final path = raw['path'] as String? ?? '';
      if (url.isEmpty) return null;
      return HttpPanelConfig(
        url: url,
        jsonPath: path,
        prefix: raw['prefix'] as String? ?? '',
        suffix: raw['suffix'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Extrai um valor de uma estrutura JSON usando notação por ponto e índices
/// (ex.: `USDBRL.bid`, `current.temperature_2m`, `items.0.name`, `items[0].name`).
dynamic extractJsonPath(dynamic root, String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return root;

  // Normaliza `items[0].name` -> `items.0.name`
  final normalized = trimmed.replaceAllMapped(
    RegExp(r'\[(\d+)\]'),
    (m) => '.${m.group(1)}',
  );
  final segments =
      normalized.split('.').where((s) => s.isNotEmpty).toList();

  dynamic current = root;
  for (final seg in segments) {
    if (current is Map) {
      if (!current.containsKey(seg)) return null;
      current = current[seg];
    } else if (current is List) {
      final idx = int.tryParse(seg);
      if (idx == null || idx < 0 || idx >= current.length) return null;
      current = current[idx];
    } else {
      return null;
    }
  }
  return current;
}

class HttpPanelService {
  Future<String> fetchValue(HttpPanelConfig config) async {
    final uri = Uri.tryParse(config.url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const FormatException('URL inválida (use http:// ou https://)');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.userAgentHeader, 'SciFiDeckControl/1.0');

      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException('HTTP ${resp.statusCode}');
      }

      final decoded = jsonDecode(body);
      final extracted = extractJsonPath(decoded, config.jsonPath);
      if (extracted == null) {
        return 'CAMPO NÃO ENCONTRADO';
      }

      final formatted = extracted is Map || extracted is List
          ? jsonEncode(extracted)
          : extracted.toString();
      return '${config.prefix}$formatted${config.suffix}';
    } finally {
      client.close(force: true);
    }
  }
}
