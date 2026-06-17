# PhysioConnect — Manual Testing Checklist

This checklist covers every interactive feature and button across all four roles (Doctor, Patient, Admin, Polyclinic) on both **Desktop** and **Mobile** layouts. Use it to systematically verify the app before repackaging/release.

## How to Use This Checklist

- **Desktop layout**: window ≥ 600px wide. Test at ~1400×900 — run `flutter run -d chrome` (maximized) or `-d windows`.
- **Mobile layout**: window < 600px wide. Test at ~390×844 — resize the Chrome window, or use Chrome DevTools device toolbar set to a phone (e.g. "iPhone 13"). The breakpoint constant is `kMobileBreakpoint = 600` (`lib/core/constants/breakpoints.dart`), enforced via `FormFactorFeatures`.
- **Language**: the app supports English and Arabic with full RTL layout, toggled via the globe/language icon on the Login screen and most dashboard headers. For items marked as layout/RTL-sensitive, repeat the test in Arabic.
- Each item has:
  - **Platform** — Desktop only / Mobile only / Both (+ layout differences)
  - **Location** — where to find it in the app
  - **Expected Behavior** — what should happen
  - **Test Steps** — how to test it manually
  - **Edge Cases / Notes** — validation rules, empty states, error handling, things to double-check
- Tick off `[ ]` → `[x]` as you go, and jot down any deviation directly under the relevant item.

## Roles Needed for Full Coverage

- **Doctor** account — ideally one Basic-tier, one Premium-tier, and one polyclinic-affiliated doctor
- **Patient** account — plus a guest (no-account) session on mobile
- **Admin** account
- **Polyclinic** account with at least one linked doctor and patients

## Table of Contents

1. Authentication, Onboarding & Global Features
2. Doctor Dashboard — Home, Schedule, Documentation & Notifications
3. Doctor Dashboard — My Patients, My Profile & Polyclinic-Affiliated Doctors
   - My Profile Tab
   - Import Patients & Schedule from Excel (Desktop only)
   - Create Patient Screen ("Add Patient" form)
   - Polyclinic-Affiliated Doctors Tab
4. Doctor Dashboard — Income/Billing, Expenses & Statistics
   - Expenses Tab
   - Statistics Tab (Desktop only)
   - Inventory Screen (not reachable — informational)
5. Patient Dashboard
   - My Appointments (Schedule)
   - My Doctors/Therapists
   - Notifications
   - My Profile
   - Find a Therapist
6. Admin Dashboard
7. Polyclinic Dashboard
8. Physiogate Store — Mobile / Responsive Verification

---
## Authentication, Onboarding & Global Features

### Login Screen
- **Platform**: Both (Desktop and Mobile). Layout differs: on screens ≥900px wide (`isWide`), the card has no horizontal padding and max-width 460px; on narrower screens, 20px horizontal padding and max-width 440px. The "Continue as Guest" button (see below) only renders when `FormFactorFeatures.of(context).showGuestLogin` is true, i.e. width < 600px (mobile).
- **Location**: `lib/features/auth/login_screen.dart` — root screen shown by `AuthGate` in `main.dart` when there is no active Supabase session.

---

### Email / Username Field
- **Platform**: Both
- **Location**: Login Screen > Login Card > first input field (person icon)
- **Expected Behavior**: Animated bordered input box. On focus, border turns green (`#43A047`), background tints light green (`#F1FBF4`), the leading person icon turns green, and a subtle green glow shadow appears. Hint text reads "Email or Username" (English) / "البريد الإلكتروني أو اسم المستخدم" (Arabic). Keyboard type is `emailAddress`. Text direction is RTL when Arabic is active, LTR otherwise. Pressing "Enter"/submit on this field moves focus to the Password field (does not submit the form).
- **Test Steps**:
  1. Tap/click the first input field (person-outline icon, hint "Email or Username").
  2. Observe the focus animation (border/background/icon turn green).
  3. Type an email address.
  4. Press Enter/Return on a physical or on-screen keyboard.
  5. Confirm focus moves to the Password field below.
- **Edge Cases / Notes**: No client-side format validation is performed on this field itself — the only check before submission is that it's non-empty (trimmed). If Arabic language is active, text entry direction is RTL.

---

### Password Field
- **Platform**: Both
- **Location**: Login Screen > Login Card > second input field (lock icon), directly below the Email/Username field
- **Expected Behavior**: Same animated focus styling as the email field (green border/background/icon on focus). Hint text reads "Password" / "كلمة المرور". Text is obscured by default (dots). A text toggle on the right side of the field reads "Show" (English: `s.showPassword`) when obscured or "Hide" (English: `s.hidePassword`) when revealed — in Arabic these are "إظهار" / "إخفاء". Pressing Enter/submit on this field triggers the Sign In action directly.
- **Test Steps**:
  1. Tap/click the Password field (lock-outline icon, hint "Password").
  2. Type a password — confirm characters are masked as dots.
  3. Tap the "Show" text on the right edge of the field — confirm the password becomes visible as plain text and the label changes to "Hide".
  4. Tap "Hide" — confirm the password is masked again and label reverts to "Show".
  5. With both fields filled, press Enter/Return while focused on the Password field — confirm this triggers sign-in (same as tapping the Sign In button).
- **Edge Cases / Notes**: The show/hide toggle is a `GestureDetector` on plain text, not a real `IconButton` — verify it has a large enough tap target on mobile. No password strength/format validation occurs here; only non-empty check is enforced before login is attempted.

---

### Show / Hide Password Toggle
- **Platform**: Both
- **Location**: Login Screen > Login Card > inside Password field, right-aligned suffix
- **Expected Behavior**: Tapping toggles `obscure` state; text label switches between "Show"/"Hide" (or "إظهار"/"إخفاء" in Arabic) and the password's visibility (masked dots vs. plain text) toggles accordingly. Styled as blue (`#1565C0`), bold, 13px text — not an icon.
- **Test Steps**:
  1. Enter text in the Password field.
  2. Tap "Show" — verify the password text becomes readable and label changes to "Hide".
  3. Tap "Hide" — verify the password is masked again and label reverts to "Show".
- **Edge Cases / Notes**: State persists only while the field has content/screen is mounted; navigating away and back resets `obscure` to `true` (default) since it's local widget state.

---

### Forgot Password? Link
- **Platform**: Both
- **Location**: Login Screen > Login Card > right-aligned link below the Password field, above the Sign In button
- **Expected Behavior**: Text reads "Forgot Password?" (English) / "نسيت كلمة المرور؟" (Arabic), blue (`#1565C0`), bold, 13px. Tapping opens a modal dialog titled "Reset Password" / "إعادة تعيين كلمة المرور" containing:
  - A hint text: "Enter your email address and we'll send you a reset link." / "أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين." (gray, 14px)
  - An email input field (autofocused, email keyboard, hint "Email Address" / "البريد الإلكتروني", email-outline prefix icon)
  - Two dialog action buttons: "Cancel" / "إلغاء" (TextButton) and "Send" / "إرسال" (ElevatedButton)
- **Test Steps**:
  1. Tap "Forgot Password?" link.
  2. Confirm the "Reset Password" dialog appears with the hint text and an autofocused email field.
  3. Leave the email field empty (or fill it) and tap "Cancel" — confirm the dialog closes with no further action (no snackbar appears).
  4. Re-open the dialog, enter a valid registered email, and tap "Send".
  5. Confirm the dialog closes and a SnackBar appears with the message "Reset link sent! Check your inbox." / "تم إرسال رابط الإعادة! تحقق من صندوق الوارد." with a green background (`#2E7D32`).
  6. Re-open the dialog, enter an email that triggers a failure (e.g. malformed or causes an error from Supabase), and tap "Send".
  7. Confirm a SnackBar appears with "Could not send reset email. Check the address and try again." / "تعذر إرسال البريد. تحقق من العنوان وحاول مجدداً." with a red background (`#C62828`).
- **Edge Cases / Notes**: The dialog's email field text is trimmed before being passed to `resetPassword`. The success/failure SnackBar is shown regardless of whether the email actually exists in the system (Supabase's `resetPasswordForEmail` does not reveal account existence) — so "sent" may show even for unregistered emails, as long as the call itself doesn't throw. The dialog returns `null`/`false` on Cancel and no reset call is made at all.

---

### Sign In Button
- **Platform**: Both
- **Location**: Login Screen > Login Card > primary button below the "Forgot Password?" link
- **Expected Behavior**: Full-width, 54px tall button with a green gradient background (`#2E7D32` → `#43A047`), rounded corners (14px), and drop shadow. Label reads "Sign In" / "تسجيل الدخول", white, bold, 16px, letter-spacing 0.6. While a login request is in flight, the button area is replaced by a centered `CircularProgressIndicator` (green, stroke width 2.5) and the button itself is hidden.
- **Test Steps**:
  1. Leave both Email/Username and Password fields empty, tap "Sign In".
  2. Confirm nothing happens (no loading indicator, no network call) — the handler returns early if either field is empty.
  3. Enter valid credentials for an existing user (any role) and tap "Sign In".
  4. Confirm the button is replaced by a green circular loading spinner while the request is pending.
  5. On success, confirm the app navigates away from the Login screen to the role-appropriate dashboard (see "AuthGate Role-Based Routing" below) — this happens automatically via the `onAuthStateChange` stream once Supabase establishes a session.
  6. Enter invalid/incorrect credentials and tap "Sign In".
  7. Confirm the spinner appears briefly, then reverts to the button, and a SnackBar appears with the text "Login failed. Check your credentials." / "فشل تسجيل الدخول. تحقق من بياناتك."
- **Edge Cases / Notes**:
  - Email and password are trimmed before the empty check and before being sent to Supabase (`_emailController.text.trim()`, `_passwordController.text.trim()`).
  - If both fields are empty, `_handleLogin` returns immediately — no loading state, no API call, no error message.
  - On any exception during `signInWithPassword` (network error, bad credentials, etc.), `AuthService.loginAdmin` catches it and returns `null`, which is treated the same as "login failed" — a generic message is shown with no distinction between "wrong password" and "network error".
  - Pressing Enter/Return while focused in the Password field also triggers this same `_handleLogin` flow.

---

### Continue as Guest Button (Mobile Only)
- **Platform**: Mobile only (`FormFactorFeatures.of(context).showGuestLogin` is true when width < 600px). Not present on desktop layouts.
- **Location**: Login Screen > Login Card > below the Sign In button (only rendered on mobile)
- **Expected Behavior**: Full-width, 50px tall `OutlinedButton` with green text (`#2E7D32`) and a light blue border (`#BBD1EA`), rounded corners (14px). Label reads "Continue as Guest" / "المتابعة كزائر". Tapping pushes a new screen: `FindDoctorsScreen(isGuest: true)` — the "Find a Therapist" / doctor search screen in a restricted, account-free preview mode. No Supabase session is created and no data is written.
- **Test Steps**:
  1. On a mobile-width viewport (e.g. 390x844), confirm the "Continue as Guest" button is visible below "Sign In".
  2. On a desktop-width viewport (e.g. 1400x900), confirm this button does NOT appear at all.
  3. Tap "Continue as Guest" (mobile).
  4. Confirm navigation to the Find a Therapist / doctor search screen, in guest mode — browsing and searching for therapists should work normally.
  5. On the guest Find Doctors screen, attempt an action that requires an account, e.g. "Add to My List" on a doctor.
  6. Confirm a dialog titled "Sign In Required" / "تسجيل الدخول مطلوب" appears with body text "Sign in or create an account to book" / "سجّل الدخول أو أنشئ حساباً للحجز", and two actions: "Cancel" / "إلغاء" (closes dialog only) and "Sign In" / "تسجيل الدخول" (closes the dialog AND pops back to the Login screen).
  7. Tap "Sign In" in that dialog — confirm both the dialog and the Find Doctors screen close, returning the user to the Login screen.
- **Edge Cases / Notes**: In guest mode, `_loadLinkedDoctors()` is skipped entirely (no Supabase query), so the "linked doctors" set starts empty and "Add to My List" always routes to the sign-in-required dialog rather than performing the action.

---

### Language Toggle Button
- **Platform**: Both
- **Location**: Login Screen > Login Card > below the Sign In/Guest buttons, above the Privacy Policy link
- **Expected Behavior**: A `TextButton.icon` with a small globe/language icon (`Icons.language_rounded`, 15px, light gray `#CFD8DC`) and label text. The label shows the name of the OTHER language to switch to: when current language is English, label reads "العربية" (Arabic for "Arabic"); when current language is Arabic, label reads "English". Both icon and text are light gray (`#CFD8DC`), 13px. Tapping calls `langProvider.toggle()`, which flips `isArabic`, persists the choice to `SharedPreferences` (`isArabic` key), updates `Intl.defaultLocale`, and triggers `notifyListeners()` — causing the entire app (via `MaterialApp.locale`) to switch locale and direction (RTL for Arabic).
- **Test Steps**:
  1. On first load (assuming default English), confirm the language button shows "العربية" with the globe icon.
  2. Tap the language button.
  3. Confirm the entire Login screen's text switches to Arabic (e.g. "Welcome Back!" becomes "مرحباً بعودتك!"), and the layout shifts to RTL (e.g. the Email field's text direction becomes RTL, and the "Forgot Password?" link / overall alignment may flip).
  4. Confirm the language button's label now reads "English".
  5. Tap again to switch back to English; confirm everything reverts.
  6. Close and relaunch the app (or hot-restart) — confirm the previously selected language persists (loaded from `SharedPreferences`).
- **Edge Cases / Notes**: This toggle is global — it affects the whole app's locale, not just the Login screen. The persisted preference (`isArabic` bool in SharedPreferences) is loaded asynchronously in `LanguageProvider._load()`, so there may be a brief flash of the default language (English) on cold start before the saved preference loads and `notifyListeners()` fires.

---

### Privacy Policy Link
- **Platform**: Both
- **Location**: Login Screen > Login Card > bottom-most element, below the Language toggle
- **Expected Behavior**: A `TextButton` with text "Privacy Policy" / "سياسة الخصوصية", styled gray (`#78909C`), 11px. Tapping opens the URL `https://jihadzhour-dot.github.io/physioconnect-privacy/` in an external browser/application (`LaunchMode.externalApplication`).
- **Test Steps**:
  1. Tap "Privacy Policy" at the bottom of the Login card.
  2. Confirm the device's default browser (or an external app) opens to `https://jihadzhour-dot.github.io/physioconnect-privacy/`.
  3. Confirm the PhysioConnect app remains in the background/unchanged (the link opens externally, not in-app).
- **Edge Cases / Notes**: Required for App Store / Play Store / Microsoft Store compliance per the inline comment. If no browser/app can handle the URL (unlikely), `url_launcher` may throw — verify no crash occurs (not currently caught in code).

---

### AuthGate Role-Based Routing (Post-Login)
- **Platform**: Both (routing logic is platform-agnostic; the notification prompt described separately below is mobile/non-Windows only)
- **Location**: `lib/main.dart` > `AuthGate` widget — the app's `home` widget, wrapping the Login screen and all dashboards
- **Expected Behavior**:
  - `AuthGate` listens to `Supabase.instance.client.auth.onAuthStateChange`.
  - While the auth stream's `ConnectionState` is `waiting`, shows a centered `CircularProgressIndicator` on a blank `Scaffold`.
  - Once resolved, checks `Supabase.instance.client.auth.currentSession`:
    - If **no session**: shows `LoginScreen`.
    - If **session exists**: runs a `FutureBuilder` querying the `users` table for the row where `id = session.user.id` (`.maybeSingle()`).
      - While that query is pending: shows the same centered `CircularProgressIndicator` Scaffold.
      - If the query **errors**: signs the user out (`Supabase.instance.client.auth.signOut()`) and shows `LoginScreen`.
      - If the query returns **no row** (`userData == null`): shows `LoginScreen` (orphaned/incomplete account).
      - If the query returns a row, reads `userData['role']` and routes:
        - `role == 'admin'` → `AdminDashboardScreen`, wrapped in `_WithNotificationPrompt`
        - `role == 'doctor'` → `DoctorDashboardScreen`, wrapped in `_WithNotificationPrompt`
        - `role == 'polyclinic'` → `PolyclinicDashboardScreen`, wrapped in `_WithNotificationPrompt`
        - `role == 'patient'` → `PatientDashboardScreen`, wrapped in `_WithNotificationPrompt`
        - Any other/unrecognized role string (including empty `''`) → falls through to `LoginScreen`
- **Test Steps**:
  1. Log in as a user with role `admin` — confirm landing on the Admin dashboard.
  2. Log in as a user with role `doctor` — confirm landing on the Doctor dashboard.
  3. Log in as a user with role `polyclinic` — confirm landing on the Polyclinic dashboard.
  4. Log in as a user with role `patient` — confirm landing on the Patient dashboard.
  5. (If testable) Log in as a user whose `users` row has been deleted or has a `null`/unrecognized `role` value — confirm the app falls back to the Login screen rather than crashing or showing a blank dashboard.
  6. Force a Supabase session to exist but make the `users` table query fail (e.g. simulate a network/RLS error) — confirm the app signs the user out and returns to the Login screen rather than getting stuck on the loading spinner.
  7. From any dashboard, trigger a logout — confirm `AuthGate` reacts to the auth state change and returns to `LoginScreen`.
- **Edge Cases / Notes**:
  - Routing is driven by a live `StreamBuilder`, so any auth state change (sign-in, sign-out, token refresh that invalidates session) re-evaluates this entire tree.
  - The `FutureBuilder` re-runs its query on every rebuild of `AuthGate` triggered by the stream (each query is a fresh `.from('users').select()...maybeSingle()` call) — repeated auth state events could cause repeated user-row fetches.
  - A `role` value of `''` (empty string, the fallback when `userData['role']` is null) does not match any of the four role checks, so it silently routes to `LoginScreen` with no error message shown to the user.

---

### Notification Permission Prompt Dialog (Mobile/Non-Windows Only)
- **Platform**: Mobile only — specifically gated by `!kIsWeb && !Platform.isWindows` (so: Android, iOS, macOS, Linux native builds; explicitly NOT shown on web or Windows desktop builds)
- **Location**: Appears automatically ~3 seconds after first landing on ANY of the four dashboards (Admin, Doctor, Polyclinic, Patient), via `_WithNotificationPrompt` wrapper in `lib/main.dart`
- **Expected Behavior**:
  - 3 seconds after `_WithNotificationPrompt.initState()` runs (i.e., after the dashboard widget is built/mounted), a non-dismissible (`barrierDismissible: false`) `AlertDialog` appears:
    - Title: "Stay Updated" / "ابقَ على اطلاع"
    - Body: "PhysioConnect sends reminders for upcoming sessions and new clinical notes from your care team." / "يرسل فيزيو كونكت تذكيرات بالجلسات القادمة والملاحظات السريرية الجديدة من فريق رعايتك."
    - Two actions:
      - "Not Now" / "ليس الآن" (`TextButton`) — closes the dialog, returns `false`/none; no permission request is made.
      - "Allow" / "السماح" (`ElevatedButton`) — closes the dialog, returns `true`, then proceeds to request OS-level notification permissions (iOS: `requestPermissions(alert: true, badge: true, sound: true)` via `IOSFlutterLocalNotificationsPlugin`; Android: `requestNotificationsPermission()` via `AndroidFlutterLocalNotificationsPlugin`).
  - On web or Windows, this entire flow is skipped — `_WithNotificationPromptState.initState()` does not schedule the delayed call at all.
- **Test Steps**:
  1. On a mobile (Android/iOS) build, log in as any role and land on its dashboard.
  2. Wait ~3 seconds.
  3. Confirm the "Stay Updated" dialog appears, is non-dismissible by tapping outside or back-button (per `barrierDismissible: false`), and shows the body text described above.
  4. Tap "Not Now" — confirm the dialog closes and no OS permission prompt appears.
  5. Repeat login (new session / app restart) and this time tap "Allow" — confirm the dialog closes, and the native OS notification-permission prompt appears (on iOS/Android), reflecting the underlying plugin's permission request.
  6. On a web build (Chrome) or Windows desktop build, log in and land on any dashboard — confirm this dialog NEVER appears, at any point.
