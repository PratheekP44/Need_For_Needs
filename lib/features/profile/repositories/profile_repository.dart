import '../../../core/repositories/base_repository.dart';
import '../models/profile_model.dart';

/// Repository skeleton for the Profile feature.
abstract class ProfileRepository extends BaseRepository {
  const ProfileRepository();

  Future<ProfileModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl();

  @override
  Future<ProfileModel?> fetchPlaceholder() async => null;
}
