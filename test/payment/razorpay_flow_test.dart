import 'package:flutter_test/flutter_test.dart';
import 'package:need_for_needs/core/payment/checkout_payment_service.dart';
import 'package:need_for_needs/core/utils/money_format.dart';

void main() {
  group('MoneyFormat INR', () {
    test('uses rupee symbol', () {
      final formatted = MoneyFormat.format(1234.5);
      expect(formatted.contains('₹'), isTrue);
      expect(formatted.contains(r'$'), isFalse);
    });
  });

  group('PaymentFlowException', () {
    test('exposes message and code', () {
      const message = 'Payment cancelled';
      final err = PaymentFlowException(message, code: 'user_cancelled');
      expect(err.message, message);
      expect(err.code, 'user_cancelled');
      expect(err.toString(), message);
    });
  });

  group('OrderPaymentResult', () {
    test('defaults to READY_FOR_COLLECTION', () {
      const result = OrderPaymentResult(
        orderId: '1',
        orderNumber: 'ORD-1',
        lockerName: 'Hub',
        lockerNumber: 'L1',
        boxes: ['1'],
        total: 100,
        subtotal: 95,
        tax: 5,
        gatewayPaymentId: 'pay_test_1',
        collectionToken: 'CE1.ORD-1.LCK.BOX.1.abcd',
      );
      expect(result.status, 'READY_FOR_COLLECTION');
      expect(result.tax, 5);
      expect(result.gatewayPaymentId, 'pay_test_1');
      expect(result.collectionToken.startsWith('CE1.'), isTrue);
    });
  });
}
