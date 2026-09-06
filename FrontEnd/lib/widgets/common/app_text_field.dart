import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool isPassword;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool isDark;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.isPassword = false,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.isDark = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final bgColor = AppColors.getCard(widget.isDark);
    final borderColor = widget.isDark
        ? Colors.grey.shade700
        : Colors.grey.shade300;
    final textColor = AppColors.getPrimary(widget.isDark);
    final hintColor = widget.isDark
        ? Colors.grey.shade500
        : Colors.grey.shade500;
    final iconColor = widget.isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: widget.errorText != null ? Colors.red : borderColor,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: widget.isPassword && _obscure,
            onChanged: widget.onChanged,
            keyboardType: widget.keyboardType,
            style: TextStyle(color: textColor, fontSize: AppSizes.fontSm),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: hintColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.md,
              ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: iconColor,
                        size: AppSizes.iconSm,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : null,
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.xs, left: AppSizes.xs),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: AppSizes.fontXs,
              ),
            ),
          ),
      ],
    );
  }
}
