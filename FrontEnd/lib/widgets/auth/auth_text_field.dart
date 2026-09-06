// FrontEnd/lib/widgets/auth/auth_text_field.dart
import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';

/// A field with its label rendered above (mockup layout), plus an optional
/// trailing widget on the label row — e.g. the "Forgot password?" link.
class LabeledAuthField extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final AuthTextField field;

  const LabeledAuthField({
    super.key,
    required this.label,
    required this.field,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        field,
      ],
    );
  }
}

/// The auth form field for the redesigned sign-in / sign-up screens.
///
/// Styled entirely from the scoped [ColorScheme] (see `buildBaseTheme`), so it
/// inherits the teal focus ring and surface tokens rather than the legacy
/// [AppColors] greys. Supports a leading icon, an inline password reveal, and
/// per-field validation errors.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool isPassword;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool enabled;

  /// Placeholder shown inside the field when empty (e.g. "you@example.com").
  final String? hintText;

  /// When true (default) the [label] floats inside the field, Material-style.
  /// When false the field shows only the [hintText] and the screen renders the
  /// [label] above the field — the mockup's layout.
  final bool floatingLabel;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.isPassword = false,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
    this.hintText,
    this.floatingLabel = true,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSizes.radiusMd);

    OutlineInputBorder borderOf(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscure,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      style: TextStyle(color: scheme.onSurface, fontSize: AppSizes.fontMd),
      decoration: InputDecoration(
        labelText: widget.floatingLabel ? widget.label : null,
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        errorText: widget.errorText,
        filled: true,
        // surfaceContainer* roles are unwired in this app's scheme (they fall
        // back to `surface`), so name the actual fill directly. Fields read as
        // outlined on the panel, matching the settings screen.
        fillColor: scheme.surface,
        prefixIcon: widget.icon == null
            ? null
            : Icon(
                widget.icon,
                size: AppSizes.iconSm,
                color: scheme.onSurfaceVariant,
              ),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: AppSizes.iconSm,
                  color: scheme.onSurfaceVariant,
                ),
                tooltip: _obscure ? 'Show password' : 'Hide password',
              )
            : null,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
        border: borderOf(scheme.outlineVariant, 1),
        enabledBorder: borderOf(scheme.outlineVariant, 1),
        focusedBorder: borderOf(scheme.primary, 1.6),
        errorBorder: borderOf(scheme.error, 1),
        focusedErrorBorder: borderOf(scheme.error, 1.6),
      ),
    );
  }
}
