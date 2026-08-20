import 'package:fl_clash/common/tor_config_transformer.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled Tor leaves configuration unchanged', () {
    final config = <String, dynamic>{
      'proxies': <dynamic>[],
      'rules': <String>['MATCH,DIRECT'],
    };

    const TorConfigTransformer().transform(
      rawConfig: config,
      torProps: const TorProps(),
      accessControlProps: const AccessControlProps(),
    );

    expect(config['proxies'], isEmpty);
    expect(config['rules'], ['MATCH,DIRECT']);
  });

  test('enabled Tor adds SOCKS outbound and loop-safe TCP routing', () {
    final config = <String, dynamic>{
      'proxies': <dynamic>[
        {'name': 'node', 'server': 'proxy.example.com'},
      ],
      'proxy-groups': <dynamic>[
        {'name': 'Default Proxy'},
      ],
      'rules': <String>['MATCH,Default Proxy'],
    };

    const TorConfigTransformer().transform(
      rawConfig: config,
      torProps: const TorProps(enable: true),
      accessControlProps: const AccessControlProps(),
    );

    expect(
      config['proxies'],
      contains(
        predicate<Map>(
          (proxy) =>
              proxy['name'] == 'tor-out' &&
              proxy['type'] == 'socks5' &&
              proxy['server'] == '127.0.0.1' &&
              proxy['port'] == 19050 &&
              proxy['udp'] == false,
        ),
      ),
    );
    expect(
      config['rules'],
      containsAllInOrder([
        'PROCESS-NAME,com.follow.clash,Default Proxy',
        r'PROCESS-NAME-REGEX,^com\.follow\.clash(:.*)?$,Default Proxy',
        'IP-CIDR,212.83.43.95/32,Default Proxy',
        'DOMAIN,proxy.example.com,Default Proxy',
        'DOMAIN,ipwho.is,Default Proxy',
        'DOMAIN,ipinfo.io,Default Proxy',
        'NETWORK,TCP,tor-out',
      ]),
    );
  });

  test('custom bridge targets bypass the Tor outbound', () {
    final config = <String, dynamic>{
      'proxies': <dynamic>[],
      'proxy-groups': <dynamic>[
        {'name': 'Default Proxy'},
      ],
      'rules': <String>['MATCH,Default Proxy'],
    };

    const TorConfigTransformer().transform(
      rawConfig: config,
      torProps: const TorProps(
        enable: true,
        bridgeMode: TorBridgeMode.obfs4,
        customBridgesEnabled: true,
        customBridges: 'obfs4 bridge.example.com:443 fingerprint cert=value',
      ),
      accessControlProps: const AccessControlProps(),
    );

    final rules = config['rules'] as List<String>;
    expect(
      rules.indexOf('DOMAIN,bridge.example.com,Default Proxy'),
      lessThan(rules.indexOf('NETWORK,TCP,tor-out')),
    );
  });
}
