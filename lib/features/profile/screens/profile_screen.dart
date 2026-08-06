import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_constants.dart';
import '../../../core/ble/ble.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSessionProvider);
    final user = auth.user;
    final lockersAsync = ref.watch(_nearbyLockerNamesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile'), automaticallyImplyLeading: false),
      body: ResponsiveCenter(
        maxWidth: 720,
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            SoftPanel(
              child: auth.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.surfaceMuted,
                          child: Text(
                            (user?.name.isNotEmpty == true)
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: AppTextStyles.headline
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Guest',
                                style: AppTextStyles.title,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? '',
                                style: AppTextStyles.caption,
                              ),
                              if (user?.phone.isNotEmpty == true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user!.phone,
                                  style: AppTextStyles.caption,
                                ),
                              ],
                              if (user != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Role: ${user.role}',
                                  style: AppTextStyles.caption,
                                ),
                                if (user.joinedDate.isNotEmpty)
                                  Text(
                                    'Joined: ${user.joinedDate.length >= 10 ? user.joinedDate.substring(0, 10) : user.joinedDate}',
                                    style: AppTextStyles.caption,
                                  ),
                                Text(
                                  'Orders: ${user.orderCount} · Spent: ${MoneyFormat.format(user.totalPurchases)}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Text('Nearby lockers', style: AppTextStyles.title),
            const SizedBox(height: 10),
            lockersAsync.when(
              loading: () => const SoftPanel(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => SoftPanel(
                child: Text(
                  'Unable to load lockers',
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
              ),
              data: (names) {
                if (names.isEmpty) {
                  return SoftPanel(
                    child: Text(
                      'No lockers nearby yet',
                      style: AppTextStyles.body.copyWith(color: AppColors.muted),
                    ),
                  );
                }
                return Column(
                  children: names
                      .map(
                        (location) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SoftPanel(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(location, style: AppTextStyles.body),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            _ProfileTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => context.push('/settings'),
            ),
            _ProfileTile(
              icon: Icons.help_outline_rounded,
              label: 'Help',
              onTap: () => context.push('/help'),
            ),
            if (auth.isAdmin)
              _ProfileTile(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin Portal',
                onTap: () => context.push('/admin/dashboard'),
              ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Logout',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text(
                      'You will need to sign in again to place orders.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                await ref.read(authSessionProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

final _nearbyLockerNamesProvider = FutureProvider<List<String>>((ref) async {
  if (!ref.watch(authSessionProvider).isAuthenticated) return const [];
  final lockers = await ref.read(lockerRepositoryProvider).list();
  return lockers.take(5).map((l) => l.name).toList();
});

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _hidden = TextEditingController();
  bool _push = true;
  bool _darkMode = false;
  bool _location = true;
  bool _showDevEntry = false;
  bool _showBleEntry = false;

  @override
  void dispose() {
    _hidden.dispose();
    super.dispose();
  }

  void _openDeveloperDashboard() {
    context.push(RouteConstants.developerDashboard);
    _hidden.clear();
    setState(() {
      _showDevEntry = false;
      _showBleEntry = false;
    });
  }

  void _openBleDebug() {
    context.push(RouteConstants.bleDebug);
    _hidden.clear();
    setState(() {
      _showDevEntry = false;
      _showBleEntry = false;
    });
  }

  void _onSearchChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _showDevEntry = q.contains('developer');
      _showBleEntry = q.contains('ble') || q.contains('cc2340');
    });
    if (q == 'developer' && mounted) {
      _openDeveloperDashboard();
    } else if ((q == 'ble' || q == 'cc2340') && mounted) {
      _openBleDebug();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(bleConfigProvider.notifier).mode;
    return PageScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          SoftPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: _push,
                  onChanged: (value) {
                    setState(() => _push = value);
                    showComingSoon(context, 'Push notification preferences');
                  },
                  title: Text('Push notifications', style: AppTextStyles.body),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() => _darkMode = value);
                    showComingSoon(context, 'Dark mode');
                  },
                  title: Text('Dark mode', style: AppTextStyles.body),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _location,
                  onChanged: (value) {
                    setState(() => _location = value);
                    showComingSoon(context, 'Location preference sync');
                  },
                  title: Text('Location services', style: AppTextStyles.body),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Developer · BLE transport', style: AppTextStyles.label),
                const SizedBox(height: 8),
                SegmentedButton<BleTransportMode>(
                  segments: const [
                    ButtonSegment(
                      value: BleTransportMode.virtualMcu,
                      label: Text('Virtual MCU'),
                    ),
                    ButtonSegment(
                      value: BleTransportMode.realBle,
                      label: Text('Real BLE'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (set) {
                    ref.read(bleConfigProvider.notifier).setMode(set.first);
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openBleDebug,
                  child: const Text('Open BLE Debug'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftPanel(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text('App version', style: AppTextStyles.body),
              trailing: Text('1.0.0', style: AppTextStyles.caption),
            ),
          ),
          const SizedBox(height: 16),
          SoftPanel(
            child: TextField(
              controller: _hidden,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search settings',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                final q = value.trim().toLowerCase();
                if (q.contains('developer')) {
                  _openDeveloperDashboard();
                } else if (q.contains('ble') || q.contains('cc2340')) {
                  _openBleDebug();
                }
              },
            ),
          ),
          if (_showDevEntry) ...[
            const SizedBox(height: 8),
            SoftPanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.developer_mode_rounded),
                title: Text('Developer Dashboard', style: AppTextStyles.body),
                subtitle: Text(
                  'Virtual MCU tools',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openDeveloperDashboard,
              ),
            ),
          ],
          if (_showBleEntry) ...[
            const SizedBox(height: 8),
            SoftPanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.bluetooth_searching_rounded),
                title: Text('BLE Debug', style: AppTextStyles.body),
                subtitle: Text(
                  'CC2340R5 scan / GATT / packets',
                  style: AppTextStyles.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _openBleDebug,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const faqs = [
      (
        'How do I collect an order?',
        'Go to Orders, open a ready order, then tap Collect Item near the locker.',
      ),
      (
        'Can I change locker?',
        'Select a nearby locker from Home before checkout.',
      ),
      (
        'Payment failed?',
        'Retry checkout. Payments are verified through the Campus Essentials backend (Razorpay test mode).',
      ),
    ];

    return PageScaffold(
      title: 'Help',
      body: ListView.separated(
        itemCount: faqs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(faq.$1, style: AppTextStyles.title.copyWith(fontSize: 15)),
                const SizedBox(height: 8),
                Text(
                  faq.$2,
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
