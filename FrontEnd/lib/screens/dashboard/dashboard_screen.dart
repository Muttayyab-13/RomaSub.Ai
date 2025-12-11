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
            horizontal: AppSizes.xl,
            vertical: AppSizes.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppStrings.hello} $userName!',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              const Text(
                AppStrings.welcomeBack,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppSizes.fontMd,
                ),
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
            const SizedBox(width: AppSizes.md),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.fontLg,
                  ),
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

        // Upload Box with dashed border
        CustomPaint(
          painter: DashedBorderPainter(
            color: AppColors.accent,
            strokeWidth: 2,
            dashWidth: 8,
            dashSpace: 6,
            borderRadius: AppSizes.radiusLg,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
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
                    Icons.upload_outlined,
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
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppSizes.fontSm,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.lg),
                ElevatedButton(
                  onPressed: _handleFilePicker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.xl,
                      vertical: AppSizes.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  child: const Text(
                    AppStrings.chooseFile,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppSizes.fontMd,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: 0,
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
          const SizedBox(height: AppSizes.xl),
          _StatusItem(
            label: AppStrings.audioTranscription,
            status: AppStrings.ready,
            isOnline: false,
          ),
          const SizedBox(height: AppSizes.lg),
          _StatusItem(
            label: AppStrings.romanUrduTranslation,
            status: AppStrings.ready,
            isOnline: false,
          ),
          const SizedBox(height: AppSizes.lg),
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 22),
            if (hasBadge)
              Positioned(
                right: 10,
                top: 10,
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppSizes.fontMd,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          decoration: BoxDecoration(
            color: isOnline ? AppColors.success.withOpacity(0.15) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w600,
              color: isOnline ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final dashedPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashWidth : dashSpace;
        if (distance + length > metric.length) {
          if (draw) {
            dashedPath.addPath(
              metric.extractPath(distance, metric.length),
              Offset.zero,
            );
          }
          break;
        } else {
          if (draw) {
            dashedPath.addPath(
              metric.extractPath(distance, distance + length),
              Offset.zero,
            );
          }
          distance += length;
          draw = !draw;
        }
      }
    }
    return dashedPath;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
