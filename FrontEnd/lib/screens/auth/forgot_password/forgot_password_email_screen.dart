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

class ForgotPasswordEmailScreen extends ConsumerStatefulWidget {
  const ForgotPasswordEmailScreen({super.key});

  @override
  ConsumerState<ForgotPasswordEmailScreen> createState() =>
      _ForgotPasswordEmailScreenState();
}

class _ForgotPasswordEmailScreenState
    extends ConsumerState<ForgotPasswordEmailScreen> {
  final _emailController = TextEditingController();
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    setState(() {
      _emailError = Validators.email(_emailController.text);
    });

    if (_emailError == null) {
      final success = await ref
          .read(forgotPasswordProvider.notifier)
          .requestOtp(_emailController.text.trim());

      if (success && mounted) {
        AppRoutes.to(context, AppRoutes.forgotPasswordOtp);
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
                  AppStrings.forgotPasswordTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSizes.md),

                Text(
                  AppStrings.enterEmailReset,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
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
                      setState(
                        () => _emailError = Validators.email(
                          _emailController.text,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSizes.lg),

                // Send Code Button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleSendCode,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(AppStrings.sendCode),
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                // Back to Login link
                GestureDetector(
                  onTap: isLoading
                      ? null
                      : () {
                          ref.read(forgotPasswordProvider.notifier).reset();
                          AppRoutes.back(context);
                        },
                  child: Text(
                    AppStrings.backToLogin,
                    style: TextStyle(
                      color: isLoading ? AppColors.textHint : AppColors.accent,
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
