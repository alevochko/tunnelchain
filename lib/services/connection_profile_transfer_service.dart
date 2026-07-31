import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/secret_ref.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';
import 'package:tunnel_chain/domain/profile_secrets.dart';
import 'package:tunnel_chain/domain/serialization/connection_profile_bundle_codec.dart';
import 'package:tunnel_chain/domain/serialization/profile_codec.dart';
import 'package:tunnel_chain/domain/serialization/tunnel_plan_codec.dart';

enum ImportConflictAction { rename, replace, skip }

class ProfileImportRow {
  ProfileImportRow({
    required this.profile,
    required this.hasIdConflict,
    this.action = ImportConflictAction.rename,
    this.selected = true,
  });

  final ConnectionProfile profile;
  final bool hasIdConflict;
  ImportConflictAction action;
  bool selected;
}

class ConnectionProfileImportPreview {
  const ConnectionProfileImportPreview({
    required this.profiles,
    required this.chains,
    required this.nodes,
    required this.secrets,
    this.nodesToAdd = 0,
  });

  final List<ProfileImportRow> profiles;
  final List<Chain> chains;
  final List<Profile> nodes;
  final Map<String, String> secrets;
  final int nodesToAdd;
}

class ResolvedConnectionProfileImport {
  const ResolvedConnectionProfileImport({
    required this.profiles,
    required this.chains,
    required this.nodes,
    required this.secrets,
  });

  final List<ConnectionProfile> profiles;
  final List<Chain> chains;
  final List<Profile> nodes;
  final Map<String, String> secrets;
}

class ConnectionProfileTransferService {
  ConnectionProfileTransferService({
    ConnectionProfileBundleCodec? bundleCodec,
    TunnelPlanCodec? planCodec,
    ProfileCodec? profileCodec,
  }) : _bundleCodec = bundleCodec ?? const ConnectionProfileBundleCodec(),
       _planCodec = planCodec ?? const TunnelPlanCodec(),
       _profileCodec = profileCodec ?? const ProfileCodec();

  final ConnectionProfileBundleCodec _bundleCodec;
  final TunnelPlanCodec _planCodec;
  final ProfileCodec _profileCodec;

  ConnectionProfileBundle buildExportBundle(
    TunnelPlan plan,
    List<Profile> allNodes, {
    List<ConnectionProfile>? profiles,
    Map<String, String> secrets = const {},
  }) {
    final selected = profiles ?? plan.profiles;
    final chainIds = selected
        .expand((profile) => profile.referencedChainIds())
        .toSet();
    final chains = plan.chains.where((c) => chainIds.contains(c.id)).toList();
    final hopIds = chains.expand((chain) => chain.hopProfileIds).toSet();
    final nodes = allNodes.where((node) => hopIds.contains(node.id)).toList();
    final secretKeys = nodes.expand(profileSecretKeys).toSet();
    final filteredSecrets = {
      for (final entry in secrets.entries)
        if (secretKeys.contains(entry.key)) entry.key: entry.value,
    };

    return ConnectionProfileBundle(
      profiles: selected,
      chains: chains,
      nodes: nodes,
      secrets: filteredSecrets,
    );
  }

  String encodeBundle(ConnectionProfileBundle bundle) =>
      _bundleCodec.encode(bundle);

  ConnectionProfileBundle decodeBundle(String json) =>
      _bundleCodec.decode(json);

  void validateBundleCompleteness(
    ConnectionProfileBundle bundle,
    Set<String> localNodeIds,
  ) {
    if (bundle.nodes.isNotEmpty) return;

    final hopIds = bundle.chains.expand((chain) => chain.hopProfileIds).toSet();
    if (hopIds.isEmpty) return;

    final missing = hopIds.difference(localNodeIds);
    if (missing.isEmpty) return;

    throw ConnectionProfileBundleFormatException(
      'File does not include node configs for: ${missing.join(', ')}. '
      'Re-export from the source Mac with the current app version.',
    );
  }

  ConnectionProfileImportPreview buildImportPreview(
    ConnectionProfileBundle bundle,
    TunnelPlan existing,
    List<Profile> existingNodes,
  ) {
    validateBundleCompleteness(
      bundle,
      existingNodes.map((node) => node.id).toSet(),
    );

    final resolvedNodes = _resolveNodesForImport(
      bundle.nodes,
      bundle.secrets,
      existingNodes,
    );

    final remappedChains = bundle.chains
        .map((chain) => _remapChainNodeIds(chain, resolvedNodes.idRemap))
        .toList();

    final resolvedChains = _resolveChainsForImport(
      remappedChains,
      existing.chains,
    );

    final existingProfileIds = {for (final p in existing.profiles) p.id};
    final profiles = bundle.profiles.map((profile) {
      return ProfileImportRow(
        profile: _remapProfileChains(profile, resolvedChains.idRemap),
        hasIdConflict: existingProfileIds.contains(profile.id),
        action: existingProfileIds.contains(profile.id)
            ? ImportConflictAction.rename
            : ImportConflictAction.replace,
      );
    }).toList();

    return ConnectionProfileImportPreview(
      profiles: profiles,
      chains: resolvedChains.chains,
      nodes: resolvedNodes.nodes,
      secrets: resolvedNodes.secrets,
      nodesToAdd: resolvedNodes.nodes.length,
    );
  }

