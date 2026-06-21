import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/form_factor_features.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import 'doctor_service.dart';

// ── Template model ─────────────────────────────────────────────────────────

class _Template {
  final String name;
  final Map<String, dynamic> data;
  const _Template({required this.name, required this.data});
}

final _templates = [
  _Template(name: 'Initial PT Assessment', data: {
    'chiefComplaint': 'Patient presents with ___ pain at ___.',
    'onsetDuration': 'Onset: ___ ago. Duration: ongoing.',
    'painLevel': 5,
    'painCharacteristics': 'Constant / intermittent. Sharp / dull / aching.',
    'aggravatingFactors': 'Prolonged standing, bending, lifting.',
    'relievingFactors': 'Rest, ice, positioning.',
    'functionalLimitations': 'Difficulty with ___, ADLs affected.',
    'patientGoals': 'Return to ___ without pain.',
    'medicalHistory': 'No prior surgeries. HTN / DM / ___.',
    'medications': 'NSAIDs / ___.',
    'observation': 'Patient appears comfortable/guarded. Posture: ___.',
    'rangeOfMotion': 'Flexion __°, Extension __°, Rotation R/L __/__°.',
    'strengthTesting': 'Strength ___/5 at ___.',
    'specialTests': '___: +/-.',
    'clinicalImpression': '___ dysfunction with functional limitations.',
    'severityStage': 'Mild / Moderate / Severe. Acute / Subacute / Chronic.',
    'prognosis': 'Good / Fair / Poor.',
    'interventions': 'Manual therapy, therapeutic exercise, modalities.',
    'frequencyDuration': '__ sessions/week × __ weeks.',
    'hep': 'Home exercises provided and demonstrated.',
  }),
  _Template(name: 'Lower Back Pain', data: {
    'chiefComplaint': 'Low back pain.',
    'onsetDuration': 'Onset: ___. Duration: ___.',
    'painLevel': 6,
    'painCharacteristics': 'Aching, worse with movement.',
    'aggravatingFactors': 'Prolonged sitting, bending, lifting.',
    'relievingFactors': 'Rest, lying supine.',
    'functionalLimitations': 'Difficulty sitting >__ min, bending, stairs.',
    'observation': 'Antalgic posture observed.',
    'palpation': 'Tenderness at L___–L___.',
    'rangeOfMotion':
        'Lumbar Flex __°, Ext __°, Lat Flex R/L __/__°.',
    'strengthTesting': 'Core: ___/5. Hip: ___/5.',
    'neurologicalExam': 'SLR: Neg/Pos. Sensation intact.',
    'specialTests': 'FABER: Neg/Pos. SLR: Neg/Pos.',
    'clinicalImpression': 'Mechanical low back pain.',
    'severityStage': 'Moderate. Subacute.',
    'responseToTreatment': 'To be assessed.',
    'prognosis': 'Good with compliance.',
    'treatmentFocus': 'Pain reduction, core stabilization, mobility.',
    'interventions': 'Manual therapy, core stabilization, McKenzie.',
    'frequencyDuration': '3×/week × 4 weeks.',
    'hep': 'Core bracing, pelvic tilts, neural flossing.',
    'followUp': 'Re-assess in 4 weeks.',
  }),
  _Template(name: 'Knee Rehabilitation', data: {
    'chiefComplaint': 'Knee pain / post-operative knee.',
    'onsetDuration': 'Surgery date: ___. / Injury: ___.',
    'painLevel': 5,
    'aggravatingFactors': 'Stairs, squatting, kneeling.',
    'functionalLimitations': 'Difficulty with stairs, prolonged walking.',
    'observation': 'Swelling: present/absent. Antalgic gait.',
    'palpation': 'Joint line tenderness: medial/lateral.',
    'rangeOfMotion': 'Flexion __°, Extension __°.',
    'strengthTesting': 'Quad ___/5, Hamstrings ___/5.',
    'specialTests': 'McMurray: +/-. Lachman: +/-. Patellar grind: +/-.',
    'clinicalImpression': 'Post-op/post-injury knee rehabilitation.',
    'severityStage': 'Phase: Early / Mid / Late rehabilitation.',
    'prognosis': 'Good with compliance.',
    'treatmentFocus': 'Quad strengthening, ROM restoration.',
    'interventions': 'Quad sets, SLR, stationary bike, CKC exercises.',
    'frequencyDuration': '3×/week × __ weeks.',
    'hep': 'Quad sets, heel slides, straight leg raises.',
    'followUp': 'Progress CKC when quad >4/5.',
  }),
  _Template(name: 'Shoulder Impingement', data: {
    'chiefComplaint': 'Shoulder pain at ___ region.',
    'onsetDuration': 'Onset: ___.',
    'painLevel': 5,
    'aggravatingFactors': 'Overhead activity, reaching behind back.',
    'relievingFactors': 'Rest, arm at side.',
    'functionalLimitations': 'Difficulty with overhead tasks, dressing.',
    'observation': 'Scapular dyskinesis: present/absent.',
    'rangeOfMotion': 'Flex __°, Abd __°, ER/IR __/__°.',
    'strengthTesting': 'RC ___/5. Scapular stabilizers ___/5.',
    'specialTests': 'Neer: +/-. Hawkins-Kennedy: +/-. Empty can: +/-.',
    'clinicalImpression': 'Subacromial impingement syndrome.',
    'severityStage': 'Mild/Moderate. Chronic.',
    'prognosis': 'Good with PT.',
    'treatmentFocus': 'RC strengthening, scapular stabilization.',
    'interventions': 'RC exercises, scapular retraction, postural correction.',
    'frequencyDuration': '2–3×/week × 4–6 weeks.',
    'hep': 'Theraband RC routine, scapular exercises.',
    'followUp': 'Review in 4 weeks.',
  }),
  _Template(name: 'Ankle Sprain', data: {
    'chiefComplaint': 'Ankle sprain — inversion/eversion injury.',
    'onsetDuration': 'Injury: ___.',
    'painLevel': 5,
    'painCharacteristics': 'Sharp at lateral/medial ankle.',
    'aggravatingFactors': 'Weight bearing, lateral stress.',
    'functionalLimitations': 'Limited weight bearing, difficulty walking.',
    'observation': 'Edema: present/absent. Ecchymosis: +/-.',
    'palpation': 'ATFL tenderness: +/-.',
    'rangeOfMotion': 'DF __°, PF __°, Inv/Ev __/__°.',
    'specialTests': 'Ottawa rules: Neg/Pos. Anterior drawer: +/-.',
    'clinicalImpression': 'Grade __ lateral/medial ankle sprain.',
    'severityStage': 'Acute. Grade I/II/III.',
    'treatmentFocus': 'Pain/edema control, proprioception.',
    'interventions': 'RICE, BAPS board, ankle strengthening.',
    'frequencyDuration': '2×/week × 3–4 weeks.',
    'hep': 'Ankle alphabet, towel scrunches, single-leg balance.',
    'followUp': 'Return to activity in __ weeks.',
  }),
  _Template(name: 'Cervical Pain / Neck', data: {
    'chiefComplaint': 'Neck pain +/- radiating to ___.',
    'onsetDuration': 'Onset: ___.',
    'painLevel': 5,
    'aggravatingFactors': 'Prolonged screen use, turning head.',
    'relievingFactors': 'Heat, rest, change of position.',
    'functionalLimitations': 'Difficulty driving, sleeping, desk work.',
    'observation': 'Forward head posture: present.',
    'rangeOfMotion': 'Flex __°, Ext __°, Rot R/L __/__°.',
    'neurologicalExam': 'Spurling: +/-. ULTT: +/-. Grip strength: ___.',
    'specialTests': 'Deep neck flexor endurance: __ sec.',
    'clinicalImpression': 'Cervical dysfunction +/- radiculopathy.',
    'prognosis': 'Good with posture correction and PT.',
    'treatmentFocus': 'Pain relief, DNF strengthening, posture.',
    'interventions': 'Manual therapy, DNF exercises, postural education.',
    'frequencyDuration': '2–3×/week × 4 weeks.',
    'hep': 'Chin tucks, cervical retraction, stretches.',
    'followUp': 'Ergonomic assessment recommended.',
  }),
  _Template(name: 'Post-Surgical Recovery', data: {
    'chiefComplaint': 'Post-operative rehabilitation.',
    'onsetDuration': 'Surgery: ___ (post-op week/day ___)',
    'painLevel': 4,
    'medicalHistory': 'Procedure: ___. Surgeon: ___.',
    'medications': 'Post-op analgesics: ___.',
    'observation': 'Scar: healing/healed. Wound: closed.',
    'palpation': 'Scar mobility: restricted/mobile.',
    'rangeOfMotion': '___',
    'strengthTesting': '___/5 at ___.',
    'clinicalImpression': 'Post-surgical rehabilitation, Phase ___.',
    'severityStage': 'On track / Behind milestones.',
    'barriers': 'Pain, swelling, fear of movement.',
    'treatmentFocus': 'Scar mobilization, ROM, progressive strengthening.',
    'interventions': 'Scar mobilization, AROM/PROM, strength per protocol.',
    'frequencyDuration': '__ sessions/week.',
    'hep': 'Protocol exercises as per surgeon guidelines.',
    'followUp': 'Next milestone: ___.',
  }),
  _Template(name: 'General Progress Note', data: {
    'chiefComplaint': 'Follow-up / progress session.',
    'painLevel': 3,
    'aggravatingFactors': 'Same as prior visit.',
    'relievingFactors': 'Improved with treatment.',
    'clinicalImpression': 'Progressing / Plateauing / Declining.',
    'progressTowardGoals': 'Goals: partially met / met / unmet.',
    'responseToTreatment': 'Positive / Fair / Poor response.',
    'treatmentFocus': 'Continue current plan / modify.',
    'interventions': 'Continue current plan. Modifications: ___.',
    'followUp': 'Next visit: ___.',
  }),
];

