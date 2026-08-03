import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/fake_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

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
            const TextField(
              decoration: InputDecoration(
                labelText: 'Admin email',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Enter Dashboard',
              onPressed: () => context.go('/admin/dashboard'),
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
    ref.watch(adminViewModelProvider);
    final stats = FakeData.adminStats;
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
      body: ListView(
        children: [
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
                label: 'Available lockers',
                value: '${stats.availableLockers}',
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
                value: '\$${stats.revenueToday.toStringAsFixed(0)}',
                icon: Icons.payments_outlined,
                color: AppColors.success,
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
        ],
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

class AdminLockerManagementScreen extends StatelessWidget {
  const AdminLockerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final columns = responsiveColumns(context, phone: 1, tablet: 2);

    return PageScaffold(
      title: 'Locker management',
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
        ),
        itemCount: FakeData.lockers.length,
        itemBuilder: (context, index) {
          final locker = FakeData.lockers[index];
          return SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(locker.name, style: AppTextStyles.title.copyWith(fontSize: 16))),
                    Text(locker.status, style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Open boxes ${locker.openBoxes}/${locker.totalBoxes}',
                  style: AppTextStyles.body,
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: FilledButton.tonal(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Manage ${locker.name} (placeholder)'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text('Manage'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AdminInventoryScreen extends StatelessWidget {
  const AdminInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Inventory',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/inventory/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 40,
          ),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(AppColors.surfaceMuted),
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Locker')),
              DataColumn(label: Text('Actions')),
            ],
            rows: FakeData.inventoryRows.map((row) {
              return DataRow(
                cells: [
                  DataCell(Text(row.name)),
                  DataCell(Text('\$${row.price.toStringAsFixed(2)}')),
                  DataCell(Text('${row.quantity}')),
                  DataCell(Text(row.assignedLocker)),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => context.push('/admin/inventory/edit/${row.id}'),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Delete ${row.name} (placeholder)'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
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

class AdminAddItemScreen extends StatelessWidget {
  const AdminAddItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Add item',
      bottom: PrimaryButton(
        label: 'Save item',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item saved (placeholder)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        },
      ),
      body: ListView(
        children: const [
          TextField(decoration: InputDecoration(labelText: 'Item name')),
          SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Price'),
          ),
          SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Quantity'),
          ),
          SizedBox(height: 12),
          TextField(decoration: InputDecoration(labelText: 'Assigned locker')),
          SizedBox(height: 12),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
    );
  }
}

class AdminEditItemScreen extends StatelessWidget {
  const AdminEditItemScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final row = FakeData.inventoryRows.firstWhere(
      (item) => item.id == itemId,
      orElse: () => FakeData.inventoryRows.first,
    );

    return PageScaffold(
      title: 'Edit item',
      bottom: PrimaryButton(
        label: 'Update item',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${row.name} updated (placeholder)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        },
      ),
      body: ListView(
        children: [
          TextField(
            controller: TextEditingController(text: row.name),
            decoration: const InputDecoration(labelText: 'Item name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: row.price.toStringAsFixed(2)),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: '${row.quantity}'),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: row.assignedLocker),
            decoration: const InputDecoration(labelText: 'Assigned locker'),
          ),
        ],
      ),
    );
  }
}

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Orders management',
      body: ListView.separated(
        itemCount: FakeData.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final order = FakeData.orders[index];
          return SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(order.id, style: AppTextStyles.title.copyWith(fontSize: 16))),
                    Text(order.status, style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${order.lockerName} - ${order.itemCount} items', style: AppTextStyles.body),
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
