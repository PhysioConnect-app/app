# =============================================================================
#  PhysioConnect - Dummy Data Seeder
#  Seeds: 5 doctors + 5 patients + appointments, SOAP notes, billing, expenses,
#         notifications. Uses curl.exe (Windows built-in) for all API calls.
#  Run:  .\seed_dummy_data.ps1
# =============================================================================
param()
$ErrorActionPreference = 'Continue'

$BASE    = 'https://curvmfmrodvkczwhgevy.supabase.co'
$SVC_KEY = 'sb_secret_YAJNVpcpnTs12q091909nQ__JVfdbzQ'
$UA      = 'PhysioConnect-Seeder/1.0'

# ── API helpers (all via curl.exe to avoid PS User-Agent blocking) ─────────────

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
    # User already exists - find via list
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
    $prefer = if ($upsert) { 'return=representation,resolution=merge-duplicates' } else { 'return=minimal' }
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
    if ($raw -and $raw -notmatch '"code"') { return $true }
    if ($raw -match '"code"') { Write-Warning "  Insert '$tableName' issue: $raw" }
    return $false
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

# ── Doctor Definitions ───────────────────────────────────────────────────────

$doctors = @(
    @{
        name='Dr. Sarah Mitchell'; email='dr.mitchell@physioconnect.test'; password='PhysioDoc@2024!'
        specialization='Orthopedic Physiotherapy'; clinic_name='Mitchell Rehab Center'
        clinic_address='Al Ain Medical District, Abu Dhabi, UAE'
        latitude=24.2075; longitude=55.7447; offers_home_visit=$true
        bio='Board-certified orthopedic PT with 10+ years in sports injury rehabilitation and post-op recovery.'
        subscription='premium'; expires_at='2026-12-31T23:59:59Z'
        features=@{messages=$true; statistics=$true; billing=$true; expenses=$true}
        plan_label='Premium (Active - expires 2026-12-31)'; location_label='Al Ain, Abu Dhabi'
    },
    @{
        name='Dr. James Rodriguez'; email='dr.rodriguez@physioconnect.test'; password='PhysioDoc@2024!'
        specialization='Sports Rehabilitation'; clinic_name='Dubai Sports Physio'
        clinic_address='Dubai Marina Walk, Tower 5, Dubai, UAE'
        latitude=25.0805; longitude=55.1403; offers_home_visit=$false
        bio='Former team physiotherapist for UAE Premier League with expertise in athlete recovery.'
        subscription='premium'; expires_at='2026-12-31T23:59:59Z'
        features=@{messages=$true; statistics=$true; billing=$true; expenses=$true}
        plan_label='Premium (Active - expires 2026-12-31)'; location_label='Dubai Marina'
    },
    @{
        name='Dr. Emily Chen'; email='dr.chen@physioconnect.test'; password='PhysioDoc@2024!'
        specialization='Neurological Physiotherapy'; clinic_name='NeuroMove Clinic'
        clinic_address='Abu Dhabi City Center, Hamdan Street, Abu Dhabi, UAE'
        latitude=24.4539; longitude=54.3773; offers_home_visit=$false
        bio='Specializes in stroke recovery, multiple sclerosis, and neurological movement disorders.'
        subscription='basic'; expires_at=$null
        features=@{}
        plan_label='Basic (No expiry - core tabs only)'; location_label='Abu Dhabi City Center'
    },
    @{
        name='Dr. Omar Hassan'; email='dr.hassan@physioconnect.test'; password='PhysioDoc@2024!'
        specialization='Post-Surgical Rehabilitation'; clinic_name='Hassan Recovery Clinic'
        clinic_address='Sharjah Medical Zone, Al Dhaid Road, Sharjah, UAE'
        latitude=25.3573; longitude=55.4033; offers_home_visit=$true
        bio='Post-surgical rehab specialist focused on orthopedic and cardiac recovery protocols.'
        subscription='basic'; expires_at=$null
        features=@{}
        plan_label='Basic (No expiry - core tabs only)'; location_label='Sharjah Medical Zone'
    },
    @{
        name='Dr. Layla Al-Farsi'; email='dr.alfarsi@physioconnect.test'; password='PhysioDoc@2024!'
        specialization='Pediatric Physiotherapy'; clinic_name='Little Steps Clinic'
        clinic_address='Dubai Healthcare City, Building 64, Dubai, UAE'
        latitude=25.2354; longitude=55.3188; offers_home_visit=$true
        bio='Pediatric PT dedicated to improving children mobility, developmental delays and CP management.'
        subscription='premium'; expires_at='2026-01-01T00:00:00Z'
        features=@{messages=$true; statistics=$true; billing=$true; expenses=$true}
        plan_label='Premium *** EXPIRED 2026-01-01 ***'; location_label='Dubai Healthcare City'
    }
)

