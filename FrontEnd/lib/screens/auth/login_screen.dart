import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/social_button.dart';

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
      final success = await ref.read(authNotifierProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (success && mounted) {
        AppRoutes.clearAndGo(context, AppRoutes.dashboard);
      } else if (mounted) {
        final error = ref.read(authNotifierProvider).error;
        if (error != null) {
          // Check if error is about email verification
          if (error.toLowerCase().contains('verify your email') ||
              error.toLowerCase().contains('verification')) {
            // Show dialog with option to go to verification screen
            _showVerificationDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Not Verified'),
        content: const Text(
          'Please verify your email address before logging in. '
          'Would you like to go to the verification screen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to verification screen with the email
              AppRoutes.to(
                context,
                AppRoutes.emailVerification,
                arguments: _emailController.text.trim(),
              );
            },
            child: const Text('Verify Email'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    final success = await ref.read(authNotifierProvider.notifier).signInWithGoogle();

    if (success && mounted) {
      AppRoutes.clearAndGo(context, AppRoutes.dashboard);
    } else if (mounted) {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xl,
            vertical: AppSizes.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(),
                const SizedBox(height: AppSizes.xl),

                Text(
                  AppStrings.loginTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.xl),

                // Email
                AppTextField(
                  controller: _emailController,
                  hint: AppStrings.email,
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = Validators.email(_emailController.text));
                    }
                  },
                ),
                const SizedBox(height: AppSizes.md),

                // Password
                AppTextField(
                  controller: _passwordController,
                  hint: AppStrings.password,
                  isPassword: true,
                  errorText: _passwordError,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = Validators.password(_passwordController.text));
                    }
                  },
                ),
                const SizedBox(height: AppSizes.sm),

                // Forgot Password link
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: isLoading ? null : () => AppRoutes.to(context, AppRoutes.forgotPasswordEmail),
                    child: Text(
                      AppStrings.forgotPassword,
                      style: TextStyle(
                        color: isLoading ? AppColors.textHint : AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.lg),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(AppStrings.continueBtn),
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      AppStrings.noAccount,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: isLoading ? null : () => AppRoutes.to(context, AppRoutes.signup),
                      child: Text(
                        AppStrings.signUp,
                        style: TextStyle(
                          color: isLoading ? AppColors.textHint : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),

                // Conditional Google Sign-In (only on supported platforms)
                if (PlatformUtils.isGoogleSignInSupported) ...[
                  // Divider
                  const _OrDivider(),
                  const SizedBox(height: AppSizes.lg),

                  // Social Buttons
                  SocialButton(
                    icon: Icons.g_mobiledata,
                    label: AppStrings.continueGoogle,
                    onTap: isLoading ? () {} : () => _handleGoogleSignIn(),
                  ),
                  const SizedBox(height: AppSizes.xl),
                ] else
                  const SizedBox(height: AppSizes.xl),

                // Footer
                const _AuthFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Text(
            AppStrings.orDivider,
            style: TextStyle(color: AppColors.textHint),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _AuthFooter extends StatelessWidget {
  const _AuthFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {},
          child: const Text(
            AppStrings.termsOfUse,
            style: TextStyle(color: AppColors.textHint, fontSize: AppSizes.fontXs),
          ),
        ),
        const Text(' | ', style: TextStyle(color: AppColors.textHint)),
        TextButton(
          onPressed: () {},
          child: const Text(
            AppStrings.privacyPolicy,
            style: TextStyle(color: AppColors.textHint, fontSize: AppSizes.fontXs),
          ),
        ),
      ],
    );
  }
}
