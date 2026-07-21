import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/app_palette.dart';
import '../../core/design/app_typography.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/responsive.dart';
import '../common/pressable.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';

// The rail is the "caption studio" surface — always dark navy, in both app
// themes, matching the auth hero and the editor's video stage.
const Color _navy = AppPalette.videoStage; // #0B1C30
const Color _teal = AppPalette.primaryFixed; // #89F5E7
const Color _tealDim = AppPalette.primaryFixedDim; // #6BD8CB
const Color _onNav = Color(0xFFEDF6F3);
const Color _onNavMuted = Color(0xFF8CA4A8);

/// Persistent navigation rail for the app shell.
///
/// Active tab + tab switching go through [navIndexProvider] (not routes), so the
/// shell's IndexedStack preserves screen state. On wide screens (>= tablet
/// breakpoint) the rail expands to show text labels + an account chip; on
/// narrower windows it collapses to an icon-only rail with tooltips.
///
/// The active item reuses the product's own active-caption cue — a teal left
/// bar + teal-glass tint — so navigating speaks the same language as the
/// captions RomaSub.AI makes.
class Sidebar extends ConsumerWidget {
  /// Overrides the active highlight. Pass `-1` from deep screens (editor,
  /// realtime) pushed over the shell so no tab appears selected there.
  final int? selectedIndexOverride;

  const Sidebar({super.key, this.selectedIndexOverride});

  static const _items = <_NavData>[
    _NavData(Icons.space_dashboard_rounded, AppStrings.dashboard, 0),
    _NavData(Icons.video_library_rounded, AppStrings.recentProjects, 1),
    _NavData(Icons.download_rounded, AppStrings.exports, 2),
    _NavData(Icons.forum_rounded, AppStrings.feedback, 3),
    _NavData(Icons.settings_rounded, AppStrings.settings, 4),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = selectedIndexOverride ?? ref.watch(navIndexProvider);
    final expanded = context.isDesktop; // labeled rail >= 1024, icon rail below
    final user = ref.watch(authNotifierProvider).user;

    void go(int index) {
      ref.read(navIndexProvider.notifier).state = index;
      // No-op inside the shell; from a pushed editor/realtime this pops back to
      // the shell with the chosen tab already selected.
      Navigator.popUntil(context, (r) => r.isFirst);
    }

    void logout() {
      ref.read(authNotifierProvider.notifier).logout();
      AppRoutes.clearAndGo(context, AppRoutes.login);
    }

    return Container(
      width: expanded ? AppSizes.sidebarWidth : AppSizes.sidebarRailWidth,
      height: double.infinity,
      margin: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Faint teal top-glow — the same atmospheric cue as the auth hero.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -1.0),
                    radius: 1.2,
                    colors: [
                      _teal.withValues(alpha: 0.10),
                      _navy.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              _brand(expanded),
              _divider(expanded),
              const SizedBox(height: AppSizes.sm + 2),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in _items) ...[
                        _NavTile(
                          icon: item.icon,
                          label: item.label,
                          active: activeIndex == item.index,
                          expanded: expanded,
                          onTap: () => go(item.index),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              _divider(expanded),
              const SizedBox(height: AppSizes.sm),
              _AccountChip(
                expanded: expanded,
                initial: _initialOf(user?.initial),
                name: _nameOf(user?.fullName),
                email: user?.email ?? '',
                onTap: () => go(AppTab.settings.index),
              ),
              const SizedBox(height: 4),
              _NavTile(
                icon: Icons.logout_rounded,
                label: AppStrings.logout,
                active: false,
                expanded: expanded,
                onTap: logout,
              ),
              const SizedBox(height: AppSizes.md),
            ],
          ),
        ],
      ),
    );
  }

  static String _initialOf(String? initial) =>
      (initial != null && initial.isNotEmpty) ? initial : '?';

  static String _nameOf(String? name) =>
      (name != null && name.trim().isNotEmpty) ? name : AppStrings.yourAccount;

  Widget _brand(bool expanded) {
    final mark = SizedBox(
      width: expanded ? 34 : 40,
      height: expanded ? 34 : 40,
      // logo3 is the light-on-dark glyph — reads cleanly on the navy rail.
      child: Image.asset(AppAssets.logoDark, fit: BoxFit.contain),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        expanded ? AppSizes.lg : 0,
        AppSizes.xl,
        expanded ? AppSizes.md : 0,
        AppSizes.md,
      ),
      child: expanded
          ? Row(
              children: [
                mark,
                const SizedBox(width: AppSizes.sm + 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'RomaSub',
                        style: AppTypography.latin(
                          size: 18,
                          weight: FontWeight.w800,
                          color: _onNav,
                        ),
                      ),
                      TextSpan(
                        text: '.AI',
                        style: AppTypography.latin(
                          size: 18,
                          weight: FontWeight.w800,
                          color: _teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(child: mark),
    );
  }

  Widget _divider(bool expanded) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: expanded ? AppSizes.lg : AppSizes.md,
    ),
    child: Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
  );
}

/// Static description of a navigation entry.
class _NavData {
  final IconData icon;
  final String label;
  final int index;
  const _NavData(this.icon, this.label, this.index);
}

/// A navigation row/tile with a hover state and the active-caption cue.
class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final Color fg = active ? _teal : (_hover ? _onNav : _onNavMuted);
    final Color bg = active
        ? _teal.withValues(alpha: 0.12)
        : (_hover ? Colors.white.withValues(alpha: 0.05) : Colors.transparent);

    final Widget tile = widget.expanded
        ? _expanded(fg, bg)
        : _collapsed(fg, bg);

    final hoverable = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: tile,
    );

    // Labels are visible when expanded, so the tooltip is only for the rail.
    return widget.expanded
        ? hoverable
        : Tooltip(message: widget.label, child: hoverable);
  }

  Widget _expanded(Color fg, Color bg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
      child: Pressable(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 12),
            child: Row(
              children: [
                // Active-caption cue: teal left bar, mirroring the editor's
                // active-segment indicator. Transparent when idle keeps rows
                // aligned.
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: widget.active ? _tealDim : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(widget.icon, color: fg, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.latin(
                      size: AppSizes.fontSm,
                      weight: widget.active ? FontWeight.w700 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsed(Color fg, Color bg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
      child: Center(
        child: Pressable(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: Icon(widget.icon, color: fg, size: 26)),
          ),
        ),
      ),
    );
  }
}

/// Bottom account chip: avatar initial + name/email, tapping opens Settings.
/// Collapses to just the avatar (with a tooltip) on the icon rail.
class _AccountChip extends StatelessWidget {
  final bool expanded;
  final String initial;
  final String name;
  final String email;
  final VoidCallback onTap;

  const _AccountChip({
    required this.expanded,
    required this.initial,
    required this.name,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _teal.withValues(alpha: 0.16),
        border: Border.all(color: _tealDim.withValues(alpha: 0.4)),
      ),
      child: Text(
        initial,
        style: AppTypography.latin(
          size: 14,
          weight: FontWeight.w700,
          color: _teal,
        ),
      ),
    );

    final tile = Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: expanded
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.latin(
                            size: 14,
                            weight: FontWeight.w600,
                            color: _onNav,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.latin(
                              size: 12,
                              weight: FontWeight.w400,
                              color: _onNavMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _onNavMuted,
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(child: avatar),
            ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? AppSizes.sm : 0),
      child: expanded ? tile : Tooltip(message: name, child: tile),
    );
  }
}
