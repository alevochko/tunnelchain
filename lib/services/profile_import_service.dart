import 'dart:convert';
import 'dart:io';

import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/parsers/vless_outbound_parser.dart';
import 'package:tunnel_chain/domain/parsers/wg_conf_parser.dart';
import 'package:tunnel_chain/services/keychain_store.dart';
import 'package:tunnel_chain/services/profile_store.dart';

class ImportResult {
  const ImportResult({required this.profile, this.warnings = const []});

  final Profile profile;
  final List<String> warnings;
}

class ProfileImportService {
  ProfileImportService({
    ProfileStore? store,
    KeychainStore? keychain,
    VlessOutboundParser? vlessParser,
    WgConfParser? wgParser,
  }) : _store = store ?? MacProfileStore(),
       _keychain = keychain ?? KeychainStore(),
       _vlessParser = vlessParser ?? VlessOutboundParser(),
       _wgParser = wgParser ?? WgConfParser();

  final ProfileStore _store;
  final KeychainStore _keychain;
  final VlessOutboundParser _vlessParser;
  final WgConfParser _wgParser;

  Future<ImportResult> importVless({
    required String uri,
    String? name,
  }) =>
      importVlessPayload(payload: uri, name: name);

  Future<ImportResult> importVlessPayload({
    required String payload,
    String? name,
  }) async {
    final id = _newId();
    final parsed = _vlessParser.parse(
      payload,
      id: id,
      name: name ?? _nameFromVlessPayload(payload),
      uuidKeychainKey: 'profile.$id.uuid',
      publicKeyKeychainKey: 'profile.$id.pbk',
    );
    await _storeSecrets(parsed.secrets);
    final profiles = List<Profile>.from(await _store.load())..add(parsed.value);
    await _store.save(profiles);
    return ImportResult(profile: parsed.value, warnings: parsed.warnings);
  }

  Future<ImportResult> importWireGuardConf({
    required String content,
    String? name,
    String? fileName,
  }) async {
    final id = _newId();
    final parsed = _wgParser.parse(
      content,
      id: id,
      name: name ?? _nameFromFileName(fileName),
      privateKeyKeychainKey: 'profile.$id.priv',
      presharedKeyKeychainKey: 'profile.$id.psk',
    );
    await _storeSecrets(parsed.secrets);
    final profiles = List<Profile>.from(await _store.load())..add(parsed.value);
    await _store.save(profiles);
    return ImportResult(profile: parsed.value, warnings: parsed.warnings);
  }

  Profile previewVless(String uri, {String? name}) =>
      previewVlessPayload(uri, name: name);

  Profile previewVlessPayload(String payload, {String? name}) {
    return _vlessParser
        .parse(
          payload,
          id: 'preview',
          name: name ?? _nameFromVlessPayload(payload),
          uuidKeychainKey: 'profile.preview.uuid',
          publicKeyKeychainKey: 'profile.preview.pbk',
        )
        .value;
  }

  Profile previewWireGuardConf(String content, {String? name}) {
    return _wgParser
        .parse(
          content,
          id: 'preview',
          name: name ?? 'WireGuard',
          privateKeyKeychainKey: 'profile.preview.priv',
          presharedKeyKeychainKey: 'profile.preview.psk',
        )
        .value;
  }

  Future<void> _storeSecrets(Map<String, String> secrets) async {
    for (final entry in secrets.entries) {
      await _keychain.write(entry.key, entry.value);
    }
  }

  static String _newId() =>
      'profile-${DateTime.now().millisecondsSinceEpoch}';

  static String _nameFromVlessPayload(String payload) {
    final trimmed = payload.trim();
    if (trimmed.startsWith('vless://')) {
      return _nameFromVlessUri(trimmed);
    }

    try {
      final json = jsonDecode(trimmed);
      if (json is Map) {
        final remarks = json['remarks'];
        if (remarks is String && remarks.trim().isNotEmpty) {
          return remarks.trim();
        }
        final tag = json['tag'];
        if (tag is String && tag.isNotEmpty) return tag;
        final outbounds = json['outbounds'];
        if (outbounds is List) {
          for (final item in outbounds) {
            if (item is Map) {
              final protocol = item['protocol'];
              final type = item['type'];
              if (protocol == 'vless' || type == 'vless') {
                final outboundTag = item['tag'];
                if (outboundTag is String && outboundTag.isNotEmpty) {
                  return outboundTag;
                }
                final settings = item['settings'];
                if (settings is Map) {
                  final vnextList = settings['vnext'] as List?;
                  if (vnextList != null && vnextList.isNotEmpty) {
                    final vnext = vnextList.first;
                    if (vnext is Map) {
                      final address = vnext['address'];
                      final port = vnext['port'];
                      if (address is String && port != null) {
                        return '$address:$port';
                      }
                    }
                  }
                }
                final server = item['server'];
                final port = item['server_port'] ?? item['port'];
                if (server is String && port != null) return '$server:$port';
              }
            }
          }
        }
        if (json['type'] == 'vless') {
          final server = json['server'];
          final port = json['server_port'] ?? json['port'];
          if (server is String && port != null) return '$server:$port';
        }
      }
    } catch (_) {
      // fall through
    }

    return 'VLESS';
  }

  static String _nameFromVlessUri(String uri) {
    final hash = uri.indexOf('#');
    if (hash >= 0 && hash < uri.length - 1) {
      return Uri.decodeComponent(uri.substring(hash + 1).trim());
    }
    final at = uri.indexOf('@');
    if (at >= 0) {
      final hostPart = uri.substring(at + 1).split('?').first.split('#').first;
      return hostPart.isNotEmpty ? hostPart : 'VLESS';
    }
    return 'VLESS';
  }

  static String _nameFromFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) return 'WireGuard';
    final base = fileName.split(Platform.pathSeparator).last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }
}
