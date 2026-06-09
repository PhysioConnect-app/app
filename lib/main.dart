import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/providers/language_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/doctor/doctor_dashboard_screen.dart';
import 'features/patient/patient_dashboard_screen.dart';
import 'features/polyclinic/polyclinic_dashboard_screen.dart';
import 'features/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  if (!Platform.isWindows) await NotificationService.initialize();
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
          surface: AppColors.surface,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
        ),
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
                if (role == 'admin') return const _WithNotificationPrompt(child: AdminDashboardScreen());
                if (role == 'doctor') return const _WithNotificationPrompt(child: DoctorDashboardScreen());
                if (role == 'polyclinic') return const _WithNotificationPrompt(child: PolyclinicDashboardScreen());
                if (role == 'patient') return const _WithNotificationPrompt(child: PatientDashboardScreen());
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
    if (!Platform.isWindows) {
      Future.delayed(const Duration(seconds: 3), _promptIfNeeded);
    }
  }

  Future<void> _promptIfNeeded() async {
    if (!mounted) return;
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    await NotificationService.requestPermissionsWithExplanation(context, s);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
