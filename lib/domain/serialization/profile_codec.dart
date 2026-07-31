import 'package:tunnel_chain/domain/models/awg_obfuscation.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/profile_kind.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// JSON serialization for profiles (metadata only — secrets live in Keychain).
class ProfileCodec {
  const ProfileCodec();

  Map<String, dynamic> encodeAll(List<Profile> profiles) => {
    'version': 1,
    'profiles': profiles.map(encode).toList(),
  };

  List<Profile> decodeAll(Map<String, dynamic> json) {
    final raw = json['profiles'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => decode(Map<String, dynamic>.from(e)))
        .toList();
  }

  Map<String, dynamic> encode(Profile profile) {
    return switch (profile.kind) {
      ProfileKind.vless => _encodeVless(profile as VlessProfile),
      ProfileKind.wireGuard => _encodeWireGuard(profile as WireGuardProfile),
    };
  }

  Profile decode(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;
    return switch (kind) {
      'vless' => _decodeVless(json),
      'wireGuard' => _decodeWireGuard(json),
      _ => throw FormatException('Unknown profile kind: $kind'),
    };
  }

  Map<String, dynamic> _encodeVless(VlessProfile p) => {
    'kind': 'vless',
    'id': p.id,
    'name': p.name,
    'createdAt': p.createdAt.toIso8601String(),
    'host': p.host,
    'port': p.port,
    'uuidRef': p.uuidRef.key,
    'security': p.security,
    'sni': p.sni,
    if (p.publicKeyRef != null) 'publicKeyRef': p.publicKeyRef!.key,
    'shortId': p.shortId,
    'fingerprint': p.fingerprint,
    'flow': p.flow,
    'transport': p.transport,
    if (p.grpcServiceName.isNotEmpty) 'grpcServiceName': p.grpcServiceName,
    if (p.grpcAuthority.isNotEmpty) 'grpcAuthority': p.grpcAuthority,
    if (p.transportPath.isNotEmpty) 'transportPath': p.transportPath,
    if (p.transportHost.isNotEmpty) 'transportHost': p.transportHost,
  };

  VlessProfile _decodeVless(Map<String, dynamic> json) => VlessProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    host: json['host'] as String,
    port: json['port'] as int,
    uuidRef: SecretRef(json['uuidRef'] as String),
    security: json['security'] as String,
    sni: json['sni'] as String? ?? '',
    publicKeyRef: json['publicKeyRef'] != null
        ? SecretRef(json['publicKeyRef'] as String)
        : null,
    shortId: json['shortId'] as String? ?? '',
    fingerprint: json['fingerprint'] as String? ?? 'chrome',
    flow: json['flow'] as String? ?? '',
    transport: json['transport'] as String? ?? 'tcp',
    grpcServiceName: json['grpcServiceName'] as String? ?? '',
    grpcAuthority: json['grpcAuthority'] as String? ?? '',
    transportPath: json['transportPath'] as String? ?? '',
    transportHost: json['transportHost'] as String? ?? '',
  );

  Map<String, dynamic> _encodeWireGuard(WireGuardProfile p) => {
    'kind': 'wireGuard',
    'id': p.id,
    'name': p.name,
    'createdAt': p.createdAt.toIso8601String(),
    'addresses': p.addresses,
    'privateKeyRef': p.privateKeyRef.key,
    'peerPublicKey': p.peerPublicKey,
    if (p.presharedKeyRef != null) 'presharedKeyRef': p.presharedKeyRef!.key,
    'endpointHost': p.endpointHost,
    'endpointPort': p.endpointPort,
    'allowedIps': p.allowedIps,
    'keepalive': p.keepalive,
    'mtu': p.mtu,
    'dnsServers': p.dnsServers,
    'searchDomains': p.searchDomains,
    if (p.obfuscation != null) 'obfuscation': _encodeAwg(p.obfuscation!),
  };

  WireGuardProfile _decodeWireGuard(Map<String, dynamic> json) =>
      WireGuardProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        addresses: (json['addresses'] as List).cast<String>(),
        privateKeyRef: SecretRef(json['privateKeyRef'] as String),
        peerPublicKey: json['peerPublicKey'] as String,
        presharedKeyRef: json['presharedKeyRef'] != null
            ? SecretRef(json['presharedKeyRef'] as String)
            : null,
        endpointHost: json['endpointHost'] as String,
        endpointPort: json['endpointPort'] as int,
        allowedIps: (json['allowedIps'] as List?)?.cast<String>() ?? const [],
        keepalive: json['keepalive'] as int? ?? 10,
        mtu: json['mtu'] as int? ?? 1280,
        dnsServers: (json['dnsServers'] as List?)?.cast<String>() ?? const [],
        searchDomains:
            (json['searchDomains'] as List?)?.cast<String>() ?? const [],
        obfuscation: json['obfuscation'] != null
            ? _decodeAwg(Map<String, dynamic>.from(json['obfuscation'] as Map))
            : null,
      );

  Map<String, dynamic> _encodeAwg(AwgObfuscation o) => {
    'jc': o.jc,
    'jmin': o.jmin,
    'jmax': o.jmax,
    's': o.s,
    'h': o.h,
    'i': o.i,
  };

  AwgObfuscation _decodeAwg(Map<String, dynamic> json) => AwgObfuscation(
    jc: json['jc'] as int? ?? 0,
    jmin: json['jmin'] as int? ?? 0,
    jmax: json['jmax'] as int? ?? 0,
    s: (json['s'] as List?)?.cast<int>() ?? const [0, 0, 0, 0],
    h: (json['h'] as List?)?.cast<int>() ?? const [1, 2, 3, 4],
    i: (json['i'] as List?)?.cast<String>() ?? const [],
  );
}
