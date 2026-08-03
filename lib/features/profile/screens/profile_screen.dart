import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/fake_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(profileViewModelProvider);
    final user = FakeData.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile'), automaticallyImplyLeading: false),
      body: ResponsiveCenter(
        maxWidth: 720,
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            SoftPanel(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.surfaceMuted,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0] : '?',
                      style: AppTextStyles.headline.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: AppTextStyles.title),
                        const SizedBox(height: 4),
                        Text(user.email, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Saved locations', style: AppTextStyles.title),
            const SizedBox(height: 10),
            ...user.savedLocations.map(
              (location) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(location, style: AppTextStyles.body)),
                    ],
                  ),
                ),
              ),
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
            _ProfileTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin Portal',
              onTap: () => context.push('/admin/login'),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Logout',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          SoftPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: true,
                  onChanged: (_) {},
                  title: Text('Push notifications', style: AppTextStyles.body),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: false,
                  onChanged: (_) {},
                  title: Text('Dark mode', style: AppTextStyles.body),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: true,
                  onChanged: (_) {},
                  title: Text('Location services', style: AppTextStyles.body),
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
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = const [
      ('How do I collect an order?', 'Go to Orders, open a ready order, then tap Collect Item near the locker.'),
      ('Can I change locker?', 'Select a nearby locker from Home before checkout.'),
      ('Payment failed?', 'Payment processing will be connected in a later phase.'),
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
                Text(faq.$2, style: AppTextStyles.body.copyWith(color: AppColors.muted)),
              ],
            ),
          );
        },
      ),
    );
  }
}
