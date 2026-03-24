import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../providers/subtitle_editor_provider.dart';
import '../../providers/video_player_provider.dart';
import 'timing_adjuster.dart';

/// Right panel: edit the selected segment's text and timing
class TextEditorPanel extends ConsumerStatefulWidget {
  const TextEditorPanel({super.key});

  @override
  ConsumerState<TextEditorPanel> createState() => _TextEditorPanelState();
}

class _TextEditorPanelState extends ConsumerState<TextEditorPanel> {
  final _romanUrduController = TextEditingController();
  final _urduController = TextEditingController();
  int? _lastSegmentIndex;

  @override
  void dispose() {
    _romanUrduController.dispose();
    _urduController.dispose();
    super.dispose();
  }

  void _syncControllers(EditorState editorState) {
    final segment = editorState.selectedSegment;
    final currentIndex = editorState.selectedSegmentIndex;

    if (currentIndex != _lastSegmentIndex) {
      _lastSegmentIndex = currentIndex;
      if (segment != null) {
        _romanUrduController.text = segment.romanUrduText;
        _urduController.text = segment.urduText;
      } else {
        _romanUrduController.clear();
        _urduController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorNotifierProvider);
    final editorNotifier = ref.read(editorNotifierProvider.notifier);
    final playerNotifier = ref.read(videoPlayerNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _syncControllers(editorState);

    final segment = editorState.selectedSegment;
    final selectedIndex = editorState.selectedSegmentIndex;

    return Container(
      color: AppColors.getSurface(isDark),
      child: segment == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: AppSizes.iconXl,
                    color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'Select a segment to edit',
                    style: TextStyle(
                      color: AppColors.getTextSecondary(isDark),
                      fontSize: AppSizes.fontSm,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: AppSizes.iconSm,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Text(
                        'Segment ${selectedIndex! + 1}',
                        style: TextStyle(
                          fontSize: AppSizes.fontMd,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                      ),
                      const Spacer(),
                      if (segment.isEdited)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSm),
                          ),
                          child: Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),

                  // Timing adjusters
                  Row(
                    children: [
                      Expanded(
                        child: TimingAdjuster(
                          label: 'Start',
                          value: segment.start,
                          onChanged: (v) {
                            editorNotifier.updateSegmentTiming(
                              selectedIndex,
                              v,
                              segment.end,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: TimingAdjuster(
                          label: 'End',
                          value: segment.end,
                          onChanged: (v) {
                            editorNotifier.updateSegmentTiming(
                              selectedIndex,
                              segment.start,
                              v,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),

                  // Duration display
                  Text(
                    'Duration: ${segment.duration.toStringAsFixed(2)}s',
                    style: TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: segment.isValid
                          ? AppColors.getTextSecondary(isDark)
                          : AppColors.error,
                    ),
                  ),

                  // Validation error
                  if (segment.validationError != null) ...[
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      segment.validationError!,
                      style: TextStyle(
                        fontSize: AppSizes.fontXs,
                        color: AppColors.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSizes.md),

                  // Roman Urdu text field
                  Text(
                    'Roman Urdu Text',
                    style: TextStyle(
                      fontSize: AppSizes.fontXs,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  TextField(
                    controller: _romanUrduController,
                    maxLines: 4,
                    maxLength: 500,
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter Roman Urdu text...',
                      hintStyle: TextStyle(
                        color: AppColors.getTextSecondary(isDark),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                        borderSide:
                            BorderSide(color: AppColors.getBorder(isDark)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                        borderSide:
                            BorderSide(color: AppColors.getBorder(isDark)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide(
                          color: AppColors.getPrimary(isDark),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.getSurfaceVariant(isDark),
                      contentPadding: const EdgeInsets.all(AppSizes.sm),
                    ),
                    onChanged: (value) {
                      editorNotifier.updateSegmentText(
                        selectedIndex,
                        romanUrduText: value,
                      );
                    },
                  ),

                  const SizedBox(height: AppSizes.md),

                  // Urdu text field (read-only display)
                  Text(
                    'Urdu Text (Original)',
                    style: TextStyle(
                      fontSize: AppSizes.fontXs,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  TextField(
                    controller: _urduController,
                    maxLines: 3,
                    readOnly: true,
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                        borderSide:
                            BorderSide(color: AppColors.getBorder(isDark)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                        borderSide:
                            BorderSide(color: AppColors.getBorder(isDark)),
                      ),
                      filled: true,
                      fillColor: AppColors.getSurfaceVariant(isDark)
                          .withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.all(AppSizes.sm),
                    ),
                    textDirection: TextDirection.rtl,
                  ),

                  const SizedBox(height: AppSizes.lg),

                  // Action buttons
                  Row(
                    children: [
                      // Play segment
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            playerNotifier.seekToSeconds(segment.start);
                            playerNotifier.play();
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Play'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.getTextPrimary(isDark),
                            side: BorderSide(
                              color: AppColors.getBorder(isDark),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      // Delete segment
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showDeleteConfirmation(
                              context,
                              isDark,
                              () => editorNotifier.deleteSegment(selectedIndex),
                            );
                          },
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSizes.sm),

                  // Add segment after
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          editorNotifier.addSegment(selectedIndex),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Segment After'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.getTextPrimary(isDark),
                        side: BorderSide(color: AppColors.getBorder(isDark)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    bool isDark,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Segment'),
        content: const Text('Are you sure you want to delete this segment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
