import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _selectedCategoryId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<Product> _filterProducts(List<Product> products) {
    var list = products;
    if (_selectedCategoryId != null) {
      final selected = _selectedCategoryId!.toUpperCase();
      list = list
          .where((p) => p.categoryId.toUpperCase() == selected)
          .toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q) ||
                p.categoryId.toLowerCase().contains(q) ||
                p.lockerName.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  void _openFilters(List<ProductCategory> categories) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter by category', style: AppTextStyles.title),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = null);
                        Navigator.pop(context);
                      },
                    ),
                    ...categories.map(
                      (c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _selectedCategoryId == c.id,
                        onSelected: (_) {
                          setState(() => _selectedCategoryId = c.id);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeViewModelProvider);
    final auth = ref.watch(authSessionProvider);
    final columns = responsiveColumns(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final homeBrandIcon = (screenWidth * 0.135).clamp(48.0, 58.0);
    // Slightly larger wordmark; centered in space after the locker (not full-screen).
    final homeBrandTitle = (screenWidth * 0.105).clamp(40.0, 50.0);
    final firstName = (auth.user?.name ?? 'there').split(' ').first;
    final lockers = home.lockers;
    final categories = home.categories;

    // Drop a selected category if inventory refresh removed it.
    if (_selectedCategoryId != null &&
        !categories.any(
          (c) => c.id.toUpperCase() == _selectedCategoryId!.toUpperCase(),
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedCategoryId = null);
      });
    }

    final filtered = _filterProducts(home.products);
    final searching = _query.trim().isNotEmpty || _selectedCategoryId != null;
    final popular =
        searching ? filtered : _filterProducts(home.popular);
    final recent = searching
        ? filtered.take(8).toList()
        : _filterProducts(home.recent.isNotEmpty ? home.recent : home.newest);
    final recentTitle =
        home.recent.isNotEmpty ? 'Buy again' : 'Recently added';
    final noAvailableItems =
        home.products.where((p) => p.isAvailable).isEmpty && !searching;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 900,
          child: home.isLoading && home.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(homeViewModelProvider.notifier).refresh(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: FadeSlideIn(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      AppBrand.icon(
                                        iconHeight: homeBrandIcon,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Center(
                                          child: AppBrand.wordmark(
                                            titleHeight: homeBrandTitle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  '${_greeting()}, $firstName',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 16),
                                AppSearchField(
                                  controller: _search,
                                  onChanged: (value) =>
                                      setState(() => _query = value),
                                  onFilterPressed: categories.isEmpty
                                      ? null
                                      : () => _openFilters(categories),
                                ),
                                const SizedBox(height: 20),
                                const SectionHeader(title: 'Nearby locker'),
                                const SizedBox(height: 10),
                                if (lockers.isNotEmpty)
                                  LockerCard(locker: lockers.first)
                                else
                                  SoftPanel(
                                    child: Text(
                                      home.error ?? 'No lockers found nearby',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                if (!noAvailableItems) ...[
                                  const SizedBox(height: 24),
                                  const SectionHeader(title: 'Categories'),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!noAvailableItems)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 100,
                            child: categories.isEmpty
                                ? Center(
                                    child: Text(
                                      'No categories with available items',
                                      style: AppTextStyles.caption,
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: categories.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final category = categories[index];
                                      final selected =
                                          _selectedCategoryId == category.id;
                                      return Material(
                                        color: selected
                                            ? AppColors.chip
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          onTap: () {
                                            setState(() {
                                              _selectedCategoryId = selected
                                                  ? null
                                                  : category.id;
                                            });
                                          },
                                          child: Ink(
                                            width: 88,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: selected
                                                    ? AppColors.primary
                                                    : AppColors.border,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _categoryIcon(category.icon),
                                                  size: 22,
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  category.name,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: AppTextStyles.caption,
                                                ),
                                              ],
                                            ),
                                          ),
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
                            title: noAvailableItems
                                ? 'Items'
                                : (_selectedCategoryId == null &&
                                        _query.isEmpty
                                    ? 'Popular items'
                                    : 'Results'),
                          ),
                        ),
                      ),
                      if (noAvailableItems)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                            child: EmptyState(
                              message: 'No products available',
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 260,
                            child: popular.isEmpty
                                ? EmptyState(
                                    message: _query.isNotEmpty ||
                                            _selectedCategoryId != null
                                        ? 'No items match your search'
                                        : 'No products available',
                                    icon: Icons.search_off_rounded,
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: popular.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final product = popular[index];
                                      return ProductCard(
                                        product: product,
                                        onAddToCart: () =>
                                            _addToCart(context, ref, product),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      if (!noAvailableItems) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                            child: Text(
                              recentTitle,
                              style: AppTextStyles.title,
                            ),
                          ),
                        ),
                        if (recent.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                              child: EmptyState(
                                message: 'No recent purchases yet',
                                icon: Icons.history_rounded,
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.68,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final product = recent[index];
                                  return ProductCard(
                                    width: double.infinity,
                                    product: product,
                                    onAddToCart: () =>
                                        _addToCart(context, ref, product),
                                  );
                                },
                                childCount: recent.length,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
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
      'inventory_2' => Icons.inventory_2_outlined,
      _ => Icons.category_outlined,
    };
  }
}

Future<void> _addToCart(
  BuildContext context,
  WidgetRef ref,
  Product product,
) async {
  try {
    await ref.read(cartViewModelProvider.notifier).addStock(product);
    // Button shows brief "Added"; snackbar kept as secondary confirmation.
    if (context.mounted) {
      showAppSnackBar(context, 'Added to cart');
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, userFacingError(e));
      rethrow;
    }
  }
}
