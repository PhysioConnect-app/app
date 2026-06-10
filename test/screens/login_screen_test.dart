import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/core/constants/app_strings.dart';
import 'package:clinic_telehealth_app/features/auth/login_screen.dart';
import 'package:clinic_telehealth_app/features/patient/find_doctors_screen.dart';
import '../test_harness.dart';

void main() {
  testWidgets('LoginScreen renders without overflow at 390x844', (tester) async {
    await ensureSupabaseInitialized();
    await pumpAtSize(tester, const LoginScreen());
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'LoginScreen shows Continue as Guest at mobile width and opens Find a Therapist',
      (tester) async {
    await ensureSupabaseInitialized();
    await pumpAtSize(tester, const LoginScreen());

    const s = AppStrings(false);
    expect(find.text(s.continueAsGuest), findsOneWidget);

    await tester.tap(find.text(s.continueAsGuest));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FindDoctorsScreen), findsOneWidget);
  });

  testWidgets('LoginScreen hides Continue as Guest at desktop width', (tester) async {
    await ensureSupabaseInitialized();
    await pumpAtSize(tester, const LoginScreen(), size: desktopSize);

    const s = AppStrings(false);
    expect(find.text(s.continueAsGuest), findsNothing);
  });
}
