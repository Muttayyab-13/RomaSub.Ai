import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../providers/forgot_password_provider.dart';
import '../../../widgets/common/app_logo.dart';

class ForgotPasswordOtpScreen extends ConsumerStatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  ConsumerState<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends ConsumerState<ForgotPasswordOtpScreen> {
  final _otpController = TextEditingController();
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit code'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await ref.read(forgotPasswordProvider.notifier).verifyOtp(
          _otpController.text,
        );

    if (success && mounted) {
      AppRoutes.to(context, AppRoutes.forgotPasswordReset);
    } else if (mounted) {
      final error = ref.read(forgotPasswordProvider).error;
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

  Future<void> _handleResendCode() async {
    if (_resendCooldown > 0) return;

    final email = ref.read(forgotPasswordProvider).email;
    if (email == null) return;

    final success = await ref.read(forgotPasswordProvider.notifier).requestOtp(email);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.otpResent),
          backgroundColor: AppColors.success,
        ),
      );
      _startResendCooldown();
    } else if (mounted) {
      final error = ref.read(forgotPasswordProvider).error;
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

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final forgotPasswordState = ref.watch(forgotPasswordProvider);
    final isLoading = forgotPasswordState.isLoading;
    final email = forgotPasswordState.email ?? '';

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        color: AppColors.surface,
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: AppColors.accent, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: AppColors.accent),
      ),
    );

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
                  AppStrings.enterVerificationCode,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.md),

                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    children: [
                      const TextSpan(text: '${AppStrings.codeSentTo}\n'),
                      TextSpan(
                        text: email,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.xl),

                // OTP Input
                Pinput(
                  controller: _otpController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onCompleted: (_) => _handleVerifyOtp(),
                ),
                const SizedBox(height: AppSizes.lg),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleVerifyOtp,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(AppStrings.verifyCode),
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                // Resend Code link
                GestureDetector(
                  onTap: _resendCooldown > 0 || isLoading ? null : _handleResendCode,
                  child: Text(
                    _resendCooldown > 0
                        ? '${AppStrings.resendCode} ($_resendCooldown s)'
                        : AppStrings.resendCode,
                    style: TextStyle(
                      color: _resendCooldown > 0 || isLoading
                          ? AppColors.textHint
                          : AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                // Back link
                GestureDetector(
                  onTap: isLoading ? null : () {
                    ref.read(forgotPasswordProvider.notifier).goToPreviousStep();
                    AppRoutes.back(context);
                  },
                  child: Text(
                    AppStrings.backToLogin,
                    style: TextStyle(
                      color: isLoading ? AppColors.textHint : AppColors.textSecondary,
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
