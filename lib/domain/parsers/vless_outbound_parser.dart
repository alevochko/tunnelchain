import 'dart:convert';

import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/parsers/parse_result.dart';
import 'package:tunnel_chain/domain/parsers/vless_parser.dart';
import 'package:tunnel_chain/domain/parsers/vless_transport.dart';

/// Parses VLESS share links and sing-box / Xray outbound JSON.
class VlessOutboundParser {
  VlessOutboundParser({VlessParser? uriParser})
    : _uriParser = uriParser ?? VlessParser();

  final VlessParser _uriParser;

  ParseResult<VlessProfile> parse(
    String payload, {
    required String id,
    required String name,
    required String uuidKeychainKey,
    String? publicKeyKeychainKey,
    DateTime? createdAt,
  }) {
    final trimmed = payload.trim();
    if (trimmed.startsWith('vless://')) {
      return _uriParser.parse(
        trimmed,
        id: id,
        name: name,
        uuidKeychainKey: uuidKeychainKey,
        publicKeyKeychainKey: publicKeyKeychainKey,
        createdAt: createdAt,
      );
    }

    return _parseJson(
      trimmed,
      id: id,
      name: name,
      uuidKeychainKey: uuidKeychainKey,
      publicKeyKeychainKey: publicKeyKeychainKey,
      createdAt: createdAt,
    );
  }

  ParseResult<VlessProfile> _parseJson(
    String jsonText, {
    required String id,
    required String name,
    required String uuidKeychainKey,
    String? publicKeyKeychainKey,
    DateTime? createdAt,
  }) {
    final dynamic parsed;
    try {
      parsed = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw VlessParseException('Invalid JSON: ${e.message}');
    }

    final extracted = _extractOutbound(parsed);
    final rootRemarks = parsed is Map ? parsed['remarks'] as String? : null;
    final effectiveName = name.isNotEmpty
        ? name
        : (rootRemarks is String ? rootRemarks.trim() : '');

    if (extracted.outbound['type'] == 'vless' ||
        extracted.outbound.containsKey('uuid')) {
      return _mergeWarnings(
        _fromSingBoxOutbound(
          extracted.outbound,
          id: id,
          name: effectiveName,
          uuidKeychainKey: uuidKeychainKey,
          publicKeyKeychainKey: publicKeyKeychainKey,
          createdAt: createdAt,
        ),
        extracted.warnings,
      );
    }

    if (extracted.outbound['protocol'] == 'vless') {
      return _mergeWarnings(
        _fromXrayOutbound(
          extracted.outbound,
          id: id,
          name: effectiveName,
          uuidKeychainKey: uuidKeychainKey,
          publicKeyKeychainKey: publicKeyKeychainKey,
          createdAt: createdAt,
        ),
        extracted.warnings,
      );
    }

    throw VlessParseException(
      'JSON does not contain a supported VLESS outbound',
    );
  }

  ParseResult<VlessProfile> _mergeWarnings(
    ParseResult<VlessProfile> result,
    List<String> extraWarnings,
  ) {
    if (extraWarnings.isEmpty) return result;
    return ParseResult(
      value: result.value,
      warnings: [...extraWarnings, ...result.warnings],
      secrets: result.secrets,
    );
  }

  ({Map<String, dynamic> outbound, List<String> warnings}) _extractOutbound(
    dynamic json,
  ) {
    final warnings = <String>[];

    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      if (map['type'] == 'vless' || map['protocol'] == 'vless') {
        return (outbound: map, warnings: warnings);
      }

      final outbounds = map['outbounds'];
      if (outbounds is List) {
        final vless = _collectVlessOutbounds(outbounds);
        if (vless.isNotEmpty) {
          if (vless.length > 1) {
            final selected = _pickPreferredVlessOutbound(vless);
            final tag = selected['tag'];
            warnings.add(
              'Found ${vless.length} VLESS outbounds in the file — '
              'importing${tag is String && tag.isNotEmpty ? ' "$tag"' : ' the first one'} only. '
              'Routing, balancers, and other outbounds are ignored.',
            );
            return (outbound: selected, warnings: warnings);
          }
          return (outbound: vless.first, warnings: warnings);
        }
      }
    }

    if (json is List) {
      final vless = _collectVlessOutbounds(json);
      if (vless.isNotEmpty) {
        return (outbound: _pickPreferredVlessOutbound(vless), warnings: warnings);
      }
    }

