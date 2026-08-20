import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/tor.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class TorStatus extends StatefulWidget {
  const TorStatus({super.key});

  @override
  State<TorStatus> createState() => _TorStatusState();
}

class _TorStatusState extends State<TorStatus> {
  Timer? _timer;
  String _status = 'disabled';
  int _progress = 0;
  String? _ip;
  String? _countryCode;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refresh(checkExit: true);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool checkExit = false}) async {
    final result = await torControl.status();
    if (!mounted) return;
    final progress = (result['bootstrapPercent'] as num?)?.toInt() ?? 0;
    setState(() {
      _status = result['status']?.toString() ?? 'disabled';
      _progress = progress.clamp(0, 100);
    });
    if (_progress >= 100 && (checkExit || _ip == null) && !_checking) {
      await _checkExit();
    }
  }

  Future<void> _checkExit() async {
    setState(() => _checking = true);
    final result = await torControl.checkExit();
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (result['ok'] == true) {
        _ip = result['ip']?.toString();
        _countryCode = result['countryCode']?.toString();
        _error = null;
      } else {
        _error = result['error']?.toString();
      }
    });
  }

  String _countryCodeToEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '';
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  String get _detail {
    if (_ip != null) return _ip!;
    if (_error != null) return _error!;
    return '$_progress%';
  }

  @override
  Widget build(BuildContext context) {
    final running = _status == 'running' || _progress >= 100;
    final connected = _progress >= 100;
    final countryFlag = _countryCodeToEmoji(_countryCode ?? '');
    final emojiTextStyle = context.textTheme.bodyMedium?.toLight.copyWith(
      fontFamily: FontFamily.twEmoji.value,
    );
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(
          label: context.appLocalizations.torStatus,
          iconData: running
              ? Icons.verified_user_outlined
              : Icons.shield_outlined,
        ),
        onPressed: () => _refresh(checkExit: true),
        child: Padding(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!connected) ...[
                LinearProgressIndicator(
                  value: _status == 'disabled' ? 0 : _progress / 100,
                  minHeight: 2,
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  if (connected && countryFlag.isNotEmpty) ...[
                    Text(countryFlag, style: emojiTextStyle),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      _checking
                          ? context.appLocalizations.torCheckingExit
                          : _detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
