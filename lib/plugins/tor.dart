import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';

class TorControl {
  const TorControl();

  static const socksPort = 19050;
  static const controlPort = 19051;
  static const dnsPort = 19053;
  static const MethodChannel _channel = MethodChannel('tor');

  Future<Map<String, dynamic>> start({
    required TorProps torProps,
    required int upstreamSocksPort,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('start', {
      'data': jsonEncode({
        'enabled': torProps.enable,
        'bridgeMode': torProps.bridgeMode.name,
        'customBridgesEnabled': torProps.customBridgesEnabled,
        'customBridges': torProps.bridgeLines,
        'upstreamSocksPort': upstreamSocksPort,
        'socksPort': socksPort,
        'controlPort': controlPort,
        'dnsPort': dnsPort,
      }),
    });
    return result ?? const {};
  }

  Future<void> stop() async {
    await _channel.invokeMethod<bool>('stop');
  }

  Future<Map<String, dynamic>> status() async {
    return await _channel.invokeMapMethod<String, dynamic>('status') ??
        const {'status': 'disabled'};
  }

  Future<Map<String, dynamic>> checkExit() async {
    return await _channel.invokeMapMethod<String, dynamic>('checkExit', {
          'socksPort': socksPort,
        }) ??
        const {'ok': false};
  }

  Future<Traffic> traffic() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('traffic', {
      'controlPort': controlPort,
    });
    if (result?['ok'] != true) return const Traffic();
    return Traffic(
      up: (result?['up'] as num?) ?? 0,
      down: (result?['down'] as num?) ?? 0,
    );
  }
}

const torControl = TorControl();
