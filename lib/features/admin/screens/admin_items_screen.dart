import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ux.dart';
import '../viewmodels/admin_viewmodel.dart';

/// Master catalogue management — separate from physical box Inventory.
class AdminItemsScreen extends ConsumerStatefulWidget {
  const AdminItemsScreen({super.key});

  @override
  ConsumerState<AdminItemsScreen> createState() => _AdminItemsScreenState();
}

class _AdminItemsScreenState extends ConsumerState<AdminItemsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(catalogRepositoryProvider).listItems(
            search: search ?? _search.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(e);
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load(search: value.trim());
    });
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? 'this item';
    final id = item['id']?.toString() ?? item['itemId']?.toString() ?? '';
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
          'Are you sure you want to delete this item from the catalogue?\n\n'
          'Items assigned to inventory boxes cannot be deleted until removed '
          'from Inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = id);
    try {
      await ref.read(catalogRepositoryProvider).deleteItem(id);
      await ref.read(adminViewModelProvider.notifier).refresh();
      if (!mounted) return;
      showAppSnackBar(context, 'Deleted $name');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e is ApiException && e.message.trim().isNotEmpty
            ? e.message
            : userFacingError(e),
      );
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Item Management',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(RouteConstants.adminItemsAdd);
          if (mounted) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Master product catalogue. Assign items to physical boxes in Inventory.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Search items',
              hintText: 'Name, category, brand…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _load(search: v.trim()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyState(
                        message: _error!,
                        icon: Icons.error_outline,
                        actionLabel: 'Retry',
                        onAction: () => _load(),
                      )
                    : _items.isEmpty
                        ? EmptyState(
                            message: _search.text.trim().isEmpty
                                ? 'No items in the catalogue yet'
                                : 'No items match your search',
                            icon: Icons.category_outlined,
                            actionLabel: 'Add Item',
                            onAction: () async {
                              await context.push(RouteConstants.adminItemsAdd);
                              if (mounted) _load();
                            },
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(),
                            child: ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                final id = item['id']?.toString() ??
                                    item['itemId']?.toString() ??
                                    '';
                                final name = item['name']?.toString() ?? 'Item';
                                final category =
                                    item['category']?.toString() ?? '—';
                                final price = item['sellingPrice'] is num
                                    ? (item['sellingPrice'] as num).toDouble()
                                    : double.tryParse(
                                          '${item['sellingPrice']}',
                                        ) ??
                                        0;
                                final imageUrl =
                                    item['imageUrl']?.toString() ?? '';
                                final deleting = _deletingId == id;

                                return SoftPanel(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ProductImage(
                                        imageUrl: imageUrl,
                                        height: 56,
                                        width: 56,
                                        borderRadius: 10,
                                        iconSize: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: AppTextStyles.body
                                                  .copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              category.replaceAll('_', ' '),
                                              style: AppTextStyles.caption,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              MoneyFormat.format(price),
                                              style: AppTextStyles.label
                                                  .copyWith(
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed: deleting
                                            ? null
                                            : () async {
                                                await context.push(
                                                  '/admin/items/edit/$id',
                                                );
                                                if (mounted) _load();
                                              },
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        onPressed: deleting
                                            ? null
                                            : () => _confirmDelete(item),
                                        icon: deleting
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.delete_outline_rounded,
                                                color: AppColors.error,
                                              ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
