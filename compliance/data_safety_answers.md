# Data Safety / App Privacy — Reference Answers

> **How to use this file:**
> - **Google Play:** Log in to Play Console → App content → Data safety.
>   Answer each question using the tables below.
> - **App Store:** Log in to App Store Connect → your app → App Privacy.
>   Use the Apple section below.
>
> Every answer here is derived directly from code review of the
> PhysioConnect source as of 2026-06-25.  If a feature changes, this
> file must be updated and the store declarations re-submitted.
>
> Items marked **⚠ VERIFY** require confirmation outside the source code.

---

## PART 1 — Google Play Data Safety Form

### Preliminary questions

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — all traffic goes via HTTPS (Supabase REST/Realtime, Groq API, Firebase FCM) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — in-app "Delete Account" button in Profile tab; also by email |

---

### Data types — collected and shared

For each row below: **Collected** = sent off the device to our servers or
third parties.  **Shared** = sent to a third party (Groq, Firebase, etc.).

---

#### Personal info

| Data type | Collected | Shared | Shared with | Linked to identity | Required/Optional | Purpose |
|---|---|---|---|---|---|---|
| **Name** | Yes | Yes (partial) | Groq — in SOAP/History AI features only, as patient first name | Linked | Required | App functionality (account, clinical docs) |
| **Email address** | Yes | No | — | Linked | Required | Account management, authentication |
| **Phone number** | Yes | No | — | Linked | Optional (patients only) | App functionality (patient contact info) |
| **Other personal info — Date of birth** | Yes | No | — | Linked | Optional (patients only) | App functionality (clinical context) |

---

#### Health and fitness  ← **Critical — mark as shared with third party**

| Data type | Collected | Shared | Shared with | Linked to identity | Required/Optional | Purpose |
|---|---|---|---|---|---|---|
| **Health info** (diagnosis, clinical notes, SOAP content, appointment history, HEP exercise assignments) | Yes | Yes | Groq — SOAP Documentation sends therapist notes + patient name/age/diagnosis; Patient History Summary sends slimmed note summaries | Linked | Required for clinical functionality | App functionality (clinical documentation) |
| **Fitness info** (home exercise programme sets/reps/frequency) | Yes | No | — | Linked | Optional | App functionality (HEP management) |

> **Form note for Health info:** When filling the "shared" sub-form, select:
> - Third party: **Groq, Inc.**
> - Purpose: **App functionality**
> - Describe the data: "Patient first name, age, primary diagnosis (optional),
>   and therapist-authored session notes (up to 2,500 chars) sent to Groq's
>   API to generate SOAP documentation.  Separately, patient first name and
>   slimmed clinical note summaries (date, chief complaint ≤200 chars,
>   interventions ≤200 chars, progress ≤150 chars) for history summarisation."
> - ⚠ VERIFY: Groq does not use this data for advertising or tracking.
>   Confirm on Groq's Data Processing Agreement / ToS.

---

#### Financial info

| Data type | Collected | Shared | Shared with | Linked to identity | Required/Optional | Purpose |
|---|---|---|---|---|---|---|
| **Other financial info** (invoice amounts, dates, status; expense records) | Yes | Yes (aggregated) | Groq — Revenue/Expense Analysis sends up to 50 records with date, amount, status (no patient names).  Financial Chat may send up to 20 invoice records including the `patient_name` text field when the AI uses the invoice-lookup tool. | Linked (to doctor account) | Optional (billing feature) | App functionality (financial management) |

---

#### Location

| Data type | Collected | Shared | Shared with | Linked to identity | Required/Optional | Purpose |
|---|---|---|---|---|---|---|
| **Precise location** | Yes | No | — | Linked (to doctor account) | Optional (doctors — clinic pin, find-therapist GPS) | App functionality (doctor discovery, clinic address) |

