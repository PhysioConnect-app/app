import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/config/supabase_config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/providers/language_provider.dart';
import 'core/services/pwa_install_service.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/doctor/doctor_dashboard_screen.dart';
import 'features/patient/patient_dashboard_screen.dart';
import 'features/store/store_manager_dashboard_screen.dart';
import 'features/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');
  await initializeDateFormatting('ar');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  if (!kIsWeb && !Platform.isWindows) await NotificationService.initialize();
  if (kIsWeb) PwaInstallService.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: const MyClinicApp(),
    ),
  );
}

class MyClinicApp extends StatelessWidget {
  const MyClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LanguageProvider>().isArabic;
    return MaterialApp(
      title: 'PhysioConnect',
      debugShowCheckedModeBanner: false,
      locale: isArabic ? const Locale('ar') : const Locale('en'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.error,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Inter — clean, professional, excellent legibility for clinical use
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        // Propagate Inter to all Material components
        primaryTextTheme: GoogleFonts.interTextTheme(ThemeData.light().primaryTextTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          color: Colors.white,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF0F9F7),
          selectedColor: AppColors.primary,
          labelStyle: GoogleFonts.inter(fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.cardBorder,
          thickness: 1,
          space: 1,
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: Supabase.instance.client
                .from('users')
                .select()
                .eq('id', session.user.id)
                .maybeSingle(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (roleSnapshot.hasError) {
                Supabase.instance.client.auth.signOut();
                return const LoginScreen();
              }
              final userData = roleSnapshot.data;
              if (userData != null) {
                final role = (userData['role'] as String?) ?? '';
                if (role == 'admin') {
                  return const _WithNotificationPrompt(child: AdminDashboardScreen());
                }
                if (role == 'doctor') return const _WithNotificationPrompt(child: DoctorDashboardScreen());
if (role == 'patient') return const _WithNotificationPrompt(child: PatientDashboardScreen());
                if (role == 'store_manager') return const StoreManagerDashboardScreen();
              }
              return const LoginScreen();
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

/// Triggers the notification permission rationale dialog once per session,
/// a few seconds after the user lands on a dashboard.
class _WithNotificationPrompt extends StatefulWidget {
  final Widget child;
  const _WithNotificationPrompt({required this.child});

  @override
  State<_WithNotificationPrompt> createState() => _WithNotificationPromptState();
}

class _WithNotificationPromptState extends State<_WithNotificationPrompt> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && !Platform.isWindows) {
      Future.delayed(const Duration(seconds: 3), _promptIfNeeded);
    }
    if (!kIsWeb && Platform.isWindows) {
      Future.delayed(const Duration(seconds: 4), _showPinTipIfNeeded);
    }
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 5), _checkPwaInstall);
    }
  }

  Future<void> _promptIfNeeded() async {
    if (!mounted) return;
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    await NotificationService.requestPermissionsWithExplanation(context, s);
  }

  Future<void> _showPinTipIfNeeded() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    const key = 'win_pin_tip_shown';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Tip: Right-click PhysioConnect in the Start menu → "Pin to taskbar" or "Pin to Start" for quick access.',
        ),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: 'Got it', onPressed: () {}),
      ),
    );
  }

  Future<void> _checkPwaInstall() async {
    if (!mounted || PwaInstallService.isInStandaloneMode) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final isArabic = context.read<LanguageProvider>().isArabic;

    if (PwaInstallService.isInstallAvailable) {
      final dismissed = prefs.getBool('pwa_install_dismissed') ?? false;
      if (dismissed || !mounted) return;
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          content: Text(
            isArabic
                ? 'ثبّت PhysioConnect للوصول السريع بدون متصفح'
                : 'Install PhysioConnect for quick offline access',
          ),
          leading: const Icon(Icons.install_mobile, color: AppColors.primary),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                PwaInstallService.triggerInstallPrompt();
              },
              child: Text(
                isArabic ? 'تثبيت' : 'Install',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                await prefs.setBool('pwa_install_dismissed', true);
              },
              child: Text(
                isArabic ? 'لاحقاً' : 'Later',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    } else if (PwaInstallService.isIosSafari) {
      final shown = prefs.getBool('pwa_ios_hint_shown') ?? false;
      if (shown || !mounted) return;
      await prefs.setBool('pwa_ios_hint_shown', true);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _IosInstallHint(isArabic: isArabic),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── iOS "Add to Home Screen" hint ────────────────────────────────────────────

class _IosInstallHint extends StatelessWidget {
  final bool isArabic;
  const _IosInstallHint({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.install_mobile, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                isArabic
                    ? 'أضف PhysioConnect إلى شاشة البداية'
                    : 'Add PhysioConnect to your Home Screen',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'وصول بنقرة واحدة — يعمل حتى بدون إنترنت'
                    : 'One-tap access — works even offline',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _IosStep(
                n: '1',
                icon: Icons.ios_share,
                isArabic: isArabic,
                text: isArabic
                    ? 'اضغط أيقونة المشاركة في شريط Safari'
                    : "Tap the Share icon in Safari's toolbar",
              ),
              _IosStep(
                n: '2',
                icon: Icons.add_box_outlined,
                isArabic: isArabic,
                text: isArabic
                    ? 'اختر «إضافة إلى الشاشة الرئيسية»'
                    : '"Add to Home Screen"',
              ),
              _IosStep(
                n: '3',
                icon: Icons.check_circle_outline,
                isArabic: isArabic,
                text: isArabic
                    ? 'اضغط «إضافة» في الزاوية العليا'
                    : 'Tap "Add" in the top-right corner',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isArabic ? 'حسناً، شكراً' : 'Got it, thanks'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosStep extends StatelessWidget {
  final String n;
  final IconData icon;
  final String text;
  final bool isArabic;
  const _IosStep(
      {required this.n,
      required this.icon,
      required this.text,
      required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(n,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
