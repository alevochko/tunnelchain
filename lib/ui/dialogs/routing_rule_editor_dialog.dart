import 'package:flutter/material.dart';
import 'package:tunnel_chain/domain/dns_resolver_utils.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/dns_upstream.dart';
import 'package:tunnel_chain/domain/models/matcher_type.dart';
import 'package:tunnel_chain/domain/models/rule_dns.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';

/// Returns a saved [RoutingRule] or `null` when cancelled.
Future<RoutingRule?> showRoutingRuleEditorDialog(
  BuildContext context, {
  RoutingRule? existing,
  required List<Chain> chains,
}) async {
  return showDialog<RoutingRule>(
    context: context,
    builder: (ctx) => _RoutingRuleEditorDialog(
      existing: existing,
      chains: chains,
    ),
  );
}

class _RoutingRuleEditorDialog extends StatefulWidget {
  const _RoutingRuleEditorDialog({
    this.existing,
    required this.chains,
  });

  final RoutingRule? existing;
  final List<Chain> chains;

  @override
  State<_RoutingRuleEditorDialog> createState() =>
      _RoutingRuleEditorDialogState();
}

class _RoutingRuleEditorDialogState extends State<_RoutingRuleEditorDialog> {
  late MatcherType _matcherType;
  late final TextEditingController _valuesController;
  late final TextEditingController _dnsController;
  late bool _useDirect;
  late bool _customDns;
  late DnsTransport _dnsTransport;
  late bool _dnsViaChain;
  String? _chainId;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _matcherType = existing?.matcher.type ?? MatcherType.domainSuffix;
    _valuesController = TextEditingController(
      text: existing?.matcher.values.join(', ') ?? '',
    );
    _dnsController = TextEditingController(
      text: existing?.dns?.server ?? '',
    );
    _useDirect = existing?.target.isDirect ?? false;
    _chainId = existing?.target.chainId;
    _customDns = existing?.dns != null;
    _dnsTransport = existing?.dns?.transport ?? DnsTransport.udp;
    _dnsViaChain = existing?.dns?.viaChain ?? true;
  }

  @override
  void dispose() {
    _valuesController.dispose();
    _dnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chains = widget.chains;
    final domainRule = _matcherType == MatcherType.domainSuffix;

    if (!_useDirect && _chainId == null && chains.isNotEmpty) {
      _chainId = chains.first.id;
    }

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add routing rule' : 'Edit rule'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<MatcherType>(
                value: _matcherType,
                decoration: const InputDecoration(
                  labelText: 'Match',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: MatcherType.ipCidr,
                    child: Text('IP / CIDR'),
                  ),
                  DropdownMenuItem(
                    value: MatcherType.domainSuffix,
                    child: Text('Domain suffix'),
                  ),
                  DropdownMenuItem(
                    value: MatcherType.port,
                    child: Text('Port'),
                  ),
                ],
                onChanged: (v) => setState(() => _matcherType = v ?? _matcherType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _valuesController,
                decoration: InputDecoration(
                  labelText: 'Values',
                  hintText: _valuesHint(_matcherType),
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _useDirect ? null : _chainId,
                decoration: const InputDecoration(
                  labelText: 'Send to',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Direct (no tunnel)'),
                  ),
                  for (final chain in chains)
                    DropdownMenuItem(
                      value: chain.id,
                      child: Text(chain.name),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _useDirect = id == null;
                  _chainId = id;
                }),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Custom DNS for matched domains'),
                subtitle: Text(
                  domainRule
                      ? 'Use a dedicated resolver for this rule; other domains use profile DNS.'
                      : 'Only available for domain suffix rules.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _customDns && domainRule,
                onChanged: domainRule
                    ? (v) => setState(() => _customDns = v ?? false)
                    : null,
              ),
              if (_customDns && domainRule) ...[
                TextField(
                  controller: _dnsController,
                  decoration: const InputDecoration(
                    labelText: 'DNS resolver',
                    hintText: '10.0.0.53, 10.0.0.54',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DnsTransport>(
                  value: _dnsTransport,
                  decoration: const InputDecoration(
                    labelText: 'Transport',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DnsTransport.udp,
                      child: Text('UDP (port 53)'),
                    ),
                    DropdownMenuItem(
                      value: DnsTransport.https,
                      child: Text('HTTPS (DoH)'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _dnsTransport = v ?? _dnsTransport),
                ),
                if (!_useDirect) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reach resolver via chain'),
                    subtitle: const Text(
                      'DNS queries go through the same chain as traffic.',
                    ),
                    value: _dnsViaChain,
                    onChanged: (v) => setState(() => _dnsViaChain = v),
                  ),
                ],
              ],
              if (_localError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _localError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _valuesHint(MatcherType type) => switch (type) {
    MatcherType.ipCidr => '10.0.0.0/8, 192.168.0.0/16',
    MatcherType.domainSuffix => '.corp.local, .office.example',
    MatcherType.port => '443, 8080',
    MatcherType.process => 'com.apple.Safari',
    MatcherType.geoip => 'private',
  };

  void _save() {
    final values = _parseValues(_valuesController.text);
    if (values.isEmpty) {
      setState(() => _localError = 'Enter at least one value.');
      return;
    }
    if (_matcherType == MatcherType.port) {
      for (final v in values) {
        final port = int.tryParse(v);
        if (port == null || port < 1 || port > 65535) {
          setState(() => _localError = 'Invalid port: $v');
          return;
        }
      }
    }

    if (!_useDirect) {
      if (_chainId == null || widget.chains.isEmpty) {
        setState(() => _localError = 'Select a chain or choose Direct.');
        return;
      }
    }

    RuleDns? ruleDns;
    if (_customDns && _matcherType == MatcherType.domainSuffix) {
      final resolvers = parsePublicResolvers(_dnsController.text.trim());
      if (resolvers.isEmpty) {
        setState(() => _localError = 'Enter a valid DNS resolver.');
        return;
      }
      for (final resolver in resolvers) {
        if (!isPlausibleDnsServer(resolver)) {
          setState(() => _localError = 'Invalid DNS resolver: $resolver');
          return;
        }
      }
      ruleDns = RuleDns(
        server: formatPublicResolvers(resolvers),
        transport: _dnsTransport,
        viaChain: _dnsViaChain && !_useDirect,
      );
    }

    final target = _useDirect
        ? const RouteTarget.direct()
        : RouteTarget.chain(_chainId!);

    Navigator.pop(
      context,
      RoutingRule(
        order: widget.existing?.order ?? 0,
        matcher: RuleMatcher(type: _matcherType, values: values),
        target: target,
        dns: ruleDns,
      ),
    );
  }

  static List<String> _parseValues(String text) {
    return text
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

String matcherTypeLabel(MatcherType type) => switch (type) {
  MatcherType.ipCidr => 'IP / CIDR',
  MatcherType.domainSuffix => 'Domain suffix',
  MatcherType.port => 'Port',
  MatcherType.process => 'Process',
  MatcherType.geoip => 'GeoIP',
};

String ruleDnsLabel(RuleDns? dns) {
  if (dns == null) return '';
  final via = dns.viaChain ? ' via chain' : '';
  return ' · DNS ${dns.server}$via';
}

List<RoutingRule> renumberRoutingOverrides(List<RoutingRule> rules) {
  final sorted = List<RoutingRule>.from(rules)
    ..sort((a, b) => a.order.compareTo(b.order));
  return [
    for (var i = 0; i < sorted.length; i++)
      RoutingRule(
        order: i,
        matcher: sorted[i].matcher,
        target: sorted[i].target,
        dns: sorted[i].dns,
      ),
  ];
}
