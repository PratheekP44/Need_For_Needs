import 'package:intl/intl.dart';

/// Indian Rupee formatting (₹) for all customer-facing amounts.
abstract final class MoneyFormat {
  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String format(num amount) => _inr.format(amount);
}
