// FrontEnd/lib/widgets/editor/segment_tile.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/editor_theme.dart';
import '../../models/subtitle_project_model.dart';
import '../common/pressable.dart';

/// One row in the editor's segment list.
///
/// Height is pinned by [height] because SubtitleListPanel scrolls by
/// `index * height` — the two must not drift apart.
class SegmentTile extends StatelessWidget {
  /// Fixed row height. SubtitleListPanel's auto-scroll depends on this.
  static const double height = 84.0;

  final EditableSegment segment;
  final int index;
  final bool isSelected;
  final bool isActive;
  final bool matchesSearch;
  final bool hasOverlap;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SegmentTile({
    super.key,
    required this.segment,
    required this.index,
    required this.isSelected,
    required this.isActive,
    required this.matchesSearch,
    required this.hasOverlap,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editor = Theme.of(context).extension<EditorTheme>()!;

    final Color background = isSelected
        ? editor.segmentSelected
        : isActive
        ? editor.segmentActive
        : scheme.surface;

    final isUrduFallback = segment.romanUrduText.isEmpty;

    return SizedBox(
      height: height,
      child: Pressable(
        onTap: onTap,
        decoration: BoxDecoration(
          color: background,
          border: Border(
            left: BorderSide(
              color: isSelected ? scheme.primary : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                style: AppTypography.mono(
                  size: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${segment.startFormatted} - ${segment.endFormatted}',
                    style: AppTypography.mono(size: 11, color: scheme.primary),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      segment.displayText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: isUrduFallback
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: isUrduFallback
                          ? AppTypography.urdu(
                              size: 12,
                              color: scheme.onSurface,
                            )
                          : AppTypography.latin(
                              size: 13,
                              color: scheme.onSurface,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.xs),
            // No mainAxisSize.min here: the Spacer below needs a bounded,
            // non-shrinking column to push the delete button to the bottom.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasOverlap)
                      Tooltip(
                        message: 'Overlaps the next segment',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: editor.overlapMarker,
                        ),
                      ),
                    if (segment.isEdited)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 12,
                          color: editor.editedMarker,
                        ),
                      ),
                    if (matchesSearch)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.search_rounded,
                          size: 12,
                          color: scheme.primary,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (isSelected)
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      splashRadius: 14,
                      tooltip: 'Delete segment',
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: scheme.onSurfaceVariant,
                      onPressed: onDelete,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
