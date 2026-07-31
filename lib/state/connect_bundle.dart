import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/core_config/config_generator.dart';
import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/domain/profile_secrets.dart';
import 'package:tunnel_chain/services/tunnel_bundle_builder.dart';
import 'package:tunnel_chain/services/tunnel_connect_builder.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';

/// Resolved tunnel config for Connect — depends on profiles + plan, no import cycle.
final connectBundleProvider = Provider<ConnectBundle?>((ref) {
  final profiles = ref.watch(profileCatalogProvider).profiles;
  final plan = ref.watch(tunnelCatalogProvider).plan;
  if (profiles.isEmpty || plan.activeProfile == null) return null;
  try {
    return TunnelConnectBuilder().build(profiles: profiles, plan: plan);
  } catch (_) {
    return null;
  }
});

final canConnectProvider = Provider<bool>(
  (ref) => ref.watch(connectBundleProvider) != null,
);

Future<MapSecretResolver> loadConnectSecrets(Ref ref) async {
  final bundle = ref.read(connectBundleProvider);
  if (bundle == null) {
    throw StateError('No connect bundle — configure a chain with VLESS first');
  }
  final keychain = ref.read(keychainStoreProvider);
  final keys = <String>{};
  for (final profile in bundle.profiles.values) {
    keys.addAll(profileSecretKeys(profile));
  }
  final map = await keychain.getSecrets(keys);
  final stillMissing = keys.where((k) => map[k]?.isNotEmpty != true).toList();
  if (stillMissing.isNotEmpty) {
    throw StateError(
      'Secrets missing in Keychain: ${stillMissing.join(', ')}. '
      'Delete and re-import nodes on the Nodes screen.',
    );
  }
  return MapSecretResolver(map);
}

String generateConnectConfigJson(Ref ref, MapSecretResolver secrets) {
  final bundle = ref.read(connectBundleProvider);
  if (bundle == null) {
    throw StateError('No connect bundle — configure a chain with VLESS first');
  }
  final config = ConfigGenerator().generate(
    profiles: bundle.profiles,
    chains: bundle.chains,
    tunnel: bundle.tunnel,
    secrets: secrets,
  );
  return const JsonEncoder.withIndent('  ').convert(config);
}
