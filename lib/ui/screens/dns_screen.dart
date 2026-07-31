import 'package:flutter/material.dart';
import 'package:tunnel_chain/core_config/config_constants.dart';
import 'package:tunnel_chain/demo/sample_tunnel.dart';
import 'package:tunnel_chain/ui/widgets/placeholder_screen.dart';
import 'package:tunnel_chain/ui/widgets/section_overline.dart';
import 'package:tunnel_chain/ui/widgets/verdict_card.dart';

class DnsScreen extends StatelessWidget {
  const DnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dns = SampleTunnel.tunnelConfig.dns;
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'Menlo',
    );

    return PlaceholderScreen(
      title: 'DNS',
      subtitle: 'Resolver upstreams, suffix rules and search domains.',
      child: ListView(
        children: [
          const SectionOverline('Upstream resolvers'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final upstream in dns.upstreams)
                  ListTile(
                    title: Text(upstream.tag, style: mono),
                    subtitle: Text(
                      '${upstream.server} · ${upstream.transport.name}'
                      '${upstream.viaChainId != null ? ' · via ${upstream.viaChainId}' : ''}',
                      style: mono,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionOverline('Suffix rules'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final rule in dns.suffixRules)
                  ListTile(
                    title: Text(rule.suffixes.join(', '), style: mono),
                    trailing: Text(rule.upstreamTag, style: mono),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionOverline('Search domains'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final domain in dns.searchDomains)
                Chip(label: Text(domain), deleteIcon: const Icon(Icons.close, size: 16)),
            ],
          ),
          const SizedBox(height: 20),
          const VerdictCard(
            title: 'Route all DNS to corporate resolver',
            body:
                'Every lookup, including personal browsing, becomes visible to the corporate resolver and adds load to it.',
          ),
          const SizedBox(height: 12),
          Text(
            'System DNS pin: ${ConfigConstants.dnsPinIp} · when connected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'Menlo'),
          ),
        ],
      ),
    );
  }
}
