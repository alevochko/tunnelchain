import 'dart:convert';

import 'package:flutter/services.dart';

/// Keychain storage for secrets (FR-4).
///
/// All profile secrets are stored in a single Keychain item (JSON vault) so
/// connect needs at most one Keychain unlock prompt instead of one per secret.
class KeychainStore {
  KeychainStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.tunnelchain/keychain');

  static const vaultRecordKey = '__vault__';

  final MethodChannel _channel;
  Map<String, String>? _vaultCache;

  Future<Map<String, String>> getSecrets(Iterable<String> keys) async {
    final needed = keys.toSet();
    if (needed.isEmpty) return {};

    if (_vaultCache != null) {
      final cached = <String, String>{};
      for (final key in needed) {
        final value = _vaultCache![key];
        if (value != null && value.isNotEmpty) {
          cached[key] = value;
        }
      }
      if (cached.length == needed.length) {
        return cached;
      }
    }

    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'loadSecrets',
      {'keys': needed.toList()},
    );
    _syncVaultCache(raw?['vaultJson'] as String?);

    final secretsRaw = raw?['secrets'];
    final secrets = <String, String>{};
    if (secretsRaw is Map) {
      secretsRaw.forEach((key, value) {
        final stringValue = '$value';
        if (stringValue.isNotEmpty) {
          secrets['$key'] = stringValue;
        }
      });
    }
    return secrets;
  }

  Future<void> mergeSecrets(Map<String, String> secrets) async {
    if (secrets.isEmpty) return;
    final vault = await _loadVault();
    vault.addAll(secrets);
    await _saveVault(vault);
  }

  Future<void> removeSecrets(Iterable<String> keys) async {
    final vault = await _loadVault();
    var changed = false;
    for (final key in keys) {
      if (vault.remove(key) != null) changed = true;
      await _channel.invokeMethod<void>('delete', {'key': key});
    }
    if (changed) await _saveVault(vault);
  }

  Future<String?> read(String key) async {
    final vault = await _loadVault();
    final cached = vault[key];
    if (cached != null) return cached;
    final value = await _channel.invokeMethod<String>('read', {'key': key});
    if (value != null) {
      vault[key] = value;
      await _saveVault(vault);
    }
    return value;
  }

  Future<void> write(String key, String value) async {
    await mergeSecrets({key: value});
  }

  Future<void> delete(String key) async {
    await removeSecrets([key]);
  }

  void clearCache() => _vaultCache = null;

  Future<Map<String, String>> _loadVault() async {
    if (_vaultCache != null) return Map.of(_vaultCache!);
    final raw = await _channel.invokeMethod<String>('readVault');
    _syncVaultCache(raw);
    return Map.of(_vaultCache!);
  }

  Future<void> _saveVault(Map<String, String> vault) async {
    _vaultCache = Map.of(vault);
    await _channel.invokeMethod<void>('writeVault', {
      'json': jsonEncode(vault),
    });
  }

  void _syncVaultCache(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      _vaultCache = {};
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _vaultCache = {};
      return;
    }
    _vaultCache = decoded.map(
      (key, value) => MapEntry('$key', '$value'),
    );
  }
}
