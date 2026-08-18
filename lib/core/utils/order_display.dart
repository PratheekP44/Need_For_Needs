/// Customer-facing presentation helpers for orders.
/// Does not change stored IDs — only display.
library;

/// Short label for lists, e.g. `Order #2701` or truncated id.
String shortOrderLabel(String id) {
  final raw = id.trim();
  if (raw.isEmpty) return 'Order';
  // Prefer trailing digits / short suffix after last dash.
  final parts = raw.split(RegExp(r'[-_]'));
  final tail = parts.isNotEmpty ? parts.last : raw;
  final digits = RegExp(r'\d+').allMatches(tail).map((m) => m.group(0)!);
  if (digits.isNotEmpty) {
    final d = digits.last;
    final shown = d.length > 6 ? d.substring(d.length - 4) : d;
    return 'Order #$shown';
  }
  if (raw.length <= 10) return 'Order $raw';
  return 'Order ${raw.substring(raw.length - 6)}';
}

/// Compact date for list rows: `12 Aug`
String formatOrderDay(DateTime? when, {String fallback = ''}) {
  if (when == null) {
    if (fallback.isEmpty) return '';
    final parsed = DateTime.tryParse(fallback);
    if (parsed == null) return fallback;
    return formatOrderDay(parsed);
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = when.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}

/// Detail timestamp: `12 Aug, 2:14 PM`
String formatOrderDateTime(DateTime? when) {
  if (when == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = when.toLocal();
  final h24 = local.hour;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final ampm = h24 >= 12 ? 'PM' : 'AM';
  final min = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]}, $h12:$min $ampm';
}

/// Soften backend payment status for customers.
String friendlyPaymentLabel(String paymentStatus) {
  final s = paymentStatus.trim().toLowerCase();
  if (s.isEmpty) return '';
  if (s.contains('paid') || s.contains('success') || s.contains('captured')) {
    return 'Paid';
  }
  if (s.contains('fail') || s.contains('error')) return 'Payment failed';
  if (s.contains('pending') || s.contains('created')) return 'Pending';
  return paymentStatus;
}

/// Soften order status for customers.
///
/// Prefers backend enums (`READY_FOR_COLLECTION`) when passed; also accepts
/// already-mapped labels (`Ready to collect`).
String friendlyOrderStatus(String status) {
  final raw = status.trim();
  if (raw.isEmpty) return 'Unknown';

  final enumKey = raw.toUpperCase().replaceAll(' ', '_');
  switch (enumKey) {
    case 'READY_FOR_COLLECTION':
    case 'READY_TO_COLLECT':
      return 'Ready for collection';
    case 'WAITING_PAYMENT':
    case 'CREATED':
    case 'AWAITING_PAYMENT':
      return 'Awaiting payment';
    case 'PAYMENT_SUCCESS':
    case 'PAID':
      return 'Paid';
    case 'COLLECTED':
      return 'Collected';
    case 'CANCELLED':
    case 'CANCELED':
      return 'Cancelled';
    case 'EXPIRED':
      return 'Expired';
  }

  final lower = raw.toLowerCase();
  if (lower.contains('ready')) return 'Ready for collection';
  if (lower.contains('collect') && !lower.contains('ready')) {
    return 'Collected';
  }
  if (lower.contains('expir')) return 'Expired';
  if (lower.contains('cancel')) return 'Cancelled';
  if (lower.contains('paid') || lower.contains('confirm')) return 'Paid';
  if (lower.contains('await') || lower.contains('waiting')) {
    return 'Awaiting payment';
  }
  return raw;
}

/// Zero-padded box label for Collect UI (`3` → `03`).
String formatBoxLabel(int boxNumber) {
  if (boxNumber < 0) return '$boxNumber';
  return boxNumber.toString().padLeft(2, '0');
}
