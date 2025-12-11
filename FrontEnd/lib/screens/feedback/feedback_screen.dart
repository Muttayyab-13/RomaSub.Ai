import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../widgets/sidebar/sidebar.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _feedbackController = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text(
                        AppStrings.feedback,
                        style: TextStyle(
                          fontSize: AppSizes.fontXl,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {},
                      ),
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
                        const Text(
                          AppStrings.feedbackTitle,
                          style: TextStyle(
                            fontSize: AppSizes.fontXl,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        const Text(
                          AppStrings.feedbackSubtitle,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSizes.lg),

                        // Feedback Form
                        Container(
                          padding: const EdgeInsets.all(AppSizes.lg),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                AppStrings.rateExperience,
                                style: TextStyle(
                                  fontSize: AppSizes.fontMd,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
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
                                      index < _rating ? Icons.star : Icons.star_border,
                                      color: AppColors.accent,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: AppSizes.lg),

                              const Text(
                                AppStrings.yourFeedback,
                                style: TextStyle(
                                  fontSize: AppSizes.fontMd,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSizes.sm),

                              TextField(
                                controller: _feedbackController,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  hintText: AppStrings.feedbackHint,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSizes.lg),

                              SizedBox(
                                width: 200,
                                child: ElevatedButton.icon(
                                  onPressed: _submitFeedback,
                                  icon: const Icon(Icons.send, size: AppSizes.iconSm),
                                  label: const Text(AppStrings.submitFeedback),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
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
