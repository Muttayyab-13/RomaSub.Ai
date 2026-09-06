import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/design/app_palette.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/base_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/upload_provider.dart';
import '../common/app_snackbar.dart';
import '../common/pressable.dart';
import 'transcription_complete_dialog.dart';

/// Upload → transcription progress dialog.
///
/// One dialog drives every [UploadPhase]: uploading and transcribing show a
/// teal progress bar (plus a "watch live" shortcut); completion shows a segment
/// summary card with a preview; errors offer a retry. Migrated onto the shared
/// design system ([buildBaseTheme] + [AppPalette]); all callbacks are unchanged.
class UploadProgressDialog extends ConsumerWidget {
  const UploadProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: buildBaseTheme(isDark),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final success = isDark ? AppPalette.successDark : AppPalette.success;
          final phase = uploadState.phase;

          final showWatchLive =
              phase == UploadPhase.transcribing ||
              phase == UploadPhase.transliterating ||
              phase == UploadPhase.extractingAudio;
          final showFooter =
              !uploadState.isProcessing || phase == UploadPhase.completed;

          return PopScope(
            canPop: !uploadState.isProcessing, // no dismiss while processing
            child: Dialog(
              backgroundColor: scheme.surface,
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.all(AppSizes.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXl + 4),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                  maxHeight: 680,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.xl,
                          AppSizes.xl,
                          AppSizes.xl,
                          AppSizes.lg,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _phaseIcon(scheme, success, phase),
                            const SizedBox(height: AppSizes.lg),
                            if (uploadState.currentFileName != null) ...[
                              Text(
                                uploadState.currentFileName!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.latin(
                                  size: 18,
                                  weight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppSizes.sm),
                            ],
                            Text(
                              uploadState.phaseMessage,
                              textAlign: TextAlign.center,
                              style: AppTypography.latin(
                                size: 14,
                                weight: FontWeight.w500,
                                color: phase == UploadPhase.error
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSizes.lg),
                            _progress(scheme, uploadState),
                            if (phase == UploadPhase.completed &&
                                uploadState.transcription != null)
                              _completedPreview(
                                context,
                                scheme,
                                success,
                                uploadState,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (showWatchLive)
                      _watchLive(context, ref, scheme, uploadState),
                    if (showFooter) _footer(context, ref, scheme, uploadState),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The circular phase glyph — teal while working, green on success, red on
  /// error, all as a tinted disc with a matching ring.
  Widget _phaseIcon(ColorScheme scheme, Color success, UploadPhase phase) {
    final (IconData icon, Color fg) = switch (phase) {
      UploadPhase.idle => (Icons.upload_file_outlined, scheme.onSurfaceVariant),
      UploadPhase.uploading => (Icons.cloud_upload_outlined, scheme.primary),
      UploadPhase.extractingAudio ||
      UploadPhase.transcribing ||
      UploadPhase.transliterating => (
        Icons.auto_awesome_outlined,
        scheme.primary,
      ),
      UploadPhase.completed => (Icons.check_rounded, success),
      UploadPhase.error => (Icons.error_outline_rounded, scheme.error),
    };

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fg.withValues(alpha: 0.12),
        border: Border.all(color: fg.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Icon(icon, size: 34, color: fg),
    );
  }

  /// Per-phase progress. Determinate bars for upload/transcribe, indeterminate
  /// for the FFmpeg/transliteration steps, nothing once complete.
  Widget _progress(ColorScheme scheme, UploadState s) {
    Widget bar(double? value) => ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
      ),
    );

    return switch (s.phase) {
      UploadPhase.uploading => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bar(s.uploadProgress),
          const SizedBox(height: AppSizes.md),
          Text(
            s.progressPercent,
            style: AppTypography.mono(
              size: 15,
              weight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
      UploadPhase.transcribing => bar(s.transcriptionProgress),
      UploadPhase.transliterating || UploadPhase.extractingAudio => bar(null),
      _ => const SizedBox.shrink(),
    };
  }

  /// The completed summary: segment count, a mono duration chip, a preview line,
  /// and a tap target that opens the full text.
  Widget _completedPreview(
    BuildContext context,
    ColorScheme scheme,
    Color success,
    UploadState s,
  ) {
    final t = s.transcription!;
    final roman = t.hasRomanUrdu;
    final preview = roman ? t.romanUrduText! : t.text;
    final count = t.segmentCount;

    return Pressable(
      onTap: () => _showFullTextDialog(context, preview, isRomanUrdu: roman),
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: success.withValues(alpha: 0.16),
                ),
                child: Icon(Icons.check_rounded, size: 14, color: success),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                '$count ${count == 1 ? 'segment' : 'segments'}',
                style: AppTypography.latin(
                  size: 14,
                  weight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: AppSizes.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Text(
                  t.durationFormatted,
                  style: AppTypography.mono(
                    size: 12,
                    weight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: roman ? TextDirection.ltr : TextDirection.rtl,
            style: roman
                ? AppTypography.latin(size: 14, color: scheme.onSurface)
                : AppTypography.urdu(size: 14, color: scheme.onSurface),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_outlined, size: 15, color: scheme.primary),
              const SizedBox(width: AppSizes.xs),
              Text(
                'View full text',
                style: AppTypography.latin(
                  size: 13,
                  weight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Watch with live subtitles" — jump to the realtime viewer instead of
  /// waiting for the batch job to finish.
  Widget _watchLive(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
    UploadState s,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        0,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () {
            final fileId = s.uploadResponse?.fileId;
            final filename = s.currentFileName ?? 'Unknown';
            if (fileId != null) {
              Navigator.of(context).pop();
              AppRoutes.to(
                context,
                AppRoutes.realtimeViewer,
                arguments: {'fileId': fileId, 'filename': filename},
              );
              ref.read(uploadNotifierProvider.notifier).reset();
            }
          },
          icon: const Icon(Icons.live_tv_rounded, size: 18),
          label: const Text('Watch with live subtitles'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
            textStyle: const TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Pinned action footer: Continue / Download on completion, Cancel / Retry
  /// otherwise. Stays visible while the summary scrolls.
  Widget _footer(
    BuildContext context,
    WidgetRef ref,
    ColorScheme scheme,
    UploadState s,
  ) {
    final Widget content = s.phase == UploadPhase.completed
        ? Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showCompletionDialog(context, ref, s);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(color: scheme.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    textStyle: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final notifier = ref.read(uploadNotifierProvider.notifier);
                    final srt = s.transcription?.hasRomanUrdu == true
                        ? await notifier.downloadRomanUrduSrt()
                        : await notifier.downloadSrt();
                    if (srt != null && context.mounted) {
                      AppSnackbar.showSuccess(
                        context,
                        'Roman Urdu SRT downloaded',
                      );
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download SRT'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    textStyle: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!s.isProcessing)
                TextButton(
                  onPressed: () {
                    ref.read(uploadNotifierProvider.notifier).reset();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: AppTypography.latin(
                      size: 14,
                      weight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (s.phase == UploadPhase.error)
                FilledButton(
                  onPressed: () {
                    ref.read(uploadNotifierProvider.notifier).clearError();
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  child: const Text('Try again'),
                ),
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: content,
      ),
    );
  }
}

/// Full-text reader for the transcription preview.
void _showFullTextDialog(
  BuildContext context,
  String fullText, {
  bool isRomanUrdu = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) => Theme(
      data: buildBaseTheme(isDark),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;
          return Dialog(
            backgroundColor: scheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.lg,
                      AppSizes.md,
                      AppSizes.sm,
                      AppSizes.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: AppSizes.iconSm,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            isRomanUrdu ? 'Roman Urdu' : 'Full transcript',
                            style: text.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      child: Directionality(
                        textDirection: isRomanUrdu
                            ? TextDirection.ltr
                            : TextDirection.rtl,
                        child: SelectableText(
                          fullText,
                          textAlign: isRomanUrdu
                              ? TextAlign.left
                              : TextAlign.right,
                          style: isRomanUrdu
                              ? AppTypography.latin(
                                  size: 15,
                                  color: scheme.onSurface,
                                )
                              : AppTypography.urdu(
                                  size: 15,
                                  color: scheme.onSurface,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
  // Capture notifier before dialog callbacks run, since ref may be disposed by then
  final uploadNotifier = ref.read(uploadNotifierProvider.notifier);

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
    isVideo: uploadState.uploadResponse?.isVideo ?? false,
    onExport: (format) async {
      // Text export (srt/vtt/txt): fetch from the subtitle project and save
      // to the downloads directory, mirroring the editor's export behaviour.
      final result = await uploadNotifier.exportText(format);
      if (result != null) {
        final content = result['content']!;
        await _saveExportToDownloads(
          navigatorState,
          filename: result['filename']!,
          writeFile: (path) => File(path).writeAsString(content),
        );
      } else {
        _showExportError(navigatorState, uploadNotifier.lastError);
      }
      uploadNotifier.reset();
    },
    onExportVideo: (mode) async {
      // Block with a progress dialog while FFmpeg renders (can take minutes).
      showDialog(
        context: navigatorState.context,
        barrierDismissible: false,
        builder: (_) => const _VideoExportProgressDialog(),
      );

      ({List<int> bytes, String filename})? result;
      try {
        result = await uploadNotifier.exportVideo(mode);
      } finally {
        // Dismiss the progress dialog regardless of outcome.
        navigatorState.pop();
      }

      if (result != null) {
        final bytes = result.bytes;
        await _saveExportToDownloads(
          navigatorState,
          filename: result.filename,
          writeFile: (path) => File(path).writeAsBytes(bytes),
        );
      } else {
        _showExportError(navigatorState, uploadNotifier.lastError);
      }
      uploadNotifier.reset();
    },
    onViewDetails: () {
      // Dialog already pops itself before calling this callback
      final fileId = uploadState.uploadResponse?.fileId;
      final filename = uploadState.currentFileName ?? 'Unknown';
      if (fileId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorState.pushNamed(
            AppRoutes.realtimeViewer,
            arguments: {'fileId': fileId, 'filename': filename},
          );
        });
        uploadNotifier.reset();
      }
    },
    onEdit: () {
      // Dialog already pops itself before calling this callback
      final transcription = uploadState.transcription;
      final fileId = uploadState.uploadResponse?.fileId;
      if (transcription != null && fileId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorState.pushNamed(
            AppRoutes.editor,
            arguments: {'fileId': fileId, 'transcription': transcription},
          );
        });
        uploadNotifier.reset();
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

/// Write an export to the platform downloads directory and report the result
/// via a snackbar — shared by the text and video export flows.
Future<void> _saveExportToDownloads(
  NavigatorState navigatorState, {
  required String filename,
  required Future<void> Function(String path) writeFile,
}) async {
  try {
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$filename';
    await writeFile(filePath);
    _showExportSnackBar(
      navigatorState,
      'Exported to: $filePath',
      AppColors.success,
    );
  } catch (e) {
    _showExportSnackBar(navigatorState, 'Export failed: $e', AppColors.error);
  }
}

/// Surface an export failure, preferring the server's actionable detail
/// (e.g. "Source video no longer available. Please re-upload.").
void _showExportError(NavigatorState navigatorState, String? message) {
  _showExportSnackBar(
    navigatorState,
    message ?? 'Export failed. Please try again.',
    AppColors.error,
  );
}

void _showExportSnackBar(
  NavigatorState navigatorState,
  String message,
  Color color,
) {
  // The completion dialog has already popped, so defer to the next frame to
  // attach the snackbar to the underlying screen's ScaffoldMessenger.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final messenger = ScaffoldMessenger.maybeOf(navigatorState.context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  });
}

/// Blocking spinner shown while a captioned video renders (FFmpeg can take
/// minutes). Mirrors the editor toolbar's export progress dialog.
class _VideoExportProgressDialog extends StatelessWidget {
  const _VideoExportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Flexible(
              child: Text(
                'Rendering video with captions…\nThis can take a few minutes.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
