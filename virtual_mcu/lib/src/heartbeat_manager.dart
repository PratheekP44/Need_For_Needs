import 'dart:async';

import 'runtime_state.dart';
import 'simulation_config.dart';

/// Periodic heartbeat counter / tick generator.
class HeartbeatManager {
  HeartbeatManager({
    required this.config,
    required this.onTick,
  });

  final SimulationConfig config;
  final void Function(int counter) onTick;

  Timer? _timer;
  int counter = 0;

  void start() {
    stop();
    _timer = Timer.periodic(config.heartbeatInterval, (_) {
      counter += 1;
      onTick(counter);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    counter = 0;
  }
}

/// Applies heartbeat tick onto [McuRuntimeState].
void applyHeartbeatTick(McuRuntimeState state, int counter) {
  state.heartbeatCounter = counter;
  state.uptimeSeconds =
      DateTime.now().difference(state.bootedAt).inSeconds;
}
