import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';

class Sidebar extends ConsumerWidget {
  final String currentRoute;

  const Sidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Container(
      width: AppSizes.sidebarWidth,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.sidebarActive,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Icon(
                    Icons.video_library,
                    color: AppColors.accent,
                    size: AppSizes.iconMd,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.md),

          // Menu Items
          _MenuItem(
            icon: Icons.home_outlined,
            label: AppStrings.dashboard,
            isActive: currentRoute == AppRoutes.dashboard,
            onTap: () => AppRoutes.replace(context, AppRoutes.dashboard),
          ),
          _MenuItem(
            icon: Icons.folder_outlined,
            label: AppStrings.recentProjects,
            isActive: currentRoute == AppRoutes.projects,
            onTap: () => AppRoutes.replace(context, AppRoutes.projects),
          ),
          _MenuItem(
            icon: Icons.download_outlined,
            label: AppStrings.exports,
            isActive: currentRoute == AppRoutes.exports,
            onTap: () => AppRoutes.replace(context, AppRoutes.exports),
          ),
          _MenuItem(
            icon: Icons.feedback_outlined,
            label: AppStrings.feedback,
            isActive: currentRoute == AppRoutes.feedback,
            onTap: () => AppRoutes.replace(context, AppRoutes.feedback),
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: AppStrings.settings,
            isActive: currentRoute == AppRoutes.settings,
            onTap: () => AppRoutes.replace(context, AppRoutes.settings),
          ),

          const Spacer(),

          // User Profile
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    authState.userInitial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: AppSizes.fontSm,
                        ),
                      ),
                      Text(
                        authState.userEmail,
                        style: const TextStyle(
                          color: AppColors.sidebarText,
                          fontSize: AppSizes.fontXs,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout,
                    color: AppColors.sidebarText,
                    size: AppSizes.iconSm,
                  ),
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).logout();
                    AppRoutes.clearAndGo(context, AppRoutes.login);
                  },
                ),
              ],
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
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: isActive ? AppColors.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? AppColors.accent : AppColors.sidebarText,
          size: AppSizes.iconSm,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.sidebarText,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: AppSizes.fontSm,
          ),
        ),
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
