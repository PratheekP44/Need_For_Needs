import '../../../core/repositories/base_repository.dart';
import '../models/cart_model.dart';

/// Repository skeleton for the Cart feature.
abstract class CartRepository extends BaseRepository {
  const CartRepository();

  Future<CartModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class CartRepositoryImpl implements CartRepository {
  const CartRepositoryImpl();

  @override
  Future<CartModel?> fetchPlaceholder() async => null;
}
