import 'package:flutter/material.dart';
import 'package:tunnel_chain/app/theme/app_colors.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';

/// Tunnel connection states for UI (AR §8.2, design-system/pages/status.md).
enum TunnelVisualStatus {
  stopped,
  connecting,
  running,
  degraded,
  failed,
  awaitingConfirm,
  resetting,
}

TunnelVisualStatus mapTunnelState(TunnelState state) {
  return switch (state) {
    TunnelState.stopped => TunnelVisualStatus.stopped,
    TunnelState.validating || TunnelState.starting => TunnelVisualStatus.connecting,
    TunnelState.running || TunnelState.confirmed => TunnelVisualStatus.running,
    TunnelState.degraded => TunnelVisualStatus.degraded,
    TunnelState.failed => TunnelVisualStatus.failed,
    TunnelState.awaitingConfirm => TunnelVisualStatus.awaitingConfirm,
    TunnelState.resetting => TunnelVisualStatus.resetting,
  };
}

extension TunnelVisualStatusStyle on TunnelVisualStatus {
  Color color(Brightness brightness) {
    return switch (this) {
      TunnelVisualStatus.stopped => AppColors.stopped,
      TunnelVisualStatus.connecting => AppColors.accent,
      TunnelVisualStatus.running => AppColors.running,
      TunnelVisualStatus.degraded => AppColors.degraded,
      TunnelVisualStatus.failed => AppColors.failed,
      TunnelVisualStatus.awaitingConfirm => AppColors.degraded,
      TunnelVisualStatus.resetting => AppColors.accent,
    };
  }

  IconData get icon {
    return switch (this) {
      TunnelVisualStatus.stopped => Icons.radio_button_unchecked,
      TunnelVisualStatus.connecting => Icons.sync,
      TunnelVisualStatus.running => Icons.check_circle,
      TunnelVisualStatus.degraded => Icons.warning_amber_rounded,
      TunnelVisualStatus.failed => Icons.error_outline,
      TunnelVisualStatus.awaitingConfirm => Icons.timer_outlined,
      TunnelVisualStatus.resetting => Icons.restore,
    };
  }

  String get label {
    return switch (this) {
      TunnelVisualStatus.stopped => 'Stopped',
      TunnelVisualStatus.connecting => 'Connecting',
      TunnelVisualStatus.running => 'Running',
      TunnelVisualStatus.degraded => 'Degraded',
      TunnelVisualStatus.failed => 'Failed',
      TunnelVisualStatus.awaitingConfirm => 'Awaiting confirmation',
      TunnelVisualStatus.resetting => 'Resetting',
    };
  }
}
