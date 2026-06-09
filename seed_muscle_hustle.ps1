# =============================================================================
#  PhysioConnect - Dr. Muscle Hustle Seeder
#  Seeds: 1 doctor (Dr. Muscle Hustle) + 8 patients + appointments, SOAP
#         notes, invoices (USD), and expenses (USD).
#  Run:  .\seed_muscle_hustle.ps1
# =============================================================================
param()
$ErrorActionPreference = 'Continue'

$BASE    = 'https://curvmfmrodvkczwhgevy.supabase.co'
$SVC_KEY = 'sb_secret_YAJNVpcpnTs12q091909nQ__JVfdbzQ'
$UA      = 'PhysioConnect-Seeder/1.0'

# ── API helpers ───────────────────────────────────────────────────────────────

function Invoke-AuthCreate($emailAddr, $pw) {
    $tmpFile = [System.IO.Path]::GetTempFileName()
    $bodyObj = @{ email = $emailAddr; password = $pw; email_confirm = $true }
    [System.IO.File]::WriteAllText($tmpFile, ($bodyObj | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))
    $raw = curl.exe -s -X POST "$BASE/auth/v1/admin/users" `
        -H "apikey: $SVC_KEY" `
        -H "Authorization: Bearer $SVC_KEY" `
        -H "User-Agent: $UA" `
        -H "Content-Type: application/json" `
        -d "@$tmpFile"
    Remove-Item $tmpFile -ErrorAction SilentlyContinue
    $parsed = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($parsed -and $parsed.id) { return $parsed.id }
    if ($raw -match 'already') {
        $listRaw  = curl.exe -s "$BASE/auth/v1/admin/users?per_page=200" `
            -H "apikey: $SVC_KEY" `
            -H "Authorization: Bearer $SVC_KEY" `
            -H "User-Agent: $UA"
        $listObj  = $listRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
        $existing = $listObj.users | Where-Object { $_.email -eq $emailAddr } | Select-Object -First 1
        return $existing.id
    }
    Write-Warning "  Auth create failed for $emailAddr : $raw"
    return $null
}

function Invoke-Insert($tableName, $rowData, [switch]$upsert) {
    $prefer  = if ($upsert) { 'return=representation,resolution=merge-duplicates' } else { 'return=minimal' }
    $tmpFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpFile, ($rowData | ConvertTo-Json -Depth 8 -Compress), [System.Text.UTF8Encoding]::new($false))
    $raw = curl.exe -s -X POST "$BASE/rest/v1/$tableName" `
        -H "apikey: $SVC_KEY" `
        -H "Authorization: Bearer $SVC_KEY" `
        -H "User-Agent: $UA" `
        -H "Content-Type: application/json" `
        -H "Prefer: $prefer" `
        -d "@$tmpFile"
    Remove-Item $tmpFile -ErrorAction SilentlyContinue
    if ($raw -and $raw -match '"code"') { Write-Warning "  Insert '$tableName' issue: $raw" }
    return $true
}

function Invoke-Patch($tableName, $filterStr, $rowData) {
    $tmpFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmpFile, ($rowData | ConvertTo-Json -Depth 8 -Compress), [System.Text.UTF8Encoding]::new($false))
    curl.exe -s -X PATCH "$BASE/rest/v1/$tableName?$filterStr" `
        -H "apikey: $SVC_KEY" `
        -H "Authorization: Bearer $SVC_KEY" `
        -H "User-Agent: $UA" `
        -H "Content-Type: application/json" `
        -H "Prefer: return=minimal" `
        -d "@$tmpFile" | Out-Null
    Remove-Item $tmpFile -ErrorAction SilentlyContinue
}