  ResolvedConnectionProfileImport resolveImport(
    ConnectionProfileImportPreview preview,
    TunnelPlan existing,
  ) {
    final existingProfileIds = {for (final p in existing.profiles) p.id};
    final reservedProfileIds = Set<String>.from(existingProfileIds);
    final profiles = <ConnectionProfile>[];

    for (final row in preview.profiles) {
      if (!row.selected || row.action == ImportConflictAction.skip) continue;

      final profile = row.profile;
      if (row.hasIdConflict) {
        switch (row.action) {
          case ImportConflictAction.replace:
            profiles.add(profile);
          case ImportConflictAction.rename:
            final newId = _uniqueId(
              '${profile.id}-imported',
              reservedProfileIds,
            );
            reservedProfileIds.add(newId);
            profiles.add(
              profile.copyWith(
                id: newId,
                name: _importedName(profile.name),
              ),
            );
          case ImportConflictAction.skip:
            break;
        }
      } else {
        profiles.add(profile);
        reservedProfileIds.add(profile.id);
      }
    }

    final existingChainIds = {for (final c in existing.chains) c.id};
    final chains = <Chain>[];
    for (final chain in preview.chains) {
      if (existingChainIds.contains(chain.id)) {
        final localChain = existing.chains.firstWhere((c) => c.id == chain.id);
        if (_chainsEqual(chain, localChain)) continue;
      }
      chains.add(chain);
    }

    return ResolvedConnectionProfileImport(
      profiles: profiles,
      chains: chains,
      nodes: preview.nodes,
      secrets: preview.secrets,
    );
  }

  bool profilesEqual(ConnectionProfile a, ConnectionProfile b) =>
      _planCodec.profileConnectConfigKey(a) ==
      _planCodec.profileConnectConfigKey(b);

  ({List<Profile> nodes, Map<String, String> secrets, Map<String, String> idRemap})
  _resolveNodesForImport(
    List<Profile> incoming,
    Map<String, String> incomingSecrets,
    List<Profile> existing,
  ) {
    final existingById = {for (final node in existing) node.id: node};
    final reservedIds = existingById.keys.toSet();
    final idRemap = <String, String>{};
    final nodes = <Profile>[];
    final secrets = <String, String>{};

    for (final node in incoming) {
      final local = existingById[node.id];
      if (local == null) {
        nodes.add(node);
        reservedIds.add(node.id);
        secrets.addAll(_secretsForNode(node, incomingSecrets));
        continue;
      }
      if (_nodesEqual(node, local)) {
        idRemap[node.id] = node.id;
        continue;
      }

      final newId = _uniqueId('${node.id}-imported', reservedIds);
      reservedIds.add(newId);
      idRemap[node.id] = newId;
      final renamed = _remapNodeId(node, newId);
      nodes.add(renamed);
      secrets.addAll(
        _remapNodeSecrets(node, renamed, incomingSecrets),
      );
    }

    return (nodes: nodes, secrets: secrets, idRemap: idRemap);
  }

  ({List<Chain> chains, Map<String, String> idRemap}) _resolveChainsForImport(
    List<Chain> incoming,
    List<Chain> existing,
  ) {
    final existingById = {for (final c in existing) c.id: c};
    final reservedIds = existingById.keys.toSet();
    final idRemap = <String, String>{};
    final chains = <Chain>[];

    for (final chain in incoming) {
      final local = existingById[chain.id];
      if (local == null) {
        chains.add(chain);
        reservedIds.add(chain.id);
        continue;
      }
      if (_chainsEqual(chain, local)) continue;

      final newId = _uniqueId('${chain.id}-imported', reservedIds);
      reservedIds.add(newId);
      idRemap[chain.id] = newId;
      chains.add(
        Chain(
          id: newId,
          name: _importedName(chain.name),
          hopProfileIds: chain.hopProfileIds,
        ),
      );
    }

    return (chains: chains, idRemap: idRemap);
  }

  Chain _remapChainNodeIds(Chain chain, Map<String, String> nodeIdRemap) {
    if (nodeIdRemap.isEmpty) return chain;
    return Chain(
      id: chain.id,
      name: chain.name,
      hopProfileIds: [
        for (final hop in chain.hopProfileIds) nodeIdRemap[hop] ?? hop,
      ],
    );
  }

