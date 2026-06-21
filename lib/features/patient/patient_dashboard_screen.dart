import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import 'find_doctors_screen.dart';
import 'patient_service.dart';
import '../auth/auth_service.dart';
import '../hep/screens/patient_hep_screen.dart';
import '../../core/widgets/lebanon_phone_field.dart';

const _kNavy = Color(0xFF1A237E);
const _kBlue = Color(0xFF1565C0);
const _kGreen = Color(0xFF2E7D32);

/// Overridable in tests so the time-of-day greeting doesn't make golden
/// renders depend on the wall-clock time the test happens to run at.
@visibleForTesting
DateTime Function() patientDashboardClock = DateTime.now;

// ════════════════════════════════════════════════════════════════════════════
// Home
// ════════════════════════════════════════════════════════════════════════════

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  final _service = PatientService();
  final _uid = Supabase.instance.client.auth.currentUser!.id;

  Map<String, dynamic>? _profile;
  int _unreadCount = 0;
  Map<String, dynamic>? _nextAppt;
  StreamSubscription? _profileSub;
  StreamSubscription? _notifSub;
  StreamSubscription? _apptSub;

  @override
  void initState() {
    super.initState();
    _profileSub = Supabase.instance.client
        .from('users').stream(primaryKey: ['id']).eq('id', _uid)
        .listen((list) {
      if (list.isNotEmpty && mounted) setState(() => _profile = list.first);
    });
    _notifSub = Supabase.instance.client
        .from('notifications').stream(primaryKey: ['id']).eq('patient_id', _uid)
        .listen((list) {
      if (mounted) setState(() => _unreadCount = list.where((n) => n['read'] == false).length);
    });
    _apptSub = Supabase.instance.client
        .from('appointments').stream(primaryKey: ['id']).eq('patient_id', _uid)
        .listen((list) {
      if (!mounted) return;
      final upcoming = list.where((d) {
        final t = DateTime.parse(d['appointment_time'] as String);
        final status = d['status'] as String? ?? '';
        return t.isAfter(DateTime.now()) && status != 'cancelled';
      }).toList()
        ..sort((a, b) {
          final at = DateTime.parse(a['appointment_time'] as String);
          final bt = DateTime.parse(b['appointment_time'] as String);
          return at.compareTo(bt);
        });
      setState(() => _nextAppt = upcoming.isEmpty ? null : upcoming.first);
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _notifSub?.cancel();
    _apptSub?.cancel();
    super.dispose();
  }

  void _showLogout(AppStrings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.logout),
        content: Text(s.areYouSure),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
            },
            child: Text(s.signOut, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  String _displayName() {
    final n = _profile?['name'] as String?;
    if (n != null && n.isNotEmpty) return n.split(' ').first;
    return Supabase.instance.client.auth.currentUser?.email?.split('@').first ?? 'there';
  }

  String _greeting(AppStrings s) {
    final h = patientDashboardClock().hour;
    if (h < 12) return s.goodMorning;
    if (h < 17) return s.goodAfternoon;
    return s.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final s = AppStrings(lang.isArabic);

    return Directionality(
      textDirection: lang.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(s, lang),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  children: [
                    _nextAppt != null
                        ? _buildUpcomingApptCard()
                        : _buildNoApptBanner(s),
                    const SizedBox(height: 20),
                    _buildGrid(s),
                    const SizedBox(height: 14),
                    _buildMyExercisesTile(),
                    const SizedBox(height: 14),
                    _buildProfileTile(s),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppStrings s, LanguageProvider lang) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE3F0FF), Color(0xFFB3D4F7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.welcome}, ${_displayName()}!',
                      style: const TextStyle(
                        color: Color(0xFF0D1B4B),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _greeting(s),
                      style: const TextStyle(
                        color: Color(0xFF3A5BA0),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: lang.toggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.language_rounded,
                              color: Color(0xFF0D47A1), size: 14),
                          const SizedBox(width: 4),
                          Text(s.language,
                              style: const TextStyle(
                                  color: Color(0xFF0D47A1), fontSize: 11)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  size: 44,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoApptBanner(AppStrings s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.event_available_rounded,
              color: Color(0xFF1565C0), size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(s.noUpcomingAppointments,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(s.bookSessionToday,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildUpcomingApptCard() {
    final data = _nextAppt!;
    final dt = DateTime.parse(data['appointment_time'] as String);
    final doctorId = data['doctor_id'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings(context.read<LanguageProvider>().isArabic).upcomingAppointment,
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<Map<String, dynamic>?>(
            future: doctorId.isNotEmpty
                ? PatientService().getDoctorById(doctorId)
                : Future.value(null),
            builder: (_, snap) {
              final doc = snap.data;
              final dName         = doc?['name'] as String? ?? '';
              final dSpec         = doc?['specialization'] as String? ?? 'Doctor';
              final dPhoto        = doc?['profile_photo_url'] as String? ?? '';
              final dClinic       = doc?['clinicName'] as String? ?? '';
              final dShowDr       = (doc?['show_dr_prefix'] as bool?) ?? false;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          const Color(0xFF1565C0).withValues(alpha: 0.1),
                      backgroundImage: dPhoto.isNotEmpty
                          ? NetworkImage(dPhoto)
                          : null,
                      child: dPhoto.isEmpty
                          ? const Icon(Icons.person_rounded,
                              color: Color(0xFF1565C0), size: 26)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        dShowDr && dName.isNotEmpty ? 'Dr. $dName' : dName.isNotEmpty ? dName : 'Your Doctor',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(dSpec,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ]),
                  ]),
                  const Divider(height: 22),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('MMM d, yyyy').format(dt)} at ${DateFormat('h:mm a').format(dt)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF444444)),
                    ),
                  ]),
                  if (dClinic.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(dClinic,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF444444))),
                    ]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => _go(const _PatientScheduleScreen()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(AppStrings(context.read<LanguageProvider>().isArabic).viewDetails,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  static const _kGrid = [
    _GridDef(Icons.calendar_month_rounded, 'My Appointments', Color(0xFF1565C0), 0),
    _GridDef(Icons.people_alt_rounded,     'My Doctors/Therapists',         Color(0xFF00695C), 1),
    _GridDef(Icons.person_search_rounded,  'Find a Doctor or Therapist',    Color(0xFF6A1B9A), 2),
    _GridDef(Icons.notifications_rounded,  'Notifications',   Color(0xFFE65100), 3),
  ];

  Widget _buildGrid(AppStrings s) {
    final gridLabels = [
      s.myAppointments,
      s.myDoctors,
      s.findDoctorOrTherapist,
      s.notifications,
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.12,
      children: _kGrid.map((item) {
        final badge = item.index == 3 ? _unreadCount : 0;
        return _GridTile(
          item: item,
          label: gridLabels[item.index],
          badge: badge,
          onTap: () => _onTap(item.index, s),
        );
      }).toList(),
    );
  }

  void _onTap(int index, AppStrings s) {
    switch (index) {
      case 0: _go(const _PatientScheduleScreen());
      case 1: _go(_PatientMyDoctorsScreen(service: _service));
      case 2: _go(const FindDoctorsScreen());
      case 3: _go(_PatientNotificationsScreen(service: _service));
    }
  }

  Widget _buildMyExercisesTile() {
    const color = Color(0xFF00897B);
    return GestureDetector(
      onTap: () => _go(const PatientHepScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: color, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My Exercises',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A1A1A))),
                SizedBox(height: 2),
                Text('View your home exercise programs',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildProfileTile(AppStrings s) {
    final photo = _profile?['profile_photo_url'] as String? ?? '';
    return GestureDetector(
      onTap: () => _go(_PatientProfileScreen(profile: _profile)),
      onLongPress: () => _showLogout(s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor:
                const Color(0xFF1565C0).withValues(alpha: 0.1),
            backgroundImage:
                photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? const Icon(Icons.person_rounded,
                    color: Color(0xFF1565C0), size: 24)
                : null,
          ),
          const SizedBox(width: 14),
          const Text(
            'My Profile',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1A1A1A)),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ]),
      ),
    );
  }

}

// ── Grid helpers ──────────────────────────────────────────────────────────────

class _GridDef {
  final IconData icon;
  final String label;
  final Color color;
  final int index;
  const _GridDef(this.icon, this.label, this.color, this.index);
}

class _GridTile extends StatelessWidget {
  final _GridDef item;
  final String label;
  final int badge;
  final VoidCallback onTap;
  const _GridTile(
      {required this.item, required this.label, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(item.icon, color: item.color, size: 32),
            ),
            if (badge > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 1. Schedule
// ════════════════════════════════════════════════════════════════════════════

class _PatientScheduleScreen extends StatefulWidget {
  const _PatientScheduleScreen();

  @override
  State<_PatientScheduleScreen> createState() => _PatientScheduleScreenState();
}

class _PatientScheduleScreenState extends State<_PatientScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _service = PatientService();

  // Doctor name/photo cache
  final Map<String, String> _doctorNames       = {};
  final Map<String, String> _doctorPhotos      = {};
  final Map<String, bool>   _doctorShowDrPrefix = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _prefetchDoctor(String doctorId) async {
    if (_doctorNames.containsKey(doctorId)) return;
    final doc = await PatientService().getDoctorById(doctorId);
    if (doc != null) {
      final d = doc;
      if (mounted) {
        setState(() {
          _doctorNames[doctorId]        = (d['name'] as String?) ?? '';
          _doctorPhotos[doctorId]       = (d['profile_photo_url'] as String?) ?? '';
          _doctorShowDrPrefix[doctorId] = (d['show_dr_prefix'] as bool?) ?? false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Builder(builder: (ctx) {
          final s = AppStrings(ctx.read<LanguageProvider>().isArabic);
          return Text(s.myAppointments,
              style: const TextStyle(fontWeight: FontWeight.bold));
        }),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(Icons.calendar_month_rounded,
                color: _kBlue, size: 24),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _kBlue,
          indicatorWeight: 3,
          labelColor: _kBlue,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: [
            Builder(builder: (ctx) { final s = AppStrings(ctx.read<LanguageProvider>().isArabic); return Tab(text: s.upcomingTab); }),
            Builder(builder: (ctx) { final s = AppStrings(ctx.read<LanguageProvider>().isArabic); return Tab(text: s.requestedTab); }),
            Builder(builder: (ctx) { final s = AppStrings(ctx.read<LanguageProvider>().isArabic); return Tab(text: s.previousTab); }),
            Builder(builder: (ctx) { final s = AppStrings(ctx.read<LanguageProvider>().isArabic); return Tab(text: s.summaryTab); }),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _service.getMyAppointments(),
        builder: (_, apptSnap) => StreamBuilder<List<Map<String, dynamic>>>(
          stream: _service.getMyAppointmentRequests(),
          builder: (_, reqSnap) {
            if (apptSnap.connectionState == ConnectionState.waiting ||
                reqSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allAppts = apptSnap.data ?? [];
            final allReqs = reqSnap.data ?? [];
            final now = DateTime.now();

            final upcoming = allAppts.where((d) {
              final t = DateTime.parse(d['appointment_time'] as String);
              final status =
                  d['status'] as String? ?? '';
              return t.isAfter(now) && status != 'cancelled';
            }).toList()
              ..sort((a, b) {
                final at = DateTime.parse(a['appointment_time'] as String);
                final bt = DateTime.parse(b['appointment_time'] as String);
                return at.compareTo(bt);
              });

            final previous = allAppts.where((d) {
              final t = DateTime.parse(d['appointment_time'] as String);
              return !t.isAfter(now);
            }).toList()
              ..sort((a, b) {
                final at = DateTime.parse(a['appointment_time'] as String);
                final bt = DateTime.parse(b['appointment_time'] as String);
                return bt.compareTo(at);
              });

            // Pre-fetch doctor names
            for (final d in allAppts) {
              final doctorId =
                  d['doctor_id'] as String? ?? '';
              if (doctorId.isNotEmpty) _prefetchDoctor(doctorId);
            }

            return TabBarView(
              controller: _tabs,
              children: [
                _buildUpcomingTab(upcoming),
                _buildRequestedTab(allReqs),
                _buildPreviousTab(previous),
                _buildSummaryTab(allAppts),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Upcoming ───────────────────────────────────────────────────────────────

  Widget _buildUpcomingTab(List<Map<String, dynamic>> appts) {
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    if (appts.isEmpty) {
      return _emptyState(Icons.event_available_rounded, s.noUpcomingApptsMsg);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: appts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _apptCard(appts[i], isUpcoming: true),
    );
  }

  // ── Requested ──────────────────────────────────────────────────────────────

  Widget _buildRequestedTab(List<Map<String, dynamic>> reqs) {
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    if (reqs.isEmpty) {
      return _emptyState(Icons.pending_actions_rounded, s.noRequestsMsg);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reqs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _requestCard(reqs[i]),
    );
  }

  Widget _requestCard(Map<String, dynamic> doc) {
    final data = doc;
    final doctorName = data['doctor_name'] as String? ?? 'Doctor';
    final rtStr = data['requested_time'] as String?;
    final dt = rtStr != null ? DateTime.parse(rtStr) : null;
    final notes = data['notes'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'accepted':
        statusColor = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Accepted';
      case 'declined':
        statusColor = const Color(0xFFC62828);
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Declined';
      default:
        statusColor = const Color(0xFFF57F17);
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: statusColor.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pending_actions_rounded,
                color: _kBlue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Dr. $doctorName',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              if (dt != null)
                Text(
                  DateFormat('EEE, MMM d  ·  h:mm a').format(dt),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, color: statusColor, size: 13),
              const SizedBox(width: 4),
              Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(notes,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ]),
    );
  }

  // ── Previous ───────────────────────────────────────────────────────────────

  Widget _buildPreviousTab(List<Map<String, dynamic>> appts) {
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    if (appts.isEmpty) {
      return _emptyState(Icons.history_rounded, s.noPastApptsMsg);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: appts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _apptCard(appts[i], isUpcoming: false),
    );
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  Widget _buildSummaryTab(List<Map<String, dynamic>> allAppts) {
    final now = DateTime.now();
    final past = allAppts.where((d) {
      final t = DateTime.parse(d['appointment_time'] as String);
      return !t.isAfter(now);
    }).toList();

    // Group by doctorId
    final Map<String, List<Map<String, dynamic>>> byDoc = {};
    for (final d in past) {
      final doctorId =
          d['doctor_id'] as String? ?? 'unknown';
      byDoc.putIfAbsent(doctorId, () => []).add(d);
    }

    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    if (byDoc.isEmpty) {
      return _emptyState(Icons.bar_chart_rounded, s.noSessionsMsg);
    }

    // Sort by session count descending
    final sorted = byDoc.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total sessions chip
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_kNavy, _kBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.event_available_rounded,
                color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${past.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              Text(s.totalSessionsAttended,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Text(s.sessionsByDoctor,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...sorted.map((entry) {
          final doctorId = entry.key;
          final sessions = entry.value;
          final doctorName    = _doctorNames[doctorId] ?? '';
          final doctorPhoto   = _doctorPhotos[doctorId] ?? '';
          final showDrSummary = _doctorShowDrPrefix[doctorId] ?? false;

          // Sort sessions by date (newest first) for the last-session label
          final sorted2 = sessions.toList()
            ..sort((a, b) {
              final at = DateTime.parse(a['appointment_time'] as String);
              final bt = DateTime.parse(b['appointment_time'] as String);
              return bt.compareTo(at);
            });
          final lastSession =
              DateTime.parse(sorted2.first['appointment_time'] as String);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _kBlue.withValues(alpha: 0.1),
                backgroundImage: doctorPhoto.isNotEmpty
                    ? NetworkImage(doctorPhoto)
                    : null,
                child: doctorPhoto.isEmpty
                    ? const Icon(Icons.person_rounded,
                        color: _kBlue, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    showDrSummary && doctorName.isNotEmpty
                        ? 'Dr. $doctorName'
                        : doctorName.isNotEmpty ? doctorName : 'Doctor',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    s.lastSessionDate(DateFormat('MMM d, yyyy').format(lastSession)),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${sessions.length} ${sessions.length == 1 ? 'session' : 'sessions'}',
                  style: const TextStyle(
                      color: _kBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }

  // ── Shared appointment card ────────────────────────────────────────────────

  Widget _apptCard(Map<String, dynamic> doc, {required bool isUpcoming}) {
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    final data = doc;
    final dt = DateTime.parse(data['appointment_time'] as String);
    final notes = data['notes'] as String? ?? '';
    final doctorId = data['doctor_id'] as String? ?? '';
    final status = data['status'] as String? ?? 'scheduled';
    final isCancelled = status == 'cancelled';
    final doctorName    = _doctorNames[doctorId] ?? '';
    final doctorPhoto   = _doctorPhotos[doctorId] ?? '';
    final showDrAppt    = _doctorShowDrPrefix[doctorId] ?? false;
    final appointmentId = data['id'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _kBlue.withValues(alpha: 0.1),
            backgroundImage: doctorPhoto.isNotEmpty
                ? NetworkImage(doctorPhoto)
                : null,
            child: doctorPhoto.isEmpty
                ? const Icon(Icons.person_rounded, color: _kBlue, size: 26)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                showDrAppt && doctorName.isNotEmpty
                    ? 'Dr. $doctorName'
                    : doctorName.isNotEmpty ? doctorName : 'Doctor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCancelled
                      ? Colors.grey
                      : AppColors.textPrimary,
                  decoration: isCancelled
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (isCancelled)
                Container(
                  margin: const EdgeInsets.only(top: 2),
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
          ),
        ]),
        const Divider(height: 18),
        Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormat('EEEE, MMM d, yyyy').format(dt)}  |  ${DateFormat('h:mm a').format(dt)}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
            ),
          ),
        ]),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.notes_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          ]),
        ],
        if (!isCancelled) ...[
          const SizedBox(height: 14),
          if (isUpcoming)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.contactYourDoctor)),
                  ),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                  label: Text(s.reschedule,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00897B),
                    side: const BorderSide(color: Color(0xFF00897B)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: appointmentId.isNotEmpty
                      ? () => _confirmCancel(appointmentId)
                      : null,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ])
          else
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Text(s.completed,
                  style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ]),
        ],
      ]),
    );
  }

  void _confirmCancel(String appointmentId) {
    final s = AppStrings(context.read<LanguageProvider>().isArabic);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.cancelAppointment),
        content: Text(s.cancelAppointmentConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.keepIt)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updated = await Supabase.instance.client
                  .from('appointments')
                  .update({'status': 'cancelled'})
                  .eq('id', appointmentId)
                  .select()
                  .single();
              final doctorId   = updated['doctor_id'] as String?;
              final patientName = (updated['patient_name'] as String?) ?? 'A patient';
              if (doctorId != null) {
                await Supabase.instance.client.from('notifications').insert({
                  'recipient_id': doctorId,
                  'recipient_type': 'doctor',
                  'type': 'appointment_cancelled',
                  'title': 'Appointment Cancelled',
                  'body': '$patientName cancelled their appointment.',
                  'read': false,
                  'created_at': DateTime.now().toIso8601String(),
                });
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.appointmentCancelled)),
                );
              }
            },
            child: Text(s.cancelIt,
                style: const TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 2. My Doctors  (only doctors in patient's doctorIds list)
// ════════════════════════════════════════════════════════════════════════════

class _PatientMyDoctorsScreen extends StatefulWidget {
  final PatientService service;
  const _PatientMyDoctorsScreen({required this.service});

  @override
  State<_PatientMyDoctorsScreen> createState() =>
      _PatientMyDoctorsScreenState();
}

class _PatientMyDoctorsScreenState extends State<_PatientMyDoctorsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(s.myDoctors,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: _kBlue),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindDoctorsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: s.searchDoctors,
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary),
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.service.getLinkedDoctors(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data ?? [];
                final doctors = _query.isEmpty
                    ? all
                    : all.where((d) {
                        final name =
                            (d['name'] as String? ?? '').toLowerCase();
                        final spec =
                            (d['specialization'] as String? ?? '')
                                .toLowerCase();
                        return name.contains(_query) ||
                            spec.contains(_query);
                      }).toList();

                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child:
                          Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _kBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_search_rounded,
                              size: 40, color: _kBlue),
                        ),
                        const SizedBox(height: 20),
                        Text(s.noDoctorsAdded,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text(
                          s.searchForDoctor,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const FindDoctorsScreen())),
                          icon: const Icon(Icons.search_rounded),
                          label: Text(s.findDoctorOrTherapist),
                        ),
                      ]),
                    ),
                  );
                }
                if (doctors.isEmpty) {
                  return Center(
                    child: Text(s.noResultsFor(_query),
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: doctors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final data = doctors[i];
                    return _LinkedDoctorCard(
                      docId: data['id'] as String,
                      data: data,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Linked doctor card ─────────────────────────────────────────────────────

class _LinkedDoctorCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _LinkedDoctorCard({required this.docId, required this.data});

  Future<Map<String, dynamic>?> _getNextAppt() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    final res = await Supabase.instance.client
        .from('appointments')
        .select()
        .eq('patient_id', uid)
        .eq('doctor_id', docId)
        .gt('appointment_time', DateTime.now().toIso8601String())
        .neq('status', 'cancelled')
        .order('appointment_time')
        .limit(1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> _confirmRemove(BuildContext context, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Doctor'),
        content: Text('Remove $displayName from your doctors list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await PatientService().removeDoctorFromMyList(docId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '$displayName removed from your doctors'
            : 'Failed to remove doctor'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name       = data['name'] as String? ?? 'Doctor';
    final spec       = data['specialization'] as String? ?? 'Physical Therapist';
    final photo      = data['profile_photo_url'] as String? ?? '';
    final clinic     = data['clinicName'] as String? ?? '';
    final homeVisit  = (data['offers_home_visit'] as bool?) ?? false;
    final bio        = data['bio'] as String? ?? '';
    final exp        = data['experience'] as String? ?? '';
    final showDrCard = (data['show_dr_prefix'] as bool?) ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _kBlue.withValues(alpha: 0.1),
            backgroundImage:
                photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty
                ? const Icon(Icons.person_rounded,
                    size: 30, color: _kBlue)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(showDrCard && name.isNotEmpty ? 'Dr. $name' : name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(spec,
                  style: const TextStyle(
                      color: _kBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              if (clinic.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(clinic,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              if (homeVisit)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Icon(Icons.home_rounded,
                        color: Colors.green, size: 12),
                    SizedBox(width: 3),
                    Text('Home Visit',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
          IconButton(
            onPressed: () => _confirmRemove(context, showDrCard && name.isNotEmpty ? 'Dr. $name' : name),
            icon: const Icon(Icons.person_remove_rounded,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Remove doctor',
            visualDensity: VisualDensity.compact,
          ),
        ]),
        FutureBuilder<Map<String, dynamic>?>(
          future: _getNextAppt(),
          builder: (_, snap) {
            if (!snap.hasData || snap.data == null) {
              return const SizedBox.shrink();
            }
            final dt = DateTime.parse(
                snap.data!['appointment_time'] as String);
            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 15, color: _kBlue),
                const SizedBox(width: 8),
                Text(
                  'Next Appointment: ${DateFormat('MMM d, yyyy').format(dt)}',
                  style: const TextStyle(
                      color: _kBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            );
          },
        ),
        if (exp.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.work_history_rounded,
                size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('$exp experience',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ],
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _btn(
              'Request',
              Icons.event_available_rounded,
              _kBlue,
              () => _showRequestSheet(context, name),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Builder(builder: (ctx) {
              final phone = (data['phone'] as String? ?? '');
              final rawPhone = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
              final hasPhone = rawPhone.isNotEmpty;
              return GestureDetector(
                onTap: () {
                  if (!hasPhone) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'No phone number on file for this doctor.')),
                    );
                    return;
                  }
                  showModalBottomSheet(
                    context: ctx,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20))),
                    builder: (_) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(phone,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  const Color(0xFF25D366).withValues(alpha: 0.1),
                              child: const Icon(Icons.chat_rounded,
                                  color: Color(0xFF25D366)),
                            ),
                            title: const Text('WhatsApp'),
                            onTap: () {
                              Navigator.pop(ctx);
                              launchUrl(Uri.parse('https://wa.me/$rawPhone'),
                                  mode: LaunchMode.externalApplication);
                            },
                          ),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.phone_rounded,
                                  color: AppColors.primary),
                            ),
                            title: const Text('Phone Call'),
                            onTap: () {
                              Navigator.pop(ctx);
                              launchUrl(Uri.parse('tel:$rawPhone'),
                                  mode: LaunchMode.externalApplication);
                            },
                          ),
                        ]),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: hasPhone
                        ? const Color(0xFF25D366)
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.phone_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    const Text('Contact',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            }),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showProfileSheet(context, data),
            icon: const Icon(Icons.person_search_rounded, size: 18),
            label: const Text('View Doctor Profile',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _btn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Request appointment with available slots ─────────────────────────────

  void _showRequestSheet(BuildContext context, String doctorName) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    DateTime? selectedDate2;
    int? selectedSlotIndex;
    List<DateTime> bookedSlots = [];
    bool loadingSlots = true;
    final notesCtrl = TextEditingController();

    // Load doctor's booked slots
    PatientService().getDoctorBookedSlots(docId).then((slots) {
      bookedSlots = slots;
      loadingSlots = false;
    });

    // Generate 1-hour time slots 9am-5pm
    List<DateTime> slotsForDay(DateTime day) {
      final slots = <DateTime>[];
      for (int h = 9; h <= 17; h++) {
        final slot = DateTime(day.year, day.month, day.day, h, 0);
        if (slot.isAfter(DateTime.now())) {
          slots.add(slot);
        }
      }
      return slots;
    }

    bool isBooked(DateTime slot) {
      return bookedSlots.any((b) =>
          b.year == slot.year &&
          b.month == slot.month &&
          b.day == slot.day &&
          b.hour == slot.hour);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) {
          bool sending = false;
          final slots = selectedDate2 != null
              ? slotsForDay(selectedDate2!)
              : <DateTime>[];

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle bar
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _kBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        const Icon(Icons.event_available_rounded, color: _kBlue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Request Appointment',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                          ((data['show_dr_prefix'] as bool?) ?? false) && doctorName.isNotEmpty
                              ? 'Dr. $doctorName'
                              : doctorName,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12)),
                    ]),
                  ),
                ]),
                // Working hours banner
                Builder(builder: (_) {
                  final wh = (data['working_hours'] as String? ?? '').trim();
                  if (wh.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time_rounded, size: 15, color: _kBlue),
                      const SizedBox(width: 8),
                      Expanded(child: Text(wh,
                          style: const TextStyle(fontSize: 12, color: _kBlue))),
                    ]),
                  );
                }),
                const SizedBox(height: 16),

                // Date picker
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 60)),
                    );
                    if (d != null) {
                      setBS(() {
                        selectedDate = d;
                        selectedDate2 = d;
                        selectedSlotIndex = null;
                      });
                      // Refresh slots
                      PatientService()
                          .getDoctorBookedSlots(docId)
                          .then((s) => setBS(() => bookedSlots = s));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kBlue.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: _kBlue, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        selectedDate2 != null
                            ? DateFormat('EEEE, MMMM d, yyyy')
                                .format(selectedDate2!)
                            : 'Tap to choose a date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selectedDate2 != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // Time slots grid
                if (selectedDate2 != null) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Available Times',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(height: 8),
                  loadingSlots
                      ? const Center(
                          child:
                              SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : slots.isEmpty
                          ? const Text('No slots available for this day.',
                              style: TextStyle(
                                  color: AppColors.textSecondary))
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: slots.asMap().entries.map((e) {
                                final idx = e.key;
                                final slot = e.value;
                                final booked = isBooked(slot);
                                final selected = selectedSlotIndex == idx;
                                return GestureDetector(
                                  onTap: booked
                                      ? null
                                      : () =>
                                          setBS(() => selectedSlotIndex = idx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: booked
                                          ? Colors.grey.shade100
                                          : selected
                                              ? _kBlue
                                              : Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: booked
                                            ? Colors.grey.shade300
                                            : selected
                                                ? _kBlue
                                                : _kBlue.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      DateFormat('h:mm a').format(slot),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: booked
                                            ? Colors.grey.shade400
                                            : selected
                                                ? Colors.white
                                                : _kBlue,
                                        decoration: booked
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                  const SizedBox(height: 12),
                ],

                // Notes
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    hintText: 'Reason / notes (optional)',
                    prefixIcon:
                        const Icon(Icons.notes_rounded, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FF),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (sending ||
                            selectedDate2 == null ||
                            selectedSlotIndex == null)
                        ? null
                        : () async {
                            setBS(() => sending = true);
                            final slot = slotsForDay(
                                selectedDate2!)[selectedSlotIndex!];
                            final ok = await PatientService()
                                .sendAppointmentRequest(
                              doctorId: docId,
                              doctorName: doctorName,
                              requestedTime: slot,
                              notes: notesCtrl.text.trim(),
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Appointment request sent!'
                                      : 'Failed to send request.'),
                                  backgroundColor: ok
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              );
                            }
                          },
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                        selectedSlotIndex != null && selectedDate2 != null
                            ? 'Send Request'
                            : 'Select a time slot',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showProfileSheet(BuildContext context, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final spec = data['specialization'] as String? ?? '';
    final bio = data['bio'] as String? ?? '';
    final clinic = data['clinicName'] as String? ?? '';
    final address = data['clinicAddress'] as String? ?? '';
    final phone        = data['phone'] as String? ?? '';
    final photo        = data['profile_photo_url'] as String? ?? '';
    final exp          = data['experience'] as String? ?? '';
    final cert         = data['certifications'] as String? ?? '';
    final homeVisit    = (data['offers_home_visit'] as bool?) ?? false;
    final workingHours = (data['working_hours'] as String? ?? '').trim();
    final showDrProfile = (data['show_dr_prefix'] as bool?) ?? false;

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
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty
                      ? const Icon(Icons.person_rounded,
                          size: 44, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(showDrProfile && name.isNotEmpty ? 'Dr. $name' : name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              if (spec.isNotEmpty)
                Center(
                  child: Text(spec,
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: 13)),
                ),
              const SizedBox(height: 20),
              if (clinic.isNotEmpty) _sheetRow(Icons.business_rounded, clinic),
              if (address.isNotEmpty)
                _sheetRow(Icons.location_on_rounded, address),
              if (phone.isNotEmpty)
                _sheetRow(Icons.phone_rounded, phone,
                    color: AppColors.primary,
                    onTap: () => _openPhone(context, phone)),
              if (exp.isNotEmpty)
                _sheetRow(Icons.work_history_rounded, '$exp experience'),
              if (cert.isNotEmpty)
                _sheetRow(Icons.military_tech_rounded, cert),
              if (homeVisit)
                _sheetRow(Icons.home_rounded, 'Home visits available',
                    color: Colors.green),
              if (workingHours.isNotEmpty)
                _sheetRow(Icons.access_time_rounded, workingHours,
                    color: _kBlue),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('About',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(bio,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                        fontSize: 13)),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(IconData icon, String text,
      {Color color = AppColors.textSecondary, VoidCallback? onTap}) {
    if (text.isEmpty) return const SizedBox.shrink();
    Widget row = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(text, style: TextStyle(color: color, fontSize: 13))),
        if (onTap != null)
          const Icon(Icons.open_in_new_rounded,
              size: 14, color: AppColors.primary),
      ]),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: row);
    }
    return row;
  }

  void _openPhone(BuildContext ctx, String phone) {
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
}

