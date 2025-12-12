import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_assets.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    // Check if we are in dark mode using Theme.of(context).
    // However, AppLogo is StatelessWidget.
    // I can just use Theme.of(context).brightness.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      isDark ? AppAssets.logoDark : AppAssets.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Icon(
          Icons.video_library,
          size: size * 0.5,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}