// ── Main Screen ────────────────────────────────────────────────────────────

class SoapNoteScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String? noteId;
  final Map<String, dynamic>? initialData;

  const SoapNoteScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.noteId,
    this.initialData,
  });

  @override
  State<SoapNoteScreen> createState() => _SoapNoteScreenState();
}

class _SoapNoteScreenState extends State<SoapNoteScreen>
    with SingleTickerProviderStateMixin {
  final _doctorService = DoctorService();
  late final TabController _tabController;
  bool _saving = false;

  // ── Subjective controllers ──────────────────────────────────────────────
  final _chiefComplaintCtrl = TextEditingController();
  final _onsetDurationCtrl = TextEditingController();
  int _painLevel = 5;
  final _painCharCtrl = TextEditingController();
  final _aggravatingCtrl = TextEditingController();
  final _relievingCtrl = TextEditingController();
  // Chip-picker selections (kept in sync with the text controllers above)
  final Set<String> _aggravatingSelected  = {};
  final Set<String> _relievingSelected    = {};
  final _functionalLimitCtrl = TextEditingController();
  final _patientGoalsCtrl = TextEditingController();
  final _medHistoryCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _socialContextCtrl = TextEditingController();

  // ── Objective controllers ───────────────────────────────────────────────
  final _observationCtrl = TextEditingController();
  final _palpationCtrl = TextEditingController();
  final _romCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController();
  final _neuroCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _specialTestsCtrl = TextEditingController();
  final _functionalTestsCtrl = TextEditingController();
  final _assistiveCtrl = TextEditingController();

  // ── Assessment controllers ──────────────────────────────────────────────
  final _clinicalImpressionCtrl = TextEditingController();
  final _severityCtrl = TextEditingController();
  // Chip selections for severity/stage (synced to _severityCtrl)
  String? _severitySelected; // 'Mild' | 'Moderate' | 'Severe'
  String? _stageSelected;    // 'Acute' | 'Subacute' | 'Chronic'
  final _progressCtrl = TextEditingController();
  final _barriersCtrl = TextEditingController();
  final _responseCtrl = TextEditingController();
  final _prognosisCtrl = TextEditingController();

  // ── Plan controllers ────────────────────────────────────────────────────
  final _treatmentFocusCtrl = TextEditingController();
  final _interventionsCtrl = TextEditingController();
  final _freqDurationCtrl = TextEditingController();
  final _hepCtrl = TextEditingController();
  final _referralsCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialData != null) {
      _prefillFromData(widget.initialData!);
    }
  }

  void _prefillFromData(Map<String, dynamic> d) {
    // Prefer the full soap_data jsonb blob if saved by the new code path
    final src = (d['soap_data'] as Map<String, dynamic>?) ?? d;
    String g(String k) => (src[k] as String?) ?? '';
    final isNew = src.containsKey('chiefComplaint');

    if (isNew) {
      _chiefComplaintCtrl.text = g('chiefComplaint');
      _onsetDurationCtrl.text  = g('onsetDuration');
      _painLevel               = (src['painLevel'] as int?) ?? 5;
      _painCharCtrl.text       = g('painCharacteristics');
      _aggravatingCtrl.text    = g('aggravatingFactors');
      _relievingCtrl.text      = g('relievingFactors');
      // Pre-select chips from saved comma-separated text
      _restoreChips(_aggravatingCtrl.text, _aggravatingSelected, _kAggravatingOptions);
      _restoreChips(_relievingCtrl.text,   _relievingSelected,   _kRelievingOptions);
      _functionalLimitCtrl.text = g('functionalLimitations');
      _patientGoalsCtrl.text   = g('patientGoals');
      _medHistoryCtrl.text     = g('medicalHistory');
      _medicationsCtrl.text    = g('medications');
      _socialContextCtrl.text  = g('socialContext');
      _observationCtrl.text    = g('observation');
      _palpationCtrl.text      = g('palpation');
      _romCtrl.text            = g('rangeOfMotion');
      _strengthCtrl.text       = g('strengthTesting');
      _neuroCtrl.text          = g('neurologicalExam');
      _balanceCtrl.text        = g('balanceCoordination');
      _specialTestsCtrl.text   = g('specialTests');
      _functionalTestsCtrl.text = g('functionalTests');
      _assistiveCtrl.text      = g('assistiveDevices');
      _clinicalImpressionCtrl.text = g('clinicalImpression');
      _severityCtrl.text       = g('severityStage');
      // Restore severity / stage chip selections from saved text
      final severityText = g('severityStage');
      for (final s in ['Mild', 'Moderate', 'Severe']) {
        if (severityText.contains(s)) { _severitySelected = s; break; }
      }
      for (final s in ['Acute', 'Subacute', 'Chronic']) {
        if (severityText.contains(s)) { _stageSelected = s; break; }
      }
      _progressCtrl.text       = g('progressTowardGoals');
      _barriersCtrl.text       = g('barriers');
      _responseCtrl.text       = g('responseToTreatment');
      _prognosisCtrl.text      = g('prognosis');
      _treatmentFocusCtrl.text = g('treatmentFocus');
      _interventionsCtrl.text  = g('interventions');
      _freqDurationCtrl.text   = g('frequencyDuration');
      _hepCtrl.text            = g('hep');
      _referralsCtrl.text      = g('referrals');
      _followUpCtrl.text       = g('followUp');
    } else {
      // Old 4-field format — map to closest new fields
      _chiefComplaintCtrl.text     = g('subjective').isNotEmpty
          ? g('subjective')
          : g('textNote');
      _romCtrl.text                = g('objective');
      _clinicalImpressionCtrl.text = g('assessment');
      _interventionsCtrl.text      = g('plan');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chiefComplaintCtrl.dispose();
    _onsetDurationCtrl.dispose();
    _painCharCtrl.dispose();
    _aggravatingCtrl.dispose();
    _relievingCtrl.dispose();
    _functionalLimitCtrl.dispose();
    _patientGoalsCtrl.dispose();
    _medHistoryCtrl.dispose();
    _medicationsCtrl.dispose();
    _socialContextCtrl.dispose();
    _observationCtrl.dispose();
    _palpationCtrl.dispose();
    _romCtrl.dispose();
    _strengthCtrl.dispose();
    _neuroCtrl.dispose();
    _balanceCtrl.dispose();
    _specialTestsCtrl.dispose();
    _functionalTestsCtrl.dispose();
    _assistiveCtrl.dispose();
    _clinicalImpressionCtrl.dispose();
    _severityCtrl.dispose();
    _progressCtrl.dispose();
    _barriersCtrl.dispose();
    _responseCtrl.dispose();
    _prognosisCtrl.dispose();
    _treatmentFocusCtrl.dispose();
    _interventionsCtrl.dispose();
    _freqDurationCtrl.dispose();
    _hepCtrl.dispose();
    _referralsCtrl.dispose();
    _followUpCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate(_Template t) {
    String s(String key) =>
        (t.data[key] as String?) ?? '';
    int i(String key, int def) =>
        (t.data[key] as int?) ?? def;

    setState(() {
      _chiefComplaintCtrl.text = s('chiefComplaint');
      _onsetDurationCtrl.text = s('onsetDuration');
      _painLevel = i('painLevel', 5);
      _painCharCtrl.text = s('painCharacteristics');
      _aggravatingCtrl.text = s('aggravatingFactors');
      _relievingCtrl.text = s('relievingFactors');
      _restoreChips(_aggravatingCtrl.text, _aggravatingSelected, _kAggravatingOptions);
      _restoreChips(_relievingCtrl.text,   _relievingSelected,   _kRelievingOptions);
      _functionalLimitCtrl.text = s('functionalLimitations');
      _patientGoalsCtrl.text = s('patientGoals');
      _medHistoryCtrl.text = s('medicalHistory');
      _medicationsCtrl.text = s('medications');
      _socialContextCtrl.text = s('socialContext');
      _observationCtrl.text = s('observation');
      _palpationCtrl.text = s('palpation');
      _romCtrl.text = s('rangeOfMotion');
      _strengthCtrl.text = s('strengthTesting');
      _neuroCtrl.text = s('neurologicalExam');
      _balanceCtrl.text = s('balanceCoordination');
      _specialTestsCtrl.text = s('specialTests');
      _functionalTestsCtrl.text = s('functionalTests');
      _assistiveCtrl.text = s('assistiveDevices');
      _clinicalImpressionCtrl.text = s('clinicalImpression');
      _severityCtrl.text = s('severityStage');
      final sev = s('severityStage');
      _severitySelected = ['Mild','Moderate','Severe'].firstWhere((v) => sev.contains(v), orElse: () => '');
      if (_severitySelected!.isEmpty) _severitySelected = null;
      _stageSelected = ['Acute','Subacute','Chronic'].firstWhere((v) => sev.contains(v), orElse: () => '');
      if (_stageSelected!.isEmpty) _stageSelected = null;
      _progressCtrl.text = s('progressTowardGoals');
      _barriersCtrl.text = s('barriers');
      _responseCtrl.text = s('responseToTreatment');
      _prognosisCtrl.text = s('prognosis');
      _treatmentFocusCtrl.text = s('treatmentFocus');
      _interventionsCtrl.text = s('interventions');
      _freqDurationCtrl.text = s('frequencyDuration');
      _hepCtrl.text = s('hep');
      _referralsCtrl.text = s('referrals');
      _followUpCtrl.text = s('followUp');
    });
  }

  Future<void> _save(AppStrings s) async {
    if (_chiefComplaintCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Please fill in at least the Chief Complaint / الشكوى الرئيسية.')));
      return;
    }
    setState(() => _saving = true);

    final soapData = <String, dynamic>{
      'chiefComplaint': _chiefComplaintCtrl.text.trim(),
      'onsetDuration': _onsetDurationCtrl.text.trim(),
      'painLevel': _painLevel,
      'painCharacteristics': _painCharCtrl.text.trim(),
      'aggravatingFactors': _aggravatingCtrl.text.trim(),
      'relievingFactors': _relievingCtrl.text.trim(),
      'functionalLimitations': _functionalLimitCtrl.text.trim(),
      'patientGoals': _patientGoalsCtrl.text.trim(),
      'medicalHistory': _medHistoryCtrl.text.trim(),
      'medications': _medicationsCtrl.text.trim(),
      'socialContext': _socialContextCtrl.text.trim(),
      'observation': _observationCtrl.text.trim(),
      'palpation': _palpationCtrl.text.trim(),
      'rangeOfMotion': _romCtrl.text.trim(),
      'strengthTesting': _strengthCtrl.text.trim(),
      'neurologicalExam': _neuroCtrl.text.trim(),
      'balanceCoordination': _balanceCtrl.text.trim(),
      'specialTests': _specialTestsCtrl.text.trim(),
      'functionalTests': _functionalTestsCtrl.text.trim(),
      'assistiveDevices': _assistiveCtrl.text.trim(),
      'clinicalImpression': _clinicalImpressionCtrl.text.trim(),
      'severityStage': _severityCtrl.text.trim(),
      'progressTowardGoals': _progressCtrl.text.trim(),
      'barriers': _barriersCtrl.text.trim(),
      'responseToTreatment': _responseCtrl.text.trim(),
      'prognosis': _prognosisCtrl.text.trim(),
      'treatmentFocus': _treatmentFocusCtrl.text.trim(),
      'interventions': _interventionsCtrl.text.trim(),
      'frequencyDuration': _freqDurationCtrl.text.trim(),
      'hep': _hepCtrl.text.trim(),
      'referrals': _referralsCtrl.text.trim(),
      'followUp': _followUpCtrl.text.trim(),
      // keep legacy fields for any backward-compat queries
      'subjective': _chiefComplaintCtrl.text.trim(),
      'objective': _romCtrl.text.trim(),
      'assessment': _clinicalImpressionCtrl.text.trim(),
      'plan': _interventionsCtrl.text.trim(),
    };

    bool ok;
    if (widget.noteId != null) {
      ok = await _doctorService.updateSoapNote(widget.noteId!, soapData);
    } else {
      ok = await _doctorService.submitSoapNoteData(
        patientId: widget.patientId,
        patientName: widget.patientName,
        soapData: soapData,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.noteId != null ? 'Note updated!' : s.notePublished),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to save note. Please try again.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _showTemplates(AppStrings s) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(s.soapTemplates,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _templates.length,
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(_templates[i].name),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  _applyTemplate(_templates[i]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);
    final isMobile = FormFactorFeatures.of(context).isMobile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.noteId != null ? 'Edit SOAP Note' : s.soapNotes,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(widget.patientName,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w400,
                    color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showTemplates(s),
            icon: const Icon(Icons.library_books_rounded,
                color: Colors.white, size: 18),
            label: Text(s.useTemplate,
                style:
                    const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
        // Mobile uses a vertical accordion instead of these tabs (the
        // single-letter tab labels overflow the AppBar's TabBar at narrow
        // widths) — see _buildMobileAccordion. Desktop TabBar is unchanged.
        bottom: isMobile
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(
                    child: _SectionTabLabel(
                        letter: 'S', title: 'Subjective', color: Colors.blue),
                  ),
                  Tab(
                    child: _SectionTabLabel(
                        letter: 'O', title: 'Objective', color: Colors.green),
                  ),
                  Tab(
                    child: _SectionTabLabel(
                        letter: 'A', title: 'Assessment', color: Colors.orange),
                  ),
                  Tab(
                    child: _SectionTabLabel(
                        letter: 'P', title: 'Plan', color: Colors.purple),
                  ),
                ],
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isMobile
                ? _buildMobileAccordion()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSubjectiveTab(),
                      _buildObjectiveTab(),
                      _buildAssessmentTab(),
                      _buildPlanTab(),
                    ],
                  ),
          ),
          // ── Save button ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: Icon(widget.noteId != null
                            ? Icons.save_rounded
                            : Icons.publish_rounded),
                        label: Text(
                          widget.noteId != null ? 'Save Changes' : s.publishNote,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _save(s),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────

  static const _kAggravatingOptions = [
    'Sitting', 'Standing', 'Walking', 'Bending', 'Lifting',
    'Running', 'Stairs', 'Sleeping', 'Coughing/Sneezing', 'Driving',
  ];
  static const _kRelievingOptions = [
    'Rest', 'Ice', 'Heat', 'Medication', 'Positioning',
    'Exercise', 'Massage', 'Physiotherapy', 'Elevation', 'Compression',
  ];

  void _syncAggravating() {
    final custom = _aggravatingCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !_kAggravatingOptions.contains(s))
        .join(', ');
    final chips = _aggravatingSelected.join(', ');
    _aggravatingCtrl.text =
        [chips, if (custom.isNotEmpty) custom].join(custom.isNotEmpty && chips.isNotEmpty ? ', ' : '');
  }

  void _syncRelieving() {
    final custom = _relievingCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !_kRelievingOptions.contains(s))
        .join(', ');
    final chips = _relievingSelected.join(', ');
    _relievingCtrl.text =
        [chips, if (custom.isNotEmpty) custom].join(custom.isNotEmpty && chips.isNotEmpty ? ', ' : '');
  }

  /// Parses a saved comma-separated string and pre-selects any values that
  /// appear in [knownOptions], leaving unknown values in the text controller.
  void _restoreChips(String saved, Set<String> target, List<String> knownOptions) {
    target.clear();
    for (final part in saved.split(',').map((s) => s.trim())) {
      if (knownOptions.contains(part)) target.add(part);
    }
  }

  void _syncSeverity() {
    final parts = [
      if (_severitySelected != null) _severitySelected!,
      if (_stageSelected    != null) _stageSelected!,
    ];
    if (parts.isNotEmpty) _severityCtrl.text = parts.join('. ');
  }

  List<Widget> _subjectiveFields(Color color) => [
        _subField('Chief Complaint', 'الشكوى الرئيسية',
            _chiefComplaintCtrl, color, lines: 2),
        _subField('Onset & Duration', 'بداية ومدة الأعراض',
            _onsetDurationCtrl, color),
        _painSliderField(color),
        _subField('Pain Characteristics', 'خصائص الألم',
            _painCharCtrl, color),
        _chipPickerField(
          'Aggravating Factors', 'العوامل المؤلمة',
          _kAggravatingOptions, _aggravatingSelected, _syncAggravating, color,
        ),
        _chipPickerField(
          'Relieving Factors', 'العوامل المؤدية للراحة',
          _kRelievingOptions, _relievingSelected, _syncRelieving, color,
        ),
        _subField('Functional Limitations', 'القيود الوظيفية',
            _functionalLimitCtrl, color),
        _subField('Patient Goals', 'أهداف المريض',
            _patientGoalsCtrl, color),
        _subField('Medical & Surgical History', 'التاريخ الطبي والجراحي',
            _medHistoryCtrl, color),
        _subField('Medications', 'الأدوية',
            _medicationsCtrl, color),
        _subField('Social & Occupational Context', 'السياق الاجتماعي والمهني',
            _socialContextCtrl, color),
      ];

  Widget _buildSubjectiveTab() {
    final color = Colors.blue.shade700;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _sectionHeader('S', 'Subjective', 'الملاحظات الذاتية', color),
        const SizedBox(height: 14),
        ..._subjectiveFields(color),
      ]),
    );
  }

  List<Widget> _objectiveFields(Color color) => [
        _subField('Observation', 'الملاحظة',
            _observationCtrl, color),
        _subField('Palpation', 'الجس',
            _palpationCtrl, color),
        _subField('Range of Motion (ROM)', 'مدى الحركة',
            _romCtrl, color, lines: 3),
        _subField('Strength Testing', 'اختبار القوة',
            _strengthCtrl, color),
        _subField('Neurological Exam', 'الفحص العصبي',
            _neuroCtrl, color),
        _subField('Balance & Coordination', 'التوازن والتنسيق',
            _balanceCtrl, color),
        _subField('Special Tests', 'الفحوصات الخاصة',
            _specialTestsCtrl, color),
        _subField('Functional Tests', 'الفحوصات الوظيفية',
            _functionalTestsCtrl, color),
        _subField('Assistive Devices', 'الأجهزة المساعدة',
            _assistiveCtrl, color),
      ];

  Widget _buildObjectiveTab() {
    final color = Colors.green.shade700;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _sectionHeader('O', 'Objective', 'الفحص الموضوعي', color),
        const SizedBox(height: 14),
        ..._objectiveFields(color),
      ]),
    );
  }

  List<Widget> _assessmentFields(Color color) => [
        _subField('Clinical Impression', 'الانطباع السريري',
            _clinicalImpressionCtrl, color, lines: 2),
        _severityStageField(color),
        _subField('Progress Toward Goals', 'التقدم نحو الأهداف',
            _progressCtrl, color),
        _subField('Barriers', 'العوائق',
            _barriersCtrl, color),
        _subField('Response to Treatment', 'الاستجابة للعلاج',
            _responseCtrl, color),
        _subField('Prognosis', 'التوقعات المستقبلية',
            _prognosisCtrl, color),
      ];

  Widget _buildAssessmentTab() {
    final color = Colors.orange.shade700;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _sectionHeader('A', 'Assessment', 'التقييم', color),
        const SizedBox(height: 14),
        ..._assessmentFields(color),
      ]),
    );
  }

  List<Widget> _planFields(Color color) => [
        _subField('Treatment Focus', 'محاور العلاج',
            _treatmentFocusCtrl, color),
        _subField('Interventions', 'التدخلات العلاجية',
            _interventionsCtrl, color, lines: 3),
        _subField('Frequency & Duration', 'عدد الجلسات والمدة',
            _freqDurationCtrl, color),
        _subField('Home Exercise Program (HEP)', 'برنامج التمارين المنزلية',
            _hepCtrl, color, lines: 3),
        _subField('Referrals', 'الإحالات',
            _referralsCtrl, color),
        _subField('Follow-up', 'المتابعة',
            _followUpCtrl, color),
      ];

  Widget _buildPlanTab() {
    final color = Colors.purple.shade700;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _sectionHeader('P', 'Plan', 'الخطة العلاجية', color),
        const SizedBox(height: 14),
        ..._planFields(color),
      ]),
    );
  }

  // ── Mobile: vertical accordion (replaces TabBar/TabBarView) ────────────────

  /// Mobile replacement for the desktop TabBar/TabBarView. Each SOAP section
  /// becomes a collapsible card sharing the same fields and styling as the
  /// desktop tabs, so editing stays fully available on mobile. Desktop's
  /// TabBar/TabBarView path above is unchanged.
  Widget _buildMobileAccordion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _accordionSection(
          letter: 'S',
          enTitle: 'Subjective',
          arTitle: 'الملاحظات الذاتية',
          color: Colors.blue.shade700,
          initiallyExpanded: true,
          fields: _subjectiveFields(Colors.blue.shade700),
        ),
        const SizedBox(height: 12),
        _accordionSection(
          letter: 'O',
          enTitle: 'Objective',
          arTitle: 'الفحص الموضوعي',
          color: Colors.green.shade700,
          fields: _objectiveFields(Colors.green.shade700),
        ),
        const SizedBox(height: 12),
        _accordionSection(
          letter: 'A',
          enTitle: 'Assessment',
          arTitle: 'التقييم',
          color: Colors.orange.shade700,
          fields: _assessmentFields(Colors.orange.shade700),
        ),
        const SizedBox(height: 12),
        _accordionSection(
          letter: 'P',
          enTitle: 'Plan',
          arTitle: 'الخطة العلاجية',
          color: Colors.purple.shade700,
          fields: _planFields(Colors.purple.shade700),
        ),
      ]),
    );
  }

  Widget _accordionSection({
    required String letter,
    required String enTitle,
    required String arTitle,
    required Color color,
    required List<Widget> fields,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: color.withValues(alpha: 0.08),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            iconColor: color,
            collapsedIconColor: color,
            title: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(letter,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(enTitle,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: color)),
                    Text(arTitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: color.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ]),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(children: fields),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _sectionHeader(
      String letter, String enTitle, String arTitle, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(letter,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(enTitle,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color)),
          Text(arTitle,
              style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.7))),
        ]),
      ]),
    );
  }

  Widget _subField(
      String en, String ar, TextEditingController ctrl, Color color,
      {int lines = 2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: en,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontSize: 13),
                ),
                TextSpan(
                  text: '  /  $ar',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            maxLines: lines,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: color.withValues(alpha: 0.3))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: color, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _painSliderField(Color color) {
    Color indicatorColor() {
      if (_painLevel <= 3) return Colors.green.shade600;
      if (_painLevel <= 6) return Colors.orange.shade600;
      return Colors.red.shade600;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Pain Level (0–10)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontSize: 13),
                ),
                TextSpan(
                  text: '  /  مستوى الألم',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: indicatorColor(),
                    inactiveTrackColor:
                        indicatorColor().withValues(alpha: 0.2),
                    thumbColor: indicatorColor(),
                    overlayColor:
                        indicatorColor().withValues(alpha: 0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _painLevel.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    onChanged: (v) =>
                        setState(() => _painLevel = v.round()),
                  ),
                ),
              ),
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: indicatorColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_painLevel/10',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Chip multi-picker (aggravating / relieving factors) ───────────────────

  Widget _chipPickerField(
    String en,
    String ar,
    List<String> options,
    Set<String> selected,
    VoidCallback onChanged,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: en,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: color, fontSize: 13),
              ),
              TextSpan(
                text: '  /  $ar',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: options.map((opt) {
                final isSelected = selected.contains(opt);
                return FilterChip(
                  label: Text(opt,
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? color : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400)),
                  selected: isSelected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      selected.add(opt);
                    } else {
                      selected.remove(opt);
                    }
                    onChanged();
                  }),
                  selectedColor: color.withValues(alpha: 0.15),
                  checkmarkColor: color,
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(
                      color: isSelected
                          ? color.withValues(alpha: 0.5)
                          : Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: true,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Severity & Stage chip selectors ──────────────────────────────────────

  Widget _severityStageField(Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: 'Severity & Stage',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: color, fontSize: 13),
              ),
              TextSpan(
                text: '  /  شدة ومرحلة الحالة',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Severity row
                Text('Severity',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: ['Mild', 'Moderate', 'Severe'].map((opt) {
                    final sel = _severitySelected == opt;
                    final chipColor = switch (opt) {
                      'Mild'     => Colors.green.shade600,
                      'Moderate' => Colors.orange.shade700,
                      _          => Colors.red.shade600,
                    };
                    return ChoiceChip(
                      label: Text(opt,
                          style: TextStyle(
                              fontSize: 12,
                              color: sel ? chipColor : Colors.grey.shade700,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.w400)),
                      selected: sel,
                      onSelected: (_) => setState(() {
                        _severitySelected = sel ? null : opt;
                        _syncSeverity();
                      }),
                      selectedColor: chipColor.withValues(alpha: 0.15),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(
                          color: sel
                              ? chipColor.withValues(alpha: 0.5)
                              : Colors.grey.shade300),
                      checkmarkColor: chipColor,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                // Stage row
                Text('Stage',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: ['Acute', 'Subacute', 'Chronic'].map((opt) {
                    final sel = _stageSelected == opt;
                    return ChoiceChip(
                      label: Text(opt,
                          style: TextStyle(
                              fontSize: 12,
                              color: sel ? color : Colors.grey.shade700,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.w400)),
                      selected: sel,
                      onSelected: (_) => setState(() {
                        _stageSelected = sel ? null : opt;
                        _syncSeverity();
                      }),
                      selectedColor: color.withValues(alpha: 0.15),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(
                          color: sel
                              ? color.withValues(alpha: 0.5)
                              : Colors.grey.shade300),
                      checkmarkColor: color,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab label widget ───────────────────────────────────────────────────────

class _SectionTabLabel extends StatelessWidget {
  final String letter;
  final String title;
  final Color color;

  const _SectionTabLabel({
    required this.letter,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(letter,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
