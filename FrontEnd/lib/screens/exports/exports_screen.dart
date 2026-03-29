import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_config.dart';
import '../../widgets/sidebar/sidebar.dart';

/// Provider that fetches real exports from the backend
final exportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.dio.get(ApiConfig.exportsList);
  final data = response.data as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(data['exports'] ?? []);
});

class ExportsScreen extends ConsumerWidget {
  const ExportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).isDark;
    final exportsAsync = ref.watch(exportsProvider);

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          const Sidebar(currentRoute: AppRoutes.exports),
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
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        AppStrings.exports,
                        style: TextStyle(
                          fontSize: AppSizes.fontXl,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        color: textPrimary,
                        onPressed: () => ref.invalidate(exportsProvider),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: exportsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 48, color: textSecondary),
                          const SizedBox(height: AppSizes.md),
                          Text('Failed to load exports', style: TextStyle(color: textSecondary)),
                          TextButton(
                            onPressed: () => ref.invalidate(exportsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (exports) {
                      if (exports.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_done_rounded, size: 64, color: textSecondary),
                              const SizedBox(height: AppSizes.md),
                              Text(
                                'No exports yet',
                                style: TextStyle(fontSize: AppSizes.fontMd, color: textSecondary),
                              ),
                              const SizedBox(height: AppSizes.sm),
                              Text(
                                'Export subtitles from the editor to see them here',
                                style: TextStyle(fontSize: AppSizes.fontSm, color: textSecondary),
                              ),
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
                              '${AppStrings.exportHistory} (${exports.length})',
                              style: TextStyle(
                                fontSize: AppSizes.fontLg,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSizes.md),
                            ...exports.map((export) => _ExportTile(
                              export: export,
                              isDark: isDark,
                            )),
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

class _ExportTile extends StatelessWidget {
  final Map<String, dynamic> export;
  final bool isDark;

  const _ExportTile({required this.export, required this.isDark});

  IconData _formatIcon(String format) {
    switch (format) {
      case 'srt': return Icons.subtitles_rounded;
      case 'vtt': return Icons.web_rounded;
      case 'txt': return Icons.description_rounded;
      default: return Icons.file_present_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = export['filename'] ?? 'Unknown';
    final format = (export['format'] ?? 'srt').toString().toUpperCase();
    final projectName = export['project_name'] ?? '';
    final createdAt = export['created_at'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(
              _formatIcon(export['format'] ?? 'srt'),
              size: 20,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.fontSm,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$projectName  |  $format',
                  style: TextStyle(
                    fontSize: AppSizes.fontXs,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Text(
              format,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