function Invoke-Get($tableName, $query) {
    $raw = curl.exe -s "$BASE/rest/v1/$tableName?$query" `
        -H "apikey: $SVC_KEY" `
        -H "Authorization: Bearer $SVC_KEY" `
        -H "User-Agent: $UA"
    return $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
}

function Get-TimeAgo($days) {
    return (Get-Date).AddDays(-$days).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
function Get-ApptTime($days, $hour) {
    return (Get-Date).Date.AddDays($days).AddHours($hour).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# ── Doctor Definition ─────────────────────────────────────────────────────────

$doctor = @{
    name            = 'Dr. Muscle Hustle'
    email           = 'dr.musclehustle@physioconnect.test'
    password        = 'PhysioDoc@2024!'
    specialization  = 'Sports & Musculoskeletal Physiotherapy'
    clinic_name     = 'Muscle Hustle Physio Clinic'
    clinic_address  = 'Downtown Sports Complex, Level 3, Dubai, UAE'
    latitude        = 25.1972
    longitude       = 55.2744
    offers_home_visit = $true
    bio             = 'High-energy sports physio specialising in musculoskeletal rehab, injury prevention, and return-to-sport protocols. Known for getting athletes back stronger than before.'
    subscription    = 'premium'
    expires_at      = '2027-06-01T00:00:00Z'
    features        = @{ messages = $true; statistics = $true; billing = $true; expenses = $true }
}

# ── Patient Definitions ───────────────────────────────────────────────────────

$patients = @(
    @{
        name              = 'Captain Crutch'
        email             = 'captain.crutch@patient.test'
        password          = 'Patient@2024!'
        phone             = '+971 50 111 0001'
        date_of_birth     = '1988-04-10'
        primary_diagnosis = 'Tibial Plateau Fracture - 8 Weeks Post-ORIF'
    },
    @{
        name              = 'Flexy Lexy'
        email             = 'flexy.lexy@patient.test'
        password          = 'Patient@2024!'
        phone             = '+971 50 111 0002'
        date_of_birth     = '1997-09-25'
        primary_diagnosis = 'Hypermobility Spectrum Disorder with Recurrent Shoulder Subluxations'
    },
    @{
        name              = 'Stiff Steve'
        email             = 'stiff.steve@patient.test'
        password          = 'Patient@2024!'
        phone             = '+971 50 111 0003'
        date_of_birth     = '1965-02-14'
        primary_diagnosis = 'Cervical Spondylosis C5-C6 with Right Radiculopathy and Shoulder Impingement'
    },
    @{
        name              = 'Sprainy Jane'
        email             = 'sprainy.jane@patient.test'
        password          = 'Patient@2024!'
        phone             = '+971 50 111 0004'
        date_of_birth     = '2000-11-03'
        primary_diagnosis = 'Grade II Right ATFL Sprain - Week 3'
    },
    @{
        name              = 'Posture Princess'
        email             = 'posture.princess@patient.test'
        password          = 'Patient@2024!'
        phone             = '+971 50 111 0005'
        date_of_birth     = '1994-06-18'
        primary_diagnosis = 'Upper Crossed Syndrome with Thoracic Kyphosis and Tension Headaches'
    },
    @{
        name              = 'Balance Barry'
        email             = 'balance.barry@patient.test'
        password          = 'Patient@2024!'
        phone             = '+971 50 111 0006'
        date_of_birth     = '1970-08-30'
        primary_diagnosis = 'Benign Paroxysmal Positional Vertigo (Right Posterior Canal) with Chronic Ankle Instability'
    },
    @{
        name              = 'Pain-Free Pete'
        email             = 'painfree.pete@patient.test'
        password          = 'Patient@2024!'
        phone             = '+971 50 111 0007'
        date_of_birth     = '1979-03-22'
        primary_diagnosis = 'Chronic Myofascial Pain Syndrome - Lumbar and Gluteal Region with Central Sensitisation'
    },
    @{
        name              = 'Ligament Larry'
        email             = 'ligament.larry@patient.test'
        password          = 'Patient@2024!'
        phone             = '+971 50 111 0008'
        date_of_birth     = '1993-12-07'
        primary_diagnosis = 'PCL Reconstruction - 12 Weeks Post-Surgery'
    }
)

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '  +----------------------------------------------------------+' -ForegroundColor Cyan
Write-Host '  |   PhysioConnect  --  Dr. Muscle Hustle Seeder            |' -ForegroundColor Cyan
Write-Host '  |   1 Doctor  |  8 Patients  |  Full Dataset (USD)         |' -ForegroundColor Cyan
Write-Host '  +----------------------------------------------------------+' -ForegroundColor Cyan
Write-Host ''

$docId     = $null
$patientIds = @($null, $null, $null, $null, $null, $null, $null, $null)

# =============================================================================
# STEP 1 -- CREATE DOCTOR
# =============================================================================

Write-Host '  STEP 1  Creating Dr. Muscle Hustle' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray
Write-Host "  [1/1] $($doctor.name) ..." -NoNewline

$docId = Invoke-AuthCreate $doctor.email $doctor.password
if (-not $docId) {
    Write-Host ' FAILED' -ForegroundColor Red
} else {
    $emptyArr = [System.Collections.ArrayList]::new()
    Invoke-Insert 'users' @{
        id                   = $docId
        email                = $doctor.email
        name                 = $doctor.name
        role                 = 'doctor'
        bio                  = $doctor.bio
        specialization       = $doctor.specialization
        clinic_name          = $doctor.clinic_name
        clinic_address       = $doctor.clinic_address
        latitude             = $doctor.latitude
        longitude            = $doctor.longitude
        location_updated_at  = Get-TimeAgo 0
        offers_home_visit    = $doctor.offers_home_visit
        show_in_search       = $true
        subscription         = $doctor.subscription
        features             = $doctor.features
        expires_at           = $doctor.expires_at
        is_enabled           = $true
        assigned_patient_ids = $emptyArr
        doctor_ids           = $emptyArr
        linked_doctor_ids    = $emptyArr
        created_at           = Get-TimeAgo 0
        updated_at           = Get-TimeAgo 0
    } -upsert | Out-Null
    Write-Host " OK  [$docId]" -ForegroundColor Green
}

Write-Host ''

# =============================================================================
# STEP 2 -- CREATE PATIENTS
# =============================================================================

Write-Host '  STEP 2  Creating 8 Patients' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

for ($i = 0; $i -lt $patients.Count; $i++) {
    $pat = $patients[$i]
    Write-Host "  [$($i+1)/8] $($pat.name) ..." -NoNewline

    $patUid = Invoke-AuthCreate $pat.email $pat.password
    if (-not $patUid) { Write-Host ' FAILED' -ForegroundColor Red; continue }

    $docIdList = [System.Collections.ArrayList]::new()
    if ($docId) { $docIdList.Add($docId) | Out-Null }
    $emptyArr2 = [System.Collections.ArrayList]::new()

    Invoke-Insert 'users' @{
        id                   = $patUid
        email                = $pat.email
        name                 = $pat.name
        role                 = 'patient'
        phone                = $pat.phone
        date_of_birth        = $pat.date_of_birth
        primary_diagnosis    = $pat.primary_diagnosis
        doctor_id            = $docId
        doctor_ids           = $docIdList
        is_enabled           = $true
        show_in_search       = $true
        assigned_patient_ids = $emptyArr2
        linked_doctor_ids    = $emptyArr2
        created_at           = Get-TimeAgo 0
        updated_at           = Get-TimeAgo 0
    } -upsert | Out-Null

    # Add patient to doctor's assigned_patient_ids
    if ($docId) {
        $docRow  = Invoke-Get 'users' "id=eq.$docId&select=assigned_patient_ids"
        $curList = [System.Collections.ArrayList]@()
        if ($docRow -and $docRow[0].assigned_patient_ids) {
            foreach ($id in $docRow[0].assigned_patient_ids) { $curList.Add($id) | Out-Null }
        }
        if (-not $curList.Contains($patUid)) { $curList.Add($patUid) | Out-Null }
        Invoke-Patch 'users' "id=eq.$docId" @{ assigned_patient_ids = @($curList) }
    }

    $patientIds[$i] = $patUid
    Write-Host " OK  [$patUid]" -ForegroundColor Green
}

Write-Host ''

# =============================================================================
# STEP 3 -- APPOINTMENTS
# =============================================================================

Write-Host '  STEP 3  Seeding Appointments' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

# 3 appointments per patient: 1 completed past, 2 upcoming scheduled
$apptDefs = @(
    # Captain Crutch (idx 0)
    @{ pIdx=0; days=-10; hour=9;  notes='Initial post-ORIF assessment. Weight bearing status reviewed, quad lag noted, crutch gait training.'; status='completed' },
    @{ pIdx=0; days= 2;  hour=9;  notes='PWB progression session - quad sets and SLR, stationary bike intro.'; status='scheduled' },
    @{ pIdx=0; days= 7;  hour=10; notes='Weight bearing advancement and ROM review - targeting 90 deg flexion.'; status='scheduled' },
    # Flexy Lexy (idx 1)
    @{ pIdx=1; days=-8;  hour=11; notes='Initial assessment. Beighton Score 7/9. Scapular stability and rotator cuff baseline measured.'; status='completed' },
    @{ pIdx=1; days= 3;  hour=11; notes='Rotator cuff stabilisation phase 1 - isometric progression and joint protection education.'; status='scheduled' },
    @{ pIdx=1; days= 9;  hour=14; notes='Phase 2 - proprioceptive neuromuscular facilitation and sport-specific loading.'; status='scheduled' },
    # Stiff Steve (idx 2)
    @{ pIdx=2; days=-12; hour=14; notes='Cervical assessment. Spurling positive R. Manual therapy C5-C6 traction performed. Postural review.'; status='completed' },
    @{ pIdx=2; days= 1;  hour=14; notes='Neural mobilisation right median nerve, deep neck flexor activation phase 1.'; status='scheduled' },
    @{ pIdx=2; days= 6;  hour=15; notes='Progressive cervical strengthening and thoracic mobility work.'; status='scheduled' },
    # Sprainy Jane (idx 3)
    @{ pIdx=3; days=-7;  hour=10; notes='Week 3 ankle sprain review. Oedema improving. RICE protocol education. Started proprioception.'; status='completed' },
    @{ pIdx=3; days= 2;  hour=10; notes='BOSU and wobble board balance training, resistance band eversion strengthening.'; status='scheduled' },
    @{ pIdx=3; days= 7;  hour=9;  notes='Functional return-to-sport testing - SEBT and hop tests.'; status='scheduled' },
    # Posture Princess (idx 4)
    @{ pIdx=4; days=-9;  hour=15; notes='Postural assessment. FHP 4cm, thoracic kyphosis increased. Ergonomic assessment completed.'; status='completed' },
    @{ pIdx=4; days= 3;  hour=15; notes='DNF chin tuck and thoracic extension programme, pectoral stretching technique review.'; status='scheduled' },
    @{ pIdx=4; days= 8;  hour=11; notes='Serratus anterior and lower trapezius strengthening phase 2.'; status='scheduled' },
    # Balance Barry (idx 5)
    @{ pIdx=5; days=-6;  hour=9;  notes='Initial vestibular assessment. Dix-Hallpike positive right. Epley manoeuvre performed. Fall risk assessed.'; status='completed' },
    @{ pIdx=5; days= 2;  hour=9;  notes='BPPV follow-up and canal repositioning. Progressive balance training on foam surface.'; status='scheduled' },
    @{ pIdx=5; days= 7;  hour=10; notes='Ankle stabilisation and dynamic balance - perturbation and gait training.'; status='scheduled' },
    # Pain-Free Pete (idx 6)
    @{ pIdx=6; days=-11; hour=13; notes='Chronic pain assessment. Trigger point mapping QL and gluteal. Pain education session 1.'; status='completed' },
    @{ pIdx=6; days= 1;  hour=13; notes='Dry needling session 2 - QL and piriformis. Graded activity plan review.'; status='scheduled' },
    @{ pIdx=6; days= 6;  hour=14; notes='Pain neuroscience education session 2. Sleep hygiene and pacing strategies.'; status='scheduled' },
    # Ligament Larry (idx 7)
    @{ pIdx=7; days=-14; hour=11; notes='12-week PCL reconstruction review. Posterior drawer negative. LSI 78% - return-to-sport programme initiated.'; status='completed' },
    @{ pIdx=7; days= 3;  hour=11; notes='Agility ladder drills and court movement. Bulgarian squat progression.'; status='scheduled' },
    @{ pIdx=7; days= 8;  hour=10; notes='Return-to-sport testing session - hop tests, 505 agility, targeting >90% LSI.'; status='scheduled' }
)

$apptCount = 0
foreach ($appt in $apptDefs) {
    $patUid = $patientIds[$appt.pIdx]
    if (-not $docId -or -not $patUid) { continue }
    Invoke-Insert 'appointments' @{
        patient_id       = $patUid
        patient_name     = $patients[$appt.pIdx].name
        doctor_id        = $docId
        appointment_time = Get-ApptTime $appt.days $appt.hour
        notes            = $appt.notes
        status           = $appt.status
        created_at       = Get-TimeAgo 0
    } | Out-Null
    $apptCount++
}
Write-Host "  [+] $apptCount appointments seeded" -ForegroundColor Green
Write-Host ''

# =============================================================================
# STEP 4 -- SOAP DOCUMENTATION
# =============================================================================

Write-Host '  STEP 4  Seeding SOAP Documentation' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

$soapDefs = @(
    @{
        pIdx=0; daysAgo=10
        S='Patient reports knee pain 5/10 with ambulation, reduced to 3/10 at rest. Cleared for partial weight bearing this week. Difficulty with stairs and prolonged standing.'
        O='ROM: knee flexion 75 deg, extension -5 deg lag. Quad strength 3/5. No wound complications. Mild pitting oedema at surgical site. Ambulating with bilateral axillary crutches.'
        A='Post-ORIF tibial plateau fracture, 8 weeks. Progressing as expected. Quad lag and reduced ROM are primary functional limitations at this stage.'
        P='1. Progress PWB 50% to 75% over 2 weeks. 2. Quad sets and SLR exercises 3x daily. 3. Stationary cycling (no resistance). 4. Patellar mobilisation. 5. Reassess ROM weekly - target 90 deg by week 10.'
    },
    @{
        pIdx=1; daysAgo=8
        S='Shoulder subluxation episode yesterday reaching overhead for a shelf item. Reports daily joint aches rated 4/10, fatigue with prolonged standing. Wears wrist splints at night.'
        O='Beighton Score 7/9. Bilateral shoulder hypermobility, excessive inferior glide noted. Scapular dyskinesis type III right. Grip strength 18 kg bilateral. Trendelenburg positive left. Sulcus sign positive bilaterally.'
        A='Hypermobility Spectrum Disorder with recurring right shoulder subluxations and global ligamentous laxity. Functional instability affecting daily activities and employment.'
        P='1. Rotator cuff isometric programme phase 1. 2. Scapular setting exercises: wall slides and prone Y-T. 3. PNF patterns D1 and D2. 4. Joint protection education and activity modification. 5. Liaise with OT regarding splinting assessment.'
    },
    @{
        pIdx=2; daysAgo=12
        S='Neck pain 6/10 with radiation to right arm in C6 distribution. Wakes with stiffness that eases after 30 minutes. Headaches 3x/week occipital and temporal. Pain worsens with prolonged reading.'
        O='Cervical rotation: R 35 deg (limited), L 55 deg. Spurling positive right. Upper trapezius trigger points bilateral. Right shoulder elevation 150 deg due to pain referral. Wrist extensors 4/5 right vs 5/5 left.'
        A='Cervical spondylosis C5-C6 with right C6 radiculopathy and secondary shoulder impingement. Chronic pain sensitisation pattern evident. Occupational posture contributing to ongoing symptoms.'
        P='1. Manual therapy: cervical sustained traction and PA mobilisation C5-C6. 2. Deep neck flexor craniocervical flexion activation. 3. Neural mobilisation right median nerve. 4. Postural re-education: chin tuck, shoulder retraction. 5. Heat therapy for upper trapezius myofascial component.'
    },
    @{
        pIdx=3; daysAgo=7
        S='Right ankle pain 4/10 walking on uneven ground, 2/10 on flat. Swelling reduced markedly since week 1. Reports ankle feeling unstable on stairs and lateral movements.'
        O='ATFL tenderness 2/4. Oedema trace at anterolateral gutter. AROM: DF 10 deg (R) vs 18 deg (L), EV 15 deg (R) vs 22 deg (L). Single leg balance: 12 sec eyes open (R). SEBT anterior reach deficit 8% vs contralateral.'
        A='Grade II ATFL sprain week 3. Resolving well anatomically. Residual proprioceptive deficit and functional instability remain primary rehabilitation targets.'
        P='1. Proprioception: wobble board single leg 3x30 sec, BOSU lateral shuffles. 2. Resistance band eversion strengthening. 3. Calf raises 3x15 progressing to single leg. 4. Return-to-sport criteria: >85% SEBT symmetry, negative inversion stress test. Target 2-3 weeks.'
    },
    @{
        pIdx=4; daysAgo=9
        S='Neck and upper back pain 5/10 after prolonged computer work. Frequent tension headaches 4x/week. Reports embarrassment about rounded shoulders. Desk job 9 hours daily, no ergonomic setup.'
        O='FHP: head 4 cm anterior to plumb line. Thoracic kyphosis increased at T4-T8. Pectoralis minor and SCM bilaterally tight. DNF strength 2/5 (craniocervical flexion test). Serratus anterior 3/5 bilateral.'
        A='Upper crossed syndrome with thoracic kyphosis and forward head posture. Pattern consistent with prolonged sedentary occupational exposure. Tension headaches likely cervicogenic in origin.'
        P='1. DNF chin tuck progression: supine to sitting to standing. 2. Thoracic extension over foam roller 2x20 sec. 3. Pectoral and levator scapulae stretching 3x30 sec. 4. Serratus anterior: wall push-up plus and protraction slides. 5. Ergonomic workstation assessment and monitor height adjustment.'
    },
    @{
        pIdx=5; daysAgo=6
        S='Dizziness with head position changes, particularly rolling over in bed and looking up. Three falls in last month, one resulting in bruising. Right ankle gives way on uneven ground.'
        O='Dix-Hallpike: positive right posterior canal (geotropic nystagmus, 8 sec). Romberg: positive with eyes closed. Tandem gait: 3 steps before loss of balance. Cumberland Ankle Instability Tool score 17/30 (right).'
        A='Right posterior canal BPPV with co-existing chronic right ankle instability. Significant multifactorial fall risk. Dual vestibular and proprioceptive deficits compounding functional limitations.'
        P='1. Epley manoeuvre performed today right posterior canal. 2. Home BBQ roll programme written and demonstrated. 3. Single leg balance progression: firm surface to foam. 4. Ankle resistance band eversion and dorsiflexion strengthening. 5. Reassess Dix-Hallpike in 1 week.'
    },
    @{
        pIdx=6; daysAgo=11
        S='Widespread lower back and gluteal pain rated 6/10, worse end of day and after prolonged sitting. Reports poor sleep due to pain interrupting rest. Has trialled physiotherapy, acupuncture and massage without lasting relief over 3 years.'
        O='Active trigger points: bilateral QL, gluteus medius (3 each side), piriformis (right > left). Pain Catastrophising Scale 28/52 (high). PPT globally reduced. Lumbar flexion 60% norm. Lumbar extension 70% norm. No neurological signs.'
        A='Chronic myofascial pain syndrome with central sensitisation component. High catastrophising and pain avoidance behaviour contributing to chronicity. Significant psychosocial overlay requiring interdisciplinary approach.'
        P='1. Dry needling: bilateral QL and right piriformis today. 2. Graded activity programme: 20 min walk daily, increase 5 min/week. 3. Pain neuroscience education session 1: threat response model. 4. Sleep hygiene: sleep restriction and stimulus control advice. 5. Referral letter to pain psychologist initiated.'
    },
    @{
        pIdx=7; daysAgo=14
        S='Knee subjectively stable in daily activities. Pain 1/10 at rest, 2/10 with loaded movements. Reports posterior knee tightness with deep squats. Motivated for basketball return. Psychologically ready.'
        O='Posterior drawer: negative. Quadriceps LSI: 85% (quad dynamometry). Single-leg hop: 78% symmetry. Crossover hop: 80% symmetry. Knee flexion 120 deg (R) vs 135 deg (L). Posterior capsule restriction with end-range flexion.'
        A='PCL reconstruction 12 weeks. Strong functional recovery trend. Limb symmetry index below the 90% return-to-sport threshold. Posterior capsule tightness limiting deep squat mechanics.'
        P='1. Posterior capsule stretching: prone knee flexion and elevated pigeon stretch. 2. Progress single-leg loading: Bulgarian split squat and eccentric step-down. 3. Introduce agility ladder and court movement drills at 50% effort. 4. Return-to-sport clearance at 16 weeks pending >90% LSI on all hop tests.'
    }
)

$soapCount = 0
foreach ($note in $soapDefs) {
    $patUid = $patientIds[$note.pIdx]
    if (-not $docId -or -not $patUid) { continue }
    Invoke-Insert 'clinical_notes' @{
        patient_id   = $patUid
        patient_name = $patients[$note.pIdx].name
        doctor_id    = $docId
        subjective   = $note.S
        objective    = $note.O
        assessment   = $note.A
        plan         = $note.P
        text_note    = "S: $($note.S)`n`nO: $($note.O)`n`nA: $($note.A)`n`nP: $($note.P)"
        note_type    = 'soap'
        created_at   = Get-TimeAgo $note.daysAgo
        updated_at   = Get-TimeAgo $note.daysAgo
    } | Out-Null
    $soapCount++
}
Write-Host "  [+] $soapCount SOAP notes seeded" -ForegroundColor Green
Write-Host ''

# =============================================================================
# STEP 5 -- INVOICES (USD)
# =============================================================================

Write-Host '  STEP 5  Seeding Invoices (USD)' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

# Each patient: 1 paid initial assessment + 1 paid follow-up + 1 pending upcoming
$invoiceDefs = @(
    # Captain Crutch
    @{ pIdx=0; service='Initial Post-ORIF Assessment';          amount=220; status='paid';    paid=220; daysAgo=10 },
    @{ pIdx=0; service='Physiotherapy Session - Quad & Gait';   amount=160; status='paid';    paid=160; daysAgo=5  },
    @{ pIdx=0; service='Physiotherapy Session - PWB Progression'; amount=160; status='pending'; paid=0;   daysAgo=0  },
    # Flexy Lexy
    @{ pIdx=1; service='Initial Hypermobility Assessment';       amount=220; status='paid';    paid=220; daysAgo=8  },
    @{ pIdx=1; service='Stabilisation Programme Session 1';      amount=155; status='paid';    paid=155; daysAgo=4  },
    @{ pIdx=1; service='Stabilisation Programme Session 2';      amount=155; status='pending'; paid=0;   daysAgo=0  },
    # Stiff Steve
    @{ pIdx=2; service='Cervical & Shoulder Assessment';         amount=220; status='paid';    paid=220; daysAgo=12 },
    @{ pIdx=2; service='Manual Therapy + Neural Mobilisation';   amount=170; status='paid';    paid=170; daysAgo=6  },
    @{ pIdx=2; service='Cervical Strengthening Session';         amount=150; status='pending'; paid=0;   daysAgo=0  },
    # Sprainy Jane
    @{ pIdx=3; service='Ankle Sprain Initial Assessment';        amount=200; status='paid';    paid=200; daysAgo=7  },
    @{ pIdx=3; service='Proprioception & Strengthening Session'; amount=145; status='paid';    paid=145; daysAgo=3  },
    @{ pIdx=3; service='Return-to-Sport Testing Session';        amount=180; status='pending'; paid=0;   daysAgo=0  },
    # Posture Princess
    @{ pIdx=4; service='Postural Assessment & Ergonomic Review'; amount=210; status='paid';    paid=210; daysAgo=9  },
    @{ pIdx=4; service='Postural Correction Session 1';          amount=145; status='paid';    paid=145; daysAgo=4  },
    @{ pIdx=4; service='Postural Correction Session 2';          amount=145; status='pending'; paid=0;   daysAgo=0  },
    # Balance Barry
    @{ pIdx=5; service='Vestibular & Balance Assessment';        amount=230; status='paid';    paid=230; daysAgo=6  },
    @{ pIdx=5; service='Epley Manoeuvre + Balance Training';     amount=165; status='paid';    paid=165; daysAgo=2  },
    @{ pIdx=5; service='Vestibular Rehab Follow-Up';             amount=155; status='pending'; paid=0;   daysAgo=0  },
    # Pain-Free Pete
    @{ pIdx=6; service='Chronic Pain Assessment';                amount=220; status='paid';    paid=220; daysAgo=11 },
    @{ pIdx=6; service='Dry Needling Session 1';                 amount=175; status='paid';    paid=175; daysAgo=5  },
    @{ pIdx=6; service='Dry Needling Session 2 + Pain Ed';       amount=175; status='pending'; paid=0;   daysAgo=0  },
    # Ligament Larry
    @{ pIdx=7; service='12-Week PCL Reconstruction Review';      amount=220; status='paid';    paid=220; daysAgo=14 },
    @{ pIdx=7; service='Return-to-Sport Programme Session 1';    amount=165; status='paid';    paid=165; daysAgo=7  },
    @{ pIdx=7; service='Agility & RTS Testing Session';          amount=180; status='pending'; paid=0;   daysAgo=0  }
)

$invCount = 0
foreach ($inv in $invoiceDefs) {
    $patUid = $patientIds[$inv.pIdx]
    if (-not $docId -or -not $patUid) { continue }
    $invDate = Get-TimeAgo $inv.daysAgo
    $row = @{
        doctor_id    = $docId
        patient_id   = $patUid
        patient_name = $patients[$inv.pIdx].name
        service      = $inv.service
        amount       = $inv.amount
        currency     = 'USD'
        status       = $inv.status
        note         = ''
        invoice_date = $invDate
        created_at   = $invDate
    }
    if ($inv.status -eq 'paid') { $row['paid_amount'] = $inv.paid }
    Invoke-Insert 'invoices' $row | Out-Null
    $invCount++
}
Write-Host "  [+] $invCount invoices seeded (USD, paid + pending)" -ForegroundColor Green
Write-Host ''

# =============================================================================
# STEP 6 -- EXPENSES (USD)
# =============================================================================

Write-Host '  STEP 6  Seeding Expenses (USD)' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

$expenseDefs = @(
    @{ description='Resistance Bands Set (Light/Medium/Heavy) x10'; category='Equipment';  amount=380;  status='paid'; daysAgo=20 },
    @{ description='Kinesiology Tape Bulk Purchase (72 rolls)';      category='Supplies';   amount=95;   status='paid'; daysAgo=18 },
    @{ description='Clinic Management Software - Monthly';           category='Software';   amount=49;   status='paid'; daysAgo=15 },
    @{ description='TENS Machine Electrode Pads x50';                category='Supplies';   amount=120;  status='paid'; daysAgo=12 },
    @{ description='Foam Rollers and Therapy Balls Set';             category='Equipment';  amount=95;   status='paid'; daysAgo=10 },
    @{ description='CPD Course - Dry Needling Advanced Module';      category='Training';   amount=450;  status='paid'; daysAgo=8  },
    @{ description='Physio Table Disposable Cover Roll x500';        category='Supplies';   amount=65;   status='paid'; daysAgo=6  },
    @{ description='Professional Liability Insurance - Q3 Premium';  category='Insurance';  amount=850;  status='paid'; daysAgo=4  },
    @{ description='Clinic Rent - June 2026';                        category='Rent';       amount=1800; status='paid'; daysAgo=2  },
    @{ description='Balance Board and BOSU Ball x2';                 category='Equipment';  amount=310;  status='pending'; daysAgo=0 },
    @{ description='Portable Ultrasound Machine Servicing';          category='Equipment';  amount=220;  status='pending'; daysAgo=0 }
)

$expCount = 0
foreach ($exp in $expenseDefs) {
    if (-not $docId) { continue }
    $expDate = Get-TimeAgo $exp.daysAgo
    Invoke-Insert 'expenses' @{
        doctor_id    = $docId
        category     = $exp.category
        description  = $exp.description
        amount       = $exp.amount
        status       = $exp.status
        note         = ''
        expense_date = $expDate
        created_at   = $expDate
    } | Out-Null
    $expCount++
}
Write-Host "  [+] $expCount expenses seeded (USD)" -ForegroundColor Green
Write-Host ''

# =============================================================================
# STEP 7 -- NOTIFICATIONS
# =============================================================================

Write-Host '  STEP 7  Seeding Patient Notifications' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

$notifDefs = @(
    @{ pIdx=0; type='appointment_scheduled'; isRead=$false; daysAgo=1; title='Session Scheduled';            body='Your PWB progression session with Dr. Muscle Hustle is confirmed.' },
    @{ pIdx=1; type='appointment_scheduled'; isRead=$false; daysAgo=2; title='Session Scheduled';            body='Your stabilisation session with Dr. Muscle Hustle is confirmed.' },
    @{ pIdx=2; type='appointment_reminder';  isRead=$false; daysAgo=1; title='Session Tomorrow';             body='Your cervical therapy session with Dr. Muscle Hustle is tomorrow.' },
    @{ pIdx=3; type='appointment_scheduled'; isRead=$false; daysAgo=2; title='RTS Testing Booked';           body='Your return-to-sport testing session with Dr. Muscle Hustle is set.' },
    @{ pIdx=4; type='appointment_reminder';  isRead=$false; daysAgo=1; title='Posture Session Tomorrow';     body='Your postural correction session with Dr. Muscle Hustle is tomorrow.' },
    @{ pIdx=5; type='appointment_scheduled'; isRead=$false; daysAgo=2; title='Vestibular Follow-Up Set';     body='Your vestibular rehab follow-up with Dr. Muscle Hustle is confirmed.' },
    @{ pIdx=6; type='appointment_scheduled'; isRead=$false; daysAgo=1; title='Dry Needling Session Booked';  body='Your dry needling session with Dr. Muscle Hustle is confirmed.' },
    @{ pIdx=7; type='appointment_reminder';  isRead=$false; daysAgo=1; title='Agility Session Tomorrow';     body='Your agility and RTS testing session with Dr. Muscle Hustle is tomorrow.' },
    @{ pIdx=0; type='doctor_added_you';      isRead=$true;  daysAgo=10; title='Added to Patient List';       body='Dr. Muscle Hustle has added you to their patient list at Muscle Hustle Physio Clinic.' },
    @{ pIdx=3; type='message';               isRead=$true;  daysAgo=3; title='Message from Dr. Muscle Hustle'; body='Great progress on your ankle stability! Keep up the wobble board exercises twice daily.' }
)

$notifCount = 0
foreach ($notif in $notifDefs) {
    $patUid = $patientIds[$notif.pIdx]
    if (-not $patUid) { continue }
    Invoke-Insert 'notifications' @{
        patient_id     = $patUid
        recipient_id   = $patUid
        recipient_type = 'patient'
        type           = $notif.type
        title          = $notif.title
        body           = $notif.body
        read           = $notif.isRead
        created_at     = Get-TimeAgo $notif.daysAgo
    } | Out-Null
    $notifCount++
}
Write-Host "  [+] $notifCount notifications seeded" -ForegroundColor Green
Write-Host ''

# =============================================================================
# SUMMARY REPORT
# =============================================================================

Write-Host '  +----------------------------------------------------------+' -ForegroundColor Cyan
Write-Host '  |              ACCOUNTS CREATED -- LOGIN DETAILS           |' -ForegroundColor Cyan
Write-Host '  +----------------------------------------------------------+' -ForegroundColor Cyan
Write-Host ''

Write-Host '  DOCTOR ACCOUNT' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------------------------------------------'
Write-Host "  Name   : $($doctor.name)"
Write-Host "  Email  : $($doctor.email)"
Write-Host "  Pass   : $($doctor.password)"
Write-Host "  Plan   : Premium (all features, expires 2027-06-01)"
Write-Host "  UUID   : $docId" -ForegroundColor DarkGray
Write-Host '  -----------------------------------------------------------------------------------'
Write-Host ''

Write-Host '  PATIENT ACCOUNTS  (password for all: Patient@2024!)' -ForegroundColor Yellow
Write-Host '  --------------------------------------------------------------------------------------------'
Write-Host '   #  Name                  Email                              Diagnosis'
Write-Host '  --------------------------------------------------------------------------------------------'
for ($i = 0; $i -lt $patients.Count; $i++) {
    $pat = $patients[$i]
    $uid = if ($patientIds[$i]) { $patientIds[$i] } else { 'FAILED' }
    $nm  = $pat.name.PadRight(21)
    $em  = $pat.email.PadRight(34)
    $dx  = $pat.primary_diagnosis.Substring(0, [Math]::Min(45, $pat.primary_diagnosis.Length))
    Write-Host "   $($i+1)  $nm $em $dx"
    Write-Host "       UUID: $uid" -ForegroundColor DarkGray
}
Write-Host '  --------------------------------------------------------------------------------------------'
Write-Host ''

$totalIncome   = ($invoiceDefs | Where-Object { $_.status -eq 'paid' } | Measure-Object -Property amount -Sum).Sum
$pendingIncome = ($invoiceDefs | Where-Object { $_.status -eq 'pending' } | Measure-Object -Property amount -Sum).Sum
$totalExpenses = ($expenseDefs | Measure-Object -Property amount -Sum).Sum

Write-Host '  FINANCIAL SUMMARY (USD)' -ForegroundColor Yellow
Write-Host "  Invoices collected (paid)  : `$$totalIncome"
Write-Host "  Invoices outstanding       : `$$pendingIncome"
Write-Host "  Total expenses             : `$$totalExpenses"
Write-Host ''
Write-Host '  DATA SEEDED' -ForegroundColor Yellow
Write-Host "  [+] 1  doctor account"
Write-Host "  [+] 8  patient accounts"
Write-Host "  [+] $apptCount  appointments  (1 completed + 2 upcoming per patient)"
Write-Host "  [+] $soapCount   SOAP notes    (1 detailed note per patient)"
Write-Host "  [+] $invCount  invoices       (2 paid + 1 pending per patient, USD)"
Write-Host "  [+] $expCount  expenses       (equipment / supplies / rent / insurance, USD)"
Write-Host "  [+] $notifCount notifications"
Write-Host ''
Write-Host '  [OK] Dr. Muscle Hustle seeding complete!' -ForegroundColor Green
Write-Host ''
