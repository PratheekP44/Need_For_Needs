import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mappers.dart';
import '../../../core/data/models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/ux.dart';

class HomeState {
  const HomeState({
    this.lockers = const [],
    this.products = const [],
    this.popular = const [],
    this.newest = const [],
    this.recent = const [],
    this.categories = const [],
    this.isLoading = true,
    this.error,
  });

  final List<Locker> lockers;
  final List<Product> products;
  final List<Product> popular;
  final List<Product> newest;
  final List<Product> recent;
  final List<ProductCategory> categories;
  final bool isLoading;
  final String? error;
}

class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() {
    ref.listen(authSessionProvider, (prev, next) {
      if (next.isAuthenticated) refresh();
    });
    Future.microtask(refresh);
    return const HomeState();
  }

  Future<void> refresh() async {
    if (!ref.read(authSessionProvider).isAuthenticated) {
      state = const HomeState(isLoading: false);
      return;
    }
    state = HomeState(
      lockers: state.lockers,
      products: state.products,
      popular: state.popular,
      newest: state.newest,
      recent: state.recent,
      categories: state.categories,
      isLoading: true,
    );
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final lockersFuture = ref.read(lockerRepositoryProvider).list();
      final homeFuture = catalog.fetchHomeCatalog();
      final productsFuture = catalog.listStock(limit: 60);

      final lockers = await lockersFuture;
      final home = await homeFuture;
      final products = await productsFuture;

      // Categories are derived only from currently available catalog items —
      // never from a static/hardcoded backend category list.
      final categories = categoriesFromProducts(products);

      state = HomeState(
        lockers: lockers,
        products: products,
        popular: home.popular.isNotEmpty ? home.popular : products.take(8).toList(),
        newest: home.newest.isNotEmpty ? home.newest : products.take(8).toList(),
        recent: home.recent.isNotEmpty
            ? home.recent
            : home.newest.take(4).toList(),
        categories: categories,
        isLoading: false,
      );
    } catch (e) {
      state = HomeState(
        isLoading: false,
        error: userFacingError(e),
        lockers: state.lockers,
        products: state.products,
        popular: state.popular,
        newest: state.newest,
        recent: state.recent,
        categories: state.categories,
      );
    }
  }
}

final homeViewModelProvider =
    NotifierProvider<HomeViewModel, HomeState>(HomeViewModel.new);