  ConnectionProfile _remapProfileChains(
    ConnectionProfile profile,
    Map<String, String> idRemap,
  ) {
    if (idRemap.isEmpty) return profile;

    RouteTarget remapTarget(RouteTarget target) {
      if (target.isDirect || target.chainId == null) return target;
      final mapped = idRemap[target.chainId!];
      return mapped == null ? target : RouteTarget.chain(mapped);
    }

    final routing = RoutingPolicy(
      defaultTarget: remapTarget(profile.routing.defaultTarget),
      overrides: [
        for (final rule in profile.routing.overrides)
          rule.copyWith(target: remapTarget(rule.target)),
      ],
    );

    final dns = DnsPolicy(
      publicResolver: profile.dns.publicResolver,
      defaultUpstreamTag: profile.dns.defaultUpstreamTag,
      includeReverseZones: profile.dns.includeReverseZones,
      searchDomains: profile.dns.searchDomains,
      upstreams: [
        for (final upstream in profile.dns.upstreams)
          DnsUpstream(
            tag: upstream.tag,
            server: upstream.server,
            transport: upstream.transport,
            viaChainId: upstream.viaChainId == null
                ? null
                : idRemap[upstream.viaChainId!] ?? upstream.viaChainId,
          ),
      ],
      suffixRules: profile.dns.suffixRules,
    );

    return profile.copyWith(routing: routing, dns: dns);
  }

  Profile _remapNodeId(Profile node, String newId) {
    return switch (node) {
      VlessProfile profile => VlessProfile(
        id: newId,
        name: _importedName(profile.name),
        createdAt: profile.createdAt,
        host: profile.host,
        port: profile.port,
        uuidRef: SecretRef('profile.$newId.uuid'),
        security: profile.security,
        sni: profile.sni,
        publicKeyRef: profile.publicKeyRef == null
            ? null
            : SecretRef('profile.$newId.pbk'),
        shortId: profile.shortId,
        fingerprint: profile.fingerprint,
        flow: profile.flow,
        transport: profile.transport,
        grpcServiceName: profile.grpcServiceName,
        grpcAuthority: profile.grpcAuthority,
        transportPath: profile.transportPath,
        transportHost: profile.transportHost,
      ),
      WireGuardProfile profile => WireGuardProfile(
        id: newId,
        name: _importedName(profile.name),
        createdAt: profile.createdAt,
        addresses: profile.addresses,
        privateKeyRef: SecretRef('profile.$newId.priv'),
        peerPublicKey: profile.peerPublicKey,
        presharedKeyRef: profile.presharedKeyRef == null
            ? null
            : SecretRef('profile.$newId.psk'),
        endpointHost: profile.endpointHost,
        endpointPort: profile.endpointPort,
        allowedIps: profile.allowedIps,
        keepalive: profile.keepalive,
        mtu: profile.mtu,
        dnsServers: profile.dnsServers,
        searchDomains: profile.searchDomains,
        obfuscation: profile.obfuscation,
      ),
      _ => node,
    };
  }

  Map<String, String> _secretsForNode(
    Profile node,
    Map<String, String> incomingSecrets,
  ) {
    final result = <String, String>{};
    for (final key in profileSecretKeys(node)) {
      final value = incomingSecrets[key];
      if (value != null && value.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  Map<String, String> _remapNodeSecrets(
    Profile source,
    Profile target,
    Map<String, String> incomingSecrets,
  ) {
    final sourceKeys = profileSecretKeys(source).toList();
    final targetKeys = profileSecretKeys(target).toList();
    final result = <String, String>{};
    for (var i = 0; i < sourceKeys.length && i < targetKeys.length; i++) {
      final value = incomingSecrets[sourceKeys[i]];
      if (value != null && value.isNotEmpty) {
        result[targetKeys[i]] = value;
      }
    }
    return result;
  }

  bool _nodesEqual(Profile a, Profile b) =>
      jsonEncode(_profileCodec.encode(a)) == jsonEncode(_profileCodec.encode(b));

  bool _chainsEqual(Chain a, Chain b) =>
      a.id == b.id &&
      a.name == b.name &&
      _listEquals(a.hopProfileIds, b.hopProfileIds);

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _uniqueId(String base, Set<String> reserved) {
    if (!reserved.contains(base)) return base;
    var n = 2;
    while (reserved.contains('$base-$n')) {
      n++;
    }
    return '$base-$n';
  }

  String _importedName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Imported profile';
    if (trimmed.endsWith(' (imported)')) return trimmed;
    return '$trimmed (imported)';
  }
}

final connectionProfileTransferServiceProvider =
    Provider<ConnectionProfileTransferService>(
      (ref) => ConnectionProfileTransferService(),
    );
