import 'package:flutter/services.dart';

/// Writes config outside the App Sandbox container (real ~/Library/Application Support).
abstract class ConfigStore {
  Future<String> configDirectory();
  Future<String> writeConfig(String content);
}

class MacConfigStore implements ConfigStore {
  MacConfigStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.tunnelchain/paths');

  final MethodChannel _channel;

  @override
  Future<String> configDirectory() async {
    final path = await _channel.invokeMethod<String>('getConfigDirectory');
    if (path == null || path.isEmpty) {
      throw StateError('config directory unavailable');
    }
    return path;
  }

  @override
  Future<String> writeConfig(String content) async {
    final path = await _channel.invokeMethod<String>('writeConfig', {
      'content': content,
    });
    if (path == null || path.isEmpty) {
      throw StateError('failed to write config');
    }
    return path;
  }
}

/// In-memory / temp store for unit tests.
class LocalConfigStore implements ConfigStore {
  LocalConfigStore({String? baseDir}) : _baseDir = baseDir ?? '/tmp/TunnelChain-test';

  final String _baseDir;
  String? _lastPath;

  @override
  Future<String> configDirectory() async => _baseDir;

  @override
  Future<String> writeConfig(String content) async {
    _lastPath = '$_baseDir/config.json';
    return _lastPath!;
  }

  String? get lastPath => _lastPath;
}
