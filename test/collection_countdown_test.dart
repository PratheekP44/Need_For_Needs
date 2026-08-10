import 'package:flutter_test/flutter_test.dart';

import 'package:need_for_needs/core/utils/collection_countdown.dart';

void main() {
  test('countdown formats HH:MM:SS from collectionDeadline', () {
    final deadline = DateTime.utc(2026, 8, 10, 14, 0, 0);
    final now = DateTime.utc(2026, 8, 10, 12, 0, 1);
    final remaining = collectionRemaining(deadline: deadline, now: now);
    expect(formatCollectionCountdown(remaining), '01:59:59');
  });

  test('countdown at zero is 00:00:00', () {
    final deadline = DateTime.utc(2026, 8, 10, 14, 0, 0);
    final remaining = collectionRemaining(deadline: deadline, now: deadline);
    expect(formatCollectionCountdown(remaining), '00:00:00');
  });

  test('negative remaining clamps to 00:00:00', () {
    final deadline = DateTime.utc(2026, 8, 10, 14, 0, 0);
    final after = DateTime.utc(2026, 8, 10, 14, 0, 5);
    final remaining = collectionRemaining(deadline: deadline, now: after);
    expect(formatCollectionCountdown(remaining), '00:00:00');
  });
}
