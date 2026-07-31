import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/domain/models/profile.dart';
import 'package:tunnel_chain/domain/profile_secrets.dart';
import 'package:tunnel_chain/services/keychain_store.dart';
import 'package:tunnel_chain/services/profile_import_service.dart';
import 'package:tunnel_chain/services/profile_store.dart';

class ProfileCatalogState {
  const ProfileCatalogState({
    this.profiles = const [],
    this.loading = false,
    this.busy = false,
    this.errorMessage,
    this.lastImportWarnings = const [],
  });

  final List<Profile> profiles;
  final bool loading;
  final bool busy;
  final String? errorMessage;
  final List<String> lastImportWarnings;

  ProfileCatalogState copyWith({
    List<Profile>? profiles,
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    List<String>? lastImportWarnings,
    bool clearWarnings = false,
  }) {
    return ProfileCatalogState(
      profiles: profiles ?? this.profiles,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastImportWarnings: clearWarnings
          ? const []
          : (lastImportWarnings ?? this.lastImportWarnings),
    );
  }
}

class ProfileCatalogNotifier extends Notifier<ProfileCatalogState> {
  ProfileStore get _store => ref.read(profileStoreProvider);
  ProfileImportService get _import => ref.read(profileImportServiceProvider);
  KeychainStore get _keychain => ref.read(keychainStoreProvider);

  @override
  ProfileCatalogState build() {
    Future.microtask(_load);
    return const ProfileCatalogState(loading: true);
  }

  Future<void> _load() async {
    try {
      final profiles = await _store.load();
      state = state.copyWith(profiles: profiles, loading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> reload() => _load();

  Future<ImportResult?> importVless(String uri, {String? name}) async {
    state = state.copyWith(busy: true, clearError: true, clearWarnings: true);
    try {
      final result = await _import.importVlessPayload(payload: uri, name: name);
      final profiles = await _store.load();
      state = state.copyWith(
        profiles: profiles,
        lastImportWarnings: result.warnings,
      );
      return result;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<ImportResult?> importWireGuardConf(
    String content, {
    String? name,
    String? fileName,
  }) async {
    state = state.copyWith(busy: true, clearError: true, clearWarnings: true);
    try {
      final result = await _import.importWireGuardConf(
        content: content,
        name: name,
        fileName: fileName,
      );
      final profiles = await _store.load();
      state = state.copyWith(
        profiles: profiles,
        lastImportWarnings: result.warnings,
      );
      return result;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> mergeImportedBundle(
    List<Profile> nodes,
    Map<String, String> secrets,
  ) async {
    if (nodes.isEmpty && secrets.isEmpty) return true;

    state = state.copyWith(busy: true, clearError: true);
    try {
      final profiles = List<Profile>.from(await _store.load());
      for (final node in nodes) {
        final idx = profiles.indexWhere((p) => p.id == node.id);
        if (idx >= 0) {
          profiles[idx] = node;
        } else {
          profiles.add(node);
        }
      }
      await _store.save(profiles);
      if (secrets.isNotEmpty) {
        await _keychain.mergeSecrets(secrets);
      }
      state = state.copyWith(profiles: profiles);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> deleteProfile(String id) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final profiles = await _store.load();
      final target = profiles.where((p) => p.id == id).firstOrNull;
      if (target == null) return;
      await _keychain.removeSecrets(profileSecretKeys(target));
      profiles.removeWhere((p) => p.id == id);
      await _store.save(profiles);
      state = state.copyWith(profiles: List.of(profiles));
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(busy: false);
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

final keychainStoreProvider = Provider<KeychainStore>((ref) => KeychainStore());

final profileStoreProvider = Provider<ProfileStore>(
  (ref) => MacProfileStore(),
);

final profileImportServiceProvider = Provider<ProfileImportService>((ref) {
  return ProfileImportService(
    store: ref.watch(profileStoreProvider),
    keychain: ref.watch(keychainStoreProvider),
  );
});

final profileCatalogProvider =
    NotifierProvider<ProfileCatalogNotifier, ProfileCatalogState>(
      ProfileCatalogNotifier.new,
    );
