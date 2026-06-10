import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/doctor/doctor_dashboard_screen.dart';
import '../test_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Drains any FlutterErrors recorded during the pump without asserting on
/// them. Used after the initial pump of [DoctorDashboardScreen] to discard
/// the already-documented home-screen footer overflow before navigating
/// into a section tab, so that section-specific overflows can be detected
/// in isolation.
void _drainExceptions(WidgetTester tester) {
  for (var i = 0; i < 20; i++) {
    if (tester.takeException() == null) return;
  }
}

/// Asserts none of the exceptions recorded since the last drain are
/// RenderFlex overflow errors (other framework warnings are not part of
/// this audit and are intentionally ignored here).
void _expectNoOverflow(WidgetTester tester) {
  for (var i = 0; i < 10; i++) {
    final exception = tester.takeException();
    if (exception == null) return;
    expect(exception.toString(), isNot(contains('RenderFlex overflowed')),
        reason: 'Unexpected RenderFlex overflow: $exception');
  }
}

void main() {
  testWidgets('Doctor > Schedule tab renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen());
    _drainExceptions(tester);

    await tester.tap(find.text('Schedule'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });

  testWidgets('Doctor > Documentation tab renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen());
    _drainExceptions(tester);

    await tester.tap(find.text('Documentation'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });

  testWidgets('Doctor > My Patients tab renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen());
    _drainExceptions(tester);

    await tester.tap(find.text('My Patients'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });

  testWidgets('Doctor > My Profile tab renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen());
    _drainExceptions(tester);

    await tester.tap(find.text('My Profile'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });

  testWidgets('Doctor > Notifications tab renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen());
    _drainExceptions(tester);

    await tester.tap(find.text('Notifications'));
    await _settle(tester);
    _expectNoOverflow(tester);
  });
}
