import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/base_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/upload_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/library_providers.dart';
import '../../models/system_health.dart';
import '../../services/api/api_config.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../widgets/dashboard/system_status_card.dart';
import '../../widgets/dashboard/recent_projects_card.dart';
import '../../widgets/dashboard/upload_dropzone.dart';
import '../../widgets/dialogs/upload_progress_dialog.dart';

/// The Dashboard tab. Opts into the redesigned system via a scoped
/// [buildBaseTheme] wrapper; the shell chrome around it keeps the old look.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _handleFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ApiConfig.allowedExtensions,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        _snack('Failed to access file path');
        return;
      }

      if (mounted) showUploadProgressDialog(context);
      await ref
          .read(uploadNotifierProvider.notifier)
          .uploadAndTranscribe(filePath, language: 'ur');
    } catch (e) {
      _snack('File picker error: ${e.toString()}');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openProject(Map<String, dynamic> project) {
    AppRoutes.to(
      context,
      AppRoutes.editor,
      arguments: {'fileId': project['file_id'], 'transcription': null},
    );
  }

  void _goToProjectsTab() {
    ref.read(navIndexProvider.notifier).state = AppTab.projects.index;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 17) return 'Good Evening';
    if (hour >= 12) return 'Good Afternoon';
    return 'Good Morning';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;
    final authState = ref.watch(authNotifierProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final exportsAsync = ref.watch(exportsProvider);
    final healthAsync = ref.watch(systemHealthProvider);

    final firstName = authState.user?.firstName ?? '';
    final projects =
        projectsAsync.asData?.value ?? const <Map<String, dynamic>>[];

    return Theme(
      data: buildBaseTheme(isDark),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;
          return ColoredBox(
            color: scheme.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName.isEmpty
                        ? _greeting()
                        : '${_greeting()}, $firstName',
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    AppStrings.dashUploadSubtitle,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final mainColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          UploadDropzone(
                            onTap: _handleFilePicker,
                            compact:
                                constraints.maxWidth <
                                AppSizes.breakpointMobile,
                          ),
                          const SizedBox(height: AppSizes.lg),
                          RecentProjectsCard(
                            projects: projects,
                            onProjectTap: _openProject,
                            onViewAll: _goToProjectsTab,
                          ),
                        ],
                      );
                      final rail = _Rail(
                        totalProjects: projectsAsync.asData?.value.length,
                        totalExports: exportsAsync.asData?.value.length,
                        health: healthAsync,
                      );

                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            mainColumn,
                            const SizedBox(height: AppSizes.lg),
                            rail,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: mainColumn),
                          const SizedBox(width: AppSizes.lg),
                          SizedBox(width: 320, child: rail),
                        ],
                      );
                    },
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

/// The right rail: two stat cards over the system-status card.
class _Rail extends StatelessWidget {
  final int? totalProjects;
  final int? totalExports;
  final AsyncValue<SystemHealth> health;

  const _Rail({
    required this.totalProjects,
    required this.totalExports,
    required this.health,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.folder_outlined,
                label: AppStrings.dashTotalProjects,
                value: totalProjects?.toString(),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: StatCard(
                icon: Icons.download_outlined,
                label: AppStrings.dashExports,
                value: totalExports?.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        health.when(
          data: (h) => SystemStatusCard(health: h),
          loading: () => const SystemStatusCard(
            health: SystemHealthLoadingPlaceholder.value,
          ),
          error: (_, _) => const SystemStatusCard(
            health: SystemHealthLoadingPlaceholder.unreachable,
          ),
        ),
      ],
    );
  }
}
