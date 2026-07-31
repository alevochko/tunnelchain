/// Normalized sing-box VLESS transport types.
abstract final class VlessTransports {
  static const supported = {'tcp', 'grpc', 'ws', 'http', 'httpupgrade'};

  static String normalize(String raw) {
    return switch (raw.trim().toLowerCase()) {
      '' || 'tcp' => 'tcp',
      'h2' => 'http',
      'http' => 'http',
      'ws' => 'ws',
      'grpc' => 'grpc',
      'httpupgrade' => 'httpupgrade',
      final other => other,
    };
  }

  static bool supportsFlow(String transport) => transport == 'tcp';
}
