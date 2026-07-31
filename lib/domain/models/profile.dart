import 'package:tunnel_chain/domain/models/profile_kind.dart';
import 'package:tunnel_chain/domain/models/protocol_kind.dart';

/// Base connection profile.
abstract class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  ProfileKind get kind;
  ProtocolKind get protocol;
}
