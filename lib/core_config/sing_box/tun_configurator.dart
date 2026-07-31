import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_tags.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_topology.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';

/// Builds the TUN inbound section.
class SingBoxTunConfigurator {
  Map<String, dynamic> build({
    required TunnelConfig tunnel,
    required SingBoxTopology topology,
  }) {
    return {
      'type': 'tun',
      'tag': SingBoxTags.tunInbound,
      'address': [ConfigConstants.tunAddr4, ConfigConstants.tunAddr6],
      'mtu': tunnel.tunMtu,
      'auto_route': true,
      'strict_route': topology.strictRoute,
      'stack': 'system',
    };
  }
}
