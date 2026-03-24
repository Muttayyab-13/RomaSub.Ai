import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/upload_provider.dart';
import 'transcription_complete_dialog.dart';

/// Upload progress dialog showing real-time upload and transcription progress
class UploadProgressDialog extends ConsumerWidget {
  const UploadProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !uploadState.isProcessing, // Prevent dismissal during processing
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon based on phase
                      _buildPhaseIcon(uploadState.phase),
                      const SizedBox(height: AppSizes.xl),

                      // Filename
                      if (uploadState.currentFileName != null) ...[
                        Text(
                          uploadState.currentFileName!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSizes.md),
                      ],

                      // Phase message
                      Text(
                        uploadState.phaseMessage,
                        style: TextStyle(
                          color: uploadState.phase == UploadPhase.error
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontSize: AppSizes.fontMd,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.xl),

                      // Progress indicator
                      if (uploadState.phase == UploadPhase.uploading) ...[
                        LinearProgressIndicator(
                          value: uploadState.uploadProgress,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          uploadState.progressPercent,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.fontMd,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ] else if (uploadState.phase ==
                          UploadPhase.transcribing) ...[
                        LinearProgressIndicator(
                          value: uploadState.transcriptionProgress,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                      ] else if (uploadState.phase ==
                          UploadPhase.transliterating) ...[
                        LinearProgressIndicator(
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          'Converting to Roman Urdu...',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.fontMd,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ] else if (uploadState.phase ==
                          UploadPhase.extractingAudio) ...[
                        LinearProgressIndicator(
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          'Extracting Audio...',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.fontMd,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],

                      // Transcription result preview
                      if (uploadState.phase == UploadPhase.completed &&
                          uploadState.transcription != null) ...[
                        InkWell(
                          onTap: () {
                            _showFullTextDialog(
                              context,
                              uploadState.transcription!.hasRomanUrdu
                                  ? uploadState.transcription!.romanUrduText!
                                  : uploadState.transcription!.text,
                              isRomanUrdu: uploadState.transcription!.hasRomanUrdu,
                            );
                          },
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSizes.lg),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(
                                          0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: AppColors.success,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.sm),
                                    Text(
                                      '${uploadState.transcription!.segmentCount} segments',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: AppSizes.fontMd,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSizes.sm,
                                        vertical: AppSizes.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusSm,
                                        ),
                                      ),
                                      child: Text(
                                        uploadState
                                            .transcription!
                                            .durationFormatted,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontSize: AppSizes.fontSm,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSizes.md),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSizes.md),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey.shade900
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    uploadState.transcription!.hasRomanUrdu
                                        ? uploadState.transcription!.romanUrduText!
                                        : uploadState.transcription!.text,
                                    style: TextStyle(
                                      fontSize: AppSizes.fontSm,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      height: 1.6,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: uploadState.transcription!.hasRomanUrdu
                                        ? TextDirection.ltr
                                        : TextDirection.rtl,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.sm),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.xs),
                                    const Text(
                                      'Click to view full text',
                                      style: TextStyle(
                                        fontSize: AppSizes.fontSm,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // "Watch Live" shortcut during transcription/transliteration
              if (uploadState.phase == UploadPhase.transcribing ||
                  uploadState.phase == UploadPhase.transliterating ||
                  uploadState.phase == UploadPhase.extractingAudio)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.sm,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        final fileId = uploadState.uploadResponse?.fileId;
                        final filename = uploadState.currentFileName ?? 'Unknown';
                        if (fileId != null) {
                          Navigator.of(context).pop();
                          AppRoutes.to(context, AppRoutes.realtimeViewer, arguments: {
                            'fileId': fileId,
                            'filename': filename,
                          });
                          ref.read(uploadNotifierProvider.notifier).reset();
                        }
                      },
                      icon: const Icon(Icons.live_tv_rounded, size: 18),
                      label: const Text('Skip wait — Watch with Live Subtitles'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                      ),
                    ),
                  ),
                ),

              // Action buttons
              if (!uploadState.isProcessing ||
                  uploadState.phase == UploadPhase.completed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppSizes.radiusLg),
                      bottomRight: Radius.circular(AppSizes.radiusLg),
                    ),
                  ),
                  child: uploadState.phase == UploadPhase.completed
                      // Completed state: Two buttons side by side
                      ? Row(
                          children: [
                            // Continue button
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showCompletionDialog(
                                    context,
                                    ref,
                                    uploadState,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  side: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSizes.md + 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusMd,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: AppSizes.fontMd,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSizes.md),
                            // Quick Download button (Roman Urdu SRT)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final notifier = ref.read(uploadNotifierProvider.notifier);
                                  final srtContent = uploadState.transcription?.hasRomanUrdu == true
                                      ? await notifier.downloadRomanUrduSrt()
                                      : await notifier.downloadSrt();

                                  if (srtContent != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Roman Urdu SRT downloaded!',
                                        ),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusMd,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSizes.md + 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusMd,
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_outlined, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Download SRT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      // Other states: Cancel or Retry
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!uploadState.isProcessing)
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(uploadNotifierProvider.notifier)
                                      .reset();
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (uploadState.phase == UploadPhase.error)
                              Flexible(child: ElevatedButton(
                                onPressed: () {
                                  ref
                                      .read(uploadNotifierProvider.notifier)
                                      .clearError();
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                                child: const Text('Try Again'),
                              )),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build icon based on current phase
  Widget _buildPhaseIcon(UploadPhase phase) {
    IconData icon;
    Color color;
    Color backgroundColor;

    switch (phase) {
      case UploadPhase.idle:
        icon = Icons.upload_file_outlined;
        color = AppColors.textSecondary;
        backgroundColor = AppColors.surfaceVariant;
        break;
      case UploadPhase.uploading:
        icon = Icons.cloud_upload_outlined;
        color = AppColors.accent;
        backgroundColor = AppColors.accentLight;
        break;
      case UploadPhase.extractingAudio:
      case UploadPhase.transcribing:
      case UploadPhase.transliterating:
        icon = Icons.auto_awesome_outlined;
        color = AppColors.accent;
        backgroundColor = AppColors.accentLight;
        break;
      case UploadPhase.completed:
        icon = Icons.check_circle;
        color = AppColors.success;
        backgroundColor = AppColors.success.withOpacity(0.15);
        break;
      case UploadPhase.error:
        icon = Icons.error_outline;
        color = AppColors.error;
        backgroundColor = AppColors.error.withOpacity(0.15);
        break;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, size: 40, color: color),
    );
  }
}

