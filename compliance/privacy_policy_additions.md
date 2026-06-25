# Privacy Policy — Ready-to-Paste Additions

> **Instructions:** Paste each section below into your
> `physioconnect-privacy` GitHub Pages site in the indicated position.
> The HTML variant is for a plain `index.html`; the Markdown variant is
> for a Jekyll / GitHub Pages `.md` file.  Both contain identical
> content — choose one per section.
>
> Items marked **⚠ VERIFY BEFORE PUBLISHING** require you to confirm a
> fact (usually a third-party terms-of-service provision) that cannot
> be verified from the app source code alone.

---

## SECTION A — Lebanese Law No. 81/2018 (lawful basis + data subject rights)

Place this near the top of the policy, after the introduction paragraph.

### HTML version

```html
<section id="legal-basis">
  <h2>Legal Basis and Applicable Law</h2>
  <p>
    PhysioConnect is operated in compliance with
    <strong>Lebanese Law No. 81/2018 on the Protection of Personal Data</strong>
    (<em>Qanun Himayat al-Bayanat al-Shakhsiyya</em>) and, where
    applicable, other data-protection regulations that govern our users'
    jurisdictions.
  </p>

  <h3>Data Controller</h3>
  <p>
    The data controller responsible for your personal information is
    <strong>PhysioConnect</strong> (operated by <em>[your full legal name
    or company name]</em>, Lebanon).  Contact:
    <a href="mailto:jihadzhour@gmail.com">jihadzhour@gmail.com</a>.
  </p>

  <h3>Lawful Basis for Processing</h3>
  <ul>
    <li>
      <strong>Contract performance</strong> — processing your name,
      contact details, and appointment information is necessary to
      provide the physiotherapy management service you have subscribed to.
    </li>
    <li>
      <strong>Legitimate interests</strong> — improving clinical
      documentation quality and clinic operational efficiency, subject to
      not overriding your fundamental rights.
    </li>
    <li>
      <strong>Legal obligation</strong> — retaining financial records
      (invoices) in anonymised form as required by applicable accounting
      and tax law.
    </li>
    <li>
      <strong>Consent</strong> — sending push notifications and using
      location data to show nearby therapists, where you have granted
      explicit device-level permission.
    </li>
  </ul>

  <h3>Your Rights Under Lebanese Law No. 81/2018</h3>
  <p>You have the right to:</p>
  <ul>
    <li><strong>Access</strong> — request a copy of the personal data we hold about you.</li>
    <li><strong>Rectification</strong> — correct inaccurate or incomplete data.</li>
    <li><strong>Erasure</strong> — request deletion of your account and associated personal data (see <em>Account Deletion</em> below).</li>
    <li><strong>Objection</strong> — object to processing based on legitimate interests.</li>
    <li><strong>Portability</strong> — receive your data in a machine-readable format where technically feasible.</li>
  </ul>
  <p>
    To exercise any of these rights, contact us at
    <a href="mailto:jihadzhour@gmail.com">jihadzhour@gmail.com</a>.
    We will respond within 30 days.
  </p>
</section>
```

### Markdown version (Jekyll)

```markdown
## Legal Basis and Applicable Law

PhysioConnect complies with **Lebanese Law No. 81/2018 on the Protection
of Personal Data** and, where applicable, data-protection laws in our
users' jurisdictions.

### Data Controller

**PhysioConnect** — operated by *[your full legal name or company name]*,
Lebanon.  
Contact: [jihadzhour@gmail.com](mailto:jihadzhour@gmail.com)

### Lawful Basis for Processing

| Processing activity | Lawful basis |
|---|---|
| Account management, appointment scheduling | Contract performance |
| AI-assisted clinical documentation | Legitimate interests |
| Financial record retention (invoices) | Legal obligation |
| Push notifications, location for nearby therapist search | Consent |

### Your Rights Under Lebanese Law No. 81/2018

You have the right to access, rectify, erase, object to, and receive a
portable copy of your personal data.  Send requests to
[jihadzhour@gmail.com](mailto:jihadzhour@gmail.com); we respond within
30 days.
```

---

## SECTION B — AI Doctor Assistant Disclosure

Place this in a dedicated "Third-Party Services" or "How We Use Your Data"
section.  This is the most important compliance clause — Apple and Google
both inspect it.

### HTML version

