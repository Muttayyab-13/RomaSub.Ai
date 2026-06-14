import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../providers/subtitle_editor_provider.dart';

/// Top toolbar: project name, undo/redo, save, export, auto-fix
class EditorToolbar extends ConsumerWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorNotifierProvider);
    final editorNotifier = ref.read(editorNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideoSource =
        _isVideoSource(editorState.project?.originalFilename ?? '');

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceVariant(isDark),
        border: Border(
          bottom: BorderSide(color: AppColors.getBorder(isDark)),
        ),
      ),
      child: Row(
        children: [
          // Back/Close button
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                size: 20, color: AppColors.getTextPrimary(isDark)),
            tooltip: 'Back to Dashboard',
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
          const SizedBox(width: AppSizes.xs),

          // Project name
          Icon(
            Icons.movie_edit,
            size: AppSizes.iconSm,
            color: AppColors.getTextSecondary(isDark),
          ),
          const SizedBox(width: AppSizes.xs),
          Flexible(
            child: Text(
              editorState.project?.projectName ?? 'Subtitle Editor',
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: AppSizes.md),

          // Undo
          _ToolbarButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo (Ctrl+Z)',
            enabled: editorState.canUndo,
            onPressed: () => editorNotifier.undo(),
            isDark: isDark,
          ),

          // Redo
          _ToolbarButton(
            icon: Icons.redo_rounded,
            tooltip: 'Redo (Ctrl+Y)',
            enabled: editorState.canRedo,
            onPressed: () => editorNotifier.redo(),
            isDark: isDark,
          ),

          const SizedBox(width: AppSizes.sm),
          Container(
            width: 1,
            height: 24,
            color: AppColors.getBorder(isDark),
          ),
          const SizedBox(width: AppSizes.sm),

          // Save
          _ToolbarButton(
            icon: editorState.isSaving
                ? Icons.hourglass_top_rounded
                : Icons.save_rounded,
            tooltip: 'Save (Ctrl+S)',
            enabled: editorState.hasUnsavedChanges && !editorState.isSaving,
            onPressed: () => editorNotifier.save(),
            isDark: isDark,
          ),

          // Save status indicator
          if (editorState.hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            ),

          const Spacer(),

          // Auto-fix overlaps
          TextButton.icon(
            onPressed: () => editorNotifier.fixTimingOverlaps(),
            icon: Icon(
              Icons.auto_fix_high_rounded,
              size: 16,
              color: AppColors.getTextSecondary(isDark),
            ),
            label: Text(
              'Fix Overlaps',
              style: TextStyle(
                fontSize: AppSizes.fontXs,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ),

          const SizedBox(width: AppSizes.sm),

          // Export dropdown
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'video_hardsub') {
                _handleVideoExport(context, ref, 'hardsub');
              } else if (value == 'video_softsub') {
                _handleVideoExport(context, ref, 'softsub');
              } else {
                _handleExport(context, ref, value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'srt', child: Text('Export as SRT')),
              const PopupMenuItem(value: 'vtt', child: Text('Export as VTT')),
              const PopupMenuItem(value: 'txt', child: Text('Export as TXT')),
              if (isVideoSource) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'video_hardsub',
                  child: Text('Video — burned-in captions'),
                ),
                const PopupMenuItem(
                  value: 'video_softsub',
                  child: Text('Video — toggleable captions'),
                ),
              ],
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.getPrimary(isDark),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Export',
                    style: TextStyle(
                      fontSize: AppSizes.fontXs,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    String format,
  ) async {
    final editorNotifier = ref.read(editorNotifierProvider.notifier);
    final result = await editorNotifier.export(format);

    if (result == null || !context.mounted) return;

    try {
      // Save to downloads directory
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${result['filename']}';
      await File(filePath).writeAsString(result['content']!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $filePath'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _isVideoSource(String filename) {
    if (!filename.contains('.')) return false;
    final ext = filename.split('.').last.toLowerCase();
    return const {'mp4', 'avi', 'mkv', 'mov', 'webm'}.contains(ext);
  }

  Future<void> _handleVideoExport(
    BuildContext context,
    WidgetRef ref,
    String mode,
  ) async {
    final editorNotifier = ref.read(editorNotifierProvider.notifier);

    // Block the UI with a progress dialog while FFmpeg renders.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _VideoExportProgressDialog(),
    );

    ({List<int> bytes, String filename})? result;
    try {
      result = await editorNotifier.exportVideo(mode);
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (result == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video export failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${result.filename}';
      await File(filePath).writeAsBytes(result.bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $filePath'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;
  final bool isDark;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 20,
      tooltip: tooltip,
      color: enabled
          ? AppColors.getTextPrimary(isDark)
          : AppColors.getTextSecondary(isDark).withValues(alpha: 0.4),
      onPressed: enabled ? onPressed : null,
      splashRadius: 18,
    );
  }
}

class _VideoExportProgressDialog extends StatelessWidget {
  const _VideoExportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: const AlertDialog(
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
