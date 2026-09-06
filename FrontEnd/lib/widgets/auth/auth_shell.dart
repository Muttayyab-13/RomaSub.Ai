// FrontEnd/lib/widgets/auth/auth_shell.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/base_theme.dart';
import '../../core/routes/app_routes.dart';
import '../common/theme_toggle_button.dart';
import 'auth_hero_panel.dart';
import 'auth_tab_switcher.dart';

/// Shared scaffold for the sign-in and sign-up screens.
///
/// Wraps its content in the scoped redesign theme ([buildBaseTheme]) and lays
/// out the branded [AuthHeroPanel] beside a quiet form column. Wide screens get
/// a true split; narrow screens stack a slim hero band above the scrollable
/// form. The header, the Log In / Sign Up [AuthTabSwitcher], and the form's
/// chrome live here; the field-level behaviour lives in the [form] each screen
/// passes in.
class AuthShell extends StatelessWidget {
  final bool isDark;
  final String title;

  /// Leading subtitle text; the brand name ([AppStrings.appName]) is appended
  /// in the accent colour (e.g. "Sign in to continue to RomaSub.AI").
  final String subtitle;

  /// Which tab is active — drives the switcher and its navigation.
  final AuthTab activeTab;
  final Widget form;

  /// Width past which the split layout kicks in.
  static const double _splitBreakpoint = 900;

  const AuthShell({
    super.key,
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.activeTab,
    required this.form,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildBaseTheme(isDark),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: scheme.surface,
            body: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _splitBreakpoint) {
                  return Row(
                    children: [
                      const Expanded(flex: 5, child: AuthHeroPanel()),
                      Expanded(flex: 6, child: _formPanel(context)),
                    ],
                  );
                }
                return Column(
                  children: [
                    const SizedBox(
                      height: 168,
                      width: double.infinity,
                      child: AuthHeroPanel(compact: true),
                    ),
                    Expanded(child: _formPanel(context)),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onSwitch(BuildContext context, AuthTab tab) {
    // Mirror the existing cross-links: Log In pushes Sign Up; Sign Up pops back
    // to the Log In beneath it (preserving the navigation stack).
    if (tab == AuthTab.signup) {
      AppRoutes.to(context, AppRoutes.signup);
    } else {
      AppRoutes.back(context);
    }
  }

  Widget _formPanel(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    const verticalPad = AppSizes.lg;

    // The form is vertically centred when it fits and scrolls only when the
    // window is too short — so nothing is ever cut off at the bottom edge.
    final scroller = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.xl,
          verticalPad,
          AppSizes.xl,
          verticalPad,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - verticalPad * 2,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.authMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.headlineLarge),
                  const SizedBox(height: AppSizes.xs + 2),
                  Text.rich(
                    TextSpan(
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(text: subtitle),
                        TextSpan(
                          text: AppStrings.appName,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  AuthTabSwitcher(
                    active: activeTab,
                    onSwitch: (tab) => _onSwitch(context, tab),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  form,
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Theme toggle floats over the form surface so it costs no vertical space.
    return Stack(
      children: [
        Positioned.fill(child: scroller),
        const Positioned(
          top: AppSizes.md,
          right: AppSizes.md,
          child: ThemeToggleButton(),
        ),
      ],
    );
  }
}

/// A labelled hairline divider ("or") between the social button and the form.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Text(
            AppStrings.orDivider.toLowerCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}

/// The "Continue with Google" button, styled as a neutral outline so it never
/// competes with the teal primary CTA, with the real multi-colour Google mark.
class GoogleAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const GoogleAuthButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSizes.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.asset(
          AppAssets.googleG,
          width: AppSizes.iconSm,
          height: AppSizes.iconSm,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.g_mobiledata, size: AppSizes.iconMd),
        ),
        label: const Text(AppStrings.continueGoogle),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
    );
  }
}
