import 'dart:io';

/// Resolves bundled sing-box binary path for the privileged helper.
String? resolveBundledSingBoxPath() {
  try {
    final executable = Platform.resolvedExecutable;
    final bundleRoot = File(executable).parent.parent.parent;
    final candidate = File(
      '${bundleRoot.path}${Platform.pathSeparator}Contents'
      '${Platform.pathSeparator}Resources'
      '${Platform.pathSeparator}sing-box',
    );
    if (candidate.existsSync()) {
      return candidate.path;
    }
  } catch (_) {}
  return null;
}
