import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tunnel_chain/domain/models/diagnostic_models.dart';
import 'package:tunnel_chain/services/core_controller.dart';
import 'package:tunnel_chain/services/diagnostics_service.dart';
import 'package:tunnel_chain/services/leakcheck_runner.dart';
import 'package:tunnel_chain/services/throughput_probe.dart';
import 'package:tunnel_chain/services/tunnel_state.dart';
import 'package:tunnel_chain/state/connect_bundle.dart';
import 'package:tunnel_chain/state/tunnel_session.dart';

class DiagnosticsUiState {
  const DiagnosticsUiState({
    this.busy = false,
    this.errorMessage,
    this.report,
    this.resetSteps = const {},
  });

  final bool busy;
  final String? errorMessage;
  final DiagnosticsReport? report;
  final Map<String, bool> resetSteps;

  DiagnosticsUiState copyWith({
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    DiagnosticsReport? report,
    Map<String, bool>? resetSteps,
    bool clearResetSteps = false,
  }) {
    return DiagnosticsUiState(
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      report: report ?? this.report,
      resetSteps: clearResetSteps ? const {} : (resetSteps ?? this.resetSteps),
    );
  }
}

class DiagnosticsSessionNotifier extends Notifier<DiagnosticsUiState> {
  DiagnosticsService get _service => ref.read(diagnosticsServiceProvider);
  LeakcheckRunner get _leakcheck => ref.read(leakcheckRunnerProvider);
  CoreController get _core => ref.read(coreControllerProvider);

  @override
  DiagnosticsUiState build() => const DiagnosticsUiState();

  Future<void> runAll() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final tunnel = ref.read(tunnelSessionProvider);
      final bundle = ref.read(connectBundleProvider);
      final connected = tunnel.tunnelState.isLive;

      final tunMtu = bundle?.tunnel.tunMtu ?? 1280;
      final wgMtu = bundle?.tunnel.wgMtu ?? 1280;
      final inner = bundle?.innerWireGuardProfile();
      final outer = bundle?.outerVlessProfile();

      final checks = <DiagnosticCheck>[
        _service.mtuInfo(tunMtu: tunMtu, wgMtu: wgMtu),
        if (connected)
          await _leakcheck.run(
            innerEndpointHost: inner?.endpointHost ?? '',
            outerEndpointHost: outer?.host,
          )
        else
          const DiagnosticCheck(
            id: 'leakcheck',
            title: 'Nesting verification',
            detail: 'Connect a chain first, then run diagnostics.',
            status: DiagnosticStatus.idle,
          ),
        if (connected)
          await ThroughputProbe(runCount: 3).measure()
        else
          const DiagnosticCheck(
            id: 'throughput',
            title: 'Throughput measurement',
            detail: 'Connect a chain first.',
            status: DiagnosticStatus.idle,
          ),
        ...await _service.runDnsSuite(),
      ];
      final findings = await _service.runDoctor();

      state = state.copyWith(
        report: DiagnosticsReport(
          checks: checks,
          findings: findings,
          ranAt: DateTime.now(),
        ),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> resetNetwork() async {
    state = state.copyWith(busy: true, clearError: true, clearResetSteps: true);
    try {
      final result = await _core.resetNetwork();
      state = state.copyWith(
        resetSteps: result.steps,
        report: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(busy: false);
    }
  }
}

final diagnosticsServiceProvider = Provider<DiagnosticsService>(
  (ref) => DiagnosticsService(),
);

final leakcheckRunnerProvider = Provider<LeakcheckRunner>(
  (ref) => LeakcheckRunner(),
);

final diagnosticsSessionProvider =
    NotifierProvider<DiagnosticsSessionNotifier, DiagnosticsUiState>(
      DiagnosticsSessionNotifier.new,
    );
