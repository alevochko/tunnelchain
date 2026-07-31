/// Core + tunnel lifecycle states (AR §8.2).
enum TunnelState {
  stopped,
  validating,
  starting,
  running,
  degraded,
  failed,
  awaitingConfirm,
  confirmed,
  resetting,
  killSwitchEngaged,
}

extension TunnelStateLabel on TunnelState {
  String get label => switch (this) {
    TunnelState.stopped => 'Stopped',
    TunnelState.validating => 'Validating',
    TunnelState.starting => 'Starting',
    TunnelState.running => 'Running',
    TunnelState.degraded => 'Degraded',
    TunnelState.failed => 'Failed',
    TunnelState.awaitingConfirm => 'Awaiting confirmation',
    TunnelState.confirmed => 'Confirmed',
    TunnelState.resetting => 'Resetting',
    TunnelState.killSwitchEngaged => 'Kill switch engaged',
  };

  bool get isConnected =>
      this == TunnelState.running ||
      this == TunnelState.degraded ||
      this == TunnelState.awaitingConfirm ||
      this == TunnelState.confirmed;

  bool get isLive =>
      isConnected || this == TunnelState.killSwitchEngaged;
}
