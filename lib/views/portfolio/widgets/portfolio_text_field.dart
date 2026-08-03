import 'package:flutter/material.dart';
import 'package:campusconnect/theme/app_theme.dart';

/// CampusConnect v8.4 — Shared text form field for portfolio forms.
///
/// Matches the CreateOpportunityView input style (label on top, filled
/// field, outlined border, primary-blue focus border).
class PortfolioTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isDark;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;

  const PortfolioTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.isDark,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.bodyMedium.copyWith(
              color: isDark ? AppTheme.gray400 : AppTheme.gray500,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppTheme.gray600 : AppTheme.gray300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppTheme.gray600 : AppTheme.gray300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.error, width: 1),
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkBackground : AppTheme.gray50,
            contentPadding: const EdgeInsets.all(14),
          ),
          style: AppTheme.bodyMedium.copyWith(
            color: isDark ? Colors.white : AppTheme.gray900,
          ),
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
        ),
      ],
    );
  }
}
