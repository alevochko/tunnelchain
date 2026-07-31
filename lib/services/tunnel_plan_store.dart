import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/serialization/tunnel_plan_codec.dart';
import 'package:tunnel_chain/services/config_store.dart';

abstract class TunnelPlanStore {
  Future<TunnelPlan> load();
  Future<void> save(TunnelPlan plan);
}

class MacTunnelPlanStore implements TunnelPlanStore {
  MacTunnelPlanStore({ConfigStore? configStore, TunnelPlanCodec? codec})
    : _configStore = configStore ?? MacConfigStore(),
      _codec = codec ?? const TunnelPlanCodec();

  final ConfigStore _configStore;
  final TunnelPlanCodec _codec;

  Future<String> _filePath() async {
    final dir = await _configStore.configDirectory();
    return p.join(dir, 'tunnel.json');
  }

  @override
  Future<TunnelPlan> load() async {
    final path = await _filePath();
    final file = File(path);
    if (!await file.exists()) return const TunnelPlan();
    final text = await file.readAsString();
    if (text.trim().isEmpty) return const TunnelPlan();
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _codec.decode(json);
  }

  @override
  Future<void> save(TunnelPlan plan) async {
    final path = await _filePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ').convert(_codec.encode(plan));
    await file.writeAsString(encoded);
  }
}

class LocalTunnelPlanStore implements TunnelPlanStore {
  LocalTunnelPlanStore({TunnelPlan? seed}) : _plan = seed ?? const TunnelPlan();

  TunnelPlan _plan;

  @override
  Future<TunnelPlan> load() async => _plan;

  @override
  Future<void> save(TunnelPlan plan) async {
    _plan = plan;
  }
}
