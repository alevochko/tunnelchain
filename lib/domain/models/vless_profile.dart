import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/profile_kind.dart';
import 'package:tunnel_chain/domain/models/protocol_kind.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';

final class VlessProfile extends Profile {
  const VlessProfile({
    required super.id,
    required super.name,
    required super.createdAt,
    required this.host,
    required this.port,
    required this.uuidRef,
    required this.security,
    this.sni = '',
    this.publicKeyRef,
    this.shortId = '',
    this.fingerprint = 'chrome',
    this.flow = '',
    this.transport = 'tcp',
    this.grpcServiceName = '',
    this.grpcAuthority = '',
    this.transportPath = '',
    this.transportHost = '',
  });

  final String host;
  final int port;
  final SecretRef uuidRef;
  final String security;
  final String sni;
  final SecretRef? publicKeyRef;
  final String shortId;
  final String fingerprint;
  final String flow;
  final String transport;
  final String grpcServiceName;
  final String grpcAuthority;
  final String transportPath;
  final String transportHost;

  @override
  ProfileKind get kind => ProfileKind.vless;

  @override
  ProtocolKind get protocol => ProtocolKind.vless;
}
