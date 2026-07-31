/// Resolves [SecretRef] values for configuration generation (Keychain in prod).
abstract class SecretResolver {
  String resolve(String key);
}

class MapSecretResolver implements SecretResolver {
  MapSecretResolver(this._secrets);

  final Map<String, String> _secrets;

  @override
  String resolve(String key) {
    final value = _secrets[key];
    if (value == null || value.isEmpty) {
      throw StateError('Secret not found for key: $key');
    }
    return value;
  }
}
