import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Improved Transcription Complete Dialog
/// Follows HCI principles and RomaSub.AI design system
class TranscriptionCompleteDialog extends StatefulWidget {
  final String filename;
  final String duration;
  final int segmentCount;
  final String language;
  final String previewText;
  final VoidCallback onDownload;
  final VoidCallback onViewDetails;
  final VoidCallback onEdit;

  const TranscriptionCompleteDialog({
    Key? key,
    required this.filename,
    required this.duration,
    required this.segmentCount,
    required this.language,
    required this.previewText,
    required this.onDownload,
    required this.onViewDetails,
    required this.onEdit,
  }) : super(key: key);

  /// Show this dialog
  static Future<void> show(
    BuildContext context, {
    required String filename,
    required String duration,
    required int segmentCount,
    required String language,
    required String previewText,
    required VoidCallback onDownload,
    required VoidCallback onViewDetails,
    required VoidCallback onEdit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TranscriptionCompleteDialog(
        filename: filename,
        duration: duration,
        segmentCount: segmentCount,
        language: language,
        previewText: previewText,
        onDownload: onDownload,
        onViewDetails: onViewDetails,
        onEdit: onEdit,
      ),
    );
  }

  @override
  State<TranscriptionCompleteDialog> createState() =>
      _TranscriptionCompleteDialogState();
}

class _TranscriptionCompleteDialogState
    extends State<TranscriptionCompleteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _checkAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: EdgeInsets.all(AppSizes.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSuccessIcon(),
              SizedBox(height: AppSizes.lg),
              _buildTitle(),
              SizedBox(height: AppSizes.lg),
              _buildInfoCard(),
              SizedBox(height: AppSizes.lg),
              _buildPreviewSection(),
              SizedBox(height: AppSizes.lg),
              _buildActionButtons(),
              SizedBox(height: AppSizes.md),
              _buildCloseButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF34D399)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FadeTransition(
          opacity: _checkAnimation,
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Transcription Complete!',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F2937),
        letterSpacing: -0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppSizes.md),
      child: Column(
        children: [
          _buildInfoRow('📄', 'File:', widget.filename, isFilename: true),
          _buildDivider(),
          _buildInfoRow('⏱️', 'Duration:', widget.duration),
          _buildDivider(),
          _buildInfoRow(
              '📝', 'Segments:', '${widget.segmentCount} subtitles'),
          _buildDivider(),
          _buildInfoRow('🗣️', 'Language:', widget.language),
          _buildDivider(),
          _buildInfoRow('✅', 'Status:', '', showBadge: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String icon,
    String label,
    String value, {
    bool isFilename = false,
    bool showBadge = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          SizedBox(width: AppSizes.sm),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          if (showBadge)
            _buildStatusBadge()
          else
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isFilename ? FontWeight.w600 : FontWeight.w500,
                  color: const Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '● Ready',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: const Color(0xFFE5E7EB),
      height: AppSizes.sm,
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preview:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: AppSizes.xs),
        Container(
          constraints: const BoxConstraints(maxHeight: 100),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          padding: EdgeInsets.all(AppSizes.md),
          child: SingleChildScrollView(
            child: Text(
              widget.previewText,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1F2937),
                height: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Stack vertically on small screens
        if (constraints.maxWidth < 500) {
          return Column(
            children: [
              _buildActionButton(
                icon: Icons.download_rounded,
                label: 'Download SRT',
                color: const Color(0xFF10B981),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDownload();
                },
              ),
              SizedBox(height: AppSizes.sm),
              _buildActionButton(
                icon: Icons.visibility_rounded,
                label: 'View Details',
                color: AppColors.accent,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onViewDetails();
                },
              ),
              SizedBox(height: AppSizes.sm),
              _buildActionButton(
                icon: Icons.edit_rounded,
                label: 'Edit Subtitles',
                color: Colors.white,
                textColor: const Color(0xFF374151),
                borderColor: const Color(0xFFE5E7EB),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onEdit();
                },
              ),
            ],
          );
        }

        // Horizontal row on larger screens
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.download_rounded,
                label: 'Download SRT',
                color: const Color(0xFF10B981),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDownload();
                },
              ),
            ),
            SizedBox(width: AppSizes.sm),
            Expanded(
              child: _buildActionButton(
                icon: Icons.visibility_rounded,
                label: 'View Details',
                color: AppColors.accent,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onViewDetails();
                },
              ),
            ),
            SizedBox(width: AppSizes.sm),
            Expanded(
              child: _buildActionButton(
                icon: Icons.edit_rounded,
                label: 'Edit Subtitles',
                color: Colors.white,
                textColor: const Color(0xFF374151),
                borderColor: const Color(0xFFE5E7EB),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onEdit();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color textColor = Colors.white,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    final isWhiteBackground = color == Colors.white;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          decoration: BoxDecoration(
            border: borderColor != null
                ? Border.all(color: borderColor)
                : null,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            boxShadow: isWhiteBackground
                ? null
                : [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: EdgeInsets.symmetric(
            vertical: AppSizes.sm,
            horizontal: AppSizes.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: textColor,
                size: 24,
              ),
              SizedBox(height: AppSizes.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.xl,
          vertical: AppSizes.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        foregroundColor: const Color(0xFF6B7280),
      ),
      child: const Text(
        'Close',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
