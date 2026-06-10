import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


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
import 'location_picker_screen.dart';
import '../../core/config/form_factor_features.dart';
import '../../core/widgets/available_on_desktop_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/subscription_model.dart';
import '../../core/providers/language_provider.dart';
import 'create_patient_screen.dart';
import 'soap_note_screen.dart';
import 'session_stats_screen.dart';
import 'billing_screen.dart';
import 'expenses_screen.dart';
import 'doctor_service.dart';
import 'import_help_sheet.dart';
import '../auth/auth_service.dart';

// ── Patient import entry ──────────────────────────────────────────────────

class _ScheduleImportEntry {
  final String name;
  final List<DateTime?> dates;
  String? patientId;   // null = not matched to an existing patient
  bool selected = true;
  _ScheduleImportEntry({required this.name, required this.dates});
}

class _PatientImportEntry {
  final String name;
  final List<DateTime?> dates; // one entry per Excel row with this name
  bool selected = true;        // checked in the preview list
  bool createAccount = false;
  _PatientImportEntry({required this.name, required this.dates});
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
  bool _homeVisit       = false;
  bool _profileLoaded   = false;
  bool _deletingAccount = false;
  bool _showDrPrefix    = false;
  // 'none' | 'pending' | 'approved' | 'declined'
  String _drPrefixStatus    = 'none';
  String _nameChangeRequest = 'none';
  String _pendingName       = '';
  String _userRole    = 'doctor';   // 'doctor' | 'polyclinic'
  double? _lat;
  double? _lng;

  // Navigation – order: Schedule | Documentation | My Patients | Chat |
  //                     Statistics | Billing | Expenses | My Profile
  int _currentIndex = 0;
  bool _showHome = true; // landing home screen

  // Subscription
  SubConfig _sub = SubConfig.defaultsFor(SubTier.basic);
  StreamSubscription<List<Map<String, dynamic>>>? _subListener;
  StreamSubscription<List<Map<String, dynamic>>>? _notifListener;

  static const List<IconData> _navIcons = [
    Icons.calendar_today_rounded,     // 0 Schedule
    Icons.description_rounded,        // 1 Documentation
    Icons.people_alt_rounded,         // 2 My Patients
    Icons.bar_chart_rounded,          // 3 Statistics
    Icons.receipt_long_rounded,       // 4 Billing
    Icons.receipt_rounded,            // 5 Expenses
    Icons.badge_rounded,              // 6 My Profile
    Icons.notifications_rounded,      // 7 Notifications
  ];

  int _doctorUnreadCount = 0;

  // When the user is a polyclinic, append a 9th "My Doctors" entry.
  List<IconData> get _allNavIcons => _userRole == 'polyclinic'
      ? [..._navIcons, Icons.manage_accounts_rounded]
      : _navIcons;

  List<Color> get _allTileColors => _userRole == 'polyclinic'
      ? [..._tileColors, const Color(0xFF00695C)]
      : _tileColors;

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
            _sub            = SubConfig.fromMap(d);
            _userRole       = (d['role']             as String?) ?? 'doctor';
            _showDrPrefix   = (d['show_dr_prefix']   as bool?)   ?? false;
            _drPrefixStatus = (d['dr_prefix_request'] as String?) ?? 'none';
          });
        }
      });
      _notifListener = Supabase.instance.client
          .from('notifications').stream(primaryKey: ['id'])
          .eq('recipient_id', uid)
          .listen((list) {
        if (mounted) {
          setState(() {
            _doctorUnreadCount = list.where(
                (n) => !(n['read'] as bool? ?? false)).length;
          });
        }
      });
    }
    final now = DateTime.now();
    _calMonth = DateTime(now.year, now.month);
    _calDay   = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _subListener?.cancel();
    _notifListener?.cancel();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _photoCtrl.dispose();
    _specCtrl.dispose();
    _clinicNameCtrl.dispose();
    _clinicAddrCtrl.dispose();
    _workingHoursCtrl.dispose();
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

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
      _showHome = false;
    });
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _goHome() => setState(() => _showHome = true);

  bool _isLocked(int index) => _sub.isLocked(index);

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

