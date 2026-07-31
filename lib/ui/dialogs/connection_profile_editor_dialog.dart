import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/dns_resolver_utils.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/dns_policy.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/state/tunnel_catalog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tunnel_chain/ui/dialogs/routing_rule_editor_dialog.dart';
import 'package:tunnel_chain/ui/widgets/design_segmented_control.dart';
import 'package:tunnel_chain/ui/widgets/section_overline.dart';

Future<void> showConnectionProfileEditorDialog(
  BuildContext context, {
  ConnectionProfile? existing,
  ConnectionProfile? cloneFrom,
}) async {
  assert(
    existing == null || cloneFrom == null,
    'Use either existing or cloneFrom, not both',
  );
  await showDialog<void>(
    context: context,
    builder: (ctx) => _ConnectionProfileEditorDialog(
      existing: existing,
      cloneFrom: cloneFrom,
    ),
  );
}

enum _ProfileMode { simple, advanced }

class _ConnectionProfileEditorDialog extends ConsumerStatefulWidget {
  const _ConnectionProfileEditorDialog({
    this.existing,
    this.cloneFrom,
  });

  final ConnectionProfile? existing;
  final ConnectionProfile? cloneFrom;

  bool get isClone => cloneFrom != null;

  ConnectionProfile? get _template => existing ?? cloneFrom;

  @override
  ConsumerState<_ConnectionProfileEditorDialog> createState() =>
      _ConnectionProfileEditorDialogState();
}

