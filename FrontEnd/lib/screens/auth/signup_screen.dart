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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeToTerms = false;

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() {
      _firstNameError = Validators.name(_firstNameController.text);
      _lastNameError = Validators.name(_lastNameController.text);
      _emailError = Validators.email(_emailController.text);
      _passwordError = Validators.password(_passwordController.text);
      _confirmPasswordError = Validators.confirmPassword(
        _confirmPasswordController.text,
        _passwordController.text,
      );
    });

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.acceptTerms),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_firstNameError == null &&
        _lastNameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null) {
      final email = await ref
          .read(authNotifierProvider.notifier)
          .register(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (email != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registration successful! Please check your email for verification code.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        AppRoutes.replace(
          context,
          AppRoutes.emailVerification,
          arguments: email,
        );
      } else if (mounted) {
        final error = ref.read(authNotifierProvider).error;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.acceptTerms),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final textHint = isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    final checkboxColor = isDark ? Colors.grey.shade300 : Colors.black;

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
                      AppStrings.signupTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                    ),
                    const SizedBox(height: AppSizes.xl),

                    // First Name
                    AppTextField(
                      controller: _firstNameController,
                      hint: AppStrings.firstName,
                      errorText: _firstNameError,
                      isDark: isDark,
                      onChanged: (_) {
                        if (_firstNameError != null) {
                          setState(
                            () => _firstNameError = Validators.name(
                              _firstNameController.text,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: AppSizes.md),

                    // Last Name
                    AppTextField(
                      controller: _lastNameController,
                      hint: AppStrings.lastName,
                      errorText: _lastNameError,
                      isDark: isDark,
                      onChanged: (_) {
                        if (_lastNameError != null) {
                          setState(
                            () => _lastNameError = Validators.name(
                              _lastNameController.text,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: AppSizes.md),

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
                          setState(() {
                            _passwordError = Validators.password(
                              _passwordController.text,
                            );
                            if (_confirmPasswordError != null) {
                              _confirmPasswordError =
                                  Validators.confirmPassword(
                                    _confirmPasswordController.text,
                                    _passwordController.text,
                                  );
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSizes.md),

                    // Confirm Password
                    AppTextField(
                      controller: _confirmPasswordController,
                      hint: AppStrings.confirmPassword,
                      isPassword: true,
                      errorText: _confirmPasswordError,
                      isDark: isDark,
                      onChanged: (_) {
                        if (_confirmPasswordError != null) {
                          setState(() {
                            _confirmPasswordError = Validators.confirmPassword(
                              _confirmPasswordController.text,
                              _passwordController.text,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSizes.md),

                    // Terms Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: isLoading
                              ? null
                              : (v) =>
                                    setState(() => _agreeToTerms = v ?? false),
                          activeColor: checkboxColor,
                          checkColor: isDark ? Colors.black : Colors.white,
                        ),
                        Text(
                          AppStrings.termsAgree,
                          style: TextStyle(color: textSecondary),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            AppStrings.termsConditions,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),

                    // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleSignUp,
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
                                AppStrings.createAccount,
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.hasAccount,
                          style: TextStyle(color: textSecondary),
                        ),
                        InkWell(
                          onTap: isLoading
                              ? null
                              : () => AppRoutes.back(context),
                          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.xs,
                              vertical: AppSizes.sm,
                            ),
                            child: Text(
                              AppStrings.logIn,
                              style: TextStyle(
                                color: isLoading
                                    ? textHint
                                    : AppColors.getAccent(isDark),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),

                    // Conditional Google Sign-In
                    if (PlatformUtils.isGoogleSignInSupported) ...[
                      _OrDivider(isDark: isDark),
                      const SizedBox(height: AppSizes.lg),

                      SocialButton(
                        icon: Icons.g_mobiledata,
                        label: AppStrings.continueGoogle,
                        onTap: isLoading ? () {} : () => _handleGoogleSignIn(),
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppSizes.xl),
                    ] else
                      const SizedBox(height: AppSizes.xl),

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
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
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
