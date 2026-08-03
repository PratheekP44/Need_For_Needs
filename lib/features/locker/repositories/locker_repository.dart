import '../../../core/repositories/base_repository.dart';
import '../models/locker_model.dart';

/// Repository skeleton for the Locker feature.
abstract class LockerRepository extends BaseRepository {
  const LockerRepository();

  Future<LockerModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class LockerRepositoryImpl implements LockerRepository {
  const LockerRepositoryImpl();

  @override
  Future<LockerModel?> fetchPlaceholder() async => null;
}
