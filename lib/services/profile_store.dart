import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/serialization/profile_codec.dart';
import 'package:tunnel_chain/services/config_store.dart';

abstract class ProfileStore {
  Future<List<Profile>> load();
  Future<void> save(List<Profile> profiles);
}

class MacProfileStore implements ProfileStore {
  MacProfileStore({ConfigStore? configStore, ProfileCodec? codec})
    : _configStore = configStore ?? MacConfigStore(),
      _codec = codec ?? const ProfileCodec();

  final ConfigStore _configStore;
  final ProfileCodec _codec;

  Future<String> _filePath() async {
    final dir = await _configStore.configDirectory();
    return p.join(dir, 'profiles.json');
  }

  @override
  Future<List<Profile>> load() async {
    final path = await _filePath();
    final file = File(path);
    if (!await file.exists()) return const [];
    final text = await file.readAsString();
    if (text.trim().isEmpty) return const [];
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _codec.decodeAll(json);
  }

  @override
  Future<void> save(List<Profile> profiles) async {
    final path = await _filePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ').convert(
      _codec.encodeAll(profiles),
    );
    await file.writeAsString(encoded);
  }
}

/// In-memory store for unit tests.
class LocalProfileStore implements ProfileStore {
  LocalProfileStore({List<Profile>? seed}) : _profiles = List.of(seed ?? const []);

  final List<Profile> _profiles;

  @override
  Future<List<Profile>> load() async => List.unmodifiable(_profiles);

  @override
  Future<void> save(List<Profile> profiles) async {
    _profiles
      ..clear()
      ..addAll(profiles);
  }
}
