import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../api/api_client.dart';
import '../api/repositories.dart';
import '../location/location_service.dart';

/// Thrown for user-visible payment failures (cancel, gateway, verify, network).
class PaymentFlowException implements Exception {
  PaymentFlowException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Progress labels for checkout UI (TEST MODE Razorpay only — no mocks).
typedef CheckoutProgress = void Function(String step);

/// Checkout → Razorpay TEST order → Checkout SDK → backend verify.
///
/// Never trusts Flutter success alone. Signature verification is server-side.
/// Key ID comes only from `POST /payment/create-order` (never Key Secret).
class CheckoutPaymentService {
  CheckoutPaymentService({
    required this.orders,
    required this.payments,
  });

  final OrderRepository orders;
  final PaymentRepository payments;

  Future<OrderPaymentResult> payCart({CheckoutProgress? onProgress}) async {
    String orderId = '';
    var openedCheckout = false;

    try {
      onProgress?.call('Creating order…');
      final orderRaw = await orders.checkoutRaw();
      orderId = orderRaw['id']?.toString() ?? '';
      if (orderId.isEmpty) {
        throw PaymentFlowException('Checkout did not return an order id');
      }

      onProgress?.call('Creating Razorpay payment…');
      final created = await payments.createOrder(orderId: orderId);
      final razorpay =
          Map<String, dynamic>.from(created['razorpay'] as Map? ?? {});

      if (razorpay['mock'] == true) {
        throw PaymentFlowException(
          'Server returned mock payment mode — configure Razorpay TEST keys '
          '(RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET) on the backend',
          code: 'mock_disabled',
        );
      }

      final gatewayOrderId = razorpay['orderId']?.toString() ?? '';
      final keyId = razorpay['keyId']?.toString() ?? '';

      if (gatewayOrderId.isEmpty) {
        throw PaymentFlowException('Payment gateway order id missing');
      }
      if (keyId.isEmpty) {
        throw PaymentFlowException('Razorpay Key ID missing from server');
      }
      if (!keyId.startsWith('rzp_test_')) {
        throw PaymentFlowException(
          'Only Razorpay TEST MODE keys (rzp_test_*) are allowed',
          code: 'invalid_key_mode',
        );
      }

      if (!_razorpaySdkSupported) {
        throw PaymentFlowException(
          'Razorpay Checkout requires Android or iOS',
          code: 'unsupported_platform',
        );
      }

      onProgress?.call('Opening Razorpay Checkout…');
      openedCheckout = true;
      final result = await _openRazorpaySdk(razorpay);
      final paymentId = result.paymentId;
      final signature = result.signature;
      if (paymentId.isEmpty || signature.isEmpty) {
        throw PaymentFlowException(
          'Incomplete Razorpay response',
          code: 'incomplete_checkout',
        );
      }

      onProgress?.call('Verifying payment…');
      final verified = await payments.verify(
        razorpayOrderId: gatewayOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        paymentMethod: 'razorpay',
      );

      final orderMap = Map<String, dynamic>.from(
        verified['order'] as Map? ?? created['order'] as Map? ?? orderRaw,
      );
      final paymentMap = Map<String, dynamic>.from(
        verified['payment'] as Map? ?? {},
      );
      final status = orderMap['status']?.toString() ?? '';
      if (status.isNotEmpty && status != 'READY_FOR_COLLECTION') {
        throw PaymentFlowException(
          'Payment verified but order status is $status',
          code: 'unexpected_status',
        );
      }

      onProgress?.call('Payment confirmed');
      return OrderPaymentResult(
        orderId: orderId,
        orderNumber: orderMap['orderNumber']?.toString() ?? orderId,
        lockerName: _lockerName(orderMap),
        lockerNumber: _lockerCode(orderMap),
        boxes: _boxes(orderMap),
        total: asDouble(orderMap['grandTotal']),
        subtotal: asDouble(orderMap['subtotal']),
        tax: asDouble(orderMap['tax']),
        status: status.isEmpty ? 'READY_FOR_COLLECTION' : status,
        collectionToken: orderMap['collectionToken']?.toString() ?? '',
        paymentId: paymentMap['id']?.toString() ??
            orderMap['paymentId']?.toString() ??
            '',
        gatewayPaymentId: paymentMap['gatewayPaymentId']?.toString() ??
            orderMap['gatewayPaymentId']?.toString() ??
            paymentId,
        transactionId: orderMap['transactionId']?.toString() ?? '',
      );
    } on PaymentFlowException catch (e) {
      if (openedCheckout &&
          orderId.isNotEmpty &&
          (e.code == 'user_cancelled' ||
              e.code == 'payment_failed' ||
              e.code == 'external_wallet' ||
              e.code == 'timeout')) {
        await _safeFail(orderId, e.message);
      }
      rethrow;
    } on ApiException catch (e) {
      throw PaymentFlowException(e.message, code: 'api_${e.statusCode}');
    } catch (e) {
      throw PaymentFlowException(
        e.toString().replaceFirst('Exception: ', ''),
        code: 'network_or_unknown',
      );
    }
  }