```html
<section id="ai-assistant">
  <h2>AI Doctor Assistant — Third-Party Data Processing</h2>

  <p>
    PhysioConnect includes an optional <strong>AI Doctor Assistant</strong>
    that helps licensed physiotherapists generate SOAP documentation
    summaries and analyse clinic performance.  This feature is
    <strong>never triggered automatically</strong> — it runs only when a
    therapist explicitly clicks an "AI" button within the app.
  </p>

  <h3>What Data Is Sent — and to Whom</h3>
  <p>
    When the AI Doctor Assistant is used, a subset of session data is
    transmitted to <strong>Groq, Inc.</strong>, a US-based artificial
    intelligence infrastructure provider
    (<a href="https://groq.com" target="_blank" rel="noopener">groq.com</a>),
    via a secure Supabase Edge Function.  The exact fields sent depend on
    which AI feature is invoked:
  </p>

  <table>
    <thead>
      <tr>
        <th>Feature</th>
        <th>Fields sent to Groq</th>
        <th>Fields NOT sent</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>SOAP Documentation</strong><br>(therapist types free-text notes; AI organises them)</td>
        <td>
          Patient first name; patient age (optional); primary diagnosis
          (optional); therapist's free-text session notes (up to 2,500
          characters); session date (optional)
        </td>
        <td>
          Patient UUID, email, phone, date of birth, address, location,
          stored clinical records, profile photo
        </td>
      </tr>
      <tr>
        <td><strong>Patient History Summary</strong><br>(AI summarises up to 8 recent sessions)</td>
        <td>
          Patient first name; total session count; up to 8 most recent
          note summaries, each slimmed to: date, chief complaint (≤200
          chars), interventions (≤200 chars), progress notes (≤150 chars)
        </td>
        <td>
          Full SOAP note text, patient UUID, email, phone, date of birth,
          location, profile photo
        </td>
      </tr>
      <tr>
        <td><strong>Revenue &amp; Expense Analysis</strong></td>
        <td>
          Date range; currency; up to 50 invoice records with: date,
          amount, status only (no patient names or patient IDs)
        </td>
        <td>All patient identifiers</td>
      </tr>
      <tr>
        <td><strong>Financial AI Chat</strong></td>
        <td>
          Pre-aggregated monthly totals (amounts, counts — no patient
          names); when the AI uses the "get invoice records" tool: up to
          20 invoice records including the de-normalised
          <em>patient_name</em> text field, service description, amount,
          and status
        </td>
        <td>Patient UUIDs, email, phone, date of birth, medical data</td>
      </tr>
      <tr>
        <td><strong>Clinic Business Analytics</strong></td>
        <td>
          Aggregated totals only: revenue/expense totals, session counts,
          therapist-level counts — no individual patient names or IDs
        </td>
        <td>All patient identifiers and clinical data</td>
      </tr>
    </tbody>
  </table>

  <h3>Purpose and Restrictions</h3>
  <p>
    Data transmitted to Groq is used <strong>solely</strong> to generate
    the AI response returned to the therapist in real time.  It is not
    used for any other purpose by PhysioConnect or Groq.
  </p>

  <!-- ⚠ VERIFY BEFORE PUBLISHING:
       Confirm the following statement against the current version of
       Groq's API Terms of Service at https://groq.com/terms-of-service/
       The statement was accurate as of the app's last compliance review
       but third-party terms may change.
  -->
  <p>
    <strong>Model training:</strong> Groq's API Terms of Service state
    that customer data submitted through the Groq API is not used to
    train or improve Groq's AI models.
    <em>(Verify against current Groq ToS before publishing.)</em>
  </p>

  <h3>Data Location</h3>
  <p>
    Groq operates infrastructure in the United States.  By using the AI
    Doctor Assistant, you acknowledge that the data fields listed above
    will be transferred to and processed in the US.  This transfer is
    made under the terms of our Data Processing Agreement with Groq
    and in accordance with applicable data-protection law.
  </p>
</section>
```

### Markdown version (Jekyll)

```markdown
## AI Doctor Assistant — Third-Party Data Processing

PhysioConnect's optional **AI Doctor Assistant** runs only on explicit
therapist action (never automatically).  It transmits a minimal subset of
session data to **Groq, Inc.** (US), via a secure Supabase Edge Function,
solely to generate the AI response.

### Exact fields sent per feature

| Feature | Sent to Groq | NOT sent |
|---|---|---|
| **SOAP Documentation** | Patient first name; age (optional); diagnosis (optional); therapist's free-text notes (≤2,500 chars); session date | Patient UUID, email, phone, DOB, stored clinical records |
| **Patient History Summary** | Patient first name; session count; up to 8 note summaries (date, chief complaint ≤200 chars, interventions ≤200 chars, progress ≤150 chars) | Full SOAP text, UUID, email, phone, DOB |
| **Revenue / Expense Analysis** | Date range, currency, amounts/dates/status only — **no patient names or IDs** | All patient identifiers |
| **Financial AI Chat** | Aggregated monthly totals; when AI requests records: up to 20 invoices including de-normalised `patient_name` text, service, amount, status | Patient UUIDs, email, phone, DOB, medical data |
| **Clinic Analytics** | Aggregated totals and counts only | All patient identifiers and clinical data |

### Model training

> ⚠ **Verify before publishing:** Groq's API Terms of Service state that
> API customer data is not used to train Groq's models.  Confirm this
> against the current terms at <https://groq.com/terms-of-service/> before
> publishing.

### Data location

Groq operates in the United States.  Use of the AI Doctor Assistant
constitutes acknowledgement of this cross-border transfer.
```

