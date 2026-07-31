import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/demo/sample_tunnel.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';

/// Back-compat alias for tests written against the fixture name.
abstract final class NestedChainFixture {
  static Map<String, Profile> get profiles => SampleTunnel.profiles;
  static List<Chain> get chains => SampleTunnel.chains;
  static TunnelConfig get tunnelConfig => SampleTunnel.tunnelConfig;
  static SecretResolver get secrets => SampleTunnel.secrets;
  static Map<String, dynamic> generate() => SampleTunnel.generateConfig();
}