  Future<void> _safeFail(String orderId, String reason) async {
    try {
      await payments.fail(orderId: orderId, reason: reason);
    } catch (_) {}
  }

  bool get _razorpaySdkSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<({String paymentId, String signature})> _openRazorpaySdk(
    Map<String, dynamic> razorpay,
  ) async {
    final completer = Completer<({String paymentId, String signature})>();
    final sdk = Razorpay();

    void clear() {
      sdk.clear();
    }

    sdk.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      if (!completer.isCompleted) {
        completer.complete((
          paymentId: response.paymentId ?? '',
          signature: response.signature ?? '',
        ));
      }
      clear();
    });
    sdk.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      if (!completer.isCompleted) {
        final code = '${response.code ?? ''}';
        final message = response.message ?? 'Payment failed';
        final cancelled = code == '2' ||
            message.toLowerCase().contains('cancel');
        completer.completeError(
          PaymentFlowException(
            cancelled ? 'Payment cancelled' : message,
            code: cancelled ? 'user_cancelled' : 'payment_failed',
          ),
        );
      }
      clear();
    });
    sdk.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      if (!completer.isCompleted) {
        final wallet = response.walletName ?? 'external wallet';
        completer.completeError(
          PaymentFlowException(
            'External wallet selected ($wallet). Complete payment in the wallet '
            'app, then return — or choose another method in Checkout.',
            code: 'external_wallet',
          ),
        );
      }
      clear();
    });

    try {
      sdk.open({
        'key': razorpay['keyId'],
        'amount': razorpay['amount'],
        'currency': razorpay['currency'] ?? 'INR',
        'name': razorpay['name'] ?? 'Campus Essentials',
        'description': razorpay['description'] ?? 'Order payment',
        'order_id': razorpay['orderId'],
        'retry': {'enabled': true, 'max_count': 3},
        'theme': {'color': '#1B7A4E'},
      });
    } catch (e) {
      clear();
      throw PaymentFlowException(
        'Unable to open Razorpay Checkout: $e',
        code: 'checkout_open_failed',
      );
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw PaymentFlowException(
        'Payment timed out',
        code: 'timeout',
      ),
    );
  }

  String _lockerName(Map<String, dynamic> order) {
    final locker = order['locker'];
    if (locker is Map) return locker['lockerName']?.toString() ?? 'Locker';
    return 'Locker';
  }

  String _lockerCode(Map<String, dynamic> order) {
    final locker = order['locker'];
    if (locker is Map) return locker['lockerId']?.toString() ?? '—';
    return '—';
  }

  List<String> _boxes(Map<String, dynamic> order) {
    final items = order['items'];
    if (items is! List) return const [];
    final boxes = <String>{};
    for (final line in items) {
      if (line is! Map) continue;
      final box = line['box'];
      if (box is Map) {
        final label = box['boxNumber']?.toString() ?? box['boxId']?.toString();
        if (label != null && label.isNotEmpty) boxes.add(label);
      }
    }
    return boxes.toList();
  }
}

class OrderPaymentResult {
  const OrderPaymentResult({
    required this.orderId,
    required this.orderNumber,
    required this.lockerName,
    required this.lockerNumber,
    required this.boxes,
    required this.total,
    this.subtotal = 0,
    this.tax = 0,
    this.status = 'READY_FOR_COLLECTION',
    this.collectionToken = '',
    this.paymentId = '',
    this.gatewayPaymentId = '',
    this.transactionId = '',
  });

  final String orderId;
  final String orderNumber;
  final String lockerName;
  final String lockerNumber;
  final List<String> boxes;
  final double total;
  final double subtotal;
  final double tax;
  final String status;
  final String collectionToken;
  final String paymentId;
  final String gatewayPaymentId;
  final String transactionId;
}
