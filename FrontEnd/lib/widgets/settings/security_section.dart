import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';

/// Password-change UI for the settings screen. Pure: state in via
/// [isGoogleAccount]/[isBusy], the completed (current, next) pair out via
/// [onChangePassword] — the screen owns the actual API call and busy flag.
///
/// Google accounts never set a password, so showing a change-password form
/// for them would be a dead end (fields that error on every submit). Instead
/// they get an honest "Signed in with Google" state with no TextFields.
class SecuritySection extends StatefulWidget {
  final bool isGoogleAccount;
  final bool isBusy;
  final void Function(String current, String next) onChangePassword;

  const SecuritySection({
    super.key,
    required this.isGoogleAccount,
    required this.isBusy,
    required this.onChangePassword,
  });

  @override
  State<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<SecuritySection> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canSubmit => _next.text.isNotEmpty && _next.text == _confirm.text;

  void _submit() {
    if (!_canSubmit) return;
    widget.onChangePassword(_current.text, _next.text);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGoogleAccount) {
      return _googleState(context);
    }
    return _passwordForm(context);
  }

  Widget _googleState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.g_mobiledata, color: scheme.onSurfaceVariant),
        SizedBox(width: AppSizes.sm),
        Expanded(
          child: Text(
            'You signed in with Google, so there is no password to '
            'change here.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _passwordForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(context, controller: _current, label: 'Current Password'),
        SizedBox(height: AppSizes.sm),
        _field(context, controller: _next, label: 'New Password'),
        SizedBox(height: AppSizes.sm),
        _field(context, controller: _confirm, label: 'Confirm Password'),
        SizedBox(height: AppSizes.md),
        FilledButton(
          onPressed: widget.isBusy ? null : _submit,
          child: widget.isBusy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update Password'),
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: true,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
