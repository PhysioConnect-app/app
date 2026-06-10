// Frozen desktop (1400x900) reference renders.
//
// These goldens are the baseline established BEFORE the mobile
// FormFactorFeatures rollout (gating, guest mode, mobile layouts). Every
// screen touched by that work must keep matching these images bit-for-bit.
// If any of these ever fails after a change, the desktop code path was
// accidentally altered — revert the change rather than re-recording the
// golden.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/features/auth/login_screen.dart';
import 'package:clinic_telehealth_app/features/patient/patient_dashboard_screen.dart';
import 'package:clinic_telehealth_app/features/patient/find_doctors_screen.dart';
import 'package:clinic_telehealth_app/features/doctor/doctor_dashboard_screen.dart';
import 'package:clinic_telehealth_app/features/doctor/soap_note_screen.dart';
import 'package:clinic_telehealth_app/features/doctor/billing_screen.dart';
import 'package:clinic_telehealth_app/features/doctor/expenses_screen.dart';
import 'package:clinic_telehealth_app/features/doctor/session_stats_screen.dart';
import 'package:clinic_telehealth_app/features/doctor/create_patient_screen.dart';
import 'package:clinic_telehealth_app/features/admin/admin_dashboard_screen.dart';
import 'package:clinic_telehealth_app/features/polyclinic/polyclinic_dashboard_screen.dart';
import '../test_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _drainExceptions(WidgetTester tester) {
  for (var i = 0; i < 20; i++) {
    if (tester.takeException() == null) return;
  }
}

Future<void> _golden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('desktop/$name.png'),
  );
}

void main() {
  testWidgets('Login screen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await pumpAtSize(tester, const LoginScreen(), size: desktopSize);
    _drainExceptions(tester);
    await _golden(tester, 'login_screen');
  });

  testWidgets('Patient dashboard home — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    // Pin the time-of-day greeting so this golden doesn't depend on the
    // wall-clock time the test happens to run at.
    patientDashboardClock = () => DateTime(2024, 1, 1, 9, 0);
    addTearDown(() => patientDashboardClock = DateTime.now);
    await pumpAtSize(tester, const PatientDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await _golden(tester, 'patient_dashboard_home');
  });

  testWidgets('Patient > My Appointments — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('My Appointments'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'patient_my_appointments');
  });

  testWidgets('Patient > My Doctors/Therapists — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('My Doctors/Therapists'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'patient_my_doctors');
  });

  testWidgets('Patient > Notifications — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.scrollUntilVisible(find.text('Notifications'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Notifications'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'patient_notifications');
  });

  testWidgets('Patient > My Profile — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PatientDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.scrollUntilVisible(find.text('My Profile'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('My Profile'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'patient_my_profile');
  });

  testWidgets('FindDoctorsScreen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const FindDoctorsScreen(), size: desktopSize);
    _drainExceptions(tester);
    await _golden(tester, 'find_doctors_screen');
  });

  testWidgets('Doctor dashboard home — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_dashboard_home');
  });

  testWidgets('Doctor > Schedule — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('Schedule'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_schedule');
  });

  testWidgets('Doctor > Documentation — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('Documentation'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_documentation');
  });

  testWidgets('Doctor > My Patients — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('My Patients'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_my_patients');
  });

  testWidgets('Doctor > Statistics — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('Statistics'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_statistics');
  });

  testWidgets('Doctor > Income — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('Income'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_income');
  });

  testWidgets('Doctor > Expenses — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('Expenses'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_expenses');
  });

  testWidgets('Doctor > My Profile — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('My Profile'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_my_profile');
  });

  testWidgets('Doctor > Notifications — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const DoctorDashboardScreen(), size: desktopSize);
    _drainExceptions(tester);
    await tester.tap(find.text('Notifications'));
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'doctor_notifications');
  });

  testWidgets('SoapNoteScreen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(
      tester,
      const SoapNoteScreen(
        patientId: 'test-patient-id',
        patientName: 'Test Patient',
      ),
      size: desktopSize,
    );
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'soap_note_screen');
  });

  testWidgets('BillingScreen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const BillingScreen(), size: desktopSize);
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'billing_screen');
  });

  testWidgets('ExpensesScreen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const ExpensesScreen(), size: desktopSize);
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'expenses_screen');
  });

  testWidgets('SessionStatsScreen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const SessionStatsScreen(), size: desktopSize);
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'session_stats_screen');
  });

  testWidgets('CreatePatientScreen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const CreatePatientScreen(), size: desktopSize);
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'create_patient_screen');
  });

  testWidgets('AdminDashboardScreen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const AdminDashboardScreen(), size: desktopSize);
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'admin_dashboard_screen');
  });

  testWidgets('PolyclinicDashboardScreen — desktop', (tester) async {
    await ensureSupabaseInitialized();
    await signInFakeUser();
    await pumpAtSize(tester, const PolyclinicDashboardScreen(), size: desktopSize);
    await _settle(tester);
    _drainExceptions(tester);
    await _golden(tester, 'polyclinic_dashboard_screen');
  });
}
