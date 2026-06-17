import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/admin/admin_dashboard_screen.dart';
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
  testWidgets('AdminDashboardScreen renders without overflow at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const AdminDashboardScreen());
    await _settle(tester);
    _expectNoOverflow(tester);
  });

  testWidgets('AdminDashboardScreen nav buttons switch sections at 390x844',
      (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const AdminDashboardScreen());
    await _settle(tester);
    _expectNoOverflow(tester);

    for (final label in [
      'Doctors',
      'Polyclinics',
      'Register',
      'Requests',
      'Overview',
    ]) {
      await tester.ensureVisible(find.text(label));
      await _settle(tester);
      await tester.tap(find.text(label));
      await _settle(tester);
      _expectNoOverflow(tester);
    }
  });
}
