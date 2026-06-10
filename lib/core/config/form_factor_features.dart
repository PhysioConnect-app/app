import 'package:flutter/material.dart';
import '../constants/breakpoints.dart';

/// Single source of truth for behavioral differences between the desktop
/// and mobile layouts. Every place the app needs to know "is this feature
/// available on this form factor?" should go through here, so the full set
/// of mobile/desktop differences stays declared in one place.
///
/// Desktop layouts are never altered by these flags (all getters are `true`
/// when [isMobile] is `false`).
class FormFactorFeatures {
  final bool isMobile;

  const FormFactorFeatures._(this.isMobile);

  factory FormFactorFeatures.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return FormFactorFeatures._(width < kMobileBreakpoint);
  }

  // ── Doctor: Scheduling ───────────────────────────────────────────────────
  /// Import-from-Excel and the related "Format" help action on the
  /// Schedule tab.
  bool get showScheduleImportExport => !isMobile;

  // ── Doctor: My Patients ──────────────────────────────────────────────────
  /// Import-from-Excel and Export-to-Excel actions on the My Patients tab,
  /// including the per-patient appointment-history Excel export reached
  /// from a patient's action sheet.
  bool get showPatientsImportExport => !isMobile;

  // ── Doctor: Documentation ────────────────────────────────────────────────
  /// "Export PDF" action on the Documentation tab.
  bool get showDocumentationExport => !isMobile;

  // ── Doctor: Income / Billing ─────────────────────────────────────────────
  /// "Export Report" and "Import Excel" actions (and their format-help
  /// button) in the Income tab's bottom action bar.
  bool get showBillingImportExport => !isMobile;

  // ── Doctor: Statistics ────────────────────────────────────────────────────
  /// The Statistics tab (Session Stats) — its nav entry, home tile, and
  /// screen content. Desktop only.
  bool get showStatistics => !isMobile;

  // ── Admin ─────────────────────────────────────────────────────────────────
  /// The Admin dashboard — desktop only.
  bool get showAdminDashboard => !isMobile;

  // ── Inventory ─────────────────────────────────────────────────────────────
  /// Reserved: the inventory screen currently has no navigation entry
  /// anywhere in the app, so this flag has no effect yet. Kept so that if a
  /// nav entry is ever added, it is gated by construction.
  bool get showInventory => !isMobile;

  // ── Patient: Guest mode ───────────────────────────────────────────────────
  /// "Continue as Guest" entry on the login screen, giving patients a
  /// restricted, account-free preview (Find a Therapist only). Mobile only;
  /// the desktop login screen is unchanged.
  bool get showGuestLogin => isMobile;
}
