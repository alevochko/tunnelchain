import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/protocol_kind.dart';

class Chain {
  const Chain({
    required this.id,
    required this.name,
    required this.hopProfileIds,
  });

  final String id;
  final String name;
  final List<String> hopProfileIds;

  Set<ProtocolKind> protocols(Map<String, Profile> profiles) {
    return hopProfileIds
        .map((id) => profiles[id]?.protocol)
        .whereType<ProtocolKind>()
        .toSet();
  }
}