// ════════════════════════════════════════════════════════════════════════════
// 3. Notifications
// ════════════════════════════════════════════════════════════════════════════

class _PatientNotificationsScreen extends StatelessWidget {
  final PatientService service;
  const _PatientNotificationsScreen({required this.service});

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  Future<void> _markAllRead() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client
        .from('notifications')
        .update({'read': true})
        .eq('patient_id', uid)
        .eq('read', false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.getMyNotifications(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_none_rounded,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No notifications yet.',
                    style:
                        TextStyle(color: AppColors.textSecondary)),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i];
              final title = data['title'] as String? ?? 'Notification';
              final body = data['body'] as String? ?? '';
              final read = data['read'] as bool? ?? false;
              final ts = data['created_at'] as String?;
              final dt = (ts != null ? DateTime.parse(ts) : null) ?? DateTime.now();
              final type = data['type'] as String? ?? '';

              // Map notification types to icons/colors
              final (notifIcon, notifColor) = switch (type) {
                'appointment_accepted' => (
                    Icons.check_circle_rounded,
                    const Color(0xFF2E7D32)
                  ),
                'appointment_declined' => (
                    Icons.cancel_rounded,
                    const Color(0xFFC62828)
                  ),
                'appointment_scheduled' => (
                    Icons.event_available_rounded,
                    _kBlue
                  ),
                'doctor_added_confirmation' => (
                    Icons.how_to_reg_rounded,
                    _kBlue
                  ),
                'appointment_reminder' => (
                    Icons.alarm_rounded,
                    const Color(0xFFF57F17)
                  ),
                'appointment' => (Icons.event_rounded, _kBlue),
                'reminder' => (
                    Icons.alarm_rounded,
                    const Color(0xFFE65100)
                  ),
                'message' => (
                    Icons.chat_bubble_rounded,
                    const Color(0xFF283593)
                  ),
                'call' => (Icons.phone_rounded, const Color(0xFF00695C)),
                _ => (Icons.assignment_rounded, AppColors.primary),
              };

