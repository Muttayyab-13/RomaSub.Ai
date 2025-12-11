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
  bool _agreeToTerms = false;

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() {
      _firstNameError = Validators.name(_firstNameController.text);
      _lastNameError = Validators.name(_lastNameController.text);
      _emailError = Validators.email(_emailController.text);
      _passwordError = Validators.password(_passwordController.text);
    });

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.acceptTerms),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_firstNameError == null &&
        _lastNameError == null &&
        _emailError == null &&
        _passwordError == null) {
      final success = await ref.read(authNotifierProvider.notifier).register(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.accountCreated),
            backgroundColor: AppColors.success,
          ),
        );
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
  }

  Future<void> _handleGoogleSignIn() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.acceptTerms),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

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
      backgroundColor: AppColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.authMaxWidth),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(),
                const SizedBox(height: AppSizes.xl),

                Text(
                  AppStrings.signupTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSizes.xl),

                // First Name
                AppTextField(
                  controller: _firstNameController,
                  hint: AppStrings.firstName,
                  errorText: _firstNameError,
                  onChanged: (_) {
                    if (_firstNameError != null) {
                      setState(() => _firstNameError = Validators.name(_firstNameController.text));
                    }
                  },
                ),
                const SizedBox(height: AppSizes.md),

                // Last Name
                AppTextField(
                  controller: _lastNameController,
                  hint: AppStrings.lastName,
                  errorText: _lastNameError,
                  onChanged: (_) {
                    if (_lastNameError != null) {
                      setState(() => _lastNameError = Validators.name(_lastNameController.text));
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
                const SizedBox(height: AppSizes.md),

                // Terms Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: isLoading ? null : (v) => setState(() => _agreeToTerms = v ?? false),
                      activeColor: AppColors.primary,
                    ),
                    const Text(AppStrings.termsAgree),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        AppStrings.termsConditions,
                        style: TextStyle(fontWeight: FontWeight.w600),
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
                        : const Text(AppStrings.createAccount),
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      AppStrings.hasAccount,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: isLoading ? null : () => AppRoutes.back(context),
                      child: Text(
                        AppStrings.logIn,
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
