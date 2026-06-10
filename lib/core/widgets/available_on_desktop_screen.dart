import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../providers/language_provider.dart';

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

  Future<void> _showLogout(BuildContext context, AppStrings s) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.logout),
        content: Text(s.areYouSure),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
            },
            child: Text(s.signOut,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(feature),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: s.logout,
            onPressed: () => _showLogout(context, s),
          ),
        ],
      ),
      body: AvailableOnDesktopNotice(feature: feature),
    );
  }
}
