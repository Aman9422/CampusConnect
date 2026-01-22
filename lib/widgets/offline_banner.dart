import 'package:campusconnect/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// V5.1 / v6.0: Offline awareness banner
/// Shows a polished banner when network is unavailable
class OfflineBanner extends StatelessWidget {
  final bool isOffline;

  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      decoration: AppTheme.bannerDecoration(AppTheme.warningBg),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: AppTheme.warning),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              'You\'re offline. Some features may be unavailable.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.gray800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
