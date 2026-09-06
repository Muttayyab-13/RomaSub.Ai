// lib/widgets/projects/projects_table.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/format_utils.dart';

/// A dense table of projects. Columns map 1:1 to real backend fields; there is
/// deliberately no Status column (projects have no status), no bulk-select, and
/// no row menu (no rename/delete endpoint exists). [onProjectTap] opens the
/// editor for the tapped row.
class ProjectsTable extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final ValueChanged<Map<String, dynamic>> onProjectTap;

  const ProjectsTable({
    super.key,
    required this.projects,
    required this.onProjectTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _header(context),
          for (var i = 0; i < projects.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            _row(context, projects[i]),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final style = text.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(AppStrings.projectsColProject, style: style),
          ),
          Expanded(
            flex: 3,
            child: Text(AppStrings.projectsColFilename, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppStrings.projectsColDuration,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppStrings.projectsColSegments,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(AppStrings.projectsColLastEdited, style: style),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> p) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mono = text.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: scheme.onSurfaceVariant,
    );
    final isVideo = p['is_video'] == true;
    return InkWell(
      onTap: () => onProjectTap(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm + 2,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Icon(
                    isVideo ? Icons.movie_outlined : Icons.audiotrack_outlined,
                    size: AppSizes.iconSm,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      (p['project_name'] ?? '').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                (p['original_filename'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatDuration(p['file_duration'] as num?),
                textAlign: TextAlign.right,
                style: mono,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${p['segment_count'] ?? 0}',
                textAlign: TextAlign.right,
                style: mono,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                formatRelativeDate((p['updated_at'] ?? '').toString()),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
