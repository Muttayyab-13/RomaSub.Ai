import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/upload_provider.dart';
import '../../widgets/sidebar/sidebar.dart';
import '../../widgets/dialogs/upload_progress_dialog.dart';
import '../../services/api/api_config.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Handle file picker and start upload process
  Future<void> _handleFilePicker() async {
    try {
      // Pick file with allowed extensions
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ApiConfig.allowedExtensions,
        allowMultiple: false,
      );

      // Check if user cancelled
      if (result == null || result.files.isEmpty) {
        return;
      }

      // Get file path
      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to access file path'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Show upload progress dialog
      if (mounted) {
        showUploadProgressDialog(context);
      }

      // Start upload and transcription
      await ref.read(uploadNotifierProvider.notifier).uploadAndTranscribe(
            filePath,
            language: 'ur', // Urdu language
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File picker error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const Sidebar(currentRoute: AppRoutes.dashboard),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  _buildHeader(authState.userName),
                  const SizedBox(height: AppSizes.xl),

                  // Main Content
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left - Upload Section
                      Expanded(
                        flex: 6,
                        child: _buildUploadSection(),
                      ),
                      const SizedBox(width: AppSizes.lg),

                      // Right - Status Section
                      Expanded(
                        flex: 4,
                        child: _buildStatusSection(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Greeting Card
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppStrings.hello} $userName!',
                style: const TextStyle(
                  fontSize: AppSizes.fontXl,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              const Text(
                AppStrings.welcomeBack,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        // Icons
        Row(
          children: [
            _IconButton(
              icon: Icons.notifications_outlined,
              hasBadge: true,
              onTap: () {},
            ),
            const SizedBox(width: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: AppSizes.fontMd,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.welcomeTitle,
          style: TextStyle(
            fontSize: AppSizes.fontXxl,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        const Text(
          AppStrings.welcomeDesc,
          style: TextStyle(
            fontSize: AppSizes.fontSm,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        // Upload Box
        Container(
          padding: const EdgeInsets.all(AppSizes.xxl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: AppSizes.iconXl,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              const Text(
                AppStrings.uploadTitle,
                style: TextStyle(
                  fontSize: AppSizes.fontLg,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              const Text(
                AppStrings.uploadDesc,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.lg),
              SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: _handleFilePicker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                  ),
                  child: const Text(AppStrings.chooseFile),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.processingStatus,
            style: TextStyle(
              fontSize: AppSizes.fontLg,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          _StatusItem(
            label: AppStrings.audioTranscription,
            status: AppStrings.ready,
            isOnline: false,
          ),
          const SizedBox(height: AppSizes.md),
          _StatusItem(
            label: AppStrings.romanUrduTranslation,
            status: AppStrings.ready,
            isOnline: false,
          ),
          const SizedBox(height: AppSizes.md),
          _StatusItem(
            label: AppStrings.aiModelStatus,
            status: AppStrings.online,
            isOnline: true,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final bool hasBadge;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    this.hasBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            Icon(icon, color: AppColors.textPrimary),
            if (hasBadge)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String status;
  final bool isOnline;

  const _StatusItem({
    required this.label,
    required this.status,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.xs,
          ),
          decoration: BoxDecoration(
            color: isOnline ? AppColors.success.withOpacity(0.1) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: AppSizes.fontXs,
              fontWeight: FontWeight.w600,
              color: isOnline ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
