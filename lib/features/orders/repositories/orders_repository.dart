import '../../../core/repositories/base_repository.dart';
import '../models/orders_model.dart';

/// Repository skeleton for the Orders feature.
abstract class OrdersRepository extends BaseRepository {
  const OrdersRepository();

  Future<OrdersModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class OrdersRepositoryImpl implements OrdersRepository {
  const OrdersRepositoryImpl();

  @override
  Future<OrdersModel?> fetchPlaceholder() async => null;
}
