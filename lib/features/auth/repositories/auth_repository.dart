import '../../../core/repositories/base_repository.dart';
import '../models/auth_model.dart';

/// Repository skeleton for the Auth feature.
abstract class AuthRepository extends BaseRepository {
  const AuthRepository();

  Future<AuthModel?> fetchPlaceholder();
}

/// Placeholder implementation with no business logic.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl();

  @override
  Future<AuthModel?> fetchPlaceholder() async => null;
}
