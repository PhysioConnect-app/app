import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Inline notice shown in place of a desktop-only feature when the app is
/// running at a mobile-width viewport (e.g. behind [FormFactorFeatures]
/// gating, or via a deep link to a desktop-only screen).
class AvailableOnDesktopNotice extends StatelessWidget {
  final String feature;
  const AvailableOnDesktopNotice({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.desktop_windows_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 22),
            Text(feature,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            const Text(
              'Available on desktop',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen wrapper around [AvailableOnDesktopNotice], for use in place of
/// an entire desktop-only screen (e.g. the Admin dashboard on mobile).
class AvailableOnDesktopScreen extends StatelessWidget {
  final String feature;
  const AvailableOnDesktopScreen({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(feature),
      ),
      body: AvailableOnDesktopNotice(feature: feature),
    );
  }
}
