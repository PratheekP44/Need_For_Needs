import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/data/models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/product_image_picker.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      showAppSnackBar(context, 'Enter admin email and password');
      return;
    }
    setState(() => _busy = true);
    try {
      final user = await ref.read(authSessionProvider.notifier).login(
            email,
            password,
          );
      if (!mounted) return;
      // Admin access depends ONLY on backend role — never email heuristics.
      if (!user.isAdmin) {
        await ref.read(authSessionProvider.notifier).logout();
        if (!mounted) return;
        showAppSnackBar(context, 'Admin role required. Access denied.');
        return;
      }
      context.go('/admin/dashboard');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin login')),
      body: ResponsiveCenter(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Campus operator access', style: AppTextStyles.headline),
            const SizedBox(height: 8),
            Text(
              'Manage lockers, inventory, and campus orders.',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Admin email',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showAppSnackBar(
                  context,
                  'Dev reset: run npm run seed:admin (or POST /auth/dev/reset-admin-password)',
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: _busy ? 'Checking…' : 'Enter Dashboard',
              onPressed: _busy ? null : _enter,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSessionProvider);
    if (!auth.isAdmin) {
      return PageScaffold(
        title: 'Admin dashboard',
        showBack: true,
        body: Center(
          child: Text(
            'Admin role required',
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
          ),
        ),
      );
    }

    final state = ref.watch(adminViewModelProvider);
    final stats = state.stats;
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return PageScaffold(
      title: 'Admin dashboard',
      showBack: true,
      actions: [
        IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.storefront_outlined),
          tooltip: 'Customer app',
        ),
      ],
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(adminViewModelProvider.notifier).refresh(),
              child: ListView(
                children: [
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        state.error!,
                        style: AppTextStyles.caption.copyWith(color: AppColors.error),
                      ),
                    ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: wide ? 4 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: wide ? 1.2 : 1.05,
                    children: [
                      StatCard(
                        label: 'Total lockers',
                        value: '${stats.totalLockers}',
                        icon: Icons.meeting_room_outlined,
                      ),
                      StatCard(
                        label: 'Lockers online',
                        value: '${stats.lockersOnline > 0 ? stats.lockersOnline : stats.availableLockers}',
                        icon: Icons.lock_open_rounded,
                        color: AppColors.secondary,
                      ),
                      StatCard(
                        label: 'Orders today',
                        value: '${stats.ordersToday}',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.accent,
                      ),
                      StatCard(
                        label: 'Revenue today',
                        value: MoneyFormat.format(stats.revenueToday),
                        icon: Icons.payments_outlined,
                        color: AppColors.success,
                      ),
                      StatCard(
                        label: 'Users',
                        value: '${stats.totalUsers}',
                        icon: Icons.people_outline,
                      ),
                      StatCard(
                        label: 'Items',
                        value: '${stats.totalItems}',
                        icon: Icons.inventory_2_outlined,
                      ),
                      StatCard(
                        label: 'Low / out of stock',
                        value: '${stats.lowStockCount}/${stats.outOfStockCount}',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.error,
                      ),
                      StatCard(
                        label: 'Empty / occupied boxes',
                        value: '${stats.emptyBoxes}/${stats.occupiedBoxes}',
                        icon: Icons.grid_view_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SoftPanel(
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inventory status', style: AppTextStyles.label),
                              Text(stats.inventoryStatus, style: AppTextStyles.body),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Quick actions', style: AppTextStyles.title),
                  const SizedBox(height: 10),
                  _AdminAction(
                    icon: Icons.lock_outline_rounded,
                    label: 'Locker management',
                    onTap: () => context.push('/admin/lockers'),
                  ),
                  _AdminAction(
                    icon: Icons.inventory_outlined,
                    label: 'Inventory management',
                    onTap: () => context.push('/admin/inventory'),
                  ),
                  _AdminAction(
                    icon: Icons.list_alt_rounded,
                    label: 'Orders management',
                    onTap: () => context.push('/admin/orders'),
                  ),
                  _AdminAction(
                    icon: Icons.developer_board_rounded,
                    label: 'Virtual MCU',
                    onTap: () => context.push(RouteConstants.adminVirtualMcu),
                  ),
                  _AdminAction(
                    icon: Icons.bluetooth_searching_rounded,
                    label: 'BLE Debug (Phase 13A)',
                    onTap: () => context.push(RouteConstants.adminBleDebug),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftPanel(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label, style: AppTextStyles.body),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class AdminLockerManagementScreen extends ConsumerWidget {
  const AdminLockerManagementScreen({super.key});

  Future<void> _editTerminal(BuildContext context, WidgetRef ref, Locker locker) async {
    final controller = TextEditingController(
      text: locker.terminalNumber?.toString() ?? '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Terminal — ${locker.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Terminal number (1–255)',
            helperText: 'Physical locker controller id',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n == null || n < 1 || n > 255) {
                showAppSnackBar(ctx, 'Enter an integer from 1 to 255');
                return;
              }
              Navigator.of(ctx).pop(n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || !context.mounted) return;
    try {
      await ref.read(lockerRepositoryProvider).update(
            locker.id,
            terminalNumber: value,
          );
      await ref.read(adminViewModelProvider.notifier).refresh();
      if (!context.mounted) return;
      showAppSnackBar(context, 'Terminal $value saved for ${locker.name}');
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        e is ApiException && e.message.trim().isNotEmpty
            ? e.message
            : userFacingError(e),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminViewModelProvider);
    final columns = responsiveColumns(context, phone: 1, tablet: 2);

    return PageScaffold(
      title: 'Locker management',
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.lockers.isEmpty
              ? const EmptyState(
                  message: 'No lockers found',
                  icon: Icons.lock_outline_rounded,
                )
              : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: state.lockers.length,
              itemBuilder: (context, index) {
                final locker = state.lockers[index];
                return SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              locker.name,
                              style: AppTextStyles.title.copyWith(fontSize: 16),
                            ),
                          ),
                          Text(locker.status, style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Open boxes ${locker.openBoxes}/${locker.totalBoxes}',
                        style: AppTextStyles.body,
                      ),
                      Text(
                        locker.terminalNumber != null
                            ? 'Terminal ${locker.terminalNumber}'
                            : 'Terminal not set',
                        style: AppTextStyles.caption.copyWith(
                          color: locker.terminalNumber != null
                              ? AppColors.muted
                              : AppColors.error,
                        ),
                      ),
                      Text(
                        '${locker.distanceMeters}m away',
                        style: AppTextStyles.caption,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _editTerminal(context, ref, locker),
                            child: const Text('Set terminal'),
                          ),
                          FilledButton.tonal(
                            onPressed: () =>
                                context.push('/locker/${locker.id}'),
                            child: const Text('Manage'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class AdminInventoryScreen extends ConsumerStatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  ConsumerState<AdminInventoryScreen> createState() =>
      _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends ConsumerState<AdminInventoryScreen> {
  String? _deletingId;

  Future<void> _confirmDelete(InventoryRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete stock record?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.name, style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text('Locker: ${row.assignedLocker}'),
            Text(
              row.boxNumber != null
                  ? 'Box: #${row.boxNumber}'
                  : 'Box: —',
            ),
            const SizedBox(height: 12),
            Text(
              'This removes the physical stock record and marks the box as EMPTY. '
              'This cannot be undone.',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = row.id);
    try {
      await ref.read(catalogRepositoryProvider).deleteStock(row.id);
      await ref.read(adminViewModelProvider.notifier).refresh();
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Deleted ${row.name} from box'
        '${row.boxNumber != null ? ' #${row.boxNumber}' : ''}. Box is now empty.',
      );
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
    final state = ref.watch(adminViewModelProvider);

    return PageScaffold(
      title: 'Inventory',
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'assign-stock',
            onPressed: () => context.push('/admin/inventory/assign'),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Assign stock'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add-item',
            onPressed: () => context.push('/admin/inventory/add'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.inventory.isEmpty
              ? const EmptyState(
                  message: 'No inventory items yet',
                  icon: Icons.inventory_2_outlined,
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.sizeOf(context).width - 40,
                    ),
                    child: DataTable(
                      headingRowColor:
                          WidgetStatePropertyAll(AppColors.surfaceMuted),
                      columns: const [
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Locker')),
                        DataColumn(label: Text('Box')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: state.inventory.map((row) {
                        final deleting = _deletingId == row.id;
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: ProductImage(
                                  imageUrl: row.imageUrl,
                                  height: 44,
                                  width: 44,
                                  borderRadius: 8,
                                  iconSize: 20,
                                ),
                              ),
                            ),
                            DataCell(Text(row.name)),
                            DataCell(Text(MoneyFormat.format(row.price))),
                            DataCell(Text('${row.quantity}')),
                            DataCell(Text(row.assignedLocker)),
                            DataCell(
                              Text(
                                row.boxNumber != null
                                    ? '#${row.boxNumber}'
                                    : '—',
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: deleting
                                        ? null
                                        : () {
                                            final target = row.itemId.isNotEmpty
                                                ? row.itemId
                                                : row.id;
                                            context.push(
                                              '/admin/inventory/edit/$target',
                                            );
                                          },
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete stock',
                                    onPressed:
                                        deleting ? null : () => _confirmDelete(row),
                                    icon: deleting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppColors.error,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
    );
  }
}

class AdminAddItemScreen extends ConsumerStatefulWidget {
  const AdminAddItemScreen({super.key});

  @override
  ConsumerState<AdminAddItemScreen> createState() => _AdminAddItemScreenState();
}

class _AdminAddItemScreenState extends ConsumerState<AdminAddItemScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _itemId = TextEditingController();
  final _selling = TextEditingController();
  final _cost = TextEditingController();
  String _category = 'STATIONERY';
  List<String> _categories = const [
    'MEDICINE',
    'ELECTRONICS',
    'STATIONERY',
    'PERSONAL_CARE',
    'FOOD',
    'BEVERAGE',
    'ACCESSORY',
    'MISC',
  ];
  ProductImageSelection? _image;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final cats = await ref.read(catalogRepositoryProvider).listCategories();
        if (!mounted || cats.isEmpty) return;
        setState(() {
          _categories = cats.map((c) => c.id).toList();
          if (!_categories.contains(_category)) {
            _category = _categories.first;
          }
        });
      } catch (_) {}
    });
  }
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _brand.dispose();
    _barcode.dispose();
    _itemId.dispose();
    _selling.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final description = _description.text.trim();
    final brand = _brand.text.trim();
    final barcode = _barcode.text.trim();
    final selling = double.tryParse(_selling.text.trim());
    final cost = double.tryParse(_cost.text.trim()) ?? selling;
    if (name.isEmpty ||
        description.isEmpty ||
        brand.isEmpty ||
        barcode.isEmpty ||
        selling == null) {
      showAppSnackBar(context, 'Fill all required fields');
      return;
    }

    final itemId = _itemId.text.trim().isNotEmpty
        ? _itemId.text.trim().toUpperCase()
        : 'ITM-${DateTime.now().millisecondsSinceEpoch}';

    setState(() => _busy = true);
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final item = await catalog.createItem({
        'itemId': itemId,
        'name': name,
        'description': description,
        'category': _category,
        'brand': brand,
        'barcode': barcode,
        'sellingPrice': selling,
        'costPrice': cost ?? selling,
        'gstPercentage': 0,
        'unit': 'piece',
      });
      final mongoId = item['id']?.toString() ?? '';
      if (mongoId.isEmpty) {
        throw Exception('Item was created but no id was returned');
      }
      if (_image != null) {
        try {
          final uploaded = await catalog.uploadItemImage(
            itemId: mongoId,
            bytes: _image!.bytes,
            filename: _image!.filename,
          );
          final url = uploaded['imageUrl']?.toString() ?? '';
          if (url.isEmpty) {
            throw Exception('Image upload did not return imageUrl');
          }
        } catch (e) {
          if (!mounted) return;
          showAppSnackBar(
            context,
            'Item saved, but image upload failed: ${userFacingError(e)}',
          );
          final assign = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Assign to a box?'),
              content: const Text(
                'Item was created without an image. Assign stock now?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Assign stock'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          await ref.read(adminViewModelProvider.notifier).refresh();
          if (!mounted) return;
          if (assign == true) {
            context.push('/admin/inventory/assign?itemId=$mongoId');
          } else {
            context.pop();
          }
          return;
        }
      }
      await ref.read(adminViewModelProvider.notifier).refresh();
      if (!mounted) return;
      showAppSnackBar(
        context,
        _image != null ? 'Item created with image' : 'Item created',
      );
      final assign = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Assign to a box?'),
          content: const Text(
            'One box holds one stock record. Assign this item to an empty box now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Assign stock'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (assign == true) {
        context.push('/admin/inventory/assign?itemId=$mongoId');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Add item',
      bottom: PrimaryButton(
        label: _busy ? 'Saving…' : 'Save item',
        isLoading: _busy,
        onPressed: _busy ? null : _save,
      ),
      body: ListView(
        children: [
          ProductImagePickerField(
            onChanged: (value) => setState(() => _image = value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Item name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _itemId,
            decoration: const InputDecoration(
              labelText: 'Item ID (optional)',
              hintText: 'Auto-generated if empty',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brand,
            decoration: const InputDecoration(labelText: 'Brand *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barcode,
            decoration: const InputDecoration(labelText: 'Barcode *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _selling,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Selling price (₹) *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cost price (₹)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description *'),
          ),
        ],
      ),
    );
  }
}

class AdminEditItemScreen extends ConsumerStatefulWidget {
  const AdminEditItemScreen({super.key, required this.itemId});

  /// Stock mongo id from inventory row (we resolve item from stock).
  final String itemId;

  @override
  ConsumerState<AdminEditItemScreen> createState() =>
      _AdminEditItemScreenState();
}

class _AdminEditItemScreenState extends ConsumerState<AdminEditItemScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _brand = TextEditingController();
  final _selling = TextEditingController();
  final _cost = TextEditingController();
  String? _existingImageUrl;
  String? _itemMongoId;
  ProductImageSelection? _image;
  bool _imageCleared = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _brand.dispose();
    _selling.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final inventory = ref.read(adminViewModelProvider).inventory;
      final rowMatches = inventory.where((r) => r.id == widget.itemId);
      final row = rowMatches.isNotEmpty ? rowMatches.first : null;

      Map<String, dynamic>? itemMap;
      final candidates = <String>[
        if (row != null && row.itemId.isNotEmpty) row.itemId,
        widget.itemId,
      ];

      for (final candidate in candidates) {
        if (candidate.isEmpty) continue;
        try {
          itemMap = await catalog.getItem(candidate);
          break;
        } catch (_) {
          // Try next candidate / list fallback.
        }
      }

      if (itemMap == null) {
        final items = await catalog.listItems();
        for (final candidate in candidates) {
          for (final e in items) {
            if (e['id']?.toString() == candidate ||
                e['itemId']?.toString() == candidate) {
              itemMap = e;
              break;
            }
          }
          if (itemMap != null) break;
        }
        if (itemMap == null && row != null) {
          for (final e in items) {
            if (e['name']?.toString() == row.name) {
              itemMap = e;
              break;
            }
          }
        }
      }

      if (itemMap == null) {
        setState(() {
          _loading = false;
          _error = 'Item not found';
        });
        return;
      }

      _itemMongoId = itemMap['id']?.toString();
      _name.text = itemMap['name']?.toString() ?? '';
      _description.text = itemMap['description']?.toString() ?? '';
      _brand.text = itemMap['brand']?.toString() ?? '';
      _selling.text = '${itemMap['sellingPrice'] ?? ''}';
      _cost.text = '${itemMap['costPrice'] ?? ''}';
      _existingImageUrl = itemMap['imageUrl']?.toString();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = userFacingError(e);
      });
    }
  }

  Future<void> _save() async {
    final id = _itemMongoId;
    if (id == null || id.isEmpty) return;
    final selling = double.tryParse(_selling.text.trim());
    final cost = double.tryParse(_cost.text.trim());
    if (_name.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        selling == null) {
      showAppSnackBar(context, 'Name, description, and price are required');
      return;
    }

    setState(() => _busy = true);
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      await catalog.updateItem(id, {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'brand': _brand.text.trim(),
        'sellingPrice': selling,
        'costPrice': ?cost,
      });
      if (_imageCleared && _image == null) {
        await catalog.removeItemImage(id);
        _existingImageUrl = null;
      } else if (_image != null) {
        final uploaded = await catalog.uploadItemImage(
          itemId: id,
          bytes: _image!.bytes,
          filename: _image!.filename,
        );
        _existingImageUrl = uploaded['imageUrl']?.toString();
        if ((_existingImageUrl ?? '').isEmpty) {
          throw Exception('Image upload did not return imageUrl');
        }
      }
      await ref.read(adminViewModelProvider.notifier).refresh();
      if (!mounted) return;
      showAppSnackBar(context, 'Item updated');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageScaffold(
        title: 'Edit item',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return PageScaffold(
        title: 'Edit item',
        body: EmptyState(message: _error!, icon: Icons.error_outline),
      );
    }

    return PageScaffold(
      title: 'Edit item',
      bottom: PrimaryButton(
        label: _busy ? 'Updating…' : 'Update item',
        isLoading: _busy,
        onPressed: _busy ? null : _save,
      ),
      body: ListView(
        children: [
          ProductImagePickerField(
            existingImageUrl: _existingImageUrl,
            onChanged: (value) {
              setState(() {
                _image = value;
                _imageCleared = value == null;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Item name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brand,
            decoration: const InputDecoration(labelText: 'Brand'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _selling,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Selling price (₹)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cost price (₹)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
    );
  }
}

class AdminAssignStockScreen extends ConsumerStatefulWidget {
  const AdminAssignStockScreen({super.key, this.initialItemId});

  final String? initialItemId;

  @override
  ConsumerState<AdminAssignStockScreen> createState() =>
      _AdminAssignStockScreenState();
}

class _AdminAssignStockScreenState extends ConsumerState<AdminAssignStockScreen> {
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _emptyBoxes = const [];
  String? _itemId;
  final _qty = TextEditingController(text: '1');
  final Set<String> _selectedBoxIds = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  int get _needed {
    final n = int.tryParse(_qty.text.trim());
    return n == null || n < 1 ? 0 : n;
  }

  bool get _selectionComplete =>
      _needed >= 1 && _selectedBoxIds.length == _needed;

  @override
  void initState() {
    super.initState();
    _itemId = widget.initialItemId;
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final items = await catalog.listItems();
      final boxes = await catalog.listEmptyBoxes();
      setState(() {
        _items = items;
        _emptyBoxes = boxes;
        _loading = false;
        if (_itemId == null && items.isNotEmpty) {
          _itemId = items.first['id']?.toString();
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = userFacingError(e);
      });
    }
  }

  Future<void> _reloadEmptyBoxes() async {
    try {
      final boxes =
          await ref.read(catalogRepositoryProvider).listEmptyBoxes();
      if (!mounted) return;
      setState(() {
        _emptyBoxes = boxes;
        _selectedBoxIds.removeWhere(
          (id) => !boxes.any((b) => b['id']?.toString() == id),
        );
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, userFacingError(e));
    }
  }

  void _onQtyChanged(String _) {
    setState(() {
      // Drop excess selections if quantity was reduced.
      if (_selectedBoxIds.length > _needed && _needed >= 0) {
        final keep = _selectedBoxIds.take(_needed).toList();
        _selectedBoxIds
          ..clear()
          ..addAll(keep);
      }
    });
  }

  void _toggleBox(String boxId) {
    setState(() {
      if (_selectedBoxIds.contains(boxId)) {
        _selectedBoxIds.remove(boxId);
        return;
      }
      if (_needed < 1) {
        showAppSnackBar(context, 'Enter a quantity first');
        return;
      }
      if (_selectedBoxIds.length >= _needed) {
        showAppSnackBar(
          context,
          'Already selected $_needed / $_needed boxes',
        );
        return;
      }
      _selectedBoxIds.add(boxId);
    });
  }

  String _boxLabel(Map<String, dynamic> box) {
    final locker = box['locker'];
    String lockerName = 'Locker';
    if (locker is Map) {
      lockerName = locker['lockerName']?.toString() ??
          locker['lockerId']?.toString() ??
          'Locker';
    }
    final num = box['boxNumber'] ?? box['boxId'] ?? '';
    return '$lockerName · Box $num';
  }

  Future<void> _save() async {
    if (_itemId == null || _itemId!.isEmpty) {
      showAppSnackBar(context, 'Select an item');
      return;
    }
    final qty = _needed;
    if (qty < 1) {
      showAppSnackBar(context, 'Enter a quantity of at least 1');
      return;
    }
    if (_selectedBoxIds.length != qty) {
      showAppSnackBar(
        context,
        'Select exactly $qty empty box(es) — currently ${_selectedBoxIds.length} / $qty',
      );
      return;
    }

    final boxIds = _selectedBoxIds.toList();
    setState(() => _busy = true);
    try {
      final result = await ref.read(catalogRepositoryProvider).assignStockBatch(
            itemId: _itemId!,
            quantity: qty,
            boxIds: boxIds,
          );
      await ref.read(adminViewModelProvider.notifier).refresh();
      if (!mounted) return;
      final count = result['count'] ?? qty;
      showAppSnackBar(
        context,
        'Stocked $count unit(s) into $count box(es)',
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      // Prefer the API message for stocking (box occupied, not found, etc.).
      final message = e is ApiException && e.message.trim().isNotEmpty
          ? e.message
          : userFacingError(e);
      showAppSnackBar(context, message);
      await _reloadEmptyBoxes();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PageScaffold(
        title: 'Stock item',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return PageScaffold(
        title: 'Stock item',
        body: EmptyState(message: _error!, icon: Icons.error_outline),
      );
    }

    final needed = _needed;
    final selected = _selectedBoxIds.length;

    return PageScaffold(
      title: 'Stock item',
      bottom: PrimaryButton(
        label: _busy
            ? 'Saving…'
            : _selectionComplete
                ? 'Save $needed box assignment(s)'
                : 'Select $needed empty box(es)',
        isLoading: _busy,
        onPressed: (_busy || !_selectionComplete) ? null : _save,
      ),
      body: ListView(
        children: [
          Text(
            'One physical box holds exactly one item. '
            'Enter how many units to stock, then select that many empty boxes.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _itemId,
            decoration: const InputDecoration(labelText: 'Item'),
            items: _items
                .map(
                  (item) => DropdownMenuItem(
                    value: item['id']?.toString(),
                    child: Text(item['name']?.toString() ?? 'Item'),
                  ),
                )
                .where((e) => e.value != null && e.value!.isNotEmpty)
                .toList(),
            onChanged: (v) => setState(() => _itemId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity (units)',
              helperText: 'Each unit needs its own empty box',
            ),
            onChanged: _onQtyChanged,
          ),
          const SizedBox(height: 16),
          SoftPanel(
            child: Row(
              children: [
                Icon(
                  _selectionComplete
                      ? Icons.check_circle_rounded
                      : Icons.grid_view_rounded,
                  color: _selectionComplete
                      ? AppColors.success
                      : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected boxes', style: AppTextStyles.label),
                      Text(
                        needed < 1
                            ? 'Enter a quantity to begin'
                            : '$selected / $needed',
                        style: AppTextStyles.title.copyWith(
                          color: _selectionComplete
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _reloadEmptyBoxes,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Empty boxes', style: AppTextStyles.title),
          const SizedBox(height: 8),
          if (_emptyBoxes.isEmpty)
            const EmptyState(
              message: 'No empty boxes available',
              icon: Icons.inbox_outlined,
            )
          else
            ..._emptyBoxes.expand((box) {
              final id = box['id']?.toString() ?? '';
              if (id.isEmpty) return const <Widget>[];
              final checked = _selectedBoxIds.contains(id);
              final canSelect = needed >= 1 &&
                  (checked || _selectedBoxIds.length < needed);
              return [
                SoftPanel(
                  padding: EdgeInsets.zero,
                  child: CheckboxListTile(
                    value: checked,
                    onChanged: !canSelect && !checked
                        ? null
                        : (_) => _toggleBox(id),
                    title: Text(_boxLabel(box), style: AppTextStyles.body),
                    subtitle: Text(
                      box['boxId']?.toString() ?? id,
                      style: AppTextStyles.caption,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 8),
              ];
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminViewModelProvider);

    return PageScaffold(
      title: 'Orders management',
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.orders.isEmpty
              ? const EmptyState(
                  message: 'No orders yet',
                  icon: Icons.receipt_long_outlined,
                )
              : ListView.separated(
                  itemCount: state.orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = state.orders[index];
                    return SoftPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.id,
                                  style:
                                      AppTextStyles.title.copyWith(fontSize: 16),
                                ),
                              ),
                              Text(order.status, style: AppTextStyles.caption),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${order.lockerName} - ${order.itemCount} items',
                            style: AppTextStyles.body,
                          ),
                          Text(order.placedAt, style: AppTextStyles.caption),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: PriceText(order.total),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
