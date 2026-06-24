import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ai/ai_service.dart';
import '../ai/clinic_analytics_sheet.dart';

import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/excel_compat.dart';
import 'location_picker_screen.dart';
import '../../core/config/form_factor_features.dart';
import '../../core/widgets/patient_search_field.dart';
import '../../core/widgets/lebanon_phone_field.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/subscription_model.dart';
import '../../core/providers/language_provider.dart';
import 'create_patient_screen.dart';
import 'soap_note_screen.dart';
import 'session_stats_screen.dart';
import '../hep/screens/hep_builder_screen.dart';
import 'billing_screen.dart';
import 'expenses_screen.dart';
import 'doctor_service.dart';
import 'import_help_sheet.dart';
import '../store/doctor_storefront_screen.dart';
import '../auth/auth_service.dart';
import 'assessment_library/assessment_library_screen.dart';
import 'doctor_notifications_tab.dart';

// ── Unified import row (patients + schedule + revenues) ───────────────────

class _UnifiedRow {
  final String    name;
  final DateTime? date;
  final double?   amount;    // null = schedule-only row
  final String    service;
  final String    statusKey; // 'pending' | 'paid' | 'partially_paid' | 'cancelled'
  final String    note;
  bool    selected  = true;
  String? patientId;         // null = unmatched → will create new patient

  _UnifiedRow({
    required this.name,
    this.date,
    this.amount,
    this.service   = 'Physical Therapy',
    this.statusKey = 'pending',
    this.note      = '',
  });

  bool get hasDate   => date != null;
  bool get hasAmount => amount != null && amount! > 0;
}

// ─────────────────────────────────────────────────────────────────────────────

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final _service = DoctorService();

  // Profile
  final _nameCtrl          = TextEditingController();
  final _bioCtrl           = TextEditingController();
  final _photoCtrl         = TextEditingController();
  final _specCtrl          = TextEditingController();
  final _clinicNameCtrl    = TextEditingController();
  final _clinicAddrCtrl    = TextEditingController();
  final _workingHoursCtrl  = TextEditingController();
  final _phoneCtrl         = TextEditingController();
  bool _homeVisit       = false;
  bool _profileLoaded   = false;
  bool _deletingAccount = false;
  bool _showDrPrefix    = false;
  // 'none' | 'pending' | 'approved' | 'declined'
  String _drPrefixStatus    = 'none';
  String _nameChangeRequest = 'none';
  String _pendingName       = '';
  double? _lat;
  double? _lng;
  ValueNotifier<({double pct, String label})>? _importProgress;

  // Navigation – order: Schedule | Documentation | My Patients | Statistics |
  //                     Billing | Expenses | My Profile | Notifications | Store | Assessment
  int _currentIndex = 0;
  bool _showHome = true; // landing home screen
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Bottom nav (mobile) — 4 positions → section tab indices
  // 0=Schedule  1=Patients  2=Finance  3=More(opens drawer)
  int get _bottomNavIndex {
    switch (_currentIndex) {
      case 0: return 0;
      case 2: return 1;
      case 4: return 2;
      default: return 3; // "More" catches all other tabs (incl. Documentation, which is drawer-only on mobile)
    }
  }

  // Subscription
  SubConfig _sub = SubConfig.defaultsFor(SubTier.basic);
  StreamSubscription<List<Map<String, dynamic>>>? _subListener;
  StreamSubscription<List<Map<String, dynamic>>>? _notifListener;
  StreamSubscription<List<Map<String, dynamic>>>? _patientsListener;
  // null = stream not yet received; true/false = confirmed state
  bool? _hasPatients;
  Timer? _expiryTimer;
  // Tracks last-known expiry state so the 30-s timer only triggers a rebuild
  // when the value actually changes, avoiding unnecessary full-tree rebuilds.
  bool _wasExpired = false;

  static const List<IconData> _navIcons = [
    Icons.calendar_today_rounded,         // 0 Schedule
    Icons.description_rounded,            // 1 Documentation
    Icons.people_alt_rounded,             // 2 My Patients
    Icons.bar_chart_rounded,              // 3 Statistics
    Icons.receipt_long_rounded,           // 4 Revenues
    Icons.receipt_rounded,                // 5 Expenses
    Icons.badge_rounded,                  // 6 My Profile
    Icons.notifications_rounded,          // 7 Notifications
    Icons.workspace_premium_rounded,      // 8 PhysioGate (doctor only)
    Icons.assignment_rounded,             // 9 Assessment Library
  ];

  int _doctorUnreadCount = 0;
  final Set<String> _seenNotifIds = {};
  bool _notifStreamInitialized = false;

  List<IconData> get _allNavIcons => _navIcons;
  List<Color> get _allTileColors => _tileColors;

  // Calendar state
  late DateTime _calMonth;
  late DateTime _calDay;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      _subListener = Supabase.instance.client
          .from('users').stream(primaryKey: ['id']).eq('id', uid)
          .listen((list) {
        if (list.isNotEmpty && mounted) {
          final d = list.first;
          setState(() {
            _sub               = SubConfig.fromMap(d);
            _showDrPrefix      = (d['show_dr_prefix']      as bool?)   ?? false;
            _drPrefixStatus    = (d['dr_prefix_request']   as String?) ?? 'none';
            _nameChangeRequest = (d['name_change_request'] as String?) ?? 'none';
            _pendingName       = (d['pending_name']        as String?) ?? '';
            final newName      = (d['name'] as String?) ?? '';
            if (newName.isNotEmpty) _nameCtrl.text = newName;
            if (!_sub.allowHomeVisit) _homeVisit = false;
          });
          _checkExpiryNotification();
        }
      });
      _patientsListener = _service.getAssignedPatients().listen((list) {
        if (mounted) setState(() => _hasPatients = list.isNotEmpty);
      });
      _notifListener = Supabase.instance.client
          .from('notifications').stream(primaryKey: ['id'])
          .eq('recipient_id', uid)
          .listen((list) {
        if (!mounted) return;
        if (_notifStreamInitialized) {
          for (final n in list) {
            final id = n['id'] as String;
            if (!_seenNotifIds.contains(id)) _showNotifPopup(n);
          }
        }
        _notifStreamInitialized = true;
        _seenNotifIds.addAll(list.map((n) => n['id'] as String));
        setState(() {
          _doctorUnreadCount = list.where(
              (n) => !(n['read'] as bool? ?? false)).length;
        });
      });
    }
    final now = DateTime.now();
    _calMonth = DateTime(now.year, now.month);
    _calDay   = DateTime(now.year, now.month, now.day);

    // Re-check subscription expiry periodically so the account is
    // locked out the moment `expires_at` passes, even with no other
    // realtime updates triggering a rebuild.
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final nowExpired = _sub.isExpired;
      if (nowExpired != _wasExpired) {
        setState(() => _wasExpired = nowExpired);
      }
    });
  }

  @override
  void dispose() {
    _subListener?.cancel();
    _notifListener?.cancel();
    _patientsListener?.cancel();
    _expiryTimer?.cancel();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _photoCtrl.dispose();
    _specCtrl.dispose();
    _clinicNameCtrl.dispose();
    _clinicAddrCtrl.dispose();
    _workingHoursCtrl.dispose();
    _phoneCtrl.dispose();
    _importProgress?.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    if (_profileLoaded) return;
    final doc = await _service.getMyProfile();
    if (!mounted) return;
    if (doc != null) {
      final d = doc;
      _nameCtrl.text       = d['name'] ?? '';
      _bioCtrl.text        = d['bio'] ?? '';
      _photoCtrl.text      = d['profile_photo_url'] ?? '';
      _specCtrl.text       = d['specialization'] ?? '';
      _clinicNameCtrl.text   = d['clinic_name'] ?? '';
      _clinicAddrCtrl.text   = d['clinic_address'] ?? '';
      _workingHoursCtrl.text = d['working_hours'] ?? '';
      _phoneCtrl.text = LebanonPhoneField.stripCountryCode(d['phone'] ?? '');
      setState(() {
        _homeVisit       = d['offers_home_visit'] ?? false;
        _profileLoaded   = true;
        _lat             = (d['latitude']  as num?)?.toDouble();
        _lng             = (d['longitude'] as num?)?.toDouble();
        _showDrPrefix       = d['show_dr_prefix']      as bool?   ?? false;
        _drPrefixStatus     = d['dr_prefix_request']   as String? ?? 'none';
        _nameChangeRequest  = d['name_change_request'] as String? ?? 'none';
        _pendingName        = d['pending_name']         as String? ?? '';
      });
    }
  }

  Future<void> _requestDrPrefix() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client
        .from('users')
        .update({'dr_prefix_request': 'pending'})
        .eq('id', uid);
    if (mounted) setState(() => _drPrefixStatus = 'pending');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Request sent — awaiting admin approval'),
        backgroundColor: Color(0xFF1565C0),
      ));
    }
  }

  Future<void> _cancelDrPrefixRequest() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client
        .from('users')
        .update({'dr_prefix_request': null, 'show_dr_prefix': false})
        .eq('id', uid);
    if (mounted) {
      setState(() {
        _drPrefixStatus = 'none';
        _showDrPrefix   = false;
      });
    }
  }

  Future<void> _requestNameChange(String newName) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('users').update({
      'pending_name':        newName.trim(),
      'name_change_request': 'pending',
    }).eq('id', uid);
    if (mounted) {
      setState(() {
        _pendingName       = newName.trim();
        _nameChangeRequest = 'pending';
      });
    }
  }

  Future<void> _cancelNameChangeRequest() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('users').update({
      'pending_name':        null,
      'name_change_request': null,
    }).eq('id', uid);
    if (mounted) {
      setState(() {
        _pendingName       = '';
        _nameChangeRequest = 'none';
      });
    }
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Flexible(child: Text(message,
                  style: const TextStyle(fontSize: 14))),
            ]),
          ),
        ),
      ),
    );
  }

  void _hideLoading() {
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  // ── Import progress dialog ─────────────────────────────────────────────────

  void _showImportProgress() {
    _importProgress?.dispose();
    _importProgress = ValueNotifier((pct: 0.0, label: 'Starting…'));
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: ValueListenableBuilder<({double pct, String label})>(
              valueListenable: _importProgress!,
              builder: (_, prog, __) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Importing…',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: prog.pct,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(prog.label,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ),
                      Text('${(prog.pct * 100).round()}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setProgress(double pct, String label) {
    _importProgress?.value = (pct: pct.clamp(0.0, 1.0), label: label);
  }

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
      _showHome = false;
    });
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _goHome() => setState(() => _showHome = true);

  bool _isLocked(int index) => _sub.isLocked(index);

  // ── AI Doctor Assistant header action ─────────────────────────────────────

  void _showAiAssistantSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF6A1B9A), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Doctor Assistant',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  Text('What would you like help with?',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            _aiActionTile(
              ctx: ctx,
              icon: Icons.description_rounded,
              color: const Color(0xFF2E7D32),
              title: 'Generate SOAP Documentation',
              subtitle: 'AI-assisted clinical note for a patient',
              onTap: () {
                Navigator.pop(ctx);
                _navigateTo(1); // Documentation tab
              },
            ),
            const SizedBox(height: 10),
            _aiActionTile(
              ctx: ctx,
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFF57F17),
              title: 'Analyze Revenue & Expenses',
              subtitle: 'AI insights on your clinic finances',
              onTap: () {
                Navigator.pop(ctx);
                showClinicAnalyticsSheet(context);
              },
            ),
            const SizedBox(height: 10),
            _aiActionTile(
              ctx: ctx,
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF00695C),
              title: 'Statistics & Performance',
              subtitle: 'Business analytics and session trends',
              onTap: () {
                Navigator.pop(ctx);
                showClinicAnalyticsSheet(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiActionTile({
    required BuildContext ctx,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.6), size: 20),
          ]),
        ),
      );

  // ── Expiry notification (5-day warning, once per day) ─────────────────────

  Future<void> _checkExpiryNotification() async {
    final expires = _sub.expiresAt;
    if (expires == null) return;
    final now = DateTime.now();
    final daysLeft = expires.difference(now).inDays;
    if (daysLeft < 0 || daysLeft > 5) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    // Check if we already sent a reminder today
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    try {
      final existing = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('recipient_id', uid)
          .eq('type', 'subscription_expiry')
          .gte('created_at', '${todayStr}T00:00:00')
          .limit(1);
      if ((existing as List).isNotEmpty) return; // already sent today

      final body = daysLeft == 0
          ? 'Your subscription expires today. Contact your administrator to renew.'
          : 'Your subscription expires in $daysLeft day${daysLeft == 1 ? '' : 's'}. Contact your administrator to renew.';

      await Supabase.instance.client.from('notifications').insert({
        'recipient_id': uid,
        'title':        'Subscription Expiring Soon',
        'body':         body,
        'type':         'subscription_expiry',
        'read':         false,
      });
    } catch (_) {
      // Non-fatal — silently ignore if notifications table has different schema
    }
  }

  void _changeCalMonth(int delta) {
    setState(() {
      _calMonth = DateTime(_calMonth.year, _calMonth.month + delta);
      final now = DateTime.now();
      if (now.year == _calMonth.year && now.month == _calMonth.month) {
        _calDay = DateTime(now.year, now.month, now.day);
      } else {
        _calDay = DateTime(_calMonth.year, _calMonth.month, 1);
      }
    });
  }

