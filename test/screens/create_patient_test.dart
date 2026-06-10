import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/doctor/create_patient_screen.dart';
import '../test_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _expectNoOverflow(WidgetTester tester) {
  for (var i = 0; i < 10; i++) {
    final exception = tester.takeException();
    if (exception == null) return;
    expect(exception.toString(), isNot(contains('RenderFlex overflowed')),
        reason: 'Unexpected RenderFlex overflow: $exception');
  }
}

void main() {
  testWidgets('CreatePatientScreen renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const CreatePatientScreen());
    await _settle(tester);
    _expectNoOverflow(tester);
  });
}