              return Dismissible(
                key: Key(docs[i]['id'] as String),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white),
                ),
                onDismissed: (_) => Supabase.instance.client
                    .from('notifications').delete().eq('id', docs[i]['id'] as String),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: read
                        ? Colors.white
                        : notifColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: read
                          ? AppColors.cardBorder
                          : notifColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    leading: Stack(clipBehavior: Clip.none, children: [
                      CircleAvatar(
                        backgroundColor:
                            notifColor.withValues(alpha: 0.12),
                        child: Icon(notifIcon,
                            color: notifColor, size: 20),
                      ),
                      if (!read)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: notifColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ]),
                    title: Text(title,
                        style: TextStyle(
                          fontWeight:
                              read ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                        )),
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (body.isNotEmpty)
                            Text(body,
                                style: const TextStyle(
                                    fontSize: 12, height: 1.3)),
                          const SizedBox(height: 2),
                          Text(_ago(dt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ]),
                    onTap: () {
                      if (!read) {
                        service.markNotificationRead(docs[i]['id'] as String);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 5. Profile
// ════════════════════════════════════════════════════════════════════════════


// ════════════════════════════════════════════════════════════════════════════
// 5. Profile
// ════════════════════════════════════════════════════════════════════════════

class _PatientProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const _PatientProfileScreen({this.profile});

  @override
  State<_PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<_PatientProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _curPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();

  bool _savingProfile = false;
  bool _savingPass = false;
  bool _deletingAccount = false;
  bool _obscureCur = true;
  bool _obscureNew = true;
  bool _obscureConf = true;
  bool _uploadingPhoto = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.profile?['name'] as String? ?? '');
    _phoneCtrl = TextEditingController(
        text: LebanonPhoneField.stripCountryCode(
            widget.profile?['phone'] as String? ?? ''));
    _photoUrl = widget.profile?['profile_photo_url'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _curPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _showDeleteAccountDialog(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
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

  Future<void> _pickPhoto() async {
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (img == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final fileName = 'profile_photos/patients/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage.from('profile-photos').uploadBinary(fileName, await img.readAsBytes());
      final url = Supabase.instance.client.storage.from('profile-photos').getPublicUrl(fileName);
      await Supabase.instance.client
          .from('users').update({'profile_photo_url': url}).eq('id', uid);
      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfile(BuildContext sheetCtx) async {
    setState(() => _savingProfile = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('users').update({
        'phone': LebanonPhoneField.toStored(_phoneCtrl.text),
      }).eq('id', uid);
      if (sheetCtx.mounted) {
        Navigator.pop(sheetCtx);
        messenger.showSnackBar(const SnackBar(
            content: Text('Profile saved!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword(BuildContext sheetCtx) async {
    if (_newPassCtrl.text != _confPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')));
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password must be at least 6 characters.')));
      return;
    }
    setState(() => _savingPass = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPassCtrl.text),
      );
      _curPassCtrl.clear();
      _newPassCtrl.clear();
      _confPassCtrl.clear();
      if (sheetCtx.mounted) {
        Navigator.pop(sheetCtx);
        messenger.showSnackBar(const SnackBar(
            content: Text('Password changed!'),
            backgroundColor: AppColors.success));
      }
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.code == 'wrong-password'
              ? 'Current password is incorrect.'
              : 'Error: ${e.message}')));
    } finally {
      if (mounted) setState(() => _savingPass = false);
    }
  }

  void _showEditProfileSheet() {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Edit Profile',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
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
                    Text('Full Name',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text(
                        _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '—',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600)),
                  ]),
                ),
                Icon(Icons.lock_outline_rounded,
                    size: 16, color: Colors.grey.shade400),
              ]),
            ),
            const SizedBox(height: 10),
            LebanonPhoneField(controller: _phoneCtrl, label: 'Phone Number'),
            const SizedBox(height: 10),
            AbsorbPointer(
              child: TextFormField(
                initialValue: email,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon:
                      const Icon(Icons.email_outlined, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _savingProfile ? null : () => _saveProfile(ctx),
                child: _savingProfile
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Profile'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Change Password',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 20),
              _passField(_curPassCtrl, 'Current Password', _obscureCur,
                  () => setBS(() => _obscureCur = !_obscureCur)),
              const SizedBox(height: 10),
              _passField(_newPassCtrl, 'New Password', _obscureNew,
                  () => setBS(() => _obscureNew = !_obscureNew)),
              const SizedBox(height: 10),
              _passField(_confPassCtrl, 'Confirm New Password', _obscureConf,
                  () => setBS(() => _obscureConf = !_obscureConf)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _savingPass ? null : () => _changePassword(ctx),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: _kGreen),
                  child: _savingPass
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Change Password'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showAppSettings(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App Settings'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.language_rounded, color: _kBlue),
            title: const Text('Language'),
            trailing: Text(
              lang.isArabic ? 'العربية' : 'English',
              style: const TextStyle(
                  color: _kBlue, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              lang.toggle();
              Navigator.pop(ctx);
            },
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final displayName =
        _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'My Profile';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kNavy, _kBlue],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text('My Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          )),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Stack(children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 3),
                    ),
                    child: ClipOval(
                      child: _uploadingPhoto
                          ? Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : (_photoUrl != null && _photoUrl!.isNotEmpty
                              ? Image.network(_photoUrl!,
                                  fit: BoxFit.cover)
                              : Container(
                                  color: Colors.white24,
                                  child: const Icon(Icons.person_rounded,
                                      size: 50, color: Colors.white))),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _kBlue,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    )),
                const SizedBox(height: 4),
                Text(email,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 28),
              ]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(children: [
                    _menuTile(Icons.edit_rounded, _kBlue, 'Edit Profile',
                        'Update your name and phone number',
                        _showEditProfileSheet),
                    Divider(height: 1, indent: 68, color: AppColors.cardBorder),
                    _menuTile(Icons.lock_rounded, const Color(0xFF6A1B9A),
                        'Change Password', 'Update your account password',
                        _showChangePasswordSheet),
                    Divider(height: 1, indent: 68, color: AppColors.cardBorder),
                    _menuTile(Icons.settings_rounded, AppColors.textSecondary,
                        'App Settings', 'Language and preferences',
                        () => _showAppSettings(context),
                        showDivider: false),
                  ]),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text(
                          'Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            }
                          },
                          child: const Text('Sign Out',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.error),
                  label: const Text('Sign Out',
                      style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: OutlinedButton.icon(
                    onPressed: _deletingAccount
                        ? null
                        : () => _showDeleteAccountDialog(context),
                    icon: _deletingAccount
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.red),
                          )
                        : const Icon(Icons.delete_forever_rounded,
                            color: Colors.red, size: 14),
                    label: Text(
                      _deletingAccount ? 'Deleting...' : 'Delete Account',
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    Color iconColor,
    String label,
    String subtitle,
    VoidCallback onTap, {
    bool showDivider = true,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 14,
          )),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  Widget _passField(TextEditingController ctrl, String label, bool obscure,
      VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}
