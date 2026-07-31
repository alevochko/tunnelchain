/// AmneziaWG obfuscation parameters from a wg-quick [Interface] section.
class AwgObfuscation {
  const AwgObfuscation({
    this.jc = 0,
    this.jmin = 0,
    this.jmax = 0,
    this.s = const [0, 0, 0, 0],
    this.h = const [1, 2, 3, 4],
    this.i = const [],
  });

  final int jc;
  final int jmin;
  final int jmax;
  final List<int> s;
  final List<int> h;
  final List<String> i;

  /// FR-3: active obfuscation requires sing-box-lx / AWG 2.0.
  bool isNonTrivial() {
    if (jc != 0) return true;
    if (s.any((v) => v != 0)) return true;
    if (h.length >= 4) {
      if (h[0] != 1 || h[1] != 2 || h[2] != 3 || h[3] != 4) return true;
    }
    if (i.isNotEmpty) return true;
    return false;
  }
}
