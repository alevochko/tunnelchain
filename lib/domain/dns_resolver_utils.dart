/// Parses user-entered public DNS resolver(s).
///
/// Accepts a single IP/hostname or a comma/space-separated list.
/// sing-box expects one address per upstream — the generator emits one
/// upstream per entry (tags `dns-public`, `dns-public-2`, …).
List<String> parsePublicResolvers(String raw) {
  return raw
      .split(RegExp(r'[,\s;]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

String formatPublicResolvers(List<String> resolvers) => resolvers.join(', ');

String primaryPublicResolver(String raw, {String fallback = '1.1.1.1'}) {
  final parsed = parsePublicResolvers(raw);
  return parsed.isEmpty ? fallback : parsed.first;
}

/// sing-box DNS tag for a public resolver at [index] (`dns-public`, `dns-public-2`, …).
String publicDnsUpstreamTag(int index) =>
    index == 0 ? 'dns-public' : 'dns-public-${index + 1}';

bool isPlausibleDnsServer(String value) {
  if (value.isEmpty) return false;
  // IPv4
  final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  if (ipv4.hasMatch(value)) return true;
  // IPv6 (loose)
  if (value.contains(':')) return true;
  // Hostname for DoH-style entries
  return RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(value);
}

/// sing-box 1.9+: leading dot keeps legacy prefix matching; strip it so
/// `corp.internal` matches apex + subdomains (`app.corp.internal`).
List<String> singBoxDomainSuffixes(Iterable<String> values) {
  return values
      .map((v) => v.startsWith('.') ? v.substring(1) : v)
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}
