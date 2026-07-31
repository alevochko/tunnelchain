class ParseResult<T> {
  const ParseResult({
    required this.value,
    this.warnings = const [],
    this.secrets = const {},
  });

  final T value;
  final List<String> warnings;

  /// Keychain record id → secret value to store on import.
  final Map<String, String> secrets;
}
