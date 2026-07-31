import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tunnel_chain/services/window_chrome_service.dart';
import 'package:window_manager/window_manager.dart';

/// Main window visibility for macOS (menu bar app).
abstract final class StatusBarService {
  static const fullWindowSize = Size(1180, 820);

  static bool _ready = false;

  static Future<void> ensureReady() async {
    if (_ready || !Platform.isMacOS) return;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    _ready = true;
  }

  static Future<void> configureMainWindow() async {
    if (!Platform.isMacOS) return;
    await ensureReady();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: fullWindowSize,
        center: true,
        title: 'TunnelChain',
        titleBarStyle: TitleBarStyle.normal,
      ),
      () async {
        await _applyChrome();
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  static Future<void> showMainWindow() async {
    if (!Platform.isMacOS) return;
    await ensureReady();
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(const Size(900, 640));
    await windowManager.setMaximumSize(const Size(4096, 4096));
    await windowManager.setResizable(true);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setSize(fullWindowSize);
    await _applyChrome();
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> hideMainWindow() async {
    if (!Platform.isMacOS) return;
    await windowManager.hide();
  }

  static Future<void> _applyChrome() async {
    await WindowChromeService.apply();
  }
}