> **Form note:** Location is collected only for doctor accounts setting
> their clinic coordinates, and optionally for patients using the
> "Find Nearby Therapist" filter.  It is stored in Supabase.  Not used
> for advertising.

---

#### Photos and videos

| Data type | Collected | Shared | Shared with | Linked to identity | Required/Optional | Purpose |
|---|---|---|---|---|---|---|
| **Photos** | Yes | No | — | Linked | Optional | Profile photos (all roles); clinical note attachments (doctors) |

> **Source:** `image_picker` with `ImageSource.gallery` — **camera is not
> used**.  Photos are uploaded to Supabase Storage via HTTPS.

---

#### Messages

| Data type | Collected | Shared | Shared with | Linked to identity | Required/Optional | Purpose |
|---|---|---|---|---|---|---|
| **Other in-app messages** (chat between doctor and patient) | Yes | No | — | Linked | Optional | App functionality (doctor–patient communication) |

---

#### Device or other IDs

| Data type | Collected | Shared | Shared with | Linked to identity | Required/Optional | Purpose |
|---|---|---|---|---|---|---|
| **Device or other IDs** (Firebase FCM token) | Yes | Yes | Firebase / Google — FCM token is sent to Firebase's servers to deliver push notification payloads | Linked | Optional (opt-in: user grants notification permission) | App functionality (appointment reminders) |

> **Notification payload sent to Firebase:** title ("Session Reminder"),
> body ("Your session is starting at {time}"), and appointment UUID.
> No patient medical data or personal identifiers beyond the FCM token.
>
> **R-2 rationale note (for reviewer questions):** The
> `RECEIVE_BOOT_COMPLETED` Android permission is used by
> `flutter_local_notifications` to reschedule appointment reminders
> after device reboot.  It is not used for data collection.

---

#### Data types NOT collected

The following Play Store data types are **not collected** by PhysioConnect:

- User IDs (beyond internal Supabase UUID — not exposed to users)
- Address / physical address (clinic address is stored as a text string for display, not as a structured postal address data type)
- Race, ethnicity, political views, religious beliefs, sexual orientation
- Audio files, video files
- Files and documents (PDFs generated are created locally and saved to device storage — not uploaded to our servers)
- Calendar events
- Contacts
- Web browsing history, search history
- Installed apps
- Crash logs / diagnostics (no crash reporting SDK — errors are caught in-app)

---

### Security practices (Play Store)

| Question | Answer |
|---|---|
| Is data encrypted in transit? | **Yes** — HTTPS/TLS for all server communication |
| Do you follow the Families Policy? | **No** — app is not directed at children |
| Does the app contain ads? | **No** |
| Does the app use data for tracking? | **No** |

---

## PART 2 — Apple App Store App Privacy (Nutrition Label)

Navigate to: App Store Connect → Your app → App Privacy → Get Started

### Preliminary

| Question | Answer |
|---|---|
| Does your app collect data from users? | **Yes** |
| Is any of this data used to track users across other companies' apps or websites? | **No** |

---

### Data types collected

For each type, Apple asks: (a) **Linked to identity** or (b) **Not linked**.
If linked, it appears in the "Data Linked to You" section of the label.
If not linked, it appears in "Data Not Linked to You."

All PhysioConnect data is linked to the user's account (Supabase UUID).

---

#### Contact Info → Name
- **Collected:** Yes
- **Linked to identity:** Yes
- **Used for:** App Functionality
- **Shared with third parties:** Yes — Groq (patient first name in SOAP/History AI features)

#### Contact Info → Email Address
- **Collected:** Yes
- **Linked to identity:** Yes
- **Used for:** App Functionality, Account Management
- **Shared with third parties:** No

#### Contact Info → Phone Number
- **Collected:** Yes (optional, patients only)
- **Linked to identity:** Yes
- **Used for:** App Functionality
- **Shared with third parties:** No

