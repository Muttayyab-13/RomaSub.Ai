import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../models/project_model.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/sidebar/sidebar.dart';
import '../../widgets/cards/project_card.dart';

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
    final allProjects = Project.getSampleData();
    final projects = _searchQuery.isEmpty
        ? allProjects
        : allProjects
              .where(
                (p) =>
                    p.title.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    p.fileName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    // Theme-aware colors
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
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
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.black : Colors.grey)
                            .withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              size: AppSizes.iconSm,
                              color: textPrimary,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: AppSizes.sm,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      IconButton(
                        icon: Icon(
                          Icons.notifications_outlined,
                          color: textPrimary,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.allProjects,
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
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 1.4,
                                crossAxisSpacing: AppSizes.md,
                                mainAxisSpacing: AppSizes.md,
                              ),
                          itemCount: projects.length,
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            return ProjectCard(
                              title: project.fileName,
                              time: project.timeAgo,
                              icon: project.icon,
                              onTap: () {},
                              isDark: isDark,
                            );
                          },
                        ),
                      ],
                    ),
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
