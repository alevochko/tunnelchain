import 'package:tunnel_chain/domain/models/awg_obfuscation.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/profile_kind.dart';
import 'package:tunnel_chain/domain/models/protocol_kind.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';

final class WireGuardProfile extends Profile {
  const WireGuardProfile({
    required super.id,
    required super.name,
    required super.createdAt,
    required this.addresses,
    required this.privateKeyRef,
    required this.peerPublicKey,
    required this.endpointHost,
    required this.endpointPort,
    this.presharedKeyRef,
    this.allowedIps = const [],
    this.keepalive = 10,
    this.mtu = 1280,
    this.dnsServers = const [],
    this.searchDomains = const [],
    this.obfuscation,
  });

  final List<String> addresses;
  final SecretRef privateKeyRef;
  final String peerPublicKey;
  final SecretRef? presharedKeyRef;
  final String endpointHost;
  final int endpointPort;
  final List<String> allowedIps;
  final int keepalive;
  final int mtu;
  final List<String> dnsServers;
  final List<String> searchDomains;
  final AwgObfuscation? obfuscation;

  @override
  ProfileKind get kind => ProfileKind.wireGuard;

  @override
  ProtocolKind get protocol => ProtocolKind.wireGuard;

  String? get primaryDnsServer => dnsServers.isEmpty ? null : dnsServers.first;
}
