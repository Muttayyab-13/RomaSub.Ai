import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_logo.dart';

class Sidebar extends ConsumerWidget {
  final String currentRoute;

  const Sidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Container(
      width: 100,
      color: Colors.black,
      child: Column(
        children: [
          // Logo - use image asset instead of text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: const Center(
                child: AppLogo(size: 40),
              ),
            ),
          ),

          const SizedBox(height: AppSizes.xl),

          // Menu Items (icon-only)
          _MenuItem(
            icon: Icons.home_outlined,
            label: AppStrings.dashboard,
            isActive: currentRoute == AppRoutes.dashboard,
            onTap: () => AppRoutes.replace(context, AppRoutes.dashboard),
          ),
          const SizedBox(height: AppSizes.sm),
          _MenuItem(
            icon: Icons.videocam_outlined,
            label: AppStrings.recentProjects,
            isActive: currentRoute == AppRoutes.projects,
            onTap: () => AppRoutes.replace(context, AppRoutes.projects),
          ),
          const SizedBox(height: AppSizes.sm),
          _MenuItem(
            icon: Icons.download_outlined,
            label: AppStrings.exports,
            isActive: currentRoute == AppRoutes.exports,
            onTap: () => AppRoutes.replace(context, AppRoutes.exports),
          ),
          const SizedBox(height: AppSizes.sm),
          _MenuItem(
            icon: Icons.chat_bubble_outline,
            label: AppStrings.feedback,
            isActive: currentRoute == AppRoutes.feedback,
            onTap: () => AppRoutes.replace(context, AppRoutes.feedback),
          ),
          const SizedBox(height: AppSizes.sm),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: AppStrings.settings,
            isActive: currentRoute == AppRoutes.settings,
            onTap: () => AppRoutes.replace(context, AppRoutes.settings),
          ),

          const Spacer(),

          // Logout Button
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.lg),
            child: Tooltip(
              message: 'Logout',
              child: IconButton(
                icon: const Icon(
                  Icons.logout,
                  color: AppColors.sidebarText,
                  size: AppSizes.iconMd,
                ),
                onPressed: () {
                  ref.read(authNotifierProvider.notifier).logout();
                  AppRoutes.clearAndGo(context, AppRoutes.login);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
          child: Row(
            children: [
              // Active indicator dot
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              // Icon
              Icon(
                icon,
                color: isActive ? Colors.white : AppColors.sidebarText,
                size: AppSizes.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
