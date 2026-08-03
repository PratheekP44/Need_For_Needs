import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/fake_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeViewModelProvider);
    final columns = responsiveColumns(context);
    final firstName = FakeData.user.name.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 900,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: FadeSlideIn(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good afternoon, $firstName', style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text('What do you need?', style: AppTextStyles.headline),
                        const SizedBox(height: 16),
                        const AppSearchField(),
                        const SizedBox(height: 20),
                        SectionHeader(
                          title: 'Nearby locker',
                          actionLabel: 'See all',
                          onAction: () => context.push('/locker/${FakeData.lockers.first.id}'),
                        ),
                        const SizedBox(height: 10),
                        LockerCard(locker: FakeData.lockers.first),
                        const SizedBox(height: 24),
                        const SectionHeader(title: 'Categories'),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 92,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: FakeData.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final category = FakeData.categories[index];
                      return Container(
                        width: 88,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_categoryIcon(category.icon), color: AppColors.primary),
                            const SizedBox(height: 8),
                            Text(category.name, style: AppTextStyles.caption),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: SectionHeader(
                    title: 'Popular items',
                    actionLabel: 'Browse',
                    onAction: () => context.push('/locker/l1'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 250,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: FakeData.popularProducts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final product = FakeData.popularProducts[index];
                      return ProductCard(
                        product: product,
                        onTap: () => context.push('/product/${product.id}'),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: Text('Recently purchased', style: AppTextStyles.title),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = FakeData.recentProducts[index];
                      return ProductCard(
                        width: double.infinity,
                        product: product,
                        onTap: () => context.push('/product/${product.id}'),
                      );
                    },
                    childCount: FakeData.recentProducts.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String key) {
    return switch (key) {
      'cookie' => Icons.cookie_outlined,
      'local_cafe' => Icons.local_cafe_outlined,
      'edit' => Icons.edit_outlined,
      'soap' => Icons.clean_hands_outlined,
      'headphones' => Icons.headphones_outlined,
      _ => Icons.category_outlined,
    };
  }
}
