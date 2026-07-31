import 'dart:io';

import 'package:flutter/services.dart';

/// Applies native macOS rounded window chrome (see [WindowChrome.swift]).
abstract final class WindowChromeService {
  static const cornerRadius = 20.0;

  static const _channel = MethodChannel('com.tunnelchain/window_chrome');

  static Future<void> apply() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('apply');
    } catch (_) {
      // Native channel not ready during early startup.
    }
  }
}
