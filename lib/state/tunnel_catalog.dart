import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/domain/models/chain.dart';
import 'package:tunnel_chain/domain/models/connection_profile.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/models/routing_policy.dart';
import 'package:tunnel_chain/domain/models/tunnel_plan.dart';
import 'package:tunnel_chain/domain/validators/chain_validator.dart';
import 'package:tunnel_chain/domain/validators/routing_validator.dart';
import 'package:tunnel_chain/domain/validators/validation_exception.dart';
import 'package:tunnel_chain/services/connection_profile_transfer_service.dart';
import 'package:tunnel_chain/services/tunnel_plan_migration.dart';
import 'package:tunnel_chain/services/tunnel_plan_store.dart';
import 'package:tunnel_chain/state/profile_catalog.dart';

class TunnelCatalogState {
  const TunnelCatalogState({
    this.plan = const TunnelPlan(),
    this.loading = false,
    this.busy = false,
    this.errorMessage,
  });

  final TunnelPlan plan;
  final bool loading;
  final bool busy;
  final String? errorMessage;

  TunnelCatalogState copyWith({
    TunnelPlan? plan,
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TunnelCatalogState(
      plan: plan ?? this.plan,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TunnelCatalogNotifier extends Notifier<TunnelCatalogState> {
  TunnelPlanStore get _store => ref.read(tunnelPlanStoreProvider);
  ChainValidator get _chainValidator => ChainValidator();
  RoutingValidator get _routingValidator => RoutingValidator();

  /// Loaded from disk, waiting for [profileCatalogProvider] before pruning.
  TunnelPlan? _pendingRawPlan;

  @override
  TunnelCatalogState build() {
    ref.listen(profileCatalogProvider, (previous, next) {
      if (next.loading) return;
      if (state.loading) {
        unawaited(_applyLoadedPlan(next.profiles));
      } else {
        _syncWithProfiles(next.profiles);
      }
    });
    Future.microtask(_load);
    return const TunnelCatalogState(loading: true);
  }

  Future<void> _load() async {
    try {
      _pendingRawPlan = TunnelPlanMigration.ensureProfiles(await _store.load());
      final profileState = ref.read(profileCatalogProvider);
      if (profileState.loading) {
        return;
      }
      await _applyLoadedPlan(profileState.profiles);
    } catch (e) {
      _pendingRawPlan = null;
      state = state.copyWith(loading: false, errorMessage: e.toString());
    }
  }

  Future<void> _applyLoadedPlan(List<Profile> profiles) async {
    final raw = _pendingRawPlan;
    if (raw == null) return;

    try {
      final plan = _prunePlan(raw, profiles.map((p) => p.id).toSet());
      _pendingRawPlan = null;
      state = state.copyWith(plan: plan, loading: false, clearError: true);
    } catch (e) {
      _pendingRawPlan = null;
      state = state.copyWith(loading: false, errorMessage: e.toString());
    }
  }

  Future<void> reload() => _load();

  void _syncWithProfiles(List<Profile> profiles) {
    if (state.loading) return;
    final ids = profiles.map((p) => p.id).toSet();
    final pruned = _prunePlan(state.plan, ids);
    if (pruned != state.plan) {
      state = state.copyWith(plan: pruned);
      unawaited(_persist(pruned));
    }
  }

  TunnelPlan _prunePlan(TunnelPlan plan, Set<String> nodeIds) {
    final nodeMap = {for (final id in nodeIds) id: true};
    final chains = <Chain>[];
    for (final chain in plan.chains) {
      final hops =
          chain.hopProfileIds.where((id) => nodeMap.containsKey(id)).toList();
      if (hops.isNotEmpty) {
        chains.add(Chain(id: chain.id, name: chain.name, hopProfileIds: hops));
      }
    }

    final chainIds = chains.map((c) => c.id).toSet();
    var next = TunnelPlanMigration.ensureProfiles(plan.copyWith(chains: chains));

    final profiles = next.profiles
        .map((p) => TunnelPlanMigration.repairProfileRouting(p, chainIds))
        .toList();

    next = next.copyWith(profiles: profiles);
    if (next.activeProfileId != null &&
        !profiles.any((p) => p.id == next.activeProfileId)) {
      next = next.copyWith(
        activeProfileId: profiles.isEmpty ? null : profiles.first.id,
        clearActiveProfileId: profiles.isEmpty,
      );
    }
    return next;
  }

  Future<void> _persist(TunnelPlan plan) async {
    try {
      await _store.save(plan);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<bool> saveChain(Chain chain, {String? previousId}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final nodes = ref.read(profileCatalogProvider).profiles;
      final nodeMap = {for (final p in nodes) p.id: p};
      _chainValidator.validate(chain, nodeMap);

      final chains = List<Chain>.from(state.plan.chains);
      if (previousId != null) {
        chains.removeWhere((c) => c.id == previousId);
      }
      final existing = chains.indexWhere((c) => c.id == chain.id);
      if (existing >= 0) {
        chains[existing] = chain;
      } else {
        chains.add(chain);
      }

      var plan = state.plan.copyWith(chains: chains);
      if (plan.activeProfileId == null && plan.profiles.isNotEmpty) {
        plan = plan.copyWith(activeProfileId: plan.profiles.first.id);
      }
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> deleteChain(String chainId) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final chains = state.plan.chains.where((c) => c.id != chainId).toList();
      if (chains.length == state.plan.chains.length) return true;

      final profiles = state.plan.profiles
          .map((profile) => _removeChainFromProfile(profile, chainId))
          .toList();

      var plan = state.plan.copyWith(chains: chains, profiles: profiles);
      plan = TunnelPlanMigration.ensureProfiles(plan);
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> saveProfile(
    ConnectionProfile profile, {
    String? previousId,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      _validateProfile(profile, state.plan.chains.map((c) => c.id).toSet());

      final profiles = List<ConnectionProfile>.from(state.plan.profiles);
      if (previousId != null) {
        profiles.removeWhere((p) => p.id == previousId);
      }
      final idx = profiles.indexWhere((p) => p.id == profile.id);
      if (idx >= 0) {
        profiles[idx] = profile;
      } else {
        profiles.add(profile);
      }

      var plan = state.plan.copyWith(profiles: profiles);
      if (plan.activeProfileId == null) {
        plan = plan.copyWith(activeProfileId: profile.id);
      }
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> deleteProfile(String profileId) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final profiles =
          state.plan.profiles.where((p) => p.id != profileId).toList();
      if (profiles.length == state.plan.profiles.length) return true;

      var plan = state.plan.copyWith(profiles: profiles);
      if (plan.activeProfileId == profileId) {
        plan = plan.copyWith(
          activeProfileId: profiles.isEmpty ? null : profiles.first.id,
          clearActiveProfileId: profiles.isEmpty,
        );
      }
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> mergeImportedBundle(ResolvedConnectionProfileImport resolved) async {
    if (resolved.profiles.isEmpty && resolved.chains.isEmpty) return true;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final nodes = ref.read(profileCatalogProvider).profiles;
      final nodeMap = {for (final p in nodes) p.id: p};

      final chains = List<Chain>.from(state.plan.chains);
      for (final chain in resolved.chains) {
        _chainValidator.validate(chain, nodeMap);
        final idx = chains.indexWhere((c) => c.id == chain.id);
        if (idx >= 0) {
          chains[idx] = chain;
        } else {
          chains.add(chain);
        }
      }

      final chainIds = chains.map((c) => c.id).toSet();
      final profiles = List<ConnectionProfile>.from(state.plan.profiles);
      for (final profile in resolved.profiles) {
        _validateProfile(profile, chainIds);
        final idx = profiles.indexWhere((p) => p.id == profile.id);
        if (idx >= 0) {
          profiles[idx] = profile;
        } else {
          profiles.add(profile);
        }
      }

      var plan = state.plan.copyWith(chains: chains, profiles: profiles);
      if (plan.activeProfileId == null && profiles.isNotEmpty) {
        plan = plan.copyWith(activeProfileId: profiles.first.id);
      }
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> setActiveProfile(String profileId) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      if (!state.plan.profiles.any((p) => p.id == profileId)) {
        throw ValidationException('Unknown profile "$profileId"');
      }
      final plan = state.plan.copyWith(activeProfileId: profileId);
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> setDefaultRoute(RouteTarget target) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final active = state.plan.activeProfile;
      if (active == null) {
        throw ValidationException('No active profile');
      }
      if (!target.isDirect &&
          !state.plan.chains.any((c) => c.id == target.chainId)) {
        throw ValidationException(
          'Unknown chain "${target.chainId}"',
        );
      }

      final plan = state.plan.updateActiveProfile(
        (profile) => profile.copyWith(
          routing: RoutingPolicy(
            defaultTarget: target,
            overrides: profile.routing.overrides,
          ),
        ),
      );
      _routingValidator.validate(
        plan.effectiveRouting,
        plan.activeRoutingChainIds(),
      );
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  @Deprecated('Use setDefaultRoute')
  Future<bool> setDefaultChain(String chainId) =>
      setDefaultRoute(RouteTarget.chain(chainId));

  bool isChainReferenced(String chainId) {
    for (final profile in state.plan.profiles) {
      if (profile.referencedChainIds().contains(chainId)) return true;
    }
    return false;
  }

  void _validateProfile(ConnectionProfile profile, Set<String> allChainIds) {
    if (profile.name.trim().isEmpty) {
      throw ValidationException('Profile name is required');
    }
    for (final chainId in profile.referencedChainIds()) {
      if (!allChainIds.contains(chainId)) {
        throw ValidationException('Unknown chain "$chainId"');
      }
    }
  }

  Set<String> _activeProfileChainIds() {
    return state.plan.activeRoutingChainIds();
  }

  ConnectionProfile _removeChainFromProfile(
    ConnectionProfile profile,
    String chainId,
  ) {
    var routing = profile.routing;
    if (routing.defaultTarget.chainId == chainId) {
      routing = RoutingPolicy(
        defaultTarget: const RouteTarget.direct(),
        overrides: routing.overrides
            .where(
              (r) => r.target.isDirect || r.target.chainId != chainId,
            )
            .toList(),
      );
    } else {
      routing = RoutingPolicy(
        defaultTarget: routing.defaultTarget,
        overrides: routing.overrides
            .where(
              (r) => r.target.isDirect || r.target.chainId != chainId,
            )
            .toList(),
      );
    }
    return profile.copyWith(routing: routing);
  }

  Future<bool> saveRoutingRule(
    RoutingRule rule, {
    int? replaceOrder,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final current = state.plan.effectiveRouting;
      final overrides = List<RoutingRule>.from(current.overrides);
      if (replaceOrder != null) {
        final idx = overrides.indexWhere((r) => r.order == replaceOrder);
        if (idx < 0) {
          throw ValidationException('Rule order $replaceOrder not found');
        }
        overrides[idx] = RoutingRule(
          order: replaceOrder,
          matcher: rule.matcher,
          target: rule.target,
          dns: rule.dns,
        );
      } else {
        overrides.add(
          RoutingRule(
            order: overrides.length,
            matcher: rule.matcher,
            target: rule.target,
            dns: rule.dns,
          ),
        );
      }

      final routing = RoutingPolicy(
        defaultTarget: current.defaultTarget,
        overrides: _renumberOverrides(overrides),
      );
      _routingValidator.validate(
        routing,
        _activeProfileChainIds(),
      );

      final plan = state.plan.updateActiveProfile(
        (profile) => profile.copyWith(routing: routing),
      );
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> deleteRoutingRule(int order) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final current = state.plan.effectiveRouting;
      final routing = RoutingPolicy(
        defaultTarget: current.defaultTarget,
        overrides: _renumberOverrides(
          current.overrides.where((r) => r.order != order).toList(),
        ),
      );
      final plan = state.plan.updateActiveProfile(
        (profile) => profile.copyWith(routing: routing),
      );
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> moveRoutingRule(int order, {required bool up}) async {
    final current = state.plan.effectiveRouting;
    final overrides = current.sortedOverrides();
    final idx = overrides.indexWhere((r) => r.order == order);
    if (idx < 0) return false;
    final swapWith = up ? idx - 1 : idx + 1;
    if (swapWith < 0 || swapWith >= overrides.length) return false;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final copy = List<RoutingRule>.from(overrides);
      final tmp = copy[idx];
      copy[idx] = copy[swapWith];
      copy[swapWith] = tmp;

      final routing = RoutingPolicy(
        defaultTarget: current.defaultTarget,
        overrides: _renumberOverrides(copy),
      );
      final plan = state.plan.updateActiveProfile(
        (profile) => profile.copyWith(routing: routing),
      );
      await _store.save(plan);
      state = state.copyWith(plan: plan);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  List<RoutingRule> _renumberOverrides(List<RoutingRule> rules) {
    final sorted = List<RoutingRule>.from(rules)
      ..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (var i = 0; i < sorted.length; i++)
        RoutingRule(
          order: i,
          matcher: sorted[i].matcher,
          target: sorted[i].target,
          dns: sorted[i].dns,
        ),
    ];
  }
}

final tunnelPlanStoreProvider = Provider<TunnelPlanStore>(
  (ref) => MacTunnelPlanStore(),
);

final tunnelCatalogProvider =
    NotifierProvider<TunnelCatalogNotifier, TunnelCatalogState>(
      TunnelCatalogNotifier.new,
    );
