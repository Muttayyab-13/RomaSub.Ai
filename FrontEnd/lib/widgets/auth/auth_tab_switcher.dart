// FrontEnd/lib/widgets/auth/auth_tab_switcher.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';

/// Which auth screen is currently showing.
enum AuthTab { login, signup }

/// The "Log In / Sign Up" switcher above the auth form.
///
/// The active tab carries a teal underline and teal label; tapping the inactive
/// tab fires [onSwitch] so the screen can navigate to the other route. Presentation
/// only — it owns no navigation itself.
class AuthTabSwitcher extends StatelessWidget {
  final AuthTab active;
  final ValueChanged<AuthTab> onSwitch;

  const AuthTabSwitcher({
    super.key,
    required this.active,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tab(context, AuthTab.login, AppStrings.tabLogIn),
        _tab(context, AuthTab.signup, AppStrings.tabSignUp),
      ],
    );
  }

  Widget _tab(BuildContext context, AuthTab tab, String label) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = tab == active;
    final color = isActive ? scheme.primary : scheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: isActive ? null : () => onSwitch(tab),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm + 2),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppSizes.fontMd,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Container(
              height: 2,
              color: isActive ? scheme.primary : scheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