    throw VlessParseException('No VLESS outbound found in JSON');
  }

  List<Map<String, dynamic>> _collectVlessOutbounds(List<dynamic> outbounds) {
    final vless = <Map<String, dynamic>>[];
    for (final item in outbounds) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (map['type'] == 'vless' || map['protocol'] == 'vless') {
        vless.add(map);
      }
    }
    return vless;
  }

  Map<String, dynamic> _pickPreferredVlessOutbound(
    List<Map<String, dynamic>> outbounds,
  ) {
    for (final tag in const ['proxy', 'main', 'default', 'auto']) {
      for (final outbound in outbounds) {
        if (outbound['tag'] == tag) return outbound;
      }
    }
    return outbounds.first;
  }

  ParseResult<VlessProfile> _fromSingBoxOutbound(
    Map<String, dynamic> outbound, {
    required String id,
    required String name,
    required String uuidKeychainKey,
    String? publicKeyKeychainKey,
    DateTime? createdAt,
  }) {
    final warnings = <String>[];
    final host = outbound['server'] as String?;
    final port = outbound['server_port'] as int? ?? outbound['port'] as int?;
    final uuid = outbound['uuid'] as String?;
    if (host == null || host.isEmpty || port == null || uuid == null) {
      throw VlessParseException('VLESS outbound missing server, port, or uuid');
    }

    final tls = outbound['tls'] is Map
        ? Map<String, dynamic>.from(outbound['tls'] as Map)
        : const <String, dynamic>{};
    final reality = tls['reality'] is Map
        ? Map<String, dynamic>.from(tls['reality'] as Map)
        : const <String, dynamic>{};
    final utls = tls['utls'] is Map
        ? Map<String, dynamic>.from(tls['utls'] as Map)
        : const <String, dynamic>{};

    final security = reality['enabled'] == true
        ? 'reality'
        : (tls['enabled'] == true ? 'tls' : 'none');
  final pbk = '${reality['public_key'] ?? ''}';
    final sni = '${tls['server_name'] ?? ''}';
    final sid = '${reality['short_id'] ?? ''}';
    final fingerprint = '${utls['fingerprint'] ?? 'chrome'}';
    final flow = '${outbound['flow'] ?? ''}';

    final effectiveSni = _validateSecurityFromJson(
      security: security,
      sni: sni,
      host: host,
      pbk: pbk,
    );

    final transportBlock = outbound['transport'] is Map
        ? Map<String, dynamic>.from(outbound['transport'] as Map)
        : null;
    final transportType = VlessTransports.normalize(
      '${transportBlock?['type'] ?? 'tcp'}',
    );
    final transportFields = VlessParser.parseTransportFromOutbound(
      transportType,
      transportBlock,
      flow: flow,
      warnings: warnings,
    );

    final pbkKey = publicKeyKeychainKey ?? 'profile.$id.pbk';
    final secrets = <String, String>{uuidKeychainKey: uuid};
    if (pbk.isNotEmpty) secrets[pbkKey] = pbk;

    final tag = outbound['tag'];
    final resolvedName = name.trim().isNotEmpty
        ? name
        : (tag is String && tag.isNotEmpty ? tag : '$host:$port');

    return ParseResult(
      value: VlessProfile(
        id: id,
        name: resolvedName,
        createdAt: createdAt ?? DateTime.now(),
        host: host,
        port: port,
        uuidRef: SecretRef(uuidKeychainKey),
        security: security,
        sni: effectiveSni,
        publicKeyRef: pbk.isNotEmpty ? SecretRef(pbkKey) : null,
        shortId: sid,
        fingerprint: fingerprint,
        flow: transportFields.flow,
        transport: transportType,
        grpcServiceName: transportFields.grpcServiceName,
        grpcAuthority: transportFields.grpcAuthority,
        transportPath: transportFields.transportPath,
        transportHost: transportFields.transportHost,
      ),
      warnings: warnings,
      secrets: secrets,
    );
  }

  ParseResult<VlessProfile> _fromXrayOutbound(
    Map<String, dynamic> outbound, {
    required String id,
    required String name,
    required String uuidKeychainKey,
    String? publicKeyKeychainKey,
    DateTime? createdAt,
  }) {
    final warnings = <String>[];
    final settings = outbound['settings'] is Map
        ? Map<String, dynamic>.from(outbound['settings'] as Map)
        : const <String, dynamic>{};
    final stream = outbound['streamSettings'] is Map
        ? Map<String, dynamic>.from(outbound['streamSettings'] as Map)
        : const <String, dynamic>{};

    final vnext = (settings['vnext'] as List?)?.whereType<Map>().firstOrNull;
    if (vnext == null) {
      throw VlessParseException('Xray VLESS outbound missing settings.vnext');
    }

    final host = vnext['address'] as String?;
    final port = vnext['port'] as int?;
    final users = (vnext['users'] as List?)?.whereType<Map>().firstOrNull;
    final uuid = users?['id'] as String?;
    final flow = '${users?['flow'] ?? ''}';
    if (host == null || port == null || uuid == null) {
      throw VlessParseException('Xray VLESS outbound missing address/port/uuid');
    }

    final security = '${stream['security'] ?? 'none'}';
    final reality = stream['realitySettings'] is Map
        ? Map<String, dynamic>.from(stream['realitySettings'] as Map)
        : const <String, dynamic>{};
    final tls = stream['tlsSettings'] is Map
        ? Map<String, dynamic>.from(stream['tlsSettings'] as Map)
        : const <String, dynamic>{};

    final pbk = '${reality['publicKey'] ?? reality['public_key'] ?? ''}';
    final sid = '${reality['shortId'] ?? reality['short_id'] ?? ''}';
    final sni = '${reality['serverName'] ?? tls['serverName'] ?? ''}';
    final fingerprint = '${reality['fingerprint'] ?? tls['fingerprint'] ?? 'chrome'}';

    final effectiveSni = _validateSecurityFromJson(
      security: security,
      sni: sni,
      host: host,
      pbk: pbk,
    );

    final network = VlessTransports.normalize('${stream['network'] ?? 'tcp'}');
    final transportBlock = _xrayTransportBlock(network, stream);
    final transportFields = VlessParser.parseTransportFromOutbound(
      network,
      transportBlock,
      flow: flow,
      warnings: warnings,
    );

    final pbkKey = publicKeyKeychainKey ?? 'profile.$id.pbk';
    final secrets = <String, String>{uuidKeychainKey: uuid};
    if (pbk.isNotEmpty) secrets[pbkKey] = pbk;

    final tag = outbound['tag'];
    final resolvedName = name.trim().isNotEmpty
        ? name
        : (tag is String && tag.isNotEmpty ? tag : '$host:$port');

    return ParseResult(
      value: VlessProfile(
        id: id,
        name: resolvedName,
        createdAt: createdAt ?? DateTime.now(),
        host: host,
        port: port,
        uuidRef: SecretRef(uuidKeychainKey),
        security: security,
        sni: effectiveSni,
        publicKeyRef: pbk.isNotEmpty ? SecretRef(pbkKey) : null,
        shortId: sid,
        fingerprint: fingerprint,
        flow: transportFields.flow,
        transport: network,
        grpcServiceName: transportFields.grpcServiceName,
        grpcAuthority: transportFields.grpcAuthority,
        transportPath: transportFields.transportPath,
        transportHost: transportFields.transportHost,
      ),
      warnings: warnings,
      secrets: secrets,
    );
  }

  Map<String, dynamic>? _xrayTransportBlock(
    String network,
    Map<String, dynamic> stream,
  ) {
    return switch (network) {
      'ws' => stream['wsSettings'] is Map
          ? Map<String, dynamic>.from(stream['wsSettings'] as Map)
          : const {},
      'grpc' => stream['grpcSettings'] is Map
          ? Map<String, dynamic>.from(stream['grpcSettings'] as Map)
          : const {},
      'http' => stream['httpSettings'] is Map
          ? Map<String, dynamic>.from(stream['httpSettings'] as Map)
          : const {},
      'httpupgrade' => stream['httpupgradeSettings'] is Map
          ? Map<String, dynamic>.from(stream['httpupgradeSettings'] as Map)
          : const {},
      _ => null,
    };
  }

  String _validateSecurityFromJson({
    required String security,
    required String sni,
    required String host,
    required String pbk,
  }) {
    switch (security) {
      case 'reality':
        if (pbk.isEmpty) {
          throw VlessParseException('REALITY requires public_key / publicKey');
        }
        if (sni.isEmpty) {
          throw VlessParseException('REALITY requires server_name / serverName');
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
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
