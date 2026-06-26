# Integration Test Coverage Inventory

Generated: 2026-06-25 | Phase 1 — inventory only, no tests written yet.

---

## Table of Contents

1. [Routing & Auth Gate](#1-routing--auth-gate)
2. [LoginScreen](#2-loginscreen)
3. [Admin Dashboard](#3-admin-dashboard)
4. [Doctor Dashboard — Home Grid](#4-doctor-dashboard--home-grid)
5. [Doctor — Schedule Tab (index 0)](#5-doctor--schedule-tab-index-0)
6. [Doctor — Documentation Tab (index 1)](#6-doctor--documentation-tab-index-1)
7. [SoapNoteScreen](#7-soapnotescreen)
8. [Doctor — My Patients Tab (index 2)](#8-doctor--my-patients-tab-index-2)
9. [CreatePatientScreen](#9-createpatientscreen)
10. [Doctor — Statistics Tab (index 3)](#10-doctor--statistics-tab-index-3)
11. [SessionStatsScreen](#11-sessionstatsscreen)
12. [Doctor — Billing Tab (index 4)](#12-doctor--billing-tab-index-4)
13. [Doctor — Expenses Tab (index 5)](#13-doctor--expenses-tab-index-5)
14. [Doctor — My Profile Tab (index 6)](#14-doctor--my-profile-tab-index-6)
15. [Doctor — Notifications Tab (index 7)](#15-doctor--notifications-tab-index-7)
16. [Doctor — PhysioGate Tab (index 8)](#16-doctor--physiogate-tab-index-8)
17. [Doctor — Assessment Library Tab (index 9)](#17-doctor--assessment-library-tab-index-9)
18. [HepProgramListScreen](#18-hepprogramlistscreen)
19. [HepBuilderView (program editor)](#19-hepbuilderview-program-editor)
20. [FinancialAiChatScreen](#20-financialaichatscreen)
21. [ClinicAnalyticsSheet](#21-clinicanalyticssheet)
22. [Patient Dashboard — Home](#22-patient-dashboard--home)
23. [Patient — _PatientScheduleScreen](#23-patient--_patientschedulescreen)
24. [Patient — _PatientMyDoctorsScreen](#24-patient--_patientmydoctorsscreen)
25. [FindDoctorsScreen](#25-finddoctorsscreen)
26. [Patient — _PatientNotificationsScreen](#26-patient--_patientnotificationsscreen)
27. [Patient — _PatientProfileScreen](#27-patient--_patientprofilescreen)
28. [PatientHepScreen](#28-patienthepscreen)
29. [StoreManagerDashboardScreen](#29-storemanagerdashboardscreen)
30. [StoreManagerCategoriesScreen](#30-storemanagercategoriesscreen)
31. [StoreManagerProductsScreen](#31-storemanagerproductsscreen)
32. [DoctorStorefrontScreen (PhysioGate)](#32-doctorstorefront-physiogate)
33. [PolyclinicDashboardScreen](#33-polyclinicdashboardscreen)
34. [LocationPickerScreen](#34-locationpickerscreen)
35. [Dialogs & Bottom Sheets (shared)](#35-dialogs--bottom-sheets-shared)
36. [Keys to Add](#36-keys-to-add)

---

## 1. Routing & Auth Gate

**File:** `lib/main.dart`  
**Widget:** `AuthGate` (StatelessWidget)

No interactive elements — routing only.

| Condition | Destination |
|---|---|
| No session | `LoginScreen` |
| `role == 'admin'` | `AdminDashboardScreen` |
| `role == 'doctor'` | `DoctorDashboardScreen` |
| `role == 'patient'` | `PatientDashboardScreen` |
| `role == 'store_manager'` | `StoreManagerDashboardScreen` |
| Unknown role / null row | `LoginScreen` |

---

## 2. LoginScreen

**File:** `lib/features/auth/login_screen.dart`  
**Widget:** `LoginScreen` (StatefulWidget)

| # | Widget type | Key | Label / action | Navigation / effect |
|---|---|---|---|---|
| L1 | `TextField` (_InputField) | ❌ none | Email or username | Sets `_emailController` |
| L2 | `TextField` (_InputField) | ❌ none | Password | Sets `_passwordController` |
| L3 | `IconButton` (suffix of L2) | ❌ none | Visibility toggle | Toggles `_obscure` |
| L4 | `TextButton` | ❌ none | "Request an account" | Opens `_showRequestAccountDialog()` |
| L5 | `TextButton` | ❌ none | "Forgot password" | Opens `_showForgotPasswordDialog()` |
| L6 | `ElevatedButton` | ❌ none | "Sign in" | `_handleLogin()` → AuthService.loginAdmin() → AuthGate routes |
| L7 | `OutlinedButton` (mobile only) | ❌ none | "Continue as guest" | Navigator.push → `FindDoctorsScreen(isGuest: true)` |
| L8 | `InkWell` | ❌ none | PhysioGate logo tile | Navigator.push → `DoctorStorefrontScreen` |
| L9 | `TextButton.icon` | ❌ none | Language toggle | `LanguageProvider.toggle()` |
| L10 | `TextButton` | ❌ none | Privacy policy | `launchUrl(AppStrings.privacyPolicyUrl)` |

### Forgot Password Dialog (inline AlertDialog)

| Widget | Key | Action |
|---|---|---|
| `TextField` | ❌ none | Email input |
| `TextButton` "Cancel" | ❌ none | Closes dialog |
| `ElevatedButton` "Send" | ❌ none | `AuthService.resetPassword()` |

### Request Account Dialog (inline AlertDialog)

| Widget | Key | Action |
|---|---|---|
| `TextField` Full Name | ❌ none | Name input |
| `TextField` Email | ❌ none | Email input |
| `TextField` Phone | ❌ none | Phone input |
| `CheckboxListTile` "I hold a doctorate" | ❌ none | Toggles `hasDoctorate` |
| `TextButton` "Cancel" | ❌ none | Closes dialog |
| `ElevatedButton` "Submit Request" | ❌ none | Inserts row in `account_requests` |

---

## 3. Admin Dashboard

**File:** `lib/features/admin/admin_dashboard_screen.dart`  
**Widget:** `AdminDashboardScreen` (StatefulWidget)

Navigation: `BottomNavigationBar` (mobile) / `NavigationRail` (desktop) — 6 tabs, no keys.

| Tab index | Label | Icon |
|---|---|---|
| 0 | Overview | `dashboard_rounded` |
| 1 | Doctors | `people_rounded` |
| 2 | Register | `person_add_rounded` |
| 3 | Requests | `notifications_rounded` |
| 4 | Patients | `personal_injury_rounded` |
| 5 | Notes | `campaign_rounded` |

### Tab 0 — Overview

Read-only KPI cards + feature distribution bars + recent registrations list. No tappable elements beyond the rail tabs.

### Tab 1 — Doctors list

| Widget | Key | Action |
|---|---|---|
| `TextField` (search) | ❌ none | Filters `_searchQuery` |
| `GestureDetector` on doctor row | ❌ none | Opens `_openManageSheet(doc)` |
| `PopupMenuButton` "⋮" on row | ❌ none | Menu: Edit / Remove |
| `ElevatedButton` "Remove" (in dialog) | ❌ none | `AdminService.deleteUserAccount()` |

#### Doctor Manage Sheet (showModalBottomSheet)

| Widget | Key | Action |
|---|---|---|
| `GestureDetector` tier chips (Basic / Premium) | ❌ none | Sets `config.tier` + auto-applies feature defaults |
| `Switch.adaptive` Statistics | ❌ none | Toggles `config.statistics` |
| `Switch.adaptive` Income | ❌ none | Toggles `config.billing` |
| `Switch.adaptive` Expenses | ❌ none | Toggles `config.expenses` |
| `Switch.adaptive` AI Agent | ❌ none | Toggles `config.aiEnabled` (read-only in switch; applied via tier) |
| `TextField` Full Name | ❌ none | Edits doctor name |
| `TextField` Specialization | ❌ none | Edits specialization |
| `Switch.adaptive` Account Enabled | ❌ none | Toggles `config.isEnabled` |
| `Switch.adaptive` Show in Find a Doctor | ❌ none | Toggles `config.showInSearch` |
| `Switch.adaptive` Allow Home Visits | ❌ none | Toggles `config.allowHomeVisit` |
| `InkWell` Account Expiry Date | ❌ none | Opens `showDatePicker` |
| `GestureDetector` AI Monthly Limit chips (25/50/100/200/500) | ❌ none | Sets `config.aiMonthlyLimit` |
| `ElevatedButton.icon` "Apply Changes" | ❌ none | Writes subscription config to Supabase |
| `TextButton` "Enable Dr. prefix" / "Disable" | ❌ none | Approves/declines `dr_prefix_request` |

### Tab 2 — Register

| Widget | Key | Action |
|---|---|---|
| `TextField` Full Name | ❌ none | Sets `_nameCtrl` |
| `TextField` Email | ❌ none | Sets `_emailCtrl` |
| `TextField` Password | ❌ none | Sets `_passCtrl` |
| `IconButton` visibility | ❌ none | Toggles `_obscure` |
| `TextField` Specialization | ❌ none | Sets `_specCtrl` |
| `ElevatedButton` "Create Doctor Account" | ❌ none | `AdminService.createDoctorAccount()` |

### Tab 3 — Requests

Three sections: Dr. Prefix requests, Name Change requests, Account Requests (from `account_requests` table).

| Widget | Key | Action |
|---|---|---|
| `ElevatedButton` "Approve" (Dr. prefix) | ❌ none | Sets `show_dr_prefix: true`, clears request |
| `OutlinedButton` "Decline" (Dr. prefix) | ❌ none | Clears `dr_prefix_request` |
| `ElevatedButton` "Approve" (name change) | ❌ none | Writes `name = pending_name`, clears request |
| `OutlinedButton` "Decline" (name change) | ❌ none | Clears `name_change_request` |
| `ElevatedButton` "Approve" (account request) | ❌ none | Creates doctor account, marks request approved |
| `OutlinedButton` "Decline" (account request) | ❌ none | Sets request status to declined |

### Tab 4 — Patients

| Widget | Key | Action |
|---|---|---|
| `TextField` (search) | ❌ none | Filters `_patientSearchQuery` |
| `Checkbox` per patient row | ❌ none | Adds/removes from `_selectedPatientIds` |
| `ElevatedButton` "Select All" | ❌ none | Selects all patient IDs |
| `ElevatedButton` "Merge Selected" | ❌ none | Opens merge-confirmation dialog |

### Tab 5 — Notes (broadcast)

| Widget | Key | Action |
|---|---|---|
| `TextField` Title | ❌ none | Sets `_noteTitleCtrl` |
| `TextField` Body | ❌ none | Sets `_noteBodyCtrl` |
| `CheckboxListTile` per doctor | ❌ none | Adds/removes from `_noteSelectedDoctorIds` |
| `ElevatedButton` "Send Note" | ❌ none | Inserts notification rows for selected doctors |

---

## 4. Doctor Dashboard — Home Grid

**File:** `lib/features/doctor/doctor_dashboard_screen.dart`  
**Widget:** `DoctorDashboardScreen` / `_buildHomeScreen()`

Header interactive elements:

| Widget | Key | Action |
|---|---|---|
| `GestureDetector` profile avatar | ❌ none | `_navigateTo(6)` → My Profile |
| `GestureDetector` AI sparkle button (shown when `_sub.aiEnabled`) | ❌ none | `_showAiAssistantSheet()` |
| `_buildHeaderNavButton` Notifications | ❌ none | `_navigateTo(7)` → Notifications |
| `TextButton` language toggle | ❌ none | `lang.toggle()` |
| `IconButton` logout | ❌ none | `_showLogout()` |
| `TextButton.icon` Import | ❌ none | `_importUnifiedFromExcel()` |
| `TextButton` Log out (sub bar) | ❌ none | `_showLogout()` |

Grid tiles (8 tiles, `primaryIndices = [2, 0, 1, 9, 4, 5, 3, 8]`):

| Tile index | Section | Color |
|---|---|---|
| 2 | My Patients | Orange |
| 0 | Schedule | Blue |
| 1 | Documentation | Green |
| 9 | Assessment Library | Dark cyan |
| 4 | Billing / Revenues | Teal accent |
| 5 | Expenses | Coral |
| 3 | Statistics | Teal |
| 8 | PhysioGate | Deep indigo |

All tiles are `GestureDetector` with **no keys**. Each calls `_navigateTo(idx)`.

First-time guide (when `_hasPatients == false`):

| Widget | Key | Action |
|---|---|---|
| `ElevatedButton.icon` "Add Patient" | ❌ none | `_navigateTo(2)` → My Patients |
| `OutlinedButton` "Import from Excel" | ❌ none | `_importUnifiedFromExcel()` |

### AI Doctor Assistant Sheet (showModalBottomSheet)

| Widget | Key | Action |
|---|---|---|
| `InkWell` "Generate SOAP Documentation" | ❌ none | `_navigateTo(1)` → Documentation |
| `InkWell` "Analyze Revenue & Expenses" | ❌ none | `showClinicAnalyticsSheet()` |
| `InkWell` "Statistics & Performance" | ❌ none | `showClinicAnalyticsSheet()` |

---

## 5. Doctor — Schedule Tab (index 0)

**File:** `lib/features/doctor/doctor_dashboard_screen.dart` — `_buildScheduleTab()`

| Widget | Key | Action |
|---|---|---|
| `IconButton` prev month `<<` | ❌ none | `_changeCalMonth(-1)` |
| `IconButton` next month `>>` | ❌ none | `_changeCalMonth(+1)` |
| Calendar day cells (`GestureDetector`) | ❌ none | Sets `_calDay` |
| `FloatingActionButton` | ❌ none | Opens `_showNewAppointmentSheet()` |
| Appointment rows (`InkWell` / `GestureDetector`) | ❌ none | Opens appointment detail/cancel sheet |

### New Appointment Sheet

| Widget | Key | Action |
|---|---|---|
| Patient search field | ❌ none | Filters patients |
| Patient list item | ❌ none | Selects patient |
| Date picker | ❌ none | `showDatePicker()` |
| Time picker | ❌ none | `showTimePicker()` |
| `TextField` notes | ❌ none | Sets notes |
| `ElevatedButton` "Book" | ❌ none | Inserts appointment row |
| `TextButton` "Cancel" | ❌ none | Closes sheet |

---

## 6. Doctor — Documentation Tab (index 1)

**File:** `lib/features/doctor/doctor_dashboard_screen.dart` — `_buildDocumentationTab()`

| Widget | Key | Action |
|---|---|---|
| Patient filter dropdown | ❌ none | Filters notes list |
| `FloatingActionButton` | ❌ none | Opens new `SoapNoteScreen` |
| Note row `GestureDetector` | ❌ none | Navigator.push → `SoapNoteScreen(noteId)` |
| `IconButton` export PDF | ❌ none | `_exportDocumentationPdf()` |

---

## 7. SoapNoteScreen

**File:** `lib/features/doctor/soap_note_screen.dart`  
**Widget:** `SoapNoteScreen` (StatefulWidget)  
Opened via `Navigator.push` from the Documentation tab.

| Widget | Key | Action |
|---|---|---|
| Template chips / dropdown (8 templates) | ❌ none | Pre-fills all SOAP fields |
| `ElevatedButton.icon` "AI Assist" | ❌ none | `AiService.generateSoap()` → preview sheet |
| **Subjective section (11 TextFormFields):** | | |
| — Chief Complaint | ❌ none | Sets `_chiefComplaintCtrl` |
| — Onset / Duration | ❌ none | Sets `_onsetDurationCtrl` |
| — Pain Level (slider or field) | ❌ none | Sets `_painLevelCtrl` |
| — Pain Characteristics | ❌ none | Sets field |
| — Aggravating Factors | ❌ none | Sets field |
| — Relieving Factors | ❌ none | Sets field |
| — Functional Limitations | ❌ none | Sets field |
| — Patient Goals | ❌ none | Sets field |
| — Medical / Surgical History | ❌ none | Sets field |
| — Medications | ❌ none | Sets field |
| — Social / Occupational Context | ❌ none | Sets field |
| **Objective section (9 TextFormFields):** | | |
| — Observation | ❌ none | Sets field |
| — Palpation | ❌ none | Sets field |
| — Range of Motion | ❌ none | Sets field |
| — Strength Testing | ❌ none | Sets field |
| — Neurological Exam | ❌ none | Sets field |
| — Balance / Coordination | ❌ none | Sets field |
| — Special Tests | ❌ none | Sets field |
| — Functional Tests | ❌ none | Sets field |
| — Assistive Devices | ❌ none | Sets field |
| **Assessment section (6 TextFormFields):** | | |
| — Clinical Impression | ❌ none | Sets field |
| — Severity / Stage | ❌ none | Sets field |
| — Progress Toward Goals | ❌ none | Sets field |
| — Barriers | ❌ none | Sets field |
| — Response to Treatment | ❌ none | Sets field |
| — Prognosis | ❌ none | Sets field |
| **Plan section (6 TextFormFields):** | | |
| — Treatment Focus | ❌ none | Sets field |
| — Interventions | ❌ none | Sets field |
| — Frequency / Duration | ❌ none | Sets field |
| — Home Exercise Program | ❌ none | Sets field |
| — Referrals | ❌ none | Sets field |
| — Follow-up | ❌ none | Sets field |
| `ElevatedButton` "Save" | ❌ none | Upserts `clinical_notes` row, Navigator.pop() |
| `TextButton` / AppBar back | ❌ none | Navigator.pop() without saving |

### AI SOAP Preview Sheet

| Widget | Key | Action |
|---|---|---|
| Field-by-field preview rows | ❌ none | Read-only display |
| `ElevatedButton` "Apply" | ❌ none | `_applyAiSoap()` — fills all 32 controllers |
| `TextButton` "Discard" | ❌ none | Closes sheet without applying |

---

## 8. Doctor — My Patients Tab (index 2)

**File:** `lib/features/doctor/doctor_dashboard_screen.dart` — `_buildPatientsTab()`

| Widget | Key | Action |
|---|---|---|
| `PatientSearchField` | ❌ none | Sets `_patientSearch` — filters by name, diagnosis, phone |
| `ElevatedButton.icon` "New Patient" | ❌ none | Navigator.push → `CreatePatientScreen` |
| `TextButton` "Import Help" | ❌ none | `showImportHelpSheet()` |
| Patient row `InkWell` | ❌ none | Opens `_showPatientActionSheet(patient)` |

### Patient Action Sheet (showModalBottomSheet)

| Widget | Key | Action |
|---|---|---|
| `ListTile` "Schedule Session" | ❌ none | Opens new appointment sheet |
| `ListTile` "SOAP / Clinical Notes" | ❌ none | Navigator.push → `SoapNoteScreen(patientId)` |
| `ListTile` "Billing & Invoices" | ❌ none | Navigator.push → `BillingScreen(patientId)` |
| `ListTile` "Exercise Programs (HEP)" | ❌ none | Navigator.push → `HepProgramListScreen` |
| `ListTile` "Assessment" | ❌ none | `_navigateTo(9)` → Assessment Library |
| `ListTile` "Delete Patient" | ❌ none | Confirmation dialog → `DoctorService.deletePatient()` |

---

## 9. CreatePatientScreen

**File:** `lib/features/doctor/create_patient_screen.dart`  
**Widget:** `CreatePatientScreen` (StatefulWidget)

| Widget | Key | Action |
|---|---|---|
| `TextField` Full Name | ❌ none | Sets `_nameController` |
| `TextField` Email | ❌ none | Sets `_emailController` |
| `TextField` Password | ❌ none | Sets `_passwordController` |
| `IconButton` visibility toggle | ❌ none | Toggles `_obscure` |
| `TextField` Phone (`LebanonPhoneField`) | ❌ none | Sets `_phoneController` |
| `AbsorbPointer`/`TextField` Date of Birth | ❌ none | Calls `showDatePicker()` on tap |
| `TextField` Primary Diagnosis | ❌ none | Sets `_diagnosisController` (maxLines 2) |
| `ElevatedButton.icon` "Create Account" | ❌ none | `AdminService.createPatientAccount()`, Navigator.pop on success |

---

## 10. Doctor — Statistics Tab (index 3)

Locked with `_buildLockedScreen()` when tier < Premium. When unlocked:

| Widget | Key | Action |
|---|---|---|
| `ElevatedButton` "Upgrade" (locked state) | ❌ none | Does nothing / contact admin copy |
| (passes directly to `SessionStatsScreen`) | — | see §11 |

---

## 11. SessionStatsScreen

**File:** `lib/features/doctor/session_stats_screen.dart`  
**Widget:** `SessionStatsScreen` (StatefulWidget)

| Widget | Key | Action |
|---|---|---|
| Period chips (Daily / Weekly / Monthly / Yearly) | ❌ none | Sets `_period` |
| `IconButton` calendar | ❌ none | `showDatePicker()` |
| `IconButton` `<<` prev period | ❌ none | Decrements `_refDate` |
| `IconButton` `>>` next period | ❌ none | Increments `_refDate` |
| Charts (read-only `fl_chart`) | — | No tap actions |
| `IconButton` "Add appointment" (passed via `onAddAppointment`) | ❌ none | `_navigateTo(0)` in parent |

---

## 12. Doctor — Billing Tab (index 4)

**File:** `lib/features/doctor/billing_screen.dart`  
**Widget:** `BillingScreen` (StatefulWidget)

| Widget | Key | Action |
|---|---|---|
| Period `DropdownButton` (Daily/Weekly/Monthly/Yearly) | ❌ none | Sets `_period` |
| `IconButton` calendar | ❌ none | `showDatePicker()` |
| `IconButton` `<<` / `>>` | ❌ none | Period navigation |
| `PatientSearchField` | ❌ none | Filters by patient name |
| Status filter chips | ❌ none | Sets `_statusFilter` |
| `ElevatedButton` "Add Income" (large primary) | ❌ none | Opens add-invoice bottom sheet |
| `OutlinedButton` "Export Excel" | ❌ none | `FileSaver.saveFile()` with Excel bytes |
| `OutlinedButton` "Insurance" | ❌ none | Opens insurance summary sheet |
| `OutlinedButton` "AI Analysis" | ❌ none | Navigator.push → `FinancialAiChatScreen` |
| Invoice row `InkWell` | ❌ none | Opens edit-invoice bottom sheet |
| `IconButton` PDF export on row | ❌ none | `printing.Printing.layoutPdf()` |
| `PopupMenuButton` on row | ❌ none | Options: Edit, Mark Paid, Cancel |

### Add / Edit Invoice Sheet

| Widget | Key | Action |
|---|---|---|
| Patient search / dropdown | ❌ none | Sets patient |
| `TextField` Service / Description | ❌ none | Sets `service` |
| `TextField` Amount | ❌ none | Sets `amount` |
| Currency dropdown | ❌ none | Sets `currency` |
| Status dropdown | ❌ none | Sets status |
| Date picker | ❌ none | Sets invoice date |
| `ElevatedButton` "Save" | ❌ none | Upserts `invoices` row |
| `TextButton` "Cancel" | ❌ none | Closes sheet |

---

## 13. Doctor — Expenses Tab (index 5)

**File:** `lib/features/doctor/expenses_screen.dart`  
**Widget:** `ExpensesScreen` (StatefulWidget)

Same period/date controls as Billing. Additionally:

| Widget | Key | Action |
|---|---|---|
| Category filter chips | ❌ none | Filters `_categoryFilter` |
| `FloatingActionButton` | ❌ none | Opens add-expense bottom sheet |
| `OutlinedButton` "Export Excel" | ❌ none | Saves Excel file |
| `OutlinedButton` "AI Analysis" | ❌ none | Navigator.push → `FinancialAiChatScreen` |
| Expense row `InkWell` | ❌ none | Opens edit-expense sheet |
| `IconButton` delete on row | ❌ none | Confirmation dialog → deletes row |

### Add / Edit Expense Sheet

| Widget | Key | Action |
|---|---|---|
| `TextField` Description | ❌ none | Sets description |
| Category `DropdownButtonFormField` | ❌ none | Sets category |
| `TextField` Amount | ❌ none | Sets amount |
| Date picker | ❌ none | Sets date |
| `ElevatedButton` "Save" | ❌ none | Upserts `expenses` row |
| `TextButton` "Cancel" | ❌ none | Closes sheet |

---

## 14. Doctor — My Profile Tab (index 6)

**File:** `lib/features/doctor/doctor_dashboard_screen.dart` — `_buildProfileTab()`

| Widget | Key | Action |
|---|---|---|
| `TextField` Display Name | ❌ none | Sets `_nameCtrl` |
| `TextField` Bio | ❌ none | Sets `_bioCtrl` |
| `TextField` Profile Photo URL | ❌ none | Sets `_photoCtrl` |
| `TextField` Specialization | ❌ none | Sets `_specCtrl` |
| `TextField` Clinic Name | ❌ none | Sets `_clinicNameCtrl` |
| `TextField` Clinic Address | ❌ none | Sets `_clinicAddrCtrl` |
| `TextField` Working Hours | ❌ none | Sets `_workingHoursCtrl` |
| `LebanonPhoneField` | ❌ none | Sets `_phoneCtrl` |
| `Switch.adaptive` Home Visits | ❌ none | Toggles `_homeVisit` |
| `ElevatedButton` "Edit Location" | ❌ none | Navigator.push → `LocationPickerScreen` |
| `ElevatedButton` "Save Profile" | ❌ none | `DoctorService.updateProfile()` |
| `TextButton` "Request Dr. prefix" / "Cancel request" | ❌ none | Calls `_requestDrPrefix()` / `_cancelDrPrefixRequest()` |
| `TextButton` "Request name change" | ❌ none | Opens name-change dialog |
| `ElevatedButton.icon` "Sign Out" | ❌ none | `_showLogout()` |
| `OutlinedButton` "Delete Account" | ❌ none | Confirmation dialog → deletes account |

---

## 15. Doctor — Notifications Tab (index 7)

**File:** `lib/features/doctor/doctor_notifications_tab.dart`  
**Widget:** `DoctorNotificationsTab` (StatefulWidget)

| Widget | Key | Action |
|---|---|---|
| Notification `ListTile` | ❌ none | Marks read; may navigate (e.g. to appointment) |
| `IconButton` delete on row | ❌ none | Deletes notification |
| `TextButton` "Mark all read" | ❌ none | Batch update `read: true` |

---

## 16. Doctor — PhysioGate Tab (index 8)

Renders `_buildStoreTab()` which embeds `DoctorStorefrontScreen` inline. See §32.

---

## 17. Doctor — Assessment Library Tab (index 9)

**File:** `lib/features/doctor/assessment_library/assessment_library_screen.dart`  
**Widget:** `AssessmentLibraryScreen` (StatefulWidget)

Internal state-machine navigation (no `Navigator.push`). Uses `PopScope` to intercept back button.

| Widget | Key | Action |
|---|---|---|
| Category `InkWell` tiles | ❌ none | `setState` → subcategory list |
| Subcategory `InkWell` tiles | ❌ none | `setState` → test list |
| Test `InkWell` tiles | ❌ none | `setState` → test detail |
| Breadcrumb back `InkWell` | ❌ none | `_goBack()` — pops internal navigation stack |
| `PopScope` | — | Intercepts Android back → `_goBack()` |

---

## 18. HepProgramListScreen

**File:** `lib/features/hep/screens/hep_builder_screen.dart`  
**Widget:** `HepProgramListScreen` (StatefulWidget)  
Opened from Patient Action Sheet.

| Widget | Key | Action |
|---|---|---|
| `FloatingActionButton` "New Program" | ❌ none | Navigator.push → `_HepBuilderView(existing: null)` |
| Program `ListTile` | ❌ none | Navigator.push → `_HepBuilderView(existing: program)` |
| `IconButton` archive on row | ❌ none | Opens archive confirmation dialog |
| Archive dialog `TextButton` "Cancel" | ❌ none | Closes dialog |
| Archive dialog `TextButton` "Archive" | ❌ none | `HepService.archiveProgram()` |

---

## 19. HepBuilderView (program editor)

**File:** `lib/features/hep/screens/hep_builder_screen.dart`  
**Widget:** `_HepBuilderView` (StatefulWidget, private)

| Widget | Key | Action |
|---|---|---|
| `TextFormField` Program title | ❌ none | Sets `_titleCtrl` |
| `TextFormField` Program description | ❌ none | Sets `_descCtrl` |
| Exercise library `DropdownButton` | ❌ none | Sets selected exercise to add |
| `IconButton` "Add exercise" | ❌ none | Appends exercise to `_items` |
| Reorderable exercise item | ✅ `ValueKey(_items[i].exerciseId)` | Drag handle for reorder |
| `TextField` Sets on exercise row | ❌ none | Updates sets count |
| `TextField` Reps on exercise row | ❌ none | Updates reps count |
| `IconButton` delete on exercise row | ❌ none | Removes from `_items` |
| `ElevatedButton` "Save Program" | ❌ none | `HepService.saveProgram()`, Navigator.pop(true) |
| `TextButton` "Cancel" | ❌ none | Navigator.pop(false) |

---

## 20. FinancialAiChatScreen

**File:** `lib/features/ai/financial_ai_chat_screen.dart`  
**Widget:** `FinancialAiChatScreen` (StatefulWidget)

| Widget | Key | Action |
|---|---|---|
| Quick suggestion chips (8 chips, `Wrap`) | ❌ none | Sets `_msgCtrl.text` then calls `_handleSendMessage()` |
| `TextField` message input | ❌ none | Sets `_msgCtrl` |
| `IconButton` send | ❌ none | `_handleSendMessage()` → `AiService.sendFinancialMessage()` |
| AI response confirm dialog `ElevatedButton` "Confirm" | ❌ none | Executes write action |
| AI response confirm dialog `TextButton` "Cancel" | ❌ none | Aborts action |

---

## 21. ClinicAnalyticsSheet

**File:** `lib/features/ai/clinic_analytics_sheet.dart`  
Opened via `showClinicAnalyticsSheet(context)` — `showModalBottomSheet`.

| Widget | Key | Action |
|---|---|---|
| Period `DropdownButton` (Monthly/Quarterly/Yearly) | ❌ none | Sets `_period` |
| Quick prompt chips (6 chips, `Wrap`) | ❌ none | Sets `_promptCtrl.text` |
| `TextField` custom prompt | ❌ none | Sets `_promptCtrl` |
| `ElevatedButton` "Analyze" | ❌ none | `_refreshFinancialContext()` → AI request |

---

## 22. Patient Dashboard — Home

**File:** `lib/features/patient/patient_dashboard_screen.dart`  
**Widget:** `PatientDashboardScreen` (StatefulWidget)

Header:

| Widget | Key | Action |
|---|---|---|
| `GestureDetector` profile avatar | ❌ none | Navigator.push → `_PatientProfileScreen` |
| `TextButton` language toggle | ❌ none | `lang.toggle()` |

Upcoming appointment card (when exists):

| Widget | Key | Action |
|---|---|---|
| `ElevatedButton` "View Details" | ❌ none | Navigator.push → `_PatientScheduleScreen` |

No-appointment banner:

| Widget | Key | Action |
|---|---|---|
| `ElevatedButton` "Book" | ❌ none | Navigator.push → `_PatientMyDoctorsScreen` |

Quick Access grid (2×2, `_GridTile`):

| Tile index | Label | Key | Navigation |
|---|---|---|---|
| 0 | My Appointments | ❌ none | `_PatientScheduleScreen` |
| 1 | My Doctors/Therapists | ❌ none | `_PatientMyDoctorsScreen` |
| 2 | Find a Doctor or Therapist | ❌ none | `FindDoctorsScreen` |
| 3 | Notifications | ❌ none | `_PatientNotificationsScreen` |

Below grid:

| Widget | Key | Action |
|---|---|---|
| `GestureDetector` "My Exercises" banner | ❌ none | Navigator.push → `PatientHepScreen` |
| `GestureDetector` "My Profile" banner | ❌ none | Navigator.push → `_PatientProfileScreen` |
| Long-press on profile banner | ❌ none | `_showLogout()` |

---

## 23. Patient — _PatientScheduleScreen

**File:** `lib/features/patient/patient_dashboard_screen.dart` (private class)

4 tabs: Upcoming / Requested / Previous / Summary.

| Widget | Key | Action |
|---|---|---|
| `TabBar` 4 tabs | ❌ none | Switches tab content |
| Appointment card on Upcoming | ❌ none | Read-only display |
| Requested appointment card status badge | ❌ none | Read-only (pending/accepted/declined) |

---

## 24. Patient — _PatientMyDoctorsScreen

**File:** `lib/features/patient/patient_dashboard_screen.dart` (private class)

| Widget | Key | Action |
|---|---|---|
| Doctor `ListTile` | ✅ `Key(docs[i]['id'] as String)` | Opens request-appointment bottom sheet |
| `IconButton` "Add Doctor" (FAB or header) | ❌ none | Navigator.push → `FindDoctorsScreen` |

### Request Appointment Sheet

| Widget | Key | Action |
|---|---|---|
| Available time slot chips | ❌ none | Selects slot |
| `ElevatedButton` "Request" | ❌ none | Inserts `appointment_requests` row |
| `TextButton` "Cancel" | ❌ none | Closes sheet |

---

## 25. FindDoctorsScreen

**File:** `lib/features/patient/find_doctors_screen.dart`  
**Widget:** `FindDoctorsScreen` (StatefulWidget, `isGuest: false/true`)

| Widget | Key | Action |
|---|---|---|
| `TextField` search | ❌ none | Sets `_searchCtrl` — filters by name, specialization, clinic, bio |
| Filter chips (All / Nearby / Home Visit / 5+ yrs / 10+ yrs) | ❌ none | Sets filter state |
| `Switch` "Show Map" | ❌ none | Toggles `_showMap` |
| `ElevatedButton.icon` "Get My Location" | ❌ none | `Geolocator.getCurrentPosition()` |
| Doctor card `GestureDetector` | ❌ none | Expands detail / inline action |
| `IconButton` "Add to My List" | ❌ none | `PatientService.addDoctorToMyList()` |
| `IconButton` Call | ❌ none | `launchUrl('tel:…')` |
| `IconButton` WhatsApp | ❌ none | `launchUrl('https://wa.me/…')` |

---

## 26. Patient — _PatientNotificationsScreen

**File:** `lib/features/patient/patient_dashboard_screen.dart` (private class)

| Widget | Key | Action |
|---|---|---|
| Notification `ListTile` | ❌ none | Marks `read: true` |
| `IconButton` delete | ❌ none | Deletes notification |

---

## 27. Patient — _PatientProfileScreen

**File:** `lib/features/patient/patient_dashboard_screen.dart` (private class)

| Widget | Key | Action |
|---|---|---|
| `TextField` Name | ❌ none | Sets name |
| `TextField` Phone | ❌ none | Sets phone |
| `ImagePicker` avatar | ❌ none | Opens camera/gallery picker |
| `ElevatedButton` "Save" | ❌ none | Updates `users` row |
| `TextButton` "Delete Account" | ❌ none | Confirmation dialog → deletes account |
| Logout button | ❌ none | `_showLogout()` |

---

## 28. PatientHepScreen

**File:** `lib/features/hep/screens/patient_hep_screen.dart`  
**Widget:** `PatientHepScreen` (StatefulWidget)  
Read-only view.

| Widget | Key | Action |
|---|---|---|
| `RefreshIndicator` | ❌ none | Pull-to-refresh → reloads programs |
| `ExpansionTile` per program | ❌ none | Expand / collapse exercises |
| Medical disclaimer text | — | Read-only |

---

## 29. StoreManagerDashboardScreen

**File:** `lib/features/store/store_manager_dashboard_screen.dart`  
**Widget:** `StoreManagerDashboardScreen` (StatefulWidget)

| Widget | Key | Action |
|---|---|---|
| `TabBar` (2 tabs: Categories / Products) | ❌ none | `_tabController.animateTo()` |
| `IconButton` sign out (AppBar) | ❌ none | `Supabase.instance.client.auth.signOut()` |

---

## 30. StoreManagerCategoriesScreen

**File:** `lib/features/store/store_manager_categories_screen.dart`

| Widget | Key | Action |
|---|---|---|
| `FloatingActionButton` | ❌ none | Opens add-category bottom sheet |
| Category `ListTile` | ❌ none | Opens edit-category bottom sheet |
| `IconButton` delete | ❌ none | Confirmation dialog → deletes category |
| **Bottom sheet fields:** | | |
| `TextField` Name | ❌ none | Sets name |
| `TextField` Description | ❌ none | Sets description |
| `TextField` Thumbnail URL | ❌ none | Sets thumbnail |
| `ElevatedButton` "Save" | ❌ none | Upserts category |
| `TextButton` "Cancel" | ❌ none | Closes sheet |

---

## 31. StoreManagerProductsScreen

**File:** `lib/features/store/store_manager_products_screen.dart`

| Widget | Key | Action |
|---|---|---|
| `FloatingActionButton` | ❌ none | Opens add-product bottom sheet |
| Product `ListTile` | ❌ none | Opens edit-product bottom sheet |
| `IconButton` delete | ❌ none | Confirmation dialog → deletes product |
| **Bottom sheet fields:** | | |
| `TextField` Name | ❌ none | Sets name |
| Category `DropdownButtonFormField` | ❌ none | Sets category |
| `TextField` Price | ❌ none | Sets price |
| `TextField` Description | ❌ none | Sets description |
| Status `Switch` (Draft / Published) | ❌ none | Toggles `is_published` |
| `ImagePicker` image upload | ❌ none | Uploads image |
| `ElevatedButton` "Save" | ❌ none | Upserts product |
| `TextButton` "Cancel" | ❌ none | Closes sheet |

---

## 32. DoctorStorefrontScreen (PhysioGate)

**File:** `lib/features/store/doctor_storefront_screen.dart`  
**Widget:** `DoctorStorefrontScreen` (StatefulWidget)

Internal breadcrumb-stack navigation (no `Navigator.push` for categories).

| Widget | Key | Action |
|---|---|---|
| Root category `GestureDetector` tiles | ❌ none | `_catStack.add(category)` → subcategory view |
| Subcategory `GestureDetector` tiles | ❌ none | `_catStack.add(subcategory)` |
| Product `GestureDetector` | ❌ none | `_openProduct(product)` → full-screen detail |
| Back breadcrumb `GestureDetector` | ❌ none | `_catStack.removeLast()` |
| Product image lightbox (`PageRouteBuilder`) | ❌ none | Opens image carousel |
| `ElevatedButton` "Contact / WhatsApp" | ❌ none | `launchUrl('https://wa.me/…')` |

---

## 33. PolyclinicDashboardScreen

**File:** `lib/features/polyclinic/polyclinic_dashboard_screen.dart`  
**Widget:** `PolyclinicDashboardScreen` (StatefulWidget)

5 tabs (TabBar, no keys): My Doctors / My Patients / Income / Statistics / Profile.

| Widget | Key | Action |
|---|---|---|
| `TabBar` 5 tabs | ❌ none | Switches content |
| `IconButton` Add Doctor (FAB) | ❌ none | `_showAddDoctorSheet()` |
| Doctor `ListTile` | ❌ none | `_unlinkDoctor()` confirmation dialog |
| Doctor search `TextField` (in sheet) | ❌ none | Filters available doctors |
| Doctor search result `ListTile` | ❌ none | `_linkDoctor(doctorUid)` |
| Income period `DropdownButton` | ❌ none | Sets period |
| Income doctor filter `DropdownButton` | ❌ none | Sets doctor filter |
| Profile `TextField` Clinic Name | ❌ none | Sets name |
| Profile `ElevatedButton` "Save" | ❌ none | Updates `users` row |

---

## 34. LocationPickerScreen

**File:** `lib/features/doctor/location_picker_screen.dart`  
**Widget:** `LocationPickerScreen` (StatefulWidget)

| Widget | Key | Action |
|---|---|---|
| `flutter_map` tap handler | ❌ none | Places marker at tapped `LatLng` |
| `FloatingActionButton` "My Location" | ❌ none | `Geolocator.getCurrentPosition()` → centers map |
| `ElevatedButton` "Save Location" | ❌ none | `Navigator.pop(context, selectedLatLng)` |
| `TextButton` "Cancel" | ❌ none | `Navigator.pop(context, null)` |

---

## 35. Dialogs & Bottom Sheets (shared)

### Logout AlertDialog (DoctorDashboardScreen, PatientDashboardScreen)

| Widget | Key | Action |
|---|---|---|
| `TextButton` "Cancel" | ❌ none | Closes dialog |
| `TextButton` "Sign Out" | ❌ none | `Supabase.instance.client.auth.signOut()` |

### Delete Account Confirmation

| Widget | Key | Action |
|---|---|---|
| `TextButton` "Cancel" | ❌ none | Closes dialog |
| `ElevatedButton` "Delete" | ❌ none | Deletes auth user + Supabase row |

### Import Help Sheet

Read-only guide. No interactive elements beyond close gesture.

---

## 36. Keys to Add

These are all interactive widgets **missing a `Key`**. Adding keys is a prerequisite for stable `find.byKey()` finders in integration tests. Every element below needs one before Phase 3 tests can be written reliably.

Proposed convention: `Key('widget_screen_descriptor')`, e.g. `Key('login_email_field')`.

### LoginScreen

| Widget | Proposed key |
|---|---|
| Email TextField | `Key('login_email_field')` |
| Password TextField | `Key('login_password_field')` |
| Password visibility toggle | `Key('login_password_toggle')` |
| Sign In button | `Key('login_sign_in_btn')` |
| Continue as Guest button | `Key('login_guest_btn')` |
| Request an account button | `Key('login_request_account_btn')` |
| Forgot password button | `Key('login_forgot_password_btn')` |
| PhysioGate InkWell | `Key('login_physiogate_tile')` |
| Language toggle | `Key('login_language_toggle')` |

### Admin Dashboard

| Widget | Proposed key |
|---|---|
| BottomNavBar / NavigationRail | `Key('admin_nav')` |
| Doctor search TextField | `Key('admin_doctor_search')` |
| Register: Name field | `Key('admin_register_name')` |
| Register: Email field | `Key('admin_register_email')` |
| Register: Password field | `Key('admin_register_password')` |
| Register: Specialization field | `Key('admin_register_specialization')` |
| Register: Create button | `Key('admin_register_btn')` |
| Notes: Title field | `Key('admin_notes_title')` |
| Notes: Body field | `Key('admin_notes_body')` |
| Notes: Send button | `Key('admin_notes_send_btn')` |

### Doctor Dashboard

| Widget | Proposed key |
|---|---|
| Home grid tile (per index) | `Key('doctor_home_tile_$idx')` |
| AI sparkle button | `Key('doctor_ai_btn')` |
| Notifications header button | `Key('doctor_notif_btn')` |
| Profile avatar | `Key('doctor_profile_avatar')` |
| Bottom nav (mobile) | `Key('doctor_bottom_nav')` |
| Schedule FAB | `Key('doctor_schedule_fab')` |
| Documentation FAB | `Key('doctor_docs_fab')` |
| My Patients "New Patient" button | `Key('doctor_patients_new_btn')` |
| Profile: Save button | `Key('doctor_profile_save_btn')` |
| Profile: Sign Out button | `Key('doctor_profile_signout_btn')` |
| Profile: Delete Account button | `Key('doctor_profile_delete_btn')` |

### SoapNoteScreen

| Widget | Proposed key |
|---|---|
| AI Assist button | `Key('soap_ai_btn')` |
| Save button | `Key('soap_save_btn')` |
| Template chip/dropdown | `Key('soap_template_selector')` |
| Chief Complaint field | `Key('soap_chief_complaint')` |
| Pain Level field | `Key('soap_pain_level')` |
| Clinical Impression field | `Key('soap_clinical_impression')` |
| Interventions field | `Key('soap_interventions')` |

### CreatePatientScreen

| Widget | Proposed key |
|---|---|
| Name field | `Key('create_patient_name')` |
| Email field | `Key('create_patient_email')` |
| Password field | `Key('create_patient_password')` |
| Phone field | `Key('create_patient_phone')` |
| Date of Birth field | `Key('create_patient_dob')` |
| Diagnosis field | `Key('create_patient_diagnosis')` |
| Create Account button | `Key('create_patient_submit_btn')` |

### Patient Dashboard

| Widget | Proposed key |
|---|---|
| Grid tile (per index) | `Key('patient_grid_tile_$idx')` |
| My Exercises banner | `Key('patient_exercises_tile')` |
| My Profile banner | `Key('patient_profile_tile')` |
| Book button (no-appointment banner) | `Key('patient_book_btn')` |
| View Details button (appointment card) | `Key('patient_view_appt_btn')` |

### BillingScreen

| Widget | Proposed key |
|---|---|
| Add Income button | `Key('billing_add_income_btn')` |
| Export Excel button | `Key('billing_export_btn')` |
| AI Analysis button | `Key('billing_ai_btn')` |
| Period dropdown | `Key('billing_period_dropdown')` |

### ExpensesScreen

| Widget | Proposed key |
|---|---|
| FAB | `Key('expenses_fab')` |
| Export button | `Key('expenses_export_btn')` |
| AI Analysis button | `Key('expenses_ai_btn')` |

### HepProgramListScreen

| Widget | Proposed key |
|---|---|
| FAB "New Program" | `Key('hep_list_fab')` |

### HepBuilderView

| Widget | Proposed key |
|---|---|
| Title field | `Key('hep_builder_title')` |
| Description field | `Key('hep_builder_description')` |
| Add exercise button | `Key('hep_builder_add_exercise_btn')` |
| Save button | `Key('hep_builder_save_btn')` |

### FindDoctorsScreen

| Widget | Proposed key |
|---|---|
| Search field | `Key('find_doctors_search')` |

### FinancialAiChatScreen

| Widget | Proposed key |
|---|---|
| Message input | `Key('ai_chat_input')` |
| Send button | `Key('ai_chat_send_btn')` |

### PolyclinicDashboardScreen

| Widget | Proposed key |
|---|---|
| Add Doctor FAB | `Key('polyclinic_add_doctor_fab')` |
| Profile Save button | `Key('polyclinic_profile_save_btn')` |

---

## Known Issue — Admin "New" Chip → Wrong Index Bug

From the codebase notes, the admin dashboard `_doctorsSummaryCard` "New" button was updated from `animateTo(0)` to `animateTo(3)` during the polyclinic addition (Register tab moved from index 2 to index 3). This is a **scheduled Phase 5 fix**. The integration test for admin tab navigation should assert the "New" chip navigates to the Register tab (index 2 in the 6-tab layout, which is the third tab). **Do not silently fix — flag as a known bug in the test report.**

---

*End of Phase 1 inventory. Review complete before proceeding to Phase 2 (add missing keys).*
