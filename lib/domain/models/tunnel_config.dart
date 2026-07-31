import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/stack_type.dart';

class TunnelConfig {
  const TunnelConfig({
    required this.routing,
    required this.dns,
    this.tunMtu = 1280,
    this.wgMtu = 1280,
    this.stack = StackType.system,
    this.killSwitch = true,
    this.safetyTimeoutSec = 300,
    this.clashApiSecret,
  });

  final RoutingPolicy routing;
  final DnsPolicy dns;
  final int tunMtu;
  final int wgMtu;
  final StackType stack;
  final bool killSwitch;
  final int safetyTimeoutSec;
  final String? clashApiSecret;

  Set<String> referencedChainIds() => routing.referencedChainIds();
}
