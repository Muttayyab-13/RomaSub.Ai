import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/responsive.dart';
import '../common/pressable.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/theme_provider.dart';

/// Persistent navigation rail for the app shell.
///
/// Active tab + tab switching go through [navIndexProvider] (not routes), so the
/// shell's IndexedStack preserves screen state. On wide screens (>= tablet
/// breakpoint) the rail expands to show text labels; on narrower windows it
/// collapses to an icon-only rail with tooltips.
class Sidebar extends ConsumerWidget {
  /// Overrides the active highlight. Pass `-1` from deep screens (editor,
  /// realtime) pushed over the shell so no tab appears selected there.
  final int? selectedIndexOverride;

  const Sidebar({super.key, this.selectedIndexOverride});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).isDark;
    final activeIndex = selectedIndexOverride ?? ref.watch(navIndexProvider);
    final expanded = context.isDesktop; // labeled rail >= 1024, icon rail below

    // Light mode: sidebar is black with grey icons.
    // Dark mode: sidebar is dark grey (#2A2A2A) to match cards.
    final sidebarBg = isDark ? const Color(0xFF2A2A2A) : Colors.black;
    final iconColor = isDark ? Colors.grey.shade500 : const Color(0xFF9CA3AF);
    // Active item: teal accent pill with white foreground (contrast-safe).
    final activeIconColor = AppColors.onAccent;
    final activeBgColor = AppColors.accentStrong;

    const items = <_NavData>[
      _NavData(Icons.home_rounded, AppStrings.dashboard, 0),
      _NavData(Icons.videocam_rounded, AppStrings.recentProjects, 1),
      _NavData(Icons.download_rounded, AppStrings.exports, 2),
      _NavData(Icons.chat_bubble_rounded, AppStrings.feedback, 3),
      _NavData(Icons.settings_rounded, AppStrings.settings, 4),
    ];

    void go(int index) {
      ref.read(navIndexProvider.notifier).state = index;
      // No-op inside the shell; from a pushed editor/realtime this pops back to
      // the shell with the chosen tab already selected.
      Navigator.popUntil(context, (r) => r.isFirst);
    }

    return Container(
      width: expanded ? AppSizes.sidebarWidth : AppSizes.sidebarRailWidth,
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
                    for (final item in items) ...[
                      _MenuItem(
                        icon: item.icon,
                        label: item.label,
                        isActive: activeIndex == item.index,
                        expanded: expanded,
                        onTap: () => go(item.index),
                        iconColor: iconColor,
                        activeIconColor: activeIconColor,
                        activeBgColor: activeBgColor,
                      ),
                      const SizedBox(height: AppSizes.lg),
                    ],

                    const Spacer(),

                    // Logout (spatially separated at the bottom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.xl),
                      child: _MenuItem(
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        isActive: false,
                        expanded: expanded,
                        onTap: () {
                          ref.read(authNotifierProvider.notifier).logout();
                          AppRoutes.clearAndGo(context, AppRoutes.login);
                        },
                        iconColor: iconColor,
                        activeIconColor: activeIconColor,
                        activeBgColor: activeBgColor,
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

/// Static description of a navigation entry.
class _NavData {
  final IconData icon;
  final String label;
  final int index;
  const _NavData(this.icon, this.label, this.index);
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool expanded;
  final VoidCallback onTap;
  final Color iconColor;
  final Color activeIconColor;
  final Color activeBgColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.expanded,
    required this.onTap,
    required this.iconColor,
    required this.activeIconColor,
    required this.activeBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isActive ? activeIconColor : iconColor;

    final pill = Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      decoration: BoxDecoration(
        color: isActive ? activeBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: expanded
          ? SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                child: Row(
                  children: [
                    Icon(icon, color: fg, size: 24),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: AppSizes.fontSm,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SizedBox(
              width: 48,
              height: 48,
              child: Center(child: Icon(icon, color: fg, size: 28)),
            ),
    );

    if (expanded) {
      // Inset the pill from the rail edges; label is visible so no tooltip.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
        child: pill,
      );
    }
    // Collapsed: tooltip preserves discoverability of the icon-only item.
    return Tooltip(message: label, child: pill);
  }
}
