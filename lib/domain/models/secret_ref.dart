/// Reference to a secret stored in Keychain — never the secret itself.
class SecretRef {
  const SecretRef(this.key);

  final String key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretRef &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'SecretRef($key)';
}
