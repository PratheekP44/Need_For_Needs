import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/catalog_refresh.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ux.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';

class LockerDetailsScreen extends ConsumerWidget {
  const LockerDetailsScreen({super.key, required this.lockerId});

  final String lockerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_lockerDetailsProvider(lockerId));
    final columns = responsiveColumns(context);

    return async.when(
      loading: () => const PageScaffold(
        title: 'Locker',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => PageScaffold(
        title: 'Locker',
        body: EmptyState(
          message: userFacingError(e),
          icon: Icons.error_outline_rounded,
        ),
      ),
      data: (data) {
        final locker = data.locker;
        final items = data.products;
        return PageScaffold(
          title: locker.name,
          padding: EdgeInsets.zero,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locker.name,
                        style: AppTextStyles.headline.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [
                          locker.status == 'Online' ? 'Available' : locker.status,
                          if (locker.availableItems > 0)
                            '${locker.availableItems} items',
                          if (locker.totalBoxes > 0)
                            '${locker.totalBoxes} boxes',
                          if (locker.distanceMeters > 0)
                            '${locker.distanceMeters}m',
                        ].join(' · '),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                  child: Text('Items', style: AppTextStyles.title),
                ),
              ),
              if (items.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    message: 'No items here',
                    icon: Icons.inventory_2_outlined,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = items[index];
                        return ProductCard(
                          width: double.infinity,
                          product: product,
                          onTap: () => context.push('/product/${product.id}'),
                          onAddToCart: () async {
                            try {
                              await ref
                                  .read(cartViewModelProvider.notifier)
                                  .addStock(product);
                              if (context.mounted) {
                                showAppSnackBar(
                                  context,
                                  '${product.name} added to cart',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showAppSnackBar(context, userFacingError(e));
                              }
                              rethrow;
                            }
                          },
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LockerBundle {
  const _LockerBundle({required this.locker, required this.products});
  final Locker locker;
  final List<Product> products;
}

final _lockerDetailsProvider =
    FutureProvider.family<_LockerBundle, String>((ref, id) async {
  ref.watch(inventoryEpochProvider);
  final products = await ref.read(catalogRepositoryProvider).listStock(lockerId: id);
  final locker = await ref.read(lockerRepositoryProvider).getById(
        id,
        availableItems: products.length,
      );
  return _LockerBundle(locker: locker, products: products);
});