# ── Patient Definitions ──────────────────────────────────────────────────────

$patients = @(
    @{
        name='Ahmed Al-Mansouri'; email='ahmed.almansouri@patient.test'; password='Patient@2024!'
        phone='+971 50 123 4567'; date_of_birth='1985-03-15'
        primary_diagnosis='Chronic Lower Back Pain (L4-L5 Disc Herniation)'; doctorIdx=0
    },
    @{
        name='Maria Santos'; email='maria.santos@patient.test'; password='Patient@2024!'
        phone='+971 50 234 5678'; date_of_birth='1992-07-22'
        primary_diagnosis='ACL Reconstruction - 6 Weeks Post-Surgery'; doctorIdx=1
    },
    @{
        name='John Thompson'; email='john.thompson@patient.test'; password='Patient@2024!'
        phone='+971 50 345 6789'; date_of_birth='1968-11-08'
        primary_diagnosis='Ischemic Stroke - Left Hemiplegia (3 Months Recovery)'; doctorIdx=2
    },
    @{
        name='Fatima Al-Zaabi'; email='fatima.alzaabi@patient.test'; password='Patient@2024!'
        phone='+971 50 456 7890'; date_of_birth='1975-05-30'
        primary_diagnosis='Total Knee Replacement - Post-Op Week 8'; doctorIdx=3
    },
    @{
        name='Ali Khalid'; email='ali.khalid@patient.test'; password='Patient@2024!'
        phone='+971 50 567 8901'; date_of_birth='2008-09-12'
        primary_diagnosis='Developmental Coordination Disorder with Mild Spasticity'; doctorIdx=4
    }
)

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '  +------------------------------------------------+' -ForegroundColor Cyan
Write-Host '  |   PhysioConnect  --  Dummy Data Seeder         |' -ForegroundColor Cyan
Write-Host '  |   5 Doctors  |  5 Patients  |  Full Dataset    |' -ForegroundColor Cyan
Write-Host '  +------------------------------------------------+' -ForegroundColor Cyan
Write-Host ''

$doctorIds  = @($null, $null, $null, $null, $null)
$patientIds = @($null, $null, $null, $null, $null)

# =============================================================================
# STEP 1 -- CREATE DOCTORS
# =============================================================================

Write-Host '  STEP 1  Creating 5 Doctor Accounts' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

for ($i = 0; $i -lt $doctors.Count; $i++) {
    $doc = $doctors[$i]
    Write-Host "  [$($i+1)/5] $($doc.name) ..." -NoNewline

    $uid = Invoke-AuthCreate $doc.email $doc.password
    if (-not $uid) { Write-Host ' FAILED' -ForegroundColor Red; continue }

    $emptyArr = [System.Collections.ArrayList]::new()
    $profileData = @{
        id                   = $uid
        email                = $doc.email
        name                 = $doc.name
        role                 = 'doctor'
        bio                  = $doc.bio
        specialization       = $doc.specialization
        clinic_name          = $doc.clinic_name
        clinic_address       = $doc.clinic_address
        latitude             = $doc.latitude
        longitude            = $doc.longitude
        location_updated_at  = Get-TimeAgo 0
        offers_home_visit    = $doc.offers_home_visit
        show_in_search       = $true
        subscription         = $doc.subscription
        features             = $doc.features
        is_enabled           = $true
        assigned_patient_ids = $emptyArr
        doctor_ids           = $emptyArr
        linked_doctor_ids    = $emptyArr
        created_at           = Get-TimeAgo 0
        updated_at           = Get-TimeAgo 0
    }
    if ($doc.expires_at) { $profileData['expires_at'] = $doc.expires_at }

    Invoke-Insert 'users' $profileData -upsert | Out-Null
    $doctorIds[$i] = $uid
    Write-Host " OK  [$uid]" -ForegroundColor Green
}

