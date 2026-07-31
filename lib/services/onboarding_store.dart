import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tunnel_chain/services/config_store.dart';

abstract class OnboardingStore {
  Future<bool> isCompleted();
  Future<void> setCompleted(bool completed);
}

class MacOnboardingStore implements OnboardingStore {
  MacOnboardingStore({ConfigStore? configStore})
    : _configStore = configStore ?? MacConfigStore();

  final ConfigStore _configStore;

  Future<File> _file() async {
    final dir = await _configStore.configDirectory();
    return File(p.join(dir, 'onboarding.json'));
  }

  @override
  Future<bool> isCompleted() async {
    final file = await _file();
    if (!await file.exists()) return false;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json['completed'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setCompleted(bool completed) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'completed': completed}),
    );
  }
}

class LocalOnboardingStore implements OnboardingStore {
  LocalOnboardingStore({this.completed = false});

  bool completed;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> setCompleted(bool value) async {
    completed = value;
  }
}
