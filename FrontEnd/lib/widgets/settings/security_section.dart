import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/utils/validators.dart';

/// Password-change UI for the settings screen. Pure: state in via
/// [isGoogleAccount]/[isBusy], the completed (current, next) pair out via
/// [onChangePassword] — the screen owns the actual API call and busy flag.
/// [onChangePassword] reports back whether the change succeeded so this
/// widget knows when it's safe to clear the form.
///
/// Google accounts never set a password, so showing a change-password form
/// for them would be a dead end (fields that error on every submit). Instead
/// they get an honest "Signed in with Google" state with no TextFields.
class SecuritySection extends StatefulWidget {
  final bool isGoogleAccount;
  final bool isBusy;
  final Future<bool> Function(String current, String next) onChangePassword;

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
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _submit() async {
    if (widget.isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await widget.onChangePassword(_current.text, _next.text);
    if (ok && mounted) {
      _current.clear();
      _next.clear();
      _confirm.clear();
      _formKey.currentState?.reset();
    }
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            context,
            controller: _current,
            label: 'Current Password',
            validator: (value) => (value == null || value.isEmpty)
                ? 'Enter your current password'
                : null,
          ),
          SizedBox(height: AppSizes.sm),
          _field(
            context,
            controller: _next,
            label: 'New Password',
            validator: Validators.password,
          ),
          SizedBox(height: AppSizes.sm),
          _field(
            context,
            controller: _confirm,
            label: 'Confirm Password',
            validator: (value) => Validators.confirmPassword(value, _next.text),
          ),
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
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: true,
      validator: validator,
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
