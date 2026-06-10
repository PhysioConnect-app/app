# Polyclinic Mobile Audit (findings only — no fixes applied)

Per the approved feature-matrix spec: "Polyclinic = leave ungated for now but fix
the shared broken Home footer; flag remaining polyclinic mobile issues in a
report, don't fix yet." The shared Home-footer fix (Part C.1) is done. This
report covers what's left, found by reading the polyclinic-specific code paths
at mobile width (390x844). **Nothing in this document has been changed.**

## 1. `_userRole == 'polyclinic'` branches in `doctor_dashboard_screen.dart` are dead code

`main.dart`'s `AuthGate` routes strictly by the `users.role` column:

- `role == 'doctor'` → `DoctorDashboardScreen`
- `role == 'polyclinic'` → `PolyclinicDashboardScreen` (a separate top-level widget)

So `DoctorDashboardScreen` is never mounted for a polyclinic account. Inside
that file, `_userRole` defaults to `'doctor'` and is only ever overwritten to
`'polyclinic'` by the realtime `_subListener` if a *doctor's* row somehow gets
`role: 'polyclinic'` while the screen is already open — an edge case the
`AuthGate` wouldn't react to without a full rebuild.

Practical consequence: every `_userRole == 'polyclinic'` branch is effectively
unreachable —

- The 9th nav icon/color (`_allNavIcons`/`_allTileColors`, lines ~107-114)
- The "My Doctors" entry in the section list / nav drawer (line 435)
- `_buildPolyclinicDoctorsTab()`, `_polyclinicDoctorCard()`, the create/edit
  doctor sheets, and `_showAssignPatientsSheet()` (lines ~6797-7480)

This also means **Part C.1's home-footer fix does not reach the polyclinic
experience** — `PolyclinicDashboardScreen` has its own `_header()` +
`BottomNavigationBar` and never calls `DoctorDashboardScreen._buildHomeScreen`.
(It was already correct/unaffected — it just wasn't "shared" the way the spec
assumed.)

Separately, even if `_userRole` were `'polyclinic'`, the Home tile grid in
`_buildHomeScreen` (lines ~518-522) builds its `sections`/`visibleIndices` from
a local 8-item list that doesn't include "My Doctors", so that tile could never
appear in the grid anyway — only the nav drawer's `sections` list (9 items,
line 426-436) accounts for it correctly.

**Suggestion (not applied):** since `cleanup/unused-code` is the active branch,
this whole `_userRole == 'polyclinic'` code block in `doctor_dashboard_screen.dart`
looks like a strong candidate for removal in a follow-up cleanup pass.

## 2. `PolyclinicDashboardScreen` has no mobile render test

`test/goldens/desktop_goldens_test.dart` covers it at 1400x900 only. There is
no 390x844 widget test (the same gap that `create_patient_test.dart` just
closed for `CreatePatientScreen`). The screen is ungated by
`FormFactorFeatures` (per spec, intentionally — "leave ungated for now"), so it
*does* render at mobile widths today, but that's currently unverified by tests.

## 3. Latent overflow risk: `_summaryCard` in the Income tab

`_IncomeTab._summaryCard()` (~line 1143) renders:

```dart
Row(children: [
  Expanded(child: Column([title, sub])),
  Text(value, style: fontSize 20, bold),  // no Expanded / no ellipsis
])
```

Two of these sit side-by-side via `Expanded` in the Revenue/Pending row, giving
roughly ~146px of inner width per card at 390px screen width. With small
amounts ("USD 0.00") this fits, but a real value like "USD 123456.78" at 20px
bold could exceed that width and trigger `RenderFlex overflowed`, since `value`
isn't wrapped in `Expanded`/`FittedBox`/ellipsis. Current tests don't catch this
because the mocked Supabase client returns `[]` for `invoices`, so
`totalRevenue`/`pendingTotal` are always `0.00`.

## 4. `DropdownButton`s missing `isExpanded: true`

- `_PatientsTab`'s "All Doctors" filter dropdown (~line 609) and
- `_StatsTab`'s period dropdown (~line 1312)

both omit `isExpanded: true`, unlike `_IncomeTab`'s doctor-filter dropdown
(~line 933) which sets it correctly. Without `isExpanded`, a `DropdownButton`
sizes to its selected item's intrinsic width; `_PatientsTab`'s dropdown in
particular shows real doctor names as items, and sits in an `Expanded` half of
a 390px-wide row (~185px). A long doctor name could overflow that Row. Not
caught by tests because the mocked doctors stream returns `[]`, leaving only
the short "All Doctors" placeholder item.

## Summary

| # | Issue | Mobile-specific? | Caught by current tests? |
|---|-------|-------------------|---------------------------|
| 1 | `_userRole == 'polyclinic'` branches in `doctor_dashboard_screen.dart` are dead code | No (general) | N/A |
| 2 | No 390x844 render test for `PolyclinicDashboardScreen` | Yes (test gap) | N/A |
| 3 | `_summaryCard` value text can overflow at mobile widths with real data | Yes | No (mocked data is always `[]`) |
| 4 | Two `DropdownButton`s missing `isExpanded: true` | Yes | No (mocked data is always `[]`) |

No code changes were made for this report.
