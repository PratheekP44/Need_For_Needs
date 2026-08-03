import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/fake_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/responsive.dart';

class LockerDetailsScreen extends StatelessWidget {
  const LockerDetailsScreen({super.key, required this.lockerId});

  final String lockerId;

  @override
  Widget build(BuildContext context) {
    final locker = FakeData.lockerById(lockerId);
    final items = FakeData.productsForLocker(locker.id);
    final columns = responsiveColumns(context);

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
                          child: Text(locker.name, style: AppTextStyles.headline.copyWith(fontSize: 22)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