Future<void> _showLogout([AppStrings? overrideStrings]) async {
    final s = overrideStrings ??
        AppStrings(context.read<LanguageProvider>().isArabic);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.logout),
        content: Text(s.areYouSure),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
            },
            child: Text(s.signOut,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final s = AppStrings(langProvider.isArabic);

    final dir = langProvider.isArabic ? TextDirection.rtl : TextDirection.ltr;

    // ── Account inactive / expired overlay ───────────────────────────────────
    if (!_sub.isActive) {
      final expired = _sub.isExpired;
      return Directionality(
        textDirection: dir,
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F4F8),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: expired
                        ? const Color(0xFFFBE9E7)
                        : const Color(0xFFECEFF1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    expired
                        ? Icons.timer_off_rounded
                        : Icons.lock_outline_rounded,
                    size: 54,
                    color: expired
                        ? const Color(0xFFE65100)
                        : const Color(0xFF546E7A),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  expired
                      ? 'Account Expired'
                      : 'Account Not Activated',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  expired
                      ? 'Your subscription has expired on '
                        '${_sub.expiresAt!.day}/${_sub.expiresAt!.month}/${_sub.expiresAt!.year}. '
                        'Please contact the administrator to renew your plan.'
                      : 'Your account is pending activation. '
                        'Please contact the administrator to enable your account and choose a plan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(s.logout),
                  onPressed: () =>
                      Supabase.instance.client.auth.signOut(),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    // ── Home landing screen ──────────────────────────────────────────────────
    if (_showHome) {
      return Directionality(
        textDirection: dir,
        child: Scaffold(
          body: _buildHomeScreen(s, langProvider),
        ),
      );
    }

    // ── Section screens ──────────────────────────────────────────────────────
    final sections = [
      s.schedule,
      s.documentation,
      s.myPatients,
      s.statistics,
      s.billing,
      s.expenses,
      s.myProfile,
      s.notifications,
      s.store,
      s.assessmentLibrary,
    ];

    final isMobile = FormFactorFeatures.of(context).isMobile;

    return Directionality(
      textDirection: dir,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: _goHome,
          ),
          title: Text(sections[_currentIndex],
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18)),
          actions: [
            TextButton.icon(
              onPressed: langProvider.toggle,
              icon: const Icon(Icons.language_rounded,
                  color: Colors.white70, size: 18),
              label: Text(s.language,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _showLogout(s),
            ),
          ],
        ),
        drawer: _buildNavDrawer(s, sections),
        // ── Bottom nav (mobile only) ─────────────────────────────────────
        bottomNavigationBar: isMobile
            ? NavigationBar(
                selectedIndex: _bottomNavIndex,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.primary.withValues(alpha: 0.12),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                height: 64,
                onDestinationSelected: (pos) {
                  if (pos == 3) {
                    _scaffoldKey.currentState?.openDrawer();
                  } else {
                    final tabIdx = switch (pos) {
                      0 => 0, // Schedule
                      1 => 2, // Patients
                      2 => 4, // Finance
                      _ => 0,
                    };
                    _navigateTo(tabIdx);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                    label: 'Schedule',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_alt_outlined),
                    selectedIcon: Icon(Icons.people_alt_rounded, color: AppColors.primary),
                    label: 'Patients',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                    label: 'Finance',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_rounded),
                    selectedIcon: Icon(Icons.menu_rounded, color: AppColors.primary),
                    label: 'More',
                  ),
                ],
              )
            : null,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildScheduleTab(s),                                              // 0
            _buildDocumentationTab(s),                                         // 1
            _buildPatientsTab(s),                                              // 2
            _isLocked(3)                                                       // 3
                ? _buildLockedScreen('Statistics', SubTier.premium)
                : SessionStatsScreen(onAddAppointment: () => _navigateTo(0)),
            _isLocked(4) ? _buildLockedScreen('Income',     SubTier.premium) // 4
                         : const BillingScreen(),
            _isLocked(5) ? _buildLockedScreen('Expenses',   SubTier.premium) // 5
                         : const ExpensesScreen(),
            _buildProfileTab(s),                                               // 6
            DoctorNotificationsTab(service: _service),                          // 7
            _buildStoreTab(),                                                // 8
            const AssessmentLibraryScreen(),                                 // 9
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Home Landing Screen
  // ════════════════════════════════════════════════════════════════════════════

  static const List<Color> _tileColors = [
    Color(0xFF1565C0), // Schedule         – blue
    Color(0xFF2E7D32), // Documentation    – green
    Color(0xFFE65100), // My Patients      – orange
    Color(0xFF00695C), // Statistics       – teal
    Color(0xFF0E8378), // Revenues         – teal accent
    Color(0xFF993C1D), // Expenses         – coral
    Color(0xFF37474F), // My Profile       – blue-grey
    Color(0xFF6A1B9A), // Notifications    – deep purple
    Color(0xFF4527A0), // PhysioGate       – deep indigo (premium)
    Color(0xFF006064), // Assessment Library – dark cyan
  ];

  Widget _buildHomeScreen(AppStrings s, LanguageProvider lang) {
    final name   = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Doctor';
    final spec   = _specCtrl.text;
    final photo  = _photoCtrl.text;
    final now    = DateTime.now();
    final today  = DateFormat('EEEE, MMM d').format(now);

    final sections = [
      s.schedule, s.documentation, s.myPatients,
      s.statistics, s.billing, s.expenses, s.myProfile,
      s.notifications, s.store, s.assessmentLibrary,
    ];

    // Fixed 4×2 grid layout.
    // Row 1: My Patients | Schedule | Documentation | Assessment Library
    // Row 2: Revenues    | Expenses | Statistics    | PhysioGate
    // My Profile lives in the header only (not in the grid).
    // Documentation is shown on all form factors; notification bell is in the header.
    const primaryIndices = [2, 0, 1, 9, 4, 5, 3, 8];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Teal header ───────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile button — prominent avatar with label
                  GestureDetector(
                    onTap: () => _navigateTo(6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo.isEmpty
                                ? const Icon(Icons.person_rounded, color: Colors.white, size: 32)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Profile',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + spec + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_showDrPrefix ? "Dr. " : ""}$name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                        if (spec.isNotEmpty)
                          Text(spec,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(today,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons: AI, Notifications, language, logout
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // AI Doctor Assistant button
                          if (_sub.aiEnabled)
                            GestureDetector(
                              onTap: () => _showAiAssistantSheet(),
                              child: Container(
                                width: 34, height: 34,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.auto_awesome_rounded,
                                    color: Colors.white, size: 17),
                              ),
                            ),
                          _buildHeaderNavButton(
                            icon: Icons.notifications_rounded,
                            label: s.notifications,
                            badge: _doctorUnreadCount > 0 ? _doctorUnreadCount : null,
                            onTap: () => _navigateTo(7),
                            compact: true,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: lang.toggle,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(36, 28),
                            ),
                            child: Text(s.language,
                                style: const TextStyle(fontSize: 10)),
                          ),
                          IconButton(
                            onPressed: () => _showLogout(),
                            icon: const Icon(Icons.logout_rounded,
                                color: Colors.white54, size: 18),
                            tooltip: 'Logout',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── First-time guide (above agenda, non-scrolling) ───────────────
        if (_hasPatients == false)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _buildAddPatientsGuide(),
          ),

        // ── Tile grid fills all remaining space ───────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Access',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    const spacing = 10.0;
                    // 3 columns on mobile, 4 on desktop
                    final isMob = FormFactorFeatures.of(ctx).isMobile;
                    final cols  = isMob ? 3 : 4;
                    final rows  = (primaryIndices.length / cols).ceil();
                    final tileW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
                    // Cap tile height so tiles don't grow taller than ~1.22× their
                    // width on tall/narrow screens (keeps icon + label readable).
                    final rawTileH = (constraints.maxHeight - (rows - 1) * spacing) / rows;
                    final tileH   = rawTileH.clamp(0.0, tileW / 0.78);
                    final ratio   = tileW / tileH;
                    return GridView.count(
                      crossAxisCount: cols,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: ratio,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: primaryIndices.map((idx) => _buildHomeTile(
                          sections[idx], _allNavIcons[idx], _allTileColors[idx], idx,
                          tileW: tileW, tileH: tileH)).toList(),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                _buildSubStatusBar(s),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubStatusBar(AppStrings s) {
    final expired = _sub.isExpired;
    final now = DateTime.now();
    final expiresAt = _sub.expiresAt;
    final expiringSoon = expiresAt != null && !expired &&
        expiresAt.isBefore(now.add(const Duration(days: 30)));
    final expiringVerySoon = expiresAt != null && !expired &&
        expiresAt.isBefore(now.add(const Duration(days: 5)));

    final Color color;
    final IconData icon;
    final String text;

    final fmtDate = expiresAt != null
        ? DateFormat('MMM d, yyyy').format(expiresAt)
        : '';

    if (expired) {
      color = AppColors.error;
      icon  = Icons.timer_off_rounded;
      text  = '${_sub.tier.label} plan — Expired $fmtDate';
    } else if (expiringVerySoon) {
      color = AppColors.error;
      icon  = Icons.warning_rounded;
      text  = '${_sub.tier.label} plan — Expires $fmtDate';
    } else if (expiringSoon) {
      color = AppColors.warning;
      icon  = Icons.info_outline_rounded;
      text  = '${_sub.tier.label} plan — Expires $fmtDate';
    } else if (expiresAt != null) {
      color = AppColors.textSecondary;
      icon  = Icons.workspace_premium_rounded;
      text  = '${_sub.tier.label} plan · Expires $fmtDate';
    } else {
      color = AppColors.textSecondary;
      icon  = Icons.workspace_premium_rounded;
      text  = '${_sub.tier.label} plan · No expiry set';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        TextButton.icon(
          onPressed: () => _importUnifiedFromExcel(s),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
          ),
          icon: const Icon(Icons.upload_file_rounded, size: 14),
          label: const Text('Import', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () => _showLogout(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
          ),
          child: const Text('Log out', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _buildAddPatientsGuide() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE65100).withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_alt_rounded,
                  color: Color(0xFFE65100), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Step 1 — Add patients to your list',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFE65100))),
            ),
          ]),
          const SizedBox(height: 10),
          // Explanation
          const Text(
            'You need at least one patient in My Patients before you can '
            'schedule appointments or add clinical documentation.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add Patient',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  setState(() {
                    _showHome     = false;
                    _currentIndex = 2; // My Patients tab
                  });
                  // Small delay so the tab renders, then open the add-patient menu
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (mounted) {
                      _showAddPatientMenu(
                          AppStrings(context.read<LanguageProvider>().isArabic));
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE65100),
                side: const BorderSide(color: Color(0xFFE65100)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => setState(() {
                _showHome     = false;
                _currentIndex = 2;
              }),
              child: const Text('My Patients',
                  style: TextStyle(fontSize: 13)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeaderNavButton({
    required IconData icon,
    required String label,
    int? badge,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Colors.white70,
                    size: compact ? 24 : 22),
                if (badge != null)
                  Positioned(
                    top: -4, right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTile(
      String title, IconData icon, Color color, int index,
      {double tileW = 80, double tileH = 80}) {
    final locked    = _isLocked(index);
    final badge     = index == 7 ? _doctorUnreadCount : 0;
    final iconColor = locked ? Colors.grey.shade400 : color;

    // Scale all visual elements to fill the tile without overflow.
    final boxSize  = (tileW * 0.42).clamp(28.0, 64.0);
    final iconSize = (boxSize  * 0.54).clamp(16.0, 34.0);
    final gap      = (tileH   * 0.06).clamp(3.0,  10.0);
    final fontSize = (tileW   * 0.13).clamp(9.0,  14.0);
    final pad      = (tileW   * 0.06).clamp(4.0,  12.0);
    final radius   = (tileW   * 0.15).clamp(8.0,  16.0);

    final semanticLabel = locked
        ? '$title — locked, requires upgrade'
        : badge > 0
            ? '$title — $badge unread'
            : title;

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: !locked,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: locked
              ? null
              : () => setState(() {
                    _currentIndex = index;
                    _showHome = false;
                  }),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: boxSize,
                          height: boxSize,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(
                                alpha: locked ? 0.06 : 0.12),
                            borderRadius: BorderRadius.circular(radius * 0.75),
                          ),
                          child: index == 8
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(radius * 0.75 - 1),
                                  child: Opacity(
                                    opacity: locked ? 0.4 : 1.0,
                                    child: Image.asset(
                                      'assets/images/physiogate_logo.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : Icon(icon, size: iconSize, color: iconColor),
                        ),
                        SizedBox(height: gap),
                        Text(
                          title,
                          style: TextStyle(
                              color: locked
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: fontSize),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(Icons.lock_rounded,
                        color: Colors.grey.shade400, size: 12),
                  ),
                if (badge > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedScreen(String feature, SubTier requiredTier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: requiredTier.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded,
                  size: 40, color: requiredTier.color),
            ),
            const SizedBox(height: 22),
            Text(feature,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text(
              'This feature requires the ${requiredTier.label} plan or higher.\n'
              'Contact your admin to upgrade your subscription.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: requiredTier.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: requiredTier.color.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(requiredTier.icon,
                    color: requiredTier.color, size: 16),
                const SizedBox(width: 8),
                Text('${requiredTier.label} Plan Required',
                    style: TextStyle(
                        color: requiredTier.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Navigation Drawer
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildNavDrawer(AppStrings s, List<String> sections) {
    final showStats = FormFactorFeatures.of(context).showStatistics;
    final showDocs = FormFactorFeatures.of(context).showDocumentation;
    final visibleIndices = [
      for (var i = 0; i < sections.length; i++)
        if ((i != 3 || showStats) && (i != 1 || showDocs)) i,
    ];
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                radius: 26,
                child: const Icon(Icons.accessibility_new_rounded,
                    color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.isNotEmpty
                          ? _nameCtrl.text
                          : s.doctorDashboard,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(s.appName,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: visibleIndices.length,
              itemBuilder: (_, pos) {
                final i = visibleIndices[pos];
                final selected = _currentIndex == i;
                final locked   = _isLocked(i);
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  child: Material(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (i == 8)
                            Opacity(
                              opacity: locked ? 0.4 : 1.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Image.asset(
                                  'assets/images/physiogate_logo.jpg',
                                  height: 22,
                                  width: 22,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            Icon(_allNavIcons[i],
                                color: locked
                                    ? Colors.grey.shade400
                                    : selected
                                        ? AppColors.primary
                                        : Colors.grey.shade600,
                                size: 22),
                          if (locked)
                            Positioned(
                              right: -4, bottom: -4,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(Icons.lock_rounded,
                                    size: 7, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      title: Text(sections[i],
                          style: TextStyle(
                            color: locked
                                ? AppColors.textSecondary
                                : selected
                                    ? AppColors.primary
                                    : null,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 15,
                          )),
                      trailing: locked
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Locked',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500)),
                            )
                          : null,
                      selected: selected && !locked,
                      onTap: () => _navigateTo(i),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // Show a transient toast for a notification that just arrived via the
  // realtime stream (i.e. not part of the initial snapshot).
  void _showNotifPopup(Map<String, dynamic> n) {
    final title = (n['title'] as String?) ?? 'Notification';
    final body  = (n['body']  as String?) ?? '';
    final (icon, color) = DoctorNotificationsTab.iconFor((n['type'] as String?) ?? '');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      content: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ],
          ),
        ),
      ]),
    ));
  }


  // ════════════════════════════════════════════════════════════════════════════
  // 0 – Schedule Tab
  // ════════════════════════════════════════════════════════════════════════════

  // ── Avatar colours cycling through appointments ───────────────────────────
  static const List<Color> _apptAvatarColors = [
    Color(0xFF1565C0),
    Color(0xFFE65100),
    Color(0xFFC62828),
    Color(0xFF2E7D32),
    Color(0xFF4527A0),
    Color(0xFF00695C),
  ];

  // ════════════════════════════════════════════════════════════════════════════
  // 0 – Schedule Tab  (calendar + day sessions, side-by-side on wide screens)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildScheduleTab(AppStrings s) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.getAllDoctorAppointments(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allAppts = snap.data ?? [];
        return LayoutBuilder(
          builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 680;
            if (isWide) {
              return SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Calendar card ────────────────────────────────
                      SizedBox(
                        width: 340,
                        child: _buildCalendarCard(allAppts, s),
                      ),
                      const SizedBox(width: 16),
                      // ── Appointments panel ───────────────────────────
                      _buildAppointmentsPanel(allAppts, s, shrinkWrap: false),
                    ],
                  ),
                ),
              );
            }
            // ── Mobile: stacked ──────────────────────────────────────
            return SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                PendingRequestsCard(service: _service),
                const SizedBox(height: 14),
                _buildCalendarCard(allAppts, s),
                const SizedBox(height: 14),
                _buildAppointmentsPanel(allAppts, s, shrinkWrap: true),
              ]),
            );
          },
        );
      },
    );
  }


  // ── Calendar card ─────────────────────────────────────────────────────────

  Widget _buildCalendarCard(List<Map<String, dynamic>> allAppts, AppStrings s) {
    // Days with appointments in the shown month
    final apptDays = <int>{};
    for (final doc in allAppts) {
      final data = doc;
      final ts   = data['appointment_time'] as String?;
      if (ts == null) continue;
      final dt = DateTime.parse(ts);
      if (dt.year == _calMonth.year && dt.month == _calMonth.month) {
        apptDays.add(dt.day);
      }
    }

    final firstDay    = DateTime(_calMonth.year, _calMonth.month, 1);
    final daysInMonth = DateTime(_calMonth.year, _calMonth.month + 1, 0).day;
    // Sunday-first (Sun=0, Mon=1 … Sat=6)
    final padStart = firstDay.weekday % 7;
    final today    = DateTime.now();
    const dayHdrs  = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Month header bar ────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1A3A5C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_calMonth),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 26),
                  onPressed: () => _changeCalMonth(1),
                ),
              ]),
            ),
            // ── Day-of-week headers ─────────────────────────────────────
            Row(
              children: dayHdrs.map((d) => Expanded(
                child: Center(
                  child: Text(d,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A3A5C))),
                ),
              )).toList(),
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
            // ── Day grid ────────────────────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.05,
              ),
              itemCount: padStart + daysInMonth,
              itemBuilder: (_, index) {
                if (index < padStart) return const SizedBox.shrink();
                final day  = index - padStart + 1;
                final date = DateTime(_calMonth.year, _calMonth.month, day);
                final isSel = _calDay.year  == date.year &&
                              _calDay.month == date.month &&
                              _calDay.day   == date.day;
                final isTod = today.year  == date.year &&
                              today.month == date.month &&
                              today.day   == date.day;
                final hasAppt = apptDays.contains(day);

                return GestureDetector(
                  onTap: () => setState(() => _calDay = date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFF1A3A5C)
                          : isTod
                              ? const Color(0xFF1A3A5C).withValues(alpha: 0.08)
                              : null,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('$day',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSel || isTod
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSel
                                  ? Colors.white
                                  : isTod
                                      ? const Color(0xFF1A3A5C)
                                      : const Color(0xFF1A2332),
                            )),
                        if (hasAppt && !isSel)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 4, height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A3A5C),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // ── Bottom row: Today + << >> ────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final n = DateTime.now();
                    setState(() {
                      _calMonth = DateTime(n.year, n.month);
                      _calDay   = DateTime(n.year, n.month, n.day);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1A3A5C)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Today',
                      style: TextStyle(
                          color: Color(0xFF1A3A5C),
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              _calNavBtn('<<', () => _changeCalMonth(-1)),
              const SizedBox(width: 6),
              _calNavBtn('>>', () => _changeCalMonth(1)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _calNavBtn(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF1A3A5C)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(46, 40),
          padding: EdgeInsets.zero,
        ),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF1A3A5C), fontWeight: FontWeight.bold)),
      );

  // ── Appointments panel ────────────────────────────────────────────────────

  Widget _buildAppointmentsPanel(
      List<Map<String, dynamic>> allAppts, AppStrings s,
      {required bool shrinkWrap}) {
    final now = DateTime.now();
    final isToday = _calDay.year  == now.year &&
                    _calDay.month == now.month &&
                    _calDay.day   == now.day;

    // Separate upcoming and previous appointments
    final upcomingAppts = <Map<String, dynamic>>[];
    final previousAppts = <Map<String, dynamic>>[];

    for (final doc in allAppts) {
      final data = doc;
      final ts = data['appointment_time'] as String?;
      if (ts == null) continue;
      final dt = DateTime.parse(ts);

      if (dt.isBefore(now)) {
        previousAppts.add(doc);
      } else {
        upcomingAppts.add(doc);
      }
    }

    upcomingAppts.sort((a, b) {
      final ta = DateTime.parse(a['appointment_time'] as String);
      final tb = DateTime.parse(b['appointment_time'] as String);
      return ta.compareTo(tb);
    });

    previousAppts.sort((a, b) {
      final ta = DateTime.parse(a['appointment_time'] as String);
      final tb = DateTime.parse(b['appointment_time'] as String);
      return tb.compareTo(ta); // Newest first
    });

    // Get appointments for selected day (past or future)
    final dayAppts = allAppts.where((doc) {
      final data = doc;
      final ts   = data['appointment_time'] as String?;
      if (ts == null) return false;
      final dt = DateTime.parse(ts);
      return dt.year  == _calDay.year &&
             dt.month == _calDay.month &&
             dt.day   == _calDay.day;
    }).toList()
      ..sort((a, b) {
        final ta = DateTime.parse(a['appointment_time'] as String);
        final tb = DateTime.parse(b['appointment_time'] as String);
        return ta.compareTo(tb);
      });

    return _buildAppointmentsContent(
      dayAppts,
      upcomingAppts,
      previousAppts,
      s,
      shrinkWrap,
      isToday,
    );
  }

  Widget _buildAppointmentsContent(
    List<Map<String, dynamic>> dayAppts,
    List<Map<String, dynamic>> upcomingAppts,
    List<Map<String, dynamic>> previousAppts,
    AppStrings s,
    bool shrinkWrap,
    bool isToday,
  ) {
    // ── Build an appointment tile ───────────────────────────────────────────
    Widget apptTile(Map<String, dynamic> doc, int i, bool isPast) {
      final data       = doc;
      final dt         = DateTime.parse(data['appointment_time'] as String);
      final patName    = (data['patient_name'] as String?) ?? '';
      final notes      = (data['notes'] as String?) ?? '';
      final apptId     = doc['id'] as String;
      final avatarColor = _apptAvatarColors[i % _apptAvatarColors.length];
      final status     = (data['status'] as String?) ?? 'scheduled';
      final isCancelled = status == 'cancelled';
      final isCompleted = status == 'completed';

      return Material(
        color: isCancelled
            ? const Color(0xFFFFF5F5)
            : isCompleted
                ? const Color(0xFFF8FFF8)
                : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // Time block
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: isCancelled
                    ? Colors.grey.shade200
                    : isCompleted
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                        : avatarColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  DateFormat('h:mm').format(dt),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCancelled
                          ? Colors.grey
                          : isCompleted
                              ? const Color(0xFF2E7D32)
                              : avatarColor),
                  textAlign: TextAlign.center,
                ),
                Text(
                  DateFormat('a').format(dt).toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCancelled
                          ? Colors.grey
                          : isCompleted
                              ? const Color(0xFF2E7D32)
                              : avatarColor),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
            const SizedBox(width: 12),
            // Patient info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        patName.isNotEmpty ? patName : 'Patient',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isCancelled
                              ? Colors.grey
                              : const Color(0xFF1A2332),
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (isCancelled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Cancelled',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFC62828),
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  if (notes.isNotEmpty)
                    Text(notes,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  Text(
                    DateFormat('EEE, MMM d').format(dt),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Trailing action
            if (isPast)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 20)
            else if (!isCancelled)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.grey.shade400, size: 20),
                onSelected: (v) async {
                  if (v == 'edit') {
                    _showEditAppointmentSheet(s, apptId, dt, notes);
                  } else if (v == 'cancel') {
                    final ok = await _service.cancelAppointment(apptId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'Session cancelled' : s.error),
                      backgroundColor:
                          ok ? AppColors.warning : AppColors.error,
                    ));
                  } else if (v == 'delete') {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await _service.deleteAppointment(apptId);
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(
                      content: Text(
                          ok ? s.appointmentDeleted : s.error),
                      backgroundColor:
                          ok ? AppColors.warning : AppColors.error,
                    ));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(s.edit),
                      ])),
                  PopupMenuItem(
                      value: 'cancel',
                      child: Row(children: [
                        const Icon(Icons.cancel_rounded,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        const Text('Cancel Session',
                            style:
                                TextStyle(color: AppColors.warning)),
                      ])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_rounded,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(s.delete,
                            style: const TextStyle(
                                color: AppColors.error)),
                      ])),
                ],
              ),
          ]),
        ),
      );
    }

    // ── Section header ─────────────────────────────────────────────────────
    Widget sectionHeader(String title, int count, IconData icon, Color color) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ]),
        );

    // ── Build sections ─────────────────────────────────────────────────────
    final addBtn = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Row(children: [
        // Add appointment
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A5C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(s.addAppointment,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => _showBookAppointmentSheet(s),
            ),
          ),
        ),
      ]),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  color: Color(0xFF1A3A5C), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_calDay),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1A2332)),
                ),
                Text(
                  isToday ? "Today's Schedule" : 'Appointments',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
          ]),
        ),
        addBtn,
        const Divider(height: 1),
        // ── Selected-day appointments ─────────────────────────────────
        sectionHeader(
          isToday ? 'Today' : DateFormat('EEE, MMM d').format(_calDay),
          dayAppts.length,
          Icons.event_rounded,
          const Color(0xFF1565C0),
        ),
        if (dayAppts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              isToday
                  ? 'No appointments scheduled for today.'
                  : 'No appointments on this date.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: dayAppts.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 66, endIndent: 12),
            itemBuilder: (_, i) {
              final d  = dayAppts[i];
              final dt = ((d['appointment_time'] as String?) != null ? DateTime.parse(d['appointment_time'] as String) : null);
              final isPastAppt =
                  dt != null && dt.isBefore(DateTime.now());
              return apptTile(dayAppts[i], i, isPastAppt);
            },
          ),
      ],
    );

    final card = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: shrinkWrap
          ? content
          : SingleChildScrollView(child: content),
    );

    if (!shrinkWrap) {
      return Expanded(child: card);
    }
    return card;
  }

  // ── Book / Edit appointment sheets ────────────────────────────────────────

  void _showBookAppointmentSheet(AppStrings s,
      {String? prePatientId, String? prePatientName}) {
    String? selPatientId   = prePatientId;
    String? selPatientName = prePatientName;
    DateTime? selDateTime;
    final notesCtrl = TextEditingController();
    final patientSearchCtrl =
        TextEditingController(text: prePatientName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.scheduleSession,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _service.getAssignedPatients(),
                builder: (context, snap) {
                  final patients = snap.data ?? [];
                  return PatientSearchField(
                    patients: patients,
                    labelText: s.selectPatient,
                    controller: patientSearchCtrl,
                    fillColor: AppColors.background,
                    onSelected: (id, name) {
                      setLocal(() {
                        selPatientId   = id;
                        selPatientName = name;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_rounded,
                      color: AppColors.primary),
                  title: Text(selDateTime == null
                      ? s.sessionDate
                      : DateFormat('d MMM yyyy  HH:mm')
                          .format(selDateTime!)),
                  trailing: const Icon(Icons.edit_calendar_rounded,
                      color: Colors.grey),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (date == null || !ctx.mounted) return;
                    final time = await showTimePicker(
                        context: ctx, initialTime: TimeOfDay.now());
                    if (time == null) return;
                    setLocal(() {
                      selDateTime = DateTime(date.year, date.month,
                          date.day, time.hour, time.minute);
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.sessionNotes,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(s.bookSession,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (selPatientId == null || selDateTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.selectPatientAndTime)));
                      return;
                    }
                    Navigator.pop(ctx);
                    final ok = await _service.bookAppointment(
                        selPatientId!, selPatientName ?? '',
                        selDateTime!, notesCtrl.text);
                    if (!mounted) return;
                    // Auto-navigate calendar to booked day
                    setState(() {
                      _calMonth = DateTime(
                          selDateTime!.year, selDateTime!.month);
                      _calDay = DateTime(selDateTime!.year,
                          selDateTime!.month, selDateTime!.day);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? s.sessionBooked : s.error),
                      backgroundColor:
                          ok ? AppColors.success : AppColors.error,
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditAppointmentSheet(
      AppStrings s, String apptId, DateTime current, String currentNotes) {
    DateTime? selDateTime = current;
    final notesCtrl = TextEditingController(text: currentNotes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.editAppointment,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_rounded,
                      color: AppColors.primary),
                  title: Text(selDateTime == null
                      ? s.sessionDate
                      : DateFormat('d MMM yyyy  HH:mm')
                          .format(selDateTime!)),
                  trailing: const Icon(Icons.edit_calendar_rounded,
                      color: Colors.grey),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selDateTime ?? DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (date == null || !ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                          hour:   selDateTime?.hour   ?? 9,
                          minute: selDateTime?.minute ?? 0),
                    );
                    if (time == null) return;
                    setLocal(() {
                      selDateTime = DateTime(date.year, date.month,
                          date.day, time.hour, time.minute);
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.sessionNotes,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: AppColors.background,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded),
                  label: Text(s.save,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (selDateTime == null) return;
                    Navigator.pop(ctx);
                    final ok = await _service.updateAppointment(
                        apptId, selDateTime!, notesCtrl.text);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(ok ? s.appointmentUpdated : s.error),
                      backgroundColor:
                          ok ? AppColors.success : AppColors.error,
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1 – Documentation Tab
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDocumentationTab(AppStrings s) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.getAllDoctorNotes(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final soapNotes = (snap.data ?? []).where((doc) {
            return doc['note_type'] == 'soap' ||
                doc.containsKey('chiefComplaint') ||
                (doc.containsKey('subjective') && doc['subjective'] != null);
          }).toList();

          final isMobile = FormFactorFeatures.of(context).isMobile;

          if (soapNotes.isEmpty) {
            return Column(children: [
              if (isMobile) _buildDocMobileHeader(s, []),
              Expanded(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.description_outlined,
                        size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 14),
                    Text(s.noDocumentation,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textSecondary, height: 1.5)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First Note'),
                      onPressed: () => _showPickPatientForDoc(s),
                    ),
                  ]),
                ),
              ),
            ]);
          }

          String selectedPatient  = '';
          String selectedCondition = '';
          String searchQuery       = '';

          return StatefulBuilder(builder: (context, setDoc) {
            final allNotes     = soapNotes.toList();
            final patientSet   = <String>{};
            final conditionSet = <String>{};

            for (final note in allNotes) {
              patientSet.add((note['patient_name'] as String?) ?? 'Unknown');
              conditionSet.add(
                (note['primary_diagnosis'] as String?) ??
                (note['chiefComplaint']    as String?) ?? 'General',
              );
            }

            final filteredNotes = allNotes.where((note) {
              final pat = (note['patient_name']    as String?) ?? '';
              final cond = (note['primary_diagnosis'] as String?) ??
                  (note['chiefComplaint'] as String?) ?? '';
              return (searchQuery.isEmpty ||
                      pat.toLowerCase().contains(searchQuery.toLowerCase()) ||
                      cond.toLowerCase().contains(searchQuery.toLowerCase())) &&
                  (selectedPatient.isEmpty   || pat  == selectedPatient) &&
                  (selectedCondition.isEmpty || cond == selectedCondition);
            }).toList()
              ..sort((a, b) {
                final ta = a['created_at'] != null
                    ? DateTime.parse(a['created_at'] as String)
                    : DateTime(2000);
                final tb = b['created_at'] != null
                    ? DateTime.parse(b['created_at'] as String)
                    : DateTime(2000);
                return tb.compareTo(ta);
              });

            // ── Mobile layout ───────────────────────────────────────────────
            if (isMobile) {
              return Column(children: [
                // Sticky header
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Expanded(
                          child: Text('Documentation',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Note',
                              style: TextStyle(fontSize: 13)),
                          onPressed: () => _showPickPatientForDoc(s),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      // Search bar
                      TextField(
                        onChanged: (v) =>
                            setDoc(() => searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search patients or conditions…',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 18, color: AppColors.primary),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Filter chips row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _docFilterChip(
                            label: 'All patients',
                            selected: selectedPatient.isEmpty,
                            onTap: () =>
                                setDoc(() => selectedPatient = ''),
                          ),
                          ...patientSet.map((p) => _docFilterChip(
                                label: p,
                                selected: selectedPatient == p,
                                onTap: () =>
                                    setDoc(() => selectedPatient = p),
                              )),
                        ]),
                      ),
                    ],
                  ),
                ),
                // Note count
                if (filteredNotes.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filteredNotes.length} note${filteredNotes.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                      ),
                    ),
                  ),
                // Card list
                Expanded(
                  child: filteredNotes.isEmpty
                      ? Center(
                          child: Text('No notes found',
                              style: TextStyle(
                                  color: Colors.grey.shade500)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              12, 10, 12, 24),
                          itemCount: filteredNotes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _buildDocNoteCard(filteredNotes[i], s),
                        ),
                ),
              ]);
            }

            // ── Desktop layout (unchanged) ──────────────────────────────────
            final recentUpdates = allNotes.take(3).map((note) {
              final patName =
                  (note['patient_name'] as String?) ?? 'Patient';
              final patId   = (note['patient_id'] as String?) ?? '';
              final ts      = note['created_at'] != null
                  ? DateTime.parse(note['created_at'] as String)
                  : null;
              return {
                'name':     patName,
                'patientId': patId,
                'noteId':   note['id'] as String,
                'noteData': note,
                'date':     ts,
                'action':   'Note Updated',
              };
            }).toList();

            return Column(children: [
              // Header
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Documentation Center',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Note'),
                          onPressed: () => _showPickPatientForDoc(s),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onChanged: (v) =>
                              setDoc(() => searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search Records',
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: AppColors.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (FormFactorFeatures.of(context)
                          .showDocumentationExport) ...[
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Export PDF'),
                          onPressed: () =>
                              _showExportPdfPatientPicker(s, allNotes),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Row(children: [
                  // Left sidebar
                  Container(
                    width: 240,
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Add New Note'),
                          onPressed: () => _showPickPatientForDoc(s),
                        ),
                        const SizedBox(height: 20),
                        const Text('Recent Updates:',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: recentUpdates.length,
                            itemBuilder: (_, i) {
                              final update = recentUpdates[i];
                              final patId   = update['patientId'] as String;
                              final patName = update['name']      as String;
                              final noteId  = update['noteId']    as String;
                              final noteData =
                                  update['noteData'] as Map<String, dynamic>;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SoapNoteScreen(
                                        patientId:   patId,
                                        patientName: patName,
                                        noteId:      noteId,
                                        initialData: noteData,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.12)),
                                    ),
                                    child: Row(children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(patName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${update['action']} '
                                              '${update['date'] != null ? DateFormat('dd/MM/yyyy').format(update['date'] as DateTime) : ''}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 12,
                                          color: AppColors.primary),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right content area
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF5F5F5),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Filters
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedPatient.isEmpty
                                      ? ''
                                      : selectedPatient,
                                  decoration: InputDecoration(
                                    labelText: 'Patient Name',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '',
                                        child: Text('All Patients')),
                                    ...patientSet.map((p) =>
                                        DropdownMenuItem(
                                            value: p, child: Text(p))),
                                  ],
                                  onChanged: (v) => setDoc(
                                      () => selectedPatient = v ?? ''),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedCondition.isEmpty
                                      ? ''
                                      : selectedCondition,
                                  decoration: InputDecoration(
                                    labelText: 'Condition',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '',
                                        child: Text('All Conditions')),
                                    ...conditionSet.map((c) =>
                                        DropdownMenuItem(
                                            value: c, child: Text(c))),
                                  ],
                                  onChanged: (v) => setDoc(
                                      () => selectedCondition = v ?? ''),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: filteredNotes.isEmpty
                                ? Center(
                                    child: Text('No documentation found',
                                        style: TextStyle(
                                            color: Colors.grey.shade600)))
                                : _buildDocumentationTable(
                                    filteredNotes, s),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ]);
          });
        },
      ),
    );
  }

  // ── Mobile: horizontal patient filter chip ────────────────────────────────

  Widget _docFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      );

  // Unused desktop header helper (kept for consistency)
  Widget _buildDocMobileHeader(AppStrings s, List notes) =>
      const SizedBox.shrink();

  // ── Mobile: note card ──────────────────────────────────────────────────────

  Widget _buildDocNoteCard(Map<String, dynamic> note, AppStrings s) {
    final patName  = (note['patient_name']    as String?) ?? 'Patient';
    final patId    = (note['patient_id']      as String?) ?? '';
    final condition = (note['primary_diagnosis'] as String?) ??
        (note['chiefComplaint'] as String?) ?? 'General';
    final ts = note['created_at'] != null
        ? DateTime.tryParse(note['created_at'] as String)
        : null;
    final date = ts != null
        ? DateFormat('dd MMM yyyy').format(ts)
        : '—';

    // Brief preview from chiefComplaint or subjective text
    final soapData = note['soap_data'] as Map<String, dynamic>?;
    final preview = (soapData?['chiefComplaint'] as String?) ??
        (note['chiefComplaint'] as String?) ??
        (note['subjective'] as String?) ?? '';
    final displayPreview = preview.length > 80
        ? '${preview.substring(0, 80)}…'
        : preview;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SoapNoteScreen(
              patientId:   patId,
              patientName: patName,
              noteId:      note['id'] as String,
              initialData: note,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EAED)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                patName.isNotEmpty ? patName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(patName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(date,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      condition,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (displayPreview.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(displayPreview,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 18, color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (action) async {
                if (action == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SoapNoteScreen(
                        patientId:   patId,
                        patientName: patName,
                        noteId:      note['id'] as String,
                        initialData: note,
                      ),
                    ),
                  );
                } else if (action == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Delete Note?'),
                      content: Text(
                          'Delete this note for $patName? This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !mounted) return;
                  try {
                    await Supabase.instance.client
                        .from('clinical_notes')
                        .delete()
                        .eq('id', note['id'] as String);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Note deleted'),
                          backgroundColor: AppColors.success),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Error deleting note'),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded,
                        size: 16, color: Colors.orange),
                    SizedBox(width: 10),
                    Text('Edit Note'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded,
                        size: 16, color: AppColors.error),
                    SizedBox(width: 10),
                    Text('Delete',
                        style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildDocumentationTable(
      List<Map<String, dynamic>> notes, AppStrings s) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          // Table header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Patient Name',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Session Date',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('Condition',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Note Summary',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(
                  width: 80,
                  child: Text('Actions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          // Table rows
          Expanded(
            child: ListView.separated(
              itemCount: notes.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
              itemBuilder: (_, i) {
                final note = notes[i];
                final d = note;
                final patName =
                    (d['patient_name'] as String?) ?? 'Patient';
                final patId = (d['patient_id'] as String?) ?? '';
                final condition = (d['primary_diagnosis'] as String?) ??
                    (d['chiefComplaint'] as String?) ??
                    'General';
                final ts = ((d['created_at'] as String?) != null ? DateTime.parse(d['created_at'] as String) : null);
                final date = ts != null
                    ? DateFormat('dd/MM/yyyy').format(ts)
                    : '—';
                final summary = ((d['subjective'] as String?) ?? '')
                    .replaceAll('\n', ' ');
                final displaySummary = summary.length > 60
                    ? '${summary.substring(0, 60)}...'
                    : summary;
                final photoUrl =
                    (d['patientPhotoUrl'] as String?) ?? '';

                return Container(
                  color: i.isEven ? Colors.white : const Color(0xFFF8FAFF),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary
                                  .withValues(alpha: 0.15),
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isEmpty
                                  ? Icon(Icons.person_rounded,
                                      size: 16,
                                      color: AppColors.primary)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(patName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(date,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(condition,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Tooltip(
                          message: summary,
                          child: Text(displaySummary,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  size: 18,
                                  color: Colors.orange),
                              tooltip: 'Edit',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SoapNoteScreen(
                                    patientId: patId,
                                    patientName: patName,
                                    noteId: note['id'] as String,
                                    initialData: d,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded,
                                  size: 18,
                                  color: AppColors.error),
                              tooltip: 'Delete',
                              onPressed: () async {
                                try {
                                  await Supabase.instance.client
                                      .from('clinical_notes')
                                      .delete().eq('id', note['id'] as String);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Note deleted'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Error deleting note'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

void _showPickPatientForDoc(AppStrings s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.addDocumentation,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(s.pickPatient,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.getAssignedPatients(),
              builder: (context, snap) {
                final patients = snap.data ?? [];
                if (patients.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(s.noPatients,
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(ctx).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: patients.length,
                    itemBuilder: (_, i) {
                      final d    = patients[i];
                      final name = d['name'] ?? d['email'] ?? 'Patient';
                      final photo = (d['profile_photo_url'] as String?) ?? '';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                          child: photo.isEmpty
                              ? const Icon(Icons.person_rounded,
                                  color: AppColors.primary)
                              : null,
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            (d['primary_diagnosis'] as String?) ?? '',
                            style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14, color: Colors.grey),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SoapNoteScreen(
                                patientId:   patients[i]['id'] as String,
                                patientName: name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2 – My Patients Tab
  // ════════════════════════════════════════════════════════════════════════════

  void _showAddPatientMenu(AppStrings s) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Patient',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _addPatientTile(
                ctx: ctx,
                icon: Icons.person_add_rounded,
                color: AppColors.primary,
                title: s.addPatient,
                subtitle: 'Create a new patient account',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const CreatePatientScreen()));
                },
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 10),
              _addPatientTile(
                ctx: ctx,
                icon: Icons.person_outline_rounded,
                color: Colors.teal,
                bgColor: Colors.teal.shade50,
                title: 'Add Without Account',
                subtitle: 'Patient who doesn\'t use the app',
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddOfflinePatientDialog(s);
                },
              ),
              const SizedBox(height: 10),
              _addPatientTile(
                ctx: ctx,
                icon: Icons.manage_search_rounded,
                color: Colors.orange.shade700,
                bgColor: Colors.orange.shade50,
                title: 'Add Existing Patient',
                subtitle: 'Link an already-registered patient',
                onTap: () {
                  Navigator.pop(ctx);
                  _showSearchExistingPatients(s);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addPatientTile({
    required BuildContext ctx,
    required IconData icon,
    required Color color,
    Color? bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onHelp,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder)),
      leading: CircleAvatar(
        backgroundColor: bgColor ?? color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title:
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (onHelp != null)
          GestureDetector(
            onTap: onHelp,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.help_outline_rounded,
                  size: 18, color: Colors.grey.shade500),
            ),
          ),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Colors.grey),
      ]),
      onTap: onTap,
    );
  }

  void _showAddOfflinePatientDialog(AppStrings s) {
    final nameCtrl      = TextEditingController();
    final phoneCtrl     = TextEditingController();
    final diagnosisCtrl = TextEditingController();
    final ageCtrl       = TextEditingController();
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Patient Without Account',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Patient won\'t need to log in',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                LebanonPhoneField(controller: phoneCtrl, label: 'Phone (optional)'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: diagnosisCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Primary Diagnosis (optional)',
                    prefixIcon: const Icon(Icons.medical_information_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Age (optional)',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final age = int.tryParse(v.trim());
                    if (age == null || age < 0 || age > 150) return 'Enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setLocal(() => saving = true);
                            final patientName = nameCtrl.text.trim();
                            final phone      = LebanonPhoneField.toStored(phoneCtrl.text);
                            final diagnosis  = diagnosisCtrl.text.trim();
                            final ageVal     = int.tryParse(ageCtrl.text.trim());
                            final messenger  = ScaffoldMessenger.of(context);
                            try {
                              final myUid = Supabase.instance.client.auth.currentUser!.id;

                              final newRow = await Supabase.instance.client
                                  .from('users').insert({
                                'name':        patientName,
                                'role':        'patient',
                                'doctor_ids':  [myUid],
                                'has_account': false,
                                'created_at':  DateTime.now().toIso8601String(),
                              }).select('id').single();
                              final patientId = newRow['id'] as String;

                              // Optional fields
                              final extras = <String, dynamic>{};
                              if (phone.isNotEmpty) extras['phone'] = phone;
                              if (ageVal != null) {
                                extras['date_of_birth'] =
                                    '${DateTime.now().year - ageVal}-01-01';
                              }
                              if (diagnosis.isNotEmpty) extras['primary_diagnosis'] = diagnosis;
                              if (extras.isNotEmpty) {
                                await Supabase.instance.client
                                    .from('users').update(extras).eq('id', patientId);
                              }

                              // Sync doctor's assigned_patient_ids
                              final myData = await Supabase.instance.client
                                  .from('users').select('assigned_patient_ids')
                                  .eq('id', myUid).maybeSingle();
                              final myIds = List<String>.from(
                                  (myData?['assigned_patient_ids'] as List?) ?? []);
                              if (!myIds.contains(patientId)) {
                                myIds.add(patientId);
                                await Supabase.instance.client.from('users')
                                    .update({'assigned_patient_ids': myIds}).eq('id', myUid);
                              }

                              final doctorName = await _service.getMyName();
                              await _service.notifyPatientAdded(patientId, doctorName);

                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              messenger.showSnackBar(SnackBar(
                                content: Text('$patientName added to your patient list.'),
                                backgroundColor: AppColors.success,
                              ));
                            } catch (e) {
                              if (kDebugMode) debugPrint('addOfflinePatient error: $e');
                              if (!ctx.mounted) return;
                              setLocal(() => saving = false);
                              messenger.showSnackBar(SnackBar(
                                content: Text('Failed to add patient: $e'),
                                backgroundColor: AppColors.error,
                              ));
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Add Patient',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPatientDialog(
    AppStrings s,
    String patientId,
    String patientName, {
    String phone = '',
    String diagnosis = '',
    String? dateOfBirth,
    bool hasAccount = true,
  }) {
    final nameCtrl      = TextEditingController(text: hasAccount ? '' : patientName);
    final phoneCtrl     = TextEditingController(
        text: phone.isNotEmpty ? LebanonPhoneField.stripCountryCode(phone) : '');
    final diagnosisCtrl = TextEditingController(text: diagnosis);

    int? currentAge;
    if (dateOfBirth != null) {
      final dob = DateTime.tryParse(dateOfBirth);
      if (dob != null) currentAge = DateTime.now().year - dob.year;
    }
    final ageCtrl = TextEditingController(text: currentAge?.toString() ?? '');

    bool saving = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.edit_rounded, size: 20),
                    const SizedBox(width: 8),
                    const Text('Edit Patient Info',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  Text(patientName,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  // Name — editable only for offline patients
                  if (!hasAccount) ...[
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon:
                            const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  LebanonPhoneField(
                      controller: phoneCtrl, label: 'Phone (optional)'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: diagnosisCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Primary Diagnosis (optional)',
                      prefixIcon: const Icon(
                          Icons.medical_information_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age (optional)',
                      prefixIcon:
                          const Icon(Icons.cake_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final age = int.tryParse(v.trim());
                      if (age == null || age < 0 || age > 150) {
                        return 'Enter a valid age';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              setLocal(() => saving = true);
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              final ageVal =
                                  int.tryParse(ageCtrl.text.trim());
                              final storedPhone =
                                  LebanonPhoneField.toStored(
                                      phoneCtrl.text);
                              final updates = <String, dynamic>{
                                'phone': storedPhone,
                                'primary_diagnosis':
                                    diagnosisCtrl.text.trim(),
                                'date_of_birth': ageVal != null
                                    ? '${DateTime.now().year - ageVal}-01-01'
                                    : null,
                              };
                              if (!hasAccount) {
                                updates['name'] = nameCtrl.text.trim();
                              }
                              final ok = await _service
                                  .updatePatientInfo(patientId, updates);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              messenger.showSnackBar(SnackBar(
                                content: Text(ok
                                    ? 'Patient updated successfully.'
                                    : 'Failed to update patient.'),
                                backgroundColor: ok
                                    ? AppColors.success
                                    : AppColors.error,
                              ));
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSearchExistingPatients(AppStrings s) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> runSearch(String q) async {
            if (q.trim().length < 2) {
              setLocal(() => results = []);
              return;
            }
            setLocal(() => searching = true);
            try {
              final found = await _service.searchAllPatients(q);
              setLocal(() {
                results   = found;
                searching = false;
              });
            } catch (_) {
              setLocal(() => searching = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Existing Patient',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Search by name, email, or diagnosis',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 14),
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  onChanged: runSearch,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.primary),
                    suffixIcon: searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)))
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                if (results.isEmpty &&
                    searchCtrl.text.trim().length >= 2 &&
                    !searching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                        child: Text('No patients found.',
                            style: TextStyle(
                                color: AppColors.textSecondary))),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(ctx).size.height * 0.45),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final d = results[i];
                        final name  = d['name'] ?? d['email'] ?? 'Patient';
                        final email = d['email'] ?? '';
                        final diagnosis = d['primary_diagnosis'] ?? '';
                        final photo = d['profile_photo_url'] ?? '';
                        final docIds =
                            (d['doctor_ids'] as List?)?.cast<String>() ?? [];
                        final alreadyAdded =
                            docIds.contains(_service.currentUid);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary
                                  .withValues(alpha: 0.1),
                              backgroundImage: photo.isNotEmpty
                                  ? NetworkImage(photo)
                                  : null,
                              child: photo.isEmpty
                                  ? const Icon(Icons.person_rounded,
                                      color: AppColors.primary)
                                  : null,
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                if (diagnosis.isNotEmpty)
                                  Text(diagnosis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary)),
                              ],
                            ),
                            trailing: alreadyAdded
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: const Text('Added',
                                        style: TextStyle(
                                            color: AppColors.success,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.bold)),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize
                                          .shrinkWrap,
                                    ),
                                    onPressed: () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final ok =
                                          await _service.addExistingPatient(
                                              results[i]['id'] as String);
                                      if (!ctx.mounted) return;
                                      if (ok) {
                                        final dName =
                                            await _service.getMyName();
                                        await _service.notifyPatientAdded(
                                            results[i]['id'] as String, dName);
                                        messenger.showSnackBar(SnackBar(
                                          content: Text(
                                              '$name added to your roster!'),
                                          backgroundColor:
                                              AppColors.success,
                                        ));
                                        await runSearch(searchCtrl.text);
                                      }
                                    },
                                    child: const Text('Add',
                                        style:
                                            TextStyle(fontSize: 12)),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Patient summary sheet ─────────────────────────────────────────────────

  void _showPatientSummary(
      AppStrings s, String patientId, String patientName, String photoUrl,
      {bool hasAccount = true, String phone = '',
       String diagnosis = '', String? dateOfBirth}) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            // drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
            ),
            // Patient header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patientName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    if (diagnosis.isNotEmpty)
                      Text(diagnosis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    if (phone.isNotEmpty)
                      Text(phone,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                )),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPatientActions(s, patientId, patientName, photoUrl,
                        hasAccount: hasAccount, phone: phone,
                        diagnosis: diagnosis, dateOfBirth: dateOfBirth);
                  },
                  icon: const Icon(Icons.more_horiz_rounded, size: 18),
                  label: const Text('Actions'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ]),
            ),
            const Divider(height: 1),
            // Summary body
            Expanded(
              child: FutureBuilder<List<List<Map<String, dynamic>>>>(
                future: Future.wait([
                  Supabase.instance.client
                      .from('appointments')
                      .select()
                      .eq('patient_id', patientId)
                      .eq('doctor_id', uid)
                      .order('appointment_time', ascending: false)
                      .then((d) => List<Map<String, dynamic>>.from(d)),
                  Supabase.instance.client
                      .from('invoices')
                      .select()
                      .eq('patient_id', patientId)
                      .eq('doctor_id', uid)
                      .then((d) => List<Map<String, dynamic>>.from(d)),
                ]),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final appts    = snap.data?[0] ?? [];
                  final invoices = snap.data?[1] ?? [];
                  final now      = DateTime.now();
                  final upcoming = appts.where((a) {
                    final t = DateTime.tryParse(a['appointment_time'] as String? ?? '');
                    return t != null && t.isAfter(now) && (a['status'] as String? ?? '') != 'cancelled';
                  }).length;
                  final completed = appts.where((a) {
                    final t = DateTime.tryParse(a['appointment_time'] as String? ?? '');
                    return t != null && t.isBefore(now);
                  }).length;
                  final totalRevenue = invoices.fold<double>(0, (sum, inv) {
                    return sum + ((inv['amount'] as num?)?.toDouble() ?? 0);
                  });
                  final paidRevenue = invoices.where((inv) => (inv['status'] as String? ?? '') == 'paid')
                      .fold<double>(0, (sum, inv) => sum + ((inv['amount'] as num?)?.toDouble() ?? 0));

                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      // ── Summary KPI cards ───────────────────────────
                      Row(children: [
                        _summaryKpi('Total Sessions', '${appts.length}',
                            Icons.calendar_today_rounded, AppColors.primary),
                        const SizedBox(width: 10),
                        _summaryKpi('Upcoming', '$upcoming',
                            Icons.event_rounded, const Color(0xFF1565C0)),
                        const SizedBox(width: 10),
                        _summaryKpi('Completed', '$completed',
                            Icons.check_circle_rounded, AppColors.success),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _summaryKpi('Total Billed',
                            '\$${totalRevenue.toStringAsFixed(0)}',
                            Icons.receipt_long_rounded, AppColors.primary),
                        const SizedBox(width: 10),
                        _summaryKpi('Paid',
                            '\$${paidRevenue.toStringAsFixed(0)}',
                            Icons.payments_rounded, AppColors.success),
                        const SizedBox(width: 10),
                        _summaryKpi('Pending',
                            '\$${(totalRevenue - paidRevenue).toStringAsFixed(0)}',
                            Icons.pending_rounded, AppColors.warning),
                      ]),

                      // ── Recent appointments ────────────────────────
                      const SizedBox(height: 18),
                      const Text('Appointment History',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (appts.isEmpty)
                        const Text('No appointments yet.',
                            style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...appts.take(8).map((a) {
                          final dt  = DateTime.tryParse(a['appointment_time'] as String? ?? '');
                          final status = (a['status'] as String? ?? 'scheduled');
                          final isPast  = dt != null && dt.isBefore(now);
                          final statusColor = status == 'cancelled'
                              ? AppColors.error
                              : isPast ? AppColors.textSecondary : AppColors.primary;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Container(
                                width: 48,
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(children: [
                                  Text(dt != null ? DateFormat('MMM d').format(dt) : '—',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                                  Text(dt != null ? DateFormat('h:mm a').format(dt) : '',
                                      style: TextStyle(fontSize: 9, color: statusColor)),
                                ]),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  (a['notes'] as String? ?? '').isNotEmpty
                                      ? (a['notes'] as String)
                                      : 'Session',
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status == 'cancelled' ? 'Cancelled' : isPast ? 'Done' : 'Upcoming',
                                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ]),
                          );
                        }),

                      // ── Recent invoices ────────────────────────────
                      if (invoices.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Text('Revenue',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 8),
                        ...invoices.take(5).map((inv) {
                          final amount  = (inv['amount'] as num?)?.toDouble() ?? 0;
                          final status  = (inv['status'] as String?) ?? 'pending';
                          final color   = status == 'paid' ? AppColors.success
                              : status == 'cancelled'     ? AppColors.error
                              : AppColors.warning;
                          final dateStr = (inv['created_at'] as String?) ?? '';
                          final dt      = DateTime.tryParse(dateStr);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text((inv['service_name'] as String? ?? '').isNotEmpty
                                      ? inv['service_name'] as String
                                      : 'Session fee',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  if (dt != null)
                                    Text(DateFormat('MMM d, yyyy').format(dt),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ]),
                              ),
                              Text('\$${amount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(status,
                                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          );
                        }),
                      ],
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(
                            Icons.auto_awesome_rounded, size: 18),
                        label: const Text(
                          'Summarize History with AI Doctor Assistant',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAiPatientHistorySummary(
                              patientId, patientName, diagnosis);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Patient History Summary ─────────────────────────────────────────────

  Future<void> _showAiPatientHistorySummary(
      String patientId, String patientName, String diagnosis) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Flexible(
                  child: Text(
                      'AI Doctor Assistant is summarising patient history…')),
            ]),
          ),
        ),
      ),
    );

    try {
      // Fetch up to 8 recent SOAP notes; strip heavy fields before sending
      final notesSnap = await Supabase.instance.client
          .from('clinical_notes')
          .select()
          .eq('patient_id', patientId)
          .eq('doctor_id', uid)
          .order('created_at', ascending: false)
          .limit(8);

      final notes = List<Map<String, dynamic>>.from(notesSnap);
      String cap(String s, int max) =>
          s.length > max ? s.substring(0, max) : s;

      final slim = notes.map((n) {
        final src = (n['soap_data'] as Map<String, dynamic>?) ?? n;
        return {
          'date': (n['created_at'] as String? ?? '').split('T').first,
          'chiefComplaint': cap(
              src['chiefComplaint'] as String? ??
                  src['subjective'] as String? ??
                  '',
              200),
          'interventions': cap(
              src['interventions'] as String? ?? src['plan'] as String? ?? '',
              200),
          'progress': cap(
              src['progressTowardGoals'] as String? ??
                  src['assessment'] as String? ??
                  '',
              150),
        };
      }).toList();

      final result = await AiDoctorAssistantService.summarizePatientHistory(
        patientName: patientName,
        noteCount: notes.length,
        recentNotes: slim,
      );

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      if (!result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error ?? 'Summary generation failed'),
          backgroundColor: AppColors.error,
        ));
        return;
      }

      final summary = result.data!;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.80,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$patientName — AI Summary',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        if (result.usage != null)
                          Text(result.usage!.label,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text(
                  '⚠ AI summarises existing documentation only.',
                  style: TextStyle(color: Color(0xFFE65100), fontSize: 11),
                ),
                const SizedBox(height: 16),
                if (summary.patientSummary.isNotEmpty) ...[
                  _aiSummarySection('Patient Overview',
                      summary.patientSummary, AppColors.primary),
                  const SizedBox(height: 12),
                ],
                if (summary.progressNotes.isNotEmpty) ...[
                  _aiSummarySection('Progress Notes',
                      summary.progressNotes, AppColors.success),
                  const SizedBox(height: 12),
                ],
                if (summary.documentationSummary.isNotEmpty) ...[
                  _aiSummarySection('Documentation Status',
                      summary.documentationSummary, AppColors.textSecondary),
                  const SizedBox(height: 12),
                ],
                if (summary.visitTimeline.isNotEmpty) ...[
                  const Text('Visit Milestones',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...summary.visitTimeline.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                              child: Text(item,
                                  style: const TextStyle(fontSize: 13))),
                        ]),
                  )),
                  const SizedBox(height: 12),
                ],
                if (summary.importantRecords.isNotEmpty) ...[
                  const Text('Notable Findings',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...summary.importantRecords.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.flag_rounded,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(item,
                                  style: const TextStyle(fontSize: 13))),
                        ]),
                  )),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('AI error: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _aiSummarySection(String title, String content, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: color)),
        const SizedBox(height: 6),
        Text(content,
            style: const TextStyle(fontSize: 13, height: 1.5)),
      ]),
    );
  }

  Widget _summaryKpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  void _showPatientActions(
      AppStrings s, String patientId, String patientName, String photoUrl,
      {bool hasAccount = true, String phone = '',
       String diagnosis = '', String? dateOfBirth}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient header
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person_rounded,
                          color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(patientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(s.selectAction,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 16),
              _actionTile(
                icon: Icons.calendar_today_rounded,
                color: Colors.blue.shade600,
                title: s.scheduleAppointment,
                onTap: () {
                  Navigator.pop(ctx);
                  _showBookAppointmentSheet(s,
                      prePatientId:   patientId,
                      prePatientName: patientName);
                },
              ),
              _actionTile(
                icon: Icons.history_rounded,
                color: const Color(0xFF00897B),
                title: 'View Appointments',
                subtitle: 'Previous & upcoming with Excel export',
                onTap: () {
                  Navigator.pop(ctx);
                  _showPatientAppointmentsSheet(patientId, patientName);
                },
              ),
              _actionTile(
                icon: Icons.description_rounded,
                color: AppColors.primary,
                title: s.addDocumentation,
                subtitle: s.soapDoctorOnly,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SoapNoteScreen(
                        patientId:   patientId,
                        patientName: patientName,
                      ),
                    ),
                  );
                },
              ),
              _actionTile(
                icon: Icons.fitness_center_rounded,
                color: AppColors.primary,
                title: 'Exercise Programs (HEP)',
                subtitle: 'Create or edit home exercise programs',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HepProgramListScreen(
                        patientId:   patientId,
                        patientName: patientName,
                      ),
                    ),
                  );
                },
              ),
              _actionTile(
                icon: Icons.edit_rounded,
                color: const Color(0xFF7B61FF),
                title: 'Edit Patient Info',
                subtitle: 'Update phone, diagnosis, or age',
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditPatientDialog(
                    s, patientId, patientName,
                    phone: phone,
                    diagnosis: diagnosis,
                    dateOfBirth: dateOfBirth,
                    hasAccount: hasAccount,
                  );
                },
              ),
              // Phone / WhatsApp (only when patient has a phone number)
              if (phone.isNotEmpty)
                _actionTile(
                  icon: Icons.phone_in_talk_rounded,
                  color: const Color(0xFF25D366),
                  title: 'Call / WhatsApp',
                  subtitle: phone,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPhoneOptions(context, phone);
                  },
                ),
              // Create Account (only for patients without one)
              if (!hasAccount)
                _actionTile(
                  icon: Icons.manage_accounts_rounded,
                  color: AppColors.primary,
                  title: 'Create Account',
                  subtitle: 'Set up login credentials for this patient',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatePatientScreen(
                            prefillName: patientName,
                            existingPatientId: patientId),
                      ),
                    );
                  },
                ),
              // Remove from list
              _actionTile(
                icon: Icons.person_remove_rounded,
                color: AppColors.error,
                title: 'Remove from My Patients',
                subtitle: 'Unlink this patient from your list',
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Remove Patient'),
                      content: Text(
                          'Remove $patientName from your patient list?'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(d, false),
                            child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () =>
                              Navigator.pop(d, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _removePatient(patientId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('$patientName removed from your list.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.background,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: ListTile(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary))
            : null,
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }


  Widget _buildPatientsTab(AppStrings s) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.getAssignedPatients(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allPatients = snap.data ?? [];
          if (allPatients.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline_rounded,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(s.noPatients,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add Patient'),
                  onPressed: () => _showAddPatientMenu(s),
                ),
              ]),
            );
          }

          String searchQuery  = '';
          String sortBy       = 'name';
          var    selectionMode = false;
          final  selectedIds   = <String>{};
          return StatefulBuilder(
            builder: (context, setState) {
              // ── Filter ────────────────────────────────────────────────
              var filteredPatients = allPatients
                  .where((p) {
                    final data = p;
                    final name =
                        (data['name'] ?? data['email'] ?? '').toString();
                    final condition =
                        (data['primary_diagnosis'] ?? '').toString();
                    final phone = (data['phone'] ?? '').toString();
                    final q = searchQuery.toLowerCase();
                    return name.toLowerCase().contains(q) ||
                        condition.toLowerCase().contains(q) ||
                        phone.toLowerCase().contains(q);
                  })
                  .toList();

              // ── Sort ─────────────────────────────────────────────────
              switch (sortBy) {
                case 'condition':
                  filteredPatients.sort((a, b) {
                    final da = a['primary_diagnosis'] as String? ?? '';
                    final db = b['primary_diagnosis'] as String? ?? '';
                    return da.toLowerCase().compareTo(db.toLowerCase());
                  });
                case 'account':
                  filteredPatients.sort((a, b) {
                    bool ha(Map<String, dynamic> p) {
                      final d = p;
                      return (d['email'] as String? ?? '').isNotEmpty &&
                          (d['has_account'] as bool? ?? true);
                    }
                    return ha(b) ? 1 : (ha(a) ? -1 : 0);
                  });
                case 'date':
                  filteredPatients.sort((a, b) {
                    final ta = a['created_at'] as String?;
                    final tb = b['created_at'] as String?;
                    if (ta == null && tb == null) return 0;
                    if (ta == null) return 1;
                    if (tb == null) return -1;
                    return tb.compareTo(ta); // newest first
                  });
                default: // 'name'
                  filteredPatients.sort((a, b) {
                    final na = (a['name'] ?? a['email'] ?? '') as String;
                    final nb = (b['name'] ?? b['email'] ?? '') as String;
                    return na.toLowerCase().compareTo(nb.toLowerCase());
                  });
              }

              void toggleOne(String id) => setState(() {
                if (selectedIds.contains(id)) {
                  selectedIds.remove(id);
                } else {
                  selectedIds.add(id);
                }
              });
              void enterSelection(String id) => setState(() {
                selectionMode = true;
                selectedIds.add(id);
              });
              void exitSelection() => setState(() {
                selectionMode = false;
                selectedIds.clear();
              });

              return Column(
                children: [
                  // ── Header: selection bar OR search+add bar ────────────
                  selectionMode
                    ? Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                        child: Row(children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Cancel selection',
                            onPressed: exitSelection,
                          ),
                          Text(
                            '${selectedIds.length} selected',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              selectedIds.addAll(filteredPatients
                                  .map((p) => p['id'] as String));
                            }),
                            child: const Text('Select all'),
                          ),
                        ]),
                      )
                    : Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (v) =>
                                      setState(() => searchQuery = v),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by name, condition, contact…',
                                    prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        color: AppColors.primary),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                icon: const Icon(Icons.add_rounded,
                                    size: 20),
                                label: const Text('Add Patient',
                                    style: TextStyle(fontSize: 13)),
                                onPressed: () => _showAddPatientMenu(s),
                              ),
                              if (FormFactorFeatures.of(context)
                                  .showPatientsImportExport) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Export to Excel',
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Icon(
                                        Icons.download_rounded,
                                        size: 20),
                                    onPressed: () => _exportPatientsExcel(
                                        filteredPatients),
                                  ),
                                ),
                              ],
                            ]),
                          ],
                        ),
                      ),

                  // ── Patient list / table ──────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: filteredPatients.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text('No patients found',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                              ),
                            )
                          : FormFactorFeatures.of(context).isMobile
                              ? _buildPatientsCardList(
                                  s, filteredPatients,
                                  selectionMode: selectionMode,
                                  selectedIds: selectedIds,
                                  onToggle: toggleOne,
                                  onLongPress: enterSelection,
                                )
                              : _buildPatientsTable(
                                  s, filteredPatients,
                                  sortBy: sortBy,
                                  onSortChanged: (v) =>
                                      setState(() => sortBy = v),
                                  selectionMode: selectionMode,
                                  selectedIds: selectedIds,
                                  onToggle: toggleOne,
                                  onToggleAll: () => setState(() {
                                    final all = filteredPatients
                                        .map((p) => p['id'] as String)
                                        .toSet();
                                    if (selectedIds.containsAll(all)) {
                                      selectedIds.removeAll(all);
                                    } else {
                                      selectedIds.addAll(all);
                                    }
                                  }),
                                  onLongPress: enterSelection,
                                ),
                    ),
                  ),

                  // ── Bulk action bar (visible only in selection mode) ───
                  if (selectionMode && selectedIds.isNotEmpty)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(
                              Icons.person_remove_rounded, size: 18),
                          label: Text(
                            'Remove ${selectedIds.length} '
                            'patient${selectedIds.length == 1 ? '' : 's'}'
                            ' from My Patients',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _bulkRemovePatients(
                            selectedIds.toList(),
                            () => exitSelection(),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Mobile replacement for the desktop 5-column patients table: a vertical
  /// list of cards (avatar, name, condition). Tapping a card opens the same
  /// action sheet as the desktop table row (schedule / view appointments /
  /// add documentation / etc.). Desktop's table is unchanged.
  Widget _buildPatientsCardList(
      AppStrings s, List<Map<String, dynamic>> patients, {
      bool selectionMode = false,
      Set<String> selectedIds = const {},
      void Function(String)? onToggle,
      void Function(String)? onLongPress,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final data        = patients[i];
        final patientId   = patients[i]['id'] as String;
        final name        = (data['name'] ?? data['email'] ?? 'Patient') as String;
        final diagnosis   = (data['primary_diagnosis'] ?? '') as String;
        final photoUrl    = (data['profile_photo_url'] ?? '') as String;
        final phone       = (data['phone'] ?? '') as String;
        final dateOfBirth = data['date_of_birth'] as String?;
        final hasAccount  = (data['email'] as String? ?? '').isNotEmpty &&
            (data['has_account'] as bool? ?? true);
        final isSelected  = selectedIds.contains(patientId);

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected && selectionMode
                  ? AppColors.primary
                  : AppColors.cardBorder,
              width: isSelected && selectionMode ? 2 : 1,
            ),
          ),
          color: isSelected && selectionMode
              ? AppColors.primary.withValues(alpha: 0.06)
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: selectionMode
                ? () => onToggle?.call(patientId)
                : () => _showPatientSummary(
                    s, patientId, name, photoUrl,
                    hasAccount: hasAccount, phone: phone,
                    diagnosis: diagnosis, dateOfBirth: dateOfBirth),
            onLongPress: selectionMode
                ? null
                : () => onLongPress?.call(patientId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggle?.call(patientId),
                      activeColor: AppColors.primary,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                Stack(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? Icon(Icons.person_rounded,
                            color: AppColors.primary)
                        : null,
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: hasAccount
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(diagnosis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!selectionMode)
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatientsTable(
      AppStrings s, List<Map<String, dynamic>> patients, {
      required String sortBy,
      required ValueChanged<String> onSortChanged,
      bool selectionMode = false,
      Set<String> selectedIds = const {},
      void Function(String)? onToggle,
      void Function()? onToggleAll,
      void Function(String)? onLongPress,
  }) {
    // Inline helper: sortable column header
    Widget sortHeader(String label, String field, {int flex = 1, bool center = false}) {
      final active = sortBy == field;
      return Expanded(
        flex: flex,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSortChanged(active ? 'name' : field),
          child: Row(
            mainAxisAlignment: center
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      decoration: active
                          ? TextDecoration.underline
                          : null,
                      decorationColor: Colors.white70)),
              const SizedBox(width: 3),
              Icon(
                active
                    ? Icons.arrow_upward_rounded
                    : Icons.unfold_more_rounded,
                size: 12,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      tristate: true,
                      value: patients.every(
                              (p) => selectedIds.contains(p['id'] as String))
                          ? true
                          : patients.any(
                                  (p) => selectedIds.contains(p['id'] as String))
                              ? null
                              : false,
                      onChanged: (_) => onToggleAll?.call(),
                      activeColor: Colors.white,
                      checkColor: const Color(0xFF1565C0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              sortHeader('Patient Name', 'name', flex: 2),
              sortHeader('Condition',    'condition'),
              _th2('Last Visit'),
              _th2('Upcoming'),
              sortHeader('Account', 'account', center: true),
            ]),
          ),
          // Table rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: patients.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF0F4FA)),
            itemBuilder: (_, i) {
              final data        = patients[i];
              final patientId   = patients[i]['id'] as String;
              final name        = (data['name'] ?? data['email'] ?? 'Patient') as String;
              final diagnosis   = (data['primary_diagnosis'] ?? '') as String;
              final photoUrl    = (data['profile_photo_url'] ?? '') as String;
              final phone       = (data['phone'] ?? '') as String;
              final dateOfBirth = data['date_of_birth'] as String?;
              // A patient has an account if they have an email and has_account != false
              final hasAccount = (data['email'] as String? ?? '').isNotEmpty &&
                  (data['has_account'] as bool? ?? true);

              return FutureBuilder<Map<String, DateTime?>>(
                future: _getPatientAppointmentDates(patientId),
                builder: (context, snapshot) {
                  final lastVisit = snapshot.data?['last'];
                  final nextVisit = snapshot.data?['next'];

                  final isSelected = selectedIds.contains(patientId);
                  return Container(
                    color: isSelected && selectionMode
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : i.isEven
                            ? Colors.white
                            : const Color(0xFFF8FAFF),
                    child: GestureDetector(
                      onTap: selectionMode
                          ? () => onToggle?.call(patientId)
                          : () => _showPatientSummary(
                              s, patientId, name, photoUrl,
                              hasAccount: hasAccount, phone: phone,
                              diagnosis: diagnosis, dateOfBirth: dateOfBirth),
                      onLongPress: selectionMode
                          ? null
                          : () => onLongPress?.call(patientId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(children: [
                          if (selectionMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: SizedBox(
                                width: 24, height: 24,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => onToggle?.call(patientId),
                                  activeColor: AppColors.primary,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          // Name + avatar
                          Expanded(
                            flex: 2,
                            child: Row(children: [
                              Stack(children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.15),
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl.isEmpty
                                      ? Icon(Icons.person_rounded,
                                          size: 18,
                                          color: AppColors.primary)
                                      : null,
                                ),
                                // Account dot
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: hasAccount
                                          ? const Color(0xFF2E7D32)
                                          : Colors.grey.shade400,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              ]),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                    if (phone.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          final n = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
                                          launchUrl(Uri.parse('https://wa.me/$n'), mode: LaunchMode.externalApplication);
                                        },
                                        child: Text(phone,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF25D366),
                                                decoration: TextDecoration.underline),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                          // Condition
                          Expanded(
                            child: Text(diagnosis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                          ),
                          // Last visit
                          Expanded(
                            child: Text(
                              lastVisit != null
                                  ? DateFormat('MM/dd').format(lastVisit)
                                  : '—',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Upcoming
                          Expanded(
                            child: Text(
                              nextVisit != null
                                  ? DateFormat('MM/dd').format(nextVisit)
                                  : '—',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Account status / Create Account button
                          Expanded(
                            child: Center(
                              child: hasAccount
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text('Active',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2E7D32))),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize
                                            .shrinkWrap,
                                        textStyle: const TextStyle(
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.bold),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CreatePatientScreen(
                                            prefillName: name,
                                            existingPatientId: hasAccount ? null : patientId,
                                          ),
                                        ),
                                      ),
                                      child: const Text('+ Account'),
                                    ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _th2(String label, {int flex = 1, bool center = false}) => Expanded(
        flex: flex,
        child: Text(label,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  // ── Remove patient ─────────────────────────────────────────────────────────

  Future<void> _removePatient(String patientId) async {
    final myUid = Supabase.instance.client.auth.currentUser!.id;
    final myData = await Supabase.instance.client.from('users').select('assigned_patient_ids').eq('id', myUid).single();
    final myIds = List<String>.from((myData['assigned_patient_ids'] as List?) ?? [])..remove(patientId);
    await Supabase.instance.client.from('users').update({'assigned_patient_ids': myIds}).eq('id', myUid);
    final patData = await Supabase.instance.client.from('users').select('doctor_ids').eq('id', patientId).single();
    final patIds = List<String>.from((patData['doctor_ids'] as List?) ?? [])..remove(myUid);
    await Supabase.instance.client.from('users').update({'doctor_ids': patIds}).eq('id', patientId);
  }

  // ── Bulk-remove patients ───────────────────────────────────────────────────

  Future<void> _bulkRemovePatients(
      List<String> ids, VoidCallback onDone) async {
    final n = ids.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove patients'),
        content: Text(
          'Remove $n patient${n == 1 ? '' : 's'} from your list?\n'
          'Their accounts are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    _showLoading('Removing patients…');
    try {
      for (final id in ids) {
        await _removePatient(id);
      }
      onDone();
    } finally {
      _hideLoading();
      if (mounted) setState(() {});
    }
  }

  // ── Export patients to Excel ───────────────────────────────────────────────

  Future<void> _exportPatientsExcel(
      List<Map<String, dynamic>> patients) async {
    final excel = xl.Excel.createExcel();
    excel.rename('Sheet1', 'Patients');
    final sheet = excel['Patients'];

    sheet.appendRow([
      xl.TextCellValue('Patient Name'),
      xl.TextCellValue('Condition'),
      xl.TextCellValue('Phone'),
      xl.TextCellValue('Email'),
      xl.TextCellValue('Account Status'),
    ]);

    for (final p in patients) {
      final d          = p;
      final email      = (d['email'] as String?) ?? '';
      final hasAccount = email.isNotEmpty &&
          (d['has_account'] as bool? ?? true);
      sheet.appendRow([
        xl.TextCellValue((d['name'] ?? d['email'] ?? '') as String),
        xl.TextCellValue((d['primary_diagnosis'] ?? '') as String),
        xl.TextCellValue((d['phone'] ?? '') as String),
        xl.TextCellValue(email),
        xl.TextCellValue(hasAccount ? 'Has Account' : 'No Account'),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null || !mounted) return;
    await downloadExcel(Uint8List.fromList(bytes), 'patients_export.xlsx');
  }

  // ── Phone number helper ────────────────────────────────────────────────────

  void _showPhoneOptions(BuildContext ctx, String phone) {
    if (phone.isEmpty) return;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(phone,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chat_rounded,
                    color: Color(0xFF25D366)),
              ),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('https://wa.me/$cleaned'),
                    mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('Phone Call'),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$cleaned'));
              },
            ),
          ]),
        ),
      ),
    );
  }


  // ════════════════════════════════════════════════════════════════════════════
  // ════════════════════════════════════════════════════════════════════════════
  // 6 – My Profile Tab
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildProfileTab(AppStrings s) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile photo and info
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile photo
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        backgroundImage: _photoCtrl.text.isNotEmpty
                            ? NetworkImage(_photoCtrl.text)
                            : null,
                        child: _photoCtrl.text.isEmpty
                            ? Icon(Icons.person_rounded,
                                size: 45, color: AppColors.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Profile info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text
                                : 'Doctor',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _specCtrl.text.isNotEmpty
                                ? _specCtrl.text
                                : 'Physical Therapist',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(s.editInfo),
                        onPressed: () => _showEditProfileSheet(s),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Tooltip(
                        message: _sub.allowHomeVisit
                            ? ''
                            : 'Disabled by your administrator',
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.white, width: 1),
                            foregroundColor: Colors.white,
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.4),
                          ),
                          icon: const Icon(Icons.map_rounded),
                          label: Text(s.updateLocation),
                          onPressed: !_sub.allowHomeVisit
                              ? null
                              : () async {
                                  final result = await Navigator.push<LatLng>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DoctorLocationPickerScreen(
                                        initialLat: _lat,
                                        initialLng: _lng,
                                      ),
                                    ),
                                  );
                                  if (result != null && mounted) {
                                    setState(() {
                                      _lat = result.latitude;
                                      _lng = result.longitude;
                                    });
                                  }
                                },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Home visit toggle
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.homeVisit,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                          Switch(
                            value: _homeVisit,
                            onChanged: _sub.allowHomeVisit
                                ? (v) => setState(() => _homeVisit = v)
                                : null,
                            activeThumbColor: Colors.white,
                            activeTrackColor: Colors.white30,
                          ),
                        ],
                      ),
                      if (!_sub.allowHomeVisit)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('Disabled by your administrator',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Plan & Subscription card ─────────────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.workspace_premium_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          const Text('Plan & Subscription',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ]),
                        const Divider(height: 20),
                        Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Current Plan',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _sub.tier.bgColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min,
                                      children: [
                                    Icon(_sub.tier.icon,
                                        size: 13,
                                        color: _sub.tier.color),
                                    const SizedBox(width: 4),
                                    Text(_sub.tier.label,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: _sub.tier.color,
                                            fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Expiry Date',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  _sub.expiresAt != null
                                      ? DateFormat('MMM d, yyyy')
                                          .format(_sub.expiresAt!)
                                      : 'No expiry',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _sub.isExpired
                                          ? AppColors.error
                                          : AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _sub.isActive
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _sub.isActive
                                  ? 'Active'
                                  : (_sub.isExpired
                                      ? 'Expired'
                                      : 'Disabled'),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _sub.isActive
                                      ? const Color(0xFF2E7D32)
                                      : AppColors.error),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        // Feature access summary
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: [
                            _planFeatureChip(
                                'Schedule', true),
                            _planFeatureChip(
                                'Documentation', true),
                            _planFeatureChip(
                                'My Patients', true),
                            _planFeatureChip(
                                'Statistics', _sub.statistics),
                            _planFeatureChip(
                                'Income', _sub.billing),
                            _planFeatureChip(
                                'Expenses', _sub.expenses),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Personal Information
                _profileSection(
                  s.personalInformation,
                  [
                    _profileItem(Icons.person_rounded, s.fullName,
                        _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '—'),
                    _profileItem(Icons.medical_services_rounded,
                        s.specialization,
                        _specCtrl.text.isNotEmpty ? _specCtrl.text : '—'),
                    _profileItem(Icons.business_rounded, s.clinicName,
                        _clinicNameCtrl.text.isNotEmpty ? _clinicNameCtrl.text : '—'),
                    _profileItem(Icons.location_on_rounded, s.clinicAddress,
                        _clinicAddrCtrl.text.isNotEmpty ? _clinicAddrCtrl.text : '—'),
                    if (_workingHoursCtrl.text.isNotEmpty)
                      _profileItem(Icons.access_time_rounded, 'Working Hours',
                          _workingHoursCtrl.text),
                  ],
                ),
                const SizedBox(height: 20),
                // Professional Overview
                _profileSection(
                  s.professionalOverview,
                  [
                    _profileItem(Icons.info_outline_rounded, s.bio,
                        _bioCtrl.text.isNotEmpty ? _bioCtrl.text : '—'),
                    _profileItem(Icons.phone_rounded, 'Mobile Number',
                        _phoneCtrl.text.isNotEmpty
                            ? '+961 ${_phoneCtrl.text}'
                            : '—'),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Name change request card ─────────────────────────────
                _buildNameChangeCard(),
                const SizedBox(height: 12),
                // ── Dr. prefix request card ──────────────────────────────
                _buildDrPrefixCard(),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: OutlinedButton.icon(
                    onPressed: _deletingAccount
                        ? null
                        : () => _showDeleteAccountDialog(),
                    icon: _deletingAccount
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.red),
                          )
                        : const Icon(Icons.delete_forever_rounded,
                            color: Colors.red, size: 16),
                    label: Text(
                      _deletingAccount ? 'Deleting...' : 'Delete Account',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrPrefixCard() {
    final statusConfig = <String, Map<String, dynamic>>{
      'none': {
        'icon': Icons.badge_outlined,
        'color': AppColors.textSecondary,
        'label': 'Not requested',
        'sublabel': 'Request admin approval to show "Dr." before your name',
        'actionLabel': 'Request Dr. Prefix',
        'actionColor': const Color(0xFF1565C0),
        'action': _requestDrPrefix,
        'cancelLabel': null,
      },
      'pending': {
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFFF57F17),
        'label': 'Pending approval',
        'sublabel': 'Your request is awaiting admin review',
        'actionLabel': null,
        'cancelLabel': 'Cancel Request',
        'action': null,
      },
      'approved': {
        'icon': Icons.verified_rounded,
        'color': const Color(0xFF2E7D32),
        'label': 'Approved — "Dr." is shown',
        'sublabel': 'Admin approved your Dr. prefix',
        'actionLabel': 'Remove Prefix',
        'actionColor': AppColors.error,
        'action': _cancelDrPrefixRequest,
        'cancelLabel': null,
      },
      'declined': {
        'icon': Icons.cancel_rounded,
        'color': AppColors.error,
        'label': 'Request declined',
        'sublabel': 'You may submit a new request',
        'actionLabel': 'Re-request Dr. Prefix',
        'actionColor': const Color(0xFF1565C0),
        'action': _requestDrPrefix,
        'cancelLabel': null,
      },
    };

    final cfg = statusConfig[_drPrefixStatus] ?? statusConfig['none']!;
    final color = cfg['color'] as Color;
    final hasAction = cfg['actionLabel'] != null;
    final hasCancelAction = cfg['cancelLabel'] != null;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cfg['icon'] as IconData, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Show "Dr." Prefix',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(cfg['label'] as String,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text(cfg['sublabel'] as String,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (hasAction)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cfg['action'] as VoidCallback?,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cfg['actionColor'] as Color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(cfg['actionLabel'] as String,
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          if (hasCancelAction)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelDrPrefixRequest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(cfg['cancelLabel'] as String,
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildNameChangeCard() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _nameChangeRequest == 'pending'
                    ? const Color(0xFFF57F17).withValues(alpha: 0.12)
                    : _nameChangeRequest == 'declined'
                        ? AppColors.error.withValues(alpha: 0.12)
                        : AppColors.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _nameChangeRequest == 'pending'
                    ? Icons.hourglass_top_rounded
                    : _nameChangeRequest == 'declined'
                        ? Icons.cancel_rounded
                        : Icons.drive_file_rename_outline_rounded,
                color: _nameChangeRequest == 'pending'
                    ? const Color(0xFFF57F17)
                    : _nameChangeRequest == 'declined'
                        ? AppColors.error
                        : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Display Name',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  _nameChangeRequest == 'pending'
                      ? 'Pending — change to "$_pendingName"'
                      : _nameChangeRequest == 'declined'
                          ? 'Request declined'
                          : 'Current: ${_nameCtrl.text}',
                  style: TextStyle(
                    color: _nameChangeRequest == 'pending'
                        ? const Color(0xFFF57F17)
                        : _nameChangeRequest == 'declined'
                            ? AppColors.error
                            : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            _nameChangeRequest == 'pending'
                ? 'Your request is awaiting admin review'
                : _nameChangeRequest == 'declined'
                    ? 'Your request was declined — you may submit a new one'
                    : 'Name changes require admin approval',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (_nameChangeRequest == 'pending')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelNameChangeRequest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Cancel Request',
                    style: TextStyle(fontSize: 13)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showNameChangeDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  _nameChangeRequest == 'declined'
                      ? 'Re-request Name Change'
                      : 'Request Name Change',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _showNameChangeDialog() {
    final ctrl = TextEditingController(text: _nameCtrl.text);
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Request Name Change'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Enter your requested new name. An admin will review and approve it.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'New Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlg),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty || name == _nameCtrl.text) {
                Navigator.pop(dlg);
                return;
              }
              Navigator.pop(dlg);
              await _requestNameChange(name);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This permanently deletes all your data and cannot be undone. '
          'Are you sure?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlg, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dlg, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _deletingAccount = true);
    try {
      final error = await AuthService().deleteMyAccount();
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Widget _profileSection(String title, List<Widget> items) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A3A5C))),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: item,
                )),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planFeatureChip(String label, bool enabled) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.lock_rounded,
            size: 11,
            color: enabled ? AppColors.primary : Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? AppColors.primary
                      : Colors.grey.shade500)),
        ]),
      );

  void _showEditProfileSheet(AppStrings s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.editProfile,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                // Profile photo upload
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profile Photo',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary
                                .withValues(alpha: 0.2),
                            backgroundImage: _photoCtrl.text.isNotEmpty
                                ? NetworkImage(_photoCtrl.text)
                                : null,
                            child: _photoCtrl.text.isEmpty
                                ? Icon(Icons.person_rounded,
                                    size: 40,
                                    color: AppColors.primary)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  icon: const Icon(Icons.upload_rounded),
                                  label:
                                      const Text('Upload Photo'),
                                  onPressed: () async {
                                    await _uploadProfilePhoto(
                                        setLocal);
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (_photoCtrl.text.isNotEmpty)
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_rounded),
                                    label:
                                        const Text('Remove'),
                                    onPressed: () {
                                      setLocal(() {
                                        _photoCtrl.clear();
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Name is read-only — changes go through the name-change request flow
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.person_outline_rounded,
                        color: Colors.grey.shade400, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(s.fullName,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text : '—',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade600)),
                      ]),
                    ),
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: Colors.grey.shade400),
                  ]),
                ),
                const SizedBox(height: 10),
                _pField(s.specialization, _specCtrl,
                    Icons.medical_services_outlined),
                const SizedBox(height: 10),
                _pField(s.clinicName, _clinicNameCtrl, Icons.business_rounded),
                const SizedBox(height: 10),
                _pField(s.clinicAddress, _clinicAddrCtrl,
                    Icons.location_on_outlined,
                    maxLines: 2),
                const SizedBox(height: 10),
                _pField('Working Hours', _workingHoursCtrl,
                    Icons.access_time_rounded,
                    maxLines: 3,
                    hint: 'e.g. Mon–Fri: 9am–5pm, Sat: 9am–1pm'),
                const SizedBox(height: 10),
                _pField(s.bio, _bioCtrl, Icons.notes_rounded, maxLines: 4),
                const SizedBox(height: 10),
                LebanonPhoneField(
                    controller: _phoneCtrl, label: 'Mobile Number'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: Text(s.saveProfile,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await _service.saveProfile(
                        bio: _bioCtrl.text,
                        profilePhotoUrl: _photoCtrl.text,
                        specialization: _specCtrl.text,
                        clinicName: _clinicNameCtrl.text,
                        clinicAddress: _clinicAddrCtrl.text,
                        offersHomeVisit: _homeVisit,
                        workingHours: _workingHoursCtrl.text,
                        phone: LebanonPhoneField.toStored(_phoneCtrl.text),
                      );
                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? s.profileSaved
                            : 'Error saving profile'),
                        backgroundColor: ok
                            ? AppColors.success
                            : AppColors.error,
                      ));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile photo upload handler ───────────────────────────────────────

  Future<void> _uploadProfilePhoto(Function(VoidCallback) setLocal) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      // Show upload progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading profile photo...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Upload to Supabase Storage
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final fileName =
          'profile_photos/doctors/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await pickedFile.readAsBytes();
      await Supabase.instance.client.storage.from('profile-photos').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final downloadUrl = Supabase.instance.client.storage.from('profile-photos').getPublicUrl(fileName);

      // Update photo URL in form
      setLocal(() {
        _photoCtrl.text = downloadUrl;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo uploaded successfully'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _pField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  // ── Get patient appointment dates ───────────────────────────────────────

  Future<Map<String, DateTime?>> _getPatientAppointmentDates(
      String patientId) async {
    try {
      final appointments = await Supabase.instance.client
          .from('appointments').select()
          .eq('patient_id', patientId)
          .eq('doctor_id', Supabase.instance.client.auth.currentUser!.id);

      DateTime? lastAppointment;
      DateTime? nextAppointment;
      final now = DateTime.now();

      for (final appt in appointments) {
        final data = appt;
        final apptDateTime =
            ((data['appointment_time'] as String?) != null ? DateTime.parse(data['appointment_time'] as String) : null);

        if (apptDateTime != null) {
          // Last appointment (past appointments)
          if (apptDateTime.isBefore(now)) {
            if (lastAppointment == null ||
                apptDateTime.isAfter(lastAppointment)) {
              lastAppointment = apptDateTime;
            }
          }
          // Next appointment (future appointments)
          if (apptDateTime.isAfter(now)) {
            if (nextAppointment == null ||
                apptDateTime.isBefore(nextAppointment)) {
              nextAppointment = apptDateTime;
            }
          }
        }
      }

      return {
        'last': lastAppointment,
        'next': nextAppointment,
      };
    } catch (e) {
      return {'last': null, 'next': null};
    }
  }

  // ── PDF export ─────────────────────────────────────────────────────────

  Future<void> _exportDocumentationPdf(
      List<Map<String, dynamic>> notes) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.blue900, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PhysioConnect – Documentation',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900)),
              pw.Text(
                DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (_) => notes.map((note) {
          final d = note;
          final patName = (d['patient_name'] as String?) ?? 'Patient';
          final condition = (d['primary_diagnosis'] as String?) ??
              (d['chiefComplaint'] as String?) ??
              'General';
          final ts = ((d['created_at'] as String?) != null ? DateTime.parse(d['created_at'] as String) : null);
          final date =
              ts != null ? DateFormat('dd/MM/yyyy').format(ts) : '—';
          final subjective = (d['subjective'] as String?) ?? '';
          final objective = (d['objective'] as String?) ?? '';
          final assessment = (d['assessment'] as String?) ?? '';
          final plan = (d['plan'] as String?) ?? '';

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(patName,
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(date,
                          style: const pw.TextStyle(
                              fontSize: 11, color: PdfColors.grey600)),
                    ]),
                pw.SizedBox(height: 4),
                pw.Text('Condition: $condition',
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey700)),
                if (subjective.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('Subjective:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(subjective,
                      style: const pw.TextStyle(fontSize: 10)),
                ],
                if (objective.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Objective:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(objective,
                      style: const pw.TextStyle(fontSize: 10)),
                ],
                if (assessment.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Assessment:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(assessment,
                      style: const pw.TextStyle(fontSize: 10)),
                ],
                if (plan.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Plan:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(plan,
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );

    await Printing.layoutPdf(
        onLayout: (format) async => doc.save());
  }

  // ── Per-patient PDF export picker ──────────────────────────────────────

  void _showExportPdfPatientPicker(
      AppStrings s, List<Map<String, dynamic>> allNotes) {
    // Build unique patient list from notes
    final patientMap = <String, String>{}; // patientId -> patientName
    for (final note in allNotes) {
      final d = note;
      final id   = (d['patient_id'] as String?) ?? '';
      final name = (d['patient_name'] as String?) ?? 'Patient';
      if (id.isNotEmpty) patientMap[id] = name;
    }

    if (patientMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No notes available to export.')));
      return;
    }

    String? selectedId = patientMap.keys.first;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Export Patient Notes as PDF',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: InputDecoration(
                  labelText: 'Select Patient',
                  prefixIcon: const Icon(Icons.person_rounded,
                      color: AppColors.primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: patientMap.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => set(() => selectedId = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Export PDF',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (selectedId == null) return;
                    Navigator.pop(ctx);
                    final patientNotes = allNotes
                        .where((n) =>
                            n['patient_id'] ==
                            selectedId)
                        .toList();
                    _exportDocumentationPdf(patientNotes);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Patient appointment sheet + Excel export ───────────────────────────

  void _showPatientAppointmentsSheet(
      String patientId, String patientName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client
              .from('appointments').select()
              .eq('patient_id', patientId)
              .eq('doctor_id', Supabase.instance.client.auth.currentUser!.id)
              .order('appointment_time', ascending: false),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs  = snap.data ?? [];
            final now   = DateTime.now();
            final upcoming = docs.where((d) {
              final ts = d['appointment_time'] as String?;
              return ts != null && DateTime.parse(ts).isAfter(now);
            }).toList();
            final previous = docs.where((d) {
              final ts = d['appointment_time'] as String?;
              return ts != null && !DateTime.parse(ts).isAfter(now);
            }).toList();

            return Column(
              children: [
                // Handle + header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(patientName,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        Text(
                            '${docs.length} total · '
                            '${upcoming.length} upcoming · '
                            '${previous.length} previous',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ]),
                    ),
                    if (FormFactorFeatures.of(context)
                        .showPatientsImportExport)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Excel',
                            style: TextStyle(fontSize: 13)),
                        onPressed: docs.isEmpty
                            ? null
                            : () => _exportAppointmentsExcel(
                                patientName, docs),
                      ),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _apptSectionHeader(
                            'Upcoming', upcoming.length,
                            const Color(0xFF1565C0)),
                        ...upcoming.map((d) =>
                            _apptCard(d, upcoming: true)),
                        const SizedBox(height: 16),
                      ],
                      if (previous.isNotEmpty) ...[
                        _apptSectionHeader(
                            'Previous', previous.length,
                            const Color(0xFF546E7A)),
                        ...previous.map((d) =>
                            _apptCard(d, upcoming: false)),
                      ],
                      if (docs.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No appointments yet.',
                                style: TextStyle(
                                    color: AppColors.textSecondary)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _apptSectionHeader(String label, int count, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(20)),
            child: Text('$label  $count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      );

  Widget _apptCard(Map<String, dynamic> doc, {required bool upcoming}) {
    final d    = doc;
    final ts   = ((d['appointment_time'] as String?) != null ? DateTime.parse(d['appointment_time'] as String) : null);
    final date = ts != null
        ? DateFormat('EEE, MMM d yyyy').format(ts)
        : '—';
    final time = ts != null ? DateFormat('h:mm a').format(ts) : '';
    final notes  = (d['notes'] as String?) ?? '';
    final status = (d['status'] as String?) ?? 'scheduled';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
              color: upcoming
                  ? const Color(0xFF1565C0).withValues(alpha: 0.3)
                  : Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: upcoming
                  ? const Color(0xFF1565C0).withValues(alpha: 0.08)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              Text(
                ts != null ? DateFormat('d').format(ts) : '—',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: upcoming
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade600),
              ),
              Text(
                ts != null ? DateFormat('MMM').format(ts) : '',
                style: TextStyle(
                    fontSize: 11,
                    color: upcoming
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade500),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(time,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(date,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              if (notes.isNotEmpty)
                Text(notes,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: upcoming
                  ? const Color(0xFFE3F2FD)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: upcoming
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade600)),
          ),
        ]),
      ),
    );
  }

  Future<void> _exportAppointmentsExcel(
      String patientName, List<Map<String, dynamic>> docs) async {
    final excel = xl.Excel.createExcel();
    excel.rename('Sheet1', 'Appointments');
    final sheet = excel['Appointments'];

    sheet.appendRow([
      xl.TextCellValue('Patient Name'),
      xl.TextCellValue('Date'),
      xl.TextCellValue('Time'),
      xl.TextCellValue('Notes'),
      xl.TextCellValue('Status'),
    ]);

    for (final doc in docs) {
      final d    = doc;
      final ts   = ((d['appointment_time'] as String?) != null ? DateTime.parse(d['appointment_time'] as String) : null);
      final date = ts != null ? DateFormat('dd/MM/yyyy').format(ts) : '';
      final time = ts != null ? DateFormat('h:mm a').format(ts) : '';
      sheet.appendRow([
        xl.TextCellValue(patientName),
        xl.TextCellValue(date),
        xl.TextCellValue(time),
        xl.TextCellValue((d['notes'] as String?) ?? ''),
        xl.TextCellValue((d['status'] as String?) ?? 'scheduled'),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) return;

    final safe = patientName.replaceAll(RegExp(r'[^\w]'), '_');
    await downloadExcel(Uint8List.fromList(bytes), '${safe}_appointments.xlsx');
  }

  // ── Import patients from Excel ─────────────────────────────────────────

  /// Try common date string formats; also handles Excel double serials.
  DateTime? _tryParseDate(String s) {
    if (s.isEmpty) return null;

    // 1) Let Dart's own parser handle ISO 8601 (e.g. DateTimeCellValue.toString()
    //    returns "2024-01-15T00:00:00.000" which DateTime.tryParse handles natively)
    final direct = DateTime.tryParse(s);
    if (direct != null) return direct;

    // 2) Strip time component — split on 'T' or space
    final datePart = s.split(RegExp(r'[T ]')).first.trim();

    for (final fmt in [
      'dd/MM/yyyy', 'd/M/yyyy',
      'yyyy-MM-dd',
      'MM/dd/yyyy', 'M/d/yyyy',
      'MM-dd-yyyy',
      'dd/MM/yy',   'd/M/yy',
    ]) {
      try { return DateFormat(fmt).parseStrict(datePart); } catch (_) {}
    }

    // 3) Excel serial number stored as a string (e.g. "45296.0")
    final serial = double.tryParse(s);
    if (serial != null && serial > 1000) {
      final adjusted = serial > 59 ? serial - 1 : serial;
      return DateTime(1899, 12, 31)
          .add(Duration(days: adjusted.toInt()));
    }
    return null;
  }

  // ── Unified Excel import (patients + schedule + revenues) ────────────────

  Future<void> _importUnifiedFromExcel(AppStrings s) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    if (!mounted) return;
    _showImportProgress();
    await Future.delayed(Duration.zero);

    List<_UnifiedRow>? rows;
    try {
      _setProgress(0.10, 'Decoding Excel…');
      final excel = decodeExcelBytes(bytes);
      if (excel.tables.isEmpty) {
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sheets found in the file.'))); }
        return;
      }

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data found in the file.'))); }
        return;
      }

      _setProgress(0.25, 'Parsing columns…');

      // Default: A=Date  B=Name  C=Amount  D=Service  E=Status  F=Note
      int dateCol = 0, nameCol = 1, amtCol = 2, svcCol = 3, statusCol = 4, noteCol = 5;
      bool hasHeader = false;
      final headerRow = sheet.rows.first;
      for (int i = 0; i < headerRow.length; i++) {
        final h = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
        if (h.contains('date') || h.contains('appt'))          { dateCol   = i; hasHeader = true; }
        if (h.contains('name') || h.contains('patient'))       { nameCol   = i; hasHeader = true; }
        if (h == 'amount' || h == 'amt' || h.contains('amou')) { amtCol    = i; hasHeader = true; }
        if (h.contains('service') || h.contains('svc'))        { svcCol    = i; hasHeader = true; }
        if (h.contains('status'))                               { statusCol = i; hasHeader = true; }
        if (h.contains('note'))                                 { noteCol   = i; hasHeader = true; }
      }

      String cellStr(List<xl.Data?> row, int col) =>
          col < row.length ? (row[col]?.value?.toString().trim() ?? '') : '';

      String parseStatus(String raw) => switch (raw.toLowerCase().trim()) {
        'paid'                                => 'paid',
        'partially_paid' || 'partially paid' => 'partially_paid',
        'cancelled'      || 'canceled'       => 'cancelled',
        _                                     => 'pending',
      };

      rows = <_UnifiedRow>[];
      final dataRows = hasHeader ? sheet.rows.skip(1) : sheet.rows;

      for (final row in dataRows) {
        if (row.isEmpty) continue;
        final name = cellStr(row, nameCol);
        if (name.isEmpty) continue;
        final dateStr   = cellStr(row, dateCol);
        final amtStr    = cellStr(row, amtCol).replaceAll(',', '').replaceAll(' ', '');
        final svc       = cellStr(row, svcCol);
        final statusRaw = cellStr(row, statusCol);
        final note      = cellStr(row, noteCol);

        final date   = dateStr.isNotEmpty ? _tryParseDate(dateStr) : null;
        final amount = double.tryParse(amtStr);

        rows.add(_UnifiedRow(
          name:      name,
          date:      date,
          amount:    (amount != null && amount > 0) ? amount : null,
          service:   svc.isEmpty ? 'Physical Therapy' : svc,
          statusKey: parseStatus(statusRaw),
          note:      note,
        ));
      }

      if (rows.isEmpty) {
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid rows found in the file.'))); }
        return;
      }

      _setProgress(0.45, 'Parsed ${rows.length} rows — matching patients…');

      // Pre-match existing patients
      final patientDocs = await _service.getAssignedPatientsOnce();
      String norm(String n) => n.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
      for (int i = 0; i < rows.length; i++) {
        _setProgress(0.45 + 0.50 * ((i + 1) / rows.length),
            'Matching patient ${i + 1} of ${rows.length}…');
        final row = rows[i];
        final q = norm(row.name);
        Map<String, dynamic>? match =
            patientDocs.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p != null && norm((p['name'] as String?) ?? '') == q,
          orElse: () => null,
        );
        match ??= patientDocs.cast<Map<String, dynamic>?>().firstWhere(
          (p) {
            if (p == null) return false;
            final n = norm((p['name'] as String?) ?? '');
            return n.isNotEmpty && (n.contains(q) || q.contains(n));
          },
          orElse: () => null,
        );
        row.patientId = match?['id'] as String?;
      }
      _setProgress(0.98, 'Ready — review and confirm…');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to read file: $e'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    } finally {
      _hideLoading();
    }

    if (!mounted) return;
    _showUnifiedImportPreview(rows, s);
  }

  void _showUnifiedImportPreview(List<_UnifiedRow> rows, AppStrings s) {
    // Pre-compute first-occurrence flags for unmatched names.
    // Rows with the same name share one patient; only the first shows the
    // "new patient" badge — subsequent duplicates show a "linked" badge instead.
    String normName(String n) =>
        n.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final seenNew = <String>{};
    final isFirstNew = rows.map((r) {
      if (r.patientId != null) return false; // already matched → not "new"
      return seenNew.add(normName(r.name));  // true on first insertion
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (ctx, set) {
            final selected    = rows.where((r) => r.selected).length;
            final allSelected = selected == rows.length;
            final apptCount   = rows.where((r) => r.selected && r.hasDate).length;
            final invCount    = rows.where((r) => r.selected && r.hasAmount).length;
            // Count unique new-patient names among selected rows only.
            final newPatCount = rows
                .where((r) => r.selected && r.patientId == null)
                .map((r) => normName(r.name))
                .toSet()
                .length;

            return Column(children: [
              // Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                child: Row(children: [
                  Checkbox(
                    tristate: true,
                    value: allSelected ? true : (selected == 0 ? false : null),
                    activeColor: AppColors.primary,
                    onChanged: (_) => set(() {
                      final target = !allSelected;
                      for (final r in rows) { r.selected = target; }
                    }),
                  ),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Unified Import · $selected / ${rows.length} selected',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Row(children: [
                        if (apptCount > 0) ...[
                          const Icon(Icons.calendar_month_rounded,
                              size: 11, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text('$apptCount appt${apptCount == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.primary)),
                          const SizedBox(width: 8),
                        ],
                        if (invCount > 0) ...[
                          const Icon(Icons.receipt_rounded,
                              size: 11, color: Color(0xFF0E8378)),
                          const SizedBox(width: 3),
                          Text('$invCount invoice${invCount == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF0E8378))),
                          const SizedBox(width: 8),
                        ],
                        if (newPatCount > 0) ...[
                          const Icon(Icons.person_add_rounded,
                              size: 11, color: Color(0xFFE65100)),
                          const SizedBox(width: 3),
                          Text('$newPatCount new',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFFE65100))),
                        ],
                      ]),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    color: Colors.grey.shade500,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => showImportHelpSheet(
                      ctx,
                      title: 'Unified Import',
                      subtitle: 'Column layout for the unified Excel sheet',
                      columns: ['Date', 'Name', 'Amount', 'Service', 'Status', 'Note'],
                      examples: [
                        ['01/15/2024', 'John Smith', '',    'PT Session',   '',        ''],
                        ['02/10/2024', 'Sara Lee',   '150', 'Follow-up',    'paid',    ''],
                        ['',           'Mike Brown', '200', 'Initial Eval', 'pending', 'First visit'],
                      ],
                      notes: [
                        'Date — appointment date (dd/MM/yyyy or yyyy-MM-dd); blank = invoice only',
                        'Name — patient name; matched against My Patients or creates new record',
                        'Amount — USD value; blank = schedule-only row, no invoice created',
                        'Service — session description; defaults to "Physical Therapy"',
                        'Status — pending · paid · partially_paid · cancelled (invoices only)',
                        'Note — optional note for the invoice entry',
                        'Row with Date only → appointment added to Schedule',
                        'Row with Amount only → invoice added to Revenue',
                        'Row with both → appointment + invoice both created',
                      ],
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1),
              // Row list
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final r        = rows[i];
                    final isNew    = r.patientId == null;
                    final isFirst  = isFirstNew[i]; // first occurrence of this name
                    final fmtDate  = r.date != null
                        ? DateFormat('MMM d, yyyy').format(r.date!)
                        : null;
                    final subtitle = [
                      if (fmtDate != null) fmtDate,
                      if (r.hasAmount)
                        'USD ${r.amount!.toStringAsFixed(2)}',
                      r.service,
                      if (r.hasAmount && r.statusKey != 'pending')
                        r.statusKey.replaceAll('_', ' '),
                    ].join(' · ');
                    return CheckboxListTile(
                      value: r.selected,
                      activeColor: AppColors.primary,
                      onChanged: (v) => set(() => r.selected = v ?? false),
                      title: Row(children: [
                        Expanded(
                          child: Text(r.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        if (r.hasDate)
                          _unifiedBadge(Icons.calendar_month_rounded,
                              AppColors.primary),
                        if (r.hasAmount)
                          _unifiedBadge(Icons.receipt_rounded,
                              const Color(0xFF0E8378)),
                        // First unmatched occurrence → will create the patient.
                        // Subsequent same-name rows → merged into that patient.
                        if (isNew && isFirst)
                          _unifiedBadge(Icons.person_add_rounded,
                              const Color(0xFFE65100))
                        else if (isNew)
                          _unifiedBadge(Icons.link_rounded,
                              Colors.grey.shade500),
                      ]),
                      subtitle: Text(subtitle,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600)),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Footer
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      'Import $selected Row${selected == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: selected == 0
                        ? null
                        : () {
                            Navigator.pop(ctx); // close preview sheet first
                            _doUnifiedImport(rows, s);
                          },
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _unifiedBadge(IconData icon, Color color) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 12, color: color),
      );

  Future<void> _doUnifiedImport(List<_UnifiedRow> rows, AppStrings s) async {
    if (!mounted) return;
    _showImportProgress();
    final messenger = ScaffoldMessenger.of(context); // capture before first await
    await Future.delayed(Duration.zero);
    final myUid     = Supabase.instance.client.auth.currentUser!.id;
    final now       = DateTime.now();
    int apptCount   = 0;
    int invCount    = 0;
    int patCount    = 0;
    bool success    = false;
    String? errMsg;

    final selected = rows.where((r) => r.selected).toList();
    final total    = selected.length;

    try {
      final resolvedIds = <String, String>{}; // normalised name → patient id
      final seenAppts   = <String>{};          // "patientId|yyyy-MM-dd" dedup
      final seenRevs    = <String>{};          // same key — one invoice per patient per day

      for (int i = 0; i < selected.length; i++) {
        final row = selected[i];
        _setProgress(i / total, 'Importing ${i + 1} of $total…');

        final nameKey    = row.name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
        String patientId = resolvedIds[nameKey] ?? row.patientId ?? '';

        if (!resolvedIds.containsKey(nameKey)) {
          if (patientId.isEmpty) {
            final existingList = await Supabase.instance.client
                .from('users').select('id, doctor_ids')
                .eq('role', 'patient').eq('name', row.name).limit(1);

            if (existingList.isNotEmpty) {
              patientId = existingList.first['id'] as String;
              final patIds = List<String>.from(
                  (existingList.first['doctor_ids'] as List?) ?? []);
              if (!patIds.contains(myUid)) {
                patIds.add(myUid);
                await Supabase.instance.client
                    .from('users').update({'doctor_ids': patIds}).eq('id', patientId);
              }
            } else {
              final newRow = await Supabase.instance.client.from('users').insert({
                'name':        row.name,
                'role':        'patient',
                'doctor_ids':  [myUid],
                'has_account': false,
                'created_at':  DateTime.now().toIso8601String(),
              }).select().single();
              patientId = newRow['id'] as String;
              patCount++;
            }

            final myData = await Supabase.instance.client
                .from('users').select('assigned_patient_ids').eq('id', myUid).single();
            final myIds = List<String>.from(
                (myData['assigned_patient_ids'] as List?) ?? []);
            if (!myIds.contains(patientId)) {
              myIds.add(patientId);
              await Supabase.instance.client
                  .from('users').update({'assigned_patient_ids': myIds}).eq('id', myUid);
            }
          }
          resolvedIds[nameKey] = patientId;
        } else {
          patientId = resolvedIds[nameKey]!;
        }

        // Schedule appointment — one per patient per calendar day.
        // Capture the inserted row's ID so the invoice can be linked to it,
        // preventing _syncPastAppointments from creating a second invoice.
        String? linkedApptId;
        if (row.hasDate) {
          final dayKey  = DateFormat('yyyy-MM-dd').format(row.date!);
          final apptKey = '$patientId|$dayKey';
          if (seenAppts.add(apptKey)) {
            final isPast  = row.date!.isBefore(now);
            final apptRow = await Supabase.instance.client
                .from('appointments')
                .insert({
                  'patient_id':       patientId,
                  'patient_name':     row.name,
                  'doctor_id':        myUid,
                  'appointment_time': row.date!.toIso8601String(),
                  'status':           isPast ? 'completed' : 'scheduled',
                  'notes':            row.service == 'Physical Therapy'
                                          ? ''
                                          : row.service,
                  'created_at':       DateTime.now().toIso8601String(),
                })
                .select('id')
                .single();
            linkedApptId = apptRow['id'] as String?;
            apptCount++;
          }
        }

        // Revenue invoice — one per patient per calendar day.
        // Stamping appointment_id prevents billing sync from creating a duplicate.
        if (row.hasAmount) {
          final invoiceDate = row.date ?? now;
          final revKey = '$patientId|${DateFormat('yyyy-MM-dd').format(invoiceDate)}';
          if (seenRevs.add(revKey)) {
            await Supabase.instance.client.from('invoices').insert({
              'doctor_id':      myUid,
              'patient_id':     patientId,
              'patient_name':   row.name,
              'service':        row.service,
              'amount':         row.amount,
              'currency':       'USD',
              'status':         row.statusKey,
              'note':           row.note,
              'invoice_date':   invoiceDate.toIso8601String(),
              'created_at':     DateTime.now().toIso8601String(),
              if (linkedApptId != null) 'appointment_id': linkedApptId,
            });
            invCount++;
          }
        }
      }

      _setProgress(1.0, 'Done');
      await Future.delayed(const Duration(milliseconds: 350));
      success = true;
    } catch (e) {
      errMsg = e.toString();
    } finally {
      _hideLoading();
    }

    if (!mounted) return;
    if (success) {
      final parts = <String>[
        if (patCount  > 0) '$patCount patient${patCount  == 1 ? '' : 's'}',
        if (apptCount > 0) '$apptCount appt${apptCount   == 1 ? '' : 's'}',
        if (invCount  > 0) '$invCount invoice${invCount   == 1 ? '' : 's'}',
      ];
      messenger.showSnackBar(SnackBar(
        content: Text('Imported: ${parts.join(' · ')}'),
        backgroundColor: AppColors.success,
      ));
      setState(() {});
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text('Import failed: $errMsg'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 8 – Doctor: Store Tab  (replaced with DoctorStorefrontScreen in Task 3)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStoreTab() => const DoctorStorefrontScreen();
}
