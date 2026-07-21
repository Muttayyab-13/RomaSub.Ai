// FrontEnd/lib/widgets/auth/auth_hero_panel.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/design/app_palette.dart';

/// The branded photographic panel behind the sign-in / sign-up screens.
///
/// A full-bleed hero image ([AppAssets.authHero]) — a finished composition that
/// already carries the brand lockup, tagline, feature pills, a dual-script demo
/// caption, and the closing quote. Swap that one asset to restyle the panel; no
/// code change needed. Always dark — the hero reads against black regardless of
/// the app theme, so the navy backdrop shows through if the asset is missing.
class AuthHeroPanel extends StatelessWidget {
  /// When true, renders the slim horizontal band used above the form on narrow
  /// screens. The band biases toward the top of the artwork (the brand lockup)
  /// rather than centre-cropping to the mid-scene.
  final bool compact;

  const AuthHeroPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppPalette.videoStage),
      child: Image.asset(
        AppAssets.authHero,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: compact ? Alignment.topCenter : Alignment.center,
        // Fall back to the flat navy backdrop rather than throwing if the asset
        // can't be decoded.
        errorBuilder: (_, _, _) => const SizedBox.expand(),
      ),
    );
  }
}
