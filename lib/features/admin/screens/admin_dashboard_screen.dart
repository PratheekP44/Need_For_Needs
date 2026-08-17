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
import '../../../core/utils/order_display.dart';
import '../../../core/utils/product_image_url.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/product_image.dart';
import '../../../core/widgets/item_image_url_field.dart';
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
        child: ListView(
          children: [
            const Center(
              child: AppBrand.full(iconHeight: 52, titleHeight: 32),
            ),
            const SizedBox(height: 24),
            Text('Admin access', style: AppTextStyles.headline),
            const SizedBox(height: 8),
            Text(
              'Manage lockers, inventory, items, and orders.',
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
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: AppBrand.full(
                      iconHeight: 40,
                      titleHeight: 28,
                      alignment: MainAxisAlignment.start,
                    ),
                  ),
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
                        useBrandGradient: true,
                      ),
                      StatCard(
                        label: 'Lockers online',
                        value: '${stats.lockersOnline > 0 ? stats.lockersOnline : stats.availableLockers}',
                        icon: Icons.lock_open_rounded,
                        useBrandGradient: true,
                      ),
                      StatCard(
                        label: 'Orders today',
                        value: '${stats.ordersToday}',
                        icon: Icons.receipt_long_outlined,
                        useBrandGradient: true,
                      ),
                      StatCard(
                        label: 'Revenue today',
                        value: MoneyFormat.format(stats.revenueToday),
                        icon: Icons.payments_outlined,
                        useBrandGradient: true,
                      ),
                      StatCard(
                        label: 'Users',
                        value: '${stats.totalUsers}',
                        icon: Icons.people_outline,
                        useBrandGradient: true,
                      ),
                      StatCard(
                        label: 'Items',
                        value: '${stats.totalItems}',
                        icon: Icons.inventory_2_outlined,
                        useBrandGradient: true,
                      ),
                      StatCard(
                        label: 'Low / out of stock',
                        value: '${stats.lowStockCount}/${stats.outOfStockCount}',
                        icon: Icons.warning_amber_rounded,
                        useBrandGradient: true,
                      ),
                      StatCard(
                        label: 'Empty / occupied boxes',
                        value: '${stats.emptyBoxes}/${stats.occupiedBoxes}',
                        icon: Icons.grid_view_rounded,
                        useBrandGradient: true,
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
                    icon: Icons.category_outlined,
                    label: 'Item Management',
                    onTap: () => context.push(RouteConstants.adminItems),
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
            helperText: 'Controller id for this locker',
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
                        locker.terminalNumber != null
                            ? '${locker.openBoxes}/${locker.totalBoxes} boxes open'
                            : '${locker.totalBoxes} boxes · set terminal',
                        style: AppTextStyles.caption.copyWith(
                          color: locker.terminalNumber != null
                              ? AppColors.muted
                              : AppColors.error,
                        ),
                      ),
                      Text(
                        '${locker.distanceMeters}m',
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
  static const _occupancyFilters = <(String, String)>[
    ('All Boxes', 'all'),
    ('Occupied', 'occupied'),
    ('Empty', 'empty'),
  ];

  String _occupancy = 'all';
  String? _lockerMongoId;
  List<Locker> _lockers = const [];
  PhysicalLockerInventory? _inventory;
  bool _loading = true;
  String? _error;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lockers = await ref.read(lockerRepositoryProvider).list();
      if (!mounted) return;
      String? preferred = _lockerMongoId;
      if (preferred == null || preferred.isEmpty) {
        final campus = lockers.where(
          (l) =>
              l.lockerCode.toUpperCase() == 'LCK-DEMO-06742' ||
              l.name.toLowerCase().contains('campus gate'),
        );
        preferred = campus.isNotEmpty
            ? campus.first.id
            : (lockers.isNotEmpty ? lockers.first.id : null);
      }
      final inventory = await ref
          .read(catalogRepositoryProvider)
          .listPhysicalInventory(
            lockerId: preferred,
            occupancy: _occupancy,
          );
      if (!mounted) return;
      setState(() {
        _lockers = lockers;
        _lockerMongoId = preferred;
        _inventory = inventory;
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

  Future<void> _reload() => _bootstrap();

  Future<void> _confirmRemove(InventoryRow row) async {
    final stockKey = row.id.startsWith('box:') ? '' : row.id;
    if (row.isEmpty || stockKey.isEmpty) {
      showAppSnackBar(context, 'Box is already empty');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item from box?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.displayName, style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text('Locker: ${row.assignedLocker}'),
            Text(
              row.boxNumber != null ? 'Box: #${row.boxNumber}' : 'Box: —',
            ),
            const SizedBox(height: 12),
            Text(
              'The physical box becomes EMPTY. The box itself is not deleted.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = row.id);
    try {
      await ref.read(catalogRepositoryProvider).deleteStock(stockKey);
      await ref.read(adminViewModelProvider.notifier).refresh();
      await _reload();
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Removed ${row.displayName} from box'
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
    final inv = _inventory;
    final summary = inv?.summary;

    return PageScaffold(
      title: 'Inventory',
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'assign-stock',
            backgroundColor: AppColors.primaryLight,
            foregroundColor: AppColors.onPrimary,
            elevation: 3,
            onPressed: () async {
              await context.push('/admin/inventory/assign');
              if (mounted) _reload();
            },
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text(
              'Assign to box',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add-item',
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            elevation: 3,
            onPressed: () => context.push('/admin/inventory/add'),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add item',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(message: _error!, icon: Icons.error_outline)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_lockers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _lockerMongoId,
                        decoration: const InputDecoration(
                          labelText: 'Locker',
                          border: OutlineInputBorder(),
                        ),
                        items: _lockers
                            .map(
                              (l) => DropdownMenuItem(
                                value: l.id,
                                child: Text(l.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _lockerMongoId = v);
                          _reload();
                        },
                      ),
                    const SizedBox(height: 12),
                    if (summary != null)
                      SoftPanel(
                        child: Row(
                          children: [
                            Expanded(
                              child: _summaryTile(
                                'Total Boxes',
                                '${summary.totalBoxes}',
                              ),
                            ),
                            Expanded(
                              child: _summaryTile(
                                'Occupied',
                                '${summary.occupiedBoxes}',
                              ),
                            ),
                            Expanded(
                              child: _summaryTile(
                                'Empty',
                                '${summary.emptyBoxes}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _occupancyFilters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final (label, value) = _occupancyFilters[index];
                          return ChoiceChip(
                            label: Text(label),
                            selected: _occupancy == value,
                            onSelected: (_) {
                              setState(() => _occupancy = value);
                              _reload();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      inv == null
                          ? 'Physical box contents'
                          : '${inv.lockerName} — each row is one physical box',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: inv == null || inv.boxes.isEmpty
                          ? const EmptyState(
                              message: 'No boxes for this locker',
                              icon: Icons.inventory_2_outlined,
                            )
                          : RefreshIndicator(
                              onRefresh: _reload,
                              child: ListView.separated(
                                itemCount: inv.boxes.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final row = inv.boxes[index];
                                  final deleting = _deletingId == row.id;
                                  return SoftPanel(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppColors.tableBorder,
                                            ),
                                            color: AppColors.surfaceMuted,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: row.isEmpty
                                              ? const Icon(
                                                  Icons.inbox_outlined,
                                                  color: AppColors.muted,
                                                )
                                              : ProductImage(
                                                  imageUrl: row.imageUrl,
                                                  height: 48,
                                                  width: 48,
                                                  borderRadius: 9,
                                                  iconSize: 22,
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                row.displayName,
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Qty ${row.quantity} · Box ${row.boxNumber ?? '—'}',
                                                style: AppTextStyles.caption,
                                              ),
                                              const SizedBox(height: 6),
                                              _OccupancyChip(
                                                occupied: row.isOccupied,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (row.isOccupied)
                                          IconButton(
                                            tooltip: 'Remove from box',
                                            onPressed: deleting
                                                ? null
                                                : () => _confirmRemove(row),
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
                                          )
                                        else
                                          IconButton(
                                            tooltip: 'Assign item',
                                            onPressed: () async {
                                              await context.push(
                                                '/admin/inventory/assign',
                                              );
                                              if (mounted) _reload();
                                            },
                                            icon: const Icon(
                                              Icons.add_box_outlined,
                                              color: AppColors.primary,
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

  Widget _summaryTile(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.title.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _OccupancyChip extends StatelessWidget {
  const _OccupancyChip({required this.occupied});

  final bool occupied;

  @override
  Widget build(BuildContext context) {
    final bg = occupied ? AppColors.stockHealthyBg : AppColors.surfaceMuted;
    final fg = occupied ? AppColors.stockHealthyFg : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: occupied
              ? AppColors.stockHealthyBorder
              : AppColors.tableBorder,
        ),
      ),
      child: Text(
        occupied ? 'Occupied' : 'Empty',
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
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
  final _imageUrl = TextEditingController();
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
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final description = _description.text.trim();
    final brand = _brand.text.trim();
    final barcode = _barcode.text.trim();
    final imageUrl = _imageUrl.text.trim();
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
    final urlError = ProductImageUrlRules.validationError(imageUrl);
    if (urlError != null && _image == null) {
      showAppSnackBar(context, urlError);
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
        'imageUrl': imageUrl,
        'sellingPrice': selling,
        'costPrice': cost ?? selling,
        'gstPercentage': 0,
        'unit': 'piece',
      });
      final mongoId = item['id']?.toString() ?? '';
      if (mongoId.isEmpty) {
        throw Exception('Item was created but no id was returned');
      }
      // Confirm Mongo persistence of imageUrl (source of truth).
      if (imageUrl.isNotEmpty) {
        final confirmed = await catalog.getItem(mongoId);
        final stored = confirmed['imageUrl']?.toString() ?? '';
        if (stored.isEmpty) {
          throw Exception('Item saved but imageUrl was not stored in MongoDB');
        }
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
        imageUrl.isNotEmpty || _image != null
            ? 'Item created with image'
            : 'Item created',
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
          ItemImageUrlField(controller: _imageUrl),
          const SizedBox(height: 16),
          Text(
            'Or upload an image file (optional)',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
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
  final _imageUrl = TextEditingController();
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
    _imageUrl.dispose();
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
      _imageUrl.text = (_existingImageUrl ?? '').trim();
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
    final imageUrl = _imageUrl.text.trim();
    if (_name.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        selling == null) {
      showAppSnackBar(context, 'Name, description, and price are required');
      return;
    }
    final urlError = ProductImageUrlRules.validationError(imageUrl);
    if (urlError != null && _image == null) {
      showAppSnackBar(context, urlError);
      return;
    }

    setState(() => _busy = true);
    try {
      final catalog = ref.read(catalogRepositoryProvider);
      final originalUrl = (_existingImageUrl ?? '').trim();
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'brand': _brand.text.trim(),
        'sellingPrice': selling,
        'costPrice': ?cost,
      };
      // Preserve imageUrl unless the admin changed or intentionally cleared it.
      // Omitting imageUrl lets the backend keep the existing Mongo value.
      final urlChanged = imageUrl != originalUrl;
      final intentionalClear =
          _imageCleared && _image == null && imageUrl.isEmpty;
      if (urlChanged || intentionalClear) {
        payload['imageUrl'] = imageUrl;
      }
      await catalog.updateItem(id, payload);
      if (intentionalClear) {
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
      } else if (urlChanged) {
        _existingImageUrl = imageUrl.isEmpty ? null : imageUrl;
      }
      // Re-fetch to confirm Mongo still has imageUrl after non-image edits.
      final confirmed = await catalog.getItem(id);
      final stored = confirmed['imageUrl']?.toString() ?? '';
      if (!intentionalClear &&
          originalUrl.isNotEmpty &&
          !urlChanged &&
          _image == null &&
          stored.isEmpty) {
        throw Exception('imageUrl was cleared unexpectedly during update');
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
          ItemImageUrlField(controller: _imageUrl),
          const SizedBox(height: 16),
          Text(
            'Or replace with an uploaded file (optional)',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
          ProductImagePickerField(
            existingImageUrl: _existingImageUrl,
            onChanged: (value) {
              setState(() {
                _image = value;
                _imageCleared = value == null;
                if (value == null) {
                  // Keep typed URL unless user cleared the picker while URL empty.
                } else {
                  // File upload will overwrite URL after save.
                }
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
            'One physical box holds exactly one item (quantity = 1). '
            'Enter how many boxes to stock, then select that many empty boxes.',
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
              labelText: 'Number of boxes',
              helperText:
                  'Each selected box receives quantity 1 — not an aggregated qty',
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

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  static const _filters = <(String, String?)>[
    ('All', null),
    ('Pending Collection', 'READY_FOR_COLLECTION'),
    ('Collected', 'COLLECTED'),
    ('Expired', 'EXPIRED'),
    ('Cancelled', 'CANCELLED'),
    ('Pending Payment', 'WAITING_PAYMENT'),
  ];

  String _filterLabel = 'All';
  String? _statusFilter;
  List<OrderSummary> _orders = const [];
  bool _loading = true;
  String? _error;
  bool _busyAction = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await ref
          .read(orderRepositoryProvider)
          .list(status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _orders = orders;
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

  String _fmt(DateTime? utc) {
    if (utc == null) return '—';
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _confirmCancel(OrderSummary order) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Order: ${order.id}'),
              Text(
                'Customer: ${order.customerName.isNotEmpty ? order.customerName : '—'}'
                '${order.customerEmail.isNotEmpty ? ' (${order.customerEmail})' : ''}',
              ),
              Text('Amount: ${MoneyFormat.format(order.total)}'),
              Text('Locker: ${order.lockerName} (${order.lockerNumber})'),
              Text(
                'Box: ${order.boxes.isEmpty ? '—' : order.boxes.join(', ')}',
              ),
              const SizedBox(height: 12),
              const Text(
                'This marks the order CANCELLED. It does not unlock the locker '
                'and does not automatically refund payment.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }
    setState(() => _busyAction = true);
    try {
      final id = order.mongoId.isNotEmpty ? order.mongoId : order.id;
      await ref.read(orderRepositoryProvider).cancel(
            id,
            reason: reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Order cancelled. Refund (if any) must be handled separately.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    } finally {
      reasonController.dispose();
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _confirmDelete(OrderSummary order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this order?'),
        content: Text(
          'Soft-delete ${order.id} (${order.status}).\n\n'
          'Payment and transaction records are preserved.\n'
          'Collected order history cannot be deleted here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyAction = true);
    try {
      final id = order.mongoId.isNotEmpty ? order.mongoId : order.id;
      await ref.read(orderRepositoryProvider).deleteOrder(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order deleted (payment history kept)')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  void _showDetails(OrderSummary order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  order.itemNames.isNotEmpty
                      ? order.itemNames.first
                      : shortOrderLabel(order.id),
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: 4),
                Text(
                  shortOrderLabel(order.id),
                  style: AppTextStyles.caption.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                _detailRow('Customer',
                    order.customerName.isEmpty ? '—' : order.customerName),
                if (order.customerEmail.isNotEmpty)
                  _detailRow('Email', order.customerEmail),
                _detailRow('Amount', MoneyFormat.format(order.total)),
                _detailRow(
                  'Payment',
                  order.paymentStatus.isEmpty
                      ? '—'
                      : friendlyPaymentLabel(order.paymentStatus),
                ),
                _detailRow('Status', friendlyOrderStatus(order.status)),
                _detailRow(
                  'Locker',
                  order.lockerName.isNotEmpty
                      ? order.lockerName
                      : order.lockerNumber,
                ),
                _detailRow(
                  'Box',
                  order.boxes.isEmpty ? '—' : order.boxes.join(', '),
                ),
                _detailRow('Created', order.placedAt),
                _detailRow('Paid', _fmt(order.paidAt)),
                _detailRow('Deadline', _fmt(order.collectionDeadline)),
                _detailRow('Collected', _fmt(order.collectedAt)),
                if (order.expiredAt != null)
                  _detailRow('Expired', _fmt(order.expiredAt)),
                if (order.cancelledAt != null)
                  _detailRow('Cancelled', _fmt(order.cancelledAt)),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Advanced',
                    style: AppTextStyles.label,
                  ),
                  children: [
                    _detailRow('Order ID', order.id),
                    if (order.mongoId.isNotEmpty && order.mongoId != order.id)
                      _detailRow('Internal ID', order.mongoId),
                    _detailRow(
                      'Terminal',
                      order.terminalNumber?.toString() ?? '—',
                    ),
                    if (order.lockerNumber.isNotEmpty)
                      _detailRow('Locker number', order.lockerNumber),
                  ],
                ),
                const SizedBox(height: 16),
                if (order.isPendingCollection)
                  PrimaryButton(
                    label: 'Cancel order',
                    onPressed: _busyAction
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _confirmCancel(order);
                          },
                  ),
                if (order.isPendingCollection) const SizedBox(height: 8),
                if (order.isExpired || order.isCancelled)
                  SecondaryButton(
                    label: 'Delete order',
                    onPressed: _busyAction
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _confirmDelete(order);
                          },
                  ),
                if (order.isPendingCollection) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Cancel active orders. Delete only expired or cancelled.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(child: Text(value, style: AppTextStyles.body)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Orders management',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (label, status) = _filters[index];
                final selected = label == _filterLabel;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _filterLabel = label;
                      _statusFilter = status;
                    });
                    _load();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!)))
          else if (_orders.isEmpty)
            const Expanded(
              child: EmptyState(
                message: 'No orders for this filter',
                icon: Icons.receipt_long_outlined,
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return SoftPanel(
                      child: InkWell(
                        onTap: () => _showDetails(order),
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    order.itemNames.isNotEmpty
                                        ? order.itemNames.first
                                        : shortOrderLabel(order.id),
                                    style: AppTextStyles.title
                                        .copyWith(fontSize: 16),
                                  ),
                                ),
                                Text(
                                  friendlyOrderStatus(order.status),
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (order.customerName.isNotEmpty)
                                  order.customerName,
                                if (order.lockerName.isNotEmpty)
                                  order.lockerName,
                                MoneyFormat.format(order.total),
                              ].join(' · '),
                              style: AppTextStyles.body,
                            ),
                            Text(
                              [
                                if (order.boxes.isNotEmpty)
                                  'Box ${order.boxes.join(', ')}',
                                if (order.paidAt != null)
                                  'Paid ${_fmt(order.paidAt)}',
                                if (order.collectionDeadline != null &&
                                    order.isPendingCollection)
                                  'Due ${_fmt(order.collectionDeadline)}',
                              ].join(' · '),
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                PriceText(order.total),
                                const Spacer(),
                                if (order.isPendingCollection)
                                  TextButton(
                                    onPressed: _busyAction
                                        ? null
                                        : () => _confirmCancel(order),
                                    child: const Text('Cancel'),
                                  ),
                                if (order.isExpired || order.isCancelled)
                                  TextButton(
                                    onPressed: _busyAction
                                        ? null
                                        : () => _confirmDelete(order),
                                    child: const Text('Delete'),
                                  ),
                              ],
                            ),
                          ],
                        ),
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
