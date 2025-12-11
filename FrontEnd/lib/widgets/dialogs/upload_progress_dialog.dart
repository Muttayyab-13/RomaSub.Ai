import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../providers/upload_provider.dart';

/// Upload progress dialog showing real-time upload and transcription progress
class UploadProgressDialog extends ConsumerWidget {
  const UploadProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadNotifierProvider);

    return PopScope(
      canPop: !uploadState.isProcessing, // Prevent dismissal during processing
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: AppColors.surface,
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
              Padding(
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.textPrimary,
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
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      const SizedBox(height: AppSizes.md),
                      Text(
                        uploadState.progressPercent,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppSizes.fontMd,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ] else if (uploadState.phase == UploadPhase.transcribing ||
                        uploadState.phase == UploadPhase.extractingAudio) ...[
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                    ],

                    // Transcription result preview
                    if (uploadState.phase == UploadPhase.completed &&
                        uploadState.transcription != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSizes.lg),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.2),
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
                                    color: AppColors.success.withOpacity(0.1),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: AppSizes.fontMd,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.sm,
                                    vertical: AppSizes.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                                  ),
                                  child: Text(
                                    uploadState.transcription!.durationFormatted,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
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
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                              ),
                              child: Text(
                                uploadState.transcription!.text,
                                style: const TextStyle(
                                  fontSize: AppSizes.fontSm,
                                  color: AppColors.textSecondary,
                                  height: 1.6,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
              if (!uploadState.isProcessing || uploadState.phase == UploadPhase.completed)
                Container(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppSizes.radiusLg),
                      bottomRight: Radius.circular(AppSizes.radiusLg),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Close button
                      if (!uploadState.isProcessing)
                        TextButton(
                          onPressed: () {
                            ref.read(uploadNotifierProvider.notifier).reset();
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.lg,
                              vertical: AppSizes.md,
                            ),
                          ),
                          child: Text(
                            uploadState.phase == UploadPhase.completed ? 'Close' : 'Cancel',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: AppSizes.fontMd,
                            ),
                          ),
                        ),

                      const SizedBox(width: AppSizes.sm),

                      // Download SRT button (only when completed)
                      if (uploadState.phase == UploadPhase.completed)
                        ElevatedButton.icon(
                          onPressed: () async {
                            final srtContent =
                                await ref.read(uploadNotifierProvider.notifier).downloadSrt();

                            if (srtContent != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('SRT downloaded successfully!'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.download_outlined, size: 20),
                          label: const Text('Download SRT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.xl,
                              vertical: AppSizes.md + 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                            ),
                            elevation: 0,
                          ),
                        ),

                      // Retry button (only on error)
                      if (uploadState.phase == UploadPhase.error)
                        ElevatedButton(
                          onPressed: () {
                            ref.read(uploadNotifierProvider.notifier).clearError();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.xl,
                              vertical: AppSizes.md + 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Try Again'),
                        ),
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
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 40,
        color: color,
      ),
    );
  }
}

/// Show upload progress dialog
void showUploadProgressDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const UploadProgressDialog(),
  );
}
