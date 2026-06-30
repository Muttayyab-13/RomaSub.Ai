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
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/social_button.dart';
import '../../widgets/common/theme_toggle_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}
// ... (skip unchanged parts in thought, but tool needs exact replacement if I use replace_file_content for single block? No, I need two edits: import and body)
// Better use multi_replace.

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
      final success = await ref
          .read(authNotifierProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);

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

    // Theme-aware colors
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textPrimary = AppColors.getPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);
    final textHint = isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    final linkColor = AppColors.getAccent(isDark);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Center(
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
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSizes.xl),

                    // Email
                    AppTextField(
                      controller: _emailController,
                      hint: AppStrings.email,
                      errorText: _emailError,
                      keyboardType: TextInputType.emailAddress,
                      isDark: isDark,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(
                            () => _emailError = Validators.email(
                              _emailController.text,
                            ),
                          );
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
                      isDark: isDark,
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
                    const SizedBox(height: AppSizes.sm),

                    // Forgot Password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () => AppRoutes.to(
                                context,
                                AppRoutes.forgotPasswordEmail,
                              ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.sm,
                            vertical: AppSizes.sm,
                          ),
                          child: Text(
                            AppStrings.forgotPassword,
                            style: TextStyle(
                              color: isLoading ? textHint : linkColor,
                              fontWeight: FontWeight.w600,
                            ),
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
                            : Text(
                                AppStrings.continueBtn,
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.noAccount,
                          style: TextStyle(color: textSecondary),
                        ),
                        InkWell(
                          onTap: isLoading
                              ? null
                              : () => AppRoutes.to(context, AppRoutes.signup),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.xs,
                              vertical: AppSizes.sm,
                            ),
                            child: Text(
                              AppStrings.signUp,
                              style: TextStyle(
                                color: isLoading ? textHint : linkColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),

                    // Conditional Google Sign-In (only on supported platforms)
                    if (PlatformUtils.isGoogleSignInSupported) ...[
                      // Divider
                      _OrDivider(isDark: isDark),
                      const SizedBox(height: AppSizes.lg),

                      // Social Buttons
                      SocialButton(
                        icon: Icons.g_mobiledata,
                        label: AppStrings.continueGoogle,
                        onTap: isLoading ? () {} : () => _handleGoogleSignIn(),
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppSizes.xl),
                    ] else
                      const SizedBox(height: AppSizes.xl),

                    // Footer
                    _AuthFooter(isDark: isDark),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: const ThemeToggleButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final bool isDark;
  const _OrDivider({this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final dividerColor = AppColors.getBorder(isDark);
    final textColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Text(AppStrings.orDivider, style: TextStyle(color: textColor)),
        ),
        Expanded(child: Divider(color: dividerColor)),
      ],
    );
  }
}

class _AuthFooter extends StatelessWidget {
  final bool isDark;
  const _AuthFooter({this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {},
          child: Text(
            AppStrings.termsOfUse,
            style: TextStyle(color: textColor, fontSize: AppSizes.fontXs),
          ),
        ),
        Text(' | ', style: TextStyle(color: textColor)),
        TextButton(
          onPressed: () {},
          child: Text(
            AppStrings.privacyPolicy,
            style: TextStyle(color: textColor, fontSize: AppSizes.fontXs),
          ),
        ),
      ],
    );
  }
}
