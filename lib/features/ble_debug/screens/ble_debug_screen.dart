import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ble/ble.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/ble_debug_provider.dart';

/// Phase 13A BLE Debug — scan, connect, discover, notify (no auth / packets).
class BleDebugScreen extends ConsumerWidget {
  const BleDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bleDebugProvider);
    final ctrl = ref.read(bleDebugProvider.notifier);
    final config = ref.watch(bleConfigProvider);
    final mode = ref.watch(bleConfigProvider.notifier).mode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BLE Debug · Phase 13A'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final auth = ref.read(authSessionProvider);
              context.go(
                auth.isAdmin
                    ? RouteConstants.adminDashboard
                    : RouteConstants.home,
              );
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Transport',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<BleTransportMode>(
                  segments: const [
                    ButtonSegment(
                      value: BleTransportMode.virtualMcu,
                      label: Text('Virtual MCU'),
                      icon: Icon(Icons.developer_board),
                    ),
                    ButtonSegment(
                      value: BleTransportMode.realBle,
                      label: Text('Real BLE'),
                      icon: Icon(Icons.bluetooth),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (set) {
                    ref.read(bleConfigProvider.notifier).setMode(set.first);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  mode == BleTransportMode.realBle
                      ? 'FlutterBluePlus → CC2340R5 (Android)'
                      : 'In-process Virtual MCU (no radio)',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          _Section(
            title: 'GATT Profile (filter / target)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UuidRow('Service', config.serviceUuid.str),
                const SizedBox(height: 6),
                _UuidRow('Char 1 · Command', config.writeCharacteristicUuid.str),
                const SizedBox(height: 6),
                _UuidRow('Char 4 · Status', config.notifyCharacteristicUuid.str),
              ],
            ),
          ),
          _Section(
            title: 'Connection status',
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _Chip('Status', state.connectionLabel),
                _Chip('RSSI', state.rssi == null ? '—' : '${state.rssi} dBm'),
                _Chip('MTU', state.mtu?.toString() ?? '—'),
                _Chip('Duration', ctrl.connectionDurationLabel()),
                _Chip('Service', state.serviceFound ? '✓' : '—'),
                _Chip('Char 1', state.char1Found ? '✓' : '—'),
                _Chip('Char 4', state.char4Found ? '✓' : '—'),
                _Chip(
                  'Notify',
                  state.notificationsEnabled ? 'Subscribed' : '—',
                ),
              ],
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.busy ? null : ctrl.scan,
                  icon: Icon(
                    state.scanning ? Icons.hourglass_top : Icons.radar,
                  ),
                  label: Text(
                    state.scanning
                        ? 'Scanning…'
                        : state.busy
                            ? 'Working…'
                            : 'Scan',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.busy ? null : ctrl.disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Nearby devices (${state.devices.length})',
            child: state.devices.isEmpty
                ? Text(
                    mode == BleTransportMode.realBle
                        ? 'No devices — grant BT permissions, turn on Bluetooth, then Scan'
                        : 'No devices — tap Scan (Virtual MCU advertises one locker)',
                    style: AppTextStyles.caption,
                  )
                : Column(
                    children: state.devices.map((d) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bluetooth_searching),
                        title: Text(d.name, style: AppTextStyles.label),
                        subtitle: Text(
                          '${d.id}\nRSSI ${d.rssi ?? '—'} dBm'
                          '${d.isConnectable ? '' : ' · not connectable'}',
                          style: AppTextStyles.caption,
                        ),
                        isThreeLine: true,
                        trailing: FilledButton(
                          onPressed:
                              state.busy ? null : () => ctrl.connect(d),
                          child: const Text('Connect'),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          _Section(
            title: 'Discovered services & characteristics',
            child: state.services.isEmpty
                ? Text(
                    'Connect to run GATT discovery',
                    style: AppTextStyles.caption,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: state.services.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service ${s.uuid}',
                              style: AppTextStyles.label,
                            ),
                            ...s.characteristics.map((c) {
                              final tag = c.isCommand
                                  ? ' [Char 1 · Command]'
                                  : c.isStatus
                                      ? ' [Char 4 · Status]'
                                      : '';
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '  Char ${c.uuid}$tag\n    ${c.properties}',
                                  style: AppTextStyles.caption
                                      .copyWith(fontSize: 11),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          Text(
            'Phase 13A scope: scan → connect → discover → notify. '
            'Authentication and packet exchange are not enabled here.',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _UuidRow extends StatelessWidget {
  const _UuidRow(this.label, this.uuid);

  final String label;
  final String uuid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        SelectableText(
          uuid,
          style: AppTextStyles.label.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('$label: $value', style: AppTextStyles.caption),
    );
  }
}
