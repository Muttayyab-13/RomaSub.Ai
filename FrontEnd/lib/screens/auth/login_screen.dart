import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/auth/auth_shell.dart';
import '../../widgets/auth/auth_tab_switcher.dart';
import '../../widgets/auth/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = Validators.email(_emailController.text);
      _passwordError = Validators.password(_passwordController.text);
    });

    if (_emailError == null && _passwordError == null) {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .login(
            _emailController.text.trim(),
            _passwordController.text,
            rememberMe: _rememberMe,
          );

      if (success && mounted) {
        AppRoutes.clearAndGo(context, AppRoutes.app);
      } else if (mounted) {
        final error = ref.read(authNotifierProvider).error;
        if (error != null) {
          if (error.toLowerCase().contains('verify your email') ||
              error.toLowerCase().contains('verification')) {
            _showVerificationDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  void _showVerificationDialog() {
    final isDark = ref.read(themeProvider).isDark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        title: Text(
          'Email Not Verified',
          style: TextStyle(color: AppColors.getPrimary(isDark)),
        ),
        content: Text(
          'Please verify your email address before logging in. '
          'Would you like to go to the verification screen?',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              AppRoutes.to(
                context,
                AppRoutes.emailVerification,
                arguments: _emailController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.grey.shade300 : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
            ),
            child: const Text('Verify Email'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    final success = await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle();

    if (success && mounted) {
      AppRoutes.clearAndGo(context, AppRoutes.app);
    } else if (mounted) {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final isDark = ref.watch(themeProvider).isDark;

    return AuthShell(
      isDark: isDark,
      title: AppStrings.loginTitle,
      subtitle: AppStrings.loginSubtitle,
      activeTab: AuthTab.login,
      form: _buildForm(context, isLoading),
    );
  }

  Widget _buildForm(BuildContext context, bool isLoading) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (PlatformUtils.isGoogleSignInSupported) ...[
          GoogleAuthButton(onPressed: isLoading ? null : _handleGoogleSignIn),
          const SizedBox(height: AppSizes.md),
          const AuthOrDivider(),
          const SizedBox(height: AppSizes.md),
        ],
        LabeledAuthField(
          label: AppStrings.email,
          field: AuthTextField(
            controller: _emailController,
            label: AppStrings.email,
            hintText: AppStrings.emailHint,
            floatingLabel: false,
            icon: Icons.mail_outline,
            errorText: _emailError,
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            onChanged: (_) {
              if (_emailError != null) {
                setState(
                  () => _emailError = Validators.email(_emailController.text),
                );
              }
            },
          ),
        ),
        const SizedBox(height: AppSizes.md),
        LabeledAuthField(
          label: AppStrings.password,
          trailing: TextButton(
            onPressed: isLoading
                ? null
                : () => AppRoutes.to(context, AppRoutes.forgotPasswordEmail),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppStrings.forgotPassword,
              style: text.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          field: AuthTextField(
            controller: _passwordController,
            label: AppStrings.password,
            hintText: AppStrings.passwordHint,
            floatingLabel: false,
            icon: Icons.lock_outline,
            isPassword: true,
            errorText: _passwordError,
            textInputAction: TextInputAction.done,
            enabled: !isLoading,
            onChanged: (_) {
              if (_passwordError != null) {
                setState(
                  () => _passwordError = Validators.password(
                    _passwordController.text,
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: AppSizes.md),
        _rememberMeRow(context, isLoading),
        const SizedBox(height: AppSizes.md),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: FilledButton(
            onPressed: isLoading ? null : _handleLogin,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              textStyle: const TextStyle(
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(AppStrings.signIn),
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.noAccount,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => AppRoutes.to(context, AppRoutes.signup),
              child: Text(
                AppStrings.signUp,
                style: text.labelLarge?.copyWith(color: scheme.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rememberMeRow(BuildContext context, bool isLoading) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _rememberMe,
            onChanged: isLoading
                ? null
                : (v) => setState(() => _rememberMe = v ?? false),
            activeColor: scheme.primary,
            checkColor: scheme.onPrimary,
            side: BorderSide(color: scheme.outline),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: AppSizes.sm + 2),
        Text(
          AppStrings.rememberMe,
          style: text.bodyMedium?.copyWith(color: scheme.onSurface),
        ),
      ],
    );
  }
}
