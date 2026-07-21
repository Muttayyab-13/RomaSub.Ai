import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/base_theme.dart';
import '../../core/utils/responsive.dart';
import '../../providers/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_config.dart';
import '../../widgets/common/app_snackbar.dart';

/// The Feedback tab. Opts into the redesigned system via a scoped
/// [buildBaseTheme] wrapper, matching Settings.
///
/// Design-system migration only — the submit flow (`_submitFeedback`, the POST
/// to [ApiConfig.feedbackSubmit], the rating-required guard) is unchanged. The
/// rating uses brand-teal stars with a live descriptor and hover preview.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _feedbackController = TextEditingController();
  int _rating = 0;
  int _hoverRating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      AppSnackbar.showError(context, AppStrings.feedbackSelectRating);
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
        AppSnackbar.showSuccess(context, AppStrings.feedbackThanks);
        setState(() {
          _rating = 0;
          _hoverRating = 0;
          _feedbackController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to submit feedback: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;

    return Theme(
      data: buildBaseTheme(isDark),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;

          return ColoredBox(
            color: scheme.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.feedbackTitle,
                        style: text.headlineMedium,
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        AppStrings.feedbackSubtitle,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),
                      _card(context),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reviews_outlined,
                size: AppSizes.iconSm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSizes.sm),
              Text(AppStrings.rateExperience, style: text.titleMedium),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          _ratingStars(context),
          const SizedBox(height: AppSizes.lg),
          Text(AppStrings.yourFeedback, style: text.labelLarge),
          const SizedBox(height: AppSizes.sm),
          _feedbackField(context),
          const SizedBox(height: AppSizes.lg),
          _submitButton(context),
        ],
      ),
    );
  }

  Widget _ratingStars(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Hover previews a rating without committing it; tap commits.
    final effective = _hoverRating > 0 ? _hoverRating : _rating;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoverRating = i + 1),
            onExit: (_) => setState(() => _hoverRating = 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _rating = i + 1),
              child: Tooltip(
                message: AppStrings.feedbackRatingLabels[i],
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSizes.sm),
                  child: AnimatedScale(
                    scale: i < effective ? 1.12 : 1.0,
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: Icon(
                      i < effective
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 34,
                      color: i < effective ? scheme.primary : scheme.outline,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(width: AppSizes.sm),
        Flexible(
          child: Text(
            effective > 0
                ? AppStrings.feedbackRatingLabels[effective - 1]
                : AppStrings.feedbackRatePrompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelLarge?.copyWith(
              color: effective > 0 ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: effective > 0 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _feedbackField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSizes.radiusMd);

    OutlineInputBorder borderOf(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: _feedbackController,
      minLines: 4,
      maxLines: 7,
      enabled: !_submitting,
      style: TextStyle(color: scheme.onSurface, fontSize: AppSizes.fontMd),
      decoration: InputDecoration(
        hintText: AppStrings.feedbackHint,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.all(AppSizes.md),
        border: borderOf(scheme.outlineVariant, 1),
        enabledBorder: borderOf(scheme.outlineVariant, 1),
        focusedBorder: borderOf(scheme.primary, 1.6),
      ),
    );
  }

  Widget _submitButton(BuildContext context) {
    return SizedBox(
      width: context.isMobile ? double.infinity : 220,
      height: AppSizes.buttonHeight,
      child: FilledButton.icon(
        onPressed: _submitting ? null : _submitFeedback,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, size: AppSizes.iconSm),
        label: Text(
          _submitting
              ? AppStrings.submittingFeedback
              : AppStrings.submitFeedback,
        ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: AppSizes.fontMd,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
