import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// CampusConnect v8.4 — Shared section card for portfolio screens.
///
/// Matches the existing card language used across the app
/// (white/dark card + 1px border + radiusMedium).
class PortfolioSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const PortfolioSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(AppTheme.space20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isDark ? AppTheme.gray700 : AppTheme.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trailing != null)
            Row(
              children: [
                Expanded(child: _buildTitle(context, isDark)),
                trailing!,
              ],
            )
          else
            _buildTitle(context, isDark),
          const SizedBox(height: AppTheme.space16),
          child,
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context, bool isDark) {
    return Text(
      title,
      style: AppTheme.titleMedium.copyWith(
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppTheme.gray900,
      ),
    );
  }
}

/// Shared read-only info row used by preview and read-only views.
class PortfolioInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;

  const PortfolioInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppTheme.space20, color: isDark ? AppTheme.gray400 : AppTheme.gray600),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.gray400 : AppTheme.gray600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.bodyMedium.copyWith(
                    color: isLink ? AppTheme.primaryBlue : (isDark ? Colors.white : AppTheme.gray900),
                    fontWeight: FontWeight.w500,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
