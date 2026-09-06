import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return AuthShell(
      isDark: isDark,
      title: AppStrings.signupTitle,
      subtitle: AppStrings.signupSubtitle,
      activeTab: AuthTab.signup,
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
        // Sign-up carries more fields than the mockup's login, so it uses
        // compact floating labels (label inside the field) to fit the viewport
        // without scrolling.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AuthTextField(
                controller: _firstNameController,
                label: AppStrings.firstName,
                errorText: _firstNameError,
                enabled: !isLoading,
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
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: AuthTextField(
                controller: _lastNameController,
                label: AppStrings.lastName,
                errorText: _lastNameError,
                enabled: !isLoading,
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
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm + 4),
        AuthTextField(
          controller: _emailController,
          label: AppStrings.email,
          hintText: AppStrings.emailHint,
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
        const SizedBox(height: AppSizes.sm + 4),
        AuthTextField(
          controller: _passwordController,
          label: AppStrings.password,
          hintText: AppStrings.passwordHint,
          icon: Icons.lock_outline,
          isPassword: true,
          errorText: _passwordError,
          enabled: !isLoading,
          onChanged: (_) {
            if (_passwordError != null) {
              setState(() {
                _passwordError = Validators.password(_passwordController.text);
                if (_confirmPasswordError != null) {
                  _confirmPasswordError = Validators.confirmPassword(
                    _confirmPasswordController.text,
                    _passwordController.text,
                  );
                }
              });
            }
          },
        ),
        const SizedBox(height: AppSizes.sm + 4),
        AuthTextField(
          controller: _confirmPasswordController,
          label: AppStrings.confirmPassword,
          hintText: AppStrings.passwordHint,
          icon: Icons.lock_outline,
          isPassword: true,
          errorText: _confirmPasswordError,
          textInputAction: TextInputAction.done,
          enabled: !isLoading,
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
        const SizedBox(height: AppSizes.sm + 4),
        _buildTermsRow(context, isLoading),
        const SizedBox(height: AppSizes.md),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: FilledButton(
            onPressed: isLoading ? null : _handleSignUp,
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
                : const Text(AppStrings.createAccount),
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.hasAccount,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            TextButton(
              onPressed: isLoading ? null : () => AppRoutes.back(context),
              child: Text(
                AppStrings.logIn,
                style: text.labelLarge?.copyWith(color: scheme.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTermsRow(BuildContext context, bool isLoading) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: isLoading
                ? null
                : (v) => setState(() => _agreeToTerms = v ?? false),
            activeColor: scheme.primary,
            checkColor: scheme.onPrimary,
            side: BorderSide(color: scheme.outline),
          ),
        ),
        const SizedBox(width: AppSizes.sm + 2),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              children: [
                const TextSpan(text: AppStrings.termsAgree),
                TextSpan(
                  text: AppStrings.termsConditions,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
