import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;

  const ProjectCard({
    super.key,
    required this.title,
    required this.time,
    required this.icon,
    this.onTap,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final iconBg = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final iconColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textHint = isDark ? Colors.grey.shade500 : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Icon(icon, size: AppSizes.iconLg, color: iconColor),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                Icon(Icons.access_time, size: AppSizes.fontXs, color: textHint),
                const SizedBox(width: AppSizes.xs),
                Text(
                  time,
                  style: TextStyle(fontSize: AppSizes.fontXs, color: textHint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
