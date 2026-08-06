import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:virtual_mcu/virtual_mcu.dart';

import '../../../core/ble/ble.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../models/dashboard_models.dart';
import '../providers/developer_dashboard_provider.dart';
import '../theme/dev_dash_theme.dart';

class DeveloperDashboardScreen extends ConsumerWidget {
  const DeveloperDashboardScreen({super.key});

  void _leave(BuildContext context, WidgetRef ref) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final auth = ref.read(authSessionProvider);
    if (auth.isAuthenticated) {
      context.go(
        auth.isAdmin ? RouteConstants.adminDashboard : RouteConstants.home,
      );
    } else {
      context.go(RouteConstants.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(developerDashboardProvider);
    final ctrl = ref.read(developerDashboardProvider.notifier);

    return Theme(
      data: DevDashColors.theme(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => _leave(context, ref),
          ),
          title: const Text('Developer Dashboard · Virtual MCU'),
          actions: [
            IconButton(
              tooltip: 'BLE Debug (CC2340)',
              onPressed: () => context.push(RouteConstants.bleDebug),
              icon: const Icon(Icons.bluetooth_searching),
            ),
            if (state.demoStatus != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    state.demoStatus!,
                    style: const TextStyle(color: DevDashColors.accent, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
        body: !state.mcuAvailable
            ? _VirtualMcuOfflinePanel(
                onUseVirtualMcu: () {
                  ref.read(bleConfigProvider.notifier).useVirtualMcu();
                },
                onOpenBleDebug: () => context.push(RouteConstants.bleDebug),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Section(
                        title: '1 · MCU Status',
                        child: _McuStatusPanel(status: state.status),
                      ),
                      _Section(
                        title: '2 · Locker Matrix (${state.matrixRows}×${state.matrixCols})',
                        child: _LockerMatrixPanel(
                          rows: state.matrixRows,
                          cols: state.matrixCols,
                          boxes: state.boxes,
                          selectedId: state.selectedBoxId,
                          onSelect: ctrl.selectBox,
                        ),
                      ),
                      _Section(
                        title: '3 · Box Details',
                        child: _BoxDetailsPanel(box: ctrl.selectedBox()),
                      ),
                      wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _Section(
                                    title: '4 · Packet Monitor',
                                    child: _PacketMonitorPanel(state: state, ctrl: ctrl),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Section(
                                    title: '5 · Event Log',
                                    child: _EventLogPanel(events: state.events),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _Section(
                                  title: '4 · Packet Monitor',
                                  child: _PacketMonitorPanel(state: state, ctrl: ctrl),
                                ),
                                _Section(
                                  title: '5 · Event Log',
                                  child: _EventLogPanel(events: state.events),
                                ),
                              ],
                            ),
                      _Section(
                        title: '6 · MCU Variable Table',
                        child: _McuTablePanel(rows: state.tableRows),
                      ),
                      _Section(
                        title: '7 · Simulation Panel',
                        child: _SimulationPanel(ctrl: ctrl),
                      ),
                      _Section(
                        title: '8 · Stats',
                        child: _StatsPanel(stats: state.stats),
                      ),
                      _Section(
                        title: '9 · Live Architecture Diagram',
                        child: _SystemDiagram(active: state.activeNode),
                      ),
                      _Section(
                        title: '10 · Test Demos',
                        child: _TestModePanel(ctrl: ctrl),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _VirtualMcuOfflinePanel extends StatelessWidget {
  const _VirtualMcuOfflinePanel({
    required this.onUseVirtualMcu,
    required this.onOpenBleDebug,
  });

  final VoidCallback onUseVirtualMcu;
  final VoidCallback onOpenBleDebug;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Virtual MCU is not active.\n'
              'Real BLE (CC2340) transport is selected.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onUseVirtualMcu,
              child: const Text('Switch to Virtual MCU'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onOpenBleDebug,
              child: const Text('Open BLE Debug'),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DevDashColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DevDashColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                  color: DevDashColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DevDashColors.accentBlue;
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 12)),
    );
  }
}

class _McuStatusPanel extends StatelessWidget {
  const _McuStatusPanel({required this.status});
  final McuStatusView? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) return const Text('No status');
    return Wrap(
      children: [
        _Chip('MCU ${s.mcuId}'),
        _Chip('FW ${s.firmwareVersion}'),
        _Chip('Virtual ${s.virtualMcuVersion}'),
        _Chip(
          s.bleConnected ? 'BLE Connected' : 'BLE Down',
          color: s.bleConnected ? DevDashColors.accent : DevDashColors.danger,
        ),
        _Chip(
          s.authenticated ? 'Authenticated' : 'Unauthenticated',
          color: s.authenticated ? DevDashColors.accent : DevDashColors.warn,
        ),
        _Chip('User ${s.currentUser ?? '-'}'),
        _Chip('Order ${s.currentOrder ?? '-'}'),
        _Chip('Locker ${s.lockerId}'),
        _Chip('Battery ${s.batteryPercent}%', color: s.batteryPercent < 15 ? DevDashColors.danger : null),
        _Chip('Temp ${s.temperatureC.toStringAsFixed(1)}°C'),
        _Chip('RSSI ${s.rssi}', color: s.rssi < -85 ? DevDashColors.warn : null),
        _Chip('HB ${s.heartbeatCounter}'),
        _Chip('Pkts ${s.packetCounter}'),
        _Chip('Uptime ${s.uptimeSeconds}s'),
        _Chip('Last ${s.lastPacket ?? '-'}'),
        _Chip('ACK ${s.lastAck ?? '-'}'),
        _Chip('Err ${s.lastError ?? 'none'}', color: s.lastError == null ? DevDashColors.accent : DevDashColors.danger),
      ],
    );
  }
}

class _LockerMatrixPanel extends StatelessWidget {
  const _LockerMatrixPanel({
    required this.rows,
    required this.cols,
    required this.boxes,
    required this.selectedId,
    required this.onSelect,
  });

  final int rows;
  final int cols;
  final List<BoxRuntime> boxes;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 8,
          children: [
            _Chip('Green Available', color: DevDashColors.accent),
            _Chip('Blue Reserved', color: DevDashColors.accentBlue),
            _Chip('Yellow Opening', color: DevDashColors.warn),
            _Chip('Red Fault', color: DevDashColors.danger),
            _Chip('Grey Empty', color: DevDashColors.grey),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: boxes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols.clamp(1, 8),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final box = boxes[index];
            final color = boxStatusColor(
              empty: box.isEmpty,
              reserved: box.reserved,
              busy: box.busy,
              doorState: box.doorState.name,
              motorState: box.motorState.name,
            );
            final selected = box.boxId == selectedId;
            return InkWell(
              onTap: () {
                onSelect(box.boxId);
                showDialog<void>(
                  context: context,
                  builder: (_) => _BoxDialog(box: box),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : color,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(box.boxId, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    Text(
                      box.itemName ?? 'Empty',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: DevDashColors.text),
                    ),
                    Text('qty ${box.quantity}', style: const TextStyle(fontSize: 10, color: DevDashColors.muted)),
                    const Spacer(),
                    Text(
                      '${box.doorState.name} · ${box.lockState.name}',
                      style: const TextStyle(fontSize: 10, color: DevDashColors.muted),
                    ),
                    Text(
                      box.busy
                          ? 'BUSY'
                          : box.reserved
                              ? 'RESERVED'
                              : box.isEmpty
                                  ? 'EMPTY'
                                  : 'OK',
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BoxDialog extends StatelessWidget {
  const _BoxDialog({required this.box});
  final BoxRuntime box;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DevDashColors.surface,
      title: Text(box.boxId),
      content: SingleChildScrollView(
        child: Text(
          const JsonEncoder.withIndent('  ').convert(box.toJson()),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class _BoxDetailsPanel extends StatelessWidget {
  const _BoxDetailsPanel({required this.box});
  final BoxRuntime? box;

  @override
  Widget build(BuildContext context) {
    final b = box;
    if (b == null) return const Text('Select a box in the matrix.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${b.boxId} · ${b.itemName ?? 'no item'} × ${b.quantity}'),
        const SizedBox(height: 8),
        Wrap(
          children: [
            _Chip('Door ${b.doorState.name}'),
            _Chip('Lock ${b.lockState.name}'),
            _Chip('Motor ${b.motorState.name}'),
            _Chip('Sensor ${b.sensorState.name}'),
            _Chip('Reserved ${b.reserved}'),
            _Chip('Busy ${b.busy}'),
            _Chip('Opened ${b.lastOpened?.toIso8601String() ?? '-'}'),
            _Chip('Pkt ${b.lastPacket ?? '-'}'),
            _Chip('Err ${b.lastError ?? 'none'}', color: b.lastError == null ? DevDashColors.accent : DevDashColors.danger),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          const JsonEncoder.withIndent('  ').convert(b.toJson()),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: DevDashColors.muted),
        ),
      ],
    );
  }
}

class _PacketMonitorPanel extends StatelessWidget {
  const _PacketMonitorPanel({required this.state, required this.ctrl});
  final DeveloperDashboardState state;
  final DeveloperDashboardController ctrl;

  @override
  Widget build(BuildContext context) {
    final filters = <String?>[null, 'AUTH', 'OPEN', 'STATUS', 'PING', 'ERROR', 'HEARTBEAT'];
    final packets = state.packets.reversed.where((p) {
      final f = state.packetFilter;
      if (f == null) return true;
      return p.packetType.contains(f);
    }).toList();

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in filters)
              ChoiceChip(
                label: Text(f ?? 'ALL'),
                selected: state.packetFilter == f,
                onSelected: (_) => ctrl.setPacketFilter(f),
              ),
            FilledButton.tonal(
              onPressed: ctrl.togglePacketPause,
              child: Text(state.packetPaused ? 'Resume' : 'Pause'),
            ),
            FilledButton.tonal(onPressed: ctrl.clearPackets, child: const Text('Clear')),
            FilledButton.tonal(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: ctrl.exportPacketsJson()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Packet log copied')),
                  );
                }
              },
              child: const Text('Export'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: ListView.builder(
            itemCount: packets.length,
            itemBuilder: (context, index) {
              final p = packets[index];
              final dir = p.direction == PacketDirection.appToMcu ? 'App→MCU' : 'MCU→App';
              return ListTile(
                dense: true,
                title: Text('$dir · ${p.packetType} · seq ${p.sequenceNumber}'),
                subtitle: Text('${p.payload} · ${p.ack} · ${p.result}'),
                trailing: Text(
                  p.timestamp.toIso8601String().substring(11, 19),
                  style: const TextStyle(fontSize: 11, color: DevDashColors.muted),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EventLogPanel extends StatelessWidget {
  const _EventLogPanel({required this.events});
  final List<RuntimeLogEntry> events;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final e = events[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.timeline, size: 16, color: DevDashColors.accentBlue),
            title: Text(e.event),
            subtitle: Text(
              [
                if (e.packet != null) 'pkt=${e.packet}',
                if (e.box != null) 'box=${e.box}',
                if (e.door != null) 'door=${e.door}',
                if (e.lock != null) 'lock=${e.lock}',
                if (e.result != null) 'result=${e.result}',
              ].join(' · '),
            ),
            trailing: Text(
              e.timestamp.toIso8601String().substring(11, 19),
              style: const TextStyle(fontSize: 11, color: DevDashColors.muted),
            ),
          );
        },
      ),
    );
  }
}

class _McuTablePanel extends StatelessWidget {
  const _McuTablePanel({required this.rows});
  final List<McuTableRow> rows;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 700),
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 40,
            columns: const [
              DataColumn(label: Text('Timestamp')),
              DataColumn(label: Text('Variable')),
              DataColumn(label: Text('Previous')),
              DataColumn(label: Text('Current')),
              DataColumn(label: Text('Reason')),
            ],
            rows: [
              for (final r in rows.take(80))
                DataRow(
                  cells: [
                    DataCell(Text(r.timestamp.toIso8601String().substring(11, 19))),
                    DataCell(Text(r.variable)),
                    DataCell(Text(r.previousValue)),
                    DataCell(Text(r.currentValue)),
                    DataCell(Text(r.reason)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimulationPanel extends StatelessWidget {
  const _SimulationPanel({required this.ctrl});
  final DeveloperDashboardController ctrl;

  @override
  Widget build(BuildContext context) {
    final actions = <(String, Future<void> Function()?)>[
      ('Authenticate', ctrl.simulateAuthenticate),
      ('Disconnect', ctrl.simulateDisconnect),
      ('Reconnect', ctrl.simulateReconnect),
      ('Heartbeat', ctrl.simulateHeartbeat),
      ('Open Box', ctrl.simulateOpenBox),
      ('Close Door', ctrl.simulateCloseDoor),
      ('Reset MCU', () async => ctrl.simulateResetMcu()),
      ('Reset Locker', () async => ctrl.simulateResetLocker()),
      ('Reserve Box', () async => ctrl.simulateReserveBox()),
      ('Release Box', () async => ctrl.simulateReleaseBox()),
      ('Low Battery', () async => ctrl.simulateLowBattery()),
      ('Low RSSI', () async => ctrl.simulateLowRssi()),
      ('Door Jam', () async => ctrl.simulateDoorJam()),
      ('Motor Failure', () async => ctrl.simulateMotorFailure()),
      ('CRC Failure', ctrl.simulateCrcFailure),
      ('Timeout', ctrl.simulateTimeout),
      ('Packet Loss', ctrl.simulatePacketLoss),
      ('Busy Locker', () async => ctrl.simulateBusyLocker()),
      ('Invalid Token', ctrl.simulateInvalidToken),
      ('Expired Token', ctrl.simulateExpiredToken),
      ('Wrong Box', ctrl.simulateWrongBox),
      ('Door Already Open', () async => ctrl.simulateDoorAlreadyOpen()),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in actions)
          FilledButton.tonal(
            onPressed: () => a.$2?.call(),
            child: Text(a.$1),
          ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        _Chip('Sent ${stats.packetsSent}'),
        _Chip('Recv ${stats.packetsReceived}'),
        _Chip('ACK ${stats.ackCount}'),
        _Chip('Errors ${stats.errorCount}', color: DevDashColors.danger),
        _Chip('Opens ${stats.doorOpens}'),
        _Chip('Closes ${stats.doorCloses}'),
        _Chip('Auth ${stats.authCount}'),
        _Chip('Reconnects ${stats.reconnectCount}'),
        _Chip('Avg ${stats.averageResponseMs.toStringAsFixed(0)} ms'),
        _Chip('Success ${stats.successPercent.toStringAsFixed(1)}%'),
      ],
    );
  }
}

class _SystemDiagram extends StatelessWidget {
  const _SystemDiagram({required this.active});
  final ArchitectureNode active;

  @override
  Widget build(BuildContext context) {
    final nodes = [
      (ArchitectureNode.flutterApp, 'Flutter App'),
      (ArchitectureNode.lockerService, 'LockerService'),
      (ArchitectureNode.bleProtocol, 'BleProtocol'),
      (ArchitectureNode.virtualMcuTransport, 'VirtualMCUTransport'),
      (ArchitectureNode.mcuCore, 'MCUCore'),
      (ArchitectureNode.lockerMatrix, 'Locker Matrix'),
    ];
    return Column(
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: nodes[i].$1 == active
                  ? DevDashColors.accent.withValues(alpha: 0.2)
                  : DevDashColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: nodes[i].$1 == active ? DevDashColors.accent : DevDashColors.border,
              ),
            ),
            child: Text(
              nodes[i].$2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: nodes[i].$1 == active ? FontWeight.w700 : FontWeight.w500,
                color: nodes[i].$1 == active ? DevDashColors.accent : DevDashColors.text,
              ),
            ),
          ),
          if (i < nodes.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(Icons.arrow_downward, size: 16, color: DevDashColors.muted),
            ),
        ],
      ],
    );
  }
}

class _TestModePanel extends StatelessWidget {
  const _TestModePanel({required this.ctrl});
  final DeveloperDashboardController ctrl;

  @override
  Widget build(BuildContext context) {
    final demos = <(String, Future<void> Function())>[
      ('Run Authentication Demo', ctrl.runAuthDemo),
      ('Run Purchase Demo', ctrl.runPurchaseDemo),
      ('Run Open Box Demo', ctrl.runOpenBoxDemo),
      ('Run Timeout Demo', ctrl.runTimeoutDemo),
      ('Run Packet Loss Demo', ctrl.runPacketLossDemo),
      ('Run Door Jam Demo', ctrl.runDoorJamDemo),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in demos)
          FilledButton(
            onPressed: d.$2,
            child: Text(d.$1),
          ),
      ],
    );
  }
}
