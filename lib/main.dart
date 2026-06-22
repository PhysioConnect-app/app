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

  @override
  Widget build(BuildContext context) => widget.child;
}