---

## SECTION C — Data Retention and Account Deletion

Place this in a "Data Retention" or "Your Rights" section, **after**
Section A.  The wording below is carefully calibrated to match the
C-1 migration behavior — do not change the invoice paragraph without
also updating the migration.

### HTML version

```html
<section id="data-retention">
  <h2>Data Retention and Account Deletion</h2>

  <h3>Retention periods</h3>
  <ul>
    <li>
      <strong>Clinical records</strong> (SOAP notes, appointments,
      appointment requests, home exercise programmes): retained for the
      duration of the active therapeutic relationship and for as long as
      required by applicable health-record retention law; deleted
      automatically when a patient account is deleted.
    </li>
    <li>
      <strong>Financial records</strong> (invoices): retained in
      anonymised form for a minimum of <strong>7 years</strong> to meet
      accounting and tax obligations under Lebanese law.  When a patient
      account is deleted, the invoice row is retained but all personal
      identifiers are removed — the patient's name is replaced with
      "[Deleted Patient]" and the patient account link is cleared.  The
      invoice amount, date, currency, and payment status are preserved
      for the clinic's legal accounting records only.
    </li>
    <li>
      <strong>Chat messages</strong>: the content of chat messages is
      retained as part of the therapeutic record.  If a user deletes
      their account, their identity as sender is anonymised (sender link
      removed) but the message content visible to the other participant
      is retained.
    </li>
    <li>
      <strong>Push notification records</strong>: deleted when the
      recipient account is deleted.
    </li>
    <li>
      <strong>AI-generated summaries</strong> (cached patient history
      summaries): deleted automatically when the patient or therapist
      account is deleted.
    </li>
  </ul>

  <h3>Account Deletion</h3>
  <p>
    You can delete your PhysioConnect account at any time:
  </p>
  <ol>
    <li>Open the app and navigate to your <strong>Profile</strong> tab.</li>
    <li>Scroll to the bottom and tap <strong>Delete Account</strong>.</li>
    <li>Confirm the deletion in the dialog that appears.</li>
  </ol>
  <p>
    Deletion is <strong>permanent and irreversible</strong>.  Upon
    confirmation, the following data is erased immediately:
  </p>
  <ul>
    <li>Your user account and authentication credentials</li>
    <li>All clinical notes (SOAP notes) linked to your account</li>
    <li>All appointment records and appointment requests</li>
    <li>All home exercise programme assignments</li>
    <li>All notifications</li>
    <li>All AI-generated summaries of your clinical history</li>
  </ul>
  <p>
    Financial records (invoices) are retained in anonymised form as
    described above.  Chat messages you have sent are anonymised (your
    identity as sender is removed) but not deleted.
  </p>
  <p>
    If you are unable to access the app, you may request account deletion
    by emailing
    <a href="mailto:jihadzhour@gmail.com">jihadzhour@gmail.com</a>.
    We will process the request within 30 days.
  </p>
</section>
```

### Markdown version (Jekyll)

```markdown
## Data Retention and Account Deletion

### Retention periods

| Data type | Retention | On account deletion |
|---|---|---|
| Clinical notes, appointments, appointment requests | Duration of therapeutic relationship / legal minimum | **Deleted immediately** |
| Home exercise programmes (patient-assigned) | Duration of therapeutic relationship | **Deleted immediately** |
| Invoices / financial records | Minimum 7 years (Lebanese accounting law) | **Retained, anonymised** — patient name → "[Deleted Patient]", patient link cleared; amount/date/status kept |
| Chat messages | Duration of account | **Anonymised** — sender identity removed; message content retained for other participant |
| Push notifications | Until read or account closed | **Deleted immediately** |
| AI summary cache | As needed for performance | **Deleted immediately** |

### How to delete your account

1. Profile tab → scroll to bottom → **Delete Account**
2. Confirm in the dialog.

Deletion is permanent.  If you cannot access the app, email
[jihadzhour@gmail.com](mailto:jihadzhour@gmail.com) and we will act
within 30 days.
```
