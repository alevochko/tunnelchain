import 'package:flutter/services.dart';

/// macOS native file drop (Runner DragDropChannel — no CocoaPods plugin).
class NativeDragDrop {
  NativeDragDrop._();

  static const _channel = MethodChannel('com.tunnelchain/drag_drop');

  static void Function(String content)? onFileDropped;
  static void Function(bool dragging)? onDragState;

  static bool _installed = false;

  static void ensureInstalled() {
    if (_installed) return;
    _installed = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onFileDropped':
          final content = call.arguments as String?;
          if (content != null) onFileDropped?.call(content);
        case 'onDragState':
          final dragging = call.arguments as bool? ?? false;
          onDragState?.call(dragging);
      }
      return null;
    });
  }

  static Future<void> setListening(bool enabled) async {
    ensureInstalled();
    await _channel.invokeMethod<void>('setListening', enabled);
  }
}
