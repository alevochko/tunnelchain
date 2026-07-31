import 'dart:convert';

import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/serialization/profile_codec.dart';
import 'package:tunnel_chain/domain/serialization/tunnel_plan_codec.dart';

/// Portable export bundle: connection profiles, chains, nodes, and secrets.
class ConnectionProfileBundle {
  const ConnectionProfileBundle({
    required this.profiles,
    required this.chains,
    this.nodes = const [],
    this.secrets = const {},
    this.exportedAt,
  });

  final List<ConnectionProfile> profiles;
  final List<Chain> chains;
  final List<Profile> nodes;
  final Map<String, String> secrets;
  final DateTime? exportedAt;

  ConnectionProfileBundle copyWith({
    List<ConnectionProfile>? profiles,
    List<Chain>? chains,
    List<Profile>? nodes,
    Map<String, String>? secrets,
    DateTime? exportedAt,
  }) {
    return ConnectionProfileBundle(
      profiles: profiles ?? this.profiles,
      chains: chains ?? this.chains,
      nodes: nodes ?? this.nodes,
      secrets: secrets ?? this.secrets,
      exportedAt: exportedAt ?? this.exportedAt,
    );
  }
}

class ConnectionProfileBundleFormatException implements Exception {
  ConnectionProfileBundleFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ConnectionProfileBundleCodec {
  const ConnectionProfileBundleCodec({
    TunnelPlanCodec? planCodec,
    ProfileCodec? profileCodec,
  }) : _planCodec = planCodec ?? const TunnelPlanCodec(),
       _profileCodec = profileCodec ?? const ProfileCodec();

  static const bundleType = 'tunnelchain.connection-profiles';
  static const currentVersion = 2;

  final TunnelPlanCodec _planCodec;
  final ProfileCodec _profileCodec;

  String encode(ConnectionProfileBundle bundle) {
    return const JsonEncoder.withIndent('  ').convert({
      'version': currentVersion,
      'type': bundleType,
      'exportedAt': (bundle.exportedAt ?? DateTime.now().toUtc())
          .toIso8601String(),
      'profiles': bundle.profiles.map(_planCodec.encodeProfile).toList(),
      'chains': bundle.chains.map(_planCodec.encodeChain).toList(),
      'nodes': bundle.nodes.map(_profileCodec.encode).toList(),
      if (bundle.secrets.isNotEmpty) 'secrets': bundle.secrets,
    });
  }

  ConnectionProfileBundle decode(String json) {
    final dynamic parsed;
    try {
      parsed = jsonDecode(json);
    } on FormatException catch (e) {
      throw ConnectionProfileBundleFormatException(
        'Invalid JSON: ${e.message}',
      );
    }

    if (parsed is! Map) {
      throw ConnectionProfileBundleFormatException(
        'Expected a JSON object at the root.',
      );
    }

    final map = Map<String, dynamic>.from(parsed);
    final type = map['type'] as String?;
    if (type != null && type != bundleType) {
      throw ConnectionProfileBundleFormatException(
        'Unsupported file type "$type". Expected "$bundleType".',
      );
    }

    final version = map['version'] as int? ?? 1;
    if (version > currentVersion) {
      throw ConnectionProfileBundleFormatException(
        'Unsupported bundle version $version (max $currentVersion).',
      );
    }

    final profileMaps = map['profiles'] as List? ?? const [];
    if (profileMaps.isEmpty) {
      throw ConnectionProfileBundleFormatException(
        'No profiles found in the file.',
      );
    }

    final profiles = profileMaps
        .whereType<Map>()
        .map((e) => _planCodec.decodeProfile(Map<String, dynamic>.from(e)))
        .toList();

    final chains = (map['chains'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => _planCodec.decodeChain(Map<String, dynamic>.from(e)))
        .toList();

    final nodes = (map['nodes'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => _profileCodec.decode(Map<String, dynamic>.from(e)))
        .toList();

    final secretsRaw = map['secrets'];
    final secrets = secretsRaw is Map
        ? secretsRaw.map((key, value) => MapEntry('$key', '$value'))
        : const <String, String>{};

    final exportedAtRaw = map['exportedAt'] as String?;
    final exportedAt =
        exportedAtRaw == null ? null : DateTime.tryParse(exportedAtRaw);

    return ConnectionProfileBundle(
      profiles: profiles,
      chains: chains,
      nodes: nodes,
      secrets: secrets,
      exportedAt: exportedAt,
    );
  }
}
