import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import 'pressable.dart';

class SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const SocialButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final bgColor = AppColors.getCard(isDark);
    final borderColor = AppColors.getBorder(isDark);
    final textColor = AppColors.getPrimary(isDark);
    final iconColor = AppColors.getPrimary(isDark);

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm + 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: AppSizes.iconMd),
          const SizedBox(width: AppSizes.sm),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
