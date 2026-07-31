import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/parsers/parse_result.dart';
import 'package:tunnel_chain/domain/parsers/vless_transport.dart';

class VlessParseException implements Exception {
  VlessParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VlessParser {
  /// Parses a `vless://` link into a [VlessProfile] (FR-1).
  ParseResult<VlessProfile> parse(
    String uri, {
    required String id,
    required String name,
    required String uuidKeychainKey,
    String? publicKeyKeychainKey,
    DateTime? createdAt,
  }) {
    final warnings = <String>[];
    final trimmed = uri.replaceAll(RegExp(r'\s'), '');
    if (!trimmed.startsWith('vless://')) {
      throw VlessParseException(
        'Expected vless:// link, got: ${trimmed.length > 20 ? '${trimmed.substring(0, 20)}...' : trimmed}',
      );
    }

    var rest = trimmed.substring('vless://'.length);
    rest = rest.split('#').first;

    String query = '';
    if (rest.contains('?')) {
      final parts = rest.split('?');
      rest = parts.first;
      query = parts.sublist(1).join('?');
    }
    if (rest.endsWith('/')) {
      rest = rest.substring(0, rest.length - 1);
    }

    if (!rest.contains('@')) {
      throw VlessParseException(
        'vless link missing @ (expected uuid@host:port)',
      );
    }

    final atIndex = rest.indexOf('@');
    final uuid = rest.substring(0, atIndex);
    var hostPort = rest.substring(atIndex + 1);

    late String host;
    late int port;

    if (hostPort.startsWith('[')) {
      final close = hostPort.indexOf(']');
      if (close < 0) {
        throw VlessParseException('Invalid IPv6 host in vless link');
      }
      host = hostPort.substring(1, close);
      final portPart = hostPort.substring(close + 1);
      if (!portPart.startsWith(':')) {
        throw VlessParseException('Missing port after IPv6 host');
      }
      port = int.tryParse(portPart.substring(1)) ?? -1;
    } else {
      final colon = hostPort.lastIndexOf(':');
      if (colon < 0) {
        throw VlessParseException('Missing port in vless link');
      }
      host = hostPort.substring(0, colon);
      port = int.tryParse(hostPort.substring(colon + 1)) ?? -1;
    }

    if (uuid.isEmpty || host.isEmpty || port < 1 || port > 65535) {
      throw VlessParseException(
        'Empty uuid/host or invalid port in vless link',
      );
    }

    final params = _parseQuery(query);
    final transport = VlessTransports.normalize(params['type'] ?? 'tcp');
    final security = params['security'] ?? 'none';
    final flow = params['flow'] ?? '';
    var sni = _urlDecode(params['sni'] ?? '');
    final fingerprint = params['fp'] ?? 'chrome';
    final pbk = _urlDecode(params['pbk'] ?? '');
    final sid = params['sid'] ?? '';

    if (!VlessTransports.supported.contains(transport)) {
      throw VlessParseException(
        "Transport '$transport' is not supported "
        '(supported: ${VlessTransports.supported.join(', ')})',
      );
    }

    sni = _validateSecurity(
      security: security,
      sni: sni,
      host: host,
      pbk: pbk,
    );

    final transportFields = _parseUriTransportFields(
      transport: transport,
      params: params,
      flow: flow,
      warnings: warnings,
    );

    if (params.containsKey('pqv')) {
      warnings.add(
        'pqv= (post-quantum) ignored — sing-box does not support it',
      );
    }

    final pbkKey = publicKeyKeychainKey ?? 'profile.$id.pbk';
    final secrets = <String, String>{uuidKeychainKey: uuid};
    if (pbk.isNotEmpty) {
      secrets[pbkKey] = pbk;
    }

    return ParseResult(
      value: VlessProfile(
        id: id,
        name: name,
        createdAt: createdAt ?? DateTime.now(),
        host: host,
        port: port,
        uuidRef: SecretRef(uuidKeychainKey),
        security: security,
        sni: sni,
        publicKeyRef: pbk.isNotEmpty ? SecretRef(pbkKey) : null,
        shortId: sid,
        fingerprint: fingerprint,
        flow: transportFields.flow,
        transport: transport,
        grpcServiceName: transportFields.grpcServiceName,
        grpcAuthority: transportFields.grpcAuthority,
        transportPath: transportFields.transportPath,
        transportHost: transportFields.transportHost,
      ),
      warnings: warnings,
      secrets: secrets,
    );
  }

  static ({
    String flow,
    String grpcServiceName,
    String grpcAuthority,
    String transportPath,
    String transportHost,
  }) parseTransportFromOutbound(
    String transport,
    Map<String, dynamic>? transportBlock, {
    String flow = '',
    required List<String> warnings,
  }) {
    final normalized = VlessTransports.normalize(transport);
    if (!VlessTransports.supported.contains(normalized)) {
      throw VlessParseException(
        "Transport '$transport' is not supported "
        '(supported: ${VlessTransports.supported.join(', ')})',
      );
    }

    final block = transportBlock == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(transportBlock);
    final headers = block['headers'] is Map
        ? Map<String, dynamic>.from(block['headers'] as Map)
        : const <String, dynamic>{};

    var grpcServiceName = '';
    var grpcAuthority = '';
    var transportPath = _urlDecode('${block['path'] ?? ''}');
    var transportHost = _urlDecode(
      '${block['host'] ?? headers['Host'] ?? headers['host'] ?? ''}',
    );

    switch (normalized) {
      case 'grpc':
        grpcServiceName = _urlDecode(
          '${block['service_name'] ?? block['serviceName'] ?? ''}',
        );
        grpcAuthority = _urlDecode('${block['authority'] ?? ''}');
        if (grpcServiceName.isEmpty) {
          warnings.add(
            'service_name is missing — gRPC may fail unless the server accepts an empty name',
          );
        }
      case 'ws':
        if (transportPath.isEmpty) transportPath = '/';
        transportHost = _urlDecode(
          '${headers['Host'] ?? headers['host'] ?? transportHost}',
        );
      case 'http':
        if (transportPath.isEmpty) transportPath = '/';
        if (transportHost.isEmpty) {
          warnings.add(
            'HTTP/2 transport host is missing — using TLS server_name',
          );
        }
      case 'httpupgrade':
        if (transportPath.isEmpty) transportPath = '/';
      case 'tcp':
        break;
    }

    final effectiveFlow = VlessTransports.supportsFlow(normalized) ? flow : '';
    if (flow.isNotEmpty && !VlessTransports.supportsFlow(normalized)) {
      warnings.add('flow is ignored for $normalized transport');
    }

    return (
      flow: effectiveFlow,
      grpcServiceName: grpcServiceName,
      grpcAuthority: grpcAuthority,
      transportPath: transportPath,
      transportHost: transportHost,
    );
  }

  static ({
    String flow,
    String grpcServiceName,
    String grpcAuthority,
    String transportPath,
    String transportHost,
  }) _parseUriTransportFields({
    required String transport,
    required Map<String, String> params,
    required String flow,
    required List<String> warnings,
  }) {
    final path = _urlDecode(params['path'] ?? '');
    final hostHeader = _urlDecode(params['host'] ?? '');

    return parseTransportFromOutbound(
      transport,
      {
        'path': path,
        'host': hostHeader,
        'service_name': params['serviceName'] ?? params['service_name'],
        'authority': params['authority'],
        if (hostHeader.isNotEmpty) 'headers': {'Host': hostHeader},
      },
      flow: flow,
      warnings: warnings,
    );
  }

  static String _validateSecurity({
    required String security,
    required String sni,
    required String host,
    required String pbk,
  }) {
    switch (security) {
      case 'reality':
        if (pbk.isEmpty) {
          throw VlessParseException(
            'security=reality requires pbk= (public key)',
          );
        }
        if (sni.isEmpty) {
          throw VlessParseException('security=reality requires sni=');
        }
        return sni;
      case 'tls':
        return sni.isEmpty ? host : sni;
      case 'none':
        throw VlessParseException(
          "security='$security' is not supported (need reality or tls)",
        );
      default:
        throw VlessParseException(
          "security='$security' is not supported (need reality or tls)",
        );
    }
  }

  static Map<String, String> _parseQuery(String query) {
    final result = <String, String>{};
    if (query.isEmpty) return result;
    for (final part in query.split('&')) {
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      if (eq < 0) {
        result[part] = '';
      } else {
        result[part.substring(0, eq)] = part.substring(eq + 1);
      }
    }
    return result;
  }

  static String _urlDecode(String value) {
    if (value.isEmpty) return value;
    return Uri.decodeComponent(value.replaceAll('+', ' '));
  }
}
