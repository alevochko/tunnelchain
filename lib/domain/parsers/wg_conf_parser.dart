import 'package:tunnel_chain/domain/models/awg_obfuscation.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/domain/parsers/parse_result.dart';

class WgConfParseException implements Exception {
  WgConfParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WgConfParser {
  /// Parses wg-quick `.conf` into [WireGuardProfile] (FR-2).
  ParseResult<WireGuardProfile> parse(
    String content, {
    required String id,
    required String name,
    required String privateKeyKeychainKey,
    String? presharedKeyKeychainKey,
    DateTime? createdAt,
  }) {
    final warnings = <String>[];
    final interfaceValues = <String, List<String>>{};
    final peerValues = <String, List<String>>{};

    String? section;
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;

      final sectionMatch = RegExp(r'^\[(.+)\]$').firstMatch(line);
      if (sectionMatch != null) {
        section = sectionMatch.group(1)!.toLowerCase();
        continue;
      }

      if (section != 'interface' && section != 'peer') continue;

      final comment = line.indexOf(RegExp(r'[#;]'));
      if (comment >= 0) line = line.substring(0, comment).trim();
      if (line.isEmpty) continue;

      final eq = line.indexOf('=');
      if (eq < 0) continue;

      var key = line.substring(0, eq).trim().toLowerCase();
      var value = line.substring(eq + 1).trim();

      final target = section == 'interface' ? interfaceValues : peerValues;
      target.putIfAbsent(key, () => []).add(value);
    }

    String? first(String sectionName, String key) {
      final map = sectionName == 'interface' ? interfaceValues : peerValues;
      final values = map[key];
      if (values == null || values.isEmpty) return null;
      return values.first;
    }

    List<String> all(String sectionName, String key) {
      final map = sectionName == 'interface' ? interfaceValues : peerValues;
      return map[key] ?? const [];
    }

    final privateKey = first('interface', 'privatekey');
    if (privateKey == null || privateKey.isEmpty) {
      throw WgConfParseException('[Interface] PrivateKey not found');
    }

    final addressRaw = all('interface', 'address');
    if (addressRaw.isEmpty) {
      throw WgConfParseException('[Interface] Address not found');
    }
    final addresses = addressRaw
        .expand((v) => v.split(','))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();

    final dnsRaw = all('interface', 'dns')
        .expand((v) => v.split(','))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();

    final dnsServers = <String>[];
    final searchDomains = <String>[];
    final ipv4 = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

    for (final entry in dnsRaw) {
      if (ipv4.hasMatch(entry)) {
        if (!dnsServers.contains(entry)) dnsServers.add(entry);
      } else if (!entry.contains(':')) {
        var domain = entry.replaceAll(RegExp(r'^\.|\.$'), '');
        if (domain.isNotEmpty && !searchDomains.contains(domain)) {
          searchDomains.add(domain);
        }
      }
    }

    final mtu = int.tryParse(first('interface', 'mtu') ?? '') ?? 1280;

    final peerPublicKey = first('peer', 'publickey');
    if (peerPublicKey == null || peerPublicKey.isEmpty) {
      throw WgConfParseException('[Peer] PublicKey not found');
    }

    final psk = first('peer', 'presharedkey');
    final endpoint = first('peer', 'endpoint');
    if (endpoint == null || endpoint.isEmpty) {
      throw WgConfParseException('[Peer] Endpoint not found');
    }

    final (endpointHost, endpointPort) = _parseEndpoint(endpoint);

    final allowedIps = all('peer', 'allowedips')
        .expand((v) => v.split(','))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty && v != '0.0.0.0/0')
        .toList();

    final keepalive =
        int.tryParse(first('peer', 'persistentkeepalive') ?? '') ?? 10;

    final obfuscation = _parseAwg(interfaceValues);
    if (obfuscation.isNonTrivial()) {
      warnings.add(
        'Active AWG obfuscation detected — upstream sing-box may not connect',
      );
    }

    final pskKey = presharedKeyKeychainKey ?? 'profile.$id.psk';
    final secrets = <String, String>{privateKeyKeychainKey: privateKey};
    if (psk != null && psk.isNotEmpty) {
      secrets[pskKey] = psk;
    }

    return ParseResult(
      value: WireGuardProfile(
        id: id,
        name: name,
        createdAt: createdAt ?? DateTime.now(),
        addresses: addresses,
        privateKeyRef: SecretRef(privateKeyKeychainKey),
        peerPublicKey: peerPublicKey,
        presharedKeyRef: psk != null && psk.isNotEmpty
            ? SecretRef(pskKey)
            : null,
        endpointHost: endpointHost,
        endpointPort: endpointPort,
        allowedIps: allowedIps,
        keepalive: keepalive,
        mtu: mtu,
        dnsServers: dnsServers,
        searchDomains: searchDomains,
        obfuscation: obfuscation,
      ),
      warnings: warnings,
      secrets: secrets,
    );
  }

  static (String host, int port) _parseEndpoint(String endpoint) {
    var ep = endpoint.trim();
    if (ep.startsWith('[')) {
      final close = ep.indexOf(']');
      if (close < 0) throw WgConfParseException('Invalid Endpoint: $endpoint');
      final host = ep.substring(1, close);
      final portStr = ep.substring(close + 1);
      if (!portStr.startsWith(':')) {
        throw WgConfParseException('Invalid Endpoint port: $endpoint');
      }
      final port = int.tryParse(portStr.substring(1));
      if (port == null || port < 1 || port > 65535) {
        throw WgConfParseException('Invalid Endpoint port: $endpoint');
      }
      return (host, port);
    }

    final colon = ep.lastIndexOf(':');
    if (colon < 0) {
      throw WgConfParseException('Invalid Endpoint: $endpoint');
    }
    final host = ep.substring(0, colon);
    final port = int.tryParse(ep.substring(colon + 1));
    if (port == null || port < 1 || port > 65535) {
      throw WgConfParseException('Invalid Endpoint port: $endpoint');
    }
    return (host, port);
  }

  static AwgObfuscation _parseAwg(Map<String, List<String>> iface) {
    int intVal(String key, int defaultValue) {
      final v = iface[key]?.firstOrNull;
      return int.tryParse(v ?? '') ?? defaultValue;
    }

    List<int> sValues() {
      return [
        intVal('s1', 0),
        intVal('s2', 0),
        intVal('s3', 0),
        intVal('s4', 0),
      ];
    }

    List<int> hValues() {
      return [
        intVal('h1', 1),
        intVal('h2', 2),
        intVal('h3', 3),
        intVal('h4', 4),
      ];
    }

    final iValues = <String>[];
    for (var n = 1; n <= 5; n++) {
      final v = iface['i$n']?.firstOrNull;
      if (v != null && v.isNotEmpty) iValues.add(v);
    }

    return AwgObfuscation(
      jc: intVal('jc', 0),
      jmin: intVal('jmin', 0),
      jmax: intVal('jmax', 0),
      s: sValues(),
      h: hValues(),
      i: iValues,
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
