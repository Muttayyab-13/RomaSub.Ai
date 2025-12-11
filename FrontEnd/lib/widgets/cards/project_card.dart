import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final VoidCallback? onTap;

  const ProjectCard({
    super.key,
    required this.title,
    required this.time,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Icon(icon, size: AppSizes.iconLg, color: AppColors.accent),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: AppSizes.fontXs,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: AppSizes.xs),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: AppSizes.fontXs,
                    color: AppColors.textHint,
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
