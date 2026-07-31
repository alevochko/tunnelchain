import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/target_kind.dart';
import 'package:tunnel_chain/domain/validators/validation_exception.dart';

class RoutingValidator {
  void validate(RoutingPolicy policy, Set<String> chainIds) {
    void checkTarget(String context, RouteTarget target) {
      if (target.kind == TargetKind.chain) {
        final id = target.chainId;
        if (id == null || id.isEmpty) {
          throw ValidationException('$context: chain target has no chainId');
        }
        if (!chainIds.contains(id)) {
          throw ValidationException('$context: unknown chain "$id"');
        }
      }
    }

    checkTarget('Default route', policy.defaultTarget);

    final orders = <int>{};
    for (final rule in policy.overrides) {
      if (!orders.add(rule.order)) {
        throw ValidationException(
          'Duplicate rule order ${rule.order} in routing overrides',
        );
      }
      checkTarget('Rule order ${rule.order}', rule.target);

      if (rule.matcher.values.isEmpty) {
        throw ValidationException(
          'Rule order ${rule.order} has empty matcher values',
        );
      }
    }
  }
}