#### Health & Fitness → Health
- **Collected:** Yes
- **Linked to identity:** Yes
- **Used for:** App Functionality
- **Shared with third parties:** **Yes — Groq**
  - Exact data: patient name, age, diagnosis, therapist session notes (SOAP feature); slimmed SOAP note summaries (History Summary feature)
  - Purpose declared to Apple: App Functionality
  - ⚠ **This must appear in the "Data Linked to You — Health" row AND show the third-party sharing disclosure.**

#### Health & Fitness → Fitness
- **Collected:** Yes (HEP exercise programmes: sets, reps, hold time, frequency)
- **Linked to identity:** Yes
- **Used for:** App Functionality
- **Shared with third parties:** No

#### Financial Info → Other Financial Info
- **Collected:** Yes (invoices, expenses)
- **Linked to identity:** Yes (to doctor account)
- **Used for:** App Functionality
- **Shared with third parties:** Yes — Groq (aggregated/slimmed financial data for AI analysis; Financial Chat may include `patient_name` from invoice records)

#### Location → Precise Location
- **Collected:** Yes (doctors only, opt-in)
- **Linked to identity:** Yes
- **Used for:** App Functionality
- **Shared with third parties:** No

#### User Content → Photos or Videos
- **Collected:** Yes (profile photos, clinical note photos)
- **Linked to identity:** Yes
- **Used for:** App Functionality
- **Shared with third parties:** No

#### User Content → Other User Content (chat messages)
- **Collected:** Yes
- **Linked to identity:** Yes
- **Used for:** App Functionality
- **Shared with third parties:** No

#### Identifiers → Device ID (FCM token)
- **Collected:** Yes (optional, when user grants notification permission)
- **Linked to identity:** Yes
- **Used for:** App Functionality (appointment reminders)
- **Shared with third parties:** Yes — Firebase / Google (FCM delivery only; payload: notification title/body + appointment UUID, no medical data)

#### Other Data → Other Data (date of birth)
- **Collected:** Yes (optional, patients only)
- **Linked to identity:** Yes
- **Used for:** App Functionality
- **Shared with third parties:** No

---

### Data NOT collected (Apple "None of the above" checkboxes)

Select "not collected" for:
- Browsing History, Search History
- Sensitive Info (race, religion, sexual orientation, etc.)
- Contacts
- Purchases (the app does not process in-app purchases or payments)
- Usage Data / Diagnostics (no analytics SDK, no crash reporting SDK)
- Audio Data
- Gameplay Content, Customer Support

---

## PART 3 — Cross-reference: AI data flow summary

> This table summarises the W-6 finding from the compliance audit.
> Use it to cross-check both store declarations above.

| Data type | Collected in app | Stored in Supabase | Transmitted to Groq | Transmitted to Firebase |
|---|---|---|---|---|
| Patient first name | Yes | Yes | **Yes** (SOAP, History) | No |
| Patient age | Yes | Yes | **Yes** (SOAP, optional) | No |
| Primary diagnosis | Yes | Yes | **Yes** (SOAP, optional) | No |
| Therapist session notes (free text) | At AI invocation | No (not stored; typed by therapist) | **Yes** (SOAP) | No |
| Historical SOAP summaries (slimmed) | No (derived at AI invocation) | Stored in `clinical_notes` | **Yes** (History, slimmed) | No |
| Patient_name in invoices | Yes | Yes | **Yes** (Financial Chat `getRevenueRecords` tool) | No |
| Aggregated financial totals | Derived in-app | Stored in `invoices`/`expenses` | **Yes** (Revenue/Expense/Analytics) | No |
| FCM device token | Yes | Yes (`users.fcm_token`) | No | **Yes** (for push delivery) |
| Email, phone, DOB | Yes | Yes | **No** | No |
| Location (lat/lng) | Yes (doctors) | Yes | **No** | No |
| Profile photos | Yes | Supabase Storage | **No** | No |
| Chat messages | Yes | Yes | **No** | No |
