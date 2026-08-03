import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable UI state placeholder for Payment.
class PaymentState {
  const PaymentState({this.message = 'Payment placeholder'});

  final String message;

  PaymentState copyWith({String? message}) {
    return PaymentState(message: message ?? this.message);
  }
}

/// Riverpod ViewModel skeleton for Payment (MVVM).
class PaymentViewModel extends Notifier<PaymentState> {
  @override
  PaymentState build() => const PaymentState();
}

final paymentViewModelProvider =
    NotifierProvider<PaymentViewModel, PaymentState>(PaymentViewModel.new);
