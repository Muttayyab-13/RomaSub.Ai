import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sidebar/sidebar.dart';
import '../../widgets/common/app_text_field.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Profile fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _firstNameError;
  String? _lastNameError;
  bool _isEditingProfile = false;
  bool _isSavingProfile = false;

  // Password fields
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  bool _isChangingPassword = false;

  // Profile picture
  String? _selectedImagePath;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // Initialize profile fields with current user data
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

      final success = await ref.read(authNotifierProvider.notifier).updateProfile(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _isSavingProfile = false;
          _isEditingProfile = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.profileUpdated),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final error = ref.read(authNotifierProvider).error;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _handleChangePassword() async {
    setState(() {
      _currentPasswordError = Validators.password(_currentPasswordController.text);
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

      final success = await ref.read(authNotifierProvider.notifier).changePassword(
            _currentPasswordController.text,
            _newPasswordController.text,
          );

      if (mounted) {
        setState(() => _isChangingPassword = false);

        if (success) {
          // Clear fields
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.passwordUpdated),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final error = ref.read(authNotifierProvider).error;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _handlePickImage() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImagePath = image.path;
          _isUploadingImage = true;
        });

        final success = await ref
            .read(authNotifierProvider.notifier)
            .uploadProfilePicture(image.path);

        if (mounted) {
          setState(() => _isUploadingImage = false);

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            setState(() => _selectedImagePath = null);
            final error = ref.read(authNotifierProvider).error;
            if (error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const Sidebar(currentRoute: AppRoutes.settings),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      AppStrings.settings,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSizes.xl),

                    // Profile Picture Section
                    _buildSection(
                      title: AppStrings.profilePicture,
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              _selectedImagePath != null
                                  ? CircleAvatar(
                                      radius: 50,
                                      backgroundImage: FileImage(File(_selectedImagePath!)),
                                    )
                                  : user?.profilePictureUrl != null
                                      ? CircleAvatar(
                                          radius: 50,
                                          backgroundImage: NetworkImage(
                                            '${ref.read(apiConfigProvider).baseUrl}${user!.profilePictureUrl}',
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 50,
                                          backgroundColor: AppColors.accent,
                                          child: Text(
                                            authState.userInitial,
                                            style: const TextStyle(
                                              fontSize: 40,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                              if (_isUploadingImage)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.md),
                          ElevatedButton.icon(
                            onPressed: _isUploadingImage ? null : _handlePickImage,
                            icon: const Icon(Icons.photo_camera),
                            label: const Text(AppStrings.changePhoto),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.lg),

                    // Profile Information Section
                    _buildSection(
                      title: AppStrings.profile,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isEditingProfile) ...[
                            _buildInfoRow(
                              label: AppStrings.firstName,
                              value: user?.firstName ?? '-',
                            ),
                            const SizedBox(height: AppSizes.md),
                            _buildInfoRow(
                              label: AppStrings.lastName,
                              value: user?.lastName ?? '-',
                            ),
                            const SizedBox(height: AppSizes.md),
                            _buildInfoRow(
                              label: AppStrings.email,
                              value: user?.email ?? '-',
                            ),
                            const SizedBox(height: AppSizes.lg),
                            if (user?.googleId == null) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() => _isEditingProfile = true);
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit Profile'),
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Google accounts cannot edit name directly.',
                                style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ] else ...[
                            // Edit mode
                            AppTextField(
                              controller: _firstNameController,
                              hint: AppStrings.firstName,
                              errorText: _firstNameError,
                              onChanged: (_) {
                                if (_firstNameError != null) {
                                  setState(() => _firstNameError =
                                      Validators.name(_firstNameController.text));
                                }
                              },
                            ),
                            const SizedBox(height: AppSizes.md),
                            AppTextField(
                              controller: _lastNameController,
                              hint: AppStrings.lastName,
                              errorText: _lastNameError,
                              onChanged: (_) {
                                if (_lastNameError != null) {
                                  setState(() => _lastNameError =
                                      Validators.name(_lastNameController.text));
                                }
                              },
                            ),
                            const SizedBox(height: AppSizes.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isSavingProfile
                                        ? null
                                        : () {
                                            setState(() {
                                              _isEditingProfile = false;
                                              // Reset to original values
                                              _firstNameController.text = user?.firstName ?? '';
                                              _lastNameController.text = user?.lastName ?? '';
                                            });
                                          },
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.md),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isSavingProfile ? null : _handleSaveProfile,
                                    child: _isSavingProfile
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(AppStrings.saveChanges),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.lg),

                    // Security Section - Change Password
                    _buildSection(
                      title: AppStrings.security,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.changePassword,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),

                          // Current Password
                          AppTextField(
                            controller: _currentPasswordController,
                            hint: AppStrings.currentPassword,
                            isPassword: true,
                            errorText: _currentPasswordError,
                            onChanged: (_) {
                              if (_currentPasswordError != null) {
                                setState(() => _currentPasswordError =
                                    Validators.password(_currentPasswordController.text));
                              }
                            },
                          ),
                          const SizedBox(height: AppSizes.md),

                          // New Password
                          AppTextField(
                            controller: _newPasswordController,
                            hint: AppStrings.newPassword,
                            isPassword: true,
                            errorText: _newPasswordError,
                            onChanged: (_) {
                              if (_newPasswordError != null) {
                                setState(() {
                                  _newPasswordError =
                                      Validators.password(_newPasswordController.text);
                                  // Also revalidate confirm password if it has an error
                                  if (_confirmPasswordError != null) {
                                    _confirmPasswordError = Validators.confirmPassword(
                                      _confirmPasswordController.text,
                                      _newPasswordController.text,
                                    );
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: AppSizes.md),

                          // Confirm Password
                          AppTextField(
                            controller: _confirmPasswordController,
                            hint: AppStrings.confirmPassword,
                            isPassword: true,
                            errorText: _confirmPasswordError,
                            onChanged: (_) {
                              if (_confirmPasswordError != null) {
                                setState(() {
                                  _confirmPasswordError = Validators.confirmPassword(
                                    _confirmPasswordController.text,
                                    _newPasswordController.text,
                                  );
                                });
                              }
                            },
                          ),
                          const SizedBox(height: AppSizes.lg),

                          // Update Password Button
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isChangingPassword ? null : _handleChangePassword,
                              child: _isChangingPassword
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(AppStrings.updatePassword),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.lg),

                    // Account Information Section
                    _buildSection(
                      title: AppStrings.accountInfo,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user?.googleId != null) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSizes.sm),
                                Text(
                                  AppStrings.googleAccount,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.md),
                          ],
                          Row(
                            children: [
                              Icon(
                                user?.isVerified == true
                                    ? Icons.verified_user
                                    : Icons.info_outline,
                                color: user?.isVerified == true
                                    ? AppColors.success
                                    : AppColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: AppSizes.sm),
                              Text(
                                user?.isVerified == true
                                    ? AppStrings.verified
                                    : AppStrings.notVerified,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// Provider to access API config
final apiConfigProvider = Provider((ref) {
  return _ApiConfig();
});

class _ApiConfig {
  // You should import the actual ApiConfig here
  final String baseUrl = 'http://localhost:8000'; // Or from ApiConfig.baseUrl
}
