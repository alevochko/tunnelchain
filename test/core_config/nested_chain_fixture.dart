import 'package:tunnel_chain/demo/sample_tunnel.dart';

/// Back-compat alias for tests written against the fixture name.
abstract final class NestedChainFixture {
  static get profiles => SampleTunnel.profiles;
  static get chains => SampleTunnel.chains;
  static get tunnelConfig => SampleTunnel.tunnelConfig;
  static get secrets => SampleTunnel.secrets;
  static Map<String, dynamic> generate() => SampleTunnel.generateConfig();
}
