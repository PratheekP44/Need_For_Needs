import '../../../core/repositories/base_repository.dart';
import '../models/admin_model.dart';

/// Repository skeleton for the Admin feature.
abstract class AdminRepository extends BaseRepository {
  const AdminRepository();

  Future<AdminModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl();

  @override
  Future<AdminModel?> fetchPlaceholder() async => null;
}
