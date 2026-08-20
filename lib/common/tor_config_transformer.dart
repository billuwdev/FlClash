import 'package:fl_clash/models/models.dart';

class TorConfigTransformer {
  const TorConfigTransformer();

  static const outboundName = 'tor-out';
  static const socksHost = '127.0.0.1';
  static const socksPort = 19050;
  static const builtinBridgeHosts = [
    '212.83.43.95',
    '45.145.95.6',
    '146.57.248.225',
    '212.83.43.74',
    '209.148.46.65',
    '37.218.245.14',
    '51.222.13.177',
  ];
  static const networkDetectionHosts = [
    'ipwho.is',
    'api.myip.com',
    'ipapi.co',
    'ident.me',
    'ip-api.com',
    'api.ip.sb',
    'ipinfo.io',
  ];

  void transform({
    required Map<String, dynamic> rawConfig,
    required TorProps torProps,
    required AccessControlProps accessControlProps,
  }) {
    if (!torProps.enable) return;
    _ensureTorProxy(rawConfig);
    rawConfig['find-process-mode'] = 'always';
    final rules = List<String>.from(rawConfig['rules'] as List? ?? const []);
    final routeTarget = _routeTarget(rawConfig);
    rawConfig['rules'] = [
      'PROCESS-NAME,com.follow.clash,$routeTarget',
      r'PROCESS-NAME-REGEX,^com\.follow\.clash(:.*)?$,' + routeTarget,
      ..._bridgeRules(torProps, routeTarget),
      ..._proxyServerRules(rawConfig, routeTarget),
      ...networkDetectionHosts.map((host) => 'DOMAIN,$host,$routeTarget'),
      'NETWORK,TCP,$outboundName',
      'AND,((NETWORK,UDP),(NOT,((DST-PORT,53)))),REJECT',
      ...rules.where((rule) => !rule.contains(outboundName)),
    ];
  }

  Iterable<String> _bridgeRules(TorProps torProps, String routeTarget) sync* {
    final hosts = <String>{...builtinBridgeHosts};
    if (torProps.customBridgesEnabled) {
      hosts.addAll(_customBridgeHosts(torProps.customBridges));
    }
    for (final host in hosts) {
      yield _hostRule(host, routeTarget);
    }
  }

  Iterable<String> _customBridgeHosts(String bridges) sync* {
    for (final line in bridges.split(RegExp(r'\r\n?|\n'))) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final endpoint = parts[1];
      final closingBracket = endpoint.indexOf(']');
      final host = endpoint.startsWith('[') && closingBracket > 1
          ? endpoint.substring(1, closingBracket)
          : endpoint.split(':').first;
      if (host.isNotEmpty) yield host;
    }
  }

  String _hostRule(String host, String routeTarget) {
    final isIpv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
    return isIpv4
        ? 'IP-CIDR,$host/32,$routeTarget'
        : 'DOMAIN,$host,$routeTarget';
  }

  void _ensureTorProxy(Map<String, dynamic> rawConfig) {
    final proxies = List<dynamic>.from(
      rawConfig['proxies'] as List? ?? const [],
    );
    proxies.removeWhere(
      (proxy) => proxy is Map && proxy['name'] == outboundName,
    );
    proxies.add({
      'name': outboundName,
      'type': 'socks5',
      'server': socksHost,
      'port': socksPort,
      'udp': false,
    });
    rawConfig['proxies'] = proxies;
  }

  String _routeTarget(Map<String, dynamic> rawConfig) {
    final groups = rawConfig['proxy-groups'];
    if (groups is! List) return 'DIRECT';
    for (final group in groups.whereType<Map>()) {
      final name = group['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return 'DIRECT';
  }

  Iterable<String> _proxyServerRules(
    Map<String, dynamic> rawConfig,
    String routeTarget,
  ) sync* {
    final proxies = rawConfig['proxies'];
    if (proxies is! List) return;
    final seen = <String>{};
    for (final proxy in proxies.whereType<Map>()) {
      final server = proxy['server']?.toString().trim();
      if (server == null ||
          server.isEmpty ||
          server == socksHost ||
          !seen.add(server)) {
        continue;
      }
      yield _hostRule(server, routeTarget);
    }
  }
}