/// Show full text dialog
void _showFullTextDialog(BuildContext context, String fullText, {bool isRomanUrdu = false}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSizes.radiusLg),
                  topRight: Radius.circular(AppSizes.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.article_outlined,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Text(
                    isRomanUrdu ? 'Roman Urdu Transliteration' : 'Full Transcription',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: SelectableText(
                  fullText,
                  textDirection: isRomanUrdu ? TextDirection.ltr : TextDirection.rtl,
                  textAlign: isRomanUrdu ? TextAlign.left : TextAlign.right,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    height: 2.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Show completion dialog with improved design
void _showCompletionDialog(
  BuildContext context,
  WidgetRef ref,
  UploadState uploadState,
) {
  if (uploadState.transcription == null) return;

  final transcription = uploadState.transcription!;

  // Capture the navigator BEFORE context becomes stale
  // (context is from the upload dialog which was already popped)
  final navigatorState = Navigator.of(context, rootNavigator: true);

  TranscriptionCompleteDialog.show(
    context,
    filename: uploadState.currentFileName ?? 'Unknown',
    duration: transcription.durationFormatted,
    segmentCount: transcription.segmentCount,
    language: 'Urdu',
    previewText: transcription.hasRomanUrdu
        ? transcription.romanUrduText!
        : transcription.text,
    romanUrduPreviewText: transcription.romanUrduText,
    onDownload: () async {
      // Download Roman Urdu SRT file (fallback to Urdu SRT)
      final notifier = ref.read(uploadNotifierProvider.notifier);
      final srtContent = transcription.hasRomanUrdu
          ? await notifier.downloadRomanUrduSrt()
          : await notifier.downloadSrt();

      if (srtContent != null) {
        // Use a post-frame callback to show snackbar after dialog is dismissed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final scaffoldMessenger = ScaffoldMessenger.maybeOf(navigatorState.context);
          scaffoldMessenger?.showSnackBar(
            SnackBar(
              content: const Text('SRT downloaded successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          );
        });
      }

      // Reset state
      ref.read(uploadNotifierProvider.notifier).reset();
    },
    onViewDetails: () {
      // Dialog already pops itself before calling this callback
      final fileId = uploadState.uploadResponse?.fileId;
      final filename = uploadState.currentFileName ?? 'Unknown';
      if (fileId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorState.pushNamed(AppRoutes.realtimeViewer, arguments: {
            'fileId': fileId,
            'filename': filename,
          });
        });
        ref.read(uploadNotifierProvider.notifier).reset();
      }
    },
    onEdit: () {
      // Dialog already pops itself before calling this callback
      final transcription = uploadState.transcription;
      final fileId = uploadState.uploadResponse?.fileId;
      if (transcription != null && fileId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorState.pushNamed(AppRoutes.editor, arguments: {
            'fileId': fileId,
            'transcription': transcription,
          });
        });
        ref.read(uploadNotifierProvider.notifier).reset();
      }
    },
  );
}

/// Show upload progress dialog
void showUploadProgressDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const UploadProgressDialog(),
  );
}
