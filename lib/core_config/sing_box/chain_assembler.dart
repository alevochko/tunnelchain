import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/core_config/sing_box/hop_builder.dart';
import 'package:tunnel_chain/core_config/sing_box/sing_box_tags.dart';
import 'package:tunnel_chain/core_config/sing_box/wire_guard_allowed_ips.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/tunnel_config.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Built hops: outbounds, endpoints, and chain → tag mappings.
class ChainAssembly {
  const ChainAssembly({
    required this.hopTags,
    required this.chainHopTags,
    required this.outbounds,
    required this.endpoints,
  });

  final Map<String, String> hopTags;
  final Map<String, List<String>> chainHopTags;
  final List<Map<String, dynamic>> outbounds;
  final List<Map<String, dynamic>> endpoints;
}

/// Walks referenced chains and emits sing-box outbounds / wireguard endpoints.
class ChainAssembler {
  ChainAssembly assemble({
    required Set<String> referencedChainIds,
    required Map<String, Chain> chainById,
    required Map<String, Profile> profiles,
    required TunnelConfig tunnel,
    required bool wgOnlyDefault,
    required SecretResolver secrets,
  }) {
    final hopTags = <String, String>{};
    final chainHopTags = <String, List<String>>{};
    final outbounds = <Map<String, dynamic>>[];
    final endpoints = <Map<String, dynamic>>[];
    final builtOutbounds = <String, String>{};

    for (final chainId in referencedChainIds) {
      final chain = chainById[chainId]!;
      final tagsInChain = <String>[];
      String? previousTag;

      for (var i = 0; i < chain.hopProfileIds.length; i++) {
        final profileId = chain.hopProfileIds[i];
        final profile = profiles[profileId]!;
        final tag = SingBoxTags.hop(chainId, i);

        if (profile is VlessProfile) {
          final dedupeKey = 'vless:$profileId:${previousTag ?? 'root'}';
          if (!builtOutbounds.containsKey(dedupeKey)) {
            builtOutbounds[dedupeKey] = tag;
            outbounds.add(SingBoxHopBuilder.vless(profile, tag, secrets));
          }
          previousTag = builtOutbounds[dedupeKey]!;
        } else if (profile is WireGuardProfile) {
          final launcherStyle = wgOnlyDefault && previousTag == null && i == 0;
          final nestedHop = previousTag != null;
          endpoints.add(
            SingBoxHopBuilder.wireGuard(
              wg: profile,
              tag: tag,
              // Never detour to "direct" — sing-box rejects it; root WG uses
              // auto_detect_interface instead. Nested hops detour through VLESS.
              detour: previousTag,
              domainResolver: launcherStyle
                  ? null
                  : (nestedHop
                        ? SingBoxTags.outerHopDns(chainId)
                        : SingBoxTags.bootstrapDns),
              allowedIps: WireGuardAllowedIps.forChain(
                chainId: chainId,
                tunnel: tunnel,
                wg: profile,
                includeIpv6Default: launcherStyle || nestedHop,
              ),
              mtu: SingBoxHopBuilder.effectiveMtu(
                profileMtu: profile.mtu,
                tunMtu: tunnel.tunMtu,
                nestedInChain: nestedHop,
              ),
              secrets: secrets,
            ),
          );
          previousTag = tag;
        } else {
          throw StateError('Unsupported profile: ${profile.runtimeType}');
        }

        tagsInChain.add(previousTag);
      }

      chainHopTags[chainId] = tagsInChain;
      hopTags[chainId] = tagsInChain.last;
    }

    return ChainAssembly(
      hopTags: hopTags,
      chainHopTags: chainHopTags,
      outbounds: outbounds,
      endpoints: endpoints,
    );
  }
}
