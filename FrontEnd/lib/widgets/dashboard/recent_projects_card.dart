// FrontEnd/lib/widgets/dashboard/recent_projects_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';

/// A bordered card listing the most recent subtitle projects (max [maxRows]),
/// with a "View All" action. Rows are plain maps from `/subtitles/list/projects`.
class RecentProjectsCard extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final void Function(Map<String, dynamic>) onProjectTap;
  final VoidCallback onViewAll;
  final int maxRows;

  const RecentProjectsCard({
    super.key,
    required this.projects,
    required this.onProjectTap,
    required this.onViewAll,
    this.maxRows = 4,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = projects.take(maxRows).toList();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              AppSizes.md,
              AppSizes.sm,
              AppSizes.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.dashRecentProjects,
                  style: text.labelSmall?.copyWith(letterSpacing: 0.5),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(AppStrings.dashViewAll),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (rows.isEmpty)
            _empty(context)
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
              _ProjectRow(project: rows[i], onTap: () => onProjectTap(rows[i])),
            ],
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: AppSizes.iconLg,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(AppStrings.dashNoProjects, style: text.titleMedium),
          const SizedBox(height: AppSizes.xs),
          Text(
            AppStrings.dashNoProjectsHint,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Map<String, dynamic> project;
  final VoidCallback onTap;

  const _ProjectRow({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isVideo = project['is_video'] == true;
    final name =
        (project['project_name'] ?? project['original_filename'] ?? 'Untitled')
            .toString();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(
                isVideo ? Icons.movie_rounded : Icons.audiotrack_rounded,
                size: AppSizes.iconSm,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppStrings.dashProjectFlow,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              _formatProjectDate(project['created_at']),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSizes.md),
            Text(
              _formatDuration(project['file_duration']),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// "45:20" for < 1h, "1:12:05" for >= 1h, "--:--" when unknown.
String _formatDuration(dynamic seconds) {
  if (seconds is! num) return '--:--';
  final total = seconds.floor();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) {
    final mm = m.toString().padLeft(2, '0');
    return '$h:$mm:$ss';
  }
  return '$m:$ss';
}

/// "Today, 10:42 AM" / "Yesterday" / "MMM d, y". Falls back to "" on bad input.
String _formatProjectDate(dynamic iso) {
  if (iso is! String) return '';
  DateTime dt;
  try {
    dt = DateTime.parse(iso).toLocal();
  } catch (_) {
    return '';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final diffDays = today.difference(that).inDays;
  if (diffDays == 0) return 'Today, ${DateFormat.jm().format(dt)}';
  if (diffDays == 1) return 'Yesterday';
  return DateFormat.yMMMd().format(dt);
}
