import 'dart:convert';
import 'dart:io';

/// Configuração serializada no `metricKey` de blocos HTTP/REST (`http:{...}`).
class HttpPanelConfig {
  static const int defaultRefreshSeconds = 60;
  static const List<int> refreshPresetsSeconds = [
    0, // Manual (apenas ao tocar)
    30,
    60,
    300,
    900,
    1800,
    3600,
    21600,
    86400,
  ];

  final String url;
  final String jsonPath;
  final String prefix;
  final String suffix;
  /// Intervalo de atualização automática em segundos (`0` = manual apenas ao tocar).
  final int refreshSeconds;
  /// Quando `true`, envia a requisição HTTP através do Desktop Agent (útil via cabo USB sem Wi-Fi).
  final bool usePcProxy;

  const HttpPanelConfig({
    required this.url,
    required this.jsonPath,
    this.prefix = '',
    this.suffix = '',
    this.refreshSeconds = defaultRefreshSeconds,
    this.usePcProxy = false,
  });

  String toMetricKey() {
    return 'http:${jsonEncode({
          'url': url,
          'path': jsonPath,
          if (prefix.isNotEmpty) 'prefix': prefix,
          if (suffix.isNotEmpty) 'suffix': suffix,
          if (refreshSeconds != defaultRefreshSeconds)
            'refresh_seconds': refreshSeconds < 0 ? 0 : refreshSeconds,
          if (usePcProxy) 'use_pc_proxy': true,
        })}';
  }

  static HttpPanelConfig? tryParseMetricKey(String? metricKey) {
    if (metricKey == null || !metricKey.startsWith('http:')) return null;
    try {
      final raw = jsonDecode(metricKey.substring(5)) as Map<String, dynamic>;
      final url = raw['url'] as String? ?? '';
      final path = raw['path'] as String? ?? '';
      if (url.isEmpty) return null;
      final parsedRefresh =
          (raw['refresh_seconds'] as num?)?.toInt() ?? defaultRefreshSeconds;
      return HttpPanelConfig(
        url: url,
        jsonPath: path,
        prefix: raw['prefix'] as String? ?? '',
        suffix: raw['suffix'] as String? ?? '',
        refreshSeconds: parsedRefresh < 0 ? 0 : parsedRefresh,
        usePcProxy: raw['use_pc_proxy'] == true,
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

final _templateTokenRegex = RegExp(r'\{\{([^}]+)\}\}');

String _stringifyJsonValue(dynamic value) {
  if (value is Map || value is List) {
    return jsonEncode(value);
  }
  return value.toString().trim();
}

/// Formata um payload JSON usando:
/// - **Caminho simples** (ex.: `USDBRL.bid`, `items[0].name`), retornando `null` se não encontrado; ou
/// - **Template com `{{caminho}}`** (ex.: `{{random_verse.book}} {{random_verse.chapter}}:{{random_verse.verse}} - {{random_verse.text}}`),
///   substituindo cada marcador pelo valor extraído do JSON.
String? formatJsonValue(dynamic decoded, String pathOrTemplate) {
  if (!_templateTokenRegex.hasMatch(pathOrTemplate)) {
    final extracted = extractJsonPath(decoded, pathOrTemplate);
    if (extracted == null) return null;
    return _stringifyJsonValue(extracted);
  }

  var resolvedCount = 0;
  final rendered = pathOrTemplate.replaceAllMapped(_templateTokenRegex, (m) {
    final expr = m.group(1)?.trim() ?? '';
    final extracted = extractJsonPath(decoded, expr);
    if (extracted == null) return '';
    resolvedCount++;
    return _stringifyJsonValue(extracted);
  });

  if (resolvedCount == 0) return null;
  return rendered.trim();
}

class HttpPanelService {
  String formatResponseBody(String body, HttpPanelConfig config) {
    final decoded = jsonDecode(body);
    final formatted = formatJsonValue(decoded, config.jsonPath);
    if (formatted == null) {
      return 'CAMPO NÃO ENCONTRADO';
    }
    return '${config.prefix}$formatted${config.suffix}';
  }

  Future<String> _fetchDirect(Uri uri) async {
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
      return body;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> fetchValue(
    HttpPanelConfig config, {
    Future<String> Function(String url)? proxyFetch,
    bool preferProxy = false,
  }) async {
    final uri = Uri.tryParse(config.url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const FormatException('URL inválida (use http:// ou https://)');
    }

    if ((preferProxy || config.usePcProxy) && proxyFetch != null) {
      final body = await proxyFetch(uri.toString());
      return formatResponseBody(body, config);
    }

    try {
      final body = await _fetchDirect(uri);
      return formatResponseBody(body, config);
    } on SocketException {
      if (proxyFetch != null) {
        final body = await proxyFetch(uri.toString());
        return formatResponseBody(body, config);
      }
      rethrow;
    }
  }
}
