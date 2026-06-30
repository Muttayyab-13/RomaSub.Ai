import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../models/subtitle_project_model.dart';
import '../common/pressable.dart';

/// Single segment row in the subtitle list panel
class SegmentTile extends StatelessWidget {
  final EditableSegment segment;
  final int index;
  final bool isSelected;
  final bool isActive; // Currently playing
  final bool matchesSearch;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SegmentTile({
    super.key,
    required this.segment,
    required this.index,
    required this.isSelected,
    required this.isActive,
    required this.matchesSearch,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor;
    if (isSelected) {
      backgroundColor = isDark
          ? AppColors.accentLightDark
          : AppColors.accentLight;
    } else if (isActive) {
      // Currently-playing segment: subtle teal accent tint
      backgroundColor = AppColors.getAccent(isDark).withValues(alpha: 0.15);
    } else {
      backgroundColor = AppColors.getSurface(isDark);
    }

    return Pressable(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: AppColors.getBorder(isDark),
              width: 0.5,
            ),
            left: isSelected
                ? BorderSide(
                    color: AppColors.getPrimary(isDark),
                    width: 3,
                  )
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Sequence number
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time range
                  Text(
                    '${segment.startFormatted} → ${segment.endFormatted}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Text preview
                  Text(
                    segment.romanUrduText.isNotEmpty
                        ? segment.romanUrduText
                        : segment.urduText,
                    style: TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Indicators
            Column(
              children: [
                if (segment.isEdited)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 12,
                      color: AppColors.warning,
                    ),
                  ),
                if (matchesSearch)
                  Icon(
                    Icons.search_rounded,
                    size: 12,
                    color: AppColors.success,
                  ),
              ],
            ),
          ],
        ),
    );
  }
}
