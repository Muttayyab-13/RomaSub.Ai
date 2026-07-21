// FrontEnd/lib/screens/settings/settings_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/design/app_palette.dart';
import '../../core/design/base_theme.dart';
import '../../core/utils/validators.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api/api_config.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/settings/appearance_row.dart';
import '../../widgets/settings/security_section.dart';

/// The Settings tab. Opts into the redesigned system via a scoped
/// [buildBaseTheme] wrapper; the shell chrome around it keeps the old look.
///
/// This is a live, fully-wired screen — the redesign is a design-system
/// migration, not a behavior change. The three real handlers
/// (`_handleSaveProfile`, `_handleChangePassword`, `_handlePickImage`) and the
/// `user.googleId == null` gating for name-edit are preserved as-is.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _firstNameError;
  String? _lastNameError;
  bool _isEditingProfile = false;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;

  String? _selectedImagePath;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    setState(() {
      _firstNameError = Validators.name(_firstNameController.text);
      _lastNameError = Validators.name(_lastNameController.text);
    });
    if (_firstNameError != null || _lastNameError != null) return;

    setState(() => _isSavingProfile = true);
    final success = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        );

    if (!mounted) return;
    setState(() {
      _isSavingProfile = false;
      _isEditingProfile = false;
    });
    if (success) {
      AppSnackbar.showSuccess(context, AppStrings.profileUpdated);
    } else {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) AppSnackbar.showError(context, error);
    }
  }

  /// Adapts [SecuritySection]'s `(current, next)` callback onto the real
  /// `authNotifier.changePassword` call.
  Future<void> _handleChangePassword(String current, String next) async {
    setState(() => _isChangingPassword = true);
    final success = await ref
        .read(authNotifierProvider.notifier)
        .changePassword(current, next);

    if (!mounted) return;
    setState(() => _isChangingPassword = false);
    if (success) {
      AppSnackbar.showSuccess(context, 'Password changed successfully!');
    } else {
      final error = ref.read(authNotifierProvider).error;
      if (error != null) AppSnackbar.showError(context, error);
    }
  }

  Future<void> _handlePickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (pickedFile == null) return;

      setState(() {
        _selectedImagePath = pickedFile.path;
        _isUploadingImage = true;
      });

      final success = await ref
          .read(authNotifierProvider.notifier)
          .uploadProfilePicture(pickedFile.path);

      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      if (success) {
        AppSnackbar.showSuccess(context, 'Profile picture updated!');
      } else {
        setState(() => _selectedImagePath = null);
        final error = ref.read(authNotifierProvider).error;
        if (error != null) AppSnackbar.showError(context, error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
      AppSnackbar.showError(context, 'Failed to pick image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return Theme(
      data: buildBaseTheme(isDark),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;
          return ColoredBox(
            color: scheme.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.profileSettings,
                        style: text.headlineMedium,
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        'Manage your profile, security, and preferences.',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),
                      _SettingsCard(
                        title: 'Profile',
                        icon: Icons.person_outline,
                        child: _buildProfileSection(context, authState, user),
                      ),
                      const SizedBox(height: AppSizes.lg),
                      _SettingsCard(
                        title: 'Security',
                        icon: Icons.lock_outline,
                        child: SecuritySection(
                          isGoogleAccount: user?.isGoogleUser ?? false,
                          isBusy: _isChangingPassword,
                          onChangePassword: _handleChangePassword,
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),
                      _SettingsCard(
                        title: 'Appearance',
                        icon: Icons.palette_outlined,
                        child: AppearanceRow(
                          isDark: isDark,
                          onChanged: (_) =>
                              ref.read(themeProvider.notifier).toggleTheme(),
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),
                      _SettingsCard(
                        title: 'Account',
                        icon: Icons.info_outline,
                        child: _buildAccountSection(context, user, isDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileSection(
    BuildContext context,
    AuthState authState,
    UserModel? user,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(context, authState, user),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'This image will be displayed on your profile.',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.lg),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: AppSizes.lg),
        if (_isEditingProfile)
          _buildNameEditForm(context, user)
        else
          _buildNameDisplay(context, user),
        const SizedBox(height: AppSizes.md),
        _infoRow(context, 'Email', user?.email ?? '-'),
      ],
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    AuthState authState,
    UserModel? user,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.primary,
          backgroundImage: _selectedImagePath != null
              ? FileImage(File(_selectedImagePath!))
              : (user?.profilePictureUrl != null
                    ? NetworkImage(
                        '${ApiConfig.baseUrl}${user!.profilePictureUrl}',
                      )
                    : null),
          child: (_selectedImagePath == null && user?.profilePictureUrl == null)
              ? Text(
                  authState.userInitial,
                  style: TextStyle(
                    fontSize: 22,
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        if (_isUploadingImage)
          Positioned.fill(
            child: CircleAvatar(
              backgroundColor: scheme.scrim.withValues(alpha: 0.5),
              child: const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Material(
            color: scheme.primary,
            shape: CircleBorder(
              side: BorderSide(color: scheme.surfaceContainerLow, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _isUploadingImage ? null : _handlePickImage,
              child: SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: Icon(
                    Icons.camera_alt,
                    color: scheme.onPrimary,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameDisplay(BuildContext context, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(context, 'First Name', user?.firstName ?? '-'),
        _infoRow(context, 'Last Name', user?.lastName ?? '-'),
        if (user?.googleId == null) ...[
          const SizedBox(height: AppSizes.sm),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isEditingProfile = true),
            icon: const Icon(Icons.edit_outlined, size: AppSizes.iconSm),
            label: const Text('Edit Profile'),
          ),
        ],
      ],
    );
  }

  Widget _buildNameEditForm(BuildContext context, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _editableField(
                context,
                controller: _firstNameController,
                label: 'First Name',
                errorText: _firstNameError,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: _editableField(
                context,
                controller: _lastNameController,
                label: 'Last Name',
                errorText: _lastNameError,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSavingProfile
                    ? null
                    : () {
                        setState(() {
                          _isEditingProfile = false;
                          _firstNameError = null;
                          _lastNameError = null;
                          _firstNameController.text = user?.firstName ?? '';
                          _lastNameController.text = user?.lastName ?? '';
                        });
                      },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: FilledButton(
                onPressed: _isSavingProfile ? null : _handleSaveProfile,
                child: _isSavingProfile
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _editableField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    String? errorText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    UserModel? user,
    bool isDark,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final successColor = isDark ? AppPalette.successDark : AppPalette.success;
    final isVerified = user?.isVerified == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(
          context,
          'Account Type',
          user?.googleId != null ? 'Google' : 'Email',
        ),
        _infoRow(
          context,
          'Verification',
          isVerified ? 'Verified' : 'Pending',
          valueColor: isVerified ? successColor : scheme.onSurface,
        ),
        _infoRow(context, 'Member Since', _formatMemberSince(user?.createdAt)),
      ],
    );
  }

  String _formatMemberSince(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('MMM d, y').format(date);
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Text(
                value,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bordered, titled card wrapping one settings section.
class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSizes.iconSm, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSizes.sm),
              Text(title, style: text.titleMedium),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}
