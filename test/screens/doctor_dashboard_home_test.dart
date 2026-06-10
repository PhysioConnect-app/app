import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/doctor/doctor_dashboard_screen.dart';
import '../test_harness.dart';

void main() {
  testWidgets('DoctorDashboardScreen home renders without overflow at 390x844', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen());
    expect(find.byType(DoctorDashboardScreen), findsOneWidget);
  });
}
