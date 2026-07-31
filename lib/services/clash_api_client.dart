import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// One second of upload/download throughput from Clash API `/traffic`.
class TrafficSample {
  const TrafficSample({
    required this.uploadBps,
    required this.downloadBps,
  });

  final int uploadBps;
  final int downloadBps;
}

/// Clash API client (AR §8.1) — traffic, connections, logs.
class ClashApiClient {
  ClashApiClient({
    this.baseUrl = 'http://127.0.0.1:9090',
    this.secret = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String secret;
  final http.Client _http;

  Map<String, String> get _headers => {
    if (secret.isNotEmpty) 'Authorization': 'Bearer $secret',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<bool> isReachable() async {
    try {
      final response = await _http
          .get(_uri('/version'), headers: _headers)
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> version() async {
    final response = await _http.get(_uri('/version'), headers: _headers);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> traffic() async {
    final response = await _http.get(_uri('/traffic'), headers: _headers);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// sing-box streams per-second deltas over WebSocket (REST body is chunked).
  Stream<TrafficSample> trafficStream() async* {
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = secret.isNotEmpty
        ? Uri.parse('$wsUrl/traffic?token=${Uri.encodeComponent(secret)}')
        : Uri.parse('$wsUrl/traffic');

    final channel = WebSocketChannel.connect(uri);
    await for (final event in channel.stream) {
      yield parseTrafficSample(jsonDecode(event.toString()));
    }
  }

  static TrafficSample parseTrafficSample(Object? raw) {
    if (raw is! Map) {
      return const TrafficSample(uploadBps: 0, downloadBps: 0);
    }
    return TrafficSample(
      uploadBps: _parseBps(raw['up']),
      downloadBps: _parseBps(raw['down']),
    );
  }

  static int _parseBps(Object? raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Future<List<dynamic>> connections() async {
    final response = await _http.get(_uri('/connections'), headers: _headers);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['connections'] as List<dynamic>? ?? [];
  }

  Stream<String> logLines({String level = 'info'}) async* {
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final token = secret.isNotEmpty
        ? '&token=${Uri.encodeComponent(secret)}'
        : '';
    final channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/logs?level=$level$token'),
    );

    await for (final event in channel.stream) {
      yield event.toString();
    }
  }

  void close() => _http.close();
}
