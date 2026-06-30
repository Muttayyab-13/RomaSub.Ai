import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_config.dart';
import '../../widgets/sidebar/sidebar.dart';
import '../../widgets/common/pressable.dart';

/// Provider that fetches real projects from the backend
final projectsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get(ApiConfig.projectsList);
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['projects'] ?? []);
});

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

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;
    final projectsAsync = ref.watch(projectsProvider);

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          const Sidebar(currentRoute: AppRoutes.projects),
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.md,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(
                      bottom: BorderSide(color: borderColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        AppStrings.recentProjects,
                        style: TextStyle(
                          fontSize: AppSizes.fontXl,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 280,
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: AppStrings.searchProjects,
                            hintStyle: TextStyle(color: textSecondary),
                            prefixIcon: Icon(Icons.search, size: AppSizes.iconSm, color: textPrimary),
                            filled: true,
                            fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        color: textPrimary,
                        onPressed: () => ref.invalidate(projectsProvider),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: projectsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 48, color: textSecondary),
                          const SizedBox(height: AppSizes.md),
                          Text('Failed to load projects', style: TextStyle(color: textSecondary)),
                          const SizedBox(height: AppSizes.sm),
                          TextButton(
                            onPressed: () => ref.invalidate(projectsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (allProjects) {
                      final projects = _searchQuery.isEmpty
                          ? allProjects
                          : allProjects.where((p) {
                              final name = (p['project_name'] ?? '').toString().toLowerCase();
                              final file = (p['original_filename'] ?? '').toString().toLowerCase();
                              final q = _searchQuery.toLowerCase();
                              return name.contains(q) || file.contains(q);
                            }).toList();

                      if (projects.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 64, color: textSecondary),
                              const SizedBox(height: AppSizes.md),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No projects match your search'
                                    : 'No projects yet',
                                style: TextStyle(fontSize: AppSizes.fontMd, color: textSecondary),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: AppSizes.sm),
                                Text(
                                  'Upload a video and transcribe it to create a project',
                                  style: TextStyle(fontSize: AppSizes.fontSm, color: textSecondary),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${projects.length} Project${projects.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: AppSizes.fontLg,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSizes.md),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.0,
                                crossAxisSpacing: AppSizes.md,
                                mainAxisSpacing: AppSizes.md,
                              ),
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                final p = projects[index];
                                return _ProjectTile(
                                  project: p,
                                  isDark: isDark,
                                  onTap: () {
                                    AppRoutes.to(context, AppRoutes.editor, arguments: {
                                      'fileId': p['file_id'],
                                      'transcription': null,
                                    });
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Map<String, dynamic> project;
  final bool isDark;
  final VoidCallback onTap;

  const _ProjectTile({required this.project, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = project['project_name'] ?? 'Untitled';
    final filename = project['original_filename'] ?? '';
    final segments = project['segment_count'] ?? 0;
    final duration = project['file_duration'] as num?;
    final durationStr = duration != null
        ? '${(duration / 60).floor()}:${(duration.toDouble() % 60).floor().toString().padLeft(2, '0')}'
        : '--:--';

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(Icons.movie_rounded, size: 20,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppSizes.fontSm,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              filename,
              style: TextStyle(
                fontSize: AppSizes.fontXs,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                Text(
                  '$segments segments',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
                const Spacer(),
                Text(
                  durationStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}
