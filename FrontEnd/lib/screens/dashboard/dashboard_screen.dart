import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/upload_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/nav_provider.dart';
import '../../widgets/common/pressable.dart';
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
      await ref
          .read(uploadNotifierProvider.notifier)
          .uploadAndTranscribe(
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
    final isDark = ref.watch(themeProvider).isDark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          _buildHeader(authState, isDark),
          const SizedBox(height: AppSizes.xl),

          // Main Content — side-by-side on wide content areas, stacked when narrow
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUploadSection(isDark),
                    const SizedBox(height: AppSizes.lg),
                    _buildStatusSection(isDark),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left - Upload Section
                  Expanded(flex: 6, child: _buildUploadSection(isDark)),
                  const SizedBox(width: AppSizes.lg),

                  // Right - Status Section
                  Expanded(flex: 4, child: _buildStatusSection(isDark)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthState authState, bool isDark) {
    // Dynamic greeting based on time
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17) {
      greeting = 'Good Evening';
    }

    // Get first name
    final firstName = authState.userName.trim().split(' ').first;

    // Theme-aware colors
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

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
            color: cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey).withValues(
                  alpha: 0.1,
                ),
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
                '$greeting, $firstName!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                AppStrings.welcomeBack,
                style: TextStyle(
                  color: textSecondary,
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
              icon: isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
              isDark: isDark,
            ),
            const SizedBox(width: AppSizes.md),
            _IconButton(
              icon: Icons.help_outline,
              tooltip: 'Help & guide',
              isDark: isDark,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Guide to Use'),
                    content: const Text(
                      'Welcome to RomaSub.AI!\n\n'
                      '1. Click "Choose File" to upload a video or audio.\n'
                      '2. Wait for the transcription and translation to complete.\n'
                      '3. Download your SRT subtitle file.\n\n'
                      'Need more help? Visit the Feedback section.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: AppSizes.md),
            _ProfilePicture(authState: authState),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadSection(bool isDark) {
    // Theme-aware colors
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final accentBg = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final buttonBg = AppColors.accentStrong;
    final buttonText = AppColors.onAccent;
    final borderColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.welcomeTitle,
          style: TextStyle(
            fontSize: AppSizes.fontXxl,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          AppStrings.welcomeDesc,
          style: TextStyle(
            fontSize: AppSizes.fontSm,
            color: textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSizes.lg),

        // Upload Box with dashed border
        CustomPaint(
          painter: DashedBorderPainter(
            color: borderColor,
            strokeWidth: 2,
            dashWidth: 8,
            dashSpace: 6,
            borderRadius: AppSizes.radiusLg,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.xxl),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  decoration: BoxDecoration(
                    color: accentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.upload_outlined,
                    size: AppSizes.iconXl,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Text(
                  AppStrings.uploadTitle,
                  style: TextStyle(
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  AppStrings.uploadDesc,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: AppSizes.fontSm,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.lg),
                ElevatedButton(
                  onPressed: _handleFilePicker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBg,
                    foregroundColor: buttonText,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.xl,
                      vertical: AppSizes.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  child: Text(
                    AppStrings.chooseFile,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppSizes.fontMd,
                      color: buttonText,
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

  Widget _buildStatusSection(bool isDark) {
    // Theme-aware colors
    final cardBg = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.1),
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
            AppStrings.processingStatus,
            style: TextStyle(
              fontSize: AppSizes.fontLg,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          _StatusItem(
            label: AppStrings.audioTranscription,
            status: AppStrings.ready,
            isOnline: true,
            isDark: isDark,
          ),
          const SizedBox(height: AppSizes.lg),
          _StatusItem(
            label: AppStrings.romanUrduTranslation,
            status: AppStrings.ready,
            isOnline: true,
            isDark: isDark,
          ),
          const SizedBox(height: AppSizes.lg),
          _StatusItem(
            label: AppStrings.aiModelStatus,
            status: AppStrings.online,
            isOnline: true,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final String? tooltip;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.isDark = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2A2A2A) : AppColors.surface;
    final iconColor = isDark ? Colors.white : AppColors.textPrimary;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.03);

    final button = Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(child: Icon(icon, color: iconColor, size: 22)),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String status;
  final bool isOnline;
  final bool isDark;

  const _StatusItem({
    required this.label,
    required this.status,
    required this.isOnline,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on status
    Color backgroundColor;
    Color textColor;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    if (isOnline) {
      backgroundColor = Colors.green.withValues(alpha: 0.15);
      textColor = Colors.green;
    } else {
      backgroundColor = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
      textColor = isDark ? Colors.white : Colors.black;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: labelColor, fontSize: AppSizes.fontMd),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePicture extends ConsumerWidget {
  final AuthState authState;

  const _ProfilePicture({required this.authState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = authState.user;
    final hasProfilePicture =
        user?.profilePictureUrl != null && user!.profilePictureUrl!.isNotEmpty;

    return InkWell(
      // Switch to the Settings tab in the shell (both screens stay alive).
      onTap: () =>
          ref.read(navIndexProvider.notifier).state = AppTab.settings.index,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: hasProfilePicture ? null : Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 2),
          image: hasProfilePicture
              ? DecorationImage(
                  image: NetworkImage(
                    '${ApiConfig.baseUrl}${user.profilePictureUrl}',
                  ),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: hasProfilePicture
            ? null
            : Center(
                child: Text(
                  authState.userInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
      ),
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
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

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
