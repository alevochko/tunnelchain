enum DiagnosticStatus { idle, running, ok, warn, fail }

enum DoctorSeverity { info, warning, error, fixed }

class DiagnosticCheck {
  const DiagnosticCheck({
    required this.id,
    required this.title,
    required this.detail,
    required this.status,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String detail;
  final DiagnosticStatus status;
  final String? actionLabel;

  DiagnosticCheck copyWith({
    DiagnosticStatus? status,
    String? title,
    String? detail,
    String? actionLabel,
  }) {
    return DiagnosticCheck(
      id: id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      status: status ?? this.status,
      actionLabel: actionLabel ?? this.actionLabel,
    );
  }
}

class DoctorFinding {
  const DoctorFinding({
    required this.id,
    required this.title,
    required this.detail,
    required this.severity,
    this.fixLabel,
  });

  final String id;
  final String title;
  final String detail;
  final DoctorSeverity severity;
  final String? fixLabel;
}

class DiagnosticsReport {
  const DiagnosticsReport({
    required this.checks,
    required this.findings,
    this.ranAt,
  });

  final List<DiagnosticCheck> checks;
  final List<DoctorFinding> findings;
  final DateTime? ranAt;

  int get issueCount =>
      findings.where((f) => f.severity != DoctorSeverity.info).length;
}
