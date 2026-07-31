import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Low-level sing-box outbound / endpoint JSON builders.
abstract final class SingBoxHopBuilder {
  static Map<String, dynamic> vless(
    VlessProfile profile,
    String tag,
    SecretResolver secrets,
  ) {
    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': profile.host,
      'server_port': profile.port,
      'uuid': secrets.resolve(profile.uuidRef.key),
      'packet_encoding': ConfigConstants.packetEncoding,
      'domain_resolver': 'dns-bootstrap',
      'tls': {
        'enabled': true,
        'server_name': profile.sni,
        'utls': {'enabled': true, 'fingerprint': profile.fingerprint},
      },
    };

    if (profile.flow.isNotEmpty && profile.transport == 'tcp') {
      outbound['flow'] = profile.flow;
    }

    final transport = _buildTransport(profile);
    if (transport != null) outbound['transport'] = transport;

    if (profile.security == 'reality') {
      (outbound['tls'] as Map<String, dynamic>)['reality'] = {
        'enabled': true,
        'public_key': secrets.resolve(
          profile.publicKeyRef?.key ?? '${profile.uuidRef.key}.pbk',
        ),
        'short_id': profile.shortId,
      };
    }

    return outbound;
  }

  static Map<String, dynamic>? _buildTransport(VlessProfile profile) {
    final path = profile.transportPath.isEmpty ? '/' : profile.transportPath;
    final host = profile.transportHost;

    return switch (profile.transport) {
      'tcp' => null,
      'grpc' => {
        'type': 'grpc',
        'service_name': profile.grpcServiceName,
        if (profile.grpcAuthority.isNotEmpty)
          'authority': profile.grpcAuthority,
      },
      'ws' => {
        'type': 'ws',
        'path': path,
        if (host.isNotEmpty) 'headers': {'Host': host},
      },
      'http' => {
        'type': 'http',
        'host': host.isNotEmpty ? host : profile.sni,
        'path': path,
      },
      'httpupgrade' => {
        'type': 'httpupgrade',
        'path': path,
        if (host.isNotEmpty) 'host': host,
      },
      _ => null,
    };
  }

  static Map<String, dynamic> wireGuard({
    required WireGuardProfile wg,
    required String tag,
    required String? detour,
    required String? domainResolver,
    required List<String> allowedIps,
    required int mtu,
    required SecretResolver secrets,
  }) {
    final peer = <String, dynamic>{
      'address': wg.endpointHost,
      'port': wg.endpointPort,
      'public_key': wg.peerPublicKey,
      'allowed_ips': allowedIps,
      'persistent_keepalive_interval': wg.keepalive,
    };

    if (wg.presharedKeyRef != null) {
      peer['pre_shared_key'] = secrets.resolve(wg.presharedKeyRef!.key);
    }

    return {
      'type': 'wireguard',
      'tag': tag,
      'address': wg.addresses,
      'private_key': secrets.resolve(wg.privateKeyRef.key),
      'mtu': mtu,
      'system': false,
      if (domainResolver != null) 'domain_resolver': domainResolver,
      'peers': [peer],
      if (detour != null) 'detour': detour,
    };
  }

  static int effectiveMtu({
    required int profileMtu,
    required int tunMtu,
    required bool nestedInChain,
  }) {
    if (!nestedInChain) return profileMtu;
    return profileMtu > tunMtu ? tunMtu : profileMtu;
  }
}
