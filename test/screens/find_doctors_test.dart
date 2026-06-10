import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/patient/find_doctors_screen.dart';
import '../test_harness.dart';

void main() {
  testWidgets('FindDoctorsScreen renders without overflow at 390x844', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const FindDoctorsScreen());
    expect(find.byType(FindDoctorsScreen), findsOneWidget);
  });
}
