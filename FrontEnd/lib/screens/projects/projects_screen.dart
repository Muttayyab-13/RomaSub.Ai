import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/base_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/library_providers.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/projects/projects_table.dart';

/// The Projects tab. Opts into the redesigned system via a scoped
/// [buildBaseTheme] wrapper; the shell chrome around it keeps the old look.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openProject(BuildContext context, Map<String, dynamic> project) {
    AppRoutes.to(
      context,
      AppRoutes.editor,
      arguments: {'fileId': project['file_id'], 'transcription': null},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;
    final projectsAsync = ref.watch(projectsProvider);

    return Theme(
      data: buildBaseTheme(isDark),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;

          return ColoredBox(
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(AppStrings.allProjects, style: text.headlineMedium),
                      const SizedBox(width: AppSizes.sm),
                      _CountPill(count: projectsAsync.asData?.value.length),
                      const Spacer(),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: text.bodyMedium,
                              decoration: InputDecoration(
                                hintText: AppStrings.searchProjects,
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: AppSizes.iconSm,
                                  color: scheme.onSurfaceVariant,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: scheme.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: AppSizes.sm,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMd,
                                  ),
                                  borderSide: BorderSide(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMd,
                                  ),
                                  borderSide: BorderSide(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMd,
                                  ),
                                  borderSide: BorderSide(color: scheme.primary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        color: scheme.onSurfaceVariant,
                        tooltip: AppStrings.refreshTooltip,
                        onPressed: () => ref.invalidate(projectsProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.lg),
                  Expanded(
                    child: projectsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppStrings.projectsLoadError,
                              style: text.bodyMedium?.copyWith(
                                color: scheme.error,
                              ),
                            ),
                            const SizedBox(height: AppSizes.sm),
                            TextButton(
                              onPressed: () => ref.invalidate(projectsProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (allProjects) {
                        final query = _searchQuery.trim().toLowerCase();
                        final filtered = query.isEmpty
                            ? allProjects
                            : allProjects.where((p) {
                                final name = (p['project_name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final file = (p['original_filename'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                return name.contains(query) ||
                                    file.contains(query);
                              }).toList();

                        if (allProjects.isEmpty) {
                          return const _EmptyState(
                            icon: Icons.folder_open_outlined,
                            title: AppStrings.projectsEmptyTitle,
                            subtitle: AppStrings.projectsEmptySubtitle,
                          );
                        }

                        if (filtered.isEmpty) {
                          return const _EmptyState(
                            icon: Icons.search_off_rounded,
                            title: AppStrings.projectsSearchEmpty,
                          );
                        }

                        return SingleChildScrollView(
                          child: ProjectsTable(
                            projects: filtered,
                            onProjectTap: (p) => _openProject(context, p),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small mono count pill next to the page title, e.g. "142 total".
class _CountPill extends StatelessWidget {
  final int? count;

  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        count == null ? '—' : '$count total',
        style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _EmptyState({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppSizes.iconXl, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSizes.md),
          Text(
            title,
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              subtitle!,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
