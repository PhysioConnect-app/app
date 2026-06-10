import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/auth/login_screen.dart';
import '../test_harness.dart';

void main() {
  testWidgets('LoginScreen renders without overflow at 390x844', (tester) async {
    await ensureSupabaseInitialized();
    await pumpAtSize(tester, const LoginScreen());
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
