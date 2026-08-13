import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/utils/locker_feedback.dart';

void main() {
  group('lockerOpenedHeadline', () {
    test('empty / single → Locker opened', () {
      expect(lockerOpenedHeadline(const []), 'Locker opened');
      expect(lockerOpenedHeadline(const [1]), 'Locker opened');
    });

    test('multiple → Lockers opened', () {
      expect(lockerOpenedHeadline(const [1, 3]), 'Lockers opened');
    });
  });

  group('lockerOpenedBoxesLine', () {
    test('single box', () {
      expect(lockerOpenedBoxesLine(const [1]), 'Box 1');
    });

    test('two boxes', () {
      expect(lockerOpenedBoxesLine(const [1, 3]), 'Boxes 1 and 3');
    });

    test('three+ boxes', () {
      expect(
        lockerOpenedBoxesLine(const [5, 1, 3]),
        'Boxes 1, 3 and 5',
      );
    });
  });

  group('lockerOpenedDetail', () {
    test('formats spoken success copy', () {
      expect(lockerOpenedDetail(const [1]), 'Box 1 opened');
      expect(lockerOpenedDetail(const [1, 3]), 'Boxes 1 and 3 opened');
      expect(
        lockerOpenedDetail(const [1, 3, 5]),
        'Boxes 1, 3 and 5 opened',
      );
    });
  });
}
