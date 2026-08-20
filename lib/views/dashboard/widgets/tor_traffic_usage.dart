import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/tor.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class TorTrafficUsage extends StatefulWidget {
  const TorTrafficUsage({super.key});

  @override
  State<TorTrafficUsage> createState() => _TorTrafficUsageState();
}

class _TorTrafficUsageState extends State<TorTrafficUsage> {
  Timer? _timer;
  Traffic _traffic = const Traffic();
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _update() async {
    if (_updating) return;
    _updating = true;
    try {
      final traffic = await torControl.traffic();
      if (mounted) setState(() => _traffic = traffic);
    } finally {
      _updating = false;
    }
  }

  Widget _metric(IconData icon, Color color, num value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${value.traffic.value} ${value.traffic.unit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final upColor = globalState.theme.darken3PrimaryContainer;
    final downColor = globalState.theme.darken2SecondaryContainer;
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(
          label: context.appLocalizations.torTrafficUsage,
          iconData: Icons.data_saver_off,
        ),
        onPressed: _update,
        child: Padding(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _metric(Icons.arrow_upward, upColor, _traffic.up),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metric(
                      Icons.arrow_downward,
                      downColor,
                      _traffic.down,
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
