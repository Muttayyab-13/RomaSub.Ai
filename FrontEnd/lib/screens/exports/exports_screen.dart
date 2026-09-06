import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/library_providers.dart';
import '../../providers/theme_provider.dart';

class ExportsScreen extends ConsumerWidget {
  const ExportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).isDark;
    final exportsAsync = ref.watch(exportsProvider);

    final cardBg = AppColors.getCard(isDark);
    final textPrimary = AppColors.getPrimary(isDark);
    final textSecondary = AppColors.getTextSecondary(isDark);
    final borderColor = AppColors.getBorder(isDark);

    return Column(
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
                  Text(
                    'Failed to load exports',
                    style: TextStyle(color: textSecondary),
                  ),
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
                      Icon(
                        Icons.download_done_rounded,
                        size: 64,
                        color: textSecondary,
                      ),
                      const SizedBox(height: AppSizes.md),
                      Text(
                        'No exports yet',
                        style: TextStyle(
                          fontSize: AppSizes.fontMd,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        'Export subtitles from the editor to see them here',
                        style: TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: textSecondary,
                        ),
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
                    ...exports.map(
                      (export) => _ExportTile(export: export, isDark: isDark),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExportTile extends StatelessWidget {
  final Map<String, dynamic> export;
  final bool isDark;

  const _ExportTile({required this.export, required this.isDark});

  IconData _formatIcon(String format) {
    switch (format) {
      case 'srt':
        return Icons.subtitles_rounded;
      case 'vtt':
        return Icons.web_rounded;
      case 'txt':
        return Icons.description_rounded;
      default:
        return Icons.file_present_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = export['filename'] ?? 'Unknown';
    final format = (export['format'] ?? 'srt').toString().toUpperCase();
    final projectName = export['project_name'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.getBorder(isDark)),
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
              color: AppColors.getTextSecondary(isDark),
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
                    color: AppColors.getPrimary(isDark),
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
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
