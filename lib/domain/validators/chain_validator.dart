import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/validators/validation_exception.dart';

class ChainValidator {
  /// FR-8: validates hop protocol uniqueness, profile existence, no repeats.
  void validate(Chain chain, Map<String, Profile> profiles) {
    if (chain.hopProfileIds.isEmpty) {
      throw ValidationException('Chain "${chain.name}" has no hops');
    }

    final seenProfiles = <String>{};
    final protocols = <String>{};

    for (final profileId in chain.hopProfileIds) {
      if (!seenProfiles.add(profileId)) {
        throw ValidationException(
          'Chain "${chain.name}" references profile "$profileId" more than once',
        );
      }

      final profile = profiles[profileId];
      if (profile == null) {
        throw ValidationException(
          'Chain "${chain.name}" references unknown profile "$profileId"',
        );
      }

      final protocolName = profile.protocol.name;
      if (!protocols.add(protocolName)) {
        throw ValidationException(
          'Chain "${chain.name}" repeats protocol $protocolName '
          '(VLESS→VLESS and WG→WG are not allowed)',
        );
      }
    }
  }
}
