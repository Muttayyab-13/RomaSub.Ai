import 'package:flutter/material.dart';

/// A tappable surface that renders the Material ripple **above** its
/// background decoration.
///
/// Fixes the common bug where an [InkWell] wraps an opaque [Container]: the
/// container paints over the Material, so the splash/highlight is never
/// visible. [Pressable] instead paints [decoration] on an [Ink] (which is part
/// of the Material) and overlays the [InkWell], so press feedback shows through.
///
/// Use for decorated, rectangular tap targets (cards, list rows, tiles). For
/// circular targets, use [InkWell] with `customBorder: CircleBorder()` inside a
/// transparent [Material] instead.
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.decoration,
    this.borderRadius,
    this.padding,
  });

  /// The content rendered inside the tappable surface.
  final Widget child;

  /// Tap callback. When null the surface is inert (no ripple).
  final VoidCallback? onTap;

  /// Background decoration painted on the [Ink] layer (below the ripple).
  final BoxDecoration? decoration;

  /// Clip radius for the ripple. Falls back to [decoration]'s radius.
  final BorderRadius? borderRadius;

  /// Optional inner padding applied to [child].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        borderRadius ?? (decoration?.borderRadius as BorderRadius?);

    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}
