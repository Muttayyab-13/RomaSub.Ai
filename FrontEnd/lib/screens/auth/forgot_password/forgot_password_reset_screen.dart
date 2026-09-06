import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/forgot_password_provider.dart';
import '../../../widgets/common/app_logo.dart';
import '../../../widgets/common/app_text_field.dart';

class ForgotPasswordResetScreen extends ConsumerStatefulWidget {
  const ForgotPasswordResetScreen({super.key});

  @override
  ConsumerState<ForgotPasswordResetScreen> createState() =>
      _ForgotPasswordResetScreenState();
}

class _ForgotPasswordResetScreenState
    extends ConsumerState<ForgotPasswordResetScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    setState(() {
      _passwordError = Validators.password(_passwordController.text);
      _confirmPasswordError = Validators.confirmPassword(
        _confirmPasswordController.text,
        _passwordController.text,
      );
    });

    if (_passwordError == null && _confirmPasswordError == null) {
      final success = await ref
          .read(forgotPasswordProvider.notifier)
          .resetPassword(_passwordController.text);

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.passwordResetSuccess),
            backgroundColor: AppColors.success,
          ),
        );

        // Reset provider state
        ref.read(forgotPasswordProvider.notifier).reset();

        // Navigate to login
        AppRoutes.clearAndGo(context, AppRoutes.login);
      } else if (mounted) {
        final error = ref.read(forgotPasswordProvider).error;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final forgotPasswordState = ref.watch(forgotPasswordProvider);
    final isLoading = forgotPasswordState.isLoading;

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
                  AppStrings.createNewPassword,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.md),

                Text(
                  'Please enter your new password',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.xl),

                // New Password
                AppTextField(
                  controller: _passwordController,
                  hint: AppStrings.newPassword,
                  isPassword: true,
                  errorText: _passwordError,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() {
                        _passwordError = Validators.password(
                          _passwordController.text,
                        );
                        // Also revalidate confirm password if it has an error
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
                const SizedBox(height: AppSizes.md),

                // Confirm Password
                AppTextField(
                  controller: _confirmPasswordController,
                  hint: AppStrings.confirmPassword,
                  isPassword: true,
                  errorText: _confirmPasswordError,
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
                const SizedBox(height: AppSizes.lg),

                // Reset Password Button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleResetPassword,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(AppStrings.resetPasswordBtn),
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                // Back link
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () {
                          ref
                              .read(forgotPasswordProvider.notifier)
                              .goToPreviousStep();
                          AppRoutes.back(context);
                        },
                  child: Text(
                    'Back',
                    style: TextStyle(
                      color: isLoading
                          ? AppColors.textHint
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
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
