import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../common/pressable.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class Sidebar extends ConsumerWidget {
  final String currentRoute;

  const Sidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).isDark;

    // Light mode: sidebar is black with white/grey icons
    // Dark mode: sidebar is dark grey (#2A2A2A) to match cards
    final sidebarBg = isDark ? const Color(0xFF2A2A2A) : Colors.black;
    final iconColor = isDark ? Colors.grey.shade500 : const Color(0xFF9CA3AF);
    // Active item: teal accent pill with white icon (meets contrast on teal-700)
    final activeIconColor = AppColors.onAccent;
    final activeBgColor = AppColors.accentStrong;

    return Container(
      width: 100,
      margin: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: sidebarBg,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Logo - switches between light and dark versions
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.xl,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: isDark ? 80 : 74,
                          height: isDark ? 80 : 74,
                          child: Image.asset(
                            isDark
                                ? 'assets/images/logos/logo2.png'
                                : 'assets/images/logos/logo3.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.md),

                    // Menu Items
                    _MenuItem(
                      icon: Icons.home_rounded,
                      label: AppStrings.dashboard,
                      isActive: currentRoute == AppRoutes.dashboard,
                      onTap: () =>
                          AppRoutes.replace(context, AppRoutes.dashboard),
                      iconColor: iconColor,
                      activeIconColor: activeIconColor,
                      activeBgColor: activeBgColor,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    _MenuItem(
                      icon: Icons.videocam_rounded,
                      label: AppStrings.recentProjects,
                      isActive: currentRoute == AppRoutes.projects,
                      onTap: () =>
                          AppRoutes.replace(context, AppRoutes.projects),
                      iconColor: iconColor,
                      activeIconColor: activeIconColor,
                      activeBgColor: activeBgColor,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    _MenuItem(
                      icon: Icons.download_rounded,
                      label: AppStrings.exports,
                      isActive: currentRoute == AppRoutes.exports,
                      onTap: () =>
                          AppRoutes.replace(context, AppRoutes.exports),
                      iconColor: iconColor,
                      activeIconColor: activeIconColor,
                      activeBgColor: activeBgColor,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    _MenuItem(
                      icon: Icons.chat_bubble_rounded,
                      label: AppStrings.feedback,
                      isActive: currentRoute == AppRoutes.feedback,
                      onTap: () =>
                          AppRoutes.replace(context, AppRoutes.feedback),
                      iconColor: iconColor,
                      activeIconColor: activeIconColor,
                      activeBgColor: activeBgColor,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    _MenuItem(
                      icon: Icons.settings_rounded,
                      label: AppStrings.settings,
                      isActive: currentRoute == AppRoutes.settings,
                      onTap: () =>
                          AppRoutes.replace(context, AppRoutes.settings),
                      iconColor: iconColor,
                      activeIconColor: activeIconColor,
                      activeBgColor: activeBgColor,
                    ),

                    const Spacer(),

                    // Logout Button
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.xl),
                      child: Tooltip(
                        message: 'Logout',
                        child: IconButton(
                          icon: Icon(
                            Icons.logout_rounded,
                            color: iconColor,
                            size: 28,
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
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color iconColor;
  final Color activeIconColor;
  final Color activeBgColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.iconColor,
    required this.activeIconColor,
    required this.activeBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(
              icon,
              color: isActive ? activeIconColor : iconColor,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
