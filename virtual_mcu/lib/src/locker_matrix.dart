import 'box_runtime.dart';
import 'simulation_config.dart';

/// Configurable N×M locker box matrix (default 4×4 = 16).
class LockerMatrix {
  LockerMatrix(this.config) {
    _boxes = [
      for (var i = 1; i <= config.boxCount; i++)
        BoxRuntime(
          boxId: _boxIdFor(i),
          itemId: i <= 8 ? 'ITM-${i.toString().padLeft(2, '0')}' : null,
          itemName: i <= 8 ? 'Demo Item $i' : null,
          quantity: i <= 8 ? 1 : 0,
        ),
    ];
  }

  final SimulationConfig config;
  late final List<BoxRuntime> _boxes;

  String get lockerId => config.lockerId;
  List<BoxRuntime> get boxes => List.unmodifiable(_boxes);

  static String _boxIdFor(int index) =>
      'BOX-${index.toString().padLeft(2, '0')}';

  BoxRuntime? find(String boxId) {
    for (final b in _boxes) {
      if (b.boxId == boxId) return b;
    }
    return null;
  }

  bool get anyBusy => _boxes.any((b) => b.busy);

  void reserve(String boxId) {
    final box = find(boxId);
    if (box == null) throw StateError('unknown box');
    box.reserved = true;
  }

  void release(String boxId) {
    final box = find(boxId);
    if (box == null) return;
    box.reserved = false;
    box.busy = false;
  }

  void simulateCollection(String boxId) {
    final box = find(boxId);
    if (box == null) return;
    if (box.quantity > 0) box.quantity -= 1;
    if (box.quantity <= 0) {
      box.itemId = null;
      box.itemName = null;
    }
    box.reserved = false;
    box.busy = false;
  }

  void reset() {
    for (var i = 0; i < _boxes.length; i++) {
      final n = i + 1;
      _boxes[i] = BoxRuntime(
        boxId: _boxIdFor(n),
        itemId: n <= 8 ? 'ITM-${n.toString().padLeft(2, '0')}' : null,
        itemName: n <= 8 ? 'Demo Item $n' : null,
        quantity: n <= 8 ? 1 : 0,
      );
    }
  }

  Map<String, Object?> snapshot() => {
        'lockerId': lockerId,
        'rows': config.rows,
        'cols': config.cols,
        'boxes': _boxes.map((b) => b.toJson()).toList(),
      };
}
