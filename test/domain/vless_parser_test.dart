import 'package:flutter_test/flutter_test.dart';
import 'package:tunnel_chain/core_config/secret_resolver.dart';
import 'package:tunnel_chain/core_config/sing_box/hop_builder.dart';
import 'package:tunnel_chain/domain/parsers/vless_outbound_parser.dart';
import 'package:tunnel_chain/domain/parsers/vless_parser.dart';

void main() {
  final parser = VlessOutboundParser();
  final secrets = MapSecretResolver({
    'secret.uuid': '550e8400-e29b-41d4-a716-446655440000',
    'secret.pbk': 'testPubKey',
  });

  const tcpLink =
      'vless://550e8400-e29b-41d4-a716-446655440000@vps.example.com:443'
      '?type=tcp&security=reality&pbk=testPubKey&fp=chrome'
      '&sni=cdn.example.com&sid=abc&flow=xtls-rprx-vision';

  const grpcLink =
      'vless://550e8400-e29b-41d4-a716-446655440000@vps.example.com:443'
      '?type=grpc&security=reality&pbk=testPubKey&fp=chrome'
      '&sni=cdn.example.com&sid=abc&serviceName=GunService';

  const wsLink =
      'vless://550e8400-e29b-41d4-a716-446655440000@vps.example.com:443'
      '?type=ws&security=tls&path=%2Fvless&host=cdn.example&sni=cdn.example';

  const httpLink =
      'vless://uuid@host:443?type=h2&security=tls&path=/h2&host=h2.example';

  const httpUpgradeLink =
      'vless://uuid@host:443?type=httpupgrade&security=tls&path=/up&host=up.example';

  group('VlessParser URI', () {
    test('parses reality tcp link', () {
      final result = VlessParser().parse(
        tcpLink,
        id: 'vps',
        name: 'VPS',
        uuidKeychainKey: 'secret.uuid',
        publicKeyKeychainKey: 'secret.pbk',
      );

      expect(result.value.transport, 'tcp');
      expect(result.value.flow, 'xtls-rprx-vision');
    });

    test('parses reality grpc link', () {
      final result = VlessParser().parse(
        grpcLink,
        id: 'vps',
        name: 'VPS gRPC',
        uuidKeychainKey: 'secret.uuid',
        publicKeyKeychainKey: 'secret.pbk',
      );

      expect(result.value.transport, 'grpc');
      expect(result.value.grpcServiceName, 'GunService');
      expect(result.value.flow, isEmpty);
    });

    test('parses ws tls link', () {
      final result = VlessParser().parse(
        wsLink,
        id: 'vps',
        name: 'VPS WS',
        uuidKeychainKey: 'secret.uuid',
      );

      expect(result.value.transport, 'ws');
      expect(result.value.transportPath, '/vless');
      expect(result.value.transportHost, 'cdn.example');
      expect(result.value.flow, isEmpty);
    });

    test('normalizes h2 to http transport', () {
      final result = VlessParser().parse(
        httpLink,
        id: 'x',
        name: 'x',
        uuidKeychainKey: 'k',
      );

      expect(result.value.transport, 'http');
      expect(result.value.transportPath, '/h2');
      expect(result.value.transportHost, 'h2.example');
    });

    test('parses httpupgrade link', () {
      final result = VlessParser().parse(
        httpUpgradeLink,
        id: 'x',
        name: 'x',
        uuidKeychainKey: 'k',
      );

      expect(result.value.transport, 'httpupgrade');
      expect(result.value.transportPath, '/up');
      expect(result.value.transportHost, 'up.example');
    });

    test('rejects unsupported transport', () {
      expect(
        () => VlessParser().parse(
          'vless://uuid@host:443?type=quic&security=tls',
          id: 'x',
          name: 'x',
          uuidKeychainKey: 'k',
        ),
        throwsA(isA<VlessParseException>()),
      );
    });
  });

  group('SingBoxHopBuilder transports', () {
    test('grpc reality outbound', () {
      final profile = VlessParser().parse(
        grpcLink,
        id: 'vps',
        name: 'VPS gRPC',
        uuidKeychainKey: 'secret.uuid',
        publicKeyKeychainKey: 'secret.pbk',
      ).value;

      final outbound = SingBoxHopBuilder.vless(profile, 'hop0', secrets);
      final transport = outbound['transport'] as Map<String, dynamic>;

      expect(transport['type'], 'grpc');
      expect(transport['service_name'], 'GunService');
      expect(outbound.containsKey('flow'), isFalse);
    });

    test('ws outbound includes path and host header', () {
      final profile = VlessParser().parse(
        wsLink,
        id: 'vps',
        name: 'VPS WS',
        uuidKeychainKey: 'secret.uuid',
      ).value;

      final outbound = SingBoxHopBuilder.vless(profile, 'hop0', secrets);
      final transport = outbound['transport'] as Map<String, dynamic>;

      expect(transport['type'], 'ws');
      expect(transport['path'], '/vless');
      expect(transport['headers'], {'Host': 'cdn.example'});
    });

    test('http outbound uses host and path', () {
      final profile = VlessParser().parse(
        httpLink,
        id: 'x',
        name: 'x',
        uuidKeychainKey: 'k',
      ).value;

      final outbound = SingBoxHopBuilder.vless(
        profile,
        'hop0',
        MapSecretResolver({'k': 'uuid'}),
      );
      final transport = outbound['transport'] as Map<String, dynamic>;

      expect(transport['type'], 'http');
      expect(transport['path'], '/h2');
      expect(transport['host'], 'h2.example');
    });
  });

  group('VlessOutboundParser JSON', () {
    test('parses sing-box vless ws outbound', () {
      const json = '''
{
  "type": "vless",
  "tag": "proxy-ws",
  "server": "1.2.3.4",
  "server_port": 443,
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "tls": {
    "enabled": true,
    "server_name": "cdn.example",
    "utls": { "enabled": true, "fingerprint": "chrome" }
  },
  "transport": {
    "type": "ws",
    "path": "/vless",
    "headers": { "Host": "cdn.example" }
  }
}
''';

      final result = parser.parse(
        json,
        id: 'node',
        name: '',
        uuidKeychainKey: 'secret.uuid',
      );

      expect(result.value.name, 'proxy-ws');
      expect(result.value.transport, 'ws');
      expect(result.value.transportPath, '/vless');
      expect(result.value.transportHost, 'cdn.example');
      expect(result.value.security, 'tls');
    });

    test('parses sing-box config with outbounds array', () {
      const json = '''
{
  "outbounds": [
    {
      "type": "vless",
      "tag": "main",
      "server": "example.com",
      "server_port": 443,
      "uuid": "uuid-value",
      "tls": {
        "enabled": true,
        "server_name": "cdn.example.com",
        "utls": { "enabled": true, "fingerprint": "chrome" },
        "reality": {
          "enabled": true,
          "public_key": "pbk-value",
          "short_id": "abcd"
        }
      },
      "transport": {
        "type": "grpc",
        "service_name": "GunService"
      }
    }
  ]
}
''';

      final result = parser.parse(
        json,
        id: 'node',
        name: '',
        uuidKeychainKey: 'secret.uuid',
        publicKeyKeychainKey: 'secret.pbk',
      );

      expect(result.value.transport, 'grpc');
      expect(result.value.grpcServiceName, 'GunService');
      expect(result.value.security, 'reality');
      expect(result.secrets['secret.pbk'], 'pbk-value');
    });

    test('parses full xray config with protocol vless outbounds', () {
      const json = '''
{
  "remarks": "LTE node",
  "outbounds": [
    {
      "protocol": "vless",
      "tag": "proxy",
      "settings": {
        "vnext": [
          {
            "address": "nl11.example.com",
            "port": 443,
            "users": [
              {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "encryption": "none",
                "flow": "xtls-rprx-vision"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "publicKey": "pbk-value",
          "shortId": "abcd",
          "serverName": "nl11.example.com",
          "fingerprint": "qq"
        }
      }
    },
    {
      "protocol": "vless",
      "tag": "rezerv",
      "settings": {
        "vnext": [
          {
            "address": "222.example.com",
            "port": 443,
            "users": [
              { "id": "550e8400-e29b-41d4-a716-446655440000", "encryption": "none" }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "reality",
        "grpcSettings": { "serviceName": "Gun" },
        "realitySettings": {
          "publicKey": "other-pbk",
          "shortId": "efgh",
          "serverName": "ads.example",
          "fingerprint": "firefox"
        }
      }
    },
    { "protocol": "freedom", "tag": "direct" }
  ]
}
''';

      final result = parser.parse(
        json,
        id: 'node',
        name: '',
        uuidKeychainKey: 'secret.uuid',
        publicKeyKeychainKey: 'secret.pbk',
      );

      expect(result.value.name, 'LTE node');
      expect(result.value.host, 'nl11.example.com');
      expect(result.value.transport, 'tcp');
      expect(result.value.flow, 'xtls-rprx-vision');
      expect(result.value.fingerprint, 'qq');
      expect(
        result.warnings.any((w) => w.contains('2 VLESS outbounds')),
        isTrue,
      );
    });

    test('parses xray vless ws reality outbound', () {
      const json = '''
{
  "protocol": "vless",
  "settings": {
    "vnext": [
      {
        "address": "1.2.3.4",
        "port": 443,
        "users": [
          { "id": "550e8400-e29b-41d4-a716-446655440000", "encryption": "none" }
        ]
      }
    ]
  },
  "streamSettings": {
    "network": "ws",
    "security": "reality",
    "realitySettings": {
      "publicKey": "pbk-value",
      "shortId": "abcd",
      "serverName": "cdn.example.com",
      "fingerprint": "chrome"
    },
    "wsSettings": {
      "path": "/ws",
      "headers": { "Host": "cdn.example" }
    }
  }
}
''';

      final result = parser.parse(
        json,
        id: 'node',
        name: 'xray',
        uuidKeychainKey: 'secret.uuid',
        publicKeyKeychainKey: 'secret.pbk',
      );

      expect(result.value.transport, 'ws');
      expect(result.value.security, 'reality');
      expect(result.value.transportPath, '/ws');
      expect(result.value.transportHost, 'cdn.example');
      expect(result.value.sni, 'cdn.example.com');
    });
  });
}