Write-Host ''

# =============================================================================
# STEP 2 -- CREATE PATIENTS
# =============================================================================

Write-Host '  STEP 2  Creating 5 Patient Accounts' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

for ($i = 0; $i -lt $patients.Count; $i++) {
    $pat      = $patients[$i]
    $dIdx     = $pat.doctorIdx
    $docUid   = $doctorIds[$dIdx]
    $docName  = $doctors[$dIdx].name

    Write-Host "  [$($i+1)/5] $($pat.name) -> $docName ..." -NoNewline

    $patUid = Invoke-AuthCreate $pat.email $pat.password
    if (-not $patUid) { Write-Host ' FAILED' -ForegroundColor Red; continue }

    $docIdList = [System.Collections.ArrayList]::new()
    if ($docUid) { $docIdList.Add($docUid) | Out-Null }
    $emptyArr2 = [System.Collections.ArrayList]::new()

    $profileData = @{
        id                   = $patUid
        email                = $pat.email
        name                 = $pat.name
        role                 = 'patient'
        phone                = $pat.phone
        date_of_birth        = $pat.date_of_birth
        primary_diagnosis    = $pat.primary_diagnosis
        doctor_id            = $docUid
        doctor_ids           = $docIdList
        is_enabled           = $true
        show_in_search       = $true
        assigned_patient_ids = $emptyArr2
        linked_doctor_ids    = $emptyArr2
        created_at           = Get-TimeAgo 0
        updated_at           = Get-TimeAgo 0
    }

    Invoke-Insert 'users' $profileData -upsert | Out-Null

    # Push patient UID into doctor's assigned_patient_ids
    if ($docUid) {
        $docRow  = Invoke-Get 'users' "id=eq.$docUid&select=assigned_patient_ids"
        $curList = [System.Collections.ArrayList]@()
        if ($docRow -and $docRow[0].assigned_patient_ids) {
            foreach ($id in $docRow[0].assigned_patient_ids) { $curList.Add($id) | Out-Null }
        }
        if (-not $curList.Contains($patUid)) { $curList.Add($patUid) | Out-Null }
        Invoke-Patch 'users' "id=eq.$docUid" @{ assigned_patient_ids = @($curList) }
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

$apptDefs = @(
    @{ dIdx=0; pIdx=0; days= 2; hour=9;  notes='Initial assessment follow-up - McKenzie Phase 1';   status='scheduled' },
    @{ dIdx=0; pIdx=0; days= 5; hour=11; notes='Core stabilisation session B';                       status='scheduled' },
    @{ dIdx=0; pIdx=0; days=-7; hour=10; notes='Initial assessment completed - L4-L5 protocol set';  status='completed' },
    @{ dIdx=1; pIdx=1; days= 1; hour=14; notes='ACL rehab Phase 2 - quad strengthening and balance'; status='scheduled' },
    @{ dIdx=1; pIdx=1; days= 4; hour=10; notes='Proprioception and plyometric intro';                 status='scheduled' },
    @{ dIdx=1; pIdx=1; days=-5; hour=9;  notes='Phase 1 completed - gait re-education';              status='completed' },
    @{ dIdx=2; pIdx=2; days= 3; hour=10; notes='Upper limb motor retraining session 4';              status='scheduled' },
    @{ dIdx=2; pIdx=2; days=-3; hour=11; notes='Constraint-induced therapy session 3';               status='completed' },
    @{ dIdx=3; pIdx=3; days= 2; hour=15; notes='Knee flexion target 90 deg - stair training intro';  status='scheduled' },
    @{ dIdx=3; pIdx=3; days=-4; hour=14; notes='Post-op week 6 cleared for full weight bearing';     status='completed' },
    @{ dIdx=4; pIdx=4; days= 6; hour=9;  notes='Gross motor skills - balance beam and ladders';      status='scheduled' },
    @{ dIdx=4; pIdx=4; days=-2; hour=10; notes='Fine motor assessment and sensory integration';      status='completed' }
)

$apptCount = 0
foreach ($appt in $apptDefs) {
    $docUid = $doctorIds[$appt.dIdx]
    $patUid = $patientIds[$appt.pIdx]
    if (-not $docUid -or -not $patUid) { continue }
    Invoke-Insert 'appointments' @{
        patient_id       = $patUid
        patient_name     = $patients[$appt.pIdx].name
        doctor_id        = $docUid
        appointment_time = Get-ApptTime $appt.days $appt.hour
        notes            = $appt.notes
        status           = $appt.status
        created_at       = Get-TimeAgo 0
    } | Out-Null
    $apptCount++
}
Write-Host "  [+] $apptCount appointments seeded (upcoming + past)" -ForegroundColor Green
Write-Host ''

# =============================================================================
# STEP 4 -- SOAP DOCUMENTATION
# =============================================================================

Write-Host '  STEP 4  Seeding SOAP Documentation' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

$soapDefs = @(
    @{
        pIdx=0; dIdx=0; daysAgo=14
        S='Patient reports 7/10 lower back pain radiating to left leg. Pain worsens with prolonged sitting. Ibuprofen 400 mg gives partial relief.'
        O='ROM: lumbar flexion 40 deg (limited), extension 15 deg. SLR positive at 45 deg left. Reduced sensation L4 dermatome. Core strength 3/5.'
        A='L4-L5 disc herniation with moderate lumbar radiculopathy. Functional limitations in ADLs confirmed.'
        P='1. McKenzie extension exercises 2x daily. 2. Core stabilisation programme. 3. Neural mobilisation. 4. Reassess in 2 weeks. Avoid flexion loading.'
    },
    @{
        pIdx=0; dIdx=0; daysAgo=0
        S='Pain reduced to 4/10. Patient reports improvement in morning stiffness. Leg pain has decreased significantly.'
        O='ROM: lumbar flexion improved to 55 deg. SLR now negative. Core strength 4/5. Gait pattern normalised.'
        A='Good progress. Radiculopathy resolving. Core stability improving with exercise adherence.'
        P='Progress to Phase 2: dynamic stabilisation, functional movement training, ergonomics assessment for return-to-work.'
    },
    @{
        pIdx=1; dIdx=1; daysAgo=10
        S='Patient reports 3/10 post-surgical pain at 6 weeks. Minimal swelling. Concerned about stability during pivoting.'
        O='Knee flexion 95 deg, extension -2 deg. Quad strength 60% of contralateral. No effusion. Lachman stable. Single-leg squat mild valgus.'
        A='ACL reconstruction progressing well. Phase 2 criteria partially met. Quad strength deficit needs addressing before return-to-sport.'
        P='1. Closed chain strengthening: squats and leg press. 2. Perturbation training. 3. Begin jogging protocol. Target: full ROM and 80% quad symmetry by week 10.'
    },
    @{
        pIdx=2; dIdx=2; daysAgo=8
        S='Patient communicates via writing. Reports frustration with left arm weakness. Family notes improvement in walking speed.'
        O='UL: shoulder flexion 85 deg, elbow extension incomplete -30 deg. Grip strength 2 kg left. Fugl-Meyer UL score 28/66. 10-m walk test 18 sec.'
        A='Left hemiplegia with moderate upper limb involvement. LL recovery superior to UL. Broca aphasia affects communication.'
        P='1. CIMT 3h/day UL. 2. Mirror therapy 20 min BID. 3. Gait training parallel bars then cane. 4. Family education on facilitation techniques.'
    },
    @{
        pIdx=3; dIdx=3; daysAgo=6
        S='Post-TKR week 8. Pain 2/10 at rest, 5/10 on stairs. Satisfied with surgical outcome. Uses cane for longer distances.'
        O='Knee flexion 95 deg, extension 0 deg. Minimal swelling. Step test: 1 flight with rail. Quad strength 3+/5.'
        A='Recovering within expected trajectory. Slightly behind on stair function - likely fear-avoidance behaviour. No complications.'
        P='1. Stair training: step-over-step technique. 2. Stationary cycling 15 min/day. 3. Progress quad strengthening. 4. Reassurance re implant stability. 5. D/C cane by week 10.'
    },
    @{
        pIdx=4; dIdx=4; daysAgo=4
        S='Parent reports Ali has difficulty with ball skills at school. Enjoys swimming. Mild fatigue with prolonged activity.'
        O='BOT-2 balance subscale 3/9, bilateral coordination 4/9. Fine motor: bead-stringing 45 sec (norm 30 sec). Lower limb spasticity MAS 1+.'
        A='DCD with mild bilateral lower extremity spasticity. Age-appropriate cognition. Good motivation and engagement.'
        P='1. Task-oriented motor learning: ball skills and obstacle course. 2. Hydrotherapy 2x/week. 3. Gastrocnemius stretching. 4. Referral to OT for handwriting assessment.'
    }
)

$soapCount = 0
foreach ($note in $soapDefs) {
    $docUid = $doctorIds[$note.dIdx]
    $patUid = $patientIds[$note.pIdx]
    if (-not $docUid -or -not $patUid) { continue }
    Invoke-Insert 'clinical_notes' @{
        patient_id   = $patUid
        patient_name = $patients[$note.pIdx].name
        doctor_id    = $docUid
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
# STEP 5 -- INVOICES (BILLING)
# =============================================================================

Write-Host '  STEP 5  Seeding Billing / Invoices' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

$invoiceDefs = @(
    @{ dIdx=0; pIdx=0; amount=350; status='paid';    paid=350; daysAgo=20 },
    @{ dIdx=0; pIdx=0; amount=350; status='paid';    paid=350; daysAgo=13 },
    @{ dIdx=0; pIdx=0; amount=350; status='pending'; paid=0;   daysAgo=0  },
    @{ dIdx=1; pIdx=1; amount=420; status='paid';    paid=420; daysAgo=18 },
    @{ dIdx=1; pIdx=1; amount=420; status='pending'; paid=0;   daysAgo=5  },
    @{ dIdx=2; pIdx=2; amount=300; status='paid';    paid=300; daysAgo=15 },
    @{ dIdx=2; pIdx=2; amount=300; status='pending'; paid=0;   daysAgo=2  },
    @{ dIdx=3; pIdx=3; amount=280; status='paid';    paid=280; daysAgo=22 },
    @{ dIdx=3; pIdx=3; amount=280; status='pending'; paid=0;   daysAgo=7  },
    @{ dIdx=4; pIdx=4; amount=250; status='paid';    paid=250; daysAgo=10 },
    @{ dIdx=4; pIdx=4; amount=250; status='pending'; paid=0;   daysAgo=3  }
)

$invCount = 0
foreach ($inv in $invoiceDefs) {
    $docUid = $doctorIds[$inv.dIdx]
    $patUid = $patientIds[$inv.pIdx]
    if (-not $docUid -or -not $patUid) { continue }
    $invDate = Get-TimeAgo $inv.daysAgo
    Invoke-Insert 'invoices' @{
        doctor_id    = $docUid
        patient_id   = $patUid
        patient_name = $patients[$inv.pIdx].name
        amount       = $inv.amount
        currency     = 'AED'
        status       = $inv.status
        paid_amount  = $inv.paid
        invoice_date = $invDate
        created_at   = $invDate
    } | Out-Null
    $invCount++
}
Write-Host "  [+] $invCount invoices seeded (paid + pending, currency AED)" -ForegroundColor Green
Write-Host ''

# =============================================================================
# STEP 6 -- EXPENSES
# =============================================================================

Write-Host '  STEP 6  Seeding Expenses' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

$expenseDefs = @(
    @{ dIdx=0; title='Ultrasound Machine Maintenance';      amount=1200; category='Equipment';  daysAgo=15 },
    @{ dIdx=0; title='Medical Supplies - Monthly Restock';  amount=680;  category='Supplies';   daysAgo=7  },
    @{ dIdx=0; title='Clinic Rent - June 2026';             amount=8500; category='Rent';       daysAgo=1  },
    @{ dIdx=1; title='Resistance Bands and Free Weights';   amount=450;  category='Equipment';  daysAgo=20 },
    @{ dIdx=1; title='Physiotherapy Table Cover Set';       amount=320;  category='Supplies';   daysAgo=10 },
    @{ dIdx=1; title='Professional Insurance Premium Q2';   amount=2800; category='Insurance';  daysAgo=30 },
    @{ dIdx=2; title='TENS Machine Replacement';            amount=950;  category='Equipment';  daysAgo=12 },
    @{ dIdx=2; title='Neurological Assessment Tool Kit';    amount=580;  category='Equipment';  daysAgo=5  },
    @{ dIdx=3; title='Elastic Bandages and Compression';    amount=290;  category='Supplies';   daysAgo=8  },
    @{ dIdx=3; title='CPD Training - Surgical Rehab';       amount=750;  category='Training';   daysAgo=25 },
    @{ dIdx=4; title='Pediatric Balance and Sensory Board'; amount=1100; category='Equipment';  daysAgo=18 },
    @{ dIdx=4; title='Sensory Integration Materials';       amount=420;  category='Supplies';   daysAgo=6  }
)

$expCount = 0
foreach ($exp in $expenseDefs) {
    $docUid = $doctorIds[$exp.dIdx]
    if (-not $docUid) { continue }
    $expDate = Get-TimeAgo $exp.daysAgo
    Invoke-Insert 'expenses' @{
        doctor_id  = $docUid
        title      = $exp.title
        amount     = $exp.amount
        category   = $exp.category
        date       = $expDate
        created_at = $expDate
    } | Out-Null
    $expCount++
}
Write-Host "  [+] $expCount expenses seeded" -ForegroundColor Green
Write-Host ''

# =============================================================================
# STEP 7 -- NOTIFICATIONS
# =============================================================================

Write-Host '  STEP 7  Seeding Patient Notifications' -ForegroundColor Yellow
Write-Host '  -----------------------------------------------' -ForegroundColor DarkGray

$notifDefs = @(
    @{ pIdx=0; type='appointment_scheduled'; isRead=$false; daysAgo=2;  title='Session Scheduled';           body='Your session with Dr. Sarah Mitchell is confirmed for Jun 7 at 9:00 AM.' },
    @{ pIdx=0; type='appointment_reminder';  isRead=$false; daysAgo=1;  title='Reminder: Session Tomorrow';  body='You have a core stabilisation session with Dr. Mitchell tomorrow at 11:00 AM.' },
    @{ pIdx=1; type='appointment_scheduled'; isRead=$false; daysAgo=3;  title='ACL Rehab Session Booked';    body='Dr. James Rodriguez confirmed your Phase 2 session for Jun 6 at 2:00 PM.' },
    @{ pIdx=1; type='appointment_accepted';  isRead=$true;  daysAgo=5;  title='Request Accepted';            body='Your appointment request was accepted by Dr. Rodriguez for Phase 2 training.' },
    @{ pIdx=2; type='doctor_added_you';      isRead=$true;  daysAgo=8;  title='Added to Patient List';       body='Dr. Emily Chen has added you to their patient list. You can now request sessions.' },
    @{ pIdx=2; type='appointment_reminder';  isRead=$false; daysAgo=1;  title='Therapy Session Tomorrow';    body='Your motor retraining session with Dr. Chen is at 10:00 AM tomorrow.' },
    @{ pIdx=3; type='appointment_scheduled'; isRead=$false; daysAgo=2;  title='Recovery Session Confirmed';  body='Your knee recovery session with Dr. Omar Hassan is set for Jun 7 at 3:00 PM.' },
    @{ pIdx=3; type='message';               isRead=$true;  daysAgo=3;  title='Message from Dr. Hassan';     body='Dr. Hassan: Great progress on your flexion range! Keep up with the home exercises.' },
    @{ pIdx=4; type='appointment_scheduled'; isRead=$false; daysAgo=1;  title='Motor Skills Session Booked'; body='Your next session with Dr. Layla Al-Farsi is set for Jun 11 at 9:00 AM.' },
    @{ pIdx=4; type='doctor_added_you';      isRead=$true;  daysAgo=10; title='Welcome to Little Steps';     body='Dr. Layla Al-Farsi has welcomed Ali to the Little Steps Clinic programme.' }
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
Write-Host "  [+] $notifCount notifications seeded (read + unread)" -ForegroundColor Green
Write-Host ''

# =============================================================================
# SUMMARY REPORT
# =============================================================================

Write-Host '  +------------------------------------------------+' -ForegroundColor Cyan
Write-Host '  |        ACCOUNTS CREATED -- LOGIN DETAILS       |' -ForegroundColor Cyan
Write-Host '  +------------------------------------------------+' -ForegroundColor Cyan
Write-Host ''

Write-Host '  DOCTOR ACCOUNTS  (password for all: PhysioDoc@2024!)' -ForegroundColor Yellow
Write-Host '  -------------------------------------------------------------------------------------------------------------------'
Write-Host '   #  Name                    Email                                  Password          Plan'
Write-Host '  -------------------------------------------------------------------------------------------------------------------'
for ($i = 0; $i -lt $doctors.Count; $i++) {
    $doc = $doctors[$i]
    $uid = if ($doctorIds[$i]) { $doctorIds[$i] } else { 'FAILED' }
    $num = " $($i+1) "
    $nm  = $doc.name.PadRight(22)
    $em  = $doc.email.PadRight(38)
    $pw  = 'PhysioDoc@2024!'.PadRight(18)
    Write-Host "  $num $nm $em $pw $($doc.plan_label)"
    Write-Host "       UUID: $uid" -ForegroundColor DarkGray
}
Write-Host '  -------------------------------------------------------------------------------------------------------------------'
Write-Host ''

Write-Host '  PATIENT ACCOUNTS  (password for all: Patient@2024!)' -ForegroundColor Yellow
Write-Host '  ------------------------------------------------------------------------------------------'
Write-Host '   #  Name                    Email                                  Password        Doctor'
Write-Host '  ------------------------------------------------------------------------------------------'
for ($i = 0; $i -lt $patients.Count; $i++) {
    $pat = $patients[$i]
    $uid = if ($patientIds[$i]) { $patientIds[$i] } else { 'FAILED' }
    $num = " $($i+1) "
    $nm  = $pat.name.PadRight(22)
    $em  = $pat.email.PadRight(38)
    $pw  = 'Patient@2024!'.PadRight(15)
    $dn  = $doctors[$pat.doctorIdx].name
    Write-Host "  $num $nm $em $pw $dn"
    Write-Host "       UUID: $uid" -ForegroundColor DarkGray
}
Write-Host '  ------------------------------------------------------------------------------------------'
Write-Host ''

Write-Host '  SEARCH BY LOCATION -- Doctor GPS Coordinates' -ForegroundColor Yellow
Write-Host '  -------------------------------------------------------------------------'
Write-Host '   #  Doctor                  Location                    Lat       Lng    Home'
Write-Host '  -------------------------------------------------------------------------'
for ($i = 0; $i -lt $doctors.Count; $i++) {
    $doc = $doctors[$i]
    $nm  = $doc.name.PadRight(22)
    $lc  = $doc.location_label.PadRight(26)
    $lat = "$($doc.latitude)".PadRight(9)
    $lng = "$($doc.longitude)".PadRight(7)
    $hv  = if ($doc.offers_home_visit) { 'Yes' } else { 'No' }
    Write-Host "   $($i+1)  $nm $lc $lat $lng $hv"
}
Write-Host '  -------------------------------------------------------------------------'
Write-Host ''

Write-Host '  SUBSCRIPTION PLANS' -ForegroundColor Yellow
Write-Host '  [1] Dr. Mitchell  : Premium  -- all features, expires 2026-12-31 (ACTIVE)'
Write-Host '  [2] Dr. Rodriguez : Premium  -- all features, expires 2026-12-31 (ACTIVE)'
Write-Host '  [3] Dr. Chen      : Basic    -- core tabs only, no expiry'
Write-Host '  [4] Dr. Hassan    : Basic    -- core tabs only, no expiry'
Write-Host '  [5] Dr. Al-Farsi  : Premium  -- all features, EXPIRED 2026-01-01 (tests account lockout)'
Write-Host ''

Write-Host '  DATA SEEDED' -ForegroundColor Yellow
Write-Host "  [+] $apptCount  appointments   (upcoming + past)"
Write-Host "  [+] $soapCount   SOAP notes     (detailed PT documentation per patient)"
Write-Host "  [+] $invCount  invoices        (paid + pending, AED)"
Write-Host "  [+] $expCount  expenses        (equipment / supplies / rent / insurance)"
Write-Host "  [+] $notifCount  notifications  (appointment / reminder / message types)"
Write-Host ''
Write-Host '  [OK] Seeding complete!' -ForegroundColor Green
Write-Host ''
