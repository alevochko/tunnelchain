import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/core_config/config_generator.dart';
import 'package:tunnel_chain/core_config/config_invariants.dart';
import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/parsers/vless_parser.dart';
import 'package:tunnel_chain/domain/serialization/profile_codec.dart';

void main() {
  test('grpc vless hop is emitted with transport in generated config', () {
    const chainId = 'chain-grpc';
    const link =
        'vless://550e8400-e29b-41d4-a716-446655440000@vps.example.com:443'
        '?type=grpc&security=reality&pbk=testPubKey&fp=chrome'
        '&sni=cdn.example.com&sid=abc&serviceName=GunService';

    final profile = VlessParser().parse(
      link,
      id: 'vps-grpc',
      name: 'VPS gRPC',
      uuidKeychainKey: 'secret.uuid',
      publicKeyKeychainKey: 'secret.pbk',
    ).value;

    final tunnel = TunnelConfig(
      routing: RoutingPolicy(
        defaultTarget: const RouteTarget.chain(chainId),
      ),
      dns: const DnsPolicy(),
      tunMtu: 1492,
      clashApiSecret: 'x',
    );

    final config = ConfigGenerator().generate(
      profiles: {profile.id: profile},
      chains: [
        Chain(id: chainId, name: 'gRPC', hopProfileIds: [profile.id]),
      ],
      tunnel: tunnel,
      secrets: MapSecretResolver({
        'secret.uuid': '550e8400-e29b-41d4-a716-446655440000',
        'secret.pbk': 'testPubKey',
      }),
    );

    final outbound = (config['outbounds'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((o) => o['tag'] == 'chain-grpc-hop0');

    final transport = outbound['transport'] as Map<String, dynamic>;
    expect(transport['type'], 'grpc');
    expect(transport['service_name'], 'GunService');
    expect(outbound.containsKey('flow'), isFalse);
    ConfigInvariants.assertAll(config);
  });

  test('profile codec round-trips grpc fields', () {
    const codec = ProfileCodec();
    final profile = VlessProfile(
      id: 'vps',
      name: 'VPS',
      createdAt: DateTime.utc(2026, 1, 1),
      host: 'example.com',
      port: 443,
      uuidRef: const SecretRef('secret.uuid'),
      security: 'reality',
      sni: 'cdn.example.com',
      publicKeyRef: const SecretRef('secret.pbk'),
      transport: 'grpc',
      grpcServiceName: 'GunService',
      grpcAuthority: 'grpc.example',
    );

    final restored = codec.decode(codec.encode(profile)) as VlessProfile;

    expect(restored.transport, 'grpc');
    expect(restored.grpcServiceName, 'GunService');
    expect(restored.grpcAuthority, 'grpc.example');
  });
}
