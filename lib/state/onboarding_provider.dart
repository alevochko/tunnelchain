import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/services/onboarding_store.dart';

final onboardingStoreProvider = Provider<OnboardingStore>(
  (ref) => MacOnboardingStore(),
);

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );

class OnboardingState {
  const OnboardingState({
    this.loading = true,
    this.visible = false,
    this.step = 0,
    this.showRestartChip = false,
  });

  final bool loading;
  final bool visible;
  final int step;
  final bool showRestartChip;

  static const stepCount = 4;

  OnboardingState copyWith({
    bool? loading,
    bool? visible,
    int? step,
    bool? showRestartChip,
  }) {
    return OnboardingState(
      loading: loading ?? this.loading,
      visible: visible ?? this.visible,
      step: step ?? this.step,
      showRestartChip: showRestartChip ?? this.showRestartChip,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    _load();
    return const OnboardingState();
  }

  OnboardingStore get _store => ref.read(onboardingStoreProvider);

  Future<void> _load() async {
    final completed = await _store.isCompleted();
    state = OnboardingState(
      loading: false,
      visible: !completed,
      showRestartChip: completed,
    );
  }

  void next() {
    if (state.step >= OnboardingState.stepCount - 1) {
      complete();
      return;
    }
    state = state.copyWith(step: state.step + 1);
  }

  void back() {
    if (state.step <= 0) return;
    state = state.copyWith(step: state.step - 1);
  }

  void skip() => complete();

  Future<void> complete() async {
    await _store.setCompleted(true);
    state = state.copyWith(visible: false, showRestartChip: true);
  }

  void restart() {
    state = const OnboardingState(
      loading: false,
      visible: true,
      step: 0,
      showRestartChip: false,
    );
  }

  void go(int delta) {
    if (delta > 0) {
      next();
    } else {
      back();
    }
  }
}
