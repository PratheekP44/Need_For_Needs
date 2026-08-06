import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/auth_debug.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/ux.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  int _logoPresses = 0;
  Timer? _navTimer;
  bool _unlockedDeveloper = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    // Hold splash long enough for 5× logo long-press developer unlock.
    _armSplashRelease();
  }

  void _armSplashRelease() {
    _navTimer?.cancel();
    _navTimer = Timer(const Duration(milliseconds: 6000), _releaseSplash);
  }

  void _releaseSplash() {
    if (!mounted || _unlockedDeveloper || _logoPresses >= 5) return;
    ref.read(splashHoldProvider.notifier).release();
    authLog('Splash hold released — router may leave splash');
  }

  void _onLogoLongPress() {
    if (_unlockedDeveloper) return;
    setState(() => _logoPresses += 1);
    authLog('Splash logo long-press count=$_logoPresses');
    // Extend the window while the user is actively unlocking.
    if (_logoPresses < 5) {
      _armSplashRelease();
    }
    if (_logoPresses >= 5 && mounted) {
      _unlockedDeveloper = true;
      _navTimer?.cancel();
      // Keep hold true until we leave; then clear so future launches work.
      context.go(RouteConstants.developerDashboard);
      // Defer releasing hold so redirect does not yank us away mid-navigation.
      Future.microtask(() {
        if (!mounted) return;
        ref.read(splashHoldProvider.notifier).release();
      });
    }
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
              AppColors.secondary,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onLongPress: _onLogoLongPress,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Need For Needs',
                  style: AppTextStyles.display.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Campus Essentials - Smart Lockers',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (_logoPresses > 0 && _logoPresses < 5) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Developer unlock $_logoPresses/5',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
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
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      showAppSnackBar(context, 'Enter email and password');
      return;
    }
    if (!email.contains('@')) {
      showAppSnackBar(context, 'Enter a valid email address');
      return;
    }
    setState(() => _busy = true);
    try {
      final user = await ref.read(authSessionProvider.notifier).login(
            email,
            password,
          );
      if (!mounted) return;
      // GoRouter redirect also handles this; keep explicit nav as a fallback.
      if (user.isAdmin) {
        context.go('/admin/dashboard');
      } else {
        context.go('/location-permission');
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
    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(24),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text('Welcome back', style: AppTextStyles.display.copyWith(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  'Sign in to unlock nearby campus lockers.',
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
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
                      'Dev reset: run npm run seed:admin in the server folder',
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: _busy ? 'Signing in…' : 'Sign In',
                  onPressed: _busy ? null : _signIn,
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Create Account',
                  onPressed: () => context.push('/signup'),
                ),
                const Spacer(),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/admin/login'),
                    child: Text(
                      'Admin access',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;
    if (name.length < 2) {
      showAppSnackBar(context, 'Enter your full name');
      return;
    }
    if (!email.contains('@')) {
      showAppSnackBar(context, 'Enter a valid campus email');
      return;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 7) {
      showAppSnackBar(context, 'Enter a valid phone number');
      return;
    }
    if (password.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      showAppSnackBar(
        context,
        'Password needs 8+ characters with a letter and a number',
      );
      return;
    }
    if (password != _confirm.text) {
      showAppSnackBar(context, 'Passwords do not match');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authSessionProvider.notifier).signup(
            name: name,
            email: email,
            phone: phone,
            password: password,
          );
      if (!mounted) return;
      context.go('/location-permission');
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
      appBar: AppBar(title: const Text('Create account')),
      body: ResponsiveCenter(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text('Join Campus Essentials', style: AppTextStyles.headline),
            const SizedBox(height: 8),
            Text(
              'Pick up snacks, stationery, and more from smart lockers.',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Campus email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'Min 8 chars, include a letter and a number',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _busy ? 'Creating…' : 'Sign Up',
              onPressed: _busy ? null : _signUp,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Back to Login',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationPermissionScreen extends ConsumerWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.near_me_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text('Find nearby lockers', style: AppTextStyles.headline, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Allow location access so we can show lockers around your campus and walking distance.',
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Enable Location',
                icon: Icons.location_on_outlined,
                onPressed: () async {
                  await ref.read(locationServiceProvider).ensurePermission();
                  if (context.mounted) context.go('/home');
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Skip for now',
                onPressed: () => context.go('/home'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}


