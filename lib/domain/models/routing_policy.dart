import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/rule_dns.dart';
import 'package:tunnel_chain/domain/models/target_kind.dart';

class RuleMatcher {
  const RuleMatcher({required this.type, required this.values});

  final MatcherType type;
  final List<String> values;
}

class RouteTarget {
  const RouteTarget.direct() : kind = TargetKind.direct, chainId = null;

  const RouteTarget.chain(this.chainId) : kind = TargetKind.chain;

  final TargetKind kind;
  final String? chainId;

  bool get isDirect => kind == TargetKind.direct;
}

class RoutingRule {
  const RoutingRule({
    required this.order,
    required this.matcher,
    required this.target,
    this.dns,
  });

  final int order;
  final RuleMatcher matcher;
  final RouteTarget target;

  /// Optional DNS for [MatcherType.domainSuffix] matches. Other matchers ignore it.
  final RuleDns? dns;

  RoutingRule copyWith({
    int? order,
    RuleMatcher? matcher,
    RouteTarget? target,
    RuleDns? dns,
    bool clearDns = false,
  }) {
    return RoutingRule(
      order: order ?? this.order,
      matcher: matcher ?? this.matcher,
      target: target ?? this.target,
      dns: clearDns ? null : (dns ?? this.dns),
    );
  }
}

class RoutingPolicy {
  const RoutingPolicy({required this.defaultTarget, this.overrides = const []});

  final RouteTarget defaultTarget;
  final List<RoutingRule> overrides;

  List<RoutingRule> sortedOverrides() {
    final copy = List<RoutingRule>.from(overrides);
    copy.sort((a, b) => a.order.compareTo(b.order));
    return copy;
  }

  Set<String> referencedChainIds() {
    final ids = <String>{};
    void collect(RouteTarget target) {
      if (target.kind == TargetKind.chain && target.chainId != null) {
        ids.add(target.chainId!);
      }
    }

    collect(defaultTarget);
    for (final rule in overrides) {
      collect(rule.target);
    }
    return ids;
  }

  RoutingPolicy deepCopy() {
    return RoutingPolicy(
      defaultTarget: defaultTarget,
      overrides: [
        for (final rule in overrides)
          rule.copyWith(
            matcher: RuleMatcher(
              type: rule.matcher.type,
              values: List<String>.from(rule.matcher.values),
            ),
          ),
      ],
    );
  }
}
