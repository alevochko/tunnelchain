import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/vless_profile.dart';
import 'package:tunnel_chain/domain/models/wire_guard_profile.dart';

/// Keychain record ids referenced by a profile.
Iterable<String> profileSecretKeys(Profile profile) sync* {
  switch (profile) {
    case VlessProfile p:
      yield p.uuidRef.key;
      if (p.publicKeyRef != null) yield p.publicKeyRef!.key;
    case WireGuardProfile p:
      yield p.privateKeyRef.key;
      if (p.presharedKeyRef != null) yield p.presharedKeyRef!.key;
    default:
      break;
  }
}
