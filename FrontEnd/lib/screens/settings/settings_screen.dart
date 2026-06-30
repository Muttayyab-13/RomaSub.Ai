import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/sidebar/sidebar.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../services/api/api_config.dart';

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

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    setState(() {
      _firstNameError = Validators.name(_firstNameController.text);
      _lastNameError = Validators.name(_lastNameController.text);
    });

    if (_firstNameError == null && _lastNameError == null) {
      setState(() => _isSavingProfile = true);
      final success = await ref
          .read(authNotifierProvider.notifier)
          .updateProfile(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _isSavingProfile = false;
          _isEditingProfile = false;
        });
        if (success) {
          AppSnackbar.showSuccess(context, AppStrings.profileUpdated);
        } else {
          final error = ref.read(authNotifierProvider).error;
          if (error != null) {
            AppSnackbar.showError(context, error);
          }
        }
      }
    }
  }

  Future<void> _handleChangePassword() async {
    setState(() {
      _currentPasswordError = Validators.password(
        _currentPasswordController.text,
      );
      _newPasswordError = Validators.password(_newPasswordController.text);
      _confirmPasswordError = Validators.confirmPassword(
        _confirmPasswordController.text,
        _newPasswordController.text,
      );
    });

    if (_currentPasswordError == null &&
        _newPasswordError == null &&
        _confirmPasswordError == null) {
      setState(() => _isChangingPassword = true);
      final success = await ref
          .read(authNotifierProvider.notifier)
          .changePassword(
            _currentPasswordController.text,
            _newPasswordController.text,
          );

      if (mounted) {
        setState(() => _isChangingPassword = false);
        if (success) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          AppSnackbar.showSuccess(context, 'Password changed successfully!');
        } else {
          final error = ref.read(authNotifierProvider).error;
          if (error != null) {
            AppSnackbar.showError(context, error);
          }
        }
      }
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

      if (pickedFile != null) {
        setState(() {
          _selectedImagePath = pickedFile.path;
          _isUploadingImage = true;
        });

        final success = await ref
            .read(authNotifierProvider.notifier)
            .uploadProfilePicture(pickedFile.path);

        if (mounted) {
          setState(() => _isUploadingImage = false);
          if (success) {
            AppSnackbar.showSuccess(context, 'Profile picture updated!');
          } else {
            setState(() => _selectedImagePath = null);
            final error = ref.read(authNotifierProvider).error;
            if (error != null) {
              AppSnackbar.showError(context, error);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        AppSnackbar.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    final isDark = ref.watch(themeProvider).isDark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          const Sidebar(currentRoute: AppRoutes.settings),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.settings_outlined,
                              color: isDark ? Colors.black : Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.settings,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage your account settings and preferences',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Two-column layout
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left - Profile Card
                          SizedBox(
                            width: 320,
                            child: _buildProfileCard(authState, user, isDark),
                          ),
                          const SizedBox(width: 24),

                          // Right - Settings
                          Expanded(
                            child: Column(
                              children: [
                                _buildSection(
                                  'Profile Information',
                                  Icons.person_outline,
                                  _buildProfileSection(user, isDark),
                                  isDark,
                                ),
                                const SizedBox(height: 20),
                                _buildSection(
                                  'Security',
                                  Icons.lock_outline,
                                  _buildSecuritySection(isDark),
                                  isDark,
                                ),
                                const SizedBox(height: 20),
                                _buildSection(
                                  'Account',
                                  Icons.info_outline,
                                  _buildAccountSection(user, isDark),
                                  isDark,
                                ),
                                const SizedBox(height: 20),
                                _buildSection(
                                  'Appearance',
                                  Icons.palette_outlined,
                                  _buildAppearanceSection(),
                                  isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(AuthState authState, dynamic user, bool isDark) {
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final avatarBg = isDark ? Colors.grey.shade300 : Colors.black;
    final avatarText = isDark ? Colors.black : Colors.white;
    final cameraBg = isDark ? Colors.grey.shade300 : Colors.black;
    final cameraIcon = isDark ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: avatarBg,
                backgroundImage: _selectedImagePath != null
                    ? FileImage(File(_selectedImagePath!))
                    : (user?.profilePictureUrl != null
                          ? NetworkImage(
                              '${ApiConfig.baseUrl}${user.profilePictureUrl}',
                            )
                          : null),
                child:
                    (_selectedImagePath == null &&
                        user?.profilePictureUrl == null)
                    ? Text(
                        authState.userInitial,
                        style: TextStyle(
                          fontSize: 48,
                          color: avatarText,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (_isUploadingImage)
                const Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: cameraBg,
                  shape: CircleBorder(
                    side: BorderSide(color: cardBg, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _isUploadingImage ? null : _handlePickImage,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: cameraIcon,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Divider(color: dividerColor),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text(
                  user?.isVerified == true ? 'Verified' : 'Unverified',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child, bool isDark) {
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final iconBg = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final iconColor = isDark ? Colors.grey.shade300 : Colors.black87;
    final textPrimary = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildProfileSection(dynamic user, bool isDark) {
    if (!_isEditingProfile) {
      return Column(
        children: [
          _buildInfoRow('First Name', user?.firstName ?? '-', isDark),
          _buildInfoRow('Last Name', user?.lastName ?? '-', isDark),
          _buildInfoRow('Email', user?.email ?? '-', isDark),
          const SizedBox(height: 16),
          if (user?.googleId == null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _isEditingProfile = true),
                icon: Icon(
                  Icons.edit,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
                label: Text(
                  'Edit Profile',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  side: BorderSide(
                    color: isDark ? Colors.grey.shade600 : Colors.black,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        AppTextField(
          controller: _firstNameController,
          hint: 'First Name',
          errorText: _firstNameError,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _lastNameController,
          hint: 'Last Name',
          errorText: _lastNameError,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSavingProfile
                    ? null
                    : () {
                        setState(() {
                          _isEditingProfile = false;
                          _firstNameController.text = user?.firstName ?? '';
                          _lastNameController.text = user?.lastName ?? '';
                        });
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSavingProfile ? null : _handleSaveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentStrong,
                  foregroundColor: AppColors.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSavingProfile
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecuritySection(bool isDark) {
    final buttonBg = AppColors.accentStrong;
    final buttonText = AppColors.onAccent;

    return Column(
      children: [
        AppTextField(
          controller: _currentPasswordController,
          hint: 'Current Password',
          isPassword: true,
          errorText: _currentPasswordError,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _newPasswordController,
          hint: 'New Password',
          isPassword: true,
          errorText: _newPasswordError,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _confirmPasswordController,
          hint: 'Confirm Password',
          isPassword: true,
          errorText: _confirmPasswordError,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isChangingPassword ? null : _handleChangePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonText,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isChangingPassword
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: buttonText,
                    ),
                  )
                : Text('Update Password', style: TextStyle(color: buttonText)),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(dynamic user, bool isDark) {
    return Column(
      children: [
        _buildInfoRow(
          'Account Type',
          user?.googleId != null ? 'Google' : 'Email',
          isDark,
        ),
        _buildInfoRow(
          'Verification',
          user?.isVerified == true ? 'Verified' : 'Pending',
          isDark,
        ),
        _buildInfoRow(
          'Member Since',
          _formatDate(user?.createdAt?.toIso8601String()),
          isDark,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final valueBg = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    final valueColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: valueBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: valueColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '-';
    }
  }

  Widget _buildAppearanceSection() {
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.isDark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: isDark ? Colors.black : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark
                          ? 'Currently using dark theme'
                          : 'Currently using light theme',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDark,
                onChanged: (_) =>
                    ref.read(themeProvider.notifier).toggleTheme(),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.accentColor,
                inactiveThumbColor: Colors.black,
                inactiveTrackColor: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
