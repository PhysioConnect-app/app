import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/patient/patient_dashboard_screen.dart';
import '../test_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Drains any FlutterErrors recorded during the pump and asserts none of
/// them are RenderFlex overflow errors (other framework warnings, e.g.
/// pre-existing ListTile ink-splash issues, are not part of this audit and
/// are intentionally ignored here).
void _expectNoOverflow(WidgetTester tester) {
  for (var i = 0; i < 10; i++) {
    final exception = tester.takeException();
    if (exception == null) return;
    expect(exception.toString(), isNot(contains('RenderFlex overflowed')),
        reason: 'Unexpected RenderFlex overflow: $exception');
  }
}

void main() {
  testWidgets('Patient > My Appointments (schedule) renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen());

    await tester.tap(find.text('My Appointments'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });

  testWidgets('Patient > My Doctors/Therapists renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen());

    await tester.tap(find.text('My Doctors/Therapists'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });

  testWidgets('Patient > Notifications renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen());

    await tester.tap(find.text('Notifications'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });

  testWidgets('Patient > My Profile renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen());

    await tester.tap(find.text('My Profile'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });
}
