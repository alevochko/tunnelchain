import 'dart:io';

import 'package:flutter/services.dart';

/// Snapshot pushed to the native NSStatusItem menu.
class StatusBarMenuState {
  const StatusBarMenuState({
    required this.profiles,
    required this.activeProfileId,
    required this.connected,
    required this.canConnect,
    required this.canDisconnect,
    required this.busy,
    required this.switchOn,
    required this.switchEnabled,
    required this.statusLine,
    required this.connectSubtitle,
  });

  final List<({String id, String name})> profiles;
  final String? activeProfileId;
  final bool connected;
  final bool canConnect;
  final bool canDisconnect;
  final bool busy;
  final bool switchOn;
  final bool switchEnabled;
  final String statusLine;
  final String connectSubtitle;

  Map<String, dynamic> toJson() => {
    'profiles': [
      for (final profile in profiles)
        {'id': profile.id, 'name': profile.name},
    ],
    if (activeProfileId != null) 'activeProfileId': activeProfileId,
    'connected': connected,
    'canConnect': canConnect,
    'canDisconnect': canDisconnect,
    'busy': busy,
    'switchOn': switchOn,
    'switchEnabled': switchEnabled,
    'statusLine': statusLine,
    'connectSubtitle': connectSubtitle,
  };
}

typedef StatusBarActionHandler = Future<void> Function(String action, Object? arg);

/// Method channel bridge to [StatusBarMenuController] on macOS.
abstract final class NativeStatusBar {
  static const _channel = MethodChannel('com.tunnelchain/status_bar');

  static StatusBarActionHandler? _handler;

  static Future<void> install(StatusBarActionHandler handler) async {
    if (!Platform.isMacOS) return;
    _handler = handler;
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static Future<void> pushState(StatusBarMenuState state) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('updateState', state.toJson());
    } catch (_) {
      // Native menu not ready yet during startup.
    }
  }

  static Future<void> showWindow() async {
    if (!Platform.isMacOS) return;
    await _channel.invokeMethod('showWindow');
  }

  static Future<void> hideWindow() async {
    if (!Platform.isMacOS) return;
    await _channel.invokeMethod('hideWindow');
  }

  static Future<void> _onNativeCall(MethodCall call) async {
    final handler = _handler;
    if (handler == null) return;
    switch (call.method) {
      case 'selectProfile':
        await handler('selectProfile', call.arguments);
      case 'connect':
        await handler('connect', null);
      case 'disconnect':
        await handler('disconnect', null);
    }
  }
}
