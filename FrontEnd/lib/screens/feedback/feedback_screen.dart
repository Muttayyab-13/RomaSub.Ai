import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_config.dart';
import '../../widgets/sidebar/sidebar.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _feedbackController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final client = ref.read(apiClientProvider);
      await client.dio.post(
        ApiConfig.feedbackSubmit,
        data: {
          'rating': _rating,
          'comment': _feedbackController.text.isNotEmpty
              ? _feedbackController.text
              : null,
          'feedback_type': 'general',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.feedbackThanks),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _rating = 0;
          _feedbackController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final buttonBg = AppColors.accentStrong;
    final buttonText = AppColors.onAccent;
    final starColor = isDark ? Colors.amber.shade300 : Colors.amber.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          const Sidebar(currentRoute: AppRoutes.feedback),
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.md,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        AppStrings.feedback,
                        style: TextStyle(
                          fontSize: AppSizes.fontXl,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.feedbackTitle,
                          style: TextStyle(
                            fontSize: AppSizes.fontXl,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          AppStrings.feedbackSubtitle,
                          style: TextStyle(color: textSecondary),
                        ),
                        const SizedBox(height: AppSizes.lg),

                        // Feedback Form
                        Container(
                          padding: const EdgeInsets.all(AppSizes.lg),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.rateExperience,
                                style: TextStyle(
                                  fontSize: AppSizes.fontMd,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSizes.md),

                              // Star Rating
                              Row(
                                children: List.generate(5, (index) {
                                  return IconButton(
                                    iconSize: AppSizes.iconLg,
                                    onPressed: () {
                                      setState(() => _rating = index + 1);
                                    },
                                    icon: Icon(
                                      index < _rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: starColor,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: AppSizes.lg),

                              Text(
                                AppStrings.yourFeedback,
                                style: TextStyle(
                                  fontSize: AppSizes.fontMd,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSizes.sm),

                              TextField(
                                controller: _feedbackController,
                                maxLines: 6,
                                style: TextStyle(color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: AppStrings.feedbackHint,
                                  hintStyle: TextStyle(color: textSecondary),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSizes.lg),

                              SizedBox(
                                width: 200,
                                child: ElevatedButton.icon(
                                  onPressed: _submitting ? null : _submitFeedback,
                                  icon: _submitting
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: buttonText,
                                          ),
                                        )
                                      : Icon(Icons.send, size: AppSizes.iconSm, color: buttonText),
                                  label: Text(
                                    _submitting ? 'Submitting...' : AppStrings.submitFeedback,
                                    style: TextStyle(color: buttonText),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: buttonBg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
