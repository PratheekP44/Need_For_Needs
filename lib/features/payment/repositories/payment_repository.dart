import '../../../core/repositories/base_repository.dart';
import '../models/payment_model.dart';

/// Repository skeleton for the Payment feature.
abstract class PaymentRepository extends BaseRepository {
  const PaymentRepository();

  Future<PaymentModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl();

  @override
  Future<PaymentModel?> fetchPlaceholder() async => null;
}
