import '../../../core/repositories/base_repository.dart';
import '../models/home_model.dart';

/// Repository skeleton for the Home feature.
abstract class HomeRepository extends BaseRepository {
  const HomeRepository();

  Future<HomeModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl();

  @override
  Future<HomeModel?> fetchPlaceholder() async => null;
}
