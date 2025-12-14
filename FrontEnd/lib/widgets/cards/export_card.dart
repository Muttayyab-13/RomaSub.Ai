import 'package:flutter/material.dart';
import '../../core/constants/app_sizes.dart';

class ExportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final bool isDark;

  const ExportCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onDownload,
    this.onDelete,
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

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(icon, color: iconColor, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppSizes.fontSm,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: AppSizes.fontXs, color: textHint),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download, color: iconColor),
            onPressed: onDownload,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
