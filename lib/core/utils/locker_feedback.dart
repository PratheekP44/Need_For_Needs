/// Customer-facing Collect unlock copy (no BLE / protocol terms).
library;

/// Primary success headline after a firmware ACK confirms unlock.
String lockerOpenedHeadline(List<int> boxNumbers) {
  final boxes = _sortedUnique(boxNumbers);
  if (boxes.isEmpty) return 'Locker opened';
  if (boxes.length == 1) return 'Locker opened';
  return 'Lockers opened';
}

/// Secondary line naming which box(es) opened.
String lockerOpenedBoxesLine(List<int> boxNumbers) {
  final boxes = _sortedUnique(boxNumbers);
  if (boxes.isEmpty) return '';
  if (boxes.length == 1) return 'Box ${boxes.first}';
  if (boxes.length == 2) {
    return 'Boxes ${boxes[0]} and ${boxes[1]}';
  }
  final head = boxes.sublist(0, boxes.length - 1).join(', ');
  return 'Boxes $head and ${boxes.last}';
}

/// Spoken / snackbar form, e.g. `Box 1 opened` or `Boxes 1, 3 and 5 opened`.
String lockerOpenedDetail(List<int> boxNumbers) {
  final boxes = _sortedUnique(boxNumbers);
  if (boxes.isEmpty) return 'Locker opened';
  if (boxes.length == 1) return 'Box ${boxes.first} opened';
  if (boxes.length == 2) {
    return 'Boxes ${boxes[0]} and ${boxes[1]} opened';
  }
  final head = boxes.sublist(0, boxes.length - 1).join(', ');
  return 'Boxes $head and ${boxes.last} opened';
}

List<int> _sortedUnique(List<int> boxNumbers) {
  final set = boxNumbers.toSet().toList()..sort();
  return set;
}
