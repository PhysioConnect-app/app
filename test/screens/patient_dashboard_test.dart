import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/patient/patient_dashboard_screen.dart';
import '../test_harness.dart';

void main() {
  testWidgets('PatientDashboardScreen renders without overflow at 390x844', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen());
    expect(find.byType(PatientDashboardScreen), findsOneWidget);
  });
}