class _ConnectionProfileEditorDialogState
    extends ConsumerState<_ConnectionProfileEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _dnsController;
  late _ProfileMode _mode;
  late RoutingPolicy _routing;
  String? _simpleChainId;
  String? _localError;

  static const _directKey = '__direct__';

  @override
  void initState() {
    super.initState();
    final template = widget._template;
    final defaultName = template == null
        ? ''
        : widget.isClone
            ? '${template.name} (copy)'
            : template.name;
    _nameController = TextEditingController(text: defaultName);
    _dnsController = TextEditingController(
      text: template?.dns.publicResolver ?? '1.1.1.1',
    );

    if (template != null && template.isSimpleFullTunnel) {
      _mode = _ProfileMode.simple;
      _simpleChainId = template.simpleChainId;
      _routing = widget.isClone
          ? template.routing.deepCopy()
          : template.routing;
    } else if (template != null) {
      _mode = _ProfileMode.advanced;
      _routing = widget.isClone
          ? template.routing.deepCopy()
          : template.routing;
      _simpleChainId = null;
    } else {
      _mode = _ProfileMode.simple;
      _routing = const RoutingPolicy(defaultTarget: RouteTarget.direct());
      _simpleChainId = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tunnel = ref.watch(tunnelCatalogProvider);
    final chains = tunnel.plan.chains;
    final busy = tunnel.busy;
    final chainById = {for (final c in chains) c.id: c};
    final sorted = _routing.sortedOverrides();

    if (_mode == _ProfileMode.simple &&
        _simpleChainId == null &&
        chains.isNotEmpty) {
      _simpleChainId = chains.first.id;
    }

    return AlertDialog(
      title: Text(
        widget.isClone
            ? 'Clone profile'
            : widget.existing == null
                ? 'New profile'
                : 'Edit profile',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DesignSegmentedControl<_ProfileMode>(
                segments: const [
                  DesignSegmentOption(
                    value: _ProfileMode.simple,
                    label: 'Full tunnel',
                    icon: LucideIcons.shield,
                  ),
                  DesignSegmentOption(
                    value: _ProfileMode.advanced,
                    label: 'Split routing',
                    icon: LucideIcons.split,
                  ),
                ],
                selected: _mode,
                onChanged: busy
                    ? null
                    : (mode) => setState(() {
                        _mode = mode;
                        if (_mode == _ProfileMode.simple) {
                          if (_simpleChainId == null && chains.isNotEmpty) {
                            _simpleChainId = chains.first.id;
                          }
                        }
                      }),
              ),
              const SizedBox(height: 16),
              if (chains.isEmpty)
                Text(
                  'Create chains on the Chains screen first.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else if (_mode == _ProfileMode.simple) ...[
                Text(
                  'All traffic goes through one chain — standalone VPN/proxy.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _simpleChainId,
                  decoration: const InputDecoration(
                    labelText: 'Chain',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final chain in chains)
                      DropdownMenuItem(
                        value: chain.id,
                        child: Text(chain.name),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => _simpleChainId = value),
                ),
              ] else ...[
                Text(
                  'Route specific traffic to chains; everything else uses the default.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _routing.defaultTarget.isDirect
                      ? _directKey
                      : _routing.defaultTarget.chainId,
                  decoration: const InputDecoration(
                    labelText: 'Default route (catch-all)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _directKey,
                      child: Text('Direct (local network)'),
                    ),
                    for (final chain in chains)
                      DropdownMenuItem(
                        value: chain.id,
                        child: Text(chain.name),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _routing = RoutingPolicy(
                              defaultTarget: value == _directKey
                                  ? const RouteTarget.direct()
                                  : RouteTarget.chain(value),
                              overrides: _routing.overrides,
                            );
                          });
                        },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: SectionOverline('Routing rules')),
                    Text(
                      '${sorted.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _addRule(chains),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sorted.isEmpty)
                  Text(
                    'No rules yet. Example: .youtube.com → chain A, '
                    '.corp.local → chain B.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (var i = 0; i < sorted.length; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        sorted[i].matcher.values.join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${matcherTypeLabel(sorted[i].matcher.type)} → '
                        '${_targetLabel(sorted[i].target, chainById)}'
                        '${ruleDnsLabel(sorted[i].dns)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'Menlo',
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Move up',
                            onPressed: busy || i == 0
                                ? null
                                : () => _moveRule(sorted[i].order, up: true),
                            icon: const Icon(Icons.arrow_upward, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Move down',
                            onPressed: busy || i == sorted.length - 1
                                ? null
                                : () => _moveRule(sorted[i].order, up: false),
                            icon: const Icon(Icons.arrow_downward, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: busy
                                ? null
                                : () => _editRule(chains, sorted[i]),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: busy
                                ? null
                                : () => _deleteRule(sorted[i].order),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(
                  'First matching rule wins.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              const SectionOverline('DNS'),
              const SizedBox(height: 8),
              TextField(
                controller: _dnsController,
                decoration: const InputDecoration(
                  labelText: 'Public DNS resolver',
                  hintText: '1.1.1.1, 8.8.8.8',
                  border: OutlineInputBorder(),
                ),
              ),
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
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: Text(widget.isClone ? 'Save copy' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _addRule(List<Chain> chains) async {
    final rule = await showRoutingRuleEditorDialog(
      context,
      chains: chains,
    );
    if (rule == null || !mounted) return;
    setState(() {
      _routing = RoutingPolicy(
        defaultTarget: _routing.defaultTarget,
        overrides: renumberRoutingOverrides([
          ..._routing.overrides,
          RoutingRule(
            order: _routing.overrides.length,
            matcher: rule.matcher,
            target: rule.target,
          ),
        ]),
      );
    });
  }

  Future<void> _editRule(List<Chain> chains, RoutingRule existing) async {
    final rule = await showRoutingRuleEditorDialog(
      context,
      existing: existing,
      chains: chains,
    );
    if (rule == null || !mounted) return;
    setState(() {
      final overrides = _routing.overrides.map((r) {
        if (r.order != existing.order) return r;
        return RoutingRule(
          order: existing.order,
          matcher: rule.matcher,
          target: rule.target,
          dns: rule.dns,
        );
      }).toList();
      _routing = RoutingPolicy(
        defaultTarget: _routing.defaultTarget,
        overrides: overrides,
      );
    });
  }

  void _deleteRule(int order) {
    setState(() {
      _routing = RoutingPolicy(
        defaultTarget: _routing.defaultTarget,
        overrides: renumberRoutingOverrides(
          _routing.overrides.where((r) => r.order != order).toList(),
        ),
      );
    });
  }

  void _moveRule(int order, {required bool up}) {
    final sorted = _routing.sortedOverrides();
    final idx = sorted.indexWhere((r) => r.order == order);
    if (idx < 0) return;
    final swapWith = up ? idx - 1 : idx + 1;
    if (swapWith < 0 || swapWith >= sorted.length) return;

    final copy = List<RoutingRule>.from(sorted);
    final tmp = copy[idx];
    copy[idx] = copy[swapWith];
    copy[swapWith] = tmp;

    setState(() {
      _routing = RoutingPolicy(
        defaultTarget: _routing.defaultTarget,
        overrides: renumberRoutingOverrides(copy),
      );
    });
  }

  String _targetLabel(RouteTarget target, Map<String, Chain> chainById) {
    if (target.isDirect) return 'direct';
    return chainById[target.chainId]?.name ?? target.chainId ?? '—';
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _localError = 'Enter a profile name.');
      return;
    }

    final dns = _dnsController.text.trim();
    if (dns.isEmpty) {
      setState(() => _localError = 'Enter a DNS resolver.');
      return;
    }
    final resolvers = parsePublicResolvers(dns);
    if (resolvers.isEmpty) {
      setState(() => _localError = 'Enter a valid DNS resolver (e.g. 1.1.1.1).');
      return;
    }
    for (final resolver in resolvers) {
      if (!isPlausibleDnsServer(resolver)) {
        setState(() => _localError = 'Invalid DNS resolver: $resolver');
        return;
      }
    }
    final normalizedDns = formatPublicResolvers(resolvers);

    final chains = ref.read(tunnelCatalogProvider).plan.chains;
    late final RoutingPolicy routing;

    if (_mode == _ProfileMode.simple) {
      if (_simpleChainId == null || chains.isEmpty) {
        setState(() => _localError = 'Select a chain for full tunnel.');
        return;
      }
      routing = RoutingPolicy(
        defaultTarget: RouteTarget.chain(_simpleChainId!),
        overrides: const [],
      );
    } else {
      routing = _routing;
    }

    final existing = widget.existing;
    final dnsBase =
        existing?.dns ?? widget.cloneFrom?.dns ?? const DnsPolicy();
    final profile = ConnectionProfile(
      id: existing?.id ?? 'profile-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      routing: routing,
      dns: dnsBase.copyWith(publicResolver: normalizedDns),
    );

    final ok = await ref.read(tunnelCatalogProvider.notifier).saveProfile(
      profile,
      previousId: existing?.id,
    );
    if (!context.mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _localError = ref.read(tunnelCatalogProvider).errorMessage ??
            'Could not save profile.';
      });
    }
  }
}

extension on DnsPolicy {
  DnsPolicy copyWith({String? publicResolver}) {
    return DnsPolicy(
      publicResolver: publicResolver ?? this.publicResolver,
      defaultUpstreamTag: defaultUpstreamTag,
      includeReverseZones: includeReverseZones,
      searchDomains: searchDomains,
      upstreams: upstreams,
      suffixRules: suffixRules,
    );
  }
}