- **Edge Cases / Notes**:
  - The prompt fires once per `_WithNotificationPrompt` mount — i.e., once per "landing on a dashboard" (e.g., after each fresh login or hot navigation that remounts the dashboard's wrapper), not just once per app lifetime. If the widget tree is rebuilt (e.g., role changes, or `AuthGate` re-renders the dashboard), the 3-second timer and dialog could fire again.
  - If the widget is unmounted before the 3-second delay completes (e.g., user logs out quickly), `_promptIfNeeded` checks `mounted` and returns early without showing the dialog.
  - `NotificationService.initialize()` (called once in `main()`, also gated by `!kIsWeb && !Platform.isWindows`) does NOT request permissions itself — it explicitly avoids requesting iOS alert/badge/sound permissions at init time so this rationale dialog can be shown first.

---

## Doctor Dashboard — Home, Schedule, Documentation & Notifications

---

### Home Landing Screen
- **Platform**: Both (Desktop: 4-column tile grid, full footer with name/clinic + "Logout" text button; Mobile: 2-column tile grid, condensed footer with ellipsized name/clinic + icon-only Logout button)
- **Location**: Doctor > Home (default landing screen after login; reached via the home/back icon)
- **Expected Behavior**: Shows a header with doctor's photo (or placeholder person icon on grey background), "Welcome, {Dr. }{Name}!" text, specialization chip (if set), a language toggle, and a grid of navigation tiles. Footer shows doctor name + clinic name and a Logout control.
- **Test Steps**:
  1. Log in as a doctor and confirm the Home screen loads with header gradient (dark blue), photo on the right.
  2. Resize/rotate to verify grid switches from 4 columns (width > 600) to 2 columns (width <= 600).
  3. Verify footer adapts: desktop shows full Row with "Logout" label; mobile shows ellipsized name/clinic and icon-only logout button that still fits without overflow.
- **Edge Cases / Notes**: If `_specCtrl` (specialization) is empty, the chip is hidden. If photo URL is empty, shows person icon placeholder. On mobile, Documentation and Statistics tiles are hidden from the grid (see `_buildHomeTile` visibility logic via `showDocumentation`/`showStatistics`).

---

### Header — Welcome Text & Doctor Name
- **Platform**: Both
- **Location**: Doctor > Home > Header (top-left)
- **Expected Behavior**: Displays "Welcome," then "{Dr. }{Name}!" — the "Dr." prefix only shows if `_showDrPrefix` is true AND role is not polyclinic. If `_nameCtrl.text` is empty, defaults to "Doctor".
- **Test Steps**:
  1. As a doctor with `show_dr_prefix = true`, confirm name shows "Dr. {Name}!".
  2. As a polyclinic-role user, confirm "Dr." prefix is never shown regardless of `_showDrPrefix`.
- **Edge Cases / Notes**: Specialization badge (pill) only renders `if (spec.isNotEmpty)`.

---

### Language Toggle (Home Header)
- **Platform**: Both
- **Location**: Doctor > Home > Header, top-right area (offset left of the doctor photo)
- **Expected Behavior**: Tapping toggles app language between English/Arabic; label text reads `s.language`. Whole app switches to RTL layout when Arabic is selected.
- **Test Steps**:
  1. Tap the language icon/button in the header.
  2. Verify text direction flips to RTL and all strings switch to Arabic equivalents.
  3. Toggle back to English and confirm LTR layout restores.
- **Edge Cases / Notes**: Same toggle also appears in the top AppBar (`actions`) once inside a section screen — both should stay in sync.

---

### Home Tile — Schedule / Documentation / My Patients / Statistics / Billing / Expenses / My Profile / Notifications
- **Platform**: Both (Documentation and Statistics tiles hidden on Mobile entirely)
- **Location**: Doctor > Home > Tile grid
- **Expected Behavior**: Each tile shows an icon, title, and colored background. Tapping navigates to that section (`_currentIndex` set, `_showHome = false`). Locked tiles (based on subscription tier) show a reduced-opacity icon/title plus a small lock badge in the top-right corner. The "Notifications" tile additionally shows a red unread-count badge (e.g. "3" or "99+") in the top-right corner when `_doctorUnreadCount > 0`.
- **Test Steps**:
  1. Tap each visible tile and confirm navigation to the corresponding tab with the AppBar title matching the section name.
  2. As a doctor on a tier where Statistics/Billing/Expenses are locked, confirm those tiles show the lock icon overlay and tapping them still navigates but shows the Locked screen (see "Locked Feature Screen" below).
  3. Trigger a new notification (e.g. have admin send one, or have a patient request an appointment) and confirm the Notifications tile shows a red badge with the count; badge shows "99+" if count > 99.
  4. On mobile (width < 600), confirm Documentation and Statistics tiles are entirely absent from the grid (not just locked/greyed).
- **Edge Cases / Notes**: Tile visibility filter: `(i != 3 || showStats) && (i != 1 || showDocs)` — index 3 = Statistics, index 1 = Documentation.

---

### Home Footer — Doctor Name/Clinic + Logout (Desktop)
- **Platform**: Desktop only
- **Location**: Doctor > Home > Footer (bottom bar, dark blue)
- **Expected Behavior**: Shows a heart-monitor icon, "{Dr. }{Name}  {Clinic Name}" (clinic name dimmed), then a Spacer, then a "Logout" text button with logout icon.
- **Test Steps**:
  1. Confirm footer text shows correct doctor name and clinic name (defaults to "PT Clinic" if `_clinicNameCtrl` is empty).
  2. Tap "Logout" and confirm the logout confirmation dialog appears (see "Logout Confirmation Dialog").
- **Edge Cases / Notes**: If the clinic/doctor name text is very long, this Row can overflow at narrow widths — this is exactly why the mobile variant exists.

---

### Home Footer — Doctor Name/Clinic + Logout (Mobile)
- **Platform**: Mobile only
- **Location**: Doctor > Home > Footer (bottom bar, dark blue, compact)
- **Expected Behavior**: Same content as desktop footer but the identity text (name + clinic) is constrained to a single ellipsized line inside an `Expanded`, and Logout is an icon-only button (`Icons.logout_rounded`, tooltip "Logout") with zero padding so the row never overflows at ~390px width.
- **Test Steps**:
  1. At 390x844 viewport, confirm the footer row fits without horizontal overflow even with a long doctor name and clinic name.
  2. Tap the logout icon and confirm the same logout confirmation dialog appears as on desktop.
- **Edge Cases / Notes**: Long name/clinic text truncates with an ellipsis rather than wrapping or overflowing.

---

### Logout Confirmation Dialog
- **Platform**: Both
- **Location**: Doctor > Home footer "Logout" (desktop) / logout icon (mobile), OR AppBar logout icon inside any section screen
- **Expected Behavior**: AlertDialog with title `s.logout`, content `s.areYouSure`, and two actions: "Cancel" (closes dialog, no action) and `s.signOut` (styled in error/red color) which signs the user out via Supabase auth and returns to the login screen.
- **Test Steps**:
  1. Tap any Logout control.
  2. Confirm dialog appears with title/body text and Cancel + Sign Out buttons.
  3. Tap Cancel — dialog closes, no navigation occurs.
  4. Tap Logout again, tap Sign Out — confirm app signs out and returns to the login/auth screen.
- **Edge Cases / Notes**: None notable.

---

### AppBar — Home Icon (Back to Home)
- **Platform**: Both
- **Location**: Doctor > any section screen (Schedule/Documentation/etc.) > AppBar leading icon
- **Expected Behavior**: Tapping the `Icons.home_rounded` leading icon (tooltip "Home") returns to the Home landing screen (`_goHome`, sets `_showHome = true`).
- **Test Steps**:
  1. Navigate into any section (e.g. Schedule).
  2. Tap the home icon in the top-left of the AppBar.
  3. Confirm the Home landing screen with tile grid reappears.
- **Edge Cases / Notes**: None.

---

### AppBar — Language Toggle (Section Screens)
- **Platform**: Both
- **Location**: Doctor > any section screen > AppBar actions (text button with language icon, labeled `s.language`)
- **Expected Behavior**: Same as the Home header language toggle — switches app language/direction.
- **Test Steps**:
  1. From within a section screen (e.g. Schedule), tap the language toggle in the AppBar.
  2. Confirm UI text and layout direction switch correctly while staying on the same section.
- **Edge Cases / Notes**: None.

---

### AppBar — Logout Icon (Section Screens)
- **Platform**: Both
- **Location**: Doctor > any section screen > AppBar actions (rightmost `Icons.logout_rounded` icon button)
- **Expected Behavior**: Opens the Logout Confirmation Dialog (see above).
- **Test Steps**:
  1. From any section screen, tap the logout icon in the AppBar.
  2. Confirm the confirmation dialog appears as described above.
- **Edge Cases / Notes**: None.

---

### Navigation Drawer (Hamburger Menu)
- **Platform**: Both (opened via the Scaffold's default drawer mechanism — swipe from left edge or AppBar drawer icon, automatically shown by Flutter when a `drawer` is set)
- **Location**: Doctor > any section screen > left-side Drawer
- **Expected Behavior**: Drawer header shows a white circle avatar with `Icons.accessibility_new_rounded`, doctor's name (or `s.doctorDashboard` if empty), and the app name (`s.appName`). Below, a scrollable list of nav items (Schedule, Documentation*, My Patients, Statistics*, Billing, Expenses, My Profile, Notifications, and "My Doctors" if polyclinic role). Each item shows its icon, label, and is highlighted (light primary-color background + bold primary-color text) when selected. Locked items show a small grey lock badge on the icon and a "Locked" pill on the trailing side; locked items are not marked `selected` even if their index matches `_currentIndex`. Tapping any item calls `_navigateTo(i)`, which sets `_currentIndex`, clears `_showHome`, and pops the drawer.
- **Test Steps**:
  1. Open the drawer (swipe from left edge or tap drawer icon if present).
  2. Confirm header shows correct doctor name and app name.
  3. Tap each visible nav item; confirm the corresponding tab loads and the drawer closes.
  4. For a locked item (e.g. Statistics/Billing/Expenses depending on tier), confirm it shows the lock badge + "Locked" pill, and tapping it navigates to the Locked Feature Screen (not highlighted as selected).
  5. On mobile, confirm Documentation and Statistics entries are entirely absent from the list (filtered via `showDocumentation`/`showStatistics`).
  6. As a polyclinic-role doctor, confirm an extra "My Doctors" entry appears at the end with `Icons.manage_accounts_rounded`.
- **Edge Cases / Notes**: Drawer item visibility uses the same `visibleIndices` filter as the Home tile grid (index 1 = Documentation, index 3 = Statistics).

---

### Locked Feature Screen (Statistics / Income / Expenses)
- **Platform**: Both (shown in place of Statistics, Billing/"Income", or Expenses tab content when the doctor's subscription tier doesn't meet the requirement)
- **Location**: Doctor > Statistics tab (requires `SubTier.premium`) / Doctor > Billing tab ("Income", requires `SubTier.premium`) / Doctor > Expenses tab (requires `SubTier.premium`)
- **Expected Behavior**: Centered layout with a circular icon background (tinted to the required tier's color) containing a lock icon, the feature name as a bold title, explanatory text ("This feature requires the {Tier} plan or higher.\nContact your admin to upgrade your subscription."), and a pill showing the required tier's icon + "{Tier} Plan Required".
- **Test Steps**:
  1. As a doctor on a tier below Premium, navigate to Statistics, Billing, and Expenses tabs (via Home tiles or drawer).
  2. For each, confirm the Locked screen renders with the correct feature name ("Statistics", "Income", "Expenses") and the correct required tier label/color/icon.
  3. Upgrade the subscription tier (via admin) and confirm the real screen content now renders instead.
- **Edge Cases / Notes**: On mobile, Statistics is additionally gated by `showStatistics` (desktop-only) — the "Available on Desktop" screen takes precedence over the Locked screen for Statistics on mobile (checked first in the IndexedStack: `!showStatistics ? AvailableOnDesktop : _isLocked(3) ? Locked : SessionStatsScreen`).

---

### "Available on Desktop" Screen (Documentation / Statistics on Mobile)
- **Platform**: Mobile only (this screen/notice only appears when viewport width < 600px)
- **Location**: Doctor > Documentation tab (if somehow navigated to on mobile) / Doctor > Statistics tab (on mobile)
- **Expected Behavior**: Centered notice with a circular icon background containing `Icons.desktop_windows_rounded`, the feature name as a bold title, and the text "Available on desktop".
- **Test Steps**:
  1. On a mobile viewport (390x844), verify there is NO Documentation entry anywhere (no Home tile, no drawer entry) — it should be impossible to reach this tab via normal navigation.
  2. If reached via deep link or by resizing from desktop to mobile while already on the Documentation/Statistics tab, confirm the "Available on Desktop" notice renders instead of the real tab content.
  3. Resize back to desktop width and confirm the real Documentation/Statistics content renders again.
- **Edge Cases / Notes**: This is a fallback/defensive UI — primary verification is that mobile has NO way to navigate here in the first place (no Home tile, no drawer entry, per `FormFactorFeatures.showDocumentation` / `showStatistics`).

---

### Notifications Tab — Header (Unread Count / "Mark all read")
- **Platform**: Both
- **Location**: Doctor > Notifications tab > top header bar
- **Expected Behavior**: If there are unread notifications, shows a purple pill "{N} unread". If zero unread, shows grey text "All caught up". A "Mark all read" text button appears on the right only when `unreadCount > 0`; tapping it marks every unread notification's `read` field to `true` in Supabase.
- **Test Steps**:
  1. With unread notifications present, confirm the "{N} unread" pill displays the correct count and "Mark all read" button is visible.
  2. Tap "Mark all read" and confirm all notification cards lose their unread styling (purple background, bold title, purple dot) and the header updates to "All caught up" with the button disappearing.
  3. With zero notifications/unread, confirm "All caught up" text shows and no button is present.
- **Edge Cases / Notes**: Updates happen one-by-one via sequential `update` calls per notification id — with many notifications this could be slow but there's no loading indicator on the button itself.

---

### Notifications Tab — Appointment Requests Card (embedded)
- **Platform**: Both
- **Location**: Doctor > Notifications tab > top of scrollable content (also embedded at top of Schedule tab on mobile — see `_buildPendingRequestsCard` below)
- **Expected Behavior**: Same `_buildPendingRequestsCard` widget as on the Schedule tab; shows pending appointment requests with Accept/Decline actions. Renders as `SizedBox.shrink()` (nothing) if there are no pending requests.
- **Test Steps**: See "Pending Appointment Requests Card" below for full test steps (shared component).
- **Edge Cases / Notes**: Appears above the notification list/empty-state in the Notifications tab.

---

### Notifications Tab — Empty State
- **Platform**: Both
- **Location**: Doctor > Notifications tab > content area (when `notifs.isEmpty`)
- **Expected Behavior**: Centered icon (`Icons.notifications_none_rounded`, large, light grey) with text "No notifications yet".
- **Test Steps**:
  1. As a doctor with zero notifications (and zero pending appointment requests), open the Notifications tab.
  2. Confirm the empty-state icon and "No notifications yet" text are centered below the pending-requests card area.
- **Edge Cases / Notes**: The pending requests card still renders above this (as `SizedBox.shrink()` if empty, so visually nothing extra appears).

---

### Notification Card (`_notifCard`)
- **Platform**: Both
- **Location**: Doctor > Notifications tab > notification list (sorted newest first by `created_at`)
- **Expected Behavior**: Each card shows a leading icon in a tinted box (icon/color varies by `type`: `patient_added_you` → person-add/blue; `appointment_request`/`appointment_reschedule` → event/orange; `admin` → admin-panel/teal; default → bell/purple), the notification title (bold if unread), body text (if present), and a formatted timestamp ("MMM d, h:mm a"). Unread cards have a light-purple background, elevation 1, and a small purple dot next to the title. Tapping an unread card marks it `read: true` (removing the unread styling); tapping a read card does nothing.
- **Test Steps**:
  1. Trigger notifications of each type (patient added, appointment request/reschedule, admin notification, generic) and confirm each shows the correct icon and color.
  2. Confirm unread cards show bold title, purple dot, and light-purple background with elevation.
  3. Tap an unread card; confirm it transitions to read styling (white background, no dot, normal weight) without navigating anywhere.
  4. Confirm read cards are not tappable/interactive (no visual feedback, `onTap: null`).
- **Edge Cases / Notes**: If `body` is empty, that line is omitted. If `created_at` is missing/unparsable, the timestamp line is omitted.

---

### Schedule Tab — Overall Layout
- **Platform**: Both (Desktop ≥680px wide: side-by-side calendar card + appointments panel in a Row; Mobile/narrow <680px: stacked vertically in a scroll view, with the Pending Requests Card shown above the calendar)
- **Location**: Doctor > Schedule tab (Home tile index 0 / drawer "Schedule")
- **Expected Behavior**: Shows a loading spinner while appointments stream connects, then renders the calendar and appointments panel per the layout rule above.
- **Test Steps**:
  1. Open Schedule tab; confirm a `CircularProgressIndicator` briefly shows on first load (connectionState waiting).
  2. At width > 680px, confirm calendar (fixed 340px wide) and appointments panel sit side by side in a Row with 16px padding/gap, both starting at the top.
  3. At width <= 680px, confirm content stacks: Pending Requests Card (if any), then Calendar Card, then Appointments Panel, in a single scroll view.
- **Edge Cases / Notes**: On wide layout, the Pending Requests Card is NOT shown separately above the calendar (it's only embedded inside the Notifications tab) — confirm this difference between wide and narrow layouts.

---

### Pending Appointment Requests Card
- **Platform**: Both
- **Location**: Doctor > Schedule tab (mobile/narrow layout, above the calendar) AND Doctor > Notifications tab (top of list)
- **Expected Behavior**: If there are pending `appointment_requests` for this doctor, shows a card titled "Appointment Requests ({count})" with an orange pending-actions icon. Each request shows: patient name, phone (if available, tappable to open Call/WhatsApp options, shown in green with underline), requested date/time ("EEE, MMM d – h:mm a" or "—" if null), notes (if any), and two buttons: "Decline" (outlined, red/error styled) and "Accept" (filled, primary blue). If there are no pending requests, the card renders nothing (`SizedBox.shrink()`).
- **Test Steps**:
  1. As a patient, submit an appointment request to this doctor.
  2. As the doctor, confirm the card appears with correct count, patient name, phone (if set), requested time, and notes.
  3. Tap "Decline" — confirm the request's status updates to "declined" and the card disappears/count decrements (no snackbar shown for decline).
  4. Submit another request; tap "Accept" — confirm: the appointment is booked via `_service.bookAppointment`, the request status updates to "accepted", a green success SnackBar "Appointment confirmed!" appears, and the card disappears/count decrements.
  5. Tap the phone number (if shown) and confirm the Call/WhatsApp bottom sheet opens (see "Phone / WhatsApp Options Sheet").
  6. With zero pending requests, confirm the card section takes up no visual space.
- **Edge Cases / Notes**: If `reqTime` is null, "Accept" does nothing (`if (dt == null) return;` — silently no-ops, no error shown — worth flagging as a potential edge case to verify). Phone is fetched via a separate `FutureBuilder` per request from the `users` table.

---

### Calendar Card — Month Header & Navigation
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Calendar Card (top bar, dark blue `#1A3A5C`)
- **Expected Behavior**: Shows the current month/year ("MMMM yyyy", e.g. "June 2026") centered, with a `chevron_right_rounded` icon button on the right that advances the month by +1 (`_changeCalMonth(1)`). Note: there is no `chevron_left` in the header itself — only a right-pointing chevron, which still moves forward.
- **Test Steps**:
  1. Note the current month/year displayed.
  2. Tap the chevron icon in the header; confirm the month advances by one and the day grid updates (dots on days with appointments recompute for the new month).
  3. Confirm `_calDay` auto-updates: if the new month is the current real-world month, `_calDay` resets to today's date; otherwise it resets to day 1 of the new month.
- **Edge Cases / Notes**: This header chevron only goes forward — backward navigation is via the "<<" button at the bottom (see below). This asymmetry (right-pointing arrow in header that's the only header nav, only moves forward) is worth specifically verifying as it may look like a UI inconsistency.

---

### Calendar Card — Day Grid
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Calendar Card > day-of-week headers (Sun–Sat) + 7-column day grid
- **Expected Behavior**: Renders a 7-column grid (Sunday-first) with empty cells padding the first week to align the 1st of the month under its correct weekday. Each day cell is tappable: tapping sets `_calDay` to that date (highlighted with a dark-blue filled circle, white bold text). Today's date (if not selected) shows a light-blue tinted circle with bold dark-blue text. Days that have at least one appointment show a small dot below the day number (unless that day is the selected day).
- **Test Steps**:
  1. Confirm the day-of-week row reads Sun, Mon, Tue, Wed, Thu, Fri, Sat and the grid below aligns correctly (e.g. if the 1st falls on a Wednesday, the first 3 cells of the grid are blank).
  2. Tap a date with no appointments; confirm it becomes the selected day (dark-blue circle) and the Appointments Panel below/right updates to show "No appointments on this date." (or "No appointments scheduled for today." if it's today).
  3. Tap a date that has appointments (shown with a small dot); confirm the dot is present before selection, disappears once selected (since selected days don't show the dot), and the panel lists that day's appointments.
  4. Confirm today's date (if not the selected day) shows the light-blue "today" tint distinct from the selected-day dark-blue fill.
- **Edge Cases / Notes**: The dot indicator and "today" tint and "selected" fill can theoretically overlap on the same day — confirm precedence (selected fill takes priority visually; dot is hidden `if (hasAppt && !isSel)`).

---

### Calendar Card — "Today" Button
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Calendar Card > bottom row, leftmost button (outlined, "Today")
- **Expected Behavior**: Tapping resets both `_calMonth` and `_calDay` to the current real-world date, regardless of what month/day was previously shown.
- **Test Steps**:
  1. Navigate the calendar to a different month (e.g. via "<<" / ">>" or header chevron) and select a different day.
  2. Tap "Today".
  3. Confirm the calendar jumps back to the current month and the current day becomes selected (highlighted).
- **Edge Cases / Notes**: None.

---

### Calendar Card — "<<" / ">>" Month Navigation Buttons
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Calendar Card > bottom row, two small outlined buttons labeled "<<" and ">>"
- **Expected Behavior**: "<<" calls `_changeCalMonth(-1)` (previous month); ">>" calls `_changeCalMonth(1)` (next month, same action as the header chevron). Both update `_calMonth` and adjust `_calDay` as described in `_changeCalMonth` (resets to today if landing on the current month, else day 1).
- **Test Steps**:
  1. Tap "<<"; confirm the month decreases by one and the day grid/appointment dots update accordingly.
  2. Tap ">>"; confirm the month increases by one (same behavior as the header chevron).
  3. Navigate several months back then use "Today" to confirm it returns correctly.
- **Edge Cases / Notes**: ">>" duplicates the header chevron's functionality — both should behave identically.

---

### Appointments Panel — Header (Selected Date)
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Appointments Panel, top section
- **Expected Behavior**: Shows a calendar icon, the selected date formatted "EEEE, MMMM d, yyyy" (e.g. "Sunday, June 14, 2026"), and a subtitle: "Today's Schedule" if `_calDay` is today, else "Appointments".
- **Test Steps**:
  1. With today selected, confirm subtitle reads "Today's Schedule".
  2. Select a different date; confirm subtitle changes to "Appointments" and the date line updates.
- **Edge Cases / Notes**: None.

---

### Appointments Panel — "Add Appointment" Button
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Appointments Panel, action row below the header
- **Expected Behavior**: Filled button (dark blue `#1A3A5C`, white text/icon, `Icons.add_rounded`) labeled with `s.addAppointment` (e.g. "Add Appointment"). Tapping opens the "Book Appointment" bottom sheet (see below).
- **Test Steps**:
  1. Tap "Add Appointment".
  2. Confirm the booking bottom sheet opens (see "Book Appointment Sheet").
- **Edge Cases / Notes**: This button is always full-width when Import/Format buttons are hidden (mobile); shares the row with them on desktop.

---

### Appointments Panel — "Import" Button (Excel)
- **Platform**: Desktop only (`FormFactorFeatures.showScheduleImportExport`)
- **Location**: Doctor > Schedule tab > Appointments Panel, action row (next to "Add Appointment")
- **Expected Behavior**: Compact green button (`#2E7D32`) with `Icons.upload_file_rounded` and label "Import". Tapping triggers `_importScheduleFromExcel(s)`, opening a file picker to import an Excel schedule.
- **Test Steps**:
  1. On desktop, confirm "Import" button is visible next to "Add Appointment".
  2. Tap it; confirm a file picker dialog opens for selecting an Excel file.
  3. On mobile (width < 600), confirm this button is NOT present.
- **Edge Cases / Notes**: Verify there is no "Import" button on mobile — this is gated by `showScheduleImportExport`.

---

### Appointments Panel — "Format" Help Button
- **Platform**: Desktop only (`FormFactorFeatures.showScheduleImportExport`)
- **Location**: Doctor > Schedule tab > Appointments Panel, action row (next to "Import")
- **Expected Behavior**: Amber-outlined pill with `Icons.help_outline_rounded` and text "Format". Tapping opens the Import Help Sheet with title "Import Schedule", showing required columns (Date in Col A, Patient Name in Col B), example rows, and notes about accepted date formats and behavior.
- **Test Steps**:
  1. On desktop, tap "Format".
  2. Confirm a bottom sheet opens listing: subtitle "Each row = one appointment for the patient in col B", column headers "Date (Col A)" / "Patient Name (Col B)", three example rows, and the bulleted notes (date formats, header auto-detection, past/future date handling).
  3. On mobile, confirm "Format" is NOT present (same gating as "Import").
- **Edge Cases / Notes**: Verify absence on mobile explicitly.

---

### Appointments Panel — Selected Day Section
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Appointments Panel, section header "Today" (if selected day is today) or "{EEE, MMM d}" (otherwise), with a count badge and blue calendar icon
- **Expected Behavior**: Lists all appointments for `_calDay`, sorted by time ascending. If empty, shows "No appointments scheduled for today." (if today) or "No appointments on this date." (otherwise) in grey text. Otherwise renders a `ListView` of appointment tiles separated by dividers.
- **Test Steps**:
  1. Select a day with no appointments; confirm the appropriate empty message.
  2. Select a day with appointments; confirm each appears as a tile (see "Appointment Tile" below), sorted earliest-first.
  3. Confirm the count badge next to the section title matches the number of appointments shown.
- **Edge Cases / Notes**: None beyond empty-state text variants.

---

### Appointment Tile
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Appointments Panel > Selected Day section, one row per appointment
- **Expected Behavior**: Shows a time block (hour:minute + AM/PM, color-coded by status: grey if cancelled, green if completed, else cycling avatar color), patient name (struck-through + "Cancelled" badge if status is cancelled), session notes (if present), and the date ("EEE, MMM d"). Trailing control depends on state:
  - If the appointment is in the past (`isPast`): shows a green `Icons.check_circle_rounded` (no menu).
  - If not cancelled and not past: shows a `PopupMenuButton` (3-dot icon) with menu items "Edit" (pencil icon, primary color), "Cancel Session" (cancel icon, warning/orange, warning-colored text), and "Delete" (trash icon, error/red, red text).
  - If cancelled: no trailing control.
- **Test Steps**:
  1. For a future, non-cancelled appointment: tap the 3-dot menu; confirm "Edit", "Cancel Session", "Delete" options appear with correct icons/colors.
  2. Tap "Edit" — confirm the Edit Appointment sheet opens pre-filled with the current date/time and notes (see "Edit Appointment Sheet").
  3. Tap "Cancel Session" — confirm `_service.cancelAppointment` is called; on success, an orange/warning SnackBar reads "Session cancelled"; on failure, shows `s.error` in error color. Confirm the tile then shows the "Cancelled" badge, struck-through name, grey time block, and no menu.
  4. Tap "Delete" — confirm `_service.deleteAppointment` is called; on success, warning-colored SnackBar reads `s.appointmentDeleted`; on failure, `s.error` in error color. Confirm the tile is removed from the list.
  5. For a past appointment, confirm only a green checkmark icon shows (no menu), regardless of status.
  6. For a cancelled appointment, confirm: time block is grey, name is struck-through with a red "Cancelled" badge, background tinted very light red (`#FFF5F5`), and no trailing menu.
  7. For a completed appointment, confirm: time block is green-tinted, background tinted very light green (`#F8FFF8`).
- **Edge Cases / Notes**: "Delete" is a destructive action with NO confirmation dialog before the delete call — verify whether this is intentional (worth flagging). Notes line only shows if non-empty.

---

### Book Appointment Sheet
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Appointments Panel > "Add Appointment" button (also reachable from My Patients > patient actions > "Schedule Appointment", which pre-fills the patient)
- **Expected Behavior**: Modal bottom sheet titled `s.scheduleSession`, containing:
  - **Select Patient** (`PatientSearchField`): searchable dropdown of assigned patients (label `s.selectPatient`); can be pre-filled with `prePatientId`/`prePatientName` when opened from a patient's action sheet.
  - **Session Date/Time** (Card/ListTile): shows `s.sessionDate` placeholder or "{d MMM yyyy  HH:mm}" once chosen; calendar icon leading, edit-calendar icon trailing. Tapping opens a date picker (range: -365 to +365 days from today) then a time picker.
  - **Session Notes** (TextField, 2 lines, label `s.sessionNotes`).
  - **"Book Session" button** (`ElevatedButton.icon`, `Icons.event_available_rounded`, label `s.bookSession`).
- **Test Steps**:
  1. Open the sheet via "Add Appointment". Confirm title and all three fields render.
  2. Tap "Book Session" without selecting a patient or date/time; confirm a SnackBar shows `s.selectPatientAndTime` and the sheet remains open.
  3. Select a patient via the search field; confirm selection updates `selPatientId`/`selPatientName`.
  4. Tap the date/time ListTile; pick a date then a time; confirm the tile updates to show "{d MMM yyyy  HH:mm}".
  5. Optionally enter session notes.
  6. Tap "Book Session"; confirm the sheet closes, the calendar auto-navigates to the booked date (`_calMonth`/`_calDay` update), and a SnackBar shows `s.sessionBooked` (success/green) or `s.error` (red) depending on `_service.bookAppointment` result.
  7. Open via a patient's "Schedule Appointment" action; confirm the patient search field is pre-filled with that patient's name and `selPatientId` is already set.
- **Edge Cases / Notes**: Date picker range is fixed at ±365 days from "now" (not from any appointment-relevant date). Validation only checks patient + date/time are set — notes are optional.

---

### Edit Appointment Sheet
- **Platform**: Both
- **Location**: Doctor > Schedule tab > Appointments Panel > Appointment Tile > 3-dot menu > "Edit"
- **Expected Behavior**: Modal bottom sheet titled `s.editAppointment`, containing:
  - **Session Date/Time** (Card/ListTile, pre-filled with the appointment's current date/time formatted "{d MMM yyyy  HH:mm}"); tapping opens date picker (±365 days from now) then time picker (pre-filled with current hour/minute).
  - **Session Notes** (TextField, 2 lines, pre-filled with current notes, label `s.sessionNotes`).
  - **"Save" button** (`ElevatedButton.icon`, `Icons.save_rounded`, label `s.save`).
- **Test Steps**:
  1. Open via an appointment's 3-dot menu > Edit; confirm the date/time and notes fields are pre-filled with the appointment's existing values.
  2. Change the date/time via the pickers; confirm the tile updates to reflect the new "{d MMM yyyy  HH:mm}".
  3. Edit the notes text.
  4. Tap "Save"; confirm the sheet closes and `_service.updateAppointment` is called; SnackBar shows `s.appointmentUpdated` (success/green) or `s.error` (red).
  5. Confirm the appointment tile in the Schedule reflects the new date/time/notes (may move to a different day's section if the date changed).
- **Edge Cases / Notes**: If `selDateTime` is somehow null on Save, the handler returns early with no feedback (defensive only — shouldn't occur since it's pre-filled).

---

### Documentation Tab — Header Bar
- **Platform**: Desktop only (entire Documentation tab is desktop-only per `showDocumentation`)
- **Location**: Doctor > Documentation tab > top header (primary-color background)
- **Expected Behavior**: Shows "Documentation Center" title (large, white, bold), then a row containing:
  - **"Add Note" button** (white background, primary-color text/icon, `Icons.add_rounded`) — opens the "Pick Patient for Documentation" sheet.
  - **Search field** ("Search Records" hint, search icon, white fill) — filters the table live by patient name or condition.
  - **"Export PDF" button** (white background, primary-color text/icon, `Icons.download_rounded`) — only shown if `showDocumentationExport` is true; opens the "Export PDF — Pick Patient" sheet.
- **Test Steps**:
  1. Confirm the header renders with "Documentation Center" title.
  2. Tap "Add Note"; confirm the patient-picker sheet opens (see "Pick Patient for Documentation Sheet").
  3. Type into "Search Records"; confirm the documentation table filters live by patient name or condition/diagnosis (case-insensitive substring match).
  4. Tap "Export PDF"; confirm the export patient-picker sheet opens (see "Export PDF Patient Picker Sheet").
- **Edge Cases / Notes**: `showDocumentationExport` is desktop-only, but since the whole tab is desktop-only, this flag is effectively always true in practice — still worth confirming it's present.

---

### Documentation Tab — Left Sidebar: "Add New Note" Button
- **Platform**: Desktop only
- **Location**: Doctor > Documentation tab > left sidebar (240px wide, white background)
- **Expected Behavior**: Filled primary-color button with `Icons.edit_rounded` and label "Add New Note". Tapping opens the same "Pick Patient for Documentation" sheet as the header's "Add Note" button.
- **Test Steps**:
  1. Tap "Add New Note" in the sidebar.
  2. Confirm the same patient-picker sheet opens as the header "Add Note" button.
- **Edge Cases / Notes**: Duplicate entry point to the same action as the header button — confirm both work identically.

---

### Documentation Tab — Left Sidebar: "Recent Updates" List
- **Platform**: Desktop only
- **Location**: Doctor > Documentation tab > left sidebar, below "Add New Note" button
- **Expected Behavior**: Shows up to 3 most recent SOAP notes (from `allNotes.take(3)`, NOT re-sorted by date — i.e. order as returned by the stream). Each entry is a tappable card showing the patient's name (bold), "Note Updated {dd/MM/yyyy}" (date from `created_at`, or blank if null), and a forward-arrow icon. Tapping navigates to `SoapNoteScreen` pre-filled with that note's data for editing.
- **Test Steps**:
  1. With at least one SOAP note existing, confirm up to 3 entries appear under "Recent Updates:".
  2. Tap an entry; confirm it navigates to the SOAP Note screen in edit mode (title "Edit SOAP Note") with the note's existing data pre-filled across all S/O/A/P tabs.
  3. With zero SOAP notes (empty state for the whole tab — see below), confirm the sidebar's "Recent Updates" list is simply empty (the whole tab shows the empty state instead, so this may not be independently reachable).
- **Edge Cases / Notes**: "Recent Updates" uses `allNotes.take(3)` — i.e., the first 3 items in the unsorted stream order, which may NOT be the 3 most recently created/updated notes (potential bug — the main table IS sorted by `created_at` descending, but this sidebar list is not). Worth flagging during testing if the sidebar's "recent" notes don't match the table's top 3 rows.

---

### Documentation Tab — Empty State
- **Platform**: Desktop only
- **Location**: Doctor > Documentation tab (when no SOAP/clinical notes exist at all)
- **Expected Behavior**: Centered icon (`Icons.description_outlined`, large, light grey) and text `s.noDocumentation`.
- **Test Steps**:
  1. As a doctor with zero clinical/SOAP notes across all patients, open the Documentation tab.
  2. Confirm the centered empty-state icon and message render, with NO header/sidebar/table.
- **Edge Cases / Notes**: This empty state replaces the ENTIRE tab content (header, sidebar, filters, table) — not just the table area. Compare with "No documentation found" (below), which is a narrower empty state for filtered results.

---

### Documentation Tab — Filter: Patient Name Dropdown
- **Platform**: Desktop only
- **Location**: Doctor > Documentation tab > right content area, filter row (first dropdown)
- **Expected Behavior**: `DropdownButtonFormField` labeled "Patient Name" with options "All Patients" (value `''`) plus one entry per unique patient name found in the notes. Selecting a patient filters the table to only that patient's notes.
- **Test Steps**:
  1. Open the dropdown; confirm "All Patients" plus a deduplicated list of patient names from existing notes.
  2. Select a specific patient; confirm the table filters to only that patient's rows.
  3. Select "All Patients"; confirm the table shows all notes again (subject to other active filters).
  4. Combine with the search field and the Condition filter; confirm all three filters apply together (AND logic).
- **Edge Cases / Notes**: If `patient_name` is missing on a note, it defaults to "Unknown" for the purpose of building the dropdown's option set.

---

### Documentation Tab — Filter: Condition Dropdown
- **Platform**: Desktop only
- **Location**: Doctor > Documentation tab > right content area, filter row (second dropdown)
- **Expected Behavior**: `DropdownButtonFormField` labeled "Condition" with options "All Conditions" (value `''`) plus one entry per unique condition (derived from `primary_diagnosis`, falling back to `chiefComplaint`, falling back to "General"). Selecting a condition filters the table to notes matching that condition exactly.
- **Test Steps**:
  1. Open the dropdown; confirm "All Conditions" plus a deduplicated list of conditions derived from notes.
  2. Select a specific condition; confirm the table filters to matching rows only.
  3. Reset to "All Conditions"; confirm all rows (subject to other filters) reappear.
- **Edge Cases / Notes**: Condition derivation precedence: `primary_diagnosis` → `chiefComplaint` → "General". A note with neither field set will be grouped under "General".

---

### Documentation Tab — "No documentation found" (Filtered Empty State)
- **Platform**: Desktop only
- **Location**: Doctor > Documentation tab > right content area, table region (when `filteredNotes.isEmpty` but `soapNotes` overall is non-empty)
- **Expected Behavior**: Centered grey text "No documentation found" in place of the table.
- **Test Steps**:
  1. With existing notes, apply a search term, patient filter, or condition filter combination that matches no notes.
  2. Confirm "No documentation found" displays in the table area while the header/sidebar/filters remain visible.
  3. Clear the filter(s); confirm the table reappears.
- **Edge Cases / Notes**: Distinguish from the full-tab empty state (`s.noDocumentation`) which only appears when there are literally zero SOAP notes at all, regardless of filters.

---

### Documentation Table
- **Platform**: Desktop only
- **Location**: Doctor > Documentation tab > right content area, below filters
- **Expected Behavior**: A `Card` with a blue (`#1565C0`) header row containing columns: "Patient Name" (flex 2), "Session Date" (flex 1), "Condition" (flex 1), "Note Summary" (flex 2), "Actions" (fixed 80px, centered). Below, one row per filtered+sorted note (sorted by `created_at` descending), alternating white/`#F8FAFF` background. Each row shows:
  - Patient avatar (photo or person icon) + name.
  - Session date ("dd/MM/yyyy" or "—" if `created_at` missing).
  - Condition (same derivation as the filter dropdown).
  - Note summary: first 60 chars of `subjective` text (newlines replaced with spaces), truncated with "..." if longer, with a `Tooltip` showing the full text on hover.
  - Actions: Edit icon button (orange `Icons.edit_rounded`, tooltip "Edit") and Delete icon button (red `Icons.delete_rounded`, tooltip "Delete").
- **Test Steps**:
  1. Confirm the table header row shows all 5 column labels in white bold text on blue background.
  2. Confirm rows alternate background colors (even index = white, odd = `#F8FAFF`).
  3. Hover over a truncated "Note Summary" cell; confirm the tooltip shows the full subjective text.
  4. Tap the Edit icon on a row; confirm navigation to `SoapNoteScreen` in edit mode with that note's data pre-filled (title "Edit SOAP Note").
  5. Tap the Delete icon on a row; confirm the note is deleted from `clinical_notes` immediately (NO confirmation dialog), and:
     - On success: green SnackBar "Note deleted".
     - On error (e.g. simulate a network failure): red SnackBar "Error deleting note".
  6. Confirm the deleted row disappears from the table (stream-driven).
- **Edge Cases / Notes**: Delete has NO confirmation dialog before permanently deleting the clinical note — flag this as a potential UX risk during testing (compare to "Remove from My Patients" which DOES have a confirmation dialog). Patient avatar uses `patientPhotoUrl` from the note record, which may be stale if the patient's photo changed since the note was created.

---

### Pick Patient for Documentation Sheet
- **Platform**: Desktop only (entry points are desktop-only, but the sheet itself has no platform gating)
- **Location**: Doctor > Documentation tab > "Add Note" (header) or "Add New Note" (sidebar)
- **Expected Behavior**: Modal bottom sheet titled `s.addDocumentation` with subtitle `s.pickPatient`. Lists all assigned patients (`_service.getAssignedPatients()`), each as a `ListTile` with avatar (photo or person icon), name (or email if name missing), subtitle showing `primary_diagnosis` (if any), and a forward arrow. Tapping a patient closes the sheet and navigates to `SoapNoteScreen` in "new note" mode (title shows `s.soapNotes`, no `noteId`).
- **Test Steps**:
  1. Open via "Add Note"/"Add New Note".
  2. Confirm title and subtitle render, and the patient list shows all assigned patients with avatars and diagnosis subtitles.
  3. With zero assigned patients, confirm the list area shows `s.noPatients` text instead.
  4. Tap a patient; confirm the sheet closes and `SoapNoteScreen` opens in "new" mode (no pre-filled S/O/A/P data, title "SOAP Notes" not "Edit SOAP Note").
- **Edge Cases / Notes**: List is capped to `MediaQuery.height * 0.5` with internal scrolling if many patients.

---

### Export PDF Patient Picker Sheet
- **Platform**: Desktop only (`showDocumentationExport`)
- **Location**: Doctor > Documentation tab > header "Export PDF" button
- **Expected Behavior**: If there are zero notes with a valid `patient_id`, tapping "Export PDF" immediately shows a SnackBar "No notes available to export." and does NOT open a sheet. Otherwise, opens a modal bottom sheet titled "Export Patient Notes as PDF" with a `DropdownButtonFormField` labeled "Select Patient" (pre-selected to the first patient with notes), and a full-width "Export PDF" button (`Icons.picture_as_pdf_rounded`). Tapping it closes the sheet and calls `_exportDocumentationPdf` with that patient's notes.
- **Test Steps**:
  1. With zero documented patients, tap header "Export PDF"; confirm the "No notes available to export." SnackBar appears and no sheet opens.
  2. With at least one documented patient, tap "Export PDF"; confirm the sheet opens with the patient dropdown pre-selected to one patient.
  3. Select a different patient from the dropdown.
  4. Tap the "Export PDF" button in the sheet; confirm the sheet closes and a PDF export/download is triggered for that patient's notes.
- **Edge Cases / Notes**: The patient dropdown is built from a `Map` keyed by `patient_id`, so patients with multiple notes appear only once.

---

### "Add Patient" Bottom Sheet — Entry Tiles (`_addPatientTile`)
- **Platform**: Both (the "Import from Excel" tile is Desktop only)
- **Location**: Doctor > My Patients tab > "Add Patient" action (FAB or button — opens `_showAddPatientMenu`)
- **Expected Behavior**: Modal bottom sheet titled "Add Patient" with up to 3 tiles (each via `_addPatientTile`: a bordered `ListTile` with a colored circle-avatar icon, bold title, subtitle, and a trailing forward-arrow — plus an optional help "?" icon button before the arrow):
  1. **"Add Patient"** tile (icon `Icons.person_add_rounded`, primary color, subtitle "Create a new patient account") — navigates to `CreatePatientScreen`.
  2. **"Add Existing Patient"** tile (icon `Icons.manage_search_rounded`, orange, subtitle "Link an already-registered patient") — opens the "Search Existing Patients" sheet.
  3. **"Import from Excel"** tile (icon `Icons.upload_file_rounded`, green, subtitle "Col A: Date → Schedule  ·  Col B: Patient Name") — Desktop only (`showPatientsImportExport`); has a help "?" icon opening the Import Help Sheet ("Import Patients & Schedule"); tapping the tile body triggers `_importPatientsFromExcel()`.
- **Test Steps**:
  1. Open the "Add Patient" sheet; confirm title and tile 1 & 2 always present.
  2. On desktop, confirm tile 3 ("Import from Excel") is present with a help icon.
  3. On mobile, confirm tile 3 is absent entirely.
  4. Tap tile 1; confirm navigation to `CreatePatientScreen`.
  5. Tap tile 2; confirm the "Search Existing Patients" sheet opens.
  6. (Desktop) Tap the help "?" icon on tile 3; confirm the Import Help Sheet opens with title "Import Patients & Schedule", columns "Date (Col A)"/"Patient Name (Col B)", 3 example rows, and the listed notes (including "Toggle 'Account' in the preview to create a patient login").
  7. (Desktop) Tap tile 3's body (not the help icon); confirm an Excel file picker opens via `_importPatientsFromExcel()`.
- **Edge Cases / Notes**: None beyond the desktop/mobile gating already covered.

---

### Patient Action Sheet — Action Tiles (`_actionTile`)
- **Platform**: Both (phone-dependent and account-dependent tiles conditionally shown)
- **Location**: Doctor > My Patients tab > tapping a patient > "Select Action" sheet (`_showPatientActions`)
- **Expected Behavior**: Modal bottom sheet (max height 75% of screen, scrollable) showing a header with the patient's avatar, name, and `s.selectAction` subtitle, followed by a list of `_actionTile` cards (each: bordered card, colored icon-in-box leading, bold title, optional grey subtitle, forward-arrow trailing):
  1. **Schedule Appointment** (`Icons.calendar_today_rounded`, blue) — opens Book Appointment sheet pre-filled with this patient.
  2. **View Appointments** (`Icons.history_rounded`, teal `#00897B`, subtitle "Previous & upcoming with Excel export") — opens the Patient Appointments sheet.
  3. **{s.addDocumentation}** (`Icons.description_rounded`, primary color, subtitle `s.soapDoctorOnly`) — navigates to `SoapNoteScreen` for this patient (new note).
  4. **Call / WhatsApp** (`Icons.phone_in_talk_rounded`, green `#25D366`, subtitle = phone number) — only shown `if (phone.isNotEmpty)`; opens the Phone/WhatsApp options sheet.
  5. **Create Account** (`Icons.manage_accounts_rounded`, primary color, subtitle "Set up login credentials for this patient") — only shown `if (!hasAccount)`; navigates to `CreatePatientScreen` pre-filled with the patient's name.
  6. **Remove from My Patients** (`Icons.person_remove_rounded`, error/red, subtitle "Unlink this patient from your list") — shows a confirmation dialog ("Remove Patient" / "Remove {patientName} from your patient list?" with "Cancel"/"Remove" buttons); on confirm, calls `_removePatient` and shows a green SnackBar "{patientName} removed from your list.".
- **Test Steps**:
  1. Open the action sheet for a patient who HAS an account and a phone number; confirm tiles 1, 2, 3, 4, 6 appear (5 absent).
  2. Open for a patient with NO account; confirm tile 5 ("Create Account") appears.
  3. Open for a patient with no phone number; confirm tile 4 ("Call / WhatsApp") is absent.
  4. Tap tile 1; confirm the Book Appointment sheet opens with this patient pre-selected.
  5. Tap tile 2; confirm the Patient Appointments sheet opens (previous/upcoming appointments, with Excel export per `showPatientsImportExport`).
  6. Tap tile 3; confirm navigation to a new SOAP note for this patient.
  7. Tap tile 4 (if present); confirm the Call/WhatsApp options sheet opens (see "Phone / WhatsApp Options Sheet").
  8. Tap tile 5 (if present); confirm navigation to `CreatePatientScreen` with the patient's name pre-filled.
  9. Tap tile 6; confirm the "Remove Patient" confirmation dialog appears. Tap "Cancel" — dialog closes, no change. Reopen, tap "Remove" — confirm the patient is unlinked and a green SnackBar confirms removal.
- **Edge Cases / Notes**: Tile 6 is the only action with a confirmation dialog; deletions in the Documentation table (above) notably lack this safeguard for comparison.

---

### Phone / WhatsApp Options Sheet
- **Platform**: Both
- **Location**: Doctor > (Pending Appointment Requests Card phone link) OR (Patient Action Sheet > "Call / WhatsApp" tile)
- **Expected Behavior**: Modal bottom sheet showing the phone number (bold, large) and at least a "WhatsApp" `ListTile` (green chat icon) that opens `https://wa.me/{cleaned phone}` in an external app/browser. (Additional options likely follow beyond the read range, e.g. "Call".)
- **Test Steps**:
  1. Open via either entry point with a valid phone number.
  2. Confirm the phone number displays at the top of the sheet.
  3. Tap "WhatsApp"; confirm the sheet closes and an external WhatsApp/browser link opens to `wa.me/{number with spaces/dashes/parens stripped}`.
- **Edge Cases / Notes**: If `phone` is empty, `_showPhoneOptions` returns immediately and no sheet opens (defensive check) — but in practice this sheet is only reached from places that already check `phone.isNotEmpty`.

---

### SOAP Note Screen — Overview (reached from Documentation tab / patient actions)
- **Platform**: Both (Desktop uses a top `TabBar`/`TabBarView` for S/O/A/P sections; Mobile uses a vertical accordion `_buildMobileAccordion` with `ExpansionTile` sections, since the single-letter tab labels overflow the AppBar TabBar at narrow widths)
- **Location**: Reached from Doctor > Documentation tab ("Add Note"/"Add New Note"/sidebar recent updates/table Edit icon) or Doctor > My Patients > patient actions > "{Add Documentation}"
- **Expected Behavior**: AppBar shows title "Edit SOAP Note" (if `noteId` present) or `s.soapNotes` (new note), subtitle = patient name, and a "Use Template" text button (`Icons.library_books_rounded`) in actions. Desktop AppBar also has a `TabBar` with 4 tabs (S/Subjective-blue, O/Objective-green, A/Assessment-orange, P/Plan-purple), each a colored letter box + title. Body is either the TabBarView (desktop) or accordion (mobile), followed by a fixed bottom "Save"/"Publish" button.
- **Test Steps**:
  1. Open in "new note" mode; confirm AppBar title = `s.soapNotes`, no "Edit" wording.
  2. Open in "edit" mode (via Documentation table Edit icon); confirm AppBar title = "Edit SOAP Note" and all fields are pre-filled from the existing note (`_prefillFromData`).
  3. On desktop, confirm the 4-tab TabBar (S/O/A/P) switches between sections; on mobile, confirm the 4 sections render as expandable accordion cards instead (Subjective expanded by default).
- **Edge Cases / Notes**: `_prefillFromData` handles both the "new" field format (`chiefComplaint` etc.) and a legacy 4-field format (`subjective`/`objective`/`assessment`/`plan`), mapping legacy fields to the closest new fields when editing old notes.

---

### SOAP Note Screen — "Use Template" Button & Templates Sheet
- **Platform**: Both
- **Location**: Doctor > SOAP Note Screen > AppBar actions, "Use Template" (`Icons.library_books_rounded`, label `s.useTemplate`)
- **Expected Behavior**: Opens a bottom sheet titled `s.soapTemplates` listing 9 templates (numbered 1-9, each a `ListTile` with a numbered circle avatar and forward arrow): "Initial PT Assessment", "Lower Back Pain", "Knee Rehabilitation", "Shoulder Impingement", "Ankle Sprain", "Cervical Pain / Neck", "Post-Surgical Recovery", "General Progress Note". Tapping a template closes the sheet and overwrites ALL form fields (across all 4 S/O/A/P sections) with that template's pre-filled placeholder text (e.g. "Patient presents with ___ pain at ___.") and pain level.
- **Test Steps**:
  1. Tap "Use Template"; confirm the sheet lists 9 templates with numbered avatars.
  2. Select "Lower Back Pain"; confirm the sheet closes and fields across ALL sections (Subjective, Objective, Assessment, Plan) populate with that template's placeholder text (e.g. Chief Complaint = "Low back pain.", Pain Level slider = 6).
  3. Repeat with a different template; confirm previous values are fully overwritten (not merged).
- **Edge Cases / Notes**: Applying a template completely overwrites existing field content with no confirmation — if a doctor has partially filled in a note and then applies a template, their entered data is lost without warning. Worth flagging as a potential data-loss risk during testing, especially when editing an existing note.

---

### SOAP Note Screen — Subjective Tab/Section
- **Platform**: Both (Tab on desktop, accordion section "S" on mobile, expanded by default)
- **Location**: Doctor > SOAP Note Screen > "S — Subjective" (blue, `الملاحظات الذاتية`)
- **Expected Behavior**: Section header (blue "S" box + "Subjective"/Arabic title) followed by fields, each a bilingual (EN/AR) label + text field:
  - Chief Complaint / الشكوى الرئيسية (2 lines)
  - Onset & Duration / بداية ومدة الأعراض
  - **Pain Level (0–10)** / مستوى الألم — a `Slider` (0-10, 10 divisions) with a colored badge showing "{level}/10" (green ≤3, orange ≤6, red >6)
  - Pain Characteristics / خصائص الألم
  - Aggravating Factors / العوامل المؤلمة
  - Relieving Factors / العوامل المؤدية للراحة
  - Functional Limitations / القيود الوظيفية
  - Patient Goals / أهداف المريض
  - Medical & Surgical History / التاريخ الطبي والجراحي
  - Medications / الأدوية
  - Social & Occupational Context / السياق الاجتماعي والمهني
- **Test Steps**:
  1. Confirm all 10 text fields + the pain slider render with correct bilingual labels.
  2. Drag the Pain Level slider; confirm the badge updates live and changes color at the 3/6 thresholds (green 0-3, orange 4-6, red 7-10).
  3. Enter text in "Chief Complaint" (required field) and leave others blank; this is the minimum required to save (see Save button below).
- **Edge Cases / Notes**: "Chief Complaint" is the only required field for saving — see validation below.

---

### SOAP Note Screen — Objective Tab/Section
- **Platform**: Both (Tab on desktop, accordion section "O" on mobile)
- **Location**: Doctor > SOAP Note Screen > "O — Objective" (green, `الفحص الموضوعي`)
- **Expected Behavior**: Section header (green "O" box) followed by 9 bilingual text fields: Observation/الملاحظة, Palpation/الجس, Range of Motion (ROM)/مدى الحركة (3 lines), Strength Testing/اختبار القوة, Neurological Exam/الفحص العصبي, Balance & Coordination/التوازن والتنسيق, Special Tests/الفحوصات الخاصة, Functional Tests/الفحوصات الوظيفية, Assistive Devices/الأجهزة المساعدة.
- **Test Steps**:
  1. Confirm all 9 fields render with correct bilingual labels; "Range of Motion (ROM)" should be a taller (3-line) field.
  2. Enter sample text in each and confirm it persists when switching tabs/sections and on save.
- **Edge Cases / Notes**: None — all fields optional.

---

### SOAP Note Screen — Assessment Tab/Section
- **Platform**: Both (Tab on desktop, accordion section "A" on mobile)
- **Location**: Doctor > SOAP Note Screen > "A — Assessment" (orange, `التقييم`)
- **Expected Behavior**: Section header (orange "A" box) followed by 6 bilingual text fields: Clinical Impression/الانطباع السريري (2 lines), Severity & Stage/شدة ومرحلة الحالة, Progress Toward Goals/التقدم نحو الأهداف, Barriers/العوائق, Response to Treatment/الاستجابة للعلاج, Prognosis/التوقعات المستقبلية.
- **Test Steps**:
  1. Confirm all 6 fields render with correct bilingual labels.
  2. Enter sample text and confirm persistence across tab/accordion switches.
- **Edge Cases / Notes**: None — all fields optional.

---

### SOAP Note Screen — Plan Tab/Section
- **Platform**: Both (Tab on desktop, accordion section "P" on mobile)
- **Location**: Doctor > SOAP Note Screen > "P — Plan" (purple, `الخطة العلاجية`)
- **Expected Behavior**: Section header (purple "P" box) followed by 6 bilingual text fields: Treatment Focus/محاور العلاج, Interventions/التدخلات العلاجية (3 lines), Frequency & Duration/عدد الجلسات والمدة, Home Exercise Program (HEP)/برنامج التمارين المنزلية (3 lines), Referrals/الإحالات, Follow-up/المتابعة.
- **Test Steps**:
  1. Confirm all 6 fields render with correct bilingual labels; "Interventions" and "HEP" should be taller (3-line) fields.
  2. Enter sample text and confirm persistence across tab/accordion switches.
- **Edge Cases / Notes**: None — all fields optional.

---

### SOAP Note Screen — Mobile Accordion Sections
- **Platform**: Mobile only
- **Location**: Doctor > SOAP Note Screen body (replaces desktop TabBar/TabBarView)
- **Expected Behavior**: Four `ExpansionTile`-based cards, one per S/O/A/P section, each with a colored letter box, bilingual title, and expand/collapse chevron. "S — Subjective" is expanded by default; the others (O, A, P) start collapsed.
- **Test Steps**:
  1. On mobile, confirm "S — Subjective" section is expanded on load, others collapsed.
  2. Tap "O — Objective" header; confirm it expands to show its 9 fields, and confirm the previously expanded "S" section remains expanded (independent expansion, not accordion-exclusive).
  3. Confirm each section's color (S=blue, O=green, A=orange, P=purple) matches its desktop tab counterpart.
- **Edge Cases / Notes**: Despite the "accordion" naming, sections expand independently (not mutually exclusive) — confirm multiple sections can be open simultaneously.

---

### SOAP Note Screen — Save / Publish Button
- **Platform**: Both
- **Location**: Doctor > SOAP Note Screen > bottom fixed bar (white background, full-width button)
- **Expected Behavior**: Button shows a `CircularProgressIndicator` while `_saving` is true. Otherwise:
  - New note: icon `Icons.publish_rounded`, label `s.publishNote`.
  - Edit existing note (`noteId != null`): icon `Icons.save_rounded`, label "Save Changes".
  Tapping validates that "Chief Complaint" is non-empty; if empty, shows a SnackBar: "Please fill in at least the Chief Complaint / الشكوى الرئيسية." and does NOT save. Otherwise saves (create or update depending on `noteId`), then:
  - Success: SnackBar "Note updated!" (edit) or `s.notePublished` (new), green/success background; screen pops back to Documentation tab.
  - Failure: SnackBar "Failed to save note. Please try again.", red/error background; screen remains open.
- **Test Steps**:
  1. Leave "Chief Complaint" empty and tap Save/Publish; confirm the validation SnackBar appears and the screen does not navigate away.
  2. Fill in "Chief Complaint" only (all else blank) and tap Publish (new note); confirm a loading spinner shows briefly, then on success a green "{s.notePublished}" SnackBar appears and the screen pops back to Documentation.
  3. Edit an existing note, change a field, tap "Save Changes"; confirm a green "Note updated!" SnackBar and pop-back.
  4. Simulate a save failure (e.g. network off); confirm the red "Failed to save note. Please try again." SnackBar appears and the screen remains open with entered data intact.
  5. Confirm the new note appears in the Documentation table (or the edited note's row updates) after returning.
- **Edge Cases / Notes**: Only "Chief Complaint" is validated — all S/O/A/P fields besides it can be saved completely empty. The save payload also writes legacy fields (`subjective`, `objective`, `assessment`, `plan`) derived from the new fields for backward compatibility.

---

## Doctor Dashboard — My Patients, My Profile & Polyclinic-Affiliated Doctors

---

### My Patients Tab — platform overview

**Platform**: Both (Desktop shows a sortable 5-column table; Mobile shows a vertical card list). Desktop-only extras: "Export to Excel" button, per-patient appointment-history Excel export, schedule/patient Excel import. These are gated by `FormFactorFeatures.showPatientsImportExport` (= `!isMobile`).

---

### Search Patients field

- **Platform**: Both
- **Location**: Doctor > My Patients tab > top search bar
- **Expected Behavior**: As you type, the patient list filters live by name, primary diagnosis ("condition"), or phone number (case-insensitive substring match). If no patients match, the list area shows "No patients found".
- **Test Steps**:
  1. Go to My Patients tab.
  2. Type part of a patient's name into the search field (hint: "Search by name, condition, contact…").
  3. Confirm only matching patients remain in the list/table.
  4. Clear the field and type part of a diagnosis (e.g. "knee") — confirm patients with that condition show.
  5. Type part of a phone number — confirm matching patient(s) show.
  6. Type a string that matches nothing — confirm "No patients found" message appears.
- **Edge Cases / Notes**: Search is purely client-side over already-loaded patients. Empty patient list shows a separate empty state (see below) instead of the search bar.

---

### Add Patient button

- **Platform**: Both
- **Location**: Doctor > My Patients tab > top bar (blue button, "+ Add Patient") — also shown as the call-to-action in the empty state when there are zero patients.
- **Expected Behavior**: Opens a bottom sheet titled "Add Patient" with options: "Add Patient" (create new account), "Add Existing Patient" (link a registered patient), and (desktop only) "Import from Excel".
- **Test Steps**:
  1. Tap "Add Patient" (top bar) or, with zero patients, tap the empty-state "Add Patient" button (icon: person-add).
  2. Confirm the bottom sheet opens with the title "Add Patient" and the listed options.
- **Edge Cases / Notes**: The empty-state button only appears when `allPatients` is empty (icon `people_outline_rounded`, message = `s.noPatients`).

---

### Add Patient sheet — "Add Patient" tile

- **Platform**: Both
- **Location**: Doctor > My Patients > Add Patient sheet > first tile (icon: person_add_rounded, primary color)
- **Expected Behavior**: Subtitle "Create a new patient account". Tapping closes the sheet and navigates to the "Add Patient" screen (CreatePatientScreen) for creating a brand-new patient account.
- **Test Steps**:
  1. Open the Add Patient sheet.
  2. Tap the "Add Patient" tile.
  3. Confirm navigation to the Add Patient form (see Create Patient Screen section below).
- **Edge Cases / Notes**: None.

---

### Add Patient sheet — "Add Existing Patient" tile

- **Platform**: Both
- **Location**: Doctor > My Patients > Add Patient sheet > second tile (icon: manage_search_rounded, orange)
- **Expected Behavior**: Subtitle "Link an already-registered patient". Tapping closes the sheet and opens the "Add Existing Patient" search sheet.
- **Test Steps**:
  1. Open the Add Patient sheet.
  2. Tap "Add Existing Patient".
  3. Confirm a new bottom sheet opens titled "Add Existing Patient" with subtitle "Search by name, email, or diagnosis" and a search field (hint: "Type at least 2 characters…").
- **Edge Cases / Notes**: See "Add Existing Patient search" item below for full behavior.

---

### Add Patient sheet — "Import from Excel" tile (Desktop only)

- **Platform**: Desktop only (`FormFactorFeatures.showPatientsImportExport`)
- **Location**: Doctor > My Patients > Add Patient sheet > third tile (icon: upload_file_rounded, green), subtitle "Col A: Date → Schedule · Col B: Patient Name"
- **Expected Behavior**: Tapping the tile (not the help icon) closes the sheet and opens a file picker restricted to `.xlsx`/`.xls`. Tapping the "?" help icon (top-right of the tile) opens the "Import Patients & Schedule" format-help sheet without closing the Add Patient sheet.
- **Test Steps**:
  1. On Desktop, open the Add Patient sheet and confirm the "Import from Excel" tile is visible (it should NOT appear on Mobile).
  2. Tap the help icon (circle with "?" / help_outline_rounded) on the tile.
  3. Confirm a help sheet appears titled "Import Patients & Schedule" with subtitle "Each row = one appointment assigned to the patient", showing required columns "Date (Col A)" and "Patient Name (Col B)" as pills A/B, an example table with rows like `01/15/2024 | John Smith`, and a Notes section listing the bullet points (date formats, header auto-detection, "Toggle Account" note, etc.).
  4. Close the help sheet, then tap the tile body (not the help icon) and confirm a native file picker opens accepting `.xlsx`/`.xls`.
  5. Pick a valid Excel file and confirm the Import Preview sheet opens (see "Import Patients from Excel — Preview sheet" below).
- **Edge Cases / Notes**: If the picked file has no rows / no data, a snackbar "No data found in the file." appears. If no patient names are found after parsing, snackbar "No patients found in the file." appears.

---

### Add Existing Patient — search field

- **Platform**: Both
- **Location**: Doctor > My Patients > Add Patient sheet > "Add Existing Patient" > search field
- **Expected Behavior**: Typing at least 2 characters triggers a search (via `_service.searchAllPatients`); a loading spinner shows in the field's suffix while searching. Results list shows matching patients with avatar, name, email, and diagnosis (if present). Each result shows either an "Added" green badge (if already in your roster) or an "Add" button.
- **Test Steps**:
  1. Open "Add Existing Patient" sheet.
  2. Type 1 character — confirm no results/search triggered (results list stays empty).
  3. Type 2+ characters matching an existing patient's name, email, or diagnosis.
  4. Confirm a spinner briefly appears in the search field, then results populate.
  5. For a patient already on your roster, confirm a green "Added" pill shows instead of a button.
  6. For a patient not yet on your roster, tap "Add".
  7. Confirm a success snackbar "<name> added to your roster!" appears, the result re-runs (so the pill may update to "Added"), and the patient now appears in My Patients list.
- **Edge Cases / Notes**: If 2+ chars are typed and search returns nothing (and not currently searching), shows "No patients found." centered message. Adding a patient also triggers `_service.notifyPatientAdded` (in-app notification to the patient).

---

### Export to Excel button (Desktop only)

- **Platform**: Desktop only (`FormFactorFeatures.showPatientsImportExport`)
- **Location**: Doctor > My Patients tab > top bar, green icon-only button (download_rounded icon), tooltip "Export to Excel"
- **Expected Behavior**: Exports the currently filtered/sorted patient list to an `.xlsx` file named `patients_export.xlsx` with columns: Patient Name, Condition, Phone, Email, Account Status ("Has Account"/"No Account"). Triggers a browser/file download via `downloadExcel`.
- **Test Steps**:
  1. On Desktop, with at least one patient in My Patients, optionally type a search filter to narrow the list.
  2. Hover the green download button — confirm tooltip "Export to Excel".
  3. Tap it and confirm a file named `patients_export.xlsx` downloads.
  4. Open the file and verify columns: Patient Name, Condition, Phone, Email, Account Status, and that only the currently filtered patients are present.
- **Edge Cases / Notes**: Button is hidden entirely on Mobile. Uses whatever `filteredPatients` is currently shown (i.e., respects the search filter).

---

### Sort options (table column headers — Desktop only)

- **Platform**: Desktop only (the sortable table `_buildPatientsTable` is shown when `!FormFactorFeatures.isMobile`; Mobile uses `_buildPatientsCardList`, which has no sort control)
- **Location**: Doctor > My Patients tab > table header row (blue bar): "Patient Name", "Condition", "Last Visit", "Upcoming", "Account"
- **Expected Behavior**: "Patient Name", "Condition", and "Account" headers are tappable sort toggles (each shows an up-arrow when active/sorted, or an "unfold" icon otherwise, plus underline on the active label). "Last Visit" and "Upcoming" are static (non-sortable) headers.
  - Default sort: by name (A–Z).
  - "Condition": sorts patients alphabetically by primary diagnosis.
  - "Account": sorts so patients without an account ("+ Account" button) are grouped before/after those with "Active" accounts.
  - "Last Visit"/"Upcoming": always show the patient's most recent past appointment date / nearest future appointment date (format MM/dd), or "—" if none. Computed asynchronously per row via `_getPatientAppointmentDates`.
- **Test Steps**:
  1. On Desktop, go to My Patients with 2+ patients having different diagnoses and account statuses.
  2. Tap "Condition" header — confirm rows re-order alphabetically by diagnosis, the header text gets an underline, and the icon switches to an up-arrow.
  3. Tap "Condition" again — confirm it toggles back to default "name" sort (tapping an active sort returns to 'name').
  4. Tap "Account" header — confirm rows re-order by account status; icon/underline updates accordingly.
  5. Tap "Patient Name" header — confirm rows sort A→Z by name.
  6. For a patient with past/future appointments, confirm "Last Visit"/"Upcoming" columns show MM/dd dates; for a patient with none, confirm "—" in both columns.
- **Edge Cases / Notes**: Sorting state (`sortBy`) is local to the StatefulBuilder and resets if the tab/stream rebuilds. "Date" sort mode exists in code (`created_at`, newest first) but is not exposed via any visible header — it can never be reached from the UI as currently wired (`onSortChanged` only toggles between 'name' and the tapped header's field, and no header maps to 'date').

---

### Patient row / card tap → Patient Actions sheet

- **Platform**: Both (Desktop: table row; Mobile: card in `_buildPatientsCardList`)
- **Location**: Doctor > My Patients tab > tap anywhere on a patient's row (Desktop) or card (Mobile)
- **Expected Behavior**: Opens a bottom sheet (max height 75% of screen, scrollable) showing the patient's avatar, name, and "Select an action" subtitle, followed by action tiles:
  1. "Schedule Appointment" (calendar icon, blue) — opens the Book Appointment sheet prefilled with this patient.
  2. "View Appointments" (history icon, teal) — subtitle "Previous & upcoming with Excel export" — opens the appointment-history sheet.
  3. "Add Documentation" (description icon, primary color) — subtitle = SOAP doctor-only string — navigates to SoapNoteScreen for this patient.
  4. "Call / WhatsApp" (phone icon, green #25D366) — only shown if the patient has a phone number; subtitle shows the phone number — opens phone/WhatsApp options sheet.
  5. "Create Account" (manage_accounts icon, primary) — only shown if patient has NO account yet — subtitle "Set up login credentials for this patient" — navigates to CreatePatientScreen prefilled with the patient's name.
  6. "Remove from My Patients" (person_remove icon, red/error) — subtitle "Unlink this patient from your list" — shows a confirmation dialog.
- **Test Steps**:
  1. Tap a patient row/card.
  2. Confirm the sheet opens with the patient's avatar + name + "Select an action".
  3. Confirm all applicable tiles render per the rules above (phone-dependent and account-dependent tiles only show when conditions are met).
  4. For a patient WITHOUT a phone number, confirm "Call / WhatsApp" tile is absent.
  5. For a patient WITH an account, confirm "Create Account" tile is absent.
- **Edge Cases / Notes**: Account status (avatar dot: green = has account, grey = no account) is computed as `email non-empty AND hasAccount != false`.

---

### Patient Actions — "Schedule Appointment"

- **Platform**: Both
- **Location**: Doctor > My Patients > tap patient > "Schedule Appointment" tile
- **Expected Behavior**: Closes the actions sheet and opens the "Book Appointment" sheet with the patient pre-selected (`prePatientId`/`prePatientName`).
- **Test Steps**:
  1. Open Patient Actions for any patient.
  2. Tap "Schedule Appointment".
  3. Confirm the Book Appointment sheet opens with this patient already selected/locked in (not the searchable picker, since pre-filled).
- **Edge Cases / Notes**: The new `PatientSearchField` widget is used in the general "Add Appointment" flow (Schedule tab), but when reached via this pre-filled path the patient is already determined, so the search field may not be interactively relevant here — still verify the patient name shown matches.

---

### Patient Actions — "View Appointments" (appointment history sheet)

- **Platform**: Both, with Excel export Desktop-only
- **Location**: Doctor > My Patients > tap patient > "View Appointments" tile
- **Expected Behavior**: Closes the actions sheet and opens a draggable bottom sheet (70%-95% height) showing:
  - Header: patient name, and a summary line "`<total>` total · `<upcoming count>` upcoming · `<previous count>` previous".
  - (Desktop only) A green "Excel" button (download icon) in the header, disabled (greyed/null onPressed) if there are zero appointments.
  - "Upcoming" section header (blue pill showing count) followed by upcoming appointment cards.
  - "Previous" section header (grey pill showing count) followed by previous appointment cards.
  - If there are no appointments at all: centered text "No appointments yet."
- **Test Steps**:
  1. Tap "View Appointments" for a patient with both past and future appointments.
  2. Confirm header shows correct total/upcoming/previous counts.
  3. Confirm "Upcoming" section appears first (blue badge with count) with one card per upcoming appointment, each showing day/month box, time, date, optional notes preview, and a status pill (e.g. "scheduled").
  4. Confirm "Previous" section appears after (grey badge with count) with cards similarly, status pill showing e.g. "completed".
  5. Drag the sheet to expand/collapse — confirm it resizes between ~40% and ~95% of screen height.
  6. For a patient with zero appointments, confirm "No appointments yet." message and (Desktop) the Excel button is disabled.
- **Edge Cases / Notes**: Appointment cards differentiate upcoming (blue-tinted border/background) vs previous (grey). Date/time formatted as "EEE, MMM d yyyy" / "h:mm a"; day number shown large, month abbreviation below.

---

### View Appointments — "Excel" export button (Desktop only)

- **Platform**: Desktop only (`FormFactorFeatures.showPatientsImportExport`)
- **Location**: Doctor > My Patients > patient > View Appointments sheet > header, green "Excel" button (download icon)
- **Expected Behavior**: Exports all of this patient's appointments (both upcoming and previous, as currently loaded) to an `.xlsx` file named `<SanitizedPatientName>_appointments.xlsx` with columns: Patient Name, Date (dd/MM/yyyy), Time (h:mm a), Notes, Status. Triggers a file download.
- **Test Steps**:
  1. On Desktop, open View Appointments for a patient with at least one appointment.
  2. Tap "Excel".
  3. Confirm a file `<patientname>_appointments.xlsx` (special characters replaced with `_`) downloads with the correct columns/rows.
  4. For a patient with zero appointments, confirm the "Excel" button is disabled (cannot be tapped).
- **Edge Cases / Notes**: Button hidden entirely on Mobile.

---

### Patient Actions — "Add Documentation"

- **Platform**: Both
- **Location**: Doctor > My Patients > tap patient > "Add Documentation" tile
- **Expected Behavior**: Closes the sheet and navigates to the SOAP Note screen for this patient (`SoapNoteScreen` with `patientId`/`patientName`).
- **Test Steps**:
  1. Tap "Add Documentation" for any patient.
  2. Confirm navigation to the SOAP note creation screen, pre-associated with this patient.
- **Edge Cases / Notes**: Subtitle text is the localized "doctor only" SOAP string.

---

### Patient Actions — "Call / WhatsApp"

- **Platform**: Both (only visible if patient has a phone number)
- **Location**: Doctor > My Patients > tap patient (with phone) > "Call / WhatsApp" tile
- **Expected Behavior**: Closes the sheet and opens a small bottom sheet showing the phone number as a title, then two list items: "WhatsApp" (chat icon, green) and "Phone Call" (phone icon, primary color).
- **Test Steps**:
  1. Tap "Call / WhatsApp" for a patient that has a phone number.
  2. Confirm a sheet appears showing the phone number, then "WhatsApp" and "Phone Call" rows.
  3. Tap "WhatsApp" — confirm the sheet closes and an external browser/app launch is attempted to `https://wa.me/<digits-only-phone>`.
  4. Re-open and tap "Phone Call" — confirm the sheet closes and a `tel:<digits-only-phone>` URL launch is attempted.
- **Edge Cases / Notes**: The phone number is "cleaned" by stripping spaces, hyphens, and parentheses before building the WhatsApp/tel URI. This same phone-options sheet is also reachable by tapping a patient's phone number directly in the Desktop table row (underlined green text) and from the Polyclinic doctor card phone number.

---

### Patient Actions — "Create Account" (only if patient has no account)

- **Platform**: Both
- **Location**: Doctor > My Patients > tap patient without an account > "Create Account" tile (also reachable via the "+ Account" button in the Desktop table's Account column)
- **Expected Behavior**: Closes the sheet and navigates to CreatePatientScreen, prefilled with the patient's name (and, when reached from the table's "+ Account" button, also passes `existingPatientId` so the new auth account merges into the existing stub record).
- **Test Steps**:
  1. Identify a patient without an account (grey status dot on Mobile card / grey dot + "+ Account" button on Desktop table).
  2. Tap the patient row/card → tap "Create Account" in the actions sheet. Confirm navigation to the Create Patient screen with Name pre-filled.
  3. Alternatively on Desktop, tap the "+ Account" button directly in the Account column.
  4. Complete the Create Patient form (see Create Patient Screen section) and confirm the stub patient is merged (appointments/notes/notifications/invoices reassigned, doctor links inherited, stub deleted) — see "Edge Cases" of the Create Patient screen.
- **Edge Cases / Notes**: When reached via the actions-sheet tile, `existingPatientId` is NOT passed (a fresh independent account is created) — only the table's "+ Account" button passes `existingPatientId: hasAccount ? null : patientId` for the merge flow.

---

### Patient Actions — "Remove from My Patients"

- **Platform**: Both
- **Location**: Doctor > My Patients > tap patient > "Remove from My Patients" tile (red)
- **Expected Behavior**: Closes the actions sheet, then shows a confirmation dialog titled "Remove Patient" with text "Remove `<patientName>` from your patient list?" and "Cancel"/"Remove" (red) buttons. On confirm, unlinks the patient from the doctor's `assigned_patient_ids` and removes the doctor from the patient's `doctor_ids`, then shows a green success snackbar "`<patientName>` removed from your list."
- **Test Steps**:
  1. Tap a patient row/card > "Remove from My Patients".
  2. Confirm dialog "Remove Patient" appears with the correct patient name in the body text.
  3. Tap "Cancel" — confirm dialog closes with no change, patient remains in the list.
  4. Repeat and tap "Remove" (red button).
  5. Confirm the dialog closes, a green snackbar "`<patientName>` removed from your list." appears, and the patient disappears from My Patients (list refreshes via stream).
- **Edge Cases / Notes**: This unlinks/removes from the doctor's roster only — it does not delete the patient's account or data globally.

---

### "Active" status pill / "+ Account" button (Desktop table, Account column)

- **Platform**: Desktop only (this column only exists in `_buildPatientsTable`)
- **Location**: Doctor > My Patients tab > table > "Account" column (rightmost)
- **Expected Behavior**: If the patient has an account, shows a green "Active" pill (non-interactive). If not, shows a blue "+ Account" elevated button.
- **Test Steps**:
  1. For a patient with an account, confirm a green pill labeled "Active" (no tap action).
  2. For a patient without an account, confirm a blue "+ Account" button; tapping it navigates to CreatePatientScreen prefilled with the patient's name and `existingPatientId` set for merging.
- **Edge Cases / Notes**: See "Create Account" item above for merge behavior.

---

### Patient phone number link (Desktop table only)

- **Platform**: Desktop only (visible in the table row's name cell, under the patient name)
- **Location**: Doctor > My Patients tab > table row > under patient name (green underlined text)
- **Expected Behavior**: If the patient has a phone number, it's shown as green underlined text under the name. Tapping it launches `https://wa.me/<digits-only-phone>` directly in an external app/browser (does NOT open the phone-options sheet — this is a direct WhatsApp launch, distinct from the "Call / WhatsApp" action tile).
- **Test Steps**:
  1. On Desktop, find a patient row with a phone number shown under their name in green/underlined.
  2. Tap it and confirm an external WhatsApp link launch is attempted to `https://wa.me/<cleaned phone>`.
- **Edge Cases / Notes**: This is a different code path than `_showPhoneOptions` — tapping the inline phone text goes straight to WhatsApp, while the "Call / WhatsApp" action-sheet tile offers a choice between WhatsApp and Phone Call.

---

## My Profile Tab

### My Profile Tab — overview

**Platform**: Both, single-column layout on both Mobile and Desktop (content is in a `SingleChildScrollView`). No layout-specific branching observed in this tab's build method.

---

### Edit Profile button

- **Platform**: Both
- **Location**: Doctor > My Profile tab > header card (blue background) > "Edit Info" button (edit icon, white background)
- **Expected Behavior**: Opens the "Edit Profile" bottom sheet (see below).
- **Test Steps**:
  1. Go to My Profile tab.
  2. Tap the "Edit Info" button in the blue header.
  3. Confirm the Edit Profile bottom sheet opens.
- **Edge Cases / Notes**: Label text comes from `s.editInfo` (localized).

---

### Update Location button (location picker entry point)

- **Platform**: Both
- **Location**: Doctor > My Profile tab > header card > "Update Location" outlined button (map icon, white outline)
- **Expected Behavior**: Navigates to the Set Clinic Location screen (`DoctorLocationPickerScreen`), pre-loaded with the doctor's current `_lat`/`_lng` if set. On return with a result (LatLng), updates the in-memory `_lat`/`_lng` for this session.
- **Test Steps**:
  1. Tap "Update Location".
  2. Confirm navigation to "Set Clinic Location" screen (app bar title bold, teal/doctor-gradient background).
  3. On the location picker screen:
     a. Confirm the search bar (hint "Search for an address or place") and an instruction banner "Search an address, or tap the map to pin your clinic." with a touch-app icon.
     b. Type an address/place name and submit (Enter or tap the search icon). Confirm results list appears (each item: location pin icon + display name, max 2 lines). If no results, confirm snackbar "No matching locations found."
     c. Tap a search result — confirm the map recenters/zooms to that location (zoom 15), the search field is filled with the selected address, and a green location pin marker appears on the map.
     d. Tap directly on the map — confirm a green pin marker is placed at the tapped coordinates and any open search results list is cleared.
     e. Confirm a coordinates readout (e.g. "31.94540, 35.92840") appears near the bottom once a location is picked.
     f. Tap the "Use GPS" icon button (top-right, my_location icon) — confirm a loading spinner replaces the icon while locating, then the map recenters to the device's current location (or shows an error/permission snackbar if denied).
     g. Tap "Save Clinic Location" (bottom button, becomes enabled once a pin is placed; shows "Tap map to pin location" and stays disabled if nothing picked yet).
     h. Confirm a green success snackbar "Clinic location saved!" appears and you're returned to My Profile.
- **Edge Cases / Notes**:
  - On Windows, if GPS permission is denied, the snackbar says "Location denied. Enable in Windows Settings → Privacy & security → Location."; on other platforms, "Location permission denied. Enable in settings."
  - The Save button is disabled (`onPressed: null`) until a location is picked, and shows a spinner while saving.
  - If saving fails, an error snackbar "Error: <e>" appears and the saving state resets (button re-enabled).
  - Search uses Nominatim (OpenStreetMap) with a 5-result limit and a custom User-Agent header.

---

### Home Visit toggle

- **Platform**: Both
- **Location**: Doctor > My Profile tab > header card > "Home Visit" row with a Switch
- **Expected Behavior**: Toggling the switch updates local state immediately (`_homeVisit`). The value is persisted only when "Save Profile" is pressed in the Edit Profile sheet (via `_service.saveProfile(offersHomeVisit: _homeVisit, ...)`).
- **Test Steps**:
  1. Toggle the "Home Visit" switch on/off directly from the profile header.
  2. Confirm the switch visually updates immediately.
  3. Reload/navigate away and back without opening Edit Profile — confirm whether the toggle persists (it should NOT persist unless saved via Edit Profile, since this toggle alone does not call the save service).
  4. Toggle it, then open Edit Profile and tap "Save Profile" — confirm the value now persists across reloads.
- **Edge Cases / Notes**: This is a quick-access duplicate of a setting that's otherwise only saved through the Edit Profile sheet's Save button — toggling here without saving may be misleading to testers; verify actual persistence behavior.

---

### Plan & Subscription card

- **Platform**: Both
- **Location**: Doctor > My Profile tab > "Plan & Subscription" card (workspace_premium icon)
- **Expected Behavior**: Shows "Current Plan" (a colored pill with tier icon + label, e.g. "Basic"/"Pro"), "Expiry Date" (formatted "MMM d, yyyy" or "No expiry"; red text if expired), and a status chip ("Active" green / "Expired" or "Disabled" red). Below, a row of feature-access chips: "Schedule", "Documentation", "My Patients" (always shown enabled/checked), "Statistics", "Income", "Expenses" (each enabled/locked based on `_sub.statistics`, `_sub.billing`, `_sub.expenses`).
- **Test Steps**:
  1. Go to My Profile tab and locate the "Plan & Subscription" card near the top of the scrollable content.
  2. Confirm the tier pill shows the correct plan name/icon/color for the current account's subscription tier.
  3. Confirm "Expiry Date" shows either a formatted date or "No expiry"; if the subscription is expired, confirm the date text is red and the status chip reads "Expired" (red background `#FFEBEE`).
  4. If active, confirm the status chip reads "Active" with green background (`#E8F5E9`) and text color `#2E7D32`.
  5. Confirm the feature chips: "Schedule", "Documentation", "My Patients" always show a green checkmark (enabled) regardless of plan; "Statistics", "Income", "Expenses" show either a checkmark (enabled, primary-colored) or a lock icon (disabled, grey) depending on the subscription's `statistics`/`billing`/`expenses` flags.
- **Edge Cases / Notes**: This card is read-only/informational — no interactive elements beyond display. If `_sub.isActive` is false at all, the entire dashboard is replaced by the "Account Expired"/"Account Not Activated" overlay (see below) before this tab is even reachable — so this card's "Disabled"/"Expired" chip states may only be visually reachable in edge states.

---

### Account inactive/expired overlay (pre-dashboard gate)

- **Platform**: Both
- **Location**: Doctor dashboard root — shown instead of any tab when `!_sub.isActive`
- **Expected Behavior**: Full-screen centered message. If expired: icon `timer_off_rounded` (orange-tinted circle), title "Account Expired", body "Your subscription has expired on `<date>`. Please contact the administrator to renew your plan." If not yet activated: icon `lock_outline_rounded` (grey circle), title "Account Not Activated", body "Your account is pending activation. Please contact the administrator to enable your account and choose a plan." Below either message, a "Logout"-labeled button (logout icon) signs the user out.
- **Test Steps**:
  1. With an account whose subscription is expired or not yet activated, log in as a doctor.
  2. Confirm the appropriate overlay (Expired vs Not Activated) renders instead of the normal dashboard tabs.
  3. Tap the logout button (icon `logout_rounded`, label = `s.logout`) and confirm it signs out (returns to login screen).
- **Edge Cases / Notes**: This is a blocking screen — none of the tabs (including My Patients/My Profile/Polyclinic) are reachable in this state.

---

### Personal Information section (read-only display)

- **Platform**: Both
- **Location**: Doctor > My Profile tab > "Personal Information" card
- **Expected Behavior**: Displays read-only rows (icon + label + value) for: Full Name, Specialization, Clinic Name, Clinic Address, and (only if set) Working Hours. Each value falls back to "—" if empty.
- **Test Steps**:
  1. Confirm the card title matches `s.personalInformation`.
  2. Confirm each row shows the correct icon (person, medical_services, business, location_on, access_time for Working Hours) and the current profile value, or "—" if blank.
  3. Confirm "Working Hours" row is hidden entirely if `_workingHoursCtrl.text` is empty.
- **Edge Cases / Notes**: Purely informational; edits happen via the Edit Profile sheet.

---

### Professional Overview section (read-only display)

- **Platform**: Both
- **Location**: Doctor > My Profile tab > "Professional Overview" card
- **Expected Behavior**: Displays static/hardcoded rows: Experience ("12 <years of experience>"), Certifications ("DPT, CMT"), Expertise Areas ("Pediatric Rehab, Sports Therapy"), Languages ("Arabic, English").
- **Test Steps**:
  1. Confirm the card renders with title `s.professionalOverview` and the four rows with the icons school, verified, star, language respectively.
- **Edge Cases / Notes**: These values appear to be hardcoded placeholders (not pulled from any editable field) — flag if this seems unintentional, but it is out of scope to "fix"; just confirm it renders without error.

---

### Name change request card

- **Platform**: Both
- **Location**: Doctor > My Profile tab > "Display Name" card (below Professional Overview)
- **Expected Behavior**: Three states based on `_nameChangeRequest`:
  - **none/default**: Icon = drive_file_rename_outline (grey), shows "Current: `<current name>`", helper text "Name changes require admin approval", and a blue "Request Name Change" button.
  - **pending**: Icon = hourglass_top (amber `#F57F17`), shows `Pending — change to "<pendingName>"`, helper text "Your request is awaiting admin review", and a red-outlined "Cancel Request" button.
  - **declined**: Icon = cancel (red/error), shows "Request declined", helper text "Your request was declined — you may submit a new one", and a blue "Re-request Name Change" button.
- **Test Steps**:
  1. **From "none" state**: tap "Request Name Change". Confirm a dialog "Request Name Change" opens with explanatory text "Enter your requested new name. An admin will review and approve it." and a "New Name" text field (prefilled with current name, person icon).
  2. In the dialog, tap "Cancel" — confirm dialog closes with no change.
  3. Re-open, clear the field or leave it equal to the current name, tap "Submit" — confirm the dialog just closes with NO request submitted (since `name.isEmpty || name == currentName` short-circuits).
  4. Re-open, enter a genuinely different name, tap "Submit" — confirm the dialog closes and the card transitions to "pending" state showing `Pending — change to "<new name>"`.
  5. **From "pending" state**: tap "Cancel Request" (red outlined button) — confirm the card reverts to "none" state, clearing the pending name.
  6. **Simulate "declined" state** (e.g. via admin action) and confirm the card shows "Request declined" with a "Re-request Name Change" button that re-opens the same dialog.
- **Edge Cases / Notes**: Submitting an empty name or the same name as current is silently a no-op (dialog just closes). The underlying request writes `pending_name` and `name_change_request: 'pending'` to the user's row; cancel clears both fields to null.

---

### Dr. prefix request card

- **Platform**: Both
- **Location**: Doctor > My Profile tab > "Show 'Dr.' Prefix" card (below Name Change card)
- **Expected Behavior**: Four states based on `_drPrefixStatus`:
  - **none**: Icon = badge_outlined (grey), label "Not requested", sublabel 'Request admin approval to show "Dr." before your name', blue "Request Dr. Prefix" button.
  - **pending**: Icon = hourglass_top (amber), label "Pending approval", sublabel "Your request is awaiting admin review", red-outlined "Cancel Request" button (no primary action button).
  - **approved**: Icon = verified (green), label 'Approved — "Dr." is shown', sublabel "Admin approved your Dr. prefix", red "Remove Prefix" button.
  - **declined**: Icon = cancel (red/error), label "Request declined", sublabel "You may submit a new request", blue "Re-request Dr. Prefix" button.
- **Test Steps**:
  1. **From "none"**: tap "Request Dr. Prefix". Confirm a snackbar appears: "Request sent — awaiting admin approval" (blue background `#1565C0`), and the card transitions to "pending" state.
  2. **From "pending"**: tap "Cancel Request" — confirm the card reverts to "none" state (and `show_dr_prefix` is cleared).
  3. **Simulate "approved" state**: confirm the green verified icon, "Approved" label, and a red "Remove Prefix" button. Tap it — confirm it calls the same cancel action, reverting to "none" and clearing `show_dr_prefix`.
  4. **Simulate "declined" state**: confirm red cancel icon, "Request declined" label, and blue "Re-request Dr. Prefix" button; tapping it re-sends the request (transitions to "pending" again with the same snackbar as step 1).
- **Edge Cases / Notes**: "Cancel Request" (pending) and "Remove Prefix" (approved) both call `_cancelDrPrefixRequest`, which sets `dr_prefix_request: null` and `show_dr_prefix: false` server-side and updates local state to "none".

---

### Delete Account button

- **Platform**: Both
- **Location**: Doctor > My Profile tab > bottom of page, centered small outlined red button "Delete Account" (delete_forever icon)
- **Expected Behavior**: Tapping opens a confirmation dialog titled "Delete Account" with body "This permanently deletes all your data and cannot be undone. Are you sure?" and "Cancel"/"Delete" (red text) actions. On confirming "Delete", the button shows a small spinner and label "Deleting..." while `AuthService().deleteMyAccount()` runs. On error, shows a snackbar "Error: `<error>`"; on success the account/session presumably ends.
- **Test Steps**:
  1. Scroll to the bottom of My Profile and confirm the small red-outlined "Delete Account" button (icon `delete_forever_rounded`, 16px, red) is present — note it is described as "smaller version — already done" per project notes, so just confirm sizing looks compact/secondary, not a large prominent CTA.
  2. Tap it — confirm the "Delete Account" confirmation dialog appears with the exact warning text above.
  3. Tap "Cancel" — confirm dialog closes, no account change.
  4. Re-open and tap "Delete" (red text) — confirm the button switches to a small red spinner + "Deleting..." label while the deletion request is in flight.
  5. On failure (if reproducible), confirm an error snackbar "Error: `<message>`" appears and the button returns to its normal "Delete Account" state.
  6. On success, confirm the user is signed out / account removed (verify per `AuthService().deleteMyAccount()` behavior — likely redirects to login).
- **Edge Cases / Notes**: Button is disabled while `_deletingAccount` is true (prevents double taps).

---

### Sign Out (logout)

- **Platform**: Both
- **Location**: Doctor dashboard > accessible via the navigation/menu (logout entry — triggers `_showLogout`); also a direct sign-out on the "Account Not Activated/Expired" overlay.
- **Expected Behavior**: Shows a confirmation dialog titled with `s.logout`, body `s.areYouSure`, actions "Cancel" and a red `s.signOut` button. Confirming calls `Supabase.instance.client.auth.signOut()`, ending the session and returning to the login screen.
- **Test Steps**:
  1. Trigger the logout action from wherever it's exposed in the navigation (e.g., drawer/menu — confirm exact location while testing since it wasn't in the read range but the handler `_showLogout` exists).
  2. Confirm a dialog appears with title = localized "Logout" and body = localized "Are you sure?".
  3. Tap "Cancel" — confirm dialog closes, session remains active.
  4. Re-open and tap the red "Sign Out" button — confirm the dialog closes and the session ends (redirect to login/landing screen).
- **Edge Cases / Notes**: A second, simpler sign-out path exists on the "Account Not Activated"/"Account Expired" overlay — a button labeled with `s.logout` (icon `logout_rounded`) that calls `signOut()` directly with NO confirmation dialog. Verify both paths during testing of locked/expired accounts.

---

### Edit Profile sheet — Profile Photo upload

- **Platform**: Both
- **Location**: Doctor > My Profile > "Edit Info" > Edit Profile sheet > "Profile Photo" section (top of sheet, light-blue background)
- **Expected Behavior**: Shows a circular avatar (current photo or person icon placeholder), an "Upload Photo" button (upload icon, primary background), and — only if a photo URL is currently set — a "Remove" text button (delete icon).
  - "Upload Photo": opens the image picker (gallery), allows selecting an image (quality 70%, max width 800px). Shows a snackbar "Uploading profile photo..." (1s), uploads to Supabase Storage bucket `profile-photos` under `profile_photos/doctors/<uid>_<timestamp>.jpg`, then updates the photo field with the new public URL and shows a green "Photo uploaded successfully" snackbar (2s). On error, shows a red "Upload failed: `<e>`" snackbar (2s).
  - "Remove": clears the photo field locally (sets `_photoCtrl` to empty) — does not delete from storage, and the change is only persisted when "Save Profile" is tapped.
- **Test Steps**:
  1. Open Edit Profile sheet.
  2. If no photo is set, confirm avatar shows a placeholder person icon and NO "Remove" button.
  3. Tap "Upload Photo" — confirm an image picker (gallery) opens.
  4. Pick an image — confirm a brief "Uploading profile photo..." snackbar appears, then (on success) the avatar updates to show the new image and a green "Photo uploaded successfully" snackbar appears.
  5. Confirm the "Remove" text button now appears (since the photo field is non-empty).
  6. Tap "Remove" — confirm the avatar reverts to the placeholder icon immediately (local state only).
  7. Without saving, close the sheet and reopen — confirm whether the removal persisted (it should NOT, since Save Profile wasn't tapped) vs. if you tap "Save Profile" after removing, confirm the photo is cleared server-side too.
- **Edge Cases / Notes**: Upload failures show a red snackbar "Upload failed: `<e>`". The "Remove" button only appears when `_photoCtrl.text.isNotEmpty`.

---

### Edit Profile sheet — Full Name (read-only)

- **Platform**: Both
- **Location**: Doctor > My Profile > Edit Profile sheet > grey "Full Name" box (below Profile Photo)
- **Expected Behavior**: Displays the current name in a disabled-looking grey box with a lock icon (`lock_outline_rounded`) on the right and a person-outline icon on the left — it is NOT an editable text field. Name changes must go through the "Request Name Change" flow on the main profile page.
- **Test Steps**:
  1. Open Edit Profile sheet and locate the "Full Name" row.
  2. Confirm it renders as a static grey box (not a TextField) showing the current name (or "—" if empty), with a lock icon, and tapping it does nothing.
- **Edge Cases / Notes**: This reinforces that name edits are only possible via the Name Change Request card on the main profile screen, not here.

---

### Edit Profile sheet — editable fields

- **Platform**: Both
- **Location**: Doctor > My Profile > Edit Profile sheet > form fields below the read-only Full Name box
- **Expected Behavior** (each is a standard TextField, white fill, rounded border, with prefix icon):
  - **Specialization** (`_specCtrl`, icon: medical_services_outlined)
  - **Clinic Name** (`_clinicNameCtrl`, icon: business_rounded)
  - **Clinic Address** (`_clinicAddrCtrl`, icon: location_on_outlined, multi-line: 2 lines)
  - **Working Hours** (`_workingHoursCtrl`, icon: access_time_rounded, multi-line: 3 lines, hint: "e.g. Mon–Fri: 9am–5pm, Sat: 9am–1pm")
- **Test Steps**:
  1. Open Edit Profile sheet and confirm all four fields render with the correct labels, icons, and (for Clinic Address / Working Hours) multi-line input behavior.
  2. Edit each field's value.
  3. Tap "Save Profile" (see next item) and confirm the values persist and reflect on the main My Profile page (Personal Information section) after the sheet closes.
- **Edge Cases / Notes**: "Working Hours" row only displays on the main profile page if non-empty (see Personal Information section item).

---

### Edit Profile sheet — Save Profile button

- **Platform**: Both
- **Location**: Doctor > My Profile > Edit Profile sheet > bottom, full-width "Save Profile" button (save icon)
- **Expected Behavior**: Closes the sheet immediately, then calls `_service.saveProfile(...)` with bio, profilePhotoUrl, specialization, clinicName, clinicAddress, offersHomeVisit, workingHours. On success, shows a green snackbar with `s.profileSaved`. On failure, shows a red snackbar "Error saving profile".
- **Test Steps**:
  1. Make edits to one or more fields (and/or toggle Home Visit, and/or change the photo).
  2. Tap "Save Profile".
  3. Confirm the sheet closes immediately (before the save completes).
  4. Confirm a snackbar appears: green with `s.profileSaved` text on success, or red "Error saving profile" on failure.
  5. Confirm the My Profile page now reflects the saved values (Personal Information card, header name/specialization, photo).
- **Edge Cases / Notes**: The sheet closes BEFORE the save result is known — if save fails, the user only sees the error via snackbar after returning to the main profile screen, with the sheet already dismissed (so they'd need to reopen Edit Profile to retry).

---

## Import Patients & Schedule from Excel (Desktop only)

### Import Schedule from Excel flow

- **Platform**: Desktop only (`FormFactorFeatures.showPatientsImportExport`/`showScheduleImportExport`)
- **Location**: Likely reached from the Schedule tab's import action (the function `_importScheduleFromExcel` is defined in this file; entry point button is outside the read range but follows the same "Import from Excel" pattern as My Patients).
- **Expected Behavior**: Opens a file picker (`.xlsx`/`.xls`). Reads the file; if empty, snackbar "No data found in the file." Auto-detects date/name columns from header keywords ("date"/"appt"/"appointment" → date column; "name"/"patient" → name column; defaults: col A = date, col B = name). Groups rows by patient name (one entry per unique name with a list of dates). Matches each name against the doctor's existing assigned patients (exact name match → fuzzy contains-match → email contains-match). If no entries found, snackbar "No entries found in the file." Otherwise opens the Schedule Import Preview sheet.
- **Test Steps**:
  1. Trigger "Import Schedule from Excel" (Desktop, from wherever it's wired in the Schedule tab).
  2. Pick a valid `.xlsx` with columns Date, Patient Name (with or without a header row).
  3. Confirm a brief "Reading Excel file…" loading dialog appears, then the Schedule Import Preview sheet opens.
  4. Try an empty file — confirm "No data found in the file." snackbar.
  5. Try a file where all name cells are blank — confirm "No entries found in the file." snackbar.
- **Edge Cases / Notes**: Date parsing supports formats: dd/MM/yyyy, d/M/yyyy, yyyy-MM-dd, MM/dd/yyyy, M/d/yyyy, MM-dd-yyyy, dd/MM/yy, d/M/yy, plus raw ISO strings and Excel serial-date numbers (e.g. "45296.0").

---

### Schedule Import Preview sheet

- **Platform**: Desktop only
- **Location**: Doctor > (Schedule import flow) > "Schedule Import" preview bottom sheet (draggable, 45–95% height)
- **Expected Behavior**:
  - Header: tri-state "select all" checkbox, title "Schedule Import · `<selected>` / `<total>` selected", and a summary row: green check icon + "`<matched>` matched", plus (if any unmatched) amber warning icon + "`<unmatched>` not in My Patients".
  - Entry list: each row has a checkbox, a status icon (green person icon if matched / amber person-off icon if unmatched), the patient name, a pill "In My Patients" (green) or "Not found" (amber), and a wrap of date chips (each showing an icon — history for past dates, event for future — and the date "MMM d, yyyy"; past dates greyed, future dates blue). If no valid dates, shows "No date".
  - Footer: if any unmatched entries are selected, an info row "Unmatched patients will be imported as stubs and added to My Patients." Then a full-width button "Import `<selected>` Appointment(s)" (event_available icon), disabled (grey) when 0 selected.
- **Test Steps**:
  1. Confirm the tri-state checkbox: tap it when all are selected → all deselect; tap when none/some selected → all select.
  2. Tap an individual row (or its checkbox) to toggle selection — confirm the name text dims to grey when deselected and the "selected" count in the header updates.
  3. Confirm matched vs unmatched entries show the correct icon/pill/colors as described.
  4. Confirm date chips render correctly for past (grey, history icon) vs future (blue, event icon) dates, and "No date" shows for entries without valid dates.
  5. With at least one unmatched + selected entry, confirm the info banner about stub import appears.
  6. With 0 selected, confirm the bottom button is disabled (grey, label still shows "Import 0 Appointment(s)").
  7. Select some entries and tap "Import `<n>` Appointment(s)".
- **Edge Cases / Notes**: Same-day duplicate dates for one patient are deduplicated during import (only one appointment created per calendar day).

---

### Schedule Import — execute import

- **Platform**: Desktop only
- **Location**: Doctor > Schedule Import Preview sheet > "Import `<n>` Appointment(s)" button
- **Expected Behavior**: For each selected entry: if unmatched (no `patientId`), creates a new stub patient row (role=patient, linked to this doctor) and sends a "patient added" notification; for each valid date (deduped per day), creates an appointment with status `completed` (past) or `scheduled` (future). After processing, closes the sheet and shows a green snackbar "`<apptCount>` appointment(s) added to your schedule."
- **Test Steps**:
  1. From the preview sheet, with a mix of matched and unmatched entries selected, tap "Import `<n>` Appointment(s)".
  2. Confirm the sheet closes and a green success snackbar shows the correct total appointment count.
  3. Confirm new appointments appear in the Schedule tab (past ones as "completed", future ones as "scheduled").
  4. For any unmatched entries that were selected, confirm new stub patients now appear in My Patients (and they received an "added" notification, verifiable from the patient side if accessible).
- **Edge Cases / Notes**: None additional beyond dedup-by-day noted above.

---

### Import Patients from Excel — file picker

- **Platform**: Desktop only (`showPatientsImportExport`)
- **Location**: Doctor > My Patients > Add Patient sheet > "Import from Excel" tile (see earlier item)
- **Expected Behavior**: Same column auto-detection as schedule import (default col A = date, col B = name; header keywords "name"/"patient" and "date"/"appt"/"appointment"). Groups rows by patient name with their dates. If the file is empty: snackbar "No data found in the file." If no patient names found: snackbar "No patients found in the file." Otherwise opens the Import Preview sheet (`_showImportPreviewSheet`).
- **Test Steps**:
  1. Tap "Import from Excel" (My Patients > Add Patient sheet).
  2. Pick an empty `.xlsx` — confirm "No data found in the file." snackbar.
  3. Pick a file with rows but no names in the name column — confirm "No patients found in the file." snackbar.
  4. Pick a valid file — confirm "Reading Excel file…" loading dialog, then the Import Preview sheet opens.
- **Edge Cases / Notes**: Unlike the schedule import, this flow does NOT attempt to match against existing patients in the preview — every entry is treated as a name+dates group with a per-entry "create account" toggle (see below).

---

### Import Patients — Preview sheet

- **Platform**: Desktop only
- **Location**: Doctor > My Patients > Import from Excel > "Import Preview" bottom sheet (draggable, 45–95% height)
- **Expected Behavior**:
  - Header: tri-state "select all" checkbox, title "Import Preview · `<selected>` / `<total>` selected", subtitle 'Toggle "Account" to create a login for the patient'.
  - Entry list: each row has a checkbox, an avatar showing the patient's first initial (colored if selected, grey if not), the name (dimmed grey if deselected), date chips (same styling as schedule import: past=grey/history icon, future=blue/event icon, or "No appointment date" if none), and on the right an "Account" label + Switch toggle (`e.createAccount`).
  - Footer: if any selected entries have `createAccount` enabled, an info row "`<n>` patient(s) will need account credentials after import." Then a full-width button: while idle, "Import `<n>` Patient(s)" (upload icon); while importing, a spinner + "Importing…"; disabled (grey) when 0 selected or while importing.
- **Test Steps**:
  1. Confirm the tri-state "select all" checkbox toggles all entries on/off.
  2. Tap a row to toggle its selection — confirm avatar color and name color change accordingly.
  3. Toggle the "Account" switch for an entry — confirm the label color changes (primary when on, grey when off) and the footer's "need account" count updates.
  4. Confirm date chips render correctly (past vs future styling), and entries with no dates show "No appointment date".
  5. With 0 selected, confirm the import button is disabled and reads "Import 0 Patient(s)".
  6. Select 1+ entries (with at least one "Account" toggle on) and tap "Import `<n>` Patient(s)".
  7. Confirm the button switches to a spinner + "Importing…" and becomes unresponsive to further taps during import.
- **Edge Cases / Notes**: None additional.

---

### Import Patients — execute import

- **Platform**: Desktop only
- **Location**: Doctor > My Patients > Import Preview sheet > "Import `<n>` Patient(s)" button
- **Expected Behavior**: For each selected entry: looks up an existing patient by exact name match (role=patient); if found, links the doctor to that patient (`doctor_ids`) if not already linked; if not found, creates a new stub patient row. Keeps the doctor's `assigned_patient_ids` in sync. Sends a "patient added" notification. For each valid date, creates an appointment (status `completed`/`scheduled` based on past/future). Tracks entries with `createAccount=true` in a `needAccount` map (name → patientId).
  - On success: closes the preview sheet, shows green snackbar "`<patientsCount>` patient(s) · `<apptCount>` appointment(s) imported." If `needAccount` is non-empty, opens the "Pending accounts" sheet.
  - On error (exception during import): closes the preview sheet and shows a red snackbar "Import failed: `<e>`".
- **Test Steps**:
  1. From the preview sheet, select entries (mix of new names and possibly a name matching an existing patient), with at least one "Account" toggle enabled, and tap "Import `<n>` Patient(s)".
  2. Confirm the sheet closes and a green snackbar shows correct counts "`<n>` patient(s) · `<m>` appointment(s) imported."
  3. Confirm new patients appear in My Patients, and appointments are created with correct statuses.
  4. Since at least one entry had "Account" toggled on, confirm the "Pending accounts" sheet (`_showPendingAccountsSheet`) opens automatically.
  5. To test the error path (if reproducible, e.g. by disconnecting network mid-import): confirm sheet closes and red "Import failed: `<e>`" snackbar appears.
- **Edge Cases / Notes**: Matching for "existing patient" here is an EXACT name match only (unlike the fuzzy matching in the schedule-import flow) — verify this distinction if testing both flows side by side.

---

### Pending Accounts sheet

- **Platform**: Desktop only (follows from Import Patients flow)
- **Location**: Doctor > My Patients > Import from Excel > (after import, if any entries had "Account" toggled on) "Set Up `<n>` Account(s)" bottom sheet
- **Expected Behavior**: Header row with manage_accounts icon and title "Set Up `<n>` Account(s)", subtitle "Create login credentials for the following patients." Below, a list of ListTiles — one per pending patient — each with an avatar (first-letter initial), the patient's name, and a primary-colored "Create Account" button.
- **Test Steps**:
  1. After an import with `createAccount`-toggled entries, confirm this sheet opens automatically with the correct count in the title.
  2. Confirm each pending patient is listed with their initial-avatar, name, and a "Create Account" button.
  3. Tap "Create Account" for one entry — confirm the sheet closes and navigation goes to CreatePatientScreen, prefilled with that patient's name and `existingPatientId` set (so the new auth account merges into the stub created during import).
  4. Complete the Create Patient form (see Create Patient Screen) and confirm the merge succeeds (appointments/notes/notifications/invoices reassigned to the new account, stub deleted).
- **Edge Cases / Notes**: If the user dismisses this sheet without creating accounts for all listed patients, those patients remain as stub records without logins (can still be converted later via the "+ Account" button in the table or the patient-actions "Create Account" tile).

---

## Create Patient Screen ("Add Patient" form)

### Add Patient form fields

- **Platform**: Both
- **Location**: Doctor > My Patients > Add Patient sheet > "Add Patient" tile > Create Patient screen (app bar title = `s.addPatient`)
- **Fields**:
  - **Patient Name** (`s.patientName`, icon: person_outline_rounded) — required.
  - **Patient Email** (`s.patientEmail`, icon: email_outlined, email keyboard) — required.
  - **Password** (`s.patientPassword`, icon: lock_outline) — required, min 6 characters; has a visibility-toggle suffix icon (eye / eye-off) to show/hide the password.
  - **Patient Phone** (`s.patientPhone`, icon: phone_outlined, phone keyboard) — optional.
  - **Date of Birth** (`s.patientDob`, icon: cake_outlined) — optional; tapping opens a date picker (initial date 1990, range 1920 to today); field is read-only (`AbsorbPointer` + `GestureDetector`).
  - **Diagnosis** (`s.diagnosis`, icon: medical_information_outlined, 2 lines) — optional.
- **Test Steps**:
  1. Open the Create Patient screen via "Add Patient".
  2. Confirm all six fields render with correct labels/icons as above.
  3. Tap the password field's visibility icon — confirm it toggles between obscured and visible text, and the icon swaps between `visibility_off`/`visibility`.
  4. Tap the Date of Birth field — confirm a date picker dialog opens (default year 1990, range 1920–today); cannot type directly into the field.
  5. Pick a date — confirm the field displays it as `d/M/yyyy`.
- **Edge Cases / Notes**: None beyond validation covered in the next item.

---

### Create Account button (Create Patient screen)

- **Platform**: Both
- **Location**: Doctor > Create Patient screen > bottom, full-width "Create Account" button (person_add icon), label = `s.createAccount`
- **Expected Behavior**: Validates that Name, Email are non-empty and Password is ≥6 characters; if not, shows snackbar "Please fill name, email, and password (min 6 chars)." On valid input, shows a loading spinner in place of the button and calls `AdminService().createPatientAccount(...)`.
  - If creation fails (returns null): red snackbar "Failed to create patient account."
  - If `existingPatientId` (stub) is set and differs from the new ID: attempts to merge the stub into the new account (`_mergeStubIntoNewAccount`) — reassigns appointments, clinical_notes, notifications (both `patient_id`/`recipient_id` directions), and invoices from the stub to the new account; copies the stub's `doctor_ids` onto the new account; for every doctor that had the stub assigned, replaces the stub ID with the new ID in their `assigned_patient_ids`; deletes the stub row.
    - If the merge throws: yellow/warning snackbar "Account created but merge failed: `<error>`" (account still created, but merge incomplete).
  - On full success: green snackbar "Patient account created for `<name>`!" and navigates back (`Navigator.pop`).
  - On any other exception: red snackbar "Error: `<e>`".
- **Test Steps**:
  1. Tap "Create Account" with empty/short fields — confirm the validation snackbar "Please fill name, email, and password (min 6 chars)." and no navigation.
  2. Fill Name, Email, and a 6+ char Password (no existing-patient merge context), tap "Create Account".
  3. Confirm a spinner replaces the button while creating.
  4. On success, confirm green snackbar "Patient account created for `<name>`!" and the screen pops back to My Patients, where the new patient now appears with an "Active"/account-having status.
  5. **Merge path**: trigger Create Patient via the "+ Account" button on an existing stub patient (so `existingPatientId` is set), fill the form, and submit.
  6. Confirm on success the stub's appointments/notes/notifications/invoices now belong to the new account, the new account inherited the stub's `doctor_ids`, and the stub row is gone from My Patients (replaced by the new account entry).
  7. If reproducible, force a merge failure and confirm the amber "Account created but merge failed: `<error>`" snackbar appears (account still exists).
- **Edge Cases / Notes**: Password minimum length is 6 characters (enforced client-side only on `.length < 6`, not via strength rules). The merge step runs in a try/catch and logs to debug console (`kDebugMode`) on failure.

---

## Polyclinic-Affiliated Doctors Tab

### My Doctors tab — overview

**Platform**: Both (no mobile/desktop branching observed in this tab's build).

---

### Add Doctor button

- **Platform**: Both
- **Location**: Doctor > Polyclinic "My Doctors" tab > top action bar, full-width teal button "Add Doctor" (person_add icon)
- **Expected Behavior**: Opens the "Create Doctor Profile" bottom sheet for adding a profile-only (no-login) internal doctor to this polyclinic.
- **Test Steps**:
  1. Go to the Polyclinic Doctors tab.
  2. Tap "Add Doctor".
  3. Confirm the "Create Doctor Profile" sheet opens (icon person_add in a teal circle, title "Create Doctor Profile", subtitle "No login account — profile only").
- **Edge Cases / Notes**: If there are zero doctors, confirm the empty state below is shown instead of a list.

---

### My Doctors — empty state

- **Platform**: Both
- **Location**: Doctor > Polyclinic "My Doctors" tab > below the "Add Doctor" bar, when no doctors are linked
- **Expected Behavior**: Centered icon (`people_outline_rounded`, large, light grey), text "No doctors yet", and helper text "Tap \"Add Doctor\" to create an internal doctor profile."
- **Test Steps**:
  1. With zero polyclinic-linked doctors, confirm the empty state renders with the exact text above.
- **Edge Cases / Notes**: None.

---

### Create Doctor Profile sheet

- **Platform**: Both
- **Location**: Doctor > Polyclinic "My Doctors" tab > "Add Doctor" > "Create Doctor Profile" sheet
- **Fields** (each via `_polyField`, teal-themed):
  - **Full Name** (icon: badge_rounded) — required (validated as non-empty before submit).
  - **Specialization** (icon: medical_services_rounded) — optional.
  - **Phone Number** (icon: phone_rounded, phone keyboard) — optional.
- **Expected Behavior**: "Create Doctor" button (check_circle icon, teal background). If Name is empty, tapping does nothing (silent no-op — `if (name.isEmpty) return;`). Otherwise shows a spinner in place of the button, creates a new `users` row (role=doctor, `has_auth_account: false`, `polyclinic_id` = this polyclinic's UID, `subscription: 'basic'`, `is_enabled: true`, `show_in_search: false`, empty bio/photo, empty `assigned_patient_ids`), appends the new doctor's ID to the polyclinic's `linked_doctor_ids`. On success: closes the sheet and shows a green snackbar 'Doctor profile "`<name>`" created'. On error (caught exception): re-enables the button (spinner removed) — no error message shown to the user.
- **Test Steps**:
  1. Open "Create Doctor Profile" sheet.
  2. Tap "Create Doctor" with Name empty — confirm nothing happens (no error, no loading state, sheet stays open).
  3. Fill in Full Name (and optionally Specialization, Phone), tap "Create Doctor".
  4. Confirm a spinner replaces the button briefly, then the sheet closes and a green snackbar 'Doctor profile "`<name>`" created' appears.
  5. Confirm the new doctor card now appears in the My Doctors list with a "Profile Only" badge (since `has_auth_account: false`).
- **Edge Cases / Notes**: On a thrown exception during creation, the UI silently resets to the editable state with no error feedback to the user — worth flagging as a potential UX gap, but just confirm the button becomes interactive again (doesn't stay stuck on a spinner).

---

### Polyclinic Doctor card — display

- **Platform**: Both
- **Location**: Doctor > Polyclinic "My Doctors" tab > each doctor's card in the list
- **Expected Behavior**: Shows a colored initials avatar (first letters of first two name words), the doctor's name (bold), specialization (if set), phone number (if set, green underlined — tappable), a badge "Has Login" (green, if `hasAuthAccount`) or "Profile Only" (amber, if not), and a patient count "`<n>` patient(s)" (singular/plural handled). A 3-dot overflow menu (`more_vert_rounded`) on the right offers: "Assign Patients", "Edit Profile", "Remove from Polyclinic" (red).
- **Test Steps**:
  1. Confirm each doctor card shows the correct initials, name, specialization (or hidden if blank), and phone (or hidden if blank).
  2. Confirm the "Has Login" vs "Profile Only" badge matches the doctor's `hasAuthAccount` flag.
  3. Confirm the patient count reflects `assigned_patient_ids.length`, with correct singular "1 patient" vs plural "`<n>` patients".
  4. If a phone number is shown, tap it — confirm it opens the phone-options sheet (WhatsApp / Phone Call), same as in My Patients.
- **Edge Cases / Notes**: None additional.

---

### Polyclinic Doctor card — overflow menu: "Assign Patients"

- **Platform**: Both
- **Location**: Doctor > Polyclinic "My Doctors" tab > doctor card > 3-dot menu > "Assign Patients" (people icon, teal)
- **Expected Behavior**: Opens the "Assign Patients" bottom sheet (80% screen height) for that doctor.
- **Test Steps**:
  1. Tap the 3-dot menu on a doctor card, select "Assign Patients".
  2. Confirm the Assign Patients sheet opens (see next item).
- **Edge Cases / Notes**: None.

---

### Polyclinic Doctor card — overflow menu: "Edit Profile"

- **Platform**: Both
- **Location**: Doctor > Polyclinic "My Doctors" tab > doctor card > 3-dot menu > "Edit Profile" (edit icon, grey)
- **Expected Behavior**: Opens the "Edit Doctor Profile" bottom sheet, prefilled with the doctor's current Full Name, Specialization, and Phone Number.
- **Test Steps**:
  1. Tap the 3-dot menu, select "Edit Profile".
  2. Confirm the sheet opens titled "Edit Doctor Profile" with the three fields prefilled with current values.
  3. Edit one or more fields and tap "Save Changes" (save icon, teal button).
  4. Confirm the sheet closes and the doctor card updates with the new values (name/specialization/phone).
- **Edge Cases / Notes**: There is no client-side validation here (unlike Create, which requires non-empty Name) — confirm behavior if Name is cleared and saved (likely saves an empty name with no warning).

---

### Polyclinic Doctor card — overflow menu: "Remove from Polyclinic"

- **Platform**: Both
- **Location**: Doctor > Polyclinic "My Doctors" tab > doctor card > 3-dot menu > "Remove from Polyclinic" (link_off icon, red text)
- **Expected Behavior**: Shows a confirmation dialog "Remove Doctor" with body 'Remove "`<name>`" from your polyclinic?' and "Cancel"/"Remove" (red) buttons. On confirm: removes the doctor's ID from the polyclinic's `linked_doctor_ids`, and clears the doctor's `polyclinic_id` to null.
- **Test Steps**:
  1. Tap the 3-dot menu, select "Remove from Polyclinic".
  2. Confirm the "Remove Doctor" dialog appears with the doctor's name in the body text.
  3. Tap "Cancel" — confirm no change, doctor remains in the list.
  4. Re-open and tap "Remove" (red) — confirm the dialog closes and the doctor card disappears from the My Doctors list (stream-driven).
- **Edge Cases / Notes**: This unlinks the doctor from the polyclinic but does not delete the doctor's profile/account itself.

---

### Assign Patients sheet

- **Platform**: Both
- **Location**: Doctor > Polyclinic "My Doctors" tab > doctor card > 3-dot menu > "Assign Patients" sheet (80% height)
- **Expected Behavior**: Header shows a people icon, title "Assign Patients", subtitle "to `<doctor name>`", and a teal pill showing "`<n>` assigned". Below, a search field (hint "Search patients...") filtering by name or phone (case-insensitive substring). Below that, a live list (StreamBuilder on all patients with role=patient) — each row shows an initials avatar, name, phone (if set), and a checkbox indicating assignment status. Tapping anywhere on the row OR the checkbox toggles assignment, immediately persisting to the doctor's `assigned_patient_ids` in Supabase.
- **Test Steps**:
  1. Open "Assign Patients" for a doctor.
  2. Confirm header shows "Assign Patients" / "to `<doctor name>`" / "`<n>` assigned" pill matching the doctor's current `assigned_patient_ids.length`.
  3. Type into the search field — confirm the patient list filters by name/phone substring (case-insensitive).
  4. With a search query that matches nothing, confirm "No results for \"`<query>`\"" message; with empty search and zero patients in the system, confirm "No patients in the system" message.
  5. Tap a patient row (not the checkbox) — confirm the checkbox toggles and the "`<n>` assigned" pill updates immediately.
  6. Tap the checkbox directly on another row — confirm the same toggle behavior.
  7. Close and reopen the sheet (or re-check via "Edit"/list) — confirm the assignment persisted (Supabase `assigned_patient_ids` updated for that doctor).
- **Edge Cases / Notes**: Both the row-tap and checkbox-tap call the same underlying update logic redundantly (two separate `onTap`/`onChanged` handlers do the same thing) — verify there's no double-toggle/race-condition glitch when tapping quickly.

---

## Doctor Dashboard — Income/Billing, Expenses & Statistics

**Platform availability overview:**
- **Income/Billing tab** (`billing_screen.dart`): Both Desktop and Mobile, with layout differences. Desktop (>700px content width) shows a wide two-column layout (invoice table + summary cards sidebar); Mobile/narrow shows a stacked single-column layout (2x2 summary cards grid above the invoice table). The "Export Report" and "Import Excel" buttons (plus their "Format" help icon) in the bottom action bar are **Desktop only** (`FormFactorFeatures.showBillingImportExport`).
- **Expenses tab** (`expenses_screen.dart`): Both Desktop and Mobile — single-column scrolling layout on all sizes (no wide/narrow split). All actions including Export Report and Import-from-Excel are visible on both platforms (not gated by `FormFactorFeatures`).
- **Statistics tab** (`session_stats_screen.dart`): **Desktop only**. The entire tab — its bottom-nav entry, home-screen tile, and screen content — is hidden on mobile (`FormFactorFeatures.showStatistics`); mobile shows an "Available on Desktop" placeholder screen instead. Also subscription-gated (Premium tier) on desktop, separate from form-factor (out of scope here).
- **Inventory screen** (`inventory_screen.dart`): Exists in code (Supabase `inventory` table CRUD, quantity adjust, low-stock warning) but has **no navigation entry anywhere in the app** — it is unreachable by any user on any platform. Not testable; no checklist items written for it.

---

### Period Selector Dropdown (Income tab)
- **Platform**: Both (same control on desktop and mobile)
- **Location**: Doctor > Income/Billing tab > top filter bar (navy background), left side
- **Expected Behavior**: A pill-shaped dropdown showing "Daily", "Weekly", "Monthly", or "Yearly" (each with a calendar icon). Selecting a new value reloads the date range, range label, summary cards, and invoice table to reflect the new period.
- **Test Steps**:
  1. Open Income/Billing tab.
  2. Tap the period dropdown (defaults to "Monthly").
  3. Select "Daily", "Weekly", or "Yearly" in turn.
  4. Confirm the date-range label (right side of the bar) and summary cards update accordingly.
- **Edge Cases / Notes**: Switching period resets the displayed range to the period containing `_refDate` (today by default, or whatever date was last picked).

### Date Range Previous/Next Arrows (Income tab)
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > top filter bar, right side, white pill containing `<` icon, range label, `>` icon
- **Expected Behavior**: Tapping `<` (chevron_left) moves the reference date back by one period (day/week/month/year depending on `_period`); tapping `>` (chevron_right) moves forward. The range label and all data (summary cards, invoice table) update to the new period.
- **Test Steps**:
  1. Note the current range label (e.g. "Jun 2026").
  2. Tap the left chevron — confirm label changes to the previous period and data refreshes.
  3. Tap the right chevron twice — confirm label advances two periods forward.
- **Edge Cases / Notes**: No artificial bound on how far back/forward you can navigate (aside from the date picker's `firstDate: 2020` / `lastDate: now+365 days` when picking directly).

### Date Range Label / Date Picker (Income tab)
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > top filter bar, center of the white pill (calendar icon + text, e.g. "Jun 2026")
- **Expected Behavior**: Tapping the label opens a native date picker. Selecting a date jumps `_refDate` to that date, recalculating the period range (daily/weekly/monthly/yearly) containing it, and refreshes all data.
- **Test Steps**:
  1. Tap the date-range label/icon in the filter bar.
  2. In the date picker, pick a date in a different month (e.g. last month).
  3. Confirm the range label updates to reflect the new period and the table/summary cards reload for that period.
- **Edge Cases / Notes**: Date picker bounds: `firstDate: Jan 1, 2020`, `lastDate: today + 365 days`.

### Search Patient Filter (Income tab)
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > top filter bar, second row, left text field ("Search patient...")
- **Expected Behavior**: Typing filters the invoice table in real time to invoices whose `patient_name` contains the typed text (case-insensitive substring match).
- **Test Steps**:
  1. Type part of a known patient's name (e.g. first 3 letters) into the "Search patient..." field.
  2. Confirm the invoice table immediately narrows to matching rows only.
  3. Clear the field and confirm the full list returns.
- **Edge Cases / Notes**: If no invoices match, the table shows the empty state (receipt icon + "No data" message). Filter is combined (AND) with the period and status filters.

### Status Filter Dropdown (Income tab)
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > top filter bar, second row, right dropdown (filter icon, defaults to "All Status")
- **Expected Behavior**: A dropdown listing "All Status", "pending", "paid", "partially paid", "insurance claim", "cancelled" (underscores replaced with spaces). Selecting a value filters the invoice table to only invoices with that `status`.
- **Test Steps**:
  1. Tap the status dropdown (defaults to "All Status").
  2. Select "paid" — confirm only paid invoices show in the table.
  3. Select "pending" — confirm only pending invoices show.
  4. Re-select "All Status" — confirm the full filtered list returns.
- **Edge Cases / Notes**: Combines with the patient-name search and period filters (AND logic). If the combination yields zero rows, the empty state is shown.

### Summary Cards (Income tab)
- **Platform**: Both (desktop shows as a vertical 280px sidebar of 4 stacked cards; mobile shows as a 2x2 grid of 4 cards)
- **Location**: Doctor > Income/Billing tab > right sidebar (desktop, width > 700px) or top of scroll area (mobile)
- **Expected Behavior**: Four colored cards display:
  - "Total Revenue" (green, `$<sum of paid + partial-paid amounts>`, subtitle "This Month"/"This Period")
  - "Pending Payments" (amber, sum of pending invoice amounts + unpaid remainder of partially-paid, subtitle "Awaiting")
  - "Insurance Claims" (grey-blue, sum of `insurance_claim` status invoices, subtitle "Processing")
  - "Transactions Completed" / "Completed" (navy, count of `paid` status invoices, subtitle "This Period"/"Transactions")
  All values recompute live as the period/filters change.
- **Test Steps**:
  1. Note current values of all 4 cards for the default "Monthly" period.
  2. Add a new "Paid" income record (see Add Income sheet) and confirm "Total Revenue" and "Transactions Completed" increase accordingly.
  3. Add a "Pending" record and confirm "Pending Payments" increases by that amount.
  4. Switch period (e.g. to "Yearly") and confirm values recompute for the wider range.
- **Edge Cases / Notes**: Currency prefix (`$`, etc.) is taken from the first filtered invoice's `currency` field, defaulting to "USD" if no records exist. Values use `FittedBox`/`scaleDown` so very large numbers shrink to fit.

### Invoice Table — Header & Empty State
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > main content area (card with navy header row: "Patient Name", "Date", "Service", "Amount", "Status")
- **Expected Behavior**: When there are no invoices for the current filters/period, shows a centered receipt icon (`receipt_long_outlined`) and "No data" message (localized via `AppStrings.noData`) inside the card body, below the header row.
- **Test Steps**:
  1. Apply a filter combination (e.g. a status + period) that yields zero invoices.
  2. Confirm the card still shows its navy header row, with the empty-state icon and message below it.
- **Edge Cases / Notes**: On desktop (wide layout) the empty state is vertically centered within the available `Expanded` space; on mobile it's just padded content within the scroll view.

### Invoice Row — Status Badge
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > each invoice table row, "Status" column
- **Expected Behavior**: A colored rounded badge showing the invoice's status label: "Pending" (amber `#F57F17`), "Paid" (green `#2E7D32`), "Partially\nPaid" (orange `#E65100`, two lines), "Insurance\nClaim" (grey-blue `#546E7A`, two lines), or "Cancelled" (red `#C62828`).
- **Test Steps**:
  1. Create or locate invoices in each status (pending, paid, partially paid, insurance claim, cancelled).
  2. Confirm each row's badge shows the correct label and background color matching the above.
- **Edge Cases / Notes**: "Partially Paid" and "Insurance Claim" labels wrap onto two lines (`\n`) inside the badge.

### Invoice Row — More Actions Menu (⋮ / `more_vert`)
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > each invoice table row, far-right icon button (`more_vert_rounded`, grey)
- **Expected Behavior**: Opens a popup menu with status-transition actions, each hidden if the invoice is already in that status:
  - "Mark as Paid" (green check icon) — sets status to `paid`.
  - "Mark Partially Paid" (orange payments icon) — opens the "Mark as Partially Paid" sheet (see separate item).
  - "Insurance Claim" (grey-blue shield icon) — sets status directly to `insurance_claim`.
  - "Cancelled" (red cancel icon, label from `AppStrings.statusCancelled`) — sets status to `cancelled`.
  Selecting "Mark as Paid", "Insurance Claim", or "Cancelled" immediately updates the invoice's `status` in Supabase (no confirmation dialog) and the row's badge updates live via the stream.
- **Test Steps**:
  1. For a "Pending" invoice, tap its `⋮` menu.
  2. Confirm menu shows: "Mark as Paid", "Mark Partially Paid", "Insurance Claim", "Cancelled" (i.e. all transitions except to its current status, "Pending" itself isn't an option since it's not in the item list at all for any status).
  3. Tap "Mark as Paid" — confirm the row's badge immediately changes to "Paid" (green) and the menu options update (now shows "Mark Partially Paid", "Insurance Claim", "Cancelled" but not "Mark as Paid").
  4. Repeat for "Insurance Claim" and "Cancelled" on other rows, confirming badge + summary cards update.
- **Edge Cases / Notes**: No undo/confirmation — status changes are immediate writes to Supabase. "Cancelled" invoices are excluded from all revenue/pending/insurance totals.

### Mark as Partially Paid Sheet
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > invoice row > `⋮` menu > "Mark Partially Paid"
- **Expected Behavior**: A bottom sheet titled "Mark as Partially Paid" showing:
  - "Total: `<currency> <totalAmt>`" (read-only, grey text).
  - "Amount Paid" text field (numeric/decimal keyboard, payments icon, orange).
  - A live "Remaining: `<currency> <remaining>`" chip (orange background) that recalculates as the Amount Paid field changes (`remaining = total - paid`, clamped to ≥ 0).
  - "Save" button (orange `#E65100`, full width).
  On Save (with a valid `paidAmt > 0`), updates the invoice's `status` to `partially_paid` and `paid_amount` to the entered value, then closes the sheet.
- **Test Steps**:
  1. Open the sheet from a Pending or Paid invoice's `⋮` menu.
  2. Confirm "Total: <currency amount>" displays the invoice's total.
  3. Enter an amount less than the total in "Amount Paid" — confirm "Remaining" updates live to `total - entered`.
  4. Enter an amount equal to or greater than the total — confirm "Remaining" shows `0.00` (clamped, not negative).
  5. Tap "Save" — confirm the sheet closes and the invoice row now shows the "Partially\nPaid" badge.
- **Edge Cases / Notes**: Tapping "Save" with an empty/zero/invalid "Amount Paid" does nothing (silently — `if (paidAmt == null || paidAmt <= 0) return;`), sheet stays open. No validation error message is shown.

### + Add Income Button
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > bottom action bar, full-width navy button "+ Add Income" (with `add_circle_rounded` icon)
- **Expected Behavior**: Opens the "Add Income" / "New Invoice" bottom sheet (form described below).
- **Test Steps**:
  1. Tap "+ Add Income".
  2. Confirm the bottom sheet opens with title from `AppStrings.newInvoice` ("New Invoice" / Arabic equivalent).
- **Edge Cases / Notes**: None.

### Add Income Sheet — Form Fields
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > "+ Add Income" sheet
- **Expected Behavior / Fields**:
  - **Select Patient** (`PatientSearchField`, label from `AppStrings.selectPatient`): A searchable dropdown (`DropdownMenu` with `enableFilter: true`) listing all patients linked to this doctor (`doctor_ids` contains the doctor's UID, role = "patient"). Typing filters the list by name/email as you type; selecting a patient sets the internal `patId`/`patName`.
  - **Service** (text field, placeholder "Service (e.g. Physical Therapy)"): free text; defaults to "Physical Therapy" if left blank on submit.
  - **Invoice Date** (tappable field with calendar icon, shows date as "MMM d, yyyy"): tapping opens a date picker (bounds: 2020 to today+365 days); selected date updates the displayed field.
  - **Amount + Currency** (row): "Amount" numeric/decimal text field (flex 3) + "Currency" dropdown (flex 2) with options USD, EUR, SAR, AED, JOD (defaults to USD).
  - **Status** dropdown: options "Pending", "Paid", "Partially Paid", "Insurance Claim" (labels via `_InvStatus.label`, newline replaced with space). Defaults to "Pending".
  - **Partially Paid sub-fields** (only shown when Status = "Partially Paid"):
    - "Amount Paid" text field (numeric/decimal, orange payments icon).
    - Live "Remaining: `<currency> <remaining>`" chip (orange) recalculating as Amount/Amount Paid change.
  - **Note** (free text field).
  - **"Create Invoice" button** (navy, full width, receipt icon, label from `AppStrings.createInvoice`).
- **Test Steps**:
  1. Open "+ Add Income".
  2. Tap "Select Patient" and type a few letters of a known patient's name — confirm the list filters to matching patients; select one.
  3. Enter a Service description (or leave blank).
  4. Tap the Invoice Date field, pick a date via the date picker, confirm it displays correctly.
  5. Enter an Amount (e.g. "150") and pick a Currency (e.g. "EUR").
  6. Leave Status as "Pending" and tap "Create Invoice" — confirm the sheet closes, a green snackbar shows the localized "invoiceCreated" message, and the new invoice appears in the table with status "Pending".
  7. Repeat, this time selecting Status = "Partially Paid" — confirm the "Amount Paid" field and "Remaining" chip appear; enter a paid amount less than the total; submit and confirm the new row shows "Partially\nPaid" badge.
- **Edge Cases / Notes**:
  - Submitting with no patient selected (`patId == null`) or an invalid/zero/negative Amount silently does nothing (`return;` — no error message shown).
  - If Service is left blank, it defaults to "Physical Therapy" on save.
  - For "Partially Paid" status, `paid_amount` is only saved if the Amount Paid field parses to a number; otherwise the invoice is saved without `paid_amount`.

### Export Report (Income tab) — Desktop Only
- **Platform**: Desktop only (`FormFactorFeatures.showBillingImportExport`)
- **Location**: Doctor > Income/Billing tab > bottom action bar > "Export Report" outlined button (download icon)
- **Expected Behavior**: Exports the currently filtered invoice list to an `.xlsx` file named `billing_<period>_export.xlsx` (e.g. `billing_monthly_export.xlsx`), with columns: Patient Name, Service, Date (dd/MM/yyyy), Amount, Currency, Status (shows `partially_paid (paid: X.XX)` for partial payments), Note. Triggers a browser/file download via `downloadExcel`.
- **Test Steps**:
  1. On desktop (window ≥ 600px width), with at least one invoice visible for the current filters, tap "Export Report".
  2. Confirm a file download starts/completes named `billing_<period>_export.xlsx`.
  3. Open the file and confirm the header row and data rows match the visible invoice table (respecting current period/search/status filters).
  4. Change filters so the table is empty, then tap "Export Report" again.
- **Edge Cases / Notes**: If `docs` (the filtered list) is empty, shows a snackbar "No records to export." and does not produce a file. Not present at all on mobile widths — confirm the button does not render below 600px width.

### Insurance Button (Submit Insurance Claim)
- **Platform**: Both
- **Location**: Doctor > Income/Billing tab > bottom action bar > "Insurance" outlined button (shield icon)
- **Expected Behavior**: Opens a bottom sheet titled "Submit Insurance Claim" listing all currently-"Pending" invoices (within the active period/filters) as `ListTile`s — each showing patient name, `<currency> <amount> • <service>`, and a "Submit" button (grey-blue `#546E7A`). Tapping "Submit" on a row sets that invoice's status to `insurance_claim`, closes the sheet, and shows a green snackbar "Insurance claim submitted!".
- **Test Steps**:
  1. Ensure at least one "Pending" invoice exists in the current period.
  2. Tap "Insurance" — confirm the sheet opens listing the pending invoice(s) with correct patient/amount/service text.
  3. Tap "Submit" on one row — confirm the sheet closes, a green "Insurance claim submitted!" snackbar appears, and that invoice's badge changes to "Insurance\nClaim" in the table.
  4. With zero pending invoices (e.g. filter to "paid" status only, or empty period), tap "Insurance" again.
- **Edge Cases / Notes**: If there are no pending invoices, tapping "Insurance" shows a snackbar "No pending invoices to submit." and does NOT open the sheet.

### Import Excel (Income tab) — Desktop Only
- **Platform**: Desktop only (`FormFactorFeatures.showBillingImportExport`)
- **Location**: Doctor > Income/Billing tab > bottom action bar > "Import Excel" outlined button (upload icon)
- **Expected Behavior**: Opens a native file picker restricted to `.xlsx`/`.xls`. After selecting a file, shows a non-dismissible loading dialog ("Importing income records…" with spinner). Parses rows (skipping the header row), and for each valid row inserts a new invoice with: patient name matched against existing patients (substring, case-insensitive; `patient_id` left empty if no match), service (defaults "Physical Therapy" if blank), date (parsed as dd/MM/yyyy or yyyy-MM-dd, else "now"), amount, currency "USD", status (pending/paid/partially_paid/cancelled based on column), and note. After import, closes the loading dialog and shows a green snackbar "Imported `<N>` invoice(s) successfully."
- **Test Steps**:
  1. On desktop, tap "Import Excel".
  2. Select a valid `.xlsx` file matching the expected column layout (see Format help item below).
  3. Confirm the "Importing income records…" loading dialog appears, then disappears.
  4. Confirm a green snackbar reads "Imported N invoice(s) successfully." with the correct count.
  5. Confirm the new invoices appear in the table (after possibly adjusting period/filters to include them).
  6. Cancel the file picker without selecting a file — confirm nothing happens (no dialog, no error).
- **Edge Cases / Notes**:
  - Rows with fewer than 5 columns, empty name, empty amount, or non-numeric amount are skipped silently.
  - Date parsing falls back to "now" if neither dd/MM/yyyy nor yyyy-MM-dd format matches.
  - Status values: `paid`, `partially_paid`/`partially paid`, `cancelled*` (prefix match), else `pending`.
  - Currency detection: if a 6th+ column with a recognized currency code (usd/eur/gbp/jod/ils/sar/aed) is present at index 4, it's treated as the exported format (status at index 5, note at index 6); otherwise index 4 is treated as status and index 5 as note. All imported invoices are hard-coded to `currency: 'USD'` regardless.
  - Not present at all on mobile widths.

### Format Help Button (Import Bills) — Desktop Only
- **Platform**: Desktop only (gated alongside Import Excel via `showBillingImportExport`)
- **Location**: Doctor > Income/Billing tab > bottom action bar > small grey square button with `help_outline_rounded` icon, immediately right of "Import Excel"
- **Expected Behavior**: Opens the "Import Bills" help bottom sheet showing: "Expected Excel column order" subtitle, lettered column pills (A: Name, B: Service, C: Date, D: Amount, E: Status, F: Note), an example table with two sample rows (John Smith/Physical Therapy/01/15/2024/150/paid/Insurance and Sara Lee/Follow-up Session/02/10/2024/80/pending/""), and a Notes section listing field requirements (name matching, service description, date formats dd/MM/yyyy or yyyy-MM-dd, amount as plain number, status values pending/paid/partially paid/cancelled, optional note).
- **Test Steps**:
  1. On desktop, tap the help (`?`) icon next to "Import Excel".
  2. Confirm the "Import Bills" sheet opens with the title, column pills A–F, example rows, and notes as described.
  3. Dismiss the sheet (swipe down or tap outside) and confirm it closes cleanly.
- **Edge Cases / Notes**: Purely informational, no interactive form fields beyond dismiss. Not present on mobile.

---

## Expenses Tab

### Period Selector Pills (Expenses tab)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > filter row below header ("Daily" / "Weekly" / "Monthly" / "Yearly" pill buttons)
- **Expected Behavior**: Tapping a pill selects that period (highlighted navy with white text when selected, light grey otherwise). The header total, KPI chips, category breakdown, chart, and expense list all recompute for the new period.
- **Test Steps**:
  1. Open Expenses tab (defaults to "Monthly", highlighted navy).
  2. Tap "Daily" — confirm it becomes highlighted and the header total/expense list update to show only today's expenses.
  3. Tap "Weekly" and "Yearly" in turn, confirming the same.
- **Edge Cases / Notes**: Unlike the Income tab, switching periods here does NOT reset `_refDate` to "now" (it stays on whatever date was last navigated to).

### Date Range Navigation (Expenses tab header)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > header (teal/navy gradient) > top-right: calendar icon button + pill with `<` range-label `>`
- **Expected Behavior**:
  - Calendar icon (`calendar_month_rounded` in a translucent circle): opens a date picker (2020 to today+365 days); selecting a date sets `_refDate` and recomputes the period range containing it.
  - `<` / `>` chevrons in the pill: step the reference date back/forward by one period (day/week/month/year per `_period`), updating the range label (e.g. "Jun 1 – Jun 30, 2026" or "2026" for yearly or "June 14, 2026" for daily) and all data.
- **Test Steps**:
  1. Tap the calendar icon, pick a date in a prior month, confirm the range label and totals update to that month.
  2. Tap the left chevron `<` — confirm range moves back one more period.
  3. Tap the right chevron `>` twice — confirm range advances forward two periods.
- **Edge Cases / Notes**: Range label format differs by period: "MMMM d, yyyy" for daily, "yyyy" for yearly, and "MMM d – MMM d, yyyy" for weekly/monthly.

### Header Total & KPI Chips (Expenses tab)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > header (gradient navy-to-teal background)
- **Expected Behavior**: Large `$<total>` figure with "Total Expenses" caption below, then three chips: "Paid" (green text, sum of expenses with status `paid`), "Pending" (orange text, `total - paid`, includes pending + partially-paid remainder conceptually as `total-paid`), "Entries" (white text, count of expenses in period).
- **Test Steps**:
  1. Note the total, "Paid", "Pending", and "Entries" values for the current period.
  2. Add a new expense with status "Paid" (see Add Expense sheet) and confirm "Total Expenses", "Paid", and "Entries" all update accordingly.
  3. Add a "Pending" expense and confirm "Pending" and "Entries" update, while "Paid" stays the same.
- **Edge Cases / Notes**: "Entries" displays as a plain integer (not currency-formatted) via the `isCount: true` flag.

### Status Filter Cycle Button (Expenses tab)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > filter row, right side — pill with `filter_list_rounded` icon and text ("All" / "Pending" / "Paid" / "Partial")
- **Expected Behavior**: Tapping cycles through filter states in order: All → Pending → Paid → Partial → All (loop). Each state has a distinct color scheme (All = grey, Pending = amber/`#FF8F00`, Paid = green/`#2E7D32`, Partial = orange/`#E65100`) shown as background tint, border, icon color, and text color. The expense list (and category/chart sections) filter to only expenses matching the selected status (no filter when "All").
- **Test Steps**:
  1. Note the button shows "All" with grey styling by default.
  2. Tap once — confirm it shows "Pending" with amber styling and the expense list filters to pending-status expenses only.
  3. Tap again — confirm "Paid" (green styling), list filters to paid expenses.
  4. Tap again — confirm "Partial" (orange styling), list filters to partially-paid expenses.
  5. Tap a fourth time — confirm it returns to "All" and the full list returns.
- **Edge Cases / Notes**: If a status filter yields zero category totals, the "By Category" and "Expenses by Category" chart sections are hidden entirely (`if (categoryTotals.isNotEmpty)`).

### By Category Section (Expenses tab)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > scroll content, first card ("By Category" with pie-chart icon)
- **Expected Behavior**: Lists up to 6 categories sorted by total amount descending, each showing a colored dot, category name, `$<amount> <pct>%` of grand total, and a horizontal progress bar (colored per category, using a 6-color rotating palette).
- **Test Steps**:
  1. Ensure expenses exist across 2+ categories in the current period.
  2. Confirm the "By Category" card lists each category with correct dollar amount and percentage (percentages should be relative to the filtered total, summing to ~100% across all categories if ≤6 exist).
  3. Confirm progress bar lengths visually correspond to the percentages.
  4. If there are more than 6 distinct categories, confirm only the top 6 (by amount) are shown.
- **Edge Cases / Notes**: Entire section (and the chart section below it) is hidden if `categoryTotals` is empty (i.e., no expenses match the current period/status filter).

### Expenses by Category Pie Chart (Expenses tab)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > scroll content, second card ("Expenses by Category" with pie-chart icon), below "By Category"
- **Expected Behavior**: A `PieChart` (fl_chart) on the left showing one slice per category (colored using the same 6-color palette, each slice labeled with its percentage), and a legend on the right listing each category name with a colored dot and percentage.
- **Test Steps**:
  1. With multiple categories of expenses present, confirm the pie chart renders a slice per category, each labeled with a percentage matching the legend.
  2. Confirm slice colors match the corresponding legend dot colors and the "By Category" list colors above (same palette/order).
  3. Resize the window (desktop ↔ mobile width) and confirm the chart + legend remain laid out side-by-side without overflow (legend text truncates with ellipsis if needed).
- **Edge Cases / Notes**: This section returns `SizedBox.shrink()` (renders nothing) if `categoryTotals` is empty — same condition as the "By Category" section above.

### Expense Records — Search Field
- **Platform**: Both
- **Location**: Doctor > Expenses tab > "Expense Records" card header, right side ("Search…" text field with search icon)
- **Expected Behavior**: Typing filters the expense list in real time to expenses whose `category` contains the typed text (case-insensitive substring).
- **Test Steps**:
  1. Type part of a category name (e.g. "Equip" for "Equipment") into the "Search…" field.
  2. Confirm the expense list filters to only matching-category rows.
  3. Clear the field — confirm the full list returns.
- **Edge Cases / Notes**: Combined (AND) with the period and status filters. If nothing matches, the list shows the "No expenses for this period" empty state (the text doesn't change to reflect the search specifically).

### Export Report Button (Expenses tab)
- **Platform**: Both (NOT gated by `FormFactorFeatures` — visible on mobile and desktop)
- **Location**: Doctor > Expenses tab > "Expense Records" card header, full-width outlined button below the search field ("Export Report" with download icon)
- **Expected Behavior**: Exports the currently filtered expense list to an `.xlsx` file named `expenses_<period>_export.xlsx`, with columns: Category, Description, Date (dd/MM/yyyy), Amount, Notes, Status (shows `partially_paid (paid: X.XX)` for partial payments). Triggers a file download via `downloadExcel`.
- **Test Steps**:
  1. With at least one expense visible for the current filters, tap "Export Report".
  2. Confirm a file downloads named `expenses_<period>_export.xlsx`.
  3. Open the file and confirm header + data rows match the visible expense list (respecting period/search/status filters).
  4. Filter to a combination with zero expenses, then tap "Export Report" again.
- **Edge Cases / Notes**: If `docs` is empty, shows a snackbar "No records to export." and produces no file. Unlike the Income tab's export, this one is available on mobile too.

### Expense Records List — Empty State
- **Platform**: Both
- **Location**: Doctor > Expenses tab > "Expense Records" card, body
- **Expected Behavior**: When no expenses match the current period/category/status filters, shows a centered receipt icon (`receipt_long_outlined`, 48px, light grey) and text "No expenses for this period".
- **Test Steps**:
  1. Apply filters (period/status/search) that yield zero expenses.
  2. Confirm the empty state icon + "No expenses for this period" text display within the card, below the header/search row and divider.
- **Edge Cases / Notes**: None.

### Expense Row — Status Badge
- **Platform**: Both
- **Location**: Doctor > Expenses tab > each expense row, right side below the amount
- **Expected Behavior**: A pill-shaped badge with an icon + label: "Pending" (`schedule_rounded`, amber `#FF8F00`, bg `#FFF3E0`), "Paid" (`check_circle_rounded`, green `#2E7D32`, bg `#E8F5E9`), or "Partial" (`hourglass_top_rounded`, orange `#E65100`, bg `#FBE9E7`).
- **Test Steps**:
  1. Create or locate expenses in each of the 3 statuses.
  2. Confirm each row's badge shows the correct icon, label, and color combination as above.
- **Edge Cases / Notes**: For "Partial" status with a `paid_amount` present, an additional line "Paid: $X.XX" (orange `#E65100`) shows above the badge.

### Expense Row — More Actions Menu (⋮ / `more_vert`)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > each expense row, far-right icon button (`more_vert_rounded`, grey)
- **Expected Behavior**: Opens a popup menu with:
  - "Mark as Paid" (green check icon, label from `AppStrings.markAsPaid`) — shown only if current status ≠ paid; sets status to `paid` immediately.
  - "Mark Partially Paid" (orange payments icon) — shown only if current status ≠ partially_paid; opens the "Mark as Partially Paid" sheet.
- **Test Steps**:
  1. On a "Pending" expense, tap `⋮` — confirm both "Mark as Paid" and "Mark Partially Paid" options appear.
  2. Tap "Mark as Paid" — confirm the badge immediately updates to "Paid" and the header KPI chips ("Paid"/"Pending") recompute.
  3. On another expense, tap `⋮` > "Mark Partially Paid" — confirm the partial-payment sheet opens (see next item).
- **Edge Cases / Notes**: No confirmation dialog; status changes write immediately to Supabase. On a "Paid" expense, only "Mark Partially Paid" shows; on a "Partial" expense, only "Mark as Paid" shows.

### Mark as Partially Paid Sheet (Expenses tab)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > expense row > `⋮` menu > "Mark Partially Paid"
- **Expected Behavior**: Bottom sheet titled "Mark as Partially Paid" showing "Total: $<totalAmt>", an "Amount Paid" numeric field (orange payments icon, autofocus), a live "Remaining: $<remaining>" chip (orange, clamped ≥ 0), and a "Save" button (orange `#E65100`). On Save with valid `paidAmt > 0`, updates the expense's `status` to `partially_paid` and `paid_amount`, then closes the sheet.
- **Test Steps**:
  1. Open from an expense's `⋮` menu.
  2. Confirm "Total: $<amount>" matches the expense's amount and the field is autofocused.
  3. Enter an amount less than the total — confirm "Remaining" updates live.
  4. Enter an amount ≥ total — confirm "Remaining" clamps to $0.00.
  5. Tap "Save" — confirm the sheet closes and the row now shows the "Partial" badge with "Paid: $X.XX" line.
- **Edge Cases / Notes**: Saving with empty/zero/invalid amount does nothing silently (sheet stays open, no error shown).

### Format Help FAB (Import Expenses)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > floating action buttons, top-left small circular button (white background, `help_outline_rounded` icon, grey)
- **Expected Behavior**: Opens the "Import Expenses" help bottom sheet: "Expected Excel column order" subtitle, lettered column pills (A: Category, B: Description, C: Date, D: Amount, E: Notes, F: Status), two example rows (Equipment/Therapy bands/01/15/2024/45/office supplies/paid and Rent/Monthly clinic rent/02/01/2024/1200/""/pending), and notes describing each field (category types, description, date formats, amount format, optional notes, status values pending/paid/partially paid).
- **Test Steps**:
  1. Tap the small white `?` FAB (top-left of the floating button cluster).
  2. Confirm the "Import Expenses" sheet opens with the described content.
  3. Dismiss the sheet (swipe down / tap outside).
- **Edge Cases / Notes**: Purely informational; no `FormFactorFeatures` gating — visible on both mobile and desktop (unlike the Income tab's equivalent, which is desktop-only).

### Import from Excel FAB (Expenses tab)
- **Platform**: Both
- **Location**: Doctor > Expenses tab > floating action buttons, top-right small circular navy button (`upload_file_rounded` icon, tooltip "Import from Excel")
- **Expected Behavior**: Opens a native file picker restricted to `.xlsx`/`.xls`. After selection, shows a non-dismissible loading dialog ("Importing expense records…"). Parses rows (skipping header), inserting an expense per valid row with: category, description, amount, status (paid/partially_paid/pending based on column 6 text), note (column 5), expense date (parsed dd/MM/yyyy or yyyy-MM-dd, else "now"). After import, closes the loading dialog and shows a green snackbar "Imported `<N>` expense(s) successfully."
- **Test Steps**:
  1. Tap the navy upload FAB (top-right of the floating button cluster).
  2. Select a valid `.xlsx` file matching the expected column layout.
  3. Confirm the "Importing expense records…" loading dialog appears then disappears.
  4. Confirm a green snackbar "Imported N expense(s) successfully." with correct count.
  5. Confirm new expenses appear in the list (adjust period/filters if needed).
  6. Cancel the file picker without choosing a file — confirm nothing happens.
- **Edge Cases / Notes**: Rows with fewer than 4 columns, empty category, or non-numeric amount are skipped. Status text "paid" → paid, "partially paid" → partially_paid, anything else → pending. Available on both mobile and desktop (no `FormFactorFeatures` gate, unlike Income's Import Excel).

### Add Expense FAB & Sheet
- **Platform**: Both
- **Location**: Doctor > Expenses tab > floating action button, bottom — extended teal FAB "Add Expense" (`add_rounded` icon)
- **Expected Behavior**: Opens a bottom sheet titled "Add Expense" (with a receipt-long teal icon) containing:
  - **Category** (text field, label icon).
  - **Description** (text field, notes icon).
  - **Expense Date** (tappable field, calendar icon, shows "MMM d, yyyy"; tapping opens date picker bounded 2020–today+365 days).
  - **Amount** (numeric/decimal field, dollar icon).
  - **Status** dropdown: "Pending" (default) / "Paid" / "Partial" (labels via `_ExpStatus.label`).
  - **Partially Paid sub-fields** (shown only when Status = Partial): "Amount Paid" field + live "Remaining: $X.XX" chip.
  - **Note** (text field, notes icon).
  - **"Add Expense" button** (teal `#00897B`, full width, `add_rounded` icon).
  On submit with valid Category and Amount, inserts the expense, closes the sheet, and shows a green snackbar "Expense added successfully!".
- **Test Steps**:
  1. Tap the "Add Expense" FAB.
  2. Leave Category empty and/or Amount empty/zero, tap "Add Expense" — confirm an orange snackbar "Please fill in category and amount." appears and the sheet stays open.
  3. Fill in Category (e.g. "Equipment") and Amount (e.g. "45").
  4. Tap the Expense Date field, pick a date via the picker, confirm it updates the display.
  5. Leave Status as "Pending", optionally fill Description/Note, tap "Add Expense" — confirm the sheet closes, a green "Expense added successfully!" snackbar appears, and the new expense shows in the list with "Pending" badge.
  6. Repeat with Status = "Partial" — confirm "Amount Paid" field + "Remaining" chip appear, fill them in, submit, and confirm the new row shows "Partial" badge with "Paid: $X.XX".
- **Edge Cases / Notes**: On a Supabase insert error, shows a red snackbar "Failed to add expense: `<error>`" and keeps the sheet open. For "Partial" status, `paid_amount` is only saved if "Amount Paid" parses to a valid number.

---

## Statistics Tab (Desktop Only)

> **Note**: The entire Statistics tab (nav entry, home tile, and content) is hidden on mobile via `FormFactorFeatures.showStatistics`. On mobile, selecting/viewing this section shows an "Available on Desktop" placeholder instead. All items below apply to Desktop only. The tab is also gated behind the Premium subscription tier (`SubTier.premium`) — if locked, a separate "locked" upsell screen shows instead of the content below (subscription gating is out of scope for this checklist).

### Period Selector Pills (Statistics tab)
- **Platform**: Desktop only
- **Location**: Doctor > Statistics tab > header (navy-to-blue gradient), bottom row — "Daily" / "Weekly" / "Monthly" / "Yearly" pills
- **Expected Behavior**: Tapping a pill selects it (white background + navy text when selected; translucent white when not) AND resets `_refDate` to "now" (unlike the Expenses tab, which does not reset the date on period change). All KPIs, charts, and breakdowns recompute for the new period starting from "now".
- **Test Steps**:
  1. Open Statistics tab (defaults to "Monthly").
  2. Tap "Daily" — confirm it highlights, the range label shows today's date, and all KPIs/charts update for today only.
  3. Tap "Weekly" — confirm range label shows the current week's range (e.g. "Jun 8 – Jun 14") and data updates.
  4. Tap "Yearly" — confirm range label shows the current year (e.g. "2026") and data updates.
- **Edge Cases / Notes**: Switching periods always snaps back to "today's" period (not wherever you'd navigated to previously) — verify this differs from the Expenses tab behavior.

### Date Range Navigation (Statistics tab header)
- **Platform**: Desktop only
- **Location**: Doctor > Statistics tab > header, top-right: calendar icon button + `<` range-label `>` pill
- **Expected Behavior**: Calendar icon opens a date picker (2020 to today+365 days); selecting a date sets `_refDate` and recomputes the period range. `<`/`>` chevrons step the reference date back/forward by one period unit, updating the range label ("MMM d, yyyy" daily / "MMM d – MMM d" weekly / "yyyy" yearly / "MMMM yyyy" monthly) and all KPIs/charts.
- **Test Steps**:
  1. Tap the calendar icon, select a date in a previous month, confirm range label and KPI values update to that month.
  2. Tap `<` — confirm range moves back one more period (e.g. to the prior month).
  3. Tap `>` twice — confirm range advances forward two periods.
- **Edge Cases / Notes**: None beyond standard date-picker bounds (2020–now+365 days).

### KPI Cards Row (Sessions / Income / Expenses / Net Profit)
- **Platform**: Desktop only
- **Location**: Doctor > Statistics tab > below header, 4-card row
- **Expected Behavior**: Four cards:
  - "Sessions" — count of appointments (`appointments` table, `appointment_time` in range) for this doctor, blue icon (`event_note_rounded`).
  - "Income" — `$<totalIncome>` (paid + pending invoice amounts), green icon (`trending_up_rounded`), subtitle "$`<paidIncome>` paid".
  - "Expenses" — `$<totalExpenses>` (paid + pending expense amounts), red icon (`trending_down_rounded`), subtitle "$`<paidExpenses>` paid".
  - "Net Profit" — `$<paidIncome - paidExpenses>`, icon/color switches based on sign: green wallet icon if ≥ 0, amber warning icon if negative; value text green if ≥0, red if negative.
- **Test Steps**:
  1. Note current values for all 4 KPI cards for the "Monthly" (default) period.
  2. Cross-check "Sessions" count against the number of appointments scheduled in the current month (Schedule tab, out of scope for detailed checks but useful for sanity check).
  3. Cross-check "Income" total against the sum of invoice amounts for the period (Income tab).
  4. Cross-check "Expenses" total against the sum of expense amounts for the period (Expenses tab).
  5. Confirm "Net Profit" = paid income − paid expenses, and that its icon/color reflect the sign correctly (test both a profitable and a loss scenario if data allows).
- **Edge Cases / Notes**: All values are `0`/`$0` when no data exists for the period — confirm cards render gracefully (no crash, shows "$0" / "0").

### Sessions per Day Chart
- **Platform**: Desktop only
- **Location**: Doctor > Statistics tab > "Sessions per Day" card (calendar icon)
- **Expected Behavior**: Shows a `Wrap` of chips, one per day in the period that has ≥1 appointment, each displaying the session count (large blue number) and the date ("d MMM" format). If no sessions exist in the period, shows centered grey text "No sessions in this period".
- **Test Steps**:
  1. With appointments scheduled on specific days within the current period, confirm a chip appears for each such day, showing the correct count and date.
  2. Switch to a period/date range with zero appointments and confirm the "No sessions in this period" empty-state message appears instead of any chips.
- **Edge Cases / Notes**: Days with 0 sessions are NOT shown as chips (only `> 0` days are included) — this is a count-by-active-day view, not a full calendar grid.

### Financial Breakdown Card
- **Platform**: Desktop only
- **Location**: Doctor > Statistics tab > "Financial Breakdown" card (account-balance icon), below the Sessions chart
- **Expected Behavior**: Shows two rows:
  - "Income" — green icon, total income value on the right, with sub-text "$`<paid>` paid" (green dot) and "$`<pending>` pending" (amber dot).
  - "Expenses" — red icon, total expenses value, with the same paid/pending sub-breakdown.
  Below a divider, a "Net Profit" row shows `$<netProfit>` in green (if ≥0) or red (if <0), with a wallet icon (teal bg if ≥0) or warning icon (amber bg if <0).
- **Test Steps**:
  1. Confirm "Income" row total matches the KPI card's "Income" value, and its paid/pending sub-amounts sum to that total.
  2. Confirm "Expenses" row total matches the KPI card's "Expenses" value similarly.
  3. Confirm "Net Profit" matches `paidIncome - paidExpenses` and the icon/color match the sign (green/teal for ≥0, red/amber for <0).
- **Edge Cases / Notes**: All-zero data should render `$0.00` rows without errors.

### Payment Methods Card
- **Platform**: Desktop only
- **Location**: Doctor > Statistics tab > "Payment Methods" card (credit-card icon), shown only if any invoices exist in the period
- **Expected Behavior**: Lists each distinct `payment_method` value found on invoices in the period (title-cased, underscores replaced with spaces, defaulting to "Cash" if unset), sorted by count descending, each with a colored dot, name, "`<count>` `<pct>`%" text, and a horizontal progress bar. Uses a 5-color rotating palette.
- **Test Steps**:
  1. Ensure invoices in the period have a mix of `payment_method` values (e.g. "cash", "credit_card", or none → defaults to "Cash").
  2. Confirm the card lists each method with correct count and percentage (percentages relative to total invoice count in the period).
  3. Confirm progress bar lengths correspond to percentages.
- **Edge Cases / Notes**: The entire card is hidden (`if (methods.isNotEmpty)`) if there are zero invoices in the period — confirm it does not render (not even an empty card) when the period has no invoices.

---

## Inventory Screen (Not Reachable — Informational Only)

`lib/features/doctor/inventory_screen.dart` implements a full clinic-inventory CRUD screen (add/edit/delete items with category, unit, quantity, min-quantity threshold, notes; low-stock warning banner; quantity +/- steppers) backed by the Supabase `inventory` table, but it has **no navigation entry anywhere in the app** (no tab, no drawer item, no button) on either desktop or mobile, so it cannot be reached or tested by any user. No checklist items are provided for it.

---

## Patient Dashboard

> Entry point: `lib/main.dart` routes `role == 'patient'` to `PatientDashboardScreen` (wrapped in `_WithNotificationPrompt`). This is the only patient-facing dashboard reachable in the app — `lib/features/patient/patient_home_screen.dart` (`PatientHomeScreen`, "My Patient Portal" with "My Care Plan"/"Browse Doctors" tabs) is NOT referenced from `main.dart` or any navigation and is unreachable dead code; it is excluded from this checklist.
>
> **Platform note**: `PatientDashboardScreen` and all its sub-screens use a single fixed mobile-style layout (no `FormFactorFeatures`/breakpoint branching). Test on **Both** desktop and mobile widths — the layout does not change, but verify it remains usable (no overflow/clipping) at desktop widths (~1400px) as well as mobile (~390px).

---

### Home — Language Toggle
- **Platform**: Both (same layout at all widths)
- **Location**: Patient > Home (top header, below the greeting text)
- **Expected Behavior**: Tapping the pill-shaped chip (globe icon + language label, e.g. "العربية"/"English") toggles the app language between English and Arabic. The whole dashboard (and app) re-renders with translated strings; when Arabic is active, layout direction switches to RTL (`Directionality` wraps the whole screen).
- **Test Steps**:
  1. Open Patient dashboard Home tab.
  2. Note current language label in the pill chip under the greeting.
  3. Tap the chip.
  4. Confirm UI text switches language and (if switching to Arabic) the layout mirrors to RTL.
  5. Tap again to toggle back.
- **Edge Cases / Notes**: This toggle is global (affects all screens via `LanguageProvider`), not just Home.

---

### Home — Upcoming Appointment Card / No-Appointment Banner
- **Platform**: Both
- **Location**: Patient > Home (main scroll area, first card below header)
- **Expected Behavior**:
  - If the patient has an upcoming (non-cancelled, future) appointment, shows a white card titled "Upcoming Appointment" with: doctor avatar (photo or person icon placeholder), doctor name (prefixed "Dr." if `show_dr_prefix` is true on that doctor, else raw name, else "Your Doctor" if name empty), specialization (or "Doctor" if empty), a divider, date/time row (`MMM d, yyyy` at `h:mm a`), and (if clinic name present) a location row with the clinic name.
  - Below that, a full-width blue "View Details" button.
  - If no upcoming appointment exists, instead shows a "No Upcoming Appointments" banner with a calendar icon, bold title, and subtitle "Book a session today" (or localized equivalent).
- **Test Steps**:
  1. As a patient with no future appointments, open Home — verify the no-appointment banner appears with calendar icon and message.
  2. Book/accept an appointment so a future appointment exists; return to Home — verify the Upcoming Appointment card renders with correct doctor name/specialization/date/time/clinic.
  3. Tap "View Details" — verify navigation to Patient > My Appointments (Schedule) screen.
- **Edge Cases / Notes**: Doctor info is loaded via `FutureBuilder` (`getDoctorById`); while loading, fields show as empty/defaults. If `doctorId` is empty, the FutureBuilder resolves to `null` and shows "Your Doctor" with empty specialization labeled "Doctor".

---

### Home — Grid Tile: My Appointments
- **Platform**: Both
- **Location**: Patient > Home (2x2 grid, top-left tile, calendar icon, blue)
- **Expected Behavior**: Tapping navigates to the "My Appointments" schedule screen (4 tabs: Upcoming, Requested, Previous, Summary).
- **Test Steps**:
  1. From Home, tap the "My Appointments" tile.
  2. Verify the Schedule screen opens with the 4-tab layout described in the "My Appointments (Schedule)" section below.
- **Edge Cases / Notes**: None.

---

### Home — Grid Tile: My Doctors/Therapists
- **Platform**: Both
- **Location**: Patient > Home (2x2 grid, top-right tile, people icon, teal)
- **Expected Behavior**: Tapping navigates to "My Doctors" screen, listing doctors the patient has linked.
- **Test Steps**:
  1. From Home, tap the "My Doctors/Therapists" tile.
  2. Verify navigation to the My Doctors screen.
- **Edge Cases / Notes**: None.

---

### Home — Grid Tile: Find a Doctor or Therapist
- **Platform**: Both
- **Location**: Patient > Home (2x2 grid, bottom-left tile, person-search icon, purple)
- **Expected Behavior**: Tapping navigates to `FindDoctorsScreen` (Find a Therapist search/browse screen).
- **Test Steps**:
  1. From Home, tap the "Find a Doctor or Therapist" tile.
  2. Verify navigation to the Find a Therapist screen (see dedicated section below).
- **Edge Cases / Notes**: None.

---

### Home — Grid Tile: Notifications (with unread badge)
- **Platform**: Both
- **Location**: Patient > Home (2x2 grid, bottom-right tile, bell icon, orange)
- **Expected Behavior**: Tapping navigates to the Notifications screen. If there are unread notifications, a red circular badge with the unread count appears in the top-right corner of the tile (shows "99+" if count > 99).
- **Test Steps**:
  1. Ensure at least one unread notification exists for the patient (e.g., trigger one from doctor side, or via a "patient_added_you" or appointment status-change action).
  2. On Home, verify the badge appears on the Notifications tile with the correct count.
  3. Tap the tile, open Notifications, mark items read.
  4. Return to Home and verify the badge disappears or count decreases accordingly (live via stream).
- **Edge Cases / Notes**: Badge count is computed live via a Supabase realtime stream on the `notifications` table filtered by `patient_id` and `read == false`.

---

### Home — My Profile Tile (tap + long-press)
- **Platform**: Both
- **Location**: Patient > Home (bottom of scroll area, white rounded card with avatar, "My Profile" label, chevron)
- **Expected Behavior**:
  - **Tap**: navigates to the My Profile screen.
  - **Long-press**: opens a "Logout" confirmation `AlertDialog` (title "Logout", message "Are you sure?" / localized `s.areYouSure`) with "Cancel" and "Sign Out" (red text) actions. Confirming calls `Supabase.auth.signOut()` (note: this dialog does NOT call `popUntil` — see Edge Cases).
- **Test Steps**:
  1. From Home, tap the profile tile (avatar + "My Profile" row) — verify navigation to My Profile screen.
  2. Go back to Home. Long-press the same tile.
  3. Verify a "Logout"/"Are you sure?" dialog appears with "Cancel" and "Sign Out" buttons.
  4. Tap "Cancel" — dialog closes, no action taken.
  5. Long-press again, tap "Sign Out" — verify `signOut()` is called and the app responds (likely returns to login via the app's auth-state listener in `main.dart`, since this dialog itself does not call `popUntil`).
- **Edge Cases / Notes**: This is a SECOND, separate sign-out entry point distinct from the My Profile screen's "Sign Out" button (which explicitly calls `popUntil((route) => route.isFirst)`). This long-press dialog's `_showLogout` handler only calls `signOut()` without `popUntil` — verify the user still lands back at the Login screen correctly (likely via `main.dart`'s top-level auth state listener / `StreamBuilder` on `onAuthStateChange` rebuilding to the login route). If this dialog leaves a stale route stack, flag it.

---

## My Appointments (Schedule)

- **Platform**: Both. AppBar titled "My Appointments" with a calendar icon on the right, and a 4-tab `TabBar`: **Upcoming**, **Requested**, **Previous**, **Summary**.

### My Appointments — Upcoming Tab
- **Platform**: Both
- **Location**: Patient > My Appointments > Upcoming tab
- **Expected Behavior**: Lists all future, non-cancelled appointments sorted soonest-first as cards. Each card shows doctor avatar/name (with "Dr." prefix if applicable, else name, else "Doctor"), date (`EEEE, MMM d, yyyy | h:mm a`), notes (if any, single line ellipsis with notes icon), and two action buttons: **Reschedule** (teal outlined, calendar-edit icon) and **Cancel** (red outlined, cancel icon). If empty, shows an empty state with a calendar icon and "no upcoming appointments" message.
- **Test Steps**:
  1. Navigate to Patient > My Appointments, ensure "Upcoming" tab is selected (default).
  2. If no appointments: verify empty-state icon + message (`s.noUpcomingApptsMsg`).
  3. With at least one upcoming appointment: verify card details (doctor name/photo, date/time, notes if present).
  4. Tap **Reschedule** — verify a SnackBar appears with message "Contact your doctor to reschedule" (`s.contactYourDoctor`).
  5. Tap **Cancel** — see "Cancel Appointment confirmation" item below.
- **Edge Cases / Notes**: Reschedule does not open a rescheduling flow — it only shows a SnackBar instructing the patient to contact the doctor. Cancel/Reschedule buttons are hidden entirely if the appointment status is `cancelled` (shouldn't normally appear in Upcoming since cancelled appts are filtered out).

### My Appointments — Cancel Appointment confirmation dialog
- **Platform**: Both
- **Location**: Patient > My Appointments > Upcoming tab > tap "Cancel" on an appointment card
- **Expected Behavior**: Opens `AlertDialog` titled "Cancel Appointment" (`s.cancelAppointment`) with body text `s.cancelAppointmentConfirm`. Actions: "Keep it" (`s.keepIt`, dismiss) and "Cancel it" (`s.cancelIt`, red text). Confirming updates the appointment's `status` to `'cancelled'` in Supabase and shows a SnackBar with `s.appointmentCancelled`.
- **Test Steps**:
  1. On an upcoming appointment card, tap "Cancel".
  2. Verify the confirmation dialog appears with "Keep it" / "Cancel it".
  3. Tap "Keep it" — dialog closes, appointment remains unchanged.
  4. Tap "Cancel" again, then "Cancel it" — verify dialog closes, a SnackBar confirms cancellation, and the appointment card now shows a "Cancelled" badge (grey strikethrough name, red "Cancelled" chip) — it should move out of the Upcoming tab (filtered by status) and appear (struck-through) in the Previous tab depending on date.
- **Edge Cases / Notes**: The Cancel button is disabled (`onPressed: null`) if `appointmentId` is empty/missing.

### My Appointments — Requested Tab
- **Platform**: Both
- **Location**: Patient > My Appointments > Requested tab
- **Expected Behavior**: Lists appointment requests sent by the patient (via "Request" in My Doctors), newest first. Each card shows a pending-actions icon, "Dr. {doctorName}", requested date/time (`EEE, MMM d · h:mm a`), notes (if any), and a status chip: **Pending** (orange, hourglass icon), **Accepted** (green, check-circle icon), or **Declined** (red, cancel icon). Empty state shows a pending-actions icon and `s.noRequestsMsg`.
- **Test Steps**:
  1. Navigate to the "Requested" tab.
  2. If no requests exist, verify empty state with message.
  3. Send a request (via My Doctors > Request flow), return here, verify it appears with "Pending" status chip.
  4. (If testable) have a doctor accept/decline the request and verify the chip updates to "Accepted"/"Declined" live.
- **Edge Cases / Notes**: This tab is read-only — no actions on request cards besides viewing status/notes.

### My Appointments — Previous Tab
- **Platform**: Both
- **Location**: Patient > My Appointments > Previous tab
- **Expected Behavior**: Lists past appointments (appointment_time not after now), newest-first. Same card layout as Upcoming, but instead of Reschedule/Cancel buttons, shows a green "Completed" row with check-circle icon (unless cancelled, in which case no action row is shown at all and the name is struck through with a "Cancelled" badge). Empty state shows a history icon and `s.noPastApptsMsg`.
- **Test Steps**:
  1. Navigate to "Previous" tab.
  2. If empty, verify empty-state icon + message.
  3. With past appointments present, verify each card shows "Completed" (green) for non-cancelled past appointments, and "Cancelled" badge + struck-through name for cancelled ones (with no action row).
- **Edge Cases / Notes**: None additional.

### My Appointments — Summary Tab
- **Platform**: Both
- **Location**: Patient > My Appointments > Summary tab
- **Expected Behavior**: Shows a gradient "total sessions attended" chip (count of all past appointments + `s.totalSessionsAttended` label), then a "Sessions by Doctor" (`s.sessionsByDoctor`) heading, followed by one card per doctor the patient has had past sessions with — sorted by session count descending. Each doctor card shows avatar, name ("Dr. " prefix if applicable), "Last session: {date}" (`s.lastSessionDate`), and a pill showing "{N} session(s)". Empty state shows a bar-chart icon and `s.noSessionsMsg` if there are no past appointments.
- **Test Steps**:
  1. Navigate to "Summary" tab.
  2. With no past appointments, verify empty state.
  3. With past appointments across one or more doctors, verify the total count chip and per-doctor breakdown are correct (counts, last-session dates, sorting by session count descending).
- **Edge Cases / Notes**: Doctor names/photos for the summary are populated from a local cache (`_doctorNames`/`_doctorPhotos`/`_doctorShowDrPrefix`) pre-fetched while building the Upcoming/Previous lists — if a doctor's info hasn't loaded yet, name may briefly show as empty/"Doctor".

---

## My Doctors/Therapists

- **Platform**: Both. AppBar titled "My Doctors" with a "person add" icon button on the right.

### My Doctors — Add Doctor (person-add icon, AppBar)
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists > AppBar action (top-right, `Icons.person_add_rounded`)
- **Expected Behavior**: Navigates (push) to `FindDoctorsScreen` to search/add a new doctor.
- **Test Steps**:
  1. From My Doctors screen, tap the person-add icon in the AppBar.
  2. Verify navigation to the Find a Therapist screen.
- **Edge Cases / Notes**: None.

### My Doctors — Search field
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists (top of body, below AppBar)
- **Expected Behavior**: A text field with placeholder `s.searchDoctors` and a search icon. Typing filters the linked-doctors list (case-insensitive) by name or specialization, live as you type.
- **Test Steps**:
  1. With 2+ linked doctors of differing names/specializations, type a partial name into the search box.
  2. Verify the list filters to only matching doctors.
  3. Clear the field — verify the full list returns.
  4. Type a query matching nothing — verify a "No results for '{query}'" message (`s.noResultsFor`) appears, centered.
- **Edge Cases / Notes**: If the patient has zero linked doctors at all (regardless of search), a dedicated empty state (below) takes precedence over the "no results" message.

### My Doctors — Empty State (no linked doctors)
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists (body, when `getLinkedDoctors()` stream returns empty)
- **Expected Behavior**: Shows a large circular icon (person-search), bold heading `s.noDoctorsAdded`, descriptive text `s.searchForDoctor`, and a prominent "Find a Doctor or Therapist" (`s.findDoctorOrTherapist`) `ElevatedButton.icon` with a search icon.
- **Test Steps**:
  1. As a patient with no linked doctors (`doctor_ids` empty), open My Doctors.
  2. Verify the empty-state illustration, heading, description, and button appear.
  3. Tap the "Find a Doctor or Therapist" button.
  4. Verify it does a `pushReplacement` to `FindDoctorsScreen` (i.e., My Doctors is replaced in the nav stack, not pushed on top).
- **Edge Cases / Notes**: Uses `pushReplacement`, unlike the AppBar's person-add icon which uses `push`.

### My Doctors — Linked Doctor Card: Request button
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists > each doctor card > "Request" button (blue, calendar-check icon)
- **Expected Behavior**: Opens the "Request Appointment" bottom sheet for that doctor (see dedicated section below).
- **Test Steps**:
  1. With at least one linked doctor, tap "Request" on their card.
  2. Verify the Request Appointment bottom sheet opens with that doctor's name.
- **Edge Cases / Notes**: See "Linked Doctor — Request Appointment sheet" below for full flow.

### My Doctors — Linked Doctor Card: Contact button
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists > each doctor card > "Contact" button (green if phone on file, grey if not, phone icon)
- **Expected Behavior**:
  - If the doctor has no phone number on file, tapping shows a SnackBar: "No phone number on file for this doctor."
  - If a phone number exists, tapping opens a bottom sheet showing the phone number text, then two `ListTile`s: "WhatsApp" (green chat icon — opens `https://wa.me/{cleanedPhone}` externally) and "Phone Call" (phone icon — opens `tel:{cleanedPhone}` externally).
- **Test Steps**:
  1. For a linked doctor without a phone number, tap "Contact" — verify the "No phone number on file" SnackBar.
  2. For a linked doctor with a phone number, tap "Contact" — verify the bottom sheet opens showing the phone number.
  3. Tap "WhatsApp" — verify it attempts to launch WhatsApp / `wa.me` link externally (and the sheet closes first).
  4. Re-open, tap "Phone Call" — verify it attempts to launch the dialer via `tel:` externally (and the sheet closes first).
- **Edge Cases / Notes**: Phone number is sanitized via `replaceAll(RegExp(r'[\s\-()]'), '')` before building the URL. Button color/state is purely based on whether `phone` is non-empty after this cleanup.

### My Doctors — Linked Doctor Card: "Next Appointment" banner
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists > each doctor card (appears below name/specialization, only if a future non-cancelled appointment with this doctor exists)
- **Expected Behavior**: A light-blue banner with calendar icon and text "Next Appointment: {MMM d, yyyy}" showing the soonest upcoming appointment with that specific doctor.
- **Test Steps**:
  1. With a linked doctor who has an upcoming appointment, verify the banner appears with the correct date.
  2. For a linked doctor with no upcoming appointment, verify the banner is absent (no placeholder shown).
- **Edge Cases / Notes**: Computed via a per-card `FutureBuilder` query (`_getNextAppt`), not a stream — won't update live without a rebuild.

### My Doctors — Linked Doctor Card: "Home Visit" badge
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists > each doctor card (green pill, home icon, "Home Visit")
- **Expected Behavior**: Shown only if the doctor's `offers_home_visit` is true.
- **Test Steps**:
  1. View a linked doctor with home-visit enabled — verify the green "Home Visit" pill appears under their name/specialization/clinic.
  2. View a linked doctor without home-visit — verify the pill is absent.
- **Edge Cases / Notes**: Purely informational, no interaction.

### My Doctors — Linked Doctor Card: "View Doctor Profile" button
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists > each doctor card > bottom full-width purple button, person-search icon, "View Doctor Profile"
- **Expected Behavior**: Opens a `DraggableScrollableSheet` (initial 80% height, up to 95%, down to 40%) showing: avatar, name ("Dr. " prefix if applicable), specialization, then rows (icon + text) for clinic name, clinic address, phone (tappable — opens the same WhatsApp/Phone-call bottom sheet as Contact), years of experience, certifications, "Home visits available" (if applicable, green), working hours (if non-empty, blue). If a bio exists, an "About" section with the bio text follows.
- **Test Steps**:
  1. Tap "View Doctor Profile" on a linked doctor card.
  2. Verify the sheet opens and drag-resizes between ~40% and ~95% of screen height.
  3. Verify each populated field (clinic, address, phone, experience, certifications, home-visit flag, working hours, bio) renders correctly; verify any empty fields are omitted (no blank rows).
  4. Tap the phone row (if present) — verify it opens the WhatsApp/Phone-call bottom sheet (with "open in new" icon shown next to phone row).
- **Edge Cases / Notes**: Rows with empty string values are hidden entirely (`_sheetRow` returns `SizedBox.shrink()` for empty text).

---

### Linked Doctor — Request Appointment sheet
- **Platform**: Both
- **Location**: Patient > My Doctors/Therapists > doctor card > "Request" button
- **Expected Behavior**: A modal bottom sheet (rounded top corners, max height 85% of screen) titled "Request Appointment" with the doctor's name (with "Dr." prefix if applicable) as subtitle. Contains:
  - An optional "working hours" info banner (blue, clock icon) if the doctor has `working_hours` set.
  - **Date picker row**: tappable container showing "Tap to choose a date" until a date is chosen, then `EEEE, MMMM d, yyyy`. Opens a `showDatePicker` with `firstDate` = tomorrow, `lastDate` = +60 days.
  - **Available Times** (shown once a date is selected): a `Wrap` of hourly slot chips from 9 AM–5 PM (only future times relative to now), each showing `h:mm a`. Already-booked slots are shown disabled/greyed with strikethrough. Selecting a slot highlights it blue. While slots are loading, shows a small spinner. If no slots available for the chosen day, shows "No slots available for this day."
  - **Notes field**: optional multi-line text field, hint "Reason / notes (optional)", notes icon.
  - **Send button**: full-width, blue, with calendar/send icon. Label reads "Select a time slot" while disabled (no date/slot chosen), or "Send Request" once both are chosen. Shows a spinner while sending.
- **Expected Behavior (on send)**: Calls `PatientService.sendAppointmentRequest` with doctorId, doctorName, the selected slot DateTime, and trimmed notes. On success, closes the sheet and shows a green SnackBar "Appointment request sent!"; on failure, a red SnackBar "Failed to send request."
- **Test Steps**:
  1. Open the Request Appointment sheet for a linked doctor.
  2. If `working_hours` is set on that doctor, verify the working-hours banner displays it.
  3. Tap the date row — verify the date picker opens with valid range (tomorrow through +60 days); pick a date.
  4. Verify the "Available Times" section appears, slots load (spinner then chips), and any already-booked slots for that day appear disabled/struck-through.
  5. Tap an available slot — verify it highlights and the Send button becomes enabled with label "Send Request".
  6. Enter optional notes text.
  7. Tap "Send Request" — verify a spinner shows briefly, the sheet closes, and a green "Appointment request sent!" SnackBar appears.
  8. Verify the new request appears in Patient > My Appointments > Requested tab with status "Pending".
  9. Re-open the sheet, pick a new date — verify booked slots refresh for the new date (re-fetches `getDoctorBookedSlots`).
  10. Attempt to tap Send before selecting date/slot — verify it's disabled and reads "Select a time slot".
- **Edge Cases / Notes**: All slots for "today" are excluded if already past current time (`slot.isAfter(DateTime.now())`). A slot is considered "booked" if any existing appointment for that doctor matches year/month/day/hour. Send failure path (red SnackBar "Failed to send request.") should be tested if possible (e.g., simulate a network/Supabase error).

---

## Notifications

- **Platform**: Both. AppBar (navy background, white text) titled "Notifications" with a "Mark all read" text button (top-right, white70 text).

### Notifications — Mark all read
- **Platform**: Both
- **Location**: Patient > Notifications > AppBar action ("Mark all read")
- **Expected Behavior**: Updates all of the patient's unread notifications (`read = false` → `true`) in Supabase. List items visually update (unread styling removed) live via the realtime stream.
- **Test Steps**:
  1. With at least one unread notification (bold title, colored dot indicator, tinted background/border), tap "Mark all read".
  2. Verify all notifications switch to "read" styling (white background, default border, normal-weight title, no colored dot).
  3. Verify the Home screen's Notifications grid-tile badge disappears (since `_unreadCount` becomes 0).
- **Edge Cases / Notes**: None.

### Notifications — Empty state
- **Platform**: Both
- **Location**: Patient > Notifications (body, when no notifications exist)
- **Expected Behavior**: Shows a bell-off icon and "No notifications yet." text, centered.
- **Test Steps**:
  1. As a patient with zero notifications, open Notifications.
  2. Verify the empty-state icon and message.
- **Edge Cases / Notes**: None.

### Notifications — List item (tap to mark read)
- **Platform**: Both
- **Location**: Patient > Notifications > each notification row
- **Expected Behavior**: Each row shows a colored circular icon (icon/color depends on `type`: appointment_accepted=green check, appointment_declined=red cancel, appointment_scheduled/appointment=blue calendar/event, appointment_reminder/reminder=orange/amber alarm, message=indigo chat bubble, call=teal phone, default=primary assignment icon), with a small colored dot badge if unread. Shows title (bold if unread), body text, and a relative timestamp ("Just now", "{n}m ago", "{n}h ago", "{n}d ago", or `MMM d` for 7+ days). Tapping an unread item calls `markNotificationRead` (marks read; styling updates).
- **Test Steps**:
  1. With multiple notifications of different `type` values, verify each shows the correct icon/color combination listed above.
  2. Tap an unread notification — verify it becomes "read" styled (background/border/title weight change, dot removed) without navigating anywhere.
  3. Tap an already-read notification — verify no error/no-op (still no navigation).
  4. Verify relative-time labels are correct for items of varying ages (just now / minutes / hours / days / older than a week shows month-day).
- **Edge Cases / Notes**: Tapping a notification does NOT navigate to any related screen (e.g., the relevant appointment) — it only marks it read.

### Notifications — Swipe to delete (Dismissible)
- **Platform**: Both (swipe gesture; on desktop with mouse, drag works the same way in Flutter web)
- **Location**: Patient > Notifications > each notification row (swipe right-to-left / end-to-start)
- **Expected Behavior**: Swiping a notification from end to start reveals a red background with a delete (trash) icon, and on completing the dismiss gesture, permanently deletes that notification row from Supabase (`notifications` table).
- **Test Steps**:
  1. On a notification row, swipe from right to left (end-to-start).
  2. Verify the red delete background with trash icon is revealed during the swipe.
  3. Complete the swipe (dismiss) — verify the notification disappears from the list and is deleted (won't reappear on refresh/stream update).
- **Edge Cases / Notes**: No "undo" option; deletion is immediate/permanent. If this was the only unread item, verify the Home badge updates accordingly.

---

## My Profile

- **Platform**: Both. Body has a navy/blue gradient header (back arrow, "My Profile" title, avatar with camera-overlay edit button, display name, email) over a scrollable white-card menu and action buttons.

### My Profile — Back navigation (arrow icon)
- **Platform**: Both
- **Location**: Patient > My Profile (top-left of gradient header, `Icons.arrow_back_ios_new_rounded`)
- **Expected Behavior**: Pops the My Profile screen, returning to the previous screen (Home, or wherever profile was opened from).
- **Test Steps**:
  1. Open My Profile from Home's profile tile.
  2. Tap the back arrow.
  3. Verify it returns to Home.
- **Edge Cases / Notes**: None.

### My Profile — Avatar / Change Photo (camera icon overlay)
- **Platform**: Both
- **Location**: Patient > My Profile (gradient header, circular avatar with small blue camera-icon button at bottom-right)
- **Expected Behavior**: Tapping the camera icon opens the device/browser image picker (gallery source, quality 70, max width 800px). On selection, shows a spinner over the avatar while uploading, uploads to Supabase Storage bucket `profile-photos` under `profile_photos/patients/{uid}_{timestamp}.jpg`, updates the `users.profile_photo_url` field, and replaces the avatar image. On error, shows a SnackBar "Upload failed: {error}".
- **Test Steps**:
  1. On My Profile, tap the camera icon over the avatar.
  2. Select an image from the gallery/file picker.
  3. Verify a loading spinner appears over the avatar during upload.
  4. Verify the avatar updates to the new photo on success.
  5. Verify the new photo persists after navigating away and back (and on Home's profile tile / upcoming-appointment doctor avatars elsewhere, if applicable to patient photo usage).
  6. (If feasible) simulate an upload failure and verify the "Upload failed: ..." SnackBar appears.
- **Edge Cases / Notes**: If no photo is set, avatar shows a white person icon on translucent white background. Picker cancellation (no image selected) results in no change (silently returns).

### My Profile — Menu: Edit Profile
- **Platform**: Both
- **Location**: Patient > My Profile > white card menu, first row ("Edit Profile" / "Update your name and phone number", blue pencil icon)
- **Expected Behavior**: Opens a bottom sheet titled "Edit Profile" containing:
  - A read-only "Full Name" display row (person icon, lock icon on the right, showing current name or "—" if empty) — name is NOT editable here.
  - **Phone Number** field (editable, phone icon, keyboard type phone).
  - **Email Address** field — read-only (`AbsorbPointer`), pre-filled with the account email, email icon.
  - "Save Profile" button (full width). Shows a spinner while saving. On save, updates `users.phone` in Supabase, closes the sheet, and shows a green "Profile saved!" SnackBar. On error, shows a SnackBar "Error: {e}".
- **Test Steps**:
  1. Tap "Edit Profile".
  2. Verify the sheet opens with: a non-editable "Full Name" row showing the current name (or "—"), an editable "Phone Number" field, and a non-editable "Email Address" field pre-filled with the account email.
  3. Edit the phone number field to a new value.
  4. Tap "Save Profile" — verify spinner shows, sheet closes, and a green "Profile saved!" SnackBar appears.
  5. Re-open "Edit Profile" — verify the new phone number persisted.
  6. Attempt to tap/edit the "Full Name" or "Email Address" fields — verify they cannot be edited (locked/absorbed pointer).
- **Edge Cases / Notes**: Only `phone` is persisted by this sheet — name and email cannot be changed from here despite name being displayed. No client-side validation on phone format (any text is accepted and trimmed).

### My Profile — Menu: Change Password
- **Platform**: Both
- **Location**: Patient > My Profile > white card menu, second row ("Change Password" / "Update your account password", purple lock icon)
- **Expected Behavior**: Opens a bottom sheet titled "Change Password" with three password fields, each with a visibility-toggle (eye) icon:
  - **Current Password**
  - **New Password**
  - **Confirm New Password**
  - "Change Password" button (green background, full width). Validations: if New Password ≠ Confirm New Password, shows SnackBar "Passwords do not match." (no submission). If New Password length < 6, shows SnackBar "Password must be at least 6 characters." (no submission). Otherwise calls `Supabase.auth.updateUser` with the new password; on success clears all three fields, closes the sheet, and shows a green "Password changed!" SnackBar. On `AuthException`, shows "Current password is incorrect." if `e.code == 'wrong-password'`, else "Error: {e.message}".
- **Test Steps**:
  1. Tap "Change Password".
  2. Verify three password fields (Current/New/Confirm), each with a toggleable visibility icon (eye / eye-off).
  3. Toggle visibility on each field and confirm text becomes visible/obscured.
  4. Enter mismatched New/Confirm passwords, tap "Change Password" — verify "Passwords do not match." SnackBar, sheet stays open.
  5. Enter a New Password under 6 characters (matching Confirm), tap "Change Password" — verify "Password must be at least 6 characters." SnackBar.
  6. Enter a valid matching New/Confirm password (≥6 chars), tap "Change Password" — verify spinner, sheet closes, green "Password changed!" SnackBar, and fields are cleared.
  7. Sign out and sign back in with the new password to confirm it took effect.
- **Edge Cases / Notes**: The "Current Password" field is collected in the UI but is NOT actually validated against the current password in this code path (Supabase `updateUser` doesn't require/check it here) — flag if this is unexpected/a security concern. `wrong-password` error-code handling exists but may never trigger given the above.

### My Profile — Menu: App Settings
- **Platform**: Both
- **Location**: Patient > My Profile > white card menu, third row ("App Settings" / "Language and preferences", grey gear icon, no divider below)
- **Expected Behavior**: Opens an `AlertDialog` titled "App Settings" containing a single `ListTile`: "Language" with a globe icon, trailing text showing the current language ("العربية" or "English"). Tapping the tile toggles the app language and closes the dialog. A "Close" button is also present.
- **Test Steps**:
  1. Tap "App Settings".
  2. Verify the dialog shows "Language" row with the current language as trailing text.
  3. Tap the "Language" row — verify the dialog closes and the app's language toggles (and, if Arabic, RTL applies app-wide).
  4. Re-open "App Settings" — verify the trailing text now shows the other language.
  5. Open again and tap "Close" — verify the dialog dismisses without changing language.
- **Edge Cases / Notes**: This is a second language-toggle entry point in addition to the Home header pill chip — both should stay in sync (shared `LanguageProvider`).

### My Profile — Sign Out
- **Platform**: Both
- **Location**: Patient > My Profile (below the menu card, red outlined full-width button, logout icon, "Sign Out")
- **Expected Behavior**: Opens an `AlertDialog` titled "Sign Out" with text "Are you sure you want to sign out?" and actions "Cancel" / "Sign Out" (red text). Confirming calls `Supabase.auth.signOut()`, then (per this session's change) calls `Navigator.of(context).popUntil((route) => route.isFirst)` to return the user all the way to the first route (the Login screen), not just pop one screen.
- **Test Steps**:
  1. Navigate into My Profile from Home (so there's at least one route on the stack below it).
  2. Tap "Sign Out".
  3. Verify the confirmation dialog appears with "Are you sure you want to sign out?" and Cancel/Sign Out buttons.
  4. Tap "Cancel" — dialog dismisses, still on My Profile.
  5. Tap "Sign Out" again, then confirm "Sign Out" in the dialog.
  6. Verify the session ends (`signOut()`) AND the navigation stack pops all the way back to the LOGIN screen (not just back to Home) — i.e., the Login screen is shown, not the Patient Dashboard Home.
  7. Verify attempting to navigate back (e.g., browser back button on web) from Login does not return to an authenticated screen.
- **Edge Cases / Notes**: This is the PRIMARY verified change for this session — confirm explicitly that after confirming Sign Out, the LOGIN screen is shown (full stack pop), not the Home/dashboard screen. Contrast with the Home-tile long-press "Logout" dialog (different screen, different code path — `_showLogout` in `PatientDashboardScreen` — which does NOT call `popUntil`).

### My Profile — Delete Account
- **Platform**: Both
- **Location**: Patient > My Profile (below Sign Out, centered, small red outlined button (~32px tall), trash icon, "Delete Account")
- **Expected Behavior**: Opens an `AlertDialog` titled "Delete Account" with body "This permanently deletes all your data and cannot be undone. Are you sure?" and actions "Cancel" / "Delete" (red text). Confirming sets a loading state (button becomes disabled, icon replaced with a small red spinner, label changes to "Deleting...") and calls `AuthService().deleteMyAccount()`. If it returns an error string, shows SnackBar "Error: {error}". On full success, the account/session is presumably terminated (app should navigate away — verify where it lands, likely Login via the auth-state listener).
- **Test Steps**:
  1. Navigate to My Profile.
  2. Verify the "Delete Account" button is small, centered, red-outlined, ~32px tall, with a trash/delete-forever icon — confirm this matches the session's described styling change (`OutlinedButton.icon`, red, small/centered).
  3. Tap "Delete Account".
  4. Verify the confirmation dialog appears with the exact warning text and "Cancel"/"Delete" actions.
  5. Tap "Cancel" — dialog dismisses, no changes.
  6. Tap "Delete Account" again, confirm "Delete".
  7. Verify the button shows "Deleting..." with a small red spinner and is disabled during the operation.
  8. On success, verify the app navigates away from the patient dashboard entirely (e.g., to Login/onboarding) and the account can no longer log in with the same credentials.
  9. (If possible without destroying a needed test account) on a forced-error scenario, verify the "Error: {error}" SnackBar appears and the button returns to its normal (non-deleting) state.
- **Edge Cases / Notes**: This is the SECOND verified change for this session — confirm the button is visually smaller/centered/red `OutlinedButton.icon` (~32px) as described, not the previous (larger) styling. Use a disposable/test patient account only — this operation is destructive and irreversible.

---

## Find a Therapist (find_doctors_screen.dart)

- **Platform**: Both. AppBar (patient-gradient-start background, white text/icons) titled "Find a Therapist" (`s.findTherapist`), with a map/list toggle icon on the right. Can be reached: (a) logged-in, from Home's "Find a Doctor or Therapist" tile, My Doctors' person-add icon, or My Doctors' empty-state button; (b) as a GUEST (mobile-only, `isGuest: true`, via "Continue as Guest" on the login screen — out of scope here but noted below where it changes behavior).

### Find a Therapist — Map/List view toggle
- **Platform**: Both
- **Location**: Patient > Find a Therapist > AppBar action (top-right icon: map icon when in list view, list icon when in map view)
- **Expected Behavior**: Toggles between a scrollable list of doctor cards and an interactive map (OpenStreetMap tiles via `flutter_map`) showing pins for doctors with location data. Switching to map view for the first time triggers a location permission request/fetch if `_myPosition` is null.
- **Test Steps**:
  1. On Find a Therapist, default should be List view (list of doctor cards).
  2. Tap the map icon in the AppBar.
  3. Verify the view switches to a map (tooltip "Map View"/"List View" updates accordingly, icon swaps to list icon).
  4. If location permission hasn't been granted, verify a location permission prompt/flow triggers (see "Nearby filter chip" for permission-denied messaging).
  5. Tap the list icon to switch back to List view.
- **Edge Cases / Notes**: None additional beyond location handling covered below.

### Find a Therapist — Search field
- **Platform**: Both
- **Location**: Patient > Find a Therapist (top of body, below AppBar)
- **Expected Behavior**: TextField with hint "Search by name, specialization, clinic…" and a search icon. Typing filters the doctor list (case-insensitive) across name, specialization, clinic name, bio, and experience text. A clear ("X") icon appears in the field when text is present, which clears the search.
- **Test Steps**:
  1. Type a query matching a doctor's name — verify the list filters to matches.
  2. Type a query matching only a specialization, clinic name, bio, or experience string — verify matching doctors appear even if the name doesn't match.
  3. Type a query matching nothing — verify the empty "no results" state (`s.noData`, search-off icon) appears.
  4. With text entered, tap the clear ("X") icon — verify the field clears and the full filtered (non-search) list returns.
- **Edge Cases / Notes**: Search combines with the "Home Visit" filter and the base "premium + show_in_search" filter (see below) — i.e., search narrows further within doctors that are already eligible to be shown.

### Find a Therapist — Filter chip: All
- **Platform**: Both
- **Location**: Patient > Find a Therapist (chip row below search field, first chip "All")
- **Expected Behavior**: Resets both "Nearby" and "Home Visit" filters to off, showing the full (premium + show_in_search) doctor list. Highlighted (primary color) when both other filters are inactive.
- **Test Steps**:
  1. Activate "Nearby" and/or "Home Visit" filters.
  2. Tap "All".
  3. Verify both other chips deactivate (return to unselected style) and the list/map shows all eligible doctors (un-sorted by distance, un-filtered by home-visit).
- **Edge Cases / Notes**: None.

### Find a Therapist — Filter chip: Nearby
- **Platform**: Both
- **Location**: Patient > Find a Therapist (chip row, second chip — "Nearby" / "Locating…" while fetching location, near-me icon)
- **Expected Behavior**: Toggles `_nearbyMode`. When activated and `_myPosition` is null, triggers `_getLocation()` (label changes to "Locating…" during the fetch). Once a position is known, the doctor list (and map's "on map" count / initial center) sorts by distance ascending from the user's location; doctors without lat/long are sorted to the end (`double.maxFinite`). Each doctor card shows a "near me" icon + "{distance} km away" (`s.kmAway`) when a position is known and the doctor has coordinates.
- **Test Steps**:
  1. Tap "Nearby" (ensure location permission not yet granted, if testing the permission flow).
  2. If permission is requested, verify the OS/browser location permission prompt appears.
  3. **Permission denied**: verify a SnackBar appears — on Windows: "Location denied. Enable in Windows Settings → Privacy & security → Location."; on other platforms: "Location denied. Enable in device settings." Verify "Nearby" remains togglable but list doesn't sort by distance (no position).
  4. **Permission granted**: verify the chip shows "Locating…" briefly, then "Nearby" (active/highlighted), and the doctor list re-sorts with nearest doctors first, each showing "{X.X} km away".
  5. Switch to Map view — verify the map centers on the user's location (blue "my location" marker) and zooms to level 13.
  6. Tap "Nearby" again to deactivate — verify sorting reverts to default order and distance labels disappear (or remain if `_myPosition` still cached — confirm actual behavior: distance display depends only on `_myPosition != null`, not `_nearbyMode`, so labels may persist even after deactivating Nearby — verify this).
- **Edge Cases / Notes**: A general location error (other than permission denial) shows SnackBar "Location error: {e}". The distance label on cards is shown whenever `_myPosition` is non-null AND the doctor has lat/long — independent of whether "Nearby" sort mode is currently active.

### Find a Therapist — Filter chip: Home Visit
- **Platform**: Both
- **Location**: Patient > Find a Therapist (chip row, third chip — "Home Visit", home icon)
- **Expected Behavior**: Toggles `_homeVisitOnly`. When active, the list/map only shows doctors with `offers_home_visit == true`. Combines with search and Nearby sorting.
- **Test Steps**:
  1. Note the full doctor count/list.
  2. Tap "Home Visit" — verify only doctors with the green "Home Visit" badge remain in the list (or as map pins).
  3. Tap "Home Visit" again to deactivate — verify the full list returns.
  4. Combine with "Nearby" and/or search query — verify all three filters apply together (AND logic).
- **Edge Cases / Notes**: None.

### Find a Therapist — Base visibility filter (premium + show_in_search)
- **Platform**: Both
- **Location**: Patient > Find a Therapist (applies to ALL doctors shown, both list and map, regardless of filter chips)
- **Expected Behavior**: Only doctors with `subscription == 'premium'` AND `show_in_search != false` (default true) appear anywhere on this screen. Non-premium or hidden doctors never appear, even if linked.
- **Test Steps**:
  1. (Requires test data / admin access) Confirm a doctor with `subscription = 'basic'` does NOT appear in Find a Therapist search results, even when searching their exact name.
  2. Confirm a premium doctor with `show_in_search = false` also does not appear.
  3. Confirm a premium doctor with `show_in_search = true` (or unset) does appear.
- **Edge Cases / Notes**: This is a silent filter — there's no UI messaging explaining why a known doctor might not appear in search. Worth confirming this matches product intent (testers may be confused if a doctor they expect doesn't show up).

### Find a Therapist — Map View: Doctor pin tap
- **Platform**: Both
- **Location**: Patient > Find a Therapist > Map view > green location pins with doctor-initial avatar
- **Expected Behavior**: Tapping a pin opens a bottom sheet ("Doctor Sheet") with avatar, name ("Dr. " prefix if applicable), specialization, "Home visits available" text (green, if applicable), bio (up to 3 lines, ellipsis), and an "Add to My List" / "Added to My List" button (see below).
- **Test Steps**:
  1. Switch to Map view with at least one doctor having lat/long set.
  2. Verify pins render (green location-pin icon with a small circular avatar showing the doctor's first initial).
  3. Tap a pin — verify the bottom sheet opens with correct doctor details.
  4. Verify the "{N} on map" counter chip (top-left, place icon) reflects the count of doctors with coordinates among the currently filtered set.
- **Edge Cases / Notes**: Doctors without `latitude`/`longitude` are skipped entirely on the map (no pin) but still counted in list view.

### Find a Therapist — "Add to My List" (list card & map-pin sheet)
- **Platform**: Both (behavior differs for guest vs. logged-in — see Edge Cases)
- **Location**: Patient > Find a Therapist > each doctor list card (bottom, full-width button) AND map pin tap-sheet (same button)
- **Expected Behavior**:
  - If already linked (`isLinked` true): button shows green background, check-circle icon, label "Added to My List", and is disabled.
  - If not linked: button shows primary color, person-add icon, label "Add to My List", enabled.
  - **Logged-in patient**: tapping calls `_addToMyList` → `PatientService.addDoctorToMyList(doctorId)`. On success: button becomes "Added to My List" (green, disabled) and a green SnackBar "Doctor added to your list!" appears; the doctor is also added to the doctor's `assigned_patient_ids` and the doctor receives a "New Patient Added You" notification. On failure: red SnackBar "Failed to add doctor. Try again."
  - **Guest** (`isGuest == true`): tapping shows the Guest Sign-In prompt instead (see next item) — no data is written.
- **Test Steps**:
  1. As a logged-in patient, find a doctor NOT already in "My Doctors". Verify their card/sheet button reads "Add to My List" (primary color, person-add icon, enabled).
  2. Tap it — verify a green "Doctor added to your list!" SnackBar appears and the button updates in place to "Added to My List" (green, check icon, disabled).
  3. Navigate to Patient > My Doctors/Therapists — verify the doctor now appears in the linked list.
  4. Re-open Find a Therapist for a doctor already linked — verify the button shows "Added to My List" pre-disabled from the start.
  5. (If possible) simulate a failure and verify the red "Failed to add doctor. Try again." SnackBar.
- **Edge Cases / Notes**: This same button/flow exists in both the list-card (`_DoctorListCard`) and the map pin's bottom sheet (`_showDoctorSheet`) — verify both stay in sync (e.g., add via map sheet, then check the list card reflects "Added to My List" too, since `_linkedDoctorIds` is shared state).

### Find a Therapist — Guest Sign-In prompt (guest-only)
- **Platform**: Mobile only (guest flow is mobile-only per `FormFactorFeatures.showGuestLogin`)
- **Location**: Patient > Find a Therapist (guest mode) > tap "Add to My List" on any doctor
- **Expected Behavior**: Opens an `AlertDialog` titled `s.guestSignInRequiredTitle` with body `s.guestSignInPrompt`, actions "Cancel" (`s.cancel`) and "Sign In" (`s.signIn`, `ElevatedButton`). Tapping "Sign In" closes the dialog AND pops the Find a Therapist screen itself (`Navigator.of(context).pop()`), presumably returning the guest to the Login screen.
- **Test Steps**:
  1. From the Login screen, use "Continue as Guest" (mobile) to reach Find a Therapist in guest mode.
  2. Search/browse for a doctor and tap "Add to My List".
  3. Verify the Guest Sign-In dialog appears with the expected title/body and "Cancel"/"Sign In" buttons.
  4. Tap "Cancel" — dialog closes, remains on Find a Therapist (guest), no data written.
  5. Tap "Add to My List" again, then "Sign In" — verify the dialog closes AND the Find a Therapist screen itself closes/pops (returning to Login).
- **Edge Cases / Notes**: In guest mode, `initState` skips `_loadLinkedDoctors()` (since there's no authenticated user), so `_linkedDoctorIds` stays empty — every doctor shows "Add to My List" (never "Added to My List") for a guest, even if (hypothetically) some were previously linked under a real account.

### Find a Therapist — Doctor List Card: info badges (Home Visit / Experience / Certifications)
- **Platform**: Both
- **Location**: Patient > Find a Therapist > List view > each doctor card (badge row below name/specialization)
- **Expected Behavior**: Shows up to three pill badges where applicable: green "Home Visit" (house icon) if `offers_home_visit`; blue badge with work-history icon showing the `experience` string if non-empty; purple badge with military-tech icon showing `certifications` string if non-empty. Row is omitted entirely if none apply.
- **Test Steps**:
  1. View a doctor card with all three attributes set — verify all three badges render with correct icons/colors/text.
  2. View a doctor with none of these set — verify the badge row is absent (no empty space/row).
  3. View a doctor with only one or two set — verify only those badges show.
- **Edge Cases / Notes**: Purely informational, no tap targets.

### Find a Therapist — Doctor List Card: bio, clinic/address
- **Platform**: Both
- **Location**: Patient > Find a Therapist > List view > each doctor card (below badges)
- **Expected Behavior**: If `bio` is non-empty, shows up to 2 lines with ellipsis. If `clinic` and/or `address` are non-empty, shows a business icon + the values joined by " · " (only non-empty parts), single line with ellipsis.
- **Test Steps**:
  1. View a doctor with a long bio — verify it truncates to 2 lines with "…".
  2. View a doctor with both clinic name and address set — verify both show joined by " · ".
  3. View a doctor with only one of clinic/address set — verify only that value shows (no stray " · ").
  4. View a doctor with neither bio nor clinic/address — verify neither row renders.
- **Edge Cases / Notes**: None.

### Find a Therapist — Doctor List Card: "My Doctor" badge
- **Platform**: Both
- **Location**: Patient > Find a Therapist > List view > each doctor card (top-right, green pill, check-circle icon, "My Doctor")
- **Expected Behavior**: Shown only if `isLinked` is true for that doctor (already in the patient's `doctor_ids`).
- **Test Steps**:
  1. View a doctor already linked — verify the "My Doctor" badge appears in the card header.
  2. View an unlinked doctor — verify it's absent.
- **Edge Cases / Notes**: This is distinct from but consistent with the "Added to My List" button state at the bottom of the same card — both should reflect `isLinked` in sync.

### Find a Therapist — Empty state (no results)
- **Platform**: Both
- **Location**: Patient > Find a Therapist > List view (when filtered `docs` list is empty)
- **Expected Behavior**: Shows a search-off icon and `s.noData` text, centered.
- **Test Steps**:
  1. Apply a filter combination (e.g., search query + Home Visit) that matches zero doctors.
  2. Verify the search-off icon + "no data" message appears in place of the list.
- **Edge Cases / Notes**: This same empty state covers both "no doctors in the system meet the base premium/show_in_search criteria" and "no doctors match the current filters" — there's no differentiation in messaging between these two cases.

---

**Summary**: 45 top-level `### ` items written to `C:\Users\Jihad\AppData\Local\Temp\manual_checklist\part5.md`.

---

## Admin Dashboard

> Platform availability (overall): **Both** — the previous `FormFactorFeatures.showAdminDashboard` desktop-only gate and the `AvailableOnDesktopScreen` fallback have been removed. `AdminDashboardScreen` is shown to every admin regardless of screen width (`lib/main.dart`). The layout is the same Column structure (`_header` → `_navBar` → body) on both form factors; on mobile (<600px) the nav bar row becomes horizontally scrollable instead of fitting on one line, and content lists/cards reflow to full width. Any further differences are called out per-item below.

### Header — Admin Portal title
- **Platform**: Both (identical layout — gradient header bar with icon, "Admin Portal" / "PhysioConnect" text)
- **Location**: Admin > Header (always visible at top of every section)
- **Expected Behavior**: Shows a 44x44 rounded icon container with `Icons.admin_panel_settings_rounded`, "Admin Portal" (bold, white, 18px) and "PhysioConnect" subtitle (white 60% opacity, 12px) on a slate-to-ink gradient background.
- **Test Steps**:
  1. Log in as an admin user.
  2. Observe the header bar at the top of the screen on both desktop (~1400px) and mobile (390px) widths.
- **Edge Cases / Notes**: Header text does not wrap/truncate in current code — verify no overflow if a future build changes "PhysioConnect" text length.

### Header — Sign Out icon button
- **Platform**: Both
- **Location**: Admin > Header > top-right icon button (`Icons.logout_rounded`, tooltip "Sign Out")
- **Expected Behavior**: Tapping signs the admin out via `Supabase.instance.client.auth.signOut()` and returns to the Login screen.
- **Test Steps**:
  1. From any Admin tab, tap the logout icon (top-right of header).
  2. Confirm the app navigates back to the Login screen.
- **Edge Cases / Notes**: No confirmation dialog before sign-out — verify this is intended (one tap immediately signs out).

### Nav Bar — 5-section horizontal nav (Overview / Doctors / Polyclinics / Register / Requests)
- **Platform**: Both (Desktop: all 5 buttons typically fit without scrolling; Mobile/390px: row is horizontally scrollable via `SingleChildScrollView` with `Axis.horizontal`)
- **Location**: Admin > Nav Bar (slate bar directly below header, present on every section)
- **Expected Behavior**: Renders 5 pill-shaped buttons in this exact order with icon + label:
  1. `Icons.dashboard_rounded` — "Overview"
  2. `Icons.people_rounded` — "Doctors"
  3. `Icons.business_rounded` — "Polyclinics"
  4. `Icons.person_add_rounded` — "Register"
  5. `Icons.notifications_rounded` — "Requests"
  Tapping a button sets `_currentIndex` and swaps the body content immediately (no animation/transition). The selected button shows a white border, semi-transparent white fill (`alpha: 0.12`), white icon/text; unselected buttons show `Colors.white24` border and `Colors.white38` icon/text.
- **Test Steps**:
  1. On Desktop (~1400px width), verify all 5 nav buttons are visible in one row without horizontal scrolling, each showing icon + label.
  2. Tap each of the 5 buttons in turn and verify the body below switches to the corresponding tab (Overview KPIs, Doctors list, Polyclinics list, Register form, Requests/notifications list) and the tapped button becomes visually "selected" (white border/fill).
  3. Resize the browser to 390x844 (or use Chrome DevTools mobile emulation, e.g. iPhone 13).
  4. Verify the nav bar row does not overflow vertically and instead becomes horizontally scrollable — swipe/drag left-right across the nav bar and confirm all 5 buttons are reachable and scroll smoothly.
  5. At 390px width, tap each of the 5 buttons again (scrolling to reveal them as needed) and verify the same section-switching behavior as desktop, with no rendering overflow (no red/yellow overflow banners) in any section.
- **Edge Cases / Notes**: Nav bar state (`_currentIndex`) is simple int 0-4 — verify selecting "Requests" (index 4, the `_` default case in the `switch`) correctly shows the notifications tab. Also verify rapid tapping between tabs does not leave stale StreamBuilder loading spinners.

---

### Overview Tab — KPI cards (Total Doctors / Basic / Premium)
- **Platform**: Both (cards stack the same; on mobile each `_kpiCard`'s value/label Column is wrapped in `Expanded` with `overflow: TextOverflow.ellipsis` on the label — this was the recent overflow fix)
- **Location**: Admin > Overview (default tab, index 0)
- **Expected Behavior**: Top row shows two cards side-by-side: "Total Doctors" (count of all doctor users, slate icon `Icons.people_rounded`) and "Basic" (count of doctors on Basic tier, `Icons.star_border_rounded`, Basic tier color). Below, a full-width "Premium" card shows count of Premium-tier doctors (`Icons.star_rounded`, Premium tier color). Each card shows a large bold number and a label below it.
- **Test Steps**:
  1. Navigate to Admin > Overview.
  2. Verify "Total Doctors" count equals the sum of "Basic" + "Premium" counts.
  3. On mobile (390px), verify the label text under each number ("Total Doctors", "Basic", "Premium") does not overflow/wrap awkwardly and ellipsizes if too long.
  4. Register a new doctor (via Register tab) and confirm counts update live (StreamBuilder on `users` table where `role = doctor`).
- **Edge Cases / Notes**: If the `users` stream errors, an error message "Error: ..." in red is shown instead of cards. While loading, a centered `CircularProgressIndicator` is shown.

### Overview Tab — Feature Distribution section
- **Platform**: Both
- **Location**: Admin > Overview > "Feature Distribution" section
- **Expected Behavior**: For each of the 3 features (Statistics, Income, Expenses — from `_kFeats`), shows a horizontal bar card with icon, feature label, a "`count` / `total`" fraction, and a `LinearProgressIndicator` showing the percentage of doctors with that feature enabled.
- **Test Steps**:
  1. Navigate to Admin > Overview, scroll to "Feature Distribution".
  2. Verify 3 rows are shown: Statistics (`Icons.bar_chart_rounded`, teal), Income (`Icons.receipt_long_rounded`, amber — labelled "Income" though internal key is `billing`), Expenses (`Icons.receipt_rounded`, teal).
  3. Toggle a feature for a doctor (Admin > Doctors > tap doctor > toggle a Feature Access switch > Apply Changes) and verify the corresponding bar/count updates after returning to Overview.
- **Edge Cases / Notes**: If `all.isEmpty` (no doctors), `pct` is computed as `0.0` to avoid divide-by-zero — verify bars render at 0% with no doctors registered.

### Overview Tab — Recent Registrations list
- **Platform**: Both
- **Location**: Admin > Overview > "Recent Registrations" section
- **Expected Behavior**: Shows up to 5 most-recently-created doctors (sorted by `created_at` descending), each as a row with avatar initials, name, email, and a tier badge (icon + label, colored by `SubTier`).
- **Test Steps**:
  1. Navigate to Admin > Overview, scroll to "Recent Registrations".
  2. Verify the most recently registered doctor appears first.
  3. Verify each row shows avatar (colored initials), name, email (ellipsized if long), and tier badge (Basic/Premium icon + label).
  4. With zero doctors registered, verify the empty-state card reading "No doctors registered yet." is shown instead of the list.
- **Edge Cases / Notes**: Doctors with `created_at == null` are sorted to the end. Email text uses `overflow: TextOverflow.ellipsis` — verify long emails truncate properly on mobile width.

---

### Doctors Tab — Summary card + "New" shortcut
- **Platform**: Both (card content same; full width on both)
- **Location**: Admin > Doctors (nav index 1)
- **Expected Behavior**: A gradient (slate→ink) summary card shows total doctor count ("`N` Doctor(s) Registered") with `Icons.people_rounded`, and a "New" pill button (`Icons.add_rounded` + "New" text) on the right.
- **Test Steps**:
  1. Navigate to Admin > Doctors.
  2. Verify the count matches the "Total Doctors" KPI from Overview.
  3. Tap the "New" pill button.
  4. Verify the app switches to the Register tab (`_currentIndex = 3`) with the Doctor type pre-selected.
- **Edge Cases / Notes**: Singular/plural handling — "1 Doctor Registered" vs "N Doctors Registered".

### Doctors Tab — Search field
- **Platform**: Both
- **Location**: Admin > Doctors > search box (below summary card)
- **Expected Behavior**: TextField with placeholder "Search name, email or specialization..." and a search icon. Typing filters the doctor list live (case-insensitive) by name, email, or specialization/specialty. Below the search box, a result-count label shows "`N` doctor(s) [found]".
- **Test Steps**:
  1. Navigate to Admin > Doctors.
  2. Type part of a known doctor's name into the search box — verify the list filters to matching doctors only and the count label updates (e.g. "1 doctor found").
  3. Type part of a doctor's specialization — verify it matches too.
  4. Type a string matching nothing — verify the empty state appears (see below).
  5. Clear the search box — verify the full list and "`N` doctors" (no "found" suffix) reappears.
- **Edge Cases / Notes**: Search query is lower-cased before comparison. Specialization may come from either `specialization` or `specialty` field — verify both populate search matches if present.

### Doctors Tab — Empty state (no doctors / no search results)
- **Platform**: Both
- **Location**: Admin > Doctors > body (when `filtered.isEmpty`)
- **Expected Behavior**: Centered icon (`Icons.people_outline_rounded` in a circle), heading text — "No doctor accounts yet" (if search empty) or `No results for "<query>"` (if searching) — and subtext "Use the Register tab to add a doctor." or "Try a different search term."
- **Test Steps**:
  1. With no doctors registered, navigate to Admin > Doctors and verify "No doctor accounts yet" / "Use the Register tab to add a doctor." is shown.
  2. With doctors present, search for a nonsense string and verify `No results for "<query>"` / "Try a different search term." is shown.
- **Edge Cases / Notes**: None additional.

### Doctors Tab — Doctor card (list item)
- **Platform**: Both (card layout is the same; on mobile the card is full width)
- **Location**: Admin > Doctors > doctor list (each card)
- **Expected Behavior**: Each card shows: avatar (initials, colored), name (bold), email (ellipsized), specialization chip (if present), a status bar row with: tier badge (Basic/Premium icon+label), expiry info (icon + "No expiry"/"Expires <Mon Year>"/"Expired <Mon Year>", color-coded green/amber/red), an Active/Disabled/Expired status chip, and (if Premium + `show_in_search`) a "Searchable" chip. Below that, a feature mini-chip row for Statistics/Income/Expenses showing enabled (colored) vs disabled (greyed) icons+labels. Tapping anywhere on the card opens the Manage Account bottom sheet.
- **Test Steps**:
  1. Navigate to Admin > Doctors with at least one doctor present.
  2. Verify avatar shows correct initials (first letters of up to 2 name words) in a color derived from the name.
  3. Verify the tier badge matches the doctor's `subscription` field (Basic vs Premium icon/label/color).
  4. For a doctor with no `expires_at`, verify "No expiry" in grey/secondary color.
  5. For a doctor with `expires_at` in the future >30 days, verify "Expires <Mon Year>" in green (`#2E7D32`).
  6. For a doctor with `expires_at` within 30 days, verify amber (`#F57F17`) "Expires <Mon Year>" and an "Active" status chip (if still enabled).
  7. For a doctor with `expires_at` in the past, verify red "Expired <Mon Year>" text, red card border, `Icons.timer_off_rounded`, and "Expired" status chip.
  8. For a Premium doctor with `show_in_search = true`, verify the "Searchable" chip appears (ink-colored).
  9. Verify the feature mini-chips (Statistics, Income, Expenses) reflect the doctor's `features` map — enabled features show colored icon+label, disabled show grey.
  10. Tap the card body (not the menu) — verify the Manage Account bottom sheet opens.
- **Edge Cases / Notes**: `isActive = isEnabled && !isExpired` drives whether status chip shows "Active" (green) vs "Disabled"/"Expired" (red). Verify a disabled-but-not-expired doctor shows "Disabled" not "Expired".

### Doctors Tab — Doctor card overflow menu (⋮)
- **Platform**: Both
- **Location**: Admin > Doctors > doctor card > top-right `Icons.more_vert_rounded` menu
- **Expected Behavior**: Opens a popup menu with two items: "Manage Account" (`Icons.manage_accounts_rounded`, slate) and "Remove Account" (`Icons.delete_rounded` in red circle, red text). "Manage Account" opens the same bottom sheet as tapping the card. "Remove Account" opens a confirmation dialog.
- **Test Steps**:
  1. Tap the ⋮ icon on a doctor card.
  2. Verify both menu items appear with correct icons/labels/colors.
  3. Select "Manage Account" — verify the Manage Account bottom sheet opens.
  4. Re-open the menu and select "Remove Account" — verify the "Remove Doctor" confirmation dialog opens (see next item).
- **Edge Cases / Notes**: None additional.

### Doctors Tab — "Remove Doctor" confirmation dialog
- **Platform**: Both
- **Location**: Admin > Doctors > card menu > "Remove Account" (or Manage sheet, if wired similarly)
- **Expected Behavior**: `AlertDialog` titled "Remove Doctor" with a red delete icon, body text `Remove "<name>" from the system?\nThis action cannot be undone.`, "Cancel" (TextButton) and "Remove" (red ElevatedButton) actions. Tapping "Remove" calls `AdminService.deleteUserAccount` (Edge Function `admin-delete-user`); on success shows green snackbar "Doctor account removed."; on failure shows red snackbar "Error: <message>".
- **Test Steps**:
  1. Tap ⋮ > "Remove Account" on a test doctor card.
  2. Tap "Cancel" — verify the dialog closes with no changes and the doctor remains in the list.
  3. Re-open the dialog and tap "Remove" — verify the dialog closes, a green snackbar "Doctor account removed." appears, and the doctor disappears from the list (live via stream).
  4. (If testable) simulate a backend error — verify a red snackbar "Error: <message>" appears and the doctor is NOT removed.
- **Edge Cases / Notes**: This is a destructive, irreversible action — confirm dialog wording emphasizes "This action cannot be undone."

### Doctors Tab — Manage Account bottom sheet (Subscription Tier)
- **Platform**: Both (modal bottom sheet, `isScrollControlled: true` — full content scrollable; on mobile the sheet takes near-full height)
- **Location**: Admin > Doctors > tap doctor card (or ⋮ > Manage Account)
- **Expected Behavior**: Sheet opens with a drag handle, doctor header (avatar, name, email, specialization chip, current tier badge), then "Subscription Tier" section with explanatory text "Selecting a tier auto-applies default features. You can still override them individually below." followed by tier chips for each `SubTier` value (e.g. Basic/Premium). Tapping a tier chip applies `SubConfig.defaultsFor(tier)` while preserving `isEnabled` and `expiresAt`; switching to Basic forces `showInSearch = false`.
- **Test Steps**:
  1. Open the Manage Account sheet for a doctor.
  2. Verify the doctor header shows correct avatar/initials, name, email, and (if set) specialization chip, plus the current tier badge in the top-right.
  3. Tap each tier chip (e.g. Basic, Premium) and verify: the chip becomes visually selected (filled with tier color, white icon/text, 2px border), and the Feature Access toggles below update to that tier's defaults.
  4. Select "Basic" tier and verify "Show in Find a Doctor" toggle (in Account Settings) is forced off.
  5. Select "Premium" and verify "Show in Find a Doctor" retains/allows its prior value.
- **Edge Cases / Notes**: Tier selection does not persist until "Apply Changes" is tapped at the bottom of the sheet.

### Doctors Tab — Manage Account sheet: Feature Access toggles
- **Platform**: Both
- **Location**: Admin > Doctors > Manage Account sheet > "Feature Access" section
- **Expected Behavior**: For each of Statistics, Income (`billing` key), Expenses, shows a row with icon, label, subtitle, and a `Switch.adaptive`. Toggling updates the local `SubConfig` (statistics/billing/expenses booleans). Enabled rows are tinted with the feature's color; disabled rows are grey.
- **Test Steps**:
  1. In the Manage Account sheet, locate "Feature Access" section with explanatory text "Toggle individual features on or off for this doctor."
  2. Toggle each of the 3 switches (Statistics, Income, Expenses) on and off, verifying the row's background/icon/text color changes between the feature's accent color (enabled) and grey (disabled).
  3. Tap "Apply Changes" and verify the Overview tab's Feature Distribution counts reflect the change.
- **Edge Cases / Notes**: None additional.

### Doctors Tab — Manage Account sheet: Doctor Info fields
- **Platform**: Both
- **Location**: Admin > Doctors > Manage Account sheet > "Doctor Info" section
- **Expected Behavior**: Two text fields:
  - "Full Name" (`Icons.person_rounded`) — editable, prefilled with doctor's current name.
  - "Specialization" (`Icons.medical_services_rounded`) — editable, prefilled with `specialization`/`specialty`.
  Changes are only persisted when "Apply Changes" is tapped.
- **Test Steps**:
  1. In the Manage Account sheet, edit "Full Name" to a new value.
  2. Edit "Specialization" to a new value.
  3. Tap "Apply Changes" and verify a green snackbar `Updated for <new name>!` appears, the sheet closes, and the doctor card now shows the updated name/specialization.
- **Edge Cases / Notes**: Note the doctor header at the top of the sheet does NOT live-update as you type (it reads from the original `nameCtrl.text` captured at sheet open) — verify whether this is expected (header may show stale name while editing).

### Doctors Tab — Manage Account sheet: Account Enabled toggle
- **Platform**: Both
- **Location**: Admin > Doctors > Manage Account sheet > "Account Settings" > "Account Enabled"
- **Expected Behavior**: `Switch.adaptive` titled "Account Enabled" / "Doctor can use the app" (green accent `#2E7D32`, `Icons.power_settings_new_rounded`). Toggling off and applying should mark `is_enabled = false`, which the doctor card reflects as "Disabled" status.
- **Test Steps**:
  1. Open Manage Account sheet for an active doctor.
  2. Toggle "Account Enabled" off, then tap "Apply Changes".
  3. Verify the doctor card now shows a "Disabled" status chip (red-tinted) and `isActive` becomes false.
  4. Re-open the sheet, toggle back on, Apply, and verify the card returns to "Active".
- **Edge Cases / Notes**: Disabling a doctor account here does not delete it — only flips `is_enabled`. Verify the doctor cannot log in (or has limited access) while disabled, if testable.

### Doctors Tab — Manage Account sheet: "Show in Find a Doctor" toggle
- **Platform**: Both
- **Location**: Admin > Doctors > Manage Account sheet > "Account Settings" > "Show in Find a Doctor"
- **Expected Behavior**: `Switch.adaptive` titled "Show in Find a Doctor" / "Visible to patients searching for therapists" (ink color, `Icons.search_rounded`). Controls `show_in_search`.
- **Test Steps**:
  1. For a Premium-tier doctor, toggle "Show in Find a Doctor" on, tap "Apply Changes".
  2. Verify the doctor card shows the "Searchable" chip (only shown for Premium + `show_in_search`).
  3. As a patient, verify the doctor now appears (or doesn't) in patient-side "Find a Doctor" search (cross-reference with patient dashboard if in scope).
  4. Toggle off, Apply, and verify the "Searchable" chip disappears from the card.
- **Edge Cases / Notes**: Switching tier to Basic via the tier chips auto-forces this off (see Subscription Tier item).

### Doctors Tab — Manage Account sheet: Account Expiry Date picker
- **Platform**: Both
- **Location**: Admin > Doctors > Manage Account sheet > "Account Settings" > "Account Expiry Date"
- **Expected Behavior**: A tappable row (`Icons.event_rounded`) showing "Account Expiry Date" and either "No expiry set (tap to choose)" (grey) or the formatted date `D/M/YYYY` (black). Tapping opens a date picker (`showDatePicker`, range: today .. 2035). If a date is set, a clear (`Icons.clear_rounded`) icon appears on the right to remove the expiry.
- **Test Steps**:
  1. In the Manage Account sheet, with no expiry set, verify the row shows "No expiry set (tap to choose)".
  2. Tap the row — verify a date picker opens with `firstDate = today` and `lastDate = 2035`.
  3. Pick a future date and verify the row updates to show `D/M/YYYY` and a clear (X) icon appears.
  4. Tap the clear (X) icon — verify the row reverts to "No expiry set (tap to choose)".
  5. Set a date within 30 days of today, tap "Apply Changes", and verify the doctor card shows "Expires <Mon Year>" in amber.
  6. Set a date in the past (if picker allows, otherwise simulate via DB), Apply, and verify the card shows "Expired <Mon Year>" in red with red border and "Expired" status chip.
- **Edge Cases / Notes**: `firstDate: DateTime.now()` — verify past dates cannot be selected via the picker UI itself.

### Doctors Tab — Manage Account sheet: Dr. Prefix section ("Disable" / "Enable" buttons)
- **Platform**: Both
- **Location**: Admin > Doctors > Manage Account sheet > "Dr. Prefix" section
- **Expected Behavior**: A status box shows current state with icon+text:
  - Enabled: green `Icons.verified_rounded`, "Enabled — \"Dr.\" shown to patients".
  - Pending request: amber `Icons.hourglass_top_rounded`, "Pending doctor request".
  - Declined: grey `Icons.badge_outlined`, "Previously declined".
  - Not requested: grey `Icons.badge_outlined`, "Not enabled".
  Two buttons below: "Disable" (red `OutlinedButton`, enabled only when `drPrefix == true`) and "Enable" (green `ElevatedButton`, enabled only when `drPrefix == false`).
- **Test Steps**:
  1. For a doctor with no Dr. prefix request, verify status shows "Not enabled" and "Enable" button is active (green), "Disable" is disabled (greyed out).
  2. Tap "Enable" — verify it calls `_approveDrPrefix`, the status updates locally to "Enabled — \"Dr.\" shown to patients" (green check icon), "Disable" becomes active and "Enable" becomes disabled, and a green snackbar `"Dr." prefix approved for <name>` appears (snackbar fires from the underlying screen, may appear after sheet still open).
  3. Tap "Disable" — verify it calls `_toggleDrPrefixDirect(false)`, status updates to "Previously declined" (since `drPrefixReq` is set to 'declined'), buttons swap availability again.
  4. For a doctor with a pending request (`dr_prefix_request = 'pending'`), verify status shows amber "Pending doctor request" with hourglass icon.
- **Edge Cases / Notes**: The "Disable"/"Enable" buttons use `disabledBackgroundColor`/translucent border to indicate disabled state — verify visually distinguishable. Note `_toggleDrPrefixDirect` and the Enable/Disable buttons here update the DB immediately (independent of "Apply Changes"), unlike other fields in this sheet — verify this asymmetry is intentional (Dr. Prefix changes apply instantly, other fields require "Apply Changes").

### Doctors Tab — Manage Account sheet: "Apply Changes" button
- **Platform**: Both
- **Location**: Admin > Doctors > Manage Account sheet > bottom "Apply Changes" button
- **Expected Behavior**: Full-width `ElevatedButton.icon` (slate background, `Icons.check_circle_rounded`, label "Apply Changes"). On tap, shows a loading spinner in place of the button while saving, then updates the `users` row (`name`, `specialization`, `subscription`, `features`, `is_enabled`, `show_in_search`, `expires_at`), closes the sheet, and shows a green snackbar `Updated for <name>!`.
- **Test Steps**:
  1. Make one or more changes in the sheet (name, specialization, tier, feature toggles, account enabled, show in search, expiry date).
  2. Tap "Apply Changes".
  3. Verify a loading spinner briefly replaces the button.
  4. Verify the sheet closes and a green snackbar `Updated for <name>!` appears.
  5. Verify the doctor card in the list reflects all changes immediately (live stream).
- **Edge Cases / Notes**: No explicit error handling shown around the `update()` call — verify behavior if the update fails (e.g., network error) — does the sheet still close and show success snackbar regardless?

---

### Polyclinics Tab — Summary card + "New" shortcut
- **Platform**: Both
- **Location**: Admin > Polyclinics (nav index 2)
- **Expected Behavior**: Teal gradient summary card shows total polyclinic count ("`N` Polyclinic(s) Registered") with `Icons.business_rounded`, and a "New" pill button.
- **Test Steps**:
  1. Navigate to Admin > Polyclinics.
  2. Verify the count matches the number of `role = 'polyclinic'` users.
  3. Tap "New" — verify it switches to the Register tab (`_currentIndex = 3`).
- **Edge Cases / Notes**: Tapping "New" here does NOT auto-select the "Polyclinic" toggle on the Register form (it just navigates to index 3; `_isPolyclinic` state is unchanged) — verify whether the admin must manually tap "Polyclinic" on the Register tab after navigating from here.

### Polyclinics Tab — Search field
- **Platform**: Both
- **Location**: Admin > Polyclinics > search box
- **Expected Behavior**: TextField "Search polyclinic name or email..." filters list (case-insensitive) by name or email. Result count label "`N` polyclinic(s)" shown below.
- **Test Steps**:
  1. Type part of a polyclinic's name — verify list filters and count updates.
  2. Type part of an email — verify filtering by email also works.
  3. Search for a nonsense string — verify empty state (see below).
  4. Clear search — verify full list returns.
- **Edge Cases / Notes**: Unlike the Doctors search field, the Polyclinics search field is implemented inline (not via the shared `_searchField()` helper) but behaves identically.

### Polyclinics Tab — Empty state (no polyclinics / no search results)
- **Platform**: Both
- **Location**: Admin > Polyclinics > body (when `filtered.isEmpty`)
- **Expected Behavior**: Centered `Icons.business_outlined` in a teal circle, heading "No polyclinic accounts yet" (if search empty) or `No results for "<query>"`, subtext "Use the Register tab to add a polyclinic." or "Try a different search term."
- **Test Steps**:
  1. With zero polyclinics registered, verify "No polyclinic accounts yet" / "Use the Register tab to add a polyclinic." is shown.
  2. With polyclinics present, search a nonsense string and verify `No results for "<query>"` / "Try a different search term."
- **Edge Cases / Notes**: None additional.

### Polyclinics Tab — Polyclinic card (list item)
- **Platform**: Both
- **Location**: Admin > Polyclinics > polyclinic list (each card)
- **Expected Behavior**: Each card shows avatar (initials), name (bold), email (ellipsized), an Active/Disabled status chip (green/red), and "`N` linked doctor(s)" with `Icons.people_outline_rounded`. Tapping the card opens the Polyclinic Manage Account sheet.
- **Test Steps**:
  1. Navigate to Admin > Polyclinics with at least one polyclinic.
  2. Verify avatar initials/colors, name, email render correctly.
  3. Verify status chip shows "Active" (green, `#E8F5E9`/`#2E7D32`) if `is_enabled` true, else "Disabled" (red, `#FFEBEE`/error color).
  4. Verify "`N` linked doctors" count matches `linked_doctor_ids` length on the polyclinic's user record.
  5. Tap the card — verify the Manage Account sheet opens.
- **Edge Cases / Notes**: Singular/plural — "1 linked doctor" vs "N linked doctors".

### Polyclinics Tab — Polyclinic card overflow menu (⋮)
- **Platform**: Both
- **Location**: Admin > Polyclinics > polyclinic card > `Icons.more_vert_rounded` menu
- **Expected Behavior**: Popup menu with "Manage Account" (`Icons.manage_accounts_rounded`) and "Remove Account" (red `Icons.delete_rounded`). "Manage Account" opens the Manage sheet; "Remove Account" opens the "Remove Polyclinic" confirmation dialog.
- **Test Steps**:
  1. Tap ⋮ on a polyclinic card.
  2. Select "Manage Account" — verify the Manage sheet opens.
  3. Re-open menu, select "Remove Account" — verify the confirmation dialog opens.
- **Edge Cases / Notes**: None additional.

### Polyclinics Tab — "Remove Polyclinic" confirmation dialog
- **Platform**: Both
- **Location**: Admin > Polyclinics > card menu > "Remove Account"
- **Expected Behavior**: `AlertDialog` titled "Remove Polyclinic", red delete icon, body `Remove "<name>" from the system?\nThis action cannot be undone.`, "Cancel"/"Remove" actions. "Remove" calls `AdminService.deleteUserAccount`; success → green snackbar "Polyclinic account removed."; failure → red snackbar "Error: <message>".
- **Test Steps**:
  1. Tap ⋮ > "Remove Account" on a test polyclinic.
  2. Tap "Cancel" — verify dialog closes, polyclinic remains.
  3. Re-open, tap "Remove" — verify dialog closes, green snackbar "Polyclinic account removed." appears, and the polyclinic disappears from the list.
- **Edge Cases / Notes**: Irreversible action — same caveat as doctor deletion. Consider whether linked doctors are orphaned (their `polyclinic_id` may remain stale) when the polyclinic is deleted — worth checking data integrity.

### Polyclinics Tab — Manage Account bottom sheet (Clinic Info / Account Settings)
- **Platform**: Both (modal bottom sheet, scroll-controlled)
- **Location**: Admin > Polyclinics > tap polyclinic card (or ⋮ > Manage Account)
- **Expected Behavior**: Sheet shows drag handle, header (avatar, name, email, "Polyclinic" chip), "Clinic Info" section with an editable "Clinic Name" field (`Icons.business_rounded`), "Account Settings" section with "Account Enabled" / "Polyclinic can use the app" toggle (green, `Icons.power_settings_new_rounded`), and a full-width "Apply Changes" button (teal `#00695C`, `Icons.check_circle_rounded`).
- **Test Steps**:
  1. Open the Manage sheet for a polyclinic.
  2. Verify header shows avatar/initials, current name, email, and "Polyclinic" chip.
  3. Edit "Clinic Name" to a new value.
  4. Toggle "Account Enabled" off.
  5. Tap "Apply Changes" — verify a loading spinner shows briefly, the sheet closes, a green snackbar `Updated for <new name>!` appears, and the polyclinic card reflects the new name and "Disabled" status.
  6. Re-open, toggle "Account Enabled" back on, Apply, and verify the card shows "Active" again.
- **Edge Cases / Notes**: Same as doctor sheet — changes only persist on "Apply Changes".

---

### Register Tab — Type selector (Doctor / Polyclinic toggle)
- **Platform**: Both
- **Location**: Admin > Register (nav index 3) > top of form
- **Expected Behavior**: Two large tappable tiles side by side: "Doctor" (`Icons.person_rounded`) and "Polyclinic" (`Icons.business_rounded`). The selected tile is filled with its accent color (slate for Doctor, `#00695C` teal for Polyclinic) with white icon/text; the unselected tile is white with colored icon/text and border. Selecting changes the form fields shown below and the banner text/icon/accent color.
- **Test Steps**:
  1. Navigate to Admin > Register. Verify "Doctor" is selected by default (slate fill, white icon/text).
  2. Tap "Polyclinic" — verify it becomes selected (teal fill), "Doctor" becomes unselected (white/slate outline), and the banner below changes to "Register New Polyclinic" / "Polyclinic accounts can link doctors and view per-doctor income." with a teal icon container.
  3. Verify the "Specialization" field (visible for Doctor) disappears when "Polyclinic" is selected.
  4. Tap "Doctor" again — verify it reverts: banner shows "Register New Doctor" / "New accounts start on the Basic plan. Upgrade via the Doctors tab.", and the Specialization field reappears.
- **Edge Cases / Notes**: Switching type does not clear already-entered field values (name/email/password persist across the toggle) — verify whether this is desired (e.g., a name typed for "Doctor" carries over if switching to "Polyclinic").

### Register Tab — Doctor registration form
- **Platform**: Both
- **Location**: Admin > Register > "Doctor" selected
- **Expected Behavior**: Form card with:
  - "Personal Info" section: "Doctor Full Name" field (`Icons.badge_rounded`), "Specialization" field (`Icons.medical_services_rounded`).
  - "Login Credentials" section: "Professional Email" field (`Icons.email_rounded`, email keyboard), "Initial Password (min 6 chars)" field (`Icons.lock_rounded`, obscured with a visibility-toggle suffix icon).
  - "Create Doctor Account" button (slate, `Icons.check_circle_rounded`).
  Submitting validates: name non-empty, email non-empty, password length >= 6. On success: green snackbar "Doctor account created!", fields cleared, navigates to Doctors tab (index 1). On failure: red snackbar "Error: <message>".
- **Test Steps**:
  1. With "Doctor" selected, leave all fields empty and tap "Create Doctor Account" — verify a snackbar "Fill all fields. Password must be at least 6 characters." appears and no account is created.
  2. Fill Name and Email but leave Password < 6 chars — verify the same validation snackbar appears.
  3. Fill Name, Specialization, Email, and a 6+ char Password. Toggle the password visibility icon (`Icons.visibility_rounded` / `Icons.visibility_off_rounded`) and verify the password text shows/hides accordingly.
  4. Tap "Create Doctor Account" — verify a loading spinner shows, then a green snackbar "Doctor account created!" appears, all 4 fields are cleared, and the view switches to the Doctors tab (index 1) showing the new doctor.
  5. Attempt to register with an email that already exists — verify a red snackbar "Error: <message>" appears (e.g. "Error: <duplicate email message>") and the form fields are NOT cleared (so the admin can correct and retry).
- **Edge Cases / Notes**: Password field's visibility toggle (`_obscure`) is shared state — verify it doesn't unexpectedly persist/reset when switching between Doctor/Polyclinic types. New doctor accounts start on "Basic" plan per the banner text — verify default tier in the Doctors tab after creation.

### Register Tab — Polyclinic registration form
- **Platform**: Both
- **Location**: Admin > Register > "Polyclinic" selected
- **Expected Behavior**: Form card with:
  - "Clinic Info" section: "Clinic Name" field (`Icons.business_rounded`). (No specialization field for polyclinics.)
  - "Login Credentials" section: "Clinic Email" field (`Icons.email_rounded`, email keyboard), "Initial Password (min 6 chars)" field (obscured, with visibility toggle).
  - "Create Polyclinic Account" button (teal `#00695C`, `Icons.check_circle_rounded`).
  Same validation as doctor form (name/email non-empty, password >= 6 chars). On success: green snackbar "Polyclinic account created!", fields cleared, navigates to Polyclinics tab (index 2). On failure: red snackbar "Error: <message>".
- **Test Steps**:
  1. Select "Polyclinic". Leave fields empty, tap "Create Polyclinic Account" — verify validation snackbar "Fill all fields. Password must be at least 6 characters."
  2. Fill Clinic Name, Clinic Email, and a valid password (6+ chars). Tap "Create Polyclinic Account".
  3. Verify a loading spinner shows, then a green snackbar "Polyclinic account created!" appears, fields clear, and the view switches to Polyclinics tab (index 2) showing the new polyclinic with 0 linked doctors.
  4. Attempt duplicate-email registration — verify red snackbar "Error: <message>" and fields retained.
- **Edge Cases / Notes**: Verify the new polyclinic appears with "Active" status and "0 linked doctors" by default.

---

### Requests Tab — Empty state ("No pending requests")
- **Platform**: Both
- **Location**: Admin > Requests (nav index 4, the `_notificationsTab`)
- **Expected Behavior**: When there are no pending Dr. prefix requests and no pending name-change requests, shows a centered icon (`Icons.notifications_none_rounded` in a primary-colored circle), heading "No pending requests", and subtext "Dr. prefix and name change requests will appear here".
- **Test Steps**:
  1. Ensure no doctors have `dr_prefix_request == 'pending'` or `name_change_request == 'pending'`.
  2. Navigate to Admin > Requests.
  3. Verify the empty-state icon, "No pending requests" heading, and subtext are shown.
- **Edge Cases / Notes**: While the `users` stream is loading, a centered `CircularProgressIndicator` is shown instead.

### Requests Tab — Name Change Request cards (Approve / Decline)
- **Platform**: Both
- **Location**: Admin > Requests > "Name Change Requests" section (shown above "Dr. Prefix Requests" if both exist)
- **Expected Behavior**: Section header "Name Change Requests" (bold, grey, 13px), followed by one card per doctor with `name_change_request == 'pending'`. Each card shows avatar (initials), current name, specialization (if any), an amber "Pending" chip, and text `Requesting name change to "<pendingName>"`. Two buttons: "Decline" (red outlined, `Icons.close_rounded`) and "Approve" (green filled, `Icons.check_rounded`).
  - **Approve**: calls `_approveNameChange` → sets `name = pendingName`, clears `pending_name` and `name_change_request`; shows green snackbar `Name changed to "<newName>" for <oldName>`.
  - **Decline**: calls `_declineNameChange` → clears `pending_name`, sets `name_change_request = 'declined'`; shows snackbar `Name change declined for <name>`.
- **Test Steps**:
  1. As a doctor (separate session/role), submit a name change request so `name_change_request = 'pending'` and `pending_name` is set.
  2. As admin, navigate to Admin > Requests and verify the "Name Change Requests" section header appears, with a card showing the doctor's current name, "Pending" chip, and `Requesting name change to "<new name>"`.
  3. Tap "Decline" — verify the snackbar `Name change declined for <name>` appears and the card disappears from the list (request resolved).
  4. Submit another name-change request, then tap "Approve" — verify the snackbar `Name changed to "<newName>" for <oldName>` (green) appears, the card disappears, and the doctor's displayed name updates across the admin dashboard (e.g. in Doctors tab / Overview) to the new name.
- **Edge Cases / Notes**: If both name-change and Dr.-prefix requests exist for the same doctor, both appear as separate cards (one per section) — verify no duplication/confusion. Section ordering: Name Change Requests header/cards come before Dr. Prefix Requests in the flat list.

### Requests Tab — Dr. Prefix Request cards (Approve / Decline)
- **Platform**: Both
- **Location**: Admin > Requests > "Dr. Prefix Requests" section
- **Expected Behavior**: Section header "Dr. Prefix Requests", followed by one card per doctor with `dr_prefix_request == 'pending'`. Each card shows avatar, name, specialization (if any), amber "Pending" chip, and text "Requesting permission to display \"Dr.\" prefix". Same "Decline"/"Approve" button pair.
  - **Approve**: calls `_approveDrPrefix` → sets `show_dr_prefix = true`, `dr_prefix_request = 'approved'`; green snackbar `"Dr." prefix approved for <name>`.
  - **Decline**: calls `_declineDrPrefix` → sets `show_dr_prefix = false`, `dr_prefix_request = 'declined'`; snackbar `Request declined for <name>`.
- **Test Steps**:
  1. As a doctor, submit a Dr.-prefix request (`dr_prefix_request = 'pending'`).
  2. As admin, navigate to Admin > Requests and verify the "Dr. Prefix Requests" section/card appears with "Requesting permission to display \"Dr.\" prefix" and amber "Pending" chip.
  3. Tap "Approve" — verify green snackbar `"Dr." prefix approved for <name>` appears, the card disappears, and (cross-check) the doctor's profile/displayed name elsewhere shows the "Dr." prefix.
  4. Submit another Dr.-prefix request, tap "Decline" — verify snackbar `Request declined for <name>` appears and the card disappears; re-open Admin > Doctors > that doctor's Manage sheet > Dr. Prefix section and verify it now shows "Previously declined".
- **Edge Cases / Notes**: Approving/declining here is equivalent to using the "Enable"/"Disable" buttons in the doctor's Manage Account sheet — verify both paths keep `show_dr_prefix` / `dr_prefix_request` in sync (no stale state if approved from one place and viewed from the other).

---

## Polyclinic Dashboard

> Platform availability (overall): **Both** — `PolyclinicDashboardScreen` is shown to all `role = 'polyclinic'` users regardless of screen size (`lib/main.dart`, no form-factor gating found). Navigation uses a `BottomNavigationBar` (5 fixed-type items) which is present at all widths — on desktop this results in a bottom tab bar rather than a sidebar; layout otherwise reflows to full width on mobile. Any further differences are called out per-item below.

### Header — Clinic name + Sign Out
- **Platform**: Both
- **Location**: Polyclinic > Header (always visible at top of every tab)
- **Expected Behavior**: Teal gradient header bar with `Icons.business_rounded` icon container, clinic name (bold white, ellipsized if long) and "Polyclinic Dashboard" subtitle (white 65% opacity). Top-right "Sign Out" icon button (`Icons.logout_rounded`) signs out via `Supabase.instance.client.auth.signOut()`.
- **Test Steps**:
  1. Log in as a polyclinic user.
  2. Verify the header shows the clinic's name (from `users.name`, falling back to "Polyclinic" if empty) and "Polyclinic Dashboard" subtitle.
  3. With a very long clinic name, verify it ellipsizes rather than wrapping/overflowing (test at 390px width especially).
  4. Tap the logout icon — verify immediate sign-out and return to Login screen (no confirmation dialog).
- **Edge Cases / Notes**: Header data comes from a `StreamBuilder` on `users` filtered by the clinic's own `id` — verify the name updates live if changed via the Profile tab without requiring a full reload.

### Bottom Nav Bar — 5 tabs (Doctors / Patients / Income / Statistics / Profile)
- **Platform**: Both (a `BottomNavigationBar` — fixed type, 5 items — appears at all screen widths, including desktop)
- **Location**: Polyclinic > bottom navigation bar (always visible)
- **Expected Behavior**: 5 fixed-type bottom nav items in this order:
  1. `Icons.people_rounded` — "Doctors"
  2. `Icons.person_rounded` — "Patients"
  3. `Icons.receipt_long_rounded` — "Income"
  4. `Icons.bar_chart_rounded` — "Statistics"
  5. `Icons.badge_rounded` — "Profile"
  Selected item is teal (`#00695C`); unselected items are grey (`Colors.grey.shade500`). Tapping switches `_tab` and the body (an `IndexedStack`, so each tab's state is preserved across switches).
- **Test Steps**:
  1. On Desktop (~1400px), verify the bottom nav bar renders with all 5 items, icons + labels, no overflow.
  2. Tap each of the 5 items and verify the body content switches to: My Doctors list, My Patients list, Income tab, Statistics tab, Clinic Profile — and the tapped item highlights teal while others are grey.
  3. Resize to 390x844 (mobile) and repeat — verify all 5 items remain visible without truncation/overflow and tapping still works.
  4. Switch to "Doctors" tab, scroll the list, switch to another tab, then switch back to "Doctors" — verify scroll position/state is preserved (because `IndexedStack` keeps tabs alive).
- **Edge Cases / Notes**: Because the nav is a standard bottom bar (not the admin's custom top button-bar), there's no horizontal-scroll concern — confirm 5 items with labels fit at 390px without the "shifting"/animation glitches that `BottomNavigationBarType.fixed` avoids.

---

### Doctors Tab — "Add Doctor" floating action button
- **Platform**: Both (FAB is shown regardless of width; on very narrow screens verify it doesn't overlap content awkwardly)
- **Location**: Polyclinic > Doctors (tab 0) > floating action button, bottom-right
- **Expected Behavior**: `FloatingActionButton.extended`, teal background, white `Icons.person_add_rounded` + "Add Doctor" label (bold). Tapping opens the "Add Doctor to Polyclinic" bottom sheet.
- **Test Steps**:
  1. Navigate to Polyclinic > Doctors tab.
  2. Verify the "Add Doctor" FAB is visible in the bottom-right corner.
  3. Tap it — verify the "Add Doctor to Polyclinic" sheet opens (see next item).
- **Edge Cases / Notes**: FAB remains visible whether the doctors list is empty or populated.

### Doctors Tab — Empty state ("No doctors linked yet")
- **Platform**: Both
- **Location**: Polyclinic > Doctors (tab 0) > body, when `linkedIds.isEmpty`
- **Expected Behavior**: Centered `Icons.people_outline_rounded` (large, light grey), heading "No doctors linked yet", subtext 'Tap "+ Add Doctor" to link a doctor.'
- **Test Steps**:
  1. As a polyclinic with zero linked doctors (`linked_doctor_ids` empty), navigate to Doctors tab.
  2. Verify the empty-state icon, heading, and subtext are shown, with the "Add Doctor" FAB still visible.
- **Edge Cases / Notes**: None additional.

### Doctors Tab — "Add Doctor to Polyclinic" bottom sheet (search + Add)
- **Platform**: Both (modal bottom sheet, `isScrollControlled: true`, fixed height 320 for the list area — verify this fixed height doesn't cause issues on short mobile viewports with keyboard open)
- **Location**: Polyclinic > Doctors tab > "Add Doctor" FAB
- **Expected Behavior**: Sheet with drag handle, title "Add Doctor to Polyclinic", a search TextField (autofocus, "Search doctor name…", `Icons.search_rounded`), and below it a 320px-tall scrollable list of all `role = 'doctor'` users NOT already linked to this polyclinic (`alreadyLinked` excludes them), filtered live by the search query (matches name or email, case-insensitive). Each row shows avatar (initials), name, specialization subtitle (if any), and a teal "Add" button.
  - Tapping "Add" calls `_linkDoctor(doctorUid)` which: adds the doctor's id to the polyclinic's `linked_doctor_ids` array and sets the doctor's `polyclinic_id` to the polyclinic's uid. Then closes the sheet and shows a green snackbar `<name> added to polyclinic`.
  - If no doctors match (or all doctors already linked), shows centered text "No available doctors found."
- **Test Steps**:
  1. Tap "Add Doctor" FAB to open the sheet.
  2. With the search field empty, verify the list shows all unlinked doctors (avatar, name, specialization if present, "Add" button each).
  3. Type part of a doctor's name into the search field — verify the list filters live to matching doctors.
  4. Type part of a doctor's email — verify it also filters by email.
  5. Type a string matching no doctor — verify "No available doctors found." is shown.
  6. Clear the search, tap "Add" next to a doctor — verify the sheet closes, a green snackbar `<name> added to polyclinic` appears, and the Doctors tab list now includes that doctor.
  7. Re-open the "Add Doctor" sheet — verify the just-added doctor no longer appears in the list (since they're now linked).
- **Edge Cases / Notes**: The list query streams ALL doctors (`role = 'doctor'`) and filters client-side — verify performance/UX is acceptable with many doctors. Verify a doctor without a `specialization` shows no subtitle (not an empty line).

### Doctors Tab — Linked doctor card
- **Platform**: Both
- **Location**: Polyclinic > Doctors (tab 0) > linked doctors list
- **Expected Behavior**: Each card shows avatar (initials, colored), doctor's name (falls back to email, then "Doctor"), specialization (if present), and a live patient count "`N` patient(s)" (counted via a `StreamBuilder` over `role = 'patient'` users whose `doctor_ids` contains this doctor's id). A `PopupMenuButton` (⋮, default icon) on the right offers "Remove from Polyclinic" (red, `Icons.link_off_rounded`).
- **Test Steps**:
  1. Navigate to Polyclinic > Doctors with at least one linked doctor.
  2. Verify avatar initials/color, name, specialization (if set) render correctly.
  3. Verify the "`N` patients" count matches the number of patients whose `doctor_ids` includes this doctor.
  4. Tap the ⋮ menu — verify "Remove from Polyclinic" option (red text/icon) appears.
- **Edge Cases / Notes**: If a doctor has neither `name` nor `email`, falls back to literal "Doctor" as display name — verify this edge case doesn't crash.

### Doctors Tab — "Remove from Polyclinic" confirmation + unlink
- **Platform**: Both
- **Location**: Polyclinic > Doctors tab > linked doctor card > ⋮ > "Remove from Polyclinic"
- **Expected Behavior**: Tapping opens an `AlertDialog` titled "Remove Doctor" with body `Remove "<name>" from this polyclinic?`, "Cancel" and red "Remove" buttons. Confirming calls `_unlinkDoctor`, which removes the doctor's id from `linked_doctor_ids` and clears the doctor's `polyclinic_id` (sets to `null`).
- **Test Steps**:
  1. Tap ⋮ > "Remove from Polyclinic" on a linked doctor card.
  2. Tap "Cancel" — verify the dialog closes and the doctor remains linked.
  3. Re-open, tap "Remove" — verify the dialog closes and the doctor disappears from the Doctors tab list (live stream).
  4. Verify that doctor's patients no longer appear under this polyclinic in the Patients tab (since the doctor is unlinked, though patient `doctor_ids` themselves aren't changed — only the polyclinic's `linked_doctor_ids`/doctor's `polyclinic_id`).
  5. Re-add the same doctor via "Add Doctor" to confirm the link/unlink cycle works repeatedly.
- **Edge Cases / Notes**: Unlinking does NOT delete the doctor account — only removes the association. This is non-destructive but still has a confirmation dialog; verify wording is appropriately less severe than the admin's "cannot be undone" dialogs (it doesn't include that phrase here).

---

### Patients Tab — Doctor filter dropdown
- **Platform**: Both
- **Location**: Polyclinic > Patients (tab 1) > top filter bar (navy background)
- **Expected Behavior**: A `DropdownButton` with white text on navy background, default value "All Doctors" (null), plus one entry per linked doctor (showing the doctor's name, or their id if name missing). Selecting a doctor filters the patient list to only that doctor's patients (via `doctor_ids` containment); selecting "All Doctors" shows patients of all linked doctors.
- **Test Steps**:
  1. Navigate to Polyclinic > Patients with multiple linked doctors, each having patients.
  2. Verify the dropdown defaults to "All Doctors" and the list shows patients across all linked doctors.
  3. Open the dropdown — verify it lists "All Doctors" plus each linked doctor by name.
  4. Select a specific doctor — verify the patient list filters to only that doctor's patients.
  5. Select "All Doctors" again — verify the full combined list returns.
- **Edge Cases / Notes**: If `widget.linkedIds.isEmpty`, the entire Patients tab shows "Link doctors first to see their patients." instead of this filter bar — verify that message appears for a polyclinic with zero linked doctors.

### Patients Tab — Search field
- **Platform**: Both
- **Location**: Polyclinic > Patients (tab 1) > top filter bar, next to doctor dropdown
- **Expected Behavior**: TextField "Search…" (white text on translucent white fill, `Icons.search_rounded`). Filters the (already doctor-filtered) patient list live by name or phone (case-insensitive, substring match).
- **Test Steps**:
  1. With patients listed, type part of a patient's name — verify the list filters to matches.
  2. Type part of a patient's phone number — verify it also matches.
  3. Combine with the doctor filter (select a specific doctor, then search) — verify both filters apply together (AND logic).
  4. Search a nonsense string — verify "No patients found." message (centered, secondary text color) is shown.
  5. Clear search — verify the doctor-filtered list returns.
- **Edge Cases / Notes**: Search matches against `phone` field as well as `name` — verify phone-number search works even with partial digits.

### Patients Tab — Patient list item
- **Platform**: Both
- **Location**: Polyclinic > Patients (tab 1) > patient list
- **Expected Behavior**: Each row shows a circular avatar (initials, colored), patient name (falls back to email, then "Patient"), phone (if present, grey), primary diagnosis/condition (if present, secondary color), and on the right, a teal chip showing the assigned doctor's name (fetched via `FutureBuilder` on the first id in `doctor_ids`; shows "Dr." while loading or as fallback).
- **Test Steps**:
  1. Verify each patient row shows correct avatar initials/color, name, phone (if set), and condition (if set).
  2. Verify the doctor-name chip on the right shows the correct doctor's name for each patient.
  3. For a patient with no `doctor_ids`, verify no doctor chip is shown (since `doctorId == null` skips the `FutureBuilder`).
  4. For a patient with neither `name` nor `email` set, verify the row falls back to "Patient" as the display name without crashing.
- **Edge Cases / Notes**: The doctor-name `FutureBuilder` re-fires per build for each row — verify no excessive flicker/loading-state churn when scrolling quickly through a long list.

---

### Income Tab — Period dropdown (Daily/Weekly/Monthly/Yearly)
- **Platform**: Both
- **Location**: Polyclinic > Income (tab 2) > top filter bar (navy background), left dropdown
- **Expected Behavior**: `DropdownButton` (white-on-translucent) with options "Daily", "Weekly", "Monthly", "Yearly" (capitalized from `_period` values `daily/weekly/monthly/yearly`). Changing the period recalculates `_start`/`_end`/`_rangeLabel` and refilters invoices to that date range.
- **Test Steps**:
  1. Navigate to Polyclinic > Income with at least one linked doctor and some invoices.
  2. Verify the dropdown defaults to "Monthly" and the date-range label shows the current month (`MMM d` – `MMM d, yyyy`).
  3. Select "Daily" — verify the range label updates to today's full date (`MMMM d, yyyy`) and the invoice list/summary recalculates for just today.
  4. Select "Weekly" — verify the range label shows a week span (Mon–Sun) and data recalculates.
  5. Select "Yearly" — verify the range label shows just the year (e.g. "2026") and data recalculates for the whole year.
  6. Return to "Monthly".
- **Edge Cases / Notes**: None additional.

### Income Tab — Date navigation (prev/next chevrons)
- **Platform**: Both
- **Location**: Polyclinic > Income (tab 2) > top filter bar, right side (white pill with `<` range label `>`)
- **Expected Behavior**: `Icons.chevron_left_rounded` / `Icons.chevron_right_rounded` step `_refDate` backward/forward by one unit of the selected period (day/week/month/year), updating the range label and refiltering invoices.
- **Test Steps**:
  1. With "Monthly" selected, note the current month label. Tap `<` — verify it moves to the previous month and the invoice list/summary updates to that month's data.
  2. Tap `>` twice — verify it advances two months forward from the previous step (i.e., one month ahead of the original).
  3. Switch to "Weekly" and verify `<`/`>` move by 7-day increments (label shows `MMM d – MMM d, yyyy`).
  4. Switch to "Daily" and verify `<`/`>` move by 1 day.
  5. Switch to "Yearly" and verify `<`/`>` move by 1 year (label shows just the year).
- **Edge Cases / Notes**: No upper/lower bound on date navigation — verify navigating far into the future/past doesn't error, just shows "No income records in this period." if empty.

### Income Tab — Doctor filter dropdown ("All Doctors (Combined)")
- **Platform**: Both
- **Location**: Polyclinic > Income (tab 2) > top filter bar, below period/date row
- **Expected Behavior**: Full-width `DropdownButton` (white-on-translucent, `isExpanded: true`) with "All Doctors (Combined)" (null) as default, plus one entry per doctor where `polyclinic_id == polyclinicUid`. Selecting a doctor filters invoices to only that doctor's; "All Doctors (Combined)" aggregates across all linked doctors.
- **Test Steps**:
  1. Verify the dropdown defaults to "All Doctors (Combined)" and summary cards reflect combined totals across all linked doctors.
  2. Select a specific doctor — verify summary cards (Revenue, Pending, Completed Transactions) and the invoice table recalculate for just that doctor.
  3. Select "All Doctors (Combined)" again — verify totals return to the combined view.
- **Edge Cases / Notes**: This dropdown queries doctors via `polyclinic_id == widget.polyclinicUid` (DB-side), which may differ subtly from the in-memory `linkedIds` list used elsewhere — verify both stay consistent (i.e., a newly linked doctor appears here too without delay).

### Income Tab — Summary cards (Revenue / Pending / Completed Transactions)
- **Platform**: Both
- **Location**: Polyclinic > Income (tab 2) > below filter bar
- **Expected Behavior**: Two side-by-side cards: "Revenue" (green, sum of `paid` + `partially_paid.paid_amount` invoice amounts in the period, labelled "Paid") and "Pending" (amber, sum of `pending`-status invoice amounts, labelled "Awaiting"). Below, a full-width "Completed Transactions" card (navy) showing the count of `paid`-status invoices, labelled "This Period".
- **Test Steps**:
  1. With invoices in various statuses (`paid`, `partially_paid`, `pending`, `cancelled`) within the selected period, verify:
     - "Revenue" = sum of `paid` invoice `amount` + sum of `partially_paid` invoice `paid_amount`.
     - "Pending" = sum of `pending` invoice `amount`.
     - "Completed Transactions" = count of `paid` invoices.
  2. Verify `cancelled` invoices are excluded from all three figures.
  3. Change the period/date range to one with zero invoices — verify all three cards show 0 / USD 0.00.
- **Edge Cases / Notes**: Currency is hardcoded as "USD" in the summary cards regardless of each invoice's actual `currency` field (which is shown per-row in the table) — verify whether this is a known limitation (multi-currency totals would be misleading if invoices use different currencies).

### Income Tab — Per-Doctor Breakdown (progress bars)
- **Platform**: Both
- **Location**: Polyclinic > Income (tab 2) > below summary cards, only when "All Doctors (Combined)" is selected AND more than one linked doctor
- **Expected Behavior**: Card titled "Per-Doctor Breakdown" listing each doctor (by name, fetched via `FutureBuilder`) with their total `paid` revenue (USD) and a teal `LinearProgressIndicator` showing their share of total paid revenue across doctors.
- **Test Steps**:
  1. With "All Doctors (Combined)" selected and 2+ linked doctors having paid invoices, verify the "Per-Doctor Breakdown" card appears with one row per doctor (name + USD amount + proportional progress bar).
  2. Select a specific doctor in the dropdown — verify the breakdown card disappears (only shown for combined view).
  3. With only one linked doctor, verify the breakdown card does not appear even in combined view (`widget.linkedIds.length > 1` condition).
  4. If no `paid` invoices exist in the period, verify the breakdown card doesn't render (returns `SizedBox.shrink()` when `totals.isEmpty`).
- **Edge Cases / Notes**: None additional.

### Income Tab — Invoice table / empty state
- **Platform**: Both (table columns: Patient/Date/Amount/Doctor — on narrow mobile widths, verify the 4-column `Expanded` row layout doesn't truncate text awkwardly)
- **Location**: Polyclinic > Income (tab 2) > below summary/breakdown
- **Expected Behavior**: If no invoices match the period/filter, shows centered text "No income records in this period." in a white card. Otherwise, shows a `Card` with a navy header row (Patient / Date / Amount / Doctor columns, flex 3/2/2/2) and a list of invoice rows (alternating white/`#F8FAFF` background), each showing patient name (or "—"), formatted date (`MM/dd/yy`, or "—" if missing), amount with currency (color-coded: green if `paid`, red if `cancelled`, amber otherwise), and the assigned doctor's name (via `FutureBuilder`, fallback "—"/"Dr.").
- **Test Steps**:
  1. With invoices present, verify the table header shows "Patient", "Date", "Amount", "Doctor" columns in navy with white bold text.
  2. Verify rows alternate white/light-blue background.
  3. Verify a `paid` invoice's amount is green, `cancelled` is red, and `pending`/`partially_paid` is amber.
  4. Verify the date column shows `MM/DD/YY` format, or "—" if `invoice_date`/`created_at` are both missing.
  5. Verify the "Doctor" column resolves to the correct doctor name per invoice.
  6. Change the period to one with zero invoices — verify the "No income records in this period." message replaces the table.
- **Edge Cases / Notes**: Invoices are sorted descending by `invoice_date` (falling back to `created_at`); invoices with neither date field default to year 2000 for sort purposes, so they sink to the bottom — verify such invoices don't visually jump to the top.

---

### Statistics Tab — Period dropdown (Daily/Weekly/Monthly/Yearly)
- **Platform**: Both
- **Location**: Polyclinic > Statistics (tab 3) > top filter bar (navy), left dropdown
- **Expected Behavior**: Same as Income tab's period dropdown — "Daily"/"Weekly"/"Monthly"/"Yearly" options, recalculates `_start`/`_end`/`_rangeLabel` for filtering appointments.
- **Test Steps**:
  1. Navigate to Polyclinic > Statistics with linked doctors having appointments.
  2. Verify default "Monthly" and range label (`MMM d – MMM d` format, slightly different from Income tab's label which includes year for non-yearly periods — verify this difference is intentional/acceptable).
  3. Switch through Daily/Weekly/Yearly and verify the range label and "Total Appointments" count update accordingly.
- **Edge Cases / Notes**: If `widget.linkedIds.isEmpty`, the whole tab shows "Link doctors first to view statistics." instead — verify for a polyclinic with zero linked doctors.

### Statistics Tab — Date navigation (prev/next chevrons)
- **Platform**: Both
- **Location**: Polyclinic > Statistics (tab 3) > top filter bar, right side
- **Expected Behavior**: Same prev/next chevron behavior as Income tab, stepping `_refDate` by the selected period unit and refiltering the appointments stream.
- **Test Steps**:
  1. With "Monthly" selected, tap `<` and `>` and verify the "Total Appointments" count and per-doctor breakdown update for the new date range.
  2. Repeat for "Weekly", "Daily", "Yearly" periods.
- **Edge Cases / Notes**: None additional — mirrors Income tab's date nav behavior but operates on the `appointments` table filtered by `appointment_time` instead of invoices.

### Statistics Tab — Total Appointments card
- **Platform**: Both
- **Location**: Polyclinic > Statistics (tab 3) > below filter bar
- **Expected Behavior**: Full-width blue (`#1565C0`) card with `Icons.calendar_today_rounded`, large bold total appointment count, and "Total Appointments" subtitle. Count = number of appointments across all linked doctors whose `appointment_time` falls within `_start`..`_end`.
- **Test Steps**:
  1. Verify the displayed total matches the sum of appointments (for all linked doctors) within the current period.
  2. Change the period/date range and verify the total updates accordingly.
  3. Navigate to a period with zero appointments — verify the card shows "0".
- **Edge Cases / Notes**: Appointments with a missing/unparseable `appointment_time` are excluded entirely from the count.

### Statistics Tab — Per-Doctor Appointments breakdown / empty state
- **Platform**: Both
- **Location**: Polyclinic > Statistics (tab 3) > below Total Appointments card
- **Expected Behavior**: If there are appointments in the period, shows a card "Per-Doctor Appointments" listing each doctor (name via `FutureBuilder`) with "`N` session(s)" and a blue `LinearProgressIndicator` showing their share of the total. If zero appointments in the period, shows a white card with centered text "No appointments in this period."
- **Test Steps**:
  1. With appointments present for 2+ doctors in the period, verify each doctor appears with correct session count and proportional progress bar (sums to 100% of total).
  2. Navigate to a period with zero appointments and verify "No appointments in this period." is shown instead of the breakdown card.
  3. Verify singular/plural wording: "1 session" vs "N sessions".
- **Edge Cases / Notes**: Doctor names resolved via per-entry `FutureBuilder` (one query per doctor) — verify no excessive flicker on period changes with many doctors.

---

### Profile Tab — Clinic Profile form (Clinic Name / Email / Save)
- **Platform**: Both
- **Location**: Polyclinic > Profile (tab 4)
- **Expected Behavior**: Heading "Clinic Profile" (bold, 18px), then a white card with:
  - "Clinic Name" field (`Icons.business_rounded`, teal) — editable, prefilled with current name.
  - "Email" field (`Icons.email_rounded`, teal) — read-only, greyed out (`#F5F5F5` fill), shows the account's email as a hint.
  - "Save Changes" button (teal, `Icons.save_rounded`, full width).
  Tapping "Save Changes" shows a loading spinner, updates `users.name` for the polyclinic's own `id`, then shows a green snackbar "Profile updated".
- **Test Steps**:
  1. Navigate to Polyclinic > Profile.
  2. Verify "Clinic Name" shows the current clinic name and "Email" shows the account email (read-only, non-editable — attempt to tap/type and confirm no input is accepted).
  3. Edit "Clinic Name" to a new value.
  4. Tap "Save Changes" — verify a loading spinner briefly appears in place of the button, then a green snackbar "Profile updated" is shown.
  5. Verify the header (top of screen) updates to show the new clinic name (live via the outer `StreamBuilder`).
  6. Navigate away and back to Profile — verify the new name persists (re-fetched from DB).
- **Edge Cases / Notes**: The email field uses `hintText` (not `controller`/`initialValue`) to display the email — verify this renders correctly as static display text rather than a placeholder that disappears on focus (since the field is `readOnly`, hint should persist). No validation on empty "Clinic Name" before save — verify behavior if the admin clears the name entirely and saves (does it save an empty string?).

---

## 8. Physiogate Store — Mobile / Responsive Verification

- **Platform**: Both (layout switches at `kMobileBreakpoint = 600` — `lib/core/constants/breakpoints.dart`)
- **How to test**: Chrome DevTools device toolbar — iPhone SE (375 px), iPhone 14 Pro Max (414 px), and drag the window to exactly 600 px for the desktop-regression check.
- **Rule**: Desktop layout (≥ 600 px) must be unchanged after every fix.

---

### 8.1 Doctor Storefront — Category Grid (root)

- **File**: `lib/features/store/doctor_storefront_screen.dart` — `_buildRootGrid` / `_buildCategoryCardMobile`
- **Status**: [x] DONE (commit `d7e912d`)
- **Test Steps**:
  - **At 375 px and 414 px (mobile):**
    - [ ] Categories render as a single-column vertical list (no multi-column grid)
    - [ ] Each card is full-width: teal icon circle on the left, category name expanded in the middle, grey chevron on the right
    - [ ] Long category names are truncated with ellipsis (single line) — no overflow
    - [ ] Tapping a card navigates into that category (subcategories / products)
    - [ ] Section header ("Physiogate Catalog / Browse our product categories") is visible and not clipped
  - **At 600 px (desktop regression):**
    - [ ] Grid layout returns — auto-wrap cards of max 150 px wide, multiple columns
    - [ ] Cards use the compact vertical style (icon above name, no chevron)

---

### 8.2 Doctor Storefront — Product List (category content)

- **File**: `lib/features/store/doctor_storefront_screen.dart` — `_buildProductTile` / `_buildSubcatTile`
- **Status**: [x] VERIFIED — no layout changes needed (audit confirmed acceptable at 375 px)
- **Test Steps**:
  - **At 375 px and 414 px (mobile):**
    - [ ] Each product tile: 56 px thumbnail on left, name + price pill in middle, chevron on right — all visible
    - [ ] Long product names wrap to at most 2 lines, do not push the price pill or chevron off-screen
    - [ ] Price pill ("USD 99.99") is fully readable beside or below the truncated name
    - [ ] Subcategory tiles (icon + name + chevron) are readable and tappable
    - [ ] Back navigation bar (breadcrumb + back arrow) fits within the screen width
  - **At 600 px (desktop regression):**
    - [ ] Layout identical to 375 px (tiles are single-column on all widths — no layout switch here)

---

### 8.3 Doctor Storefront — Product Detail

- **File**: `lib/features/store/doctor_storefront_screen.dart` — `_buildProductDetail`
- **Status**: [x] VERIFIED — no layout changes needed (audit confirmed acceptable at 375 px)
- **Test Steps**:
  - **At 375 px and 414 px (mobile):**
    - [ ] Image carousel (240 px tall) fills the full screen width — no horizontal overflow
    - [ ] Title + price pill row: title wraps gracefully, price pill stays on the right and is fully visible even for long price strings (e.g. "LBP 1,500,000")
    - [ ] Description text wraps normally — no clipping
    - [ ] Phone and WhatsApp contact buttons are full-width and reachable (no horizontal scrolling needed)
    - [ ] Lightbox opens full-screen when the expand icon is tapped; swipe between images works; close button is reachable
    - [ ] Dot indicators at the bottom of the carousel are visible and not clipped
  - **At 600 px (desktop regression):**
    - [ ] All of the above hold unchanged

---

### 8.4 Store Manager — Categories List

- **File**: `lib/features/store/store_manager_categories_screen.dart` — `_buildCatRow`
- **Status**: [x] DONE (commit `6b88913`)
- **Test Steps**:
  - **At 375 px and 414 px (mobile):**
    - [ ] Each category row: icon circle on the left, name + status chip visible in the middle, a single ⋮ menu button on the right
    - [ ] Tapping ⋮ opens a popup menu with "Publish/Unpublish", "Edit", "Delete"
    - [ ] If the category has subcategories, an expand/collapse arrow appears alongside the ⋮ menu
    - [ ] Long category names do not push the ⋮ button off-screen
    - [ ] Expanded subcategory rows (indented 16 px) still fit within the screen — name and ⋮ both visible
    - [ ] Status chip ("Published" / "Draft") is readable in the subtitle row (does not overflow)
  - **At 600 px (desktop regression):**
    - [ ] Inline buttons return: publish/unpublish text button + edit icon + delete icon (+ expand icon if applicable)
    - [ ] No ⋮ popup menu visible on desktop

---

### 8.5 Store Manager — Add / Edit Category Dialog

- **File**: `lib/features/store/store_manager_categories_screen.dart` — `_CategoryFormDialogState.build`
- **Status**: [x] DONE (commit `6b88913`)
- **Test Steps**:
  - **At 375 px and 414 px (mobile):**
    - [ ] Dialog fills nearly the full screen width (only 8 px inset on each side)
    - [ ] "Name", "Parent category" dropdown, and "Sort order" fields are fully visible and editable
    - [ ] "Cancel" and "Save"/"Create" buttons are both reachable without scrolling
    - [ ] No horizontal overflow or clipping of any field
  - **At 600 px (desktop regression):**
    - [ ] Dialog reverts to 380 px fixed width, centred with 40 px horizontal inset
    - [ ] Appearance identical to pre-change behaviour

---

### 8.6 Store Manager — Products List

- **File**: `lib/features/store/store_manager_products_screen.dart` — `_buildProductCard`
- **Status**: [x] DONE (commit `a8d93de`)
- **Test Steps**:
  - **At 375 px and 414 px (mobile):**
    - [ ] Each product row: thumbnail on the left, title + category + price in the middle, a single ⋮ menu button on the right
    - [ ] Tapping ⋮ opens a popup with "Publish/Unpublish", "Edit", "Delete"
    - [ ] Orange draft-warning row ("Category is draft — hidden from doctors") wraps correctly if visible
    - [ ] Long product names do not push the ⋮ button off-screen
  - **At 600 px (desktop regression):**
    - [ ] Inline buttons return: publish text button + edit icon + delete icon
    - [ ] No ⋮ popup menu visible on desktop

---

### 8.7 Store Manager — Add / Edit Product Dialog

- **File**: `lib/features/store/store_manager_products_screen.dart` — `_ProductFormDialogState.build`
- **Status**: [x] DONE (commit `a8d93de`)
- **Test Steps**:
  - **At 375 px and 414 px (mobile):**
    - [ ] Dialog fills nearly the full screen width (only 8 px inset on each side)
    - [ ] All fields are visible: images, category dropdown, title, description, price, currency, phone, WhatsApp, sort order
    - [ ] Price field and currency dropdown are stacked vertically (price above, currency below) — no side-by-side row
    - [ ] "Cancel" and "Create Product"/"Save Changes" buttons are reachable by scrolling to the bottom
    - [ ] Image chip picker ("Add image" / "Add another") wraps correctly — chips do not overflow horizontally
    - [ ] No horizontal overflow or field clipping
  - **At 600 px (desktop regression):**
    - [ ] Dialog reverts to 440 px fixed width, centred with 40 px horizontal inset
    - [ ] Price and currency fields are side-by-side (Expanded price + 120 px currency dropdown)
    - [ ] Appearance identical to pre-change behaviour
