import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Resolves TUN / WG MTU for sing-box from plan + topology + profile metadata.
///
/// - WG endpoint MTU in sing-box config always comes from [WireGuardProfile.mtu].
/// - TUN MTU: explicit [TunnelPlan.tunMtu], else auto by hop count.
abstract final class TunnelMtuPolicy {
  static const nestedTunMtuDefault = 1280;

  /// singbox-launcher macOS default for single-hop TUN (≠ WG endpoint mtu).
  static const singleHopTunMtuDefault = 1492;

  /// @deprecated Use [singleHopTunMtuDefault].
  static const wgOnlyTunMtuDefault = singleHopTunMtuDefault;

  static int resolveTunMtu({
    required TunnelPlan plan,
    required Chain? defaultChain,
    WireGuardProfile? wireGuard,
  }) {
    if (plan.tunMtu != null) return plan.tunMtu!;

    if (defaultChain != null && defaultChain.hopProfileIds.length == 1) {
      return singleHopTunMtuDefault;
    }

    if (wireGuard != null && defaultChain != null) {
      return plan.wgMtu;
    }

    return nestedTunMtuDefault;
  }

  static int resolveWgMtu({
    required TunnelPlan plan,
    WireGuardProfile? wireGuard,
  }) {
    if (wireGuard != null) return wireGuard.mtu;
    return plan.wgMtu;
  }
}
