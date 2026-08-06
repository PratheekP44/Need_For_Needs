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
        body: Center(child: Text(e.toString())),
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
                  child: SoftPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                locker.name,
                                style: AppTextStyles.headline.copyWith(fontSize: 22),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.chip,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(locker.status, style: AppTextStyles.label),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${locker.distanceMeters}m away - ${locker.availableItems} available items',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Open boxes ${locker.openBoxes}/${locker.totalBoxes}',
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text('Available items', style: AppTextStyles.title),
                ),
              ),
              if (items.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    message: 'No items available in this locker',
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
                      childAspectRatio: 0.72,
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
