import '../../../core/repositories/base_repository.dart';
import '../models/inventory_model.dart';

/// Repository skeleton for the Inventory feature.
abstract class InventoryRepository extends BaseRepository {
  const InventoryRepository();

  Future<InventoryModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class InventoryRepositoryImpl implements InventoryRepository {
  const InventoryRepositoryImpl();

  @override
  Future<InventoryModel?> fetchPlaceholder() async => null;
}