Future<void> _showLogout(AppStrings s) async {
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
      'Notifications',
      if (_userRole == 'polyclinic') 'My Doctors',
    ];

    return Directionality(
      textDirection: dir,
      child: Scaffold(
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
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildScheduleTab(s),                                              // 0
            _buildDocumentationTab(s),                                         // 1
            _buildPatientsTab(s),                                              // 2
            !FormFactorFeatures.of(context).showStatistics // 3
                ? _buildAvailableOnDesktopScreen('Statistics')
                : _isLocked(3)
                    ? _buildLockedScreen('Statistics', SubTier.premium)
                    : SessionStatsScreen(onAddAppointment: () => _navigateTo(0)),
            _isLocked(4) ? _buildLockedScreen('Income',     SubTier.premium) // 4
                         : const BillingScreen(),
            _isLocked(5) ? _buildLockedScreen('Expenses',   SubTier.premium) // 5
                         : const ExpensesScreen(),
            _buildProfileTab(s),                                               // 6
            _buildDoctorNotificationsTab(s),                                   // 7
            if (_userRole == 'polyclinic')
              _buildPolyclinicDoctorsTab(),                                    // 8
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Home Landing Screen
  // ════════════════════════════════════════════════════════════════════════════

  static const List<Color> _tileColors = [
    Color(0xFF1565C0), // Schedule       – blue
    Color(0xFF2E7D32), // Documentation  – green
    Color(0xFFE65100), // My Patients    – orange
    Color(0xFF00695C), // Statistics     – teal
    Color(0xFFF57F17), // Billing        – amber
    Color(0xFF00796B), // Expenses       – teal
    Color(0xFF37474F), // My Profile     – blue-grey
    Color(0xFF6A1B9A), // Notifications  – deep purple
  ];

  Widget _buildHomeScreen(AppStrings s, LanguageProvider lang) {
    final name     = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Doctor';
    final spec     = _specCtrl.text;
    final photo    = _photoCtrl.text;
    final clinic   = _clinicNameCtrl.text.isNotEmpty
        ? _clinicNameCtrl.text
        : 'PT Clinic';

    final sections = [
      s.schedule, s.documentation, s.myPatients,
      s.statistics, s.billing, s.expenses, s.myProfile,
      'Notifications',
    ];

    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A3A5C), Color(0xFF2C5F8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Doctor photo (right)
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(80)),
                    child: photo.isNotEmpty
                        ? Image.network(photo,
                            width: 140, fit: BoxFit.cover)
                        : Container(
                            width: 130,
                            alignment: Alignment.center,
                            color: Colors.white10,
                            child: const Icon(Icons.person_rounded,
                                size: 80, color: Colors.white30)),
                  ),
                ),
                // Language toggle (top-right corner offset from photo)
                Positioned(
                  top: 6, right: 148,
                  child: TextButton.icon(
                    onPressed: lang.toggle,
                    icon: const Icon(Icons.language_rounded,
                        color: Colors.white60, size: 15),
                    label: Text(s.language,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ),
                ),
                // Welcome text (left)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(22, 24, 160, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Welcome,',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(_userRole == 'polyclinic' ? '$name!' : '${_showDrPrefix ? "Dr. " : ""}$name!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      if (spec.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(spec,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ),
                      ],
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Tile grid ─────────────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 600 ? 4 : 2;
              final showStats = FormFactorFeatures.of(context).showStatistics;
              final visibleIndices = [
                for (var i = 0; i < sections.length; i++)
                  if (i != 3 || showStats) i,
              ];
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: cols == 4 ? 1.15 : 1.05,
                ),
                itemCount: visibleIndices.length,
                itemBuilder: (_, i) {
                  final idx = visibleIndices[i];
                  return _buildHomeTile(
                      sections[idx], _allNavIcons[idx], _allTileColors[idx], idx);
                },
              );
            },
          ),
        ),

        // ── Footer ────────────────────────────────────────────────────────
        FormFactorFeatures.of(context).isMobile
            ? _buildMobileHomeFooter(name, clinic)
            : Container(
                width: double.infinity,
                color: const Color(0xFF1A3A5C),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    const Icon(Icons.monitor_heart_rounded,
                        color: Color(0xFF4FC3F7), size: 20),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14),
                        children: [
                          TextSpan(
                            text: '${_showDrPrefix ? "Dr. " : ""}$name  ',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: clinic,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Logout button
                    TextButton.icon(
                      onPressed: () => _showLogout(AppStrings(false)),
                      icon: const Icon(Icons.logout_rounded,
                          color: Colors.white54, size: 16),
                      label: const Text('Logout',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ]),
                ),
              ),
      ],
    );
  }

  /// Mobile replacement for the desktop home footer. The desktop Row above
  /// lets the doctor's name + clinic text grow unbounded next to a Spacer
  /// and Logout button, which overflows at narrow widths; here the identity
  /// text is constrained to a single ellipsized line and Logout is an
  /// icon-only button so the row always fits.
  Widget _buildMobileHomeFooter(String name, String clinic) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A3A5C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(children: [
          const Icon(Icons.monitor_heart_rounded,
              color: Color(0xFF4FC3F7), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              text: TextSpan(
                style: const TextStyle(fontSize: 13),
                children: [
                  TextSpan(
                    text: '${_showDrPrefix ? "Dr. " : ""}$name  ',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: clinic,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showLogout(AppStrings(false)),
            icon: const Icon(Icons.logout_rounded,
                color: Colors.white54, size: 20),
            tooltip: 'Logout',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }

  Widget _buildHomeTile(
      String title, IconData icon, Color color, int index) {
    final locked = _isLocked(index);
    final tileColor = locked ? color.withValues(alpha: 0.45) : color;
    final badge = index == 7 ? _doctorUnreadCount : 0;

    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          _currentIndex = index;
          _showHome = false;
        }),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: locked
                ? []
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 46,
                        color: locked
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.white),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        title,
                        style: TextStyle(
                            color: locked
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              if (badge > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
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

  /// Shown instead of a desktop-only screen (e.g. Statistics) when the
  /// doctor is using a mobile-width viewport, such as via a deep link.
  Widget _buildAvailableOnDesktopScreen(String feature) {
    return AvailableOnDesktopNotice(feature: feature);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Navigation Drawer
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildNavDrawer(AppStrings s, List<String> sections) {
    final showStats = FormFactorFeatures.of(context).showStatistics;
    final visibleIndices = [
      for (var i = 0; i < sections.length; i++)
        if (i != 3 || showStats) i,
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

  // ════════════════════════════════════════════════════════════════════════════
  // 7 – Notifications Tab
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDoctorNotificationsTab(AppStrings s) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return const Center(child: Text('Not signed in'));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('recipient_id', uid)
          .map((list) => (list
            ..sort((a, b) => (b['created_at'] as String)
                .compareTo(a['created_at'] as String)))
              .toList()),
      builder: (ctx, snap) {
        final notifs = snap.data ?? [];
        final unreadCount =
            notifs.where((n) => !(n['read'] as bool? ?? false)).length;

        return Column(children: [
          // ── header ──────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(children: [
              if (unreadCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$unreadCount unread',
                      style: const TextStyle(
                          color: Color(0xFF6A1B9A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ] else
                const Text('All caught up',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              if (unreadCount > 0)
                TextButton(
                  onPressed: () async {
                    final ids = notifs
                        .where((n) => !(n['read'] as bool? ?? false))
                        .map((n) => n['id'] as String)
                        .toList();
                    for (final id in ids) {
                      await Supabase.instance.client
                          .from('notifications')
                          .update({'read': true}).eq('id', id);
                    }
                  },
                  child: const Text('Mark all read',
                      style: TextStyle(fontSize: 13)),
                ),
            ]),
          ),
          const Divider(height: 1),
          // ── content ─────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildPendingRequestsCard(s),
                if (notifs.isEmpty) ...[
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No notifications yet',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  ...notifs.map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _notifCard(n),
                      )),
                ],
              ],
            ),
          ),
        ]);
      },
    );
  }

  Widget _notifCard(Map<String, dynamic> n) {
    final type    = (n['type']  as String?) ?? '';
    final title   = (n['title'] as String?) ?? 'Notification';
    final body    = (n['body']  as String?) ?? '';
    final raw     = n['created_at'] as String?;
    final dt      = raw != null ? DateTime.tryParse(raw) : null;
    final timeStr = dt != null
        ? DateFormat('MMM d, h:mm a').format(dt.toLocal())
        : '';
    final unread  = !(n['read'] as bool? ?? false);

    final (IconData icon, Color iconColor) = switch (type) {
      'patient_added_you'           => (Icons.person_add_rounded,        const Color(0xFF1565C0)),
      'appointment_request'
      || 'appointment_reschedule'   => (Icons.event_rounded,             Colors.orange),
      'admin'                       => (Icons.admin_panel_settings_rounded, Colors.teal),
      _                             => (Icons.notifications_rounded,     const Color(0xFF6A1B9A)),
    };

    return Material(
      color: unread ? const Color(0xFFF3E5F5) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: unread ? 1 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: unread
            ? () => Supabase.instance.client
                .from('notifications')
                .update({'read': true})
                .eq('id', n['id'] as String)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14)),
                      ),
                      if (unread)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFF6A1B9A),
                              shape: BoxShape.circle),
                        ),
                    ]),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                    ],
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(timeStr,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                      Expanded(
                        child: _buildAppointmentsPanel(
                            allAppts, s, shrinkWrap: false),
                      ),
                    ],
                  ),
                ),
              );
            }
            // ── Mobile: stacked ──────────────────────────────────────
            return SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _buildPendingRequestsCard(s),
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

  // ── Pending appointment requests ──────────────────────────────────────────

  Widget _buildPendingRequestsCard(AppStrings s) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('appointment_requests')
          .stream(primaryKey: ['id'])
          .eq('doctor_id', uid)
          .map((list) => list
              .where((r) => (r['status'] as String? ?? '') == 'pending')
              .toList()
              ..sort((a, b) => (b['created_at'] as String)
                  .compareTo(a['created_at'] as String))),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pending_actions_rounded,
                        color: Colors.orange, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Appointment Requests (${requests.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                const SizedBox(height: 10),
                ...requests.map((req) {
                  final patName  = (req['patient_name'] as String?) ?? 'Patient';
                  final patId    = (req['patient_id']   as String?) ?? '';
                  final notes    = (req['notes']         as String?) ?? '';
                  final reqTime  = req['requested_time'] as String?;
                  final dt       = reqTime != null ? DateTime.parse(reqTime) : null;
                  final timeStr  = dt != null
                      ? DateFormat('EEE, MMM d – h:mm a').format(dt)
                      : '—';

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: Supabase.instance.client
                        .from('users').select('phone').eq('id', patId).maybeSingle(),
                    builder: (_, patSnap) {
                      final phone = (patSnap.data?['phone'] as String?) ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(patName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ),
                              if (phone.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _showPhoneOptions(context, phone),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.phone_rounded,
                                        size: 14, color: Color(0xFF25D366)),
                                    const SizedBox(width: 4),
                                    Text(phone,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF25D366),
                                            decoration: TextDecoration.underline)),
                                  ]),
                                ),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(timeStr,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ]),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(notes,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    await Supabase.instance.client
                                        .from('appointment_requests')
                                        .update({'status': 'declined'})
                                        .eq('id', req['id'] as String);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Decline', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (dt == null) return;
                                    final messenger = ScaffoldMessenger.of(context);
                                    final ok = await _service.bookAppointment(
                                        patId, patName, dt, notes);
                                    if (!mounted) return;
                                    if (ok) {
                                      await Supabase.instance.client
                                          .from('appointment_requests')
                                          .update({'status': 'accepted'})
                                          .eq('id', req['id'] as String);
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Appointment confirmed!'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Accept', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
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
        if (FormFactorFeatures.of(context).showScheduleImportExport) ...[
          const SizedBox(width: 6),
          // Import from Excel — compact
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 14),
              label: const Text('Import',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11)),
              onPressed: () => _importScheduleFromExcel(s),
            ),
          ),
          const SizedBox(width: 6),
          // Help
          GestureDetector(
            onTap: () => showImportHelpSheet(
              context,
              title: 'Import Schedule',
              subtitle: 'Each row = one appointment for the patient in col B',
              columns: ['Date (Col A)', 'Patient Name (Col B)'],
              examples: [
                ['01/15/2024', 'John Smith'],
                ['03/20/2024', 'John Smith'],
                ['02/10/2024', 'Sarah Lee'],
              ],
              notes: [
                'Column A: Appointment date — added to the schedule',
                'Column B: Patient name — must match a patient in My Patients',
                'Same patient on multiple rows = multiple appointments',
                'Past dates → Previous (completed), Future → Upcoming',
                'Accepted formats: dd/MM/yyyy · yyyy-MM-dd · d/M/yyyy',
                'First row can be a header (auto-detected)',
              ],
            ),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.help_outline_rounded,
                    color: Colors.amber, size: 16),
                SizedBox(width: 4),
                Text('Format',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ],
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
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: s.selectPatient,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    initialValue: selPatientId,
                    items: patients.map((p) {
                      final pid = p['id'] as String;
                      return DropdownMenuItem<String>(
                          value: pid,
                          child: Text(p['name'] ?? p['email'] ?? pid));
                    }).toList(),
                    onChanged: (v) {
                      final doc =
                          patients.firstWhere((p) => p['id'] == v);
                      final d = doc;
                      setLocal(() {
                        selPatientId   = v;
                        selPatientName = d['name'] ?? d['email'] ?? v;
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

          // Keep only SOAP / clinical documentation notes
          final soapNotes = (snap.data ?? []).where((doc) {
            final d = doc;
            return d['note_type'] == 'soap' ||
                d.containsKey('chiefComplaint') ||
                (d.containsKey('subjective') && d['subjective'] != null);
          }).toList();

          if (soapNotes.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.description_outlined,
                    size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text(s.noDocumentation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary, height: 1.5)),
              ]),
            );
          }

          String selectedPatient = '';
          String selectedCondition = '';
          String searchQuery = '';
          return StatefulBuilder(
            builder: (context, setState) {

              // Get unique patients and conditions
              final patientSet = <String>{};
              final conditionSet = <String>{};
              final allNotes = soapNotes.toList();

              for (final note in allNotes) {
                final d = note;
                final patName =
                    (d['patient_name'] as String?) ?? 'Unknown';
                final condition = (d['primary_diagnosis'] as String?) ??
                    (d['chiefComplaint'] as String?) ??
                    'General';
                patientSet.add(patName);
                conditionSet.add(condition);
              }

              final filteredNotes = allNotes.where((note) {
                final d = note;
                final patName =
                    (d['patient_name'] as String?) ?? '';
                final condition = (d['primary_diagnosis'] as String?) ??
                    (d['chiefComplaint'] as String?) ??
                    '';

                final matchesSearch = searchQuery.isEmpty ||
                    patName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    condition.toLowerCase().contains(searchQuery.toLowerCase());
                final matchesPatient = selectedPatient.isEmpty ||
                    patName == selectedPatient;
                final matchesCondition = selectedCondition.isEmpty ||
                    condition == selectedCondition;

                return matchesSearch &&
                    matchesPatient &&
                    matchesCondition;
              }).toList();

              // Sort by date
              filteredNotes.sort((a, b) {
                final ta = a['created_at'] != null ? DateTime.parse(a['created_at'] as String) : DateTime(2000);
                final tb = b['created_at'] != null ? DateTime.parse(b['created_at'] as String) : DateTime(2000);
                return tb.compareTo(ta);
              });

              // Get recent updates
              final recentUpdates = allNotes
                  .take(3)
                  .map((note) {
                    final d = note;
                    final patName =
                        (d['patient_name'] as String?) ?? 'Patient';
                    final patId =
                        (d['patient_id'] as String?) ?? '';
                    final ts = ((d['created_at'] as String?) != null ? DateTime.parse(d['created_at'] as String) : null);
                    return {
                      'name': patName,
                      'patientId': patId,
                      'noteId': note['id'] as String,
                      'noteData': d,
                      'date': ts,
                      'action': 'Note Updated',
                    };
                  })
                  .toList();

              return Column(
                children: [
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
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Note'),
                                onPressed: () =>
                                    _showPickPatientForDoc(s),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                onChanged: (v) =>
                                    setState(() => searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Search Records',
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Main content
                  Expanded(
                    child: Row(
                      children: [
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
                                onPressed: () =>
                                    _showPickPatientForDoc(s),
                              ),
                              const SizedBox(height: 20),
                              const Text('Recent Updates:',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: recentUpdates.length,
                                  itemBuilder: (_, i) {
                                    final update = recentUpdates[i];
                                    final patId = update['patientId'] as String;
                                    final patName = update['name'] as String;
                                    final noteId = update['noteId'] as String;
                                    final noteData = update['noteData'] as Map<String, dynamic>;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SoapNoteScreen(
                                              patientId: patId,
                                              patientName: patName,
                                              noteId: noteId,
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
                                                      '${update['action']} ${update['date'] != null ? DateFormat('dd/MM/yyyy').format(update['date'] as DateTime) : ''}',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors
                                                              .textSecondary)),
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
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<
                                            String>(
                                          initialValue: selectedPatient.isEmpty
                                              ? ''
                                              : selectedPatient,
                                          decoration: InputDecoration(
                                            labelText: 'Patient Name',
                                            border:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(8),
                                            ),
                                          ),
                                          items: [
                                            const DropdownMenuItem(
                                              value: '',
                                              child: Text('All Patients'),
                                            ),
                                            ...patientSet.map((p) =>
                                                DropdownMenuItem(
                                                  value: p,
                                                  child: Text(p),
                                                )),
                                          ],
                                          onChanged: (v) => setState(() =>
                                              selectedPatient = v ?? ''),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonFormField<
                                            String>(
                                          initialValue: selectedCondition.isEmpty
                                              ? ''
                                              : selectedCondition,
                                          decoration: InputDecoration(
                                            labelText: 'Condition',
                                            border:
                                                OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(8),
                                            ),
                                          ),
                                          items: [
                                            const DropdownMenuItem(
                                              value: '',
                                              child: Text('All Conditions'),
                                            ),
                                            ...conditionSet.map((c) =>
                                                DropdownMenuItem(
                                                  value: c,
                                                  child: Text(c),
                                                )),
                                          ],
                                          onChanged: (v) => setState(() =>
                                              selectedCondition = v ?? ''),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Documentation table
                                Expanded(
                                  child: filteredNotes.isEmpty
                                      ? Center(
                                          child: Text(
                                              'No documentation found',
                                              style: TextStyle(
                                                  color: Colors.grey
                                                      .shade600)),
                                        )
                                      : _buildDocumentationTable(
                                          filteredNotes, s),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
              if (FormFactorFeatures.of(context)
                  .showPatientsImportExport) ...[
                const SizedBox(height: 10),
                _addPatientTile(
                  ctx: ctx,
                  icon: Icons.upload_file_rounded,
                  color: const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                  title: 'Import from Excel',
                  subtitle: 'Col A: Date → Schedule  ·  Col B: Patient Name',
                  onTap: () {
                    Navigator.pop(ctx);
                    _importPatientsFromExcel();
                  },
                  onHelp: () => showImportHelpSheet(
                    ctx,
                    title: 'Import Patients & Schedule',
                    subtitle: 'Each row = one appointment assigned to the patient',
                    columns: ['Date (Col A)', 'Patient Name (Col B)'],
                    examples: [
                      ['01/15/2024', 'John Smith'],
                      ['03/20/2024', 'John Smith'],
                      ['02/10/2024', 'Sarah Johnson'],
                    ],
                    notes: [
                      'Column A — Appointment date: fills the doctor\'s schedule',
                      'Column B — Patient name: the appointment is assigned to this patient',
                      'Each row creates ONE appointment linked to the patient in col B',
                      'Same patient can appear on multiple rows (different dates)',
                      'Past dates → shown in Schedule "Previous" section (status: completed)',
                      'Future dates → shown in Schedule "Upcoming" section (status: scheduled)',
                      'Accepted date formats: dd/MM/yyyy · yyyy-MM-dd · d/M/yyyy',
                      'First row can be a header (auto-detected by keyword)',
                      'Toggle "Account" in the preview to create a patient login',
                    ],
                  ),
                ),
              ],
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
            final found = await _service.searchAllPatients(q);
            setLocal(() {
              results  = found;
              searching = false;
            });
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
                    hintText: 'Type at least 2 characters…',
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

  void _showPatientActions(
      AppStrings s, String patientId, String patientName, String photoUrl,
      {bool hasAccount = true, String phone = ''}) {
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
                            prefillName: patientName),
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

          String searchQuery = '';
          String sortBy     = 'name'; // 'name' | 'condition' | 'account' | 'date'
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
                          (d['hasAccount'] as bool? ?? true);
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

              return Column(
                children: [
                  // Header with search and add button
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (v) =>
                                    setState(() => searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Search by name, condition, contact…',
                                  prefixIcon: const Icon(Icons.search_rounded,
                                      color: AppColors.primary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 10),
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
                              icon: const Icon(Icons.add_rounded, size: 20),
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
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Icon(Icons.download_rounded,
                                      size: 20),
                                  onPressed: () =>
                                      _exportPatientsExcel(filteredPatients),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Patient table
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
                          : _buildPatientsTable(s, filteredPatients,
                              sortBy: sortBy,
                              onSortChanged: (v) =>
                                  setState(() => sortBy = v)),
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

  Widget _buildPatientsTable(
      AppStrings s, List<Map<String, dynamic>> patients, {
      required String sortBy,
      required ValueChanged<String> onSortChanged}) {
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
              final data      = patients[i];
              final patientId = patients[i]['id'] as String;
              final name      = (data['name'] ?? data['email'] ?? 'Patient') as String;
              final diagnosis = (data['primary_diagnosis'] ?? 'General') as String;
              final photoUrl  = (data['profile_photo_url'] ?? '') as String;
              final phone     = (data['phone'] ?? '') as String;
              // A patient has an account if they have an email and hasAccount != false
              final hasAccount = (data['email'] as String? ?? '').isNotEmpty &&
                  (data['hasAccount'] as bool? ?? true);

              return FutureBuilder<Map<String, DateTime?>>(
                future: _getPatientAppointmentDates(patientId),
                builder: (context, snapshot) {
                  final lastVisit = snapshot.data?['last'];
                  final nextVisit = snapshot.data?['next'];

                  return Container(
                    color: i.isEven ? Colors.white : const Color(0xFFF8FAFF),
                    child: GestureDetector(
                      onTap: () => _showPatientActions(
                          s, patientId, name, photoUrl,
                          hasAccount: hasAccount, phone: phone),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(children: [
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
                                          final n = phone.replaceAll(RegExp(r'[\s\-()]'), '');
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
          (d['hasAccount'] as bool? ?? true);
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
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
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
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side:
                              const BorderSide(color: Colors.white, width: 1),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.map_rounded),
                        label: Text(s.updateLocation),
                        onPressed: () async {
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.homeVisit,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                      Switch(
                        value: _homeVisit,
                        onChanged: (v) => setState(() => _homeVisit = v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.white30,
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
                    _profileItem(Icons.school_rounded, s.experience,
                        '12 ${s.yearsOfExperience}'),
                    _profileItem(Icons.verified_rounded, s.certifications,
                        'DPT, CMT'),
                    _profileItem(Icons.star_rounded, s.expertiseAreas,
                        'Pediatric Rehab, Sports Therapy'),
                    _profileItem(
                        Icons.language_rounded, s.languages, 'Arabic, English'),
                  ],
                ),
                const SizedBox(height: 20),
                // ── Name change request card ─────────────────────────────
                _buildNameChangeCard(),
                const SizedBox(height: 12),
                // ── Dr. prefix request card ──────────────────────────────
                _buildDrPrefixCard(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _deletingAccount
                      ? null
                      : () => _showDeleteAccountDialog(),
                  icon: _deletingAccount
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.red),
                        )
                      : const Icon(Icons.delete_forever_rounded,
                          color: Colors.red),
                  label: Text(
                    _deletingAccount ? 'Deleting...' : 'Delete Account',
                    style: const TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                      );
                      if (!mounted) return;
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

  // ── Import Schedule from Excel ────────────────────────────────────────────

  Future<void> _importScheduleFromExcel(AppStrings s) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    if (mounted) _showLoading('Reading Excel file…');
    await Future.delayed(Duration.zero); // yield so dialog renders before heavy sync work

    final excel = xl.Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null || sheet.rows.isEmpty) {
      _hideLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found in the file.')));
      return;
    }

    // Auto-detect columns (default: col A = date, col B = name)
    int dateCol = 0, nameCol = 1;
    bool hasHeader = false;
    final headerRow = sheet.rows.first;
    for (int i = 0; i < headerRow.length; i++) {
      final h = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
      if (h.contains('date') || h.contains('appt') ||
          h.contains('appointment')) {
        dateCol = i;
        hasHeader = true;
      }
      if (h.contains('name') || h.contains('patient')) {
        nameCol = i;
        hasHeader = true;
      }
    }

    // Group dates by patient name
    final grouped = <String, List<DateTime?>>{};
    final dataRows = hasHeader ? sheet.rows.skip(1) : sheet.rows;
    for (final row in dataRows) {
      if (row.isEmpty) continue;
      final name = nameCol < row.length
          ? (row[nameCol]?.value?.toString().trim() ?? '')
          : '';
      if (name.isEmpty) continue;
      final date = dateCol < row.length
          ? _tryParseDate(row[dateCol]?.value?.toString().trim() ?? '')
          : null;
      grouped.putIfAbsent(name, () => []).add(date);
    }

    if (grouped.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No entries found in the file.')));
      return;
    }

    // One-shot fetch of assigned patients (avoids stream empty-first-emission)
    final patientDocs = await _service.getAssignedPatientsOnce();

    // Normalise a name for comparison: lowercase, collapse internal spaces
    String norm(String s) =>
        s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

    final entries = grouped.entries.map((e) {
      final entry = _ScheduleImportEntry(name: e.key, dates: e.value);
      final q = norm(e.key);

      // 1) Exact match on 'name' field
      Map<String, dynamic>? match = patientDocs.cast<Map<String, dynamic>?>()
          .firstWhere(
        (p) => p != null && norm((p['name'] as String?) ?? '') == q,
        orElse: () => null,
      );

      // 2) Fallback: contains-match
      match ??= patientDocs.cast<Map<String, dynamic>?>().firstWhere(
        (p) {
          if (p == null) return false;
          final name = norm((p['name'] as String?) ?? '');
          return name.isNotEmpty && (name.contains(q) || q.contains(name));
        },
        orElse: () => null,
      );

      // 3) Try matching against email field
      match ??= patientDocs.cast<Map<String, dynamic>?>().firstWhere(
        (p) {
          if (p == null) return false;
          final em = norm((p['email'] as String?) ?? '');
          return em.isNotEmpty && em.contains(q);
        },
        orElse: () => null,
      );

      entry.patientId = match?['id'] as String?;
      return entry;
    }).toList();

    _hideLoading();
    if (!mounted) return;
    _showScheduleImportPreview(entries, s);
  }

  // ── Schedule import preview ────────────────────────────────────────────────

  void _showScheduleImportPreview(
      List<_ScheduleImportEntry> entries, AppStrings s) {
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (ctx, set) {
            final matched   = entries.where((e) => e.patientId != null).length;
            final unmatched = entries.length - matched;
            final selected  = entries.where((e) => e.selected).length;
            final allSelected = selected == entries.length;

            return Column(children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 14, 20, 10),
                child: Row(children: [
                  Checkbox(
                    tristate: true,
                    value: allSelected
                        ? true
                        : (selected == 0 ? false : null),
                    activeColor: AppColors.primary,
                    onChanged: (_) => set(() {
                      final target = !allSelected;
                      for (final e in entries) { e.selected = target; }
                    }),
                  ),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        'Schedule Import  ·  $selected / ${entries.length} selected',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                      Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 11, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Text('$matched matched',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2E7D32))),
                        if (unmatched > 0) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.warning_amber_rounded,
                              size: 11, color: Color(0xFFF57F17)),
                          const SizedBox(width: 4),
                          Text('$unmatched not in My Patients',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFF57F17))),
                        ],
                      ]),
                    ]),
                  ),
                ]),
              ),
              const Divider(height: 1),
              // ── Entry list ───────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final e       = entries[i];
                    final matched = e.patientId != null;
                    final validDates =
                        e.dates.whereType<DateTime>().toList();

                    return InkWell(
                      onTap: () => set(() => e.selected = !e.selected),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: e.selected,
                              activeColor: AppColors.primary,
                              onChanged: (v) =>
                                  set(() => e.selected = v ?? false),
                            ),
                            // Status icon
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: matched
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                matched
                                    ? Icons.person_rounded
                                    : Icons.person_off_rounded,
                                size: 18,
                                color: matched
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFF57F17),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(e.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: e.selected
                                                  ? AppColors.textPrimary
                                                  : Colors.grey)),
                                    ),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: matched
                                            ? const Color(0xFFE8F5E9)
                                            : const Color(0xFFFFF3E0),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        matched
                                            ? 'In My Patients'
                                            : 'Not found',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: matched
                                                ? const Color(0xFF2E7D32)
                                                : const Color(
                                                    0xFFF57F17)),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  if (validDates.isEmpty)
                                    const Text('No date',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors
                                                .textSecondary))
                                  else
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: validDates.map((d) {
                                        final isPast = d.isBefore(now);
                                        return Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isPast
                                                ? Colors.grey.shade100
                                                : const Color(
                                                    0xFFE3F2FD),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    6),
                                          ),
                                          child: Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPast
                                                    ? Icons
                                                        .history_rounded
                                                    : Icons
                                                        .event_rounded,
                                                size: 10,
                                                color: isPast
                                                    ? Colors.grey
                                                    : const Color(
                                                        0xFF1565C0),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                DateFormat('MMM d, yyyy')
                                                    .format(d),
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: isPast
                                                        ? Colors.grey
                                                            .shade700
                                                        : const Color(
                                                            0xFF1565C0),
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // ── Bottom action ─────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (unmatched > 0 &&
                      entries
                          .where(
                              (e) => e.selected && e.patientId == null)
                          .isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: Color(0xFFF57F17)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Unmatched patients will be imported as stubs and added to My Patients.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFF57F17)),
                          ),
                        ),
                      ]),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            selected == 0 ? Colors.grey : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.event_available_rounded),
                      label: Text(
                        'Import $selected Appointment(s)',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: selected == 0
                          ? null
                          : () => _doScheduleImport(entries, s, ctx),
                    ),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  // ── Execute schedule import ────────────────────────────────────────────────

  Future<void> _doScheduleImport(
      List<_ScheduleImportEntry> entries,
      AppStrings s,
      BuildContext sheetCtx) async {
    final messenger = ScaffoldMessenger.of(context);
    final myUid     = Supabase.instance.client.auth.currentUser!.id;
    final now       = DateTime.now();
    int apptCount   = 0;

    for (final entry in entries) {
      if (!entry.selected) continue;

      String patientId = entry.patientId ?? '';

      // If unmatched, create a stub patient and link them
      if (patientId.isEmpty) {
        final newRow = await Supabase.instance.client.from('users').insert({
          'name':       entry.name,
          'role':       'patient',
          'doctor_ids': [myUid],
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();
        patientId = newRow['id'] as String;
        final myData = await Supabase.instance.client.from('users').select('assigned_patient_ids').eq('id', myUid).single();
        final myIds = List<String>.from((myData['assigned_patient_ids'] as List?) ?? [])..add(patientId);
        await Supabase.instance.client.from('users').update({'assigned_patient_ids': myIds}).eq('id', myUid);
        await _service.notifyPatientAdded(
            patientId, await _service.getMyName());
      }

      // Create one appointment per calendar day (deduplicate same-day entries)
      final seenDays = <String>{};
      for (final date in entry.dates) {
        if (date == null) continue;
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        if (!seenDays.add(dayKey)) continue;
        final isPast = date.isBefore(now);
        await Supabase.instance.client.from('appointments').insert({
          'patient_id':       patientId,
          'patient_name':     entry.name,
          'doctor_id':        myUid,
          'appointment_time': date.toIso8601String(),
          'status':           isPast ? 'completed' : 'scheduled',
          'notes':            '',
          'created_at':       DateTime.now().toIso8601String(),
        });
        apptCount++;
      }
    }

    if (!sheetCtx.mounted) return;
    Navigator.pop(sheetCtx);

    messenger.showSnackBar(SnackBar(
      content: Text(
          '$apptCount appointment(s) added to your schedule.'),
      backgroundColor: AppColors.success,
    ));
    if (mounted) setState(() {});
  }

  // ── Import patients from Excel ─────────────────────────────────────────

  Future<void> _importPatientsFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    if (mounted) _showLoading('Reading Excel file…');
    await Future.delayed(Duration.zero); // yield so dialog renders before heavy sync work

    final excel = xl.Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null || sheet.rows.isEmpty) {
      _hideLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data found in the file.')));
      return;
    }

    // ── Auto-detect columns from header row ──────────────────────────────
    int dateCol = 0, nameCol = 1; // col A = date, col B = name
    bool hasHeader = false;
    final headerRow = sheet.rows.first;
    for (int i = 0; i < headerRow.length; i++) {
      final h = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
      if (h.contains('name') || h.contains('patient')) {
        nameCol = i; hasHeader = true;
      }
      if (h.contains('date') || h.contains('appt') ||
          h.contains('appointment')) {
        dateCol = i; hasHeader = true;
      }
    }

    // ── Parse & group rows by patient name ───────────────────────────────
    final grouped = <String, List<DateTime?>>{};
    final dataRows = hasHeader ? sheet.rows.skip(1) : sheet.rows;

    for (final row in dataRows) {
      if (row.isEmpty) continue;
      final name = nameCol < row.length
          ? (row[nameCol]?.value?.toString().trim() ?? '')
          : '';
      if (name.isEmpty) continue;
      DateTime? date;
      if (dateCol < row.length) {
        date = _tryParseDate(row[dateCol]?.value?.toString().trim() ?? '');
      }
      grouped.putIfAbsent(name, () => []).add(date);
    }

    if (grouped.isEmpty) {
      _hideLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patients found in the file.')));
      return;
    }

    final entries = grouped.entries
        .map((e) => _PatientImportEntry(name: e.key, dates: e.value))
        .toList();

    _hideLoading();
    if (!mounted) return;
    _showImportPreviewSheet(entries);
  }

  // ── Import preview sheet ───────────────────────────────────────────────

  void _showImportPreviewSheet(List<_PatientImportEntry> entries) {
    final now = DateTime.now();
    bool importing = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (ctx, set) {
            final selectedCount = entries.where((e) => e.selected).length;
            final allSelected   = selectedCount == entries.length;
            final noneSelected  = selectedCount == 0;
            final needAccount   = entries.where((e) => e.createAccount && e.selected).length;

            return Column(
              children: [
                // ── Header + Select All ───────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 14, 20, 10),
                  child: Row(children: [
                    // Select-all tristate checkbox
                    Checkbox(
                      tristate: true,
                      value: allSelected ? true : (noneSelected ? false : null),
                      activeColor: AppColors.primary,
                      onChanged: (_) => set(() {
                        final target = !allSelected;
                        for (final e in entries) { e.selected = target; }
                      }),
                    ),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                          'Import Preview  ·  $selectedCount / ${entries.length} selected',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                        const Text(
                          'Toggle "Account" to create a login for the patient',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      ]),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                // ── Patient list ─────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final e       = entries[i];
                      final validDates = e.dates.whereType<DateTime>().toList();

                      return InkWell(
                        onTap: () => set(() => e.selected = !e.selected),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Checkbox
                              Checkbox(
                                value: e.selected,
                                activeColor: AppColors.primary,
                                onChanged: (v) =>
                                    set(() => e.selected = v ?? false),
                              ),
                              // Avatar
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: e.selected
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.grey.shade200,
                                child: Text(
                                  e.name.isNotEmpty
                                      ? e.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: e.selected
                                          ? AppColors.primary
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Name + dates
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(e.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: e.selected
                                                ? AppColors.textPrimary
                                                : Colors.grey)),
                                    const SizedBox(height: 4),
                                    if (validDates.isEmpty)
                                      const Text('No appointment date',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary))
                                    else
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: validDates.map((d) {
                                          final isPast = d.isBefore(now);
                                          return Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isPast
                                                  ? Colors.grey.shade100
                                                  : const Color(0xFFE3F2FD),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isPast
                                                      ? Icons.history_rounded
                                                      : Icons.event_rounded,
                                                  size: 10,
                                                  color: isPast
                                                      ? Colors.grey
                                                      : const Color(0xFF1565C0),
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  DateFormat('MMM d, yyyy')
                                                      .format(d),
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: isPast
                                                          ? Colors.grey.shade700
                                                          : const Color(
                                                              0xFF1565C0),
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                ),
                              ),
                              // Account toggle
                              SizedBox(
                                width: 72,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Account',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: e.createAccount
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.w600)),
                                    Transform.scale(
                                      scale: 0.75,
                                      child: Switch(
                                        value: e.createAccount,
                                        onChanged: (v) =>
                                            set(() => e.createAccount = v),
                                        activeThumbColor: AppColors.primary,
                                        activeTrackColor: AppColors.primary
                                            .withValues(alpha: 0.4),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // ── Bottom action ─────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (needAccount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                                '$needAccount patient(s) will need '
                                'account credentials after import.',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary)),
                          ]),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (selectedCount == 0 || importing)
                                ? Colors.grey
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: (selectedCount == 0 || importing)
                              ? null
                              : () async {
                                  set(() => importing = true);
                                  await _doPatientImport(entries, ctx);
                                },
                          child: importing
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Importing…',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.upload_rounded),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Import $selectedCount Patient(s)',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
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

  // ── Execute import ─────────────────────────────────────────────────────

  Future<void> _doPatientImport(
      List<_PatientImportEntry> entries, BuildContext sheetCtx) async {
    final messenger   = ScaffoldMessenger.of(context);
    final myUid       = Supabase.instance.client.auth.currentUser!.id;
    final now         = DateTime.now();
    final needAccount = <String, String>{};  // name → patientId
    int patientsCount = 0, apptCount = 0;

    try {
      final doctorName = await _service.getMyName();

      for (final entry in entries) {
        if (!entry.selected) continue;

        String patientId;
        final existingList = await Supabase.instance.client
            .from('users').select('id, doctor_ids')
            .eq('role', 'patient').eq('name', entry.name).limit(1);

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
            'name':       entry.name,
            'role':       'patient',
            'doctor_ids': [myUid],
            'created_at': DateTime.now().toIso8601String(),
          }).select('id').single();
          patientId = newRow['id'] as String;
        }

        // Keep doctor's assigned_patient_ids in sync
        final myData = await Supabase.instance.client
            .from('users').select('assigned_patient_ids').eq('id', myUid).maybeSingle();
        final myIds = List<String>.from(
            (myData?['assigned_patient_ids'] as List?) ?? []);
        if (!myIds.contains(patientId)) {
          myIds.add(patientId);
          await Supabase.instance.client
              .from('users').update({'assigned_patient_ids': myIds}).eq('id', myUid);
        }

        await _service.notifyPatientAdded(patientId, doctorName);

        for (final date in entry.dates) {
          if (date == null) continue;
          await Supabase.instance.client.from('appointments').insert({
            'patient_id':       patientId,
            'patient_name':     entry.name,
            'doctor_id':        myUid,
            'appointment_time': date.toIso8601String(),
            'status':           date.isBefore(now) ? 'completed' : 'scheduled',
            'notes':            '',
            'created_at':       DateTime.now().toIso8601String(),
          });
          apptCount++;
        }

        if (entry.createAccount) needAccount[entry.name] = patientId;
        patientsCount++;
      }

      if (!sheetCtx.mounted) return;
      Navigator.pop(sheetCtx);

      messenger.showSnackBar(SnackBar(
        content: Text('$patientsCount patient(s) · $apptCount appointment(s) imported.'),
        backgroundColor: AppColors.success,
      ));

      if (mounted) setState(() {});

      if (needAccount.isNotEmpty && mounted) {
        _showPendingAccountsSheet(needAccount);
      }
    } catch (e) {
      if (!sheetCtx.mounted) return;
      Navigator.pop(sheetCtx);
      messenger.showSnackBar(SnackBar(
        content: Text('Import failed: $e'),
        backgroundColor: AppColors.error,
      ));
      if (mounted) setState(() {});
    }
  }

  // ── Pending accounts sheet ─────────────────────────────────────────────

  // nameToId: patient display name → existing stub patient UUID
  void _showPendingAccountsSheet(Map<String, String> nameToId) {
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
              Row(children: [
                const Icon(Icons.manage_accounts_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 10),
                Text('Set Up ${nameToId.length} Account(s)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              const Text(
                  'Create login credentials for the following patients.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary)),
              const Divider(height: 20),
              ...nameToId.entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(e.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreatePatientScreen(
                              prefillName: e.key,
                              existingPatientId: e.value,
                            ),
                          ),
                        );
                      },
                      child: const Text('Create Account'),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 8 – Polyclinic: My Doctors Tab
  // ════════════════════════════════════════════════════════════════════════════

  static const _kPolyTeal = Color(0xFF00695C);

  Widget _buildPolyclinicDoctorsTab() {
    final myUid = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('users').stream(primaryKey: ['id']).eq('polyclinic_id', myUid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final doctors = snap.data ?? [];

          return Column(children: [
            // ── Action bar ────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPolyTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 20),
                  label: const Text('Add Doctor',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () =>
                      _showCreateDoctorProfileSheet(myUid),
                ),
              ),
            ),
            const Divider(height: 1),
            // ── Doctors list ──────────────────────────────────────────────
            Expanded(
              child: doctors.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.people_outline_rounded,
                            size: 64,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No doctors yet',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text(
                            'Tap "Add Doctor" to create an internal doctor profile.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: doctors.length,
                      itemBuilder: (_, i) =>
                          _polyclinicDoctorCard(doctors[i], myUid),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  // ── Doctor card inside polyclinic tab ──────────────────────────────────────

  Widget _polyclinicDoctorCard(
      Map<String, dynamic> doc, String polyclinicUid) {
    final d          = doc;
    final name       = (d['name'] ?? d['email'] ?? 'Doctor') as String;
    final spec       = (d['specialization'] ?? '') as String;
    final phone      = (d['phone'] ?? '') as String;
    final hasAuth    = (d['hasAuthAccount'] as bool?) ?? true;
    final color      = _tileColors[1]; // green
    final patCnt     = ((d['assigned_patient_ids'] as List?) ?? []).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13)),
            child: Center(
              child: Text(
                name.trim().split(' ').take(2)
                    .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                    .join(),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              if (spec.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(spec,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => _showPhoneOptions(context, phone),
                  child: Text(phone,
                      style: const TextStyle(
                          color: Color(0xFF25D366),
                          fontSize: 12,
                          decoration: TextDecoration.underline)),
                ),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: hasAuth
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      hasAuth ? 'Has Login' : 'Profile Only',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hasAuth
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFF57F17))),
                ),
                const SizedBox(width: 8),
                Text('$patCnt patient${patCnt != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ]),
            ]),
          ),
          // Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: Colors.grey.shade400, size: 18),
            onSelected: (v) async {
              if (v == 'patients') {
                _showAssignPatientsSheet(doc);
              } else if (v == 'edit') {
                _showEditDoctorProfileSheet(doc);
              } else if (v == 'unlink') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Remove Doctor'),
                    content: Text('Remove "$name" from your polyclinic?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                final docId = doc['id'] as String;
                final polyData = await Supabase.instance.client.from('users').select('linked_doctor_ids').eq('id', polyclinicUid).single();
                final linkedIds = List<String>.from((polyData['linked_doctor_ids'] as List?) ?? [])..remove(docId);
                await Supabase.instance.client.from('users').update({'linked_doctor_ids': linkedIds}).eq('id', polyclinicUid);
                await Supabase.instance.client.from('users').update({'polyclinic_id': null}).eq('id', docId);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'patients',
                child: Row(children: [
                  Icon(Icons.people_rounded, size: 18, color: _kPolyTeal),
                  SizedBox(width: 8),
                  Text('Assign Patients'),
                ]),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_rounded, size: 18,
                      color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('Edit Profile'),
                ]),
              ),
              const PopupMenuItem(
                value: 'unlink',
                child: Row(children: [
                  Icon(Icons.link_off_rounded, size: 18,
                      color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Remove from Polyclinic',
                      style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Create doctor profile sheet (no auth account) ──────────────────────────

  void _showCreateDoctorProfileSheet(
      String polyclinicUid) {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final phCtrl   = TextEditingController();
    bool saving    = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: _kPolyTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.person_add_rounded,
                      color: _kPolyTeal, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Doctor Profile',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('No login account — profile only',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ]),
              const SizedBox(height: 20),
              _polyField(nameCtrl, 'Full Name', Icons.badge_rounded),
              const SizedBox(height: 10),
              _polyField(specCtrl, 'Specialization',
                  Icons.medical_services_rounded),
              const SizedBox(height: 10),
              _polyField(phCtrl, 'Phone Number', Icons.phone_rounded,
                  type: TextInputType.phone),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPolyTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Create Doctor',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          set(() => saving = true);
                          try {
                            final newDoc = await Supabase.instance.client.from('users').insert({
                              'role':            'doctor',
                              'name':            name,
                              'specialization':  specCtrl.text.trim(),
                              'phone':           phCtrl.text.trim(),
                              'polyclinic_id':    polyclinicUid,
                              'has_auth_account':  false,
                              'subscription':    'basic',
                              'is_enabled':       true,
                              'show_in_search':    false,
                              'bio':             '',
                              'profile_photo_url': '',
                              'assigned_patient_ids': <String>[],
                              'created_at': DateTime.now().toIso8601String(),
                            }).select().single();
                            final newDoctorId = newDoc['id'] as String;
                            final polyData = await Supabase.instance.client.from('users').select('linked_doctor_ids').eq('id', polyclinicUid).single();
                            final linkedIds = List<String>.from((polyData['linked_doctor_ids'] as List?) ?? [])..add(newDoctorId);
                            await Supabase.instance.client.from('users').update({'linked_doctor_ids': linkedIds}).eq('id', polyclinicUid);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Doctor profile "$name" created'),
                                  backgroundColor: AppColors.success),
                            );
                          } catch (e) {
                            set(() => saving = false);
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit doctor profile sheet ──────────────────────────────────────────────

  void _showEditDoctorProfileSheet(
      Map<String, dynamic> doc) {
    final d        = doc;
    final nameCtrl = TextEditingController(
        text: (d['name'] ?? '') as String);
    final specCtrl = TextEditingController(
        text: (d['specialization'] ?? '') as String);
    final phCtrl   = TextEditingController(
        text: (d['phone'] ?? '') as String);
    bool saving    = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Edit Doctor Profile',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              _polyField(nameCtrl, 'Full Name', Icons.badge_rounded),
              const SizedBox(height: 10),
              _polyField(specCtrl, 'Specialization',
                  Icons.medical_services_rounded),
              const SizedBox(height: 10),
              _polyField(phCtrl, 'Phone Number', Icons.phone_rounded,
                  type: TextInputType.phone),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPolyTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Changes',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          set(() => saving = true);
                          await Supabase.instance.client.from('users').update({
                            'name':           nameCtrl.text.trim(),
                            'specialization': specCtrl.text.trim(),
                            'phone':          phCtrl.text.trim(),
                          }).eq('id', doc['id'] as String);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Assign patients to a polyclinic-internal doctor ───────────────────────

  void _showAssignPatientsSheet(
      Map<String, dynamic> doc) {
    final d       = doc;
    final docName = (d['name'] ?? 'Doctor') as String;
    List<String> assignedIds = List<String>.from(
        (d['assigned_patient_ids'] as List?) ?? []);
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(top: 14, bottom: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: _kPolyTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.people_rounded,
                        color: _kPolyTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assign Patients',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('to $docName',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _kPolyTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${assignedIds.length} assigned',
                        style: const TextStyle(
                            color: _kPolyTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => set(() => query = v.toLowerCase()),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search patients...',
                    hintStyle: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 20, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: _kPolyTeal, width: 1.5)),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Supabase.instance.client.from('users').stream(primaryKey: ['id']).eq('role', 'patient'),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    var patients = snap.data!;
                    if (query.isNotEmpty) {
                      patients = patients.where((p) {
                        final pd = p;
                        final n = ((pd['name'] ?? '') as String)
                            .toLowerCase();
                        final ph = ((pd['phone'] ?? '') as String)
                            .toLowerCase();
                        return n.contains(query) || ph.contains(query);
                      }).toList();
                    }
                    if (patients.isEmpty) {
                      return Center(
                        child: Text(
                          query.isEmpty
                              ? 'No patients in the system'
                              : 'No results for "$query"',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: patients.length,
                      itemBuilder: (_, i) {
                        final p  = patients[i];
                        final pd = p;
                        final name  = (pd['name']  ?? 'Patient') as String;
                        final phone = (pd['phone'] ?? '') as String;
                        final isAssigned = assignedIds.contains(p['id'] as String);

                        return InkWell(
                          onTap: () async {
                            final newIds = List<String>.from(assignedIds);
                            if (isAssigned) {
                              newIds.remove(p['id'] as String);
                            } else {
                              newIds.add(p['id'] as String);
                            }
                            set(() => assignedIds = newIds);
                            await Supabase.instance.client.from('users').update({
                              'assigned_patient_ids': newIds,
                            }).eq('id', doc['id'] as String);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    _kPolyTeal.withValues(alpha: 0.1),
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: _kPolyTeal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  if (phone.isNotEmpty)
                                    Text(phone,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                ]),
                              ),
                              Checkbox(
                                value: isAssigned,
                                activeColor: _kPolyTeal,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(4)),
                                onChanged: (_) async {
                                  final newIds =
                                      List<String>.from(assignedIds);
                                  if (isAssigned) {
                                    newIds.remove(p['id'] as String);
                                  } else {
                                    newIds.add(p['id'] as String);
                                  }
                                  set(() => assignedIds = newIds);
                                  await Supabase.instance.client.from('users').update({'assigned_patient_ids': newIds}).eq('id', doc['id'] as String);
                                },
                              ),
                            ]),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Shared field helper for polyclinic sheets ──────────────────────────────

  Widget _polyField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _kPolyTeal, size: 20),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: _kPolyTeal, width: 2),
          ),
          filled: true, fillColor: Colors.white,
        ),
      );
}

