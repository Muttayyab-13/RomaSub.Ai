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
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        contentPadding: const EdgeInsets.all(AppSizes.xl),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon based on phase
              _buildPhaseIcon(uploadState.phase),
              const SizedBox(height: AppSizes.lg),

              // Filename
              if (uploadState.currentFileName != null) ...[
                Text(
                  uploadState.currentFileName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.fontMd,
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
                  fontSize: AppSizes.fontSm,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.lg),

              // Progress indicator
              if (uploadState.phase == UploadPhase.uploading) ...[
                LinearProgressIndicator(
                  value: uploadState.uploadProgress,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  uploadState.progressPercent,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.fontSm,
                  ),
                ),
              ] else if (uploadState.phase == UploadPhase.transcribing ||
                  uploadState.phase == UploadPhase.extractingAudio) ...[
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ],

              const SizedBox(height: AppSizes.lg),

              // Transcription result preview
              if (uploadState.phase == UploadPhase.completed &&
                  uploadState.transcription != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Text(
                            '${uploadState.transcription!.segmentCount} segments',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: AppSizes.fontSm,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            uploadState.transcription!.durationFormatted,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppSizes.fontSm,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sm),
                      const Divider(height: 1),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        uploadState.transcription!.text,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
              ],

              // Action buttons
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: AppSizes.sm,
                  children: [
                    // Cancel button (only when not processing)
                    if (!uploadState.isProcessing)
                      TextButton(
                        onPressed: () {
                          ref.read(uploadNotifierProvider.notifier).reset();
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          uploadState.phase == UploadPhase.completed
                              ? 'Close'
                              : 'Cancel',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),

                    // Download SRT button (only when completed)
                    if (uploadState.phase == UploadPhase.completed)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final srtContent = await ref
                              .read(uploadNotifierProvider.notifier)
                              .downloadSrt();

                          if (srtContent != null && context.mounted) {
                            // TODO: Save file to disk using file_picker
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SRT downloaded successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download SRT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: AppSizes.sm,
                          ),
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: AppSizes.sm,
                          ),
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

    switch (phase) {
      case UploadPhase.idle:
        icon = Icons.upload_file;
        color = AppColors.textSecondary;
        break;
      case UploadPhase.uploading:
        icon = Icons.cloud_upload;
        color = AppColors.primary;
        break;
      case UploadPhase.extractingAudio:
      case UploadPhase.transcribing:
        icon = Icons.auto_awesome;
        color = AppColors.accent;
        break;
      case UploadPhase.completed:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case UploadPhase.error:
        icon = Icons.error;
        color = AppColors.error;
        break;
    }

    return Icon(
      icon,
      size: 64,
      color: color,
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
