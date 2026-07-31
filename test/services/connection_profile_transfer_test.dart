import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/demo/sample_tunnel.dart';
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
import 'package:tunnel_chain/domain/serialization/connection_profile_bundle_codec.dart';
import 'package:tunnel_chain/services/connection_profile_transfer_service.dart';
import 'package:tunnel_chain/services/profile_store.dart';
import 'package:tunnel_chain/services/tunnel_connect_builder.dart';
import 'package:tunnel_chain/services/tunnel_plan_migration.dart';
import 'package:tunnel_chain/services/tunnel_plan_seeder.dart';
import 'package:tunnel_chain/services/tunnel_plan_store.dart';

void main() {
  const codec = ConnectionProfileBundleCodec();
  final service = ConnectionProfileTransferService();

  const profileA = ConnectionProfile(
    id: 'profile-a',
    name: 'Work',
    routing: RoutingPolicy(defaultTarget: RouteTarget.chain('chain-1')),
  );

  const profileB = ConnectionProfile(
    id: 'profile-b',
    name: 'Home',
    routing: RoutingPolicy(defaultTarget: RouteTarget.chain('chain-2')),
  );

  const chain1 = Chain(
    id: 'chain-1',
    name: 'VLESS hop',
    hopProfileIds: ['node-1'],
  );

  const chain2 = Chain(
    id: 'chain-2',
    name: 'Nested hop',
    hopProfileIds: ['node-1', 'node-2'],
  );

  final node1 = VlessProfile(
    id: 'node-1',
    name: 'VPS',
    createdAt: DateTime.utc(2026, 1, 1),
    host: 'example.com',
    port: 443,
    uuidRef: const SecretRef('profile.node-1.uuid'),
    security: 'reality',
  );

  final node2 = WireGuardProfile(
    id: 'node-2',
    name: 'Inner',
    createdAt: DateTime.utc(2026, 1, 1),
    addresses: const ['10.0.0.2/32'],
    privateKeyRef: const SecretRef('profile.node-2.priv'),
    peerPublicKey: 'peer-public-key',
    endpointHost: 'wg.example',
    endpointPort: 51820,
    presharedKeyRef: const SecretRef('profile.node-2.psk'),
  );

  const sampleSecrets = {
    'secret.outer.uuid': '550e8400-e29b-41d4-a716-446655440000',
    'secret.outer.pbk': 'spOJjek2S_Zkx2eDVA7r57OqpqmcU8_tdVzXW0-vJ0I',
    'secret.inner.priv': 'EOneqFYge/y/jHeEMNRjptzUUR5YeQrHVSt81CpZ0Eg=',
    'secret.inner.psk': '8DbDwZN+tJoLkjF77gGbBBO8xxLrqDfPWwvuWLLCaE8=',
  };

  TunnelPlan mergeResolved(
    TunnelPlan existing,
    ResolvedConnectionProfileImport resolved,
  ) {
    final chains = List<Chain>.from(existing.chains);
    for (final chain in resolved.chains) {
      final idx = chains.indexWhere((c) => c.id == chain.id);
      if (idx >= 0) {
        chains[idx] = chain;
      } else {
        chains.add(chain);
      }
    }

    final profiles = List<ConnectionProfile>.from(existing.profiles);
    for (final profile in resolved.profiles) {
      final idx = profiles.indexWhere((p) => p.id == profile.id);
      if (idx >= 0) {
        profiles[idx] = profile;
      } else {
        profiles.add(profile);
      }
    }

    return existing.copyWith(chains: chains, profiles: profiles);
  }

  group('ConnectionProfileBundleCodec', () {
    test('round-trip preserves profiles chains nodes and secrets', () {
      final bundle = ConnectionProfileBundle(
        profiles: const [profileA],
        chains: const [chain1],
        nodes: [node1],
        secrets: const {'profile.node-1.uuid': 'secret-uuid'},
        exportedAt: DateTime.utc(2026, 7, 31),
      );

      final decoded = codec.decode(codec.encode(bundle));
      expect(decoded.profiles.single.id, 'profile-a');
      expect(decoded.chains.single.hopProfileIds, ['node-1']);
      expect(decoded.nodes.single.id, 'node-1');
      expect(decoded.secrets['profile.node-1.uuid'], 'secret-uuid');
    });

    test('encode writes version 2 bundle type nodes and secrets', () {
      final json = codec.encode(
        ConnectionProfileBundle(
          profiles: const [profileA],
          chains: const [chain1],
          nodes: [node1],
          secrets: const {'profile.node-1.uuid': 'x'},
        ),
      );

      expect(json, contains('"version": 2'));
      expect(json, contains('"type": "tunnelchain.connection-profiles"'));
      expect(json, contains('"nodes"'));
      expect(json, contains('"secrets"'));
    });

    test('decode v1 bundle without nodes is supported', () {
      const raw = '''
{
  "version": 1,
  "type": "tunnelchain.connection-profiles",
  "profiles": [
    {
      "id": "profile-a",
      "name": "Work",
      "routing": {
        "defaultTarget": {"kind": "chain", "chainId": "chain-1"}
      },
      "dns": {}
    }
  ],
  "chains": [
    {"id": "chain-1", "name": "Hop", "hopProfileIds": ["node-1"]}
  ]
}
''';

      final decoded = codec.decode(raw);
      expect(decoded.nodes, isEmpty);
      expect(decoded.secrets, isEmpty);
      expect(decoded.profiles.single.id, 'profile-a');
    });

    test('decode rejects empty profiles list', () {
      expect(
        () => codec.decode(
          '{"version":1,"type":"tunnelchain.connection-profiles","profiles":[]}',
        ),
        throwsA(isA<ConnectionProfileBundleFormatException>()),
      );
    });

    test('decode rejects unknown bundle type', () {
      expect(
        () => codec.decode(
          '{"version":2,"type":"other","profiles":[{"id":"p","name":"P","routing":{"defaultTarget":{"kind":"direct"}},"dns":{}}]}',
        ),
        throwsA(
          isA<ConnectionProfileBundleFormatException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported file type'),
          ),
        ),
      );
    });

    test('decode rejects invalid json', () {
      expect(
        () => codec.decode('{not json'),
        throwsA(isA<ConnectionProfileBundleFormatException>()),
      );
    });
  });

  group('export', () {
    test('includes only chains and nodes referenced by exported profiles', () {
      const plan = TunnelPlan(
        profiles: [profileA, profileB],
        chains: [
          chain1,
          chain2,
          Chain(id: 'chain-unused', name: 'Unused', hopProfileIds: ['node-x']),
        ],
      );
      final extraNode = VlessProfile(
        id: 'node-x',
        name: 'Unused node',
        createdAt: DateTime.utc(2026, 1, 1),
        host: 'unused.example',
        port: 443,
        uuidRef: const SecretRef('profile.node-x.uuid'),
        security: 'reality',
      );

      final bundle = service.buildExportBundle(
        plan,
        [node1, node2, extraNode],
        profiles: [profileA],
        secrets: const {
          'profile.node-1.uuid': 'a',
          'profile.node-2.priv': 'b',
          'profile.node-x.uuid': 'c',
        },
      );

      expect(bundle.profiles.map((p) => p.id), ['profile-a']);
      expect(bundle.chains.map((c) => c.id), ['chain-1']);
      expect(bundle.nodes.map((n) => n.id), ['node-1']);
      expect(bundle.secrets.keys, ['profile.node-1.uuid']);
    });

    test('export all profiles includes union of dependencies', () {
      const plan = TunnelPlan(
        profiles: [profileA, profileB],
        chains: [chain1, chain2],
      );

      final bundle = service.buildExportBundle(
        plan,
        [node1, node2],
        secrets: const {
          'profile.node-1.uuid': 'a',
          'profile.node-2.priv': 'b',
          'profile.node-2.psk': 'c',
        },
      );

      expect(bundle.profiles, hasLength(2));
      expect(bundle.chains.map((c) => c.id), containsAll(['chain-1', 'chain-2']));
      expect(bundle.nodes.map((n) => n.id), containsAll(['node-1', 'node-2']));
      expect(bundle.secrets.keys, hasLength(3));
    });

    test('encodeBundle and decodeBundle round-trip through json string', () {
      final bundle = service.buildExportBundle(
        const TunnelPlan(profiles: [profileA], chains: [chain1]),
        [node1],
        secrets: const {'profile.node-1.uuid': 'uuid'},
      );

      final restored = service.decodeBundle(service.encodeBundle(bundle));
      expect(restored.profiles.single.name, 'Work');
      expect((restored.nodes.single as VlessProfile).host, 'example.com');
      expect(restored.secrets['profile.node-1.uuid'], 'uuid');
    });
  });

  group('import preview and resolve', () {
    test('renames connection profile on id conflict by default', () {
      const existing = TunnelPlan(profiles: [profileA], chains: [chain1]);
      const incoming = ConnectionProfileBundle(
        profiles: [
          ConnectionProfile(
            id: 'profile-a',
            name: 'Imported work',
            routing: RoutingPolicy(defaultTarget: RouteTarget.chain('chain-1')),
          ),
        ],
        chains: [chain1],
      );

      final preview = service.buildImportPreview(incoming, existing, [node1]);
      expect(preview.profiles.single.hasIdConflict, isTrue);
      expect(preview.profiles.single.action, ImportConflictAction.rename);

      final resolved = service.resolveImport(preview, existing);
      expect(resolved.profiles.single.id, 'profile-a-imported');
      expect(resolved.profiles.single.name, 'Imported work (imported)');
      expect(resolved.chains, isEmpty);
    });

    test('replace overwrites existing connection profile', () {
      const existing = TunnelPlan(profiles: [profileA], chains: [chain1]);
      const incoming = ConnectionProfileBundle(
        profiles: [
          ConnectionProfile(
            id: 'profile-a',
            name: 'Replaced',
            routing: RoutingPolicy(defaultTarget: RouteTarget.direct()),
          ),
        ],
        chains: const [],
        nodes: const [],
      );

      final preview = service.buildImportPreview(incoming, existing, [node1]);
      preview.profiles.single.action = ImportConflictAction.replace;

      final resolved = service.resolveImport(preview, existing);
      expect(resolved.profiles.single.name, 'Replaced');
      expect(resolved.profiles.single.id, 'profile-a');
      expect(resolved.profiles.single.routing.defaultTarget.isDirect, isTrue);
    });

    test('skip excludes connection profile from resolved import', () {
      const existing = TunnelPlan(profiles: [profileA], chains: [chain1]);
      const incoming = ConnectionProfileBundle(
        profiles: [
          ConnectionProfile(
            id: 'profile-a',
            name: 'Skipped',
            routing: RoutingPolicy(defaultTarget: RouteTarget.chain('chain-1')),
          ),
        ],
        chains: [chain1],
      );

      final preview = service.buildImportPreview(incoming, existing, [node1]);
      preview.profiles.single.action = ImportConflictAction.skip;

      final resolved = service.resolveImport(preview, existing);
      expect(resolved.profiles, isEmpty);
    });

    test('auto-adds missing nodes with secrets', () {
      const existing = TunnelPlan(profiles: [profileA], chains: [chain1]);
      final incoming = ConnectionProfileBundle(
        profiles: const [profileA],
        chains: const [chain1],
        nodes: [node1, node2],
        secrets: const {
          'profile.node-1.uuid': 'uuid-1',
          'profile.node-2.priv': 'priv',
          'profile.node-2.psk': 'psk',
        },
      );

      final preview = service.buildImportPreview(incoming, existing, const []);
      expect(preview.nodesToAdd, 2);
      expect(preview.nodes.map((n) => n.id), containsAll(['node-1', 'node-2']));
      expect(preview.secrets['profile.node-2.psk'], 'psk');
    });

    test('skips identical nodes already in catalog', () {
      const existing = TunnelPlan(profiles: [profileA], chains: [chain1]);
      final incoming = ConnectionProfileBundle(
        profiles: const [profileA],
        chains: const [chain1],
        nodes: [node1],
        secrets: const {'profile.node-1.uuid': 'secret-uuid'},
      );

      final preview = service.buildImportPreview(incoming, existing, [node1]);
      expect(preview.nodes, isEmpty);
      expect(preview.nodesToAdd, 0);
    });

    test('renames conflicting node and remaps secret keys', () {
      const existing = TunnelPlan(profiles: [profileA], chains: [chain1]);
      final conflictingLocal = VlessProfile(
        id: 'node-1',
        name: 'Local VPS',
        createdAt: DateTime.utc(2025, 1, 1),
        host: 'local.example',
        port: 443,
        uuidRef: const SecretRef('profile.node-1.uuid'),
        security: 'reality',
      );
      final incoming = ConnectionProfileBundle(
        profiles: const [profileA],
        chains: const [chain1],
        nodes: [node1],
        secrets: const {'profile.node-1.uuid': 'incoming-uuid'},
      );

      final preview = service.buildImportPreview(
        incoming,
        existing,
        [conflictingLocal],
      );
      expect(preview.nodes, hasLength(1));
      expect(preview.nodes.single.id, 'node-1-imported');
      expect(
        (preview.nodes.single as VlessProfile).uuidRef.key,
        'profile.node-1-imported.uuid',
      );
      expect(preview.secrets['profile.node-1-imported.uuid'], 'incoming-uuid');
      expect(
        preview.chains.single.hopProfileIds,
        ['node-1-imported'],
      );
    });

    test('renames conflicting chain and remaps profile and dns refs', () {
      const existing = TunnelPlan(profiles: [profileA], chains: [chain1]);
      final incoming = ConnectionProfileBundle(
        profiles: [
          ConnectionProfile(
            id: 'profile-b',
            name: 'Split',
            routing: RoutingPolicy(
              defaultTarget: RouteTarget.chain('chain-1'),
            ),
            dns: DnsPolicy(
              upstreams: const [
                DnsUpstream(
                  tag: 'dns-internal',
                  server: '10.0.0.53',
                  viaChainId: 'chain-1',
                ),
              ],
            ),
          ),
        ],
        chains: const [
          Chain(
            id: 'chain-1',
            name: 'Different hops',
            hopProfileIds: ['node-2'],
          ),
        ],
        nodes: [node2],
        secrets: const {
          'profile.node-2.priv': 'priv',
          'profile.node-2.psk': 'psk',
        },
      );

      final preview = service.buildImportPreview(incoming, existing, const []);
      expect(preview.chains.single.id, 'chain-1-imported');
      expect(
        preview.profiles.single.profile.routing.defaultTarget.chainId,
        'chain-1-imported',
      );
      expect(
        preview.profiles.single.profile.dns.upstreams.single.viaChainId,
        'chain-1-imported',
      );
    });

    test('validateBundleCompleteness rejects legacy files without nodes', () {
      const bundle = ConnectionProfileBundle(
        profiles: [profileA],
        chains: [chain1],
      );

      expect(
        () => service.validateBundleCompleteness(bundle, const {}),
        throwsA(isA<ConnectionProfileBundleFormatException>()),
      );
    });

    test('validateBundleCompleteness passes legacy file when nodes exist locally', () {
      const bundle = ConnectionProfileBundle(
        profiles: [profileA],
        chains: [chain1],
      );

      expect(
        () => service.validateBundleCompleteness(bundle, {'node-1'}),
        returnsNormally,
      );
    });
  });

  group('full export → import round-trip', () {
    late TunnelPlan sourcePlan;
    late List<Profile> sourceNodes;

    setUp(() {
      sourceNodes = SampleTunnel.profiles.values.toList();
      sourcePlan = TunnelPlanMigration.ensureProfiles(
        const TunnelPlanSeeder().seed(sourceNodes),
      );
    });

    test('restores full config on empty destination catalog', () {
      final exported = service.buildExportBundle(
        sourcePlan,
        sourceNodes,
        secrets: sampleSecrets,
      );
      final decoded = service.decodeBundle(service.encodeBundle(exported));

      final preview = service.buildImportPreview(
        decoded,
        const TunnelPlan(),
        const [],
      );
      final resolved = service.resolveImport(preview, const TunnelPlan());

      expect(resolved.nodes.map((n) => n.id), containsAll(sourceNodes.map((n) => n.id)));
      expect(resolved.chains.map((c) => c.id), containsAll(sourcePlan.chains.map((c) => c.id)));
      expect(
        resolved.profiles.map((p) => p.id),
        containsAll(sourcePlan.profiles.map((p) => p.id)),
      );
      expect(resolved.secrets, sampleSecrets);
    });

    test('merged import can build connect bundle', () async {
      final exported = service.buildExportBundle(
        sourcePlan,
        sourceNodes,
        secrets: sampleSecrets,
      );
      final decoded = service.decodeBundle(service.encodeBundle(exported));
      final preview = service.buildImportPreview(
        decoded,
        const TunnelPlan(),
        const [],
      );
      final resolved = service.resolveImport(preview, const TunnelPlan());

      final nodeStore = LocalProfileStore();
      await nodeStore.save(resolved.nodes);
      final mergedPlan = mergeResolved(const TunnelPlan(), resolved);

      final bundle = TunnelConnectBuilder().build(
        profiles: await nodeStore.load(),
        plan: mergedPlan,
      );

      expect(bundle, isNotNull);
      expect(bundle!.chains, isNotEmpty);
      expect(bundle.profiles, hasLength(2));
    });

    test('persists nodes and tunnel plan into local stores', () async {
      final exported = service.buildExportBundle(
        sourcePlan,
        sourceNodes,
        secrets: sampleSecrets,
      );
      final decoded = service.decodeBundle(service.encodeBundle(exported));
      final preview = service.buildImportPreview(
        decoded,
        const TunnelPlan(),
        const [],
      );
      final resolved = service.resolveImport(preview, const TunnelPlan());

      final nodeStore = LocalProfileStore();
      final planStore = LocalTunnelPlanStore();
      await nodeStore.save(resolved.nodes);
      await planStore.save(mergeResolved(await planStore.load(), resolved));

      final storedNodes = await nodeStore.load();
      final storedPlan = await planStore.load();

      expect(storedNodes, hasLength(2));
      expect(storedPlan.chains, hasLength(sourcePlan.chains.length));
      expect(storedPlan.profiles, hasLength(sourcePlan.profiles.length));
    });
  });
}
