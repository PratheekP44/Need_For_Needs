import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ble/ble.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/ble_demo_packet_request.dart';
import '../viewmodels/ble_demo_viewmodel.dart';

/// Admin engineering tool — real locker BLE without payment / unlock JWT.
///
/// Does not replace or touch the production Collect flow.
class BleDemoScreen extends ConsumerWidget {
  const BleDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bleDemoViewModelProvider);
    final vm = ref.read(bleDemoViewModelProvider.notifier);
    final mode = ref.watch(bleConfigProvider.notifier).mode;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BLE Demo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteConstants.adminDashboard);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Clear logs',
            onPressed: vm.clearLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
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
                  onSelectionChanged: state.busy
                      ? null
                      : (set) {
                          ref
                              .read(bleConfigProvider.notifier)
                              .setMode(set.first);
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  mode == BleTransportMode.realBle
                      ? 'Real radio → firmware validation (LKRM-V2)'
                      : 'Virtual MCU — offline bring-up only (not real firmware)',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          _Section(
            title: 'Connection',
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _Chip('Status', state.connectionLabel),
                _Chip('MTU', state.mtu?.toString() ?? '—'),
                _Chip(
                  'Write',
                  state.writeSucceeded == null
                      ? '—'
                      : state.writeSucceeded!
                          ? 'OK'
                          : 'Failed',
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
          _Section(
            title: 'Controls',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: state.lockerDeviceName,
                  decoration: const InputDecoration(
                    labelText: 'Locker Device',
                    hintText: 'LKRM-V2',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: vm.updateLockerDeviceName,
                ),
                const SizedBox(height: 12),
                Text('Command', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: BleDemoCommandKind.values.map((kind) {
                    final selected = state.commandKind == kind;
                    return ChoiceChip(
                      label: Text(kind.label),
                      selected: selected,
                      onSelected: (_) => vm.updateCommandKind(kind),
                    );
                  }).toList(),
                ),
                if (state.commandKind == BleDemoCommandKind.custom) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: state.customOpcode
                        .toRadixString(16)
                        .padLeft(2, '0')
                        .toUpperCase(),
                    decoration: const InputDecoration(
                      labelText: 'Custom opcode (hex)',
                      hintText: 'FF',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixText: '0x',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9a-fA-F]'),
                      ),
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (v) {
                      final parsed = int.tryParse(v, radix: 16);
                      if (parsed != null) vm.updateCustomOpcode(parsed);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _IntField(
                        label: 'Terminal Number',
                        value: state.terminalNumber,
                        onChanged: vm.updateTerminal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _IntField(
                        label: 'Port Number',
                        value: state.portNumber,
                        onChanged: vm.updatePort,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Boxes (bitmap) — select one or more',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var b = 1; b <= 32; b++)
                      FilterChip(
                        label: Text('$b', style: const TextStyle(fontSize: 12)),
                        selected: state.selectedBoxes.contains(b),
                        onSelected: (_) => vm.toggleBox(b),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Selected: ${state.boxNumbersSorted.join(', ')}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: state.orderId,
                  decoration: const InputDecoration(
                    labelText: 'Order ID (optional)',
                    hintText: 'max 8 ASCII on wire',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: vm.updateOrderId,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: state.itemId,
                  decoration: const InputDecoration(
                    labelText: 'Item ID (optional)',
                    hintText: 'max 8 ASCII on wire',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: vm.updateItemId,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: state.transactionId,
                  decoration: const InputDecoration(
                    labelText: 'Transaction ID (optional)',
                    hintText: 'max 6 ASCII on wire',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: vm.updateTransactionId,
                ),
                const SizedBox(height: 8),
                Text(
                  'Opcode 0x${state.effectiveCommand.toRadixString(16).padLeft(2, '0').toUpperCase()} · '
                  '32-byte RealPacketBuilder (bitmap Bytes[2..5], no Phase-10 / JSON)',
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.busy ? null : vm.scan,
                  icon: Icon(
                    state.scanning ? Icons.hourglass_top : Icons.radar,
                  ),
                  label: Text(state.scanning ? 'Scanning…' : 'SCAN'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.busy ? null : vm.connect,
                  icon: const Icon(Icons.bluetooth_connected),
                  label: const Text('CONNECT'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.busy ? null : vm.disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('DISCONNECT'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                  ),
                  onPressed: state.busy ? null : vm.sendPacket,
                  icon: const Icon(Icons.send),
                  label: const Text('SEND PACKET'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.devices.isNotEmpty)
            _Section(
              title: 'Nearby devices (${state.devices.length})',
              child: Column(
                children: state.devices.take(12).map((d) {
                  final highlight = d.isTargetLocker ||
                      d.name.toLowerCase().contains(
                            state.lockerDeviceName.toLowerCase(),
                          );
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      highlight
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_searching,
                      color: highlight ? AppColors.primary : null,
                    ),
                    title: Text(
                      highlight ? '★ ${d.name}' : d.name,
                      style: AppTextStyles.label,
                    ),
                    subtitle: Text(
                      '${d.id} · RSSI ${d.rssi ?? '—'}',
                      style: AppTextStyles.caption,
                    ),
                  );
                }).toList(),
              ),
            ),
          if (state.lastPacketHex != null)
            _Section(
              title: 'Last packet',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Length: ${state.lastPacketLength}',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    state.lastPacketHex!,
                    style: AppTextStyles.caption.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          _Section(
            title: 'Received Data',
            child: state.received == null
                ? Text(
                    'No notification yet — SEND PACKET and wait',
                    style: AppTextStyles.caption,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Kv('HEX', state.received!.hex),
                      const SizedBox(height: 8),
                      _Kv('ASCII', state.received!.ascii),
                      const SizedBox(height: 8),
                      _Kv('Length', '${state.received!.length}'),
                      const SizedBox(height: 8),
                      _Kv(
                        'Timestamp',
                        state.received!.timestamp.toIso8601String(),
                      ),
                      if (state.received!.parsedKind != null) ...[
                        const SizedBox(height: 8),
                        _Kv(
                          'Parsed',
                          '${state.received!.parsedKind}'
                          '${state.received!.parsedMessage != null ? ' — ${state.received!.parsedMessage}' : ''}',
                        ),
                      ],
                    ],
                  ),
          ),
          _Section(
            title: 'Logs',
            child: state.logs.isEmpty
                ? Text('No logs yet', style: AppTextStyles.caption)
                : SizedBox(
                    height: 280,
                    child: ListView.builder(
                      itemCount: state.logs.length,
                      itemBuilder: (context, i) {
                        final e = state.logs[state.logs.length - 1 - i];
                        final t =
                            '${e.at.hour.toString().padLeft(2, '0')}:'
                            '${e.at.minute.toString().padLeft(2, '0')}:'
                            '${e.at.second.toString().padLeft(2, '0')}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '[$t] ${e.message}',
                            style: AppTextStyles.caption.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: e.isError
                                  ? AppColors.error
                                  : AppColors.onBackground,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          Text(
            'Engineering tool only — no payment, orders, unlock JWT, or '
            'production Collect path. Packet = RealPacketBuilder 32 bytes.',
            style: AppTextStyles.caption.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: '$value',
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null && n >= 0 && n <= 255) onChanged(n);
      },
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        SelectableText(
          value,
          style: AppTextStyles.label.copyWith(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('$label: $value', style: AppTextStyles.caption),
    );
  }
}
