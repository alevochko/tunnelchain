import 'package:flutter/services.dart';

/// Resolves bundled sing-box via Swift [Bundle.main] (UTF-8 safe).
Future<String?> resolveBundledSingBoxPath() async {
  const channel = MethodChannel('com.tunnelchain/paths');
  try {
    final path = await channel.invokeMethod<String>('getBundledSingBoxPath');
    if (path != null && path.isNotEmpty) return path;
  } catch (_) {}
  return null;
}
