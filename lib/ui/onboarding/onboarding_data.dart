class OnboardingStepData {
  const OnboardingStepData({
    required this.kicker,
    required this.title,
    required this.body,
    required this.nextLabel,
  });

  final String kicker;
  final String title;
  final String body;
  final String nextLabel;
}

const onboardingSteps = <OnboardingStepData>[
  OnboardingStepData(
    kicker: '01 · NODES',
    title: 'Add your proxy and VPN nodes',
    body:
        'Pick a protocol or import a config to add proxy and VPN nodes. '
        'Everything you save lands in Saved nodes, ready to chain on the next screen. '
        'Keys stay on your Mac — nothing is uploaded or shared.',
    nextLabel: 'Next: build a chain',
  ),
  OnboardingStepData(
    kicker: '02 · CHAINS',
    title: 'Chain the hops in order',
    body:
        'On Chains, arrange nodes into a path from your Mac to the internet. '
        'Add as many hops as you need and reorder them until the route looks right. '
        'TunnelChain pings every hop so you see latency before connecting.',
    nextLabel: 'Next: make a profile',
  ),
  OnboardingStepData(
    kicker: '03 · PROFILES',
    title: 'Wrap it in a profile',
    body:
        'Profiles bind a chain to routing and DNS — full tunnel or split rules for '
        'specific domains and subnets. Keep separate profiles for everyday browsing and '
        'work; tap a card on the Profiles screen to make it active.',
    nextLabel: 'Next: connect',
  ),
  OnboardingStepData(
    kicker: '04 · EVERYDAY',
    title: "Connect, then forget it's there",
    body:
        'Hit Connect on Status — if the tunnel fails, settings roll back automatically. '
        'After that, the menu bar icon shows state at a glance: switch profiles or '
        'disconnect without opening the main window.',
    nextLabel: 'Start using TunnelChain',
  ),
];

/// Demo labels used across onboarding previews (abstract, no real endpoints).
abstract final class OnboardingDemoData {
  static const homeProxy = 'Home proxy';
  static const officeVpn = 'Office VPN';
  static const officeViaHome = 'Office via Home';
  static const everydayBrowsing = 'Everyday browsing';
  static const officeNetwork = 'Office network';
  static const homeWifi = 'Home Wi‑Fi';

  static const homeProxyEndpoint = 'proxy.example.com:443';
  static const officeVpnEndpoint = 'vpn.office.example:51820';
}
