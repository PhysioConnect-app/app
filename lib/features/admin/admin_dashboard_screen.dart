import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/subscription_model.dart';
import '../admin/admin_service.dart';

const _kSlate = Color(0xFF37474F);
const _kInk   = Color(0xFF1A237E);

// ── Notification list helpers ─────────────────────────────────────────────────

enum _NotifType { drPrefix, nameChange, accountRequest }

class _NotifItem {
  final bool isHeader;
  final String? headerTitle;
  final _NotifType? type;
  final Map<String, dynamic>? data;

  const _NotifItem._({
    required this.isHeader,
    this.headerTitle,
    this.type,
    this.data,
  });

  factory _NotifItem.header(String title) =>
      _NotifItem._(isHeader: true, headerTitle: title);
  factory _NotifItem.drPrefix(Map<String, dynamic> d) =>
      _NotifItem._(isHeader: false, type: _NotifType.drPrefix, data: d);
  factory _NotifItem.nameChange(Map<String, dynamic> d) =>
      _NotifItem._(isHeader: false, type: _NotifType.nameChange, data: d);
  factory _NotifItem.accountRequest(Map<String, dynamic> d) =>
      _NotifItem._(isHeader: false, type: _NotifType.accountRequest, data: d);
}

// ── Feature definitions ──────────────────────────────────────────────────────

class _FeatDef {
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _FeatDef(this.key, this.label, this.subtitle, this.icon, this.color);
}

// ── Nav bar definitions ───────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

const _kAdminNavItems = [
  _NavItem(Icons.dashboard_rounded, 'Overview'),
  _NavItem(Icons.people_rounded, 'Doctors'),
  _NavItem(Icons.business_rounded, 'Polyclinics'),
  _NavItem(Icons.person_add_rounded, 'Register'),
  _NavItem(Icons.notifications_rounded, 'Requests'),
  _NavItem(Icons.personal_injury_rounded, 'Patients'),
  _NavItem(Icons.campaign_rounded, 'Notes'),
];

const _kFeats = [
  _FeatDef('statistics', 'Statistics', 'Session & revenue analytics', Icons.bar_chart_rounded,    Color(0xFF00695C)),
  _FeatDef('billing',    'Income',     'Invoices & income tracking',  Icons.receipt_long_rounded, Color(0xFFF57F17)),
  _FeatDef('expenses',   'Expenses',   'Expense management & reports',Icons.receipt_rounded,      Color(0xFF00796B)),
];

// ── Avatar color ─────────────────────────────────────────────────────────────

Color _avatarColor(String name) {
  const palette = [
    Color(0xFF5C6BC0), Color(0xFF26A69A), Color(0xFF42A5F5),
    Color(0xFF66BB6A), Color(0xFFAB47BC), Color(0xFFFF7043),
    Color(0xFF26C6DA), Color(0xFFEF5350),
  ];
  if (name.isEmpty) return palette[0];
  return palette[name.codeUnits.fold(0, (a, b) => a + b) % palette.length];
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  return parts.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
}

String _fmtDate(String? ts) {
  if (ts == null) return '';
  const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final dt = DateTime.parse(ts);
  return '${mo[dt.month - 1]} ${dt.year}';
}

String _fmtDateTime(String? ts) {
  if (ts == null) return '';
  const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final dt = DateTime.parse(ts).toLocal();
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '${mo[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$min $ampm';
}

// ── Duplicate patient detection ─────────────────────────────────────────────
// Groups patients whose names match after trimming/collapsing whitespace and
// lower-casing, so admins can spot likely duplicate records to merge.

List<List<Map<String, dynamic>>> _findDuplicatePatientGroups(
    List<Map<String, dynamic>> patients) {
  final byName = <String, List<Map<String, dynamic>>>{};
  for (final p in patients) {
    final name = ((p['name'] ?? '') as String)
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    if (name.isEmpty) continue;
    byName.putIfAbsent(name, () => []).add(p);
  }
  final groups = byName.values.where((g) => g.length > 1).toList();
  groups.sort((a, b) => ((a.first['name'] ?? '') as String)
      .compareTo((b.first['name'] ?? '') as String));
  return groups;
}

// ════════════════════════════════════════════════════════════════════════════════
// Screen
// ════════════════════════════════════════════════════════════════════════════════

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  final _adminService = AdminService();
  int _currentIndex = 0;

  // Register form
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _specCtrl  = TextEditingController();
  bool _processing    = false;
  bool _obscure       = true;
  bool _isPolyclinic  = false;   // toggle between doctor / polyclinic registration

  // Doctors list
  String _searchQuery = '';
  // Polyclinics list
  String _polySearchQuery = '';
  // Patients list
  String _patientSearchQuery = '';
  final Set<String> _selectedPatientIds = {};

  // Notes / broadcast tab
  final _noteTitleCtrl = TextEditingController();
  final _noteBodyCtrl  = TextEditingController();
  final Set<String> _noteSelectedDoctorIds = {};
  bool _noteSending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _specCtrl.dispose();
    _noteTitleCtrl.dispose();
    _noteBodyCtrl.dispose();
    super.dispose();
  }

  // ── Register ───────────────────────────────────────────────────────────────

  Future<void> _registerDoctor() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    final spec  = _specCtrl.text.trim();
    if (name.isEmpty || email.isEmpty || pass.length < 6) {
      _snack('Fill all fields. Password must be at least 6 characters.');
      return;
    }
    setState(() => _processing = true);
    final error = await _adminService.createDoctorAccount(
      name: name, email: email, password: pass, specialty: spec,
    );
    if (!mounted) return;
    if (error == null) {
      _snack('Doctor account created!', color: AppColors.success);
      _nameCtrl.clear(); _emailCtrl.clear(); _passCtrl.clear(); _specCtrl.clear();
      setState(() => _currentIndex = 1);
    } else {
      _snack('Error: $error', color: AppColors.error);
    }
    setState(() => _processing = false);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(String docId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Remove Doctor'),
        ]),
        content: Text(
            'Remove "$name" from the system?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _adminService.deleteUserAccount(docId);
    if (!mounted) return;
    _snack(err == null ? 'Doctor account removed.' : 'Error: $err',
        color: err == null ? null : AppColors.error);
  }

  // ── Manage subscription ────────────────────────────────────────────────────

  void _openManageSheet(Map<String, dynamic> doc) {
    final data  = doc;
    final ac    = _avatarColor((data['name'] ?? '') as String);

    SubConfig config = SubConfig.fromMap(data);
    bool saving = false;
    bool drPrefix       = (data['show_dr_prefix']    as bool?)   ?? false;
    String drPrefixReq  = (data['dr_prefix_request'] as String?) ?? 'none';

    // Editable info fields
    final nameCtrl = TextEditingController(text: data['name'] as String? ?? '');
    final specCtrl = TextEditingController(
        text: (data['specialization'] ?? data['specialty'] ?? '') as String);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Doctor header ────────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      color: ac.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(_initials(nameCtrl.text),
                          style: TextStyle(
                              color: ac,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nameCtrl.text,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text((data['email'] as String?) ?? '',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                        if (specCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: ac.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(specCtrl.text,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: ac,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Current tier badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: config.tier.bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(config.tier.icon,
                          size: 13, color: config.tier.color),
                      const SizedBox(width: 4),
                      Text(config.tier.label,
                          style: TextStyle(
                              fontSize: 12,
                              color: config.tier.color,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ]),

                const SizedBox(height: 28),
                _sheetSectionLabel('Subscription Tier'),
                const SizedBox(height: 4),
                const Text(
                  'Selecting a tier auto-applies default features. '
                  'You can still override them individually below.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),

                // ── Tier chips ───────────────────────────────────────────────
                Row(
                  children: SubTier.values.map((t) {
                    final sel = config.tier == t;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setLocal(() {
                          config = SubConfig.defaultsFor(t).copyWith(
                            isEnabled:    config.isEnabled,
                            showInSearch: t == SubTier.premium
                                ? config.showInSearch
                                : false, // Basic → hide from patient search
                            expiresAt: config.expiresAt,
                          );
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: sel ? t.color : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel ? t.color : AppColors.cardBorder,
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Column(children: [
                            Icon(t.icon,
                                size: 22,
                                color: sel ? Colors.white : t.color),
                            const SizedBox(height: 6),
                            Text(t.label,
                                style: TextStyle(
                                    color:
                                        sel ? Colors.white : t.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 26),
                _sheetSectionLabel('Feature Access'),
                const SizedBox(height: 4),
                const Text(
                  'Toggle individual features on or off for this doctor.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // ── Feature toggles ──────────────────────────────────────────
                ..._kFeats.map((f) {
                  final enabled = config.featureEnabled(f.key);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: enabled
                          ? f.color.withValues(alpha: 0.05)
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: enabled
                            ? f.color.withValues(alpha: 0.2)
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: enabled
                              ? f.color.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(f.icon,
                            size: 18,
                            color: enabled
                                ? f.color
                                : Colors.grey.shade400),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(f.subtitle,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: enabled
                                        ? f.color
                                        : AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: enabled,
                        activeTrackColor: f.color,
                        onChanged: (v) => setLocal(() {
                          if (f.key == 'statistics') {
                            config = config.copyWith(statistics: v);
                          } else if (f.key == 'billing') {
                            config = config.copyWith(billing: v);
                          } else if (f.key == 'expenses') {
                            config = config.copyWith(expenses: v);
                          }
                        }),
                      ),
                    ]),
                  );
                }),

                const SizedBox(height: 26),
                // ── Doctor info ───────────────────────────────────────────────
                _sheetSectionLabel('Doctor Info'),
                const SizedBox(height: 10),
                _adminField(nameCtrl, 'Full Name', Icons.person_rounded),
                const SizedBox(height: 10),
                _adminField(specCtrl, 'Specialization', Icons.medical_services_rounded),

                const SizedBox(height: 26),
                // ── Account settings ──────────────────────────────────────────
                _sheetSectionLabel('Account Settings'),
                const SizedBox(height: 10),
                _adminToggleTile(
                  icon: Icons.power_settings_new_rounded,
                  color: const Color(0xFF2E7D32),
                  title: 'Account Enabled',
                  subtitle: 'Doctor can use the app',
                  value: config.isEnabled,
                  onChanged: (v) =>
                      setLocal(() => config = config.copyWith(isEnabled: v)),
                ),
                const SizedBox(height: 8),
                _adminToggleTile(
                  icon: Icons.search_rounded,
                  color: _kInk,
                  title: 'Show in Find a Doctor',
                  subtitle: 'Visible to patients searching for therapists',
                  value: config.showInSearch,
                  onChanged: (v) =>
                      setLocal(() => config = config.copyWith(showInSearch: v)),
                ),
                const SizedBox(height: 8),
                _adminToggleTile(
                  icon: Icons.home_work_rounded,
                  color: const Color(0xFF6A1B9A),
                  title: 'Allow Home Visits',
                  subtitle: 'Doctor can offer home visits & set a location',
                  value: config.allowHomeVisit,
                  onChanged: (v) =>
                      setLocal(() => config = config.copyWith(allowHomeVisit: v)),
                ),
                const SizedBox(height: 14),
                // Expiry date
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: config.expiresAt ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setLocal(() =>
                          config = config.copyWith(expiresAt: picked));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.event_rounded,
                          color: _kInk, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Account Expiry Date',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text(
                            config.expiresAt != null
                                ? '${config.expiresAt!.day}/${config.expiresAt!.month}/${config.expiresAt!.year}'
                                : 'No expiry set (tap to choose)',
                            style: TextStyle(
                                fontSize: 12,
                                color: config.expiresAt != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary),
                          ),
                        ]),
                      ),
                      if (config.expiresAt != null)
                        GestureDetector(
                          onTap: () => setLocal(
                              () => config = config.copyWith(expiresAt: null)),
                          child: const Icon(Icons.clear_rounded,
                              size: 18, color: AppColors.textSecondary),
                        ),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),
                // ── Dr. prefix ────────────────────────────────────────────────
                _sheetSectionLabel('Dr. Prefix'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Icon(
                        drPrefix
                            ? Icons.verified_rounded
                            : drPrefixReq == 'pending'
                                ? Icons.hourglass_top_rounded
                                : Icons.badge_outlined,
                        size: 16,
                        color: drPrefix
                            ? AppColors.success
                            : drPrefixReq == 'pending'
                                ? const Color(0xFFF57F17)
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        drPrefix
                            ? 'Enabled — "Dr." shown to patients'
                            : drPrefixReq == 'pending'
                                ? 'Pending doctor request'
                                : drPrefixReq == 'declined'
                                    ? 'Previously declined'
                                    : 'Not enabled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: drPrefix
                              ? AppColors.success
                              : drPrefixReq == 'pending'
                                  ? const Color(0xFFF57F17)
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: drPrefix
                              ? () async {
                                  final docId = doc['id'] as String;
                                  await _toggleDrPrefixDirect(docId, false);
                                  setLocal(() {
                                    drPrefix      = false;
                                    drPrefixReq   = 'declined';
                                  });
                                }
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                                color: drPrefix
                                    ? AppColors.error
                                    : AppColors.cardBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Disable',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: drPrefix
                              ? null
                              : () async {
                                  final docId = doc['id'] as String;
                                  final name =
                                      (doc['name'] as String?) ?? '';
                                  await _approveDrPrefix(docId, name);
                                  setLocal(() {
                                    drPrefix    = true;
                                    drPrefixReq = 'approved';
                                  });
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.success.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Enable',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ]),
                  ]),
                ),

                const SizedBox(height: 20),
                // ── Save ─────────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: saving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kSlate,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded,
                              size: 20),
                          label: const Text('Apply Changes',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            setLocal(() => saving = true);
                            final update = {
                              'name': nameCtrl.text.trim(),
                              'specialization': specCtrl.text.trim(),
                              'subscription': config.tier.name,
                              'features':     config.toFeaturesMap(),
                              'is_enabled':    config.isEnabled,
                              'show_in_search': config.showInSearch,
                              'allow_home_visit': config.allowHomeVisit,
                              'expires_at': config.expiresAt?.toIso8601String(),
                            };
                            if (!config.allowHomeVisit) {
                              update['offers_home_visit'] = false;
                            }
                            try {
                              await _supabase
                                  .from('users')
                                  .update(update)
                                  .eq('id', doc['id'] as String);
                            } catch (e) {
                              setLocal(() => saving = false);
                              if (mounted) {
                                _snack('Update failed: $e',
                                    color: AppColors.error);
                              }
                              return;
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _snack(
                                'Updated for ${nameCtrl.text.trim()}!',
                                color: AppColors.success);
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

  // ── Util ───────────────────────────────────────────────────────────────────

  // ── Dr. prefix approval ────────────────────────────────────────────────────

  Future<void> _approveDrPrefix(String doctorId, String name) async {
    await _supabase.from('users').update({
      'show_dr_prefix':    true,
      'dr_prefix_request': 'approved',
    }).eq('id', doctorId);
    if (mounted) _snack('"Dr." prefix approved for $name', color: AppColors.success);
  }

  Future<void> _declineDrPrefix(String doctorId, String name) async {
    await _supabase.from('users').update({
      'show_dr_prefix':    false,
      'dr_prefix_request': 'declined',
    }).eq('id', doctorId);
    if (mounted) _snack('Request declined for $name');
  }

  Future<void> _toggleDrPrefixDirect(String doctorId, bool enable) async {
    await _supabase.from('users').update({
      'show_dr_prefix':    enable,
      'dr_prefix_request': enable ? 'approved' : 'declined',
    }).eq('id', doctorId);
  }

  // ── Name change approval ───────────────────────────────────────────────────

  Future<void> _approveNameChange(String doctorId, String newName, String oldName) async {
    await _supabase.from('users').update({
      'name':                newName,
      'pending_name':        null,
      'name_change_request': null,
    }).eq('id', doctorId);
    if (mounted) _snack('Name changed to "$newName" for $oldName', color: AppColors.success);
  }

  Future<void> _declineNameChange(String doctorId, String name) async {
    await _supabase.from('users').update({
      'pending_name':        null,
      'name_change_request': 'declined',
    }).eq('id', doctorId);
    if (mounted) _snack('Name change declined for $name');
  }

  // ── Account-request approval ───────────────────────────────────────────────

  Future<void> _approveAccountRequestDialog(Map<String, dynamic> req) async {
    final hasDoctorate = (req['has_doctorate'] as bool?) ?? false;
    final specCtrl = TextEditingController(
      text: hasDoctorate ? 'Doctor of Physical Therapy' : 'Physical Therapist',
    );
    final passCtrl   = TextEditingController();
    bool  passHidden = true;
    bool  saving     = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Approve account request'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Creating account for ${req['therapist_name']} (${req['email']})',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passCtrl,
                  obscureText: passHidden,
                  decoration: InputDecoration(
                    labelText: 'Initial password *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(passHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setLocal(() => passHidden = !passHidden),
                    ),
                    helperText: 'Min 6 characters — share with the therapist',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (passCtrl.text.length < 6) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Password must be at least 6 characters'),
                        ));
                        return;
                      }
                      setLocal(() => saving = true);
                      Navigator.pop(ctx, true);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await _adminService.approveAccountRequest(
      requestId: req['id'] as String,
      name:      req['therapist_name'] as String,
      email:     req['email'] as String,
      password:  passCtrl.text,
      specialty: specCtrl.text.trim(),
    );
    specCtrl.dispose();
    passCtrl.dispose();
    if (!mounted) return;
    _snack(
      error == null
          ? 'Account created for ${req['therapist_name']}'
          : 'Error: $error',
      color: error == null ? AppColors.success : AppColors.error,
    );
  }

  Future<void> _declineAccountRequest(Map<String, dynamic> req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Decline request?'),
        content: Text(
            'Decline the account request from "${req['therapist_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await _adminService.declineAccountRequest(req['id'] as String);
    if (!mounted) return;
    _snack(
      error == null
          ? 'Request from ${req['therapist_name']} declined'
          : 'Error: $error',
      color: error == null ? null : AppColors.error,
    );
  }

  // ── Notifications tab ──────────────────────────────────────────────────────

  Widget _notificationsTab() {
    // Outer stream: pending account requests (new therapist sign-up requests).
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('account_requests')
          .stream(primaryKey: ['id'])
          .eq('status', 'pending')
          .order('created_at', ascending: true),
      builder: (context, accountSnap) {
        // Inner stream: existing doctor prefix / name-change requests.
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase
              .from('users')
              .stream(primaryKey: ['id'])
              .eq('role', 'doctor'),
          builder: (context, usersSnap) {
            if (!accountSnap.hasData && !usersSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final accountRequests = accountSnap.data ?? [];
            final allDoctors      = usersSnap.data ?? [];
            final drPending   = allDoctors.where((d) =>
                (d['dr_prefix_request']   as String?) == 'pending').toList();
            final namePending = allDoctors.where((d) =>
                (d['name_change_request'] as String?) == 'pending').toList();

            if (accountRequests.isEmpty &&
                drPending.isEmpty &&
                namePending.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_none_rounded,
                        size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text('No pending requests',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  const Text(
                      'Account, Dr. prefix and name change requests will appear here',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ]),
              );
            }

            // Build a flat list: account requests first, then name/prefix.
            final items = <_NotifItem>[];
            if (accountRequests.isNotEmpty) {
              items.add(_NotifItem.header('Account Requests'));
              for (final r in accountRequests) {
                items.add(_NotifItem.accountRequest(r));
              }
            }
            if (namePending.isNotEmpty) {
              items.add(_NotifItem.header('Name Change Requests'));
              for (final d in namePending) { items.add(_NotifItem.nameChange(d)); }
            }
            if (drPending.isNotEmpty) {
              items.add(_NotifItem.header('Dr. Prefix Requests'));
              for (final d in drPending) { items.add(_NotifItem.drPrefix(d)); }
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];

                // ── Section header ──────────────────────────────────────────
                if (item.isHeader) {
                  return Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 10),
                    child: Text(item.headerTitle!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  );
                }

                final d = item.data!;

                // ── Account request card ────────────────────────────────────
                if (item.type == _NotifType.accountRequest) {
                  final reqName  = (d['therapist_name'] as String? ?? 'Unknown');
                  final reqEmail = (d['email']          as String? ?? '');
                  final reqPhone = (d['phone_number']   as String? ?? '');
                  final hasDpt   = (d['has_doctorate']  as bool?) ?? false;
                  final ac       = _avatarColor(reqName);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8EAED)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: ac.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(_initials(reqName),
                                    style: TextStyle(
                                        color: ac,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(reqName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.textPrimary)),
                                  Text(reqEmail,
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
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Pending',
                                  style: TextStyle(
                                      color: Color(0xFFF57F17),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          // Details row: phone + doctorate badge
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (reqPhone.isNotEmpty)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.phone_outlined,
                                      size: 13,
                                      color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(reqPhone,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ]),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasDpt
                                      ? const Color(0xFFE3F2FD)
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  hasDpt ? 'DPT' : 'No DPT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: hasDpt
                                        ? const Color(0xFF1565C0)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _declineAccountRequest(d),
                                icon: const Icon(Icons.close_rounded, size: 16),
                                label: const Text('Decline'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _approveAccountRequestDialog(d),
                                icon: const Icon(Icons.person_add_rounded,
                                    size: 16),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  );
                }

                // ── Dr. prefix / name-change card (existing logic) ──────────
                final id   = d['id'] as String;
                final name = (d['name'] as String? ?? 'Unknown');
                final spec = (d['specialization'] ?? '') as String;
                final ac   = _avatarColor(name);
                final isNameChange = item.type == _NotifType.nameChange;
                final pendingName =
                    isNameChange ? (d['pending_name'] as String? ?? '') : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8EAED)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: ac.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(_initials(name),
                                  style: TextStyle(
                                      color: ac,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary)),
                                if (spec.isNotEmpty)
                                  Text(spec,
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
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Pending',
                                style: TextStyle(
                                    color: Color(0xFFF57F17),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          isNameChange
                              ? 'Requesting name change to "$pendingName"'
                              : 'Requesting permission to display "Dr." prefix',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => isNameChange
                                  ? _declineNameChange(id, name)
                                  : _declineDrPrefix(id, name),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Decline'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => isNameChange
                                  ? _approveNameChange(id, pendingName, name)
                                  : _approveDrPrefix(id, name),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _adminField(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: _kSlate),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _adminToggleTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? color.withValues(alpha: 0.05)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value
                  ? color.withValues(alpha: 0.25)
                  : AppColors.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: value
                  ? color.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 18,
                color: value ? color : Colors.grey.shade400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: value ? color : AppColors.textSecondary)),
            ]),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: color,
            onChanged: onChanged,
          ),
        ]),
      );

  // ════════════════════════════════════════════════════════════════════════════
  // Build
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(children: [
        _header(),
        _navBar(),
        Expanded(
          child: switch (_currentIndex) {
            0 => _overviewTab(),
            1 => _doctorsTab(),
            2 => _polyclinicsTab(),
            3 => _registerTab(),
            4 => _notificationsTab(),
            5 => _patientsTab(),
            _ => _notesTab(),
          },
        ),
      ]),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kSlate, _kInk],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 18),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Admin Portal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text('PhysioConnect',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 20),
              color: Colors.white.withValues(alpha: 0.8),
              tooltip: 'Sign Out',
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _navBar() {
    return Container(
      color: _kSlate,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var i = 0; i < _kAdminNavItems.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _navButton(i, _kAdminNavItems[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(int index, _NavItem item) {
    final selected = _currentIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? Colors.white : Colors.white24),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(item.icon,
                size: 16,
                color: selected ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(item.label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: selected ? Colors.white : Colors.white38)),
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Overview Tab
  // ════════════════════════════════════════════════════════════════════════════

  Widget _overviewTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'doctor'),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: AppColors.error)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snap.data!;
        int basic = 0, premium = 0;
        for (final d in all) {
          final tier = (d['subscription'] as String?) ?? 'basic';
          if (tier == 'premium') { premium++; }
          else                   { basic++;   }
        }

        // recent 5
        final recent = List<Map<String, dynamic>>.from(all)
          ..sort((a, b) {
            final ta = a['created_at'] as String?;
            final tb = b['created_at'] as String?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        final latest = recent.take(5).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Stat cards ─────────────────────────────────────────────────
            Row(children: [
              Expanded(child: _kpiCard(
                  all.length.toString(), 'Total Doctors',
                  Icons.people_rounded, _kSlate)),
              const SizedBox(width: 10),
              Expanded(child: _kpiCard(
                  basic.toString(), 'Basic',
                  Icons.star_border_rounded, SubTier.basic.color)),
            ]),
            const SizedBox(height: 10),
            _kpiCard(premium.toString(), 'Premium',
                Icons.star_rounded, SubTier.premium.color),

            const SizedBox(height: 24),

            // ── Feature summary ────────────────────────────────────────────
            _overviewSectionLabel('Feature Distribution'),
            const SizedBox(height: 12),
            ..._kFeats.map((f) {
              final count = all.where((d) {
                final feats = (d['features'] as Map<String, dynamic>?) ?? {};
                return feats[f.key] as bool? ?? false;
              }).length;
              final pct = all.isEmpty ? 0.0 : count / all.length;
              return _featureBar(f, count, all.length, pct);
            }),

            const SizedBox(height: 24),

            // ── Recent registrations ───────────────────────────────────────
            _overviewSectionLabel('Recent Registrations'),
            const SizedBox(height: 12),
            if (latest.isEmpty)
              _emptyCard('No doctors registered yet.')
            else
              ...latest.map((d) => _recentRow(d)),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1)),
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _featureBar(_FeatDef f, int count, int total, double pct) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: f.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(f.icon, size: 16, color: f.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(f.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Text('$count / $total',
              style: TextStyle(
                  color: f.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: const Color(0xFFE8EAED),
            valueColor: AlwaysStoppedAnimation(f.color),
          ),
        ),
      ]),
    );
  }

  Widget _recentRow(Map<String, dynamic> doc) {
    final data  = doc;
    final name  = (data['name']  ?? 'Unknown') as String;
    final email = (data['email'] ?? '')         as String;
    final tier  = SubTier.values.firstWhere(
      (t) => t.name == ((data['subscription'] as String?) ?? 'basic'),
      orElse: () => SubTier.basic,
    );
    final ac = _avatarColor(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: ac.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(_initials(name),
                style: TextStyle(
                    color: ac,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
              Text(email,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tier.bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(tier.icon, size: 10, color: tier.color),
            const SizedBox(width: 3),
            Text(tier.label,
                style: TextStyle(
                    fontSize: 10,
                    color: tier.color,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _overviewSectionLabel(String label) {
    return Row(children: [
      Container(
        width: 3, height: 16,
        decoration: BoxDecoration(
          color: _kSlate, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
    ]);
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Text(msg,
          style: const TextStyle(color: AppColors.textSecondary)),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Doctors Tab
  // ════════════════════════════════════════════════════════════════════════════

  Widget _doctorsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'doctor'),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: AppColors.error)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = List<Map<String, dynamic>>.from(snap.data!)
          ..sort((a, b) {
            final ta = a['created_at'] as String?;
            final tb = b['created_at'] as String?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });

        final filtered = _searchQuery.isEmpty
            ? all
            : all.where((d) {
                final n  = (d['name']  ?? '').toString().toLowerCase();
                final e  = (d['email'] ?? '').toString().toLowerCase();
                final sp = (d['specialization'] ?? d['specialty'] ?? '')
                    .toString().toLowerCase();
                return n.contains(_searchQuery) ||
                    e.contains(_searchQuery) ||
                    sp.contains(_searchQuery);
              }).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(children: [
                  _doctorsSummaryCard(all.length),
                  const SizedBox(height: 14),
                  _searchField(),
                  const SizedBox(height: 10),
                  if (filtered.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filtered.length} doctor${filtered.length != 1 ? 's' : ''}'
                        '${_searchQuery.isNotEmpty ? ' found' : ''}',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12),
                      ),
                    ),
                ]),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(child: _emptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _doctorCard(filtered[i]),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _doctorsSummaryCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kSlate, _kInk],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.people_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$total',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1)),
              Text('Doctor${total != 1 ? 's' : ''} Registered',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _currentIndex = 3),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('New',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _doctorCard(Map<String, dynamic> doc) {
    final data      = doc;
    final name      = (data['name']  ?? 'Unknown') as String;
    final email     = (data['email'] ?? '')         as String;
    final spec      = (data['specialization'] ?? data['specialty'] ?? '') as String;
    final tier      = (data['subscription'] as String?) == 'premium'
        ? SubTier.premium : SubTier.basic;
    final featMap   = (data['features'] as Map<String, dynamic>?) ?? {};
    final isEnabled = (data['is_enabled'] as bool?) ?? true;
    final showSearch = (data['show_in_search'] as bool?) ?? true;
    final ac        = _avatarColor(name);

    // Expiry date
    final expiresTs  = data['expires_at'] as String?;
    final expiresDate = expiresTs != null ? DateTime.tryParse(expiresTs) : null;
    final now         = DateTime.now();
    final isExpired   = expiresDate != null && expiresDate.isBefore(now);
    final expiresSoon = expiresDate != null &&
        !isExpired &&
        expiresDate.isBefore(now.add(const Duration(days: 30)));
    String expiryLabel = 'No expiry';
    Color  expiryColor = AppColors.textSecondary;
    if (expiresDate != null) {
      expiryLabel = isExpired
          ? 'Expired ${_fmtDate(expiresTs)}'
          : 'Expires ${_fmtDate(expiresTs)}';
      expiryColor = isExpired
          ? AppColors.error
          : expiresSoon
              ? const Color(0xFFF57F17)
              : const Color(0xFF2E7D32);
    }

    final bool isActive = isEnabled && !isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? AppColors.error.withValues(alpha: 0.3)
              : const Color(0xFFE8EAED),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openManageSheet(doc),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // ── Top row ────────────────────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Avatar
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: ac.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(_initials(name),
                        style: TextStyle(
                            color: ac,
                            fontWeight: FontWeight.bold,
                            fontSize: 17)),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + email + spec
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(email,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                      if (spec.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: ac.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(spec,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: ac,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textSecondary, size: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'manage') {
                      _openManageSheet(doc);
                    } else if (v == 'delete') {
                      _confirmDelete(doc['id'] as String, name);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'manage',
                      child: Row(children: [
                        Icon(Icons.manage_accounts_rounded,
                            color: _kSlate, size: 18),
                        SizedBox(width: 10),
                        Text('Manage Account'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_rounded,
                              color: AppColors.error, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text('Remove Account',
                            style: TextStyle(color: AppColors.error)),
                      ]),
                    ),
                  ],
                ),
              ]),

              // ── Status bar ─────────────────────────────────────────────
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isExpired
                      ? const Color(0xFFFFEBEE)
                      : isActive
                          ? const Color(0xFFF0FFF4)
                          : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isExpired
                        ? AppColors.error.withValues(alpha: 0.2)
                        : isActive
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.2)
                            : Colors.grey.shade200,
                  ),
                ),
                child: Row(children: [
                  // Plan badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tier.bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(tier.icon, size: 10, color: tier.color),
                      const SizedBox(width: 3),
                      Text(tier.label,
                          style: TextStyle(
                              fontSize: 10,
                              color: tier.color,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  // Expiry date
                  Icon(
                    isExpired
                        ? Icons.timer_off_rounded
                        : Icons.event_rounded,
                    size: 12,
                    color: expiryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      expiryLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: expiryColor),
                    ),
                  ),
                  // Account status chips
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isExpired
                          ? 'Expired'
                          : isEnabled
                              ? 'Active'
                              : 'Disabled',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? const Color(0xFF2E7D32)
                              : AppColors.error),
                    ),
                  ),
                  if (showSearch && tier == SubTier.premium) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kInk.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Searchable',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _kInk)),
                    ),
                  ],
                ]),
              ),

              // ── Feature mini-chips ─────────────────────────────────────
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: _kFeats.map((f) {
                    final on = featMap[f.key] as bool? ?? false;
                    return Expanded(
                      child: Column(children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: on
                                ? f.color.withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(f.icon,
                              size: 14,
                              color: on
                                  ? f.color
                                  : Colors.grey.shade400),
                        ),
                        const SizedBox(height: 3),
                        Text(f.label,
                            style: TextStyle(
                                fontSize: 9,
                                color: on
                                    ? f.color
                                    : Colors.grey.shade400,
                                fontWeight: FontWeight.w500)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Register Tab
  // ════════════════════════════════════════════════════════════════════════════

  Widget _registerTab() {
    final isPolyclinic = _isPolyclinic;
    final accentColor  = isPolyclinic ? const Color(0xFF00695C) : _kSlate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Type selector ───────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPolyclinic = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: !isPolyclinic ? _kSlate : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: !isPolyclinic ? _kSlate : AppColors.cardBorder),
                  ),
                  child: Column(children: [
                    Icon(Icons.person_rounded,
                        size: 22,
                        color: !isPolyclinic ? Colors.white : _kSlate),
                    const SizedBox(height: 4),
                    Text('Doctor',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !isPolyclinic ? Colors.white : _kSlate)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPolyclinic = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isPolyclinic ? const Color(0xFF00695C) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isPolyclinic
                            ? const Color(0xFF00695C)
                            : AppColors.cardBorder),
                  ),
                  child: Column(children: [
                    Icon(Icons.business_rounded,
                        size: 22,
                        color: isPolyclinic ? Colors.white : const Color(0xFF00695C)),
                    const SizedBox(height: 4),
                    Text('Polyclinic',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isPolyclinic
                                ? Colors.white
                                : const Color(0xFF00695C))),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.12)),
            ),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                    isPolyclinic
                        ? Icons.business_rounded
                        : Icons.person_add_rounded,
                    color: accentColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isPolyclinic
                            ? 'Register New Polyclinic'
                            : 'Register New Doctor',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                        isPolyclinic
                            ? 'Polyclinic accounts can link doctors and view per-doctor income.'
                            : 'New accounts start on the Basic plan. Upgrade via the Doctors tab.',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),

          // Form card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _formSection(isPolyclinic ? 'Clinic Info' : 'Personal Info'),
                const SizedBox(height: 14),
                _field(_nameCtrl,
                    isPolyclinic ? 'Clinic Name' : 'Doctor Full Name',
                    isPolyclinic ? Icons.business_rounded : Icons.badge_rounded),
                if (!isPolyclinic) ...[
                  const SizedBox(height: 12),
                  _field(_specCtrl, 'Specialization',
                      Icons.medical_services_rounded),
                ],
                const SizedBox(height: 22),
                _formSection('Login Credentials'),
                const SizedBox(height: 14),
                _field(_emailCtrl,
                    isPolyclinic ? 'Clinic Email' : 'Professional Email',
                    Icons.email_rounded,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Initial Password (min 6 chars)',
                    prefixIcon: const Icon(Icons.lock_rounded,
                        color: _kSlate, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _processing
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded,
                              size: 20),
                          label: Text(
                              isPolyclinic
                                  ? 'Create Polyclinic Account'
                                  : 'Create Doctor Account',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          onPressed: isPolyclinic
                              ? _registerPolyclinic
                              : _registerDoctor,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Register Polyclinic ────────────────────────────────────────────────────

  Future<void> _registerPolyclinic() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (name.isEmpty || email.isEmpty || pass.length < 6) {
      _snack('Fill all fields. Password must be at least 6 characters.');
      return;
    }
    setState(() => _processing = true);
    final error = await _adminService.createPolyclinicAccount(
      name: name, email: email, password: pass,
    );
    if (!mounted) return;
    if (error == null) {
      _snack('Polyclinic account created!', color: AppColors.success);
      _nameCtrl.clear(); _emailCtrl.clear(); _passCtrl.clear();
      setState(() => _currentIndex = 2);
    } else {
      _snack('Error: $error', color: AppColors.error);
    }
    setState(() => _processing = false);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Polyclinics Tab
  // ════════════════════════════════════════════════════════════════════════════

  Widget _polyclinicsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'polyclinic'),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: AppColors.error)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = List<Map<String, dynamic>>.from(snap.data!)
          ..sort((a, b) {
            final ta = a['created_at'] as String?;
            final tb = b['created_at'] as String?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });

        final filtered = _polySearchQuery.isEmpty
            ? all
            : all.where((d) {
                final n = (d['name']  ?? '').toString().toLowerCase();
                final e = (d['email'] ?? '').toString().toLowerCase();
                return n.contains(_polySearchQuery) ||
                    e.contains(_polySearchQuery);
              }).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(children: [
                  _polyclinicsSummaryCard(all.length),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) =>
                        setState(() => _polySearchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search polyclinic name or email...',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          '${filtered.length} polyclinic${filtered.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                ]),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                          color: const Color(0xFF00695C).withValues(alpha: 0.07),
                          shape: BoxShape.circle),
                      child: Icon(Icons.business_outlined,
                          size: 36,
                          color: const Color(0xFF00695C).withValues(alpha: 0.35)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        _polySearchQuery.isEmpty
                            ? 'No polyclinic accounts yet'
                            : 'No results for "$_polySearchQuery"',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(
                        _polySearchQuery.isEmpty
                            ? 'Use the Register tab to add a polyclinic.'
                            : 'Try a different search term.',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _polyclinicCard(filtered[i]),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _polyclinicsSummaryCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00695C), Color(0xFF004D40)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.business_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$total',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1)),
            Text('Polyclinic${total != 1 ? 's' : ''} Registered',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          ]),
        ),
        GestureDetector(
          onTap: () => setState(() => _currentIndex = 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('New',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _polyclinicCard(Map<String, dynamic> doc) {
    final data      = doc;
    final name      = (data['name']  ?? 'Unknown') as String;
    final email     = (data['email'] ?? '')         as String;
    final isEnabled = (data['is_enabled'] as bool?)  ?? true;
    final linkedIds = (data['linked_doctor_ids'] as List?)?.length ?? 0;
    final ac        = _avatarColor(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openPolyclinicManageSheet(doc),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: ac.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(_initials(name),
                      style: TextStyle(
                          color: ac,
                          fontWeight: FontWeight.bold,
                          fontSize: 17)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(email,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          isEnabled ? 'Active' : 'Disabled',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isEnabled
                                  ? const Color(0xFF2E7D32)
                                  : AppColors.error)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.people_outline_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('$linkedIds linked doctor${linkedIds != 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ]),
                ]),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textSecondary, size: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'manage') _openPolyclinicManageSheet(doc);
                  if (v == 'delete') _confirmDeletePolyclinic(doc['id'] as String, name);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'manage',
                    child: Row(children: [
                      Icon(Icons.manage_accounts_rounded,
                          color: _kSlate, size: 18),
                      SizedBox(width: 10),
                      Text('Manage Account'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.delete_rounded,
                            color: AppColors.error, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text('Remove Account',
                          style: TextStyle(color: AppColors.error)),
                    ]),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePolyclinic(String docId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.delete_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Remove Polyclinic'),
        ]),
        content: Text(
            'Remove "$name" from the system?\nThis action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _adminService.deleteUserAccount(docId);
    if (!mounted) return;
    _snack(err == null ? 'Polyclinic account removed.' : 'Error: $err',
        color: err == null ? null : AppColors.error);
  }

  void _openPolyclinicManageSheet(Map<String, dynamic> doc) {
    final data      = doc;
    final ac        = _avatarColor((data['name'] ?? '') as String);
    final nameCtrl  = TextEditingController(
        text: data['name'] as String? ?? '');
    bool isEnabled  = (data['is_enabled'] as bool?) ?? true;
    bool saving     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                        color: ac.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(15)),
                    child: Center(
                      child: Text(_initials(nameCtrl.text),
                          style: TextStyle(
                              color: ac,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(nameCtrl.text,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text((data['email'] as String?) ?? '',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF00695C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Polyclinic',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF00695C),
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 24),
                _sheetSectionLabel('Clinic Info'),
                const SizedBox(height: 10),
                _adminField(nameCtrl, 'Clinic Name', Icons.business_rounded),
                const SizedBox(height: 24),
                _sheetSectionLabel('Account Settings'),
                const SizedBox(height: 10),
                _adminToggleTile(
                  icon: Icons.power_settings_new_rounded,
                  color: const Color(0xFF2E7D32),
                  title: 'Account Enabled',
                  subtitle: 'Polyclinic can use the app',
                  value: isEnabled,
                  onChanged: (v) => setLocal(() => isEnabled = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: saving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00695C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: const Text('Apply Changes',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            setLocal(() => saving = true);
                            await _supabase.from('users').update({
                              'name':       nameCtrl.text.trim(),
                              'is_enabled': isEnabled,
                            }).eq('id', doc['id'] as String);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _snack('Updated for ${nameCtrl.text.trim()}!',
                                color: AppColors.success);
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

  // ════════════════════════════════════════════════════════════════════════════
  // Patients Tab
  // ════════════════════════════════════════════════════════════════════════════

  Widget _patientsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'patient'),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: AppColors.error)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = List<Map<String, dynamic>>.from(snap.data!)
          ..sort((a, b) {
            final ta = a['created_at'] as String?;
            final tb = b['created_at'] as String?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });

        final filtered = _patientSearchQuery.isEmpty
            ? all
            : all.where((d) {
                final n = (d['name']  ?? '').toString().toLowerCase();
                final e = (d['email'] ?? '').toString().toLowerCase();
                return n.contains(_patientSearchQuery) ||
                    e.contains(_patientSearchQuery);
              }).toList();

        final dupGroups = _findDuplicatePatientGroups(all);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(children: [
                  _patientsSummaryCard(all.length),
                  if (dupGroups.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _duplicatePatientsCard(dupGroups),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) =>
                        setState(() => _patientSearchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search patient name or email...',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isNotEmpty)
                    Row(children: [
                      Text(
                          '${filtered.length} patient${filtered.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const Spacer(),
                      if (_selectedPatientIds.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _confirmDeleteSelectedPatients(),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16, color: AppColors.error),
                          label: Text(
                              'Delete (${_selectedPatientIds.length})',
                              style: const TextStyle(color: AppColors.error, fontSize: 12)),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                      TextButton(
                        onPressed: () => setState(() {
                          if (_selectedPatientIds.length == filtered.length) {
                            _selectedPatientIds.clear();
                          } else {
                            _selectedPatientIds
                              ..clear()
                              ..addAll(filtered.map((p) => p['id'] as String));
                          }
                        }),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: Text(
                            _selectedPatientIds.length == filtered.length
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ]),
                ]),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.07),
                          shape: BoxShape.circle),
                      child: Icon(Icons.personal_injury_outlined,
                          size: 36,
                          color: const Color(0xFF1565C0).withValues(alpha: 0.35)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        _patientSearchQuery.isEmpty
                            ? 'No patient accounts yet'
                            : 'No results for "$_patientSearchQuery"',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(
                        _patientSearchQuery.isEmpty
                            ? 'Patients appear here once they register.'
                            : 'Try a different search term.',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final id = filtered[i]['id'] as String;
                      return _patientCard(
                        filtered[i],
                        isSelected: _selectedPatientIds.contains(id),
                        onToggle: () => setState(() {
                          if (_selectedPatientIds.contains(id)) {
                            _selectedPatientIds.remove(id);
                          } else {
                            _selectedPatientIds.add(id);
                          }
                        }),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Possible duplicates card ─────────────────────────────────────────────────

  Widget _duplicatePatientsCard(List<List<Map<String, dynamic>>> groups) {
    final totalRows = groups.fold<int>(0, (sum, g) => sum + g.length);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF9A825), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${groups.length} possible duplicate name'
              '${groups.length != 1 ? 's' : ''} ($totalRows records)',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ...groups.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                  child: Text(
                    '${(g.first['name'] ?? '') as String} (${g.length})',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => _openMergeDuplicatesSheet(g),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10)),
                  child: const Text('Review'),
                ),
              ]),
            )),
      ]),
    );
  }

  // ── Merge duplicate patients sheet ──────────────────────────────────────────

  void _openMergeDuplicatesSheet(List<Map<String, dynamic>> group) {
    final sorted = List<Map<String, dynamic>>.from(group)
      ..sort((a, b) => ((a['created_at'] as String?) ?? '')
          .compareTo((b['created_at'] as String?) ?? ''));
    // Default to keeping the oldest record — most likely to have a linked login.
    String canonicalId = sorted.first['id'] as String;
    bool merging = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text('Merge Duplicate Patients',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                  'Pick the record to keep. Appointments, notes, invoices, '
                  'messages and doctor links from the others will be moved '
                  'onto it, and the duplicate records removed.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                ...sorted.map((p) {
                  final id    = p['id'] as String;
                  final name  = (p['name']  ?? '') as String;
                  final email = (p['email'] ?? '') as String;
                  final phone = (p['phone'] ?? '') as String;
                  final ac    = _avatarColor(name);
                  final selected = id == canonicalId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: merging
                          ? null
                          : () => setLocal(() => canonicalId = id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF1565C0).withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: selected
                                  ? const Color(0xFF1565C0)
                                  : const Color(0xFFE8EAED),
                              width: selected ? 1.5 : 1),
                        ),
                        child: Row(children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected
                                ? const Color(0xFF1565C0)
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: ac.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Center(
                              child: Text(_initials(name),
                                  style: TextStyle(
                                      color: ac,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textPrimary)),
                                if (email.isNotEmpty)
                                  Text(email,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12)),
                                if (phone.isNotEmpty)
                                  Text(phone,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12)),
                                Text('Added ${_fmtDateTime(p['created_at'] as String?)}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: merging
                        ? null
                        : () async {
                            final keep = sorted
                                .firstWhere((p) => p['id'] == canonicalId);
                            final others = sorted
                                .where((p) => p['id'] != canonicalId)
                                .toList();
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: const Text('Merge Patients?'),
                                content: Text(
                                    'Merge ${others.length} record'
                                    '${others.length != 1 ? 's' : ''} into '
                                    '"${keep['name']}"?\nThis cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1565C0),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Merge'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            setLocal(() => merging = true);
                            final err = await _adminService.mergePatients(
                              canonicalId: canonicalId,
                              duplicateIds:
                                  others.map((p) => p['id'] as String).toList(),
                            );
                            if (!ctx.mounted) return;
                            if (err == null) {
                              Navigator.pop(ctx);
                              _snack('Merged into "${keep['name']}".',
                                  color: AppColors.success);
                            } else {
                              setLocal(() => merging = false);
                              _snack('Merge failed: $err', color: AppColors.error);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: merging
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Merge ${sorted.length - 1} into selected'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _patientsSummaryCard(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.personal_injury_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$total',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1)),
            Text('Patient${total != 1 ? 's' : ''} Registered',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  Widget _patientCard(
    Map<String, dynamic> doc, {
    required bool isSelected,
    required VoidCallback onToggle,
  }) {
    final name  = (doc['name']  ?? 'Unknown') as String;
    final email = (doc['email'] ?? '')         as String;
    final phone = (doc['phone'] ?? '')         as String;
    final ac    = _avatarColor(name);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : const Color(0xFFE8EAED),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: ac.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(_initials(name),
                    style: TextStyle(
                        color: ac, fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.phone_rounded, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(phone,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ],
              ]),
            ),
            IconButton(
              onPressed: () => _confirmDeletePatient(doc['id'] as String, name),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 20),
              tooltip: 'Remove patient',
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSelectedPatients() async {
    final count = _selectedPatientIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.delete_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Remove Patients'),
        ]),
        content: Text(
            'Remove $count patient${count != 1 ? 's' : ''} from the system?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove All'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ids = Set<String>.from(_selectedPatientIds);
    setState(() => _selectedPatientIds.clear());
    int failed = 0;
    for (final id in ids) {
      final err = await _adminService.deleteUserAccount(id);
      if (err != null) failed++;
    }
    if (!mounted) return;
    _snack(
      failed == 0
          ? 'Removed ${ids.length} patient${ids.length != 1 ? 's' : ''}.'
          : '$failed deletion${failed != 1 ? 's' : ''} failed.',
      color: failed == 0 ? null : AppColors.error,
    );
  }

  Future<void> _confirmDeletePatient(String patientId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.delete_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Remove Patient'),
        ]),
        content: Text(
            'Remove "$name" from the system?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await _adminService.deleteUserAccount(patientId);
    if (!mounted) return;
    _snack(err == null ? 'Patient account removed.' : 'Error: $err',
        color: err == null ? null : AppColors.error);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Notes Tab (broadcast a note to one or more doctors)
  // ════════════════════════════════════════════════════════════════════════════

  Widget _notesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'doctor'),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: AppColors.error)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final doctors = List<Map<String, dynamic>>.from(snap.data!)
          ..sort((a, b) => ((a['name'] ?? '') as String)
              .compareTo((b['name'] ?? '') as String));
        final doctorIds = doctors.map((d) => d['id'] as String).toSet();
        _noteSelectedDoctorIds.removeWhere((id) => !doctorIds.contains(id));
        final allSelected =
            doctors.isNotEmpty && _noteSelectedDoctorIds.length == doctors.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _formSection('Send a Note to Doctors'),
              const SizedBox(height: 14),
              TextField(
                controller: _noteTitleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.title_rounded,
                      color: _kSlate, size: 20),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kSlate, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteBodyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kSlate, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                _sheetSectionLabel('Send To'),
                const Spacer(),
                TextButton(
                  onPressed: doctors.isEmpty
                      ? null
                      : () => setState(() {
                            if (allSelected) {
                              _noteSelectedDoctorIds.clear();
                            } else {
                              _noteSelectedDoctorIds
                                ..clear()
                                ..addAll(doctorIds);
                            }
                          }),
                  child: Text(allSelected ? 'Deselect All' : 'Select All'),
                ),
              ]),
              const SizedBox(height: 8),
              if (doctors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No doctors registered yet.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: doctors.map((d) {
                      final id = d['id'] as String;
                      final name = (d['name'] ?? 'Unknown') as String;
                      final email = (d['email'] ?? '') as String;
                      return CheckboxListTile(
                        value: _noteSelectedDoctorIds.contains(id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _noteSelectedDoctorIds.add(id);
                          } else {
                            _noteSelectedDoctorIds.remove(id);
                          }
                        }),
                        title: Text(name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: email.isNotEmpty
                            ? Text(email, style: const TextStyle(fontSize: 12))
                            : null,
                        activeColor: _kSlate,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _noteSending
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _noteSelectedDoctorIds.isEmpty
                            ? null
                            : _sendAdminNote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kSlate,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 20),
                        label: const Text('Send',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendAdminNote() async {
    final title = _noteTitleCtrl.text.trim();
    final body  = _noteBodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack('Please enter a title and message.', color: AppColors.error);
      return;
    }
    if (_noteSelectedDoctorIds.isEmpty) {
      _snack('Select at least one doctor.', color: AppColors.error);
      return;
    }
    setState(() => _noteSending = true);
    final recipients = _noteSelectedDoctorIds.toList();
    final now = DateTime.now().toIso8601String();
    try {
      await _supabase.from('notifications').insert([
        for (final doctorId in recipients)
          {
            'recipient_id': doctorId,
            'recipient_type': 'doctor',
            'type': 'admin_note',
            'title': title,
            'body': body,
            'read': false,
            'created_at': now,
          },
      ]);
      if (!mounted) return;
      setState(() {
        _noteSending = false;
        _noteTitleCtrl.clear();
        _noteBodyCtrl.clear();
        _noteSelectedDoctorIds.clear();
      });
      _snack('Note sent to ${recipients.length} doctor${recipients.length != 1 ? 's' : ''}.',
          color: AppColors.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _noteSending = false);
      _snack('Error: $e', color: AppColors.error);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Shared helpers
  // ════════════════════════════════════════════════════════════════════════════

  Widget _searchField() {
    return TextField(
      onChanged: (v) =>
          setState(() => _searchQuery = v.toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search name, email or specialization...',
        hintStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _kSlate, width: 1.5),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: _kSlate.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_outline_rounded,
                size: 36, color: _kSlate.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No doctor accounts yet'
                : 'No results for "$_searchQuery"',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isEmpty
                ? 'Use the Register tab to add a doctor.'
                : 'Try a different search term.',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _formSection(String label) {
    return Row(children: [
      Container(
        width: 3, height: 16,
        decoration: BoxDecoration(
          color: _kSlate, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kSlate,
              letterSpacing: 0.3)),
    ]);
  }

  Widget _sheetSectionLabel(String label) {
    return Row(children: [
      Container(
        width: 3, height: 16,
        decoration: BoxDecoration(
          color: _kSlate, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
    ]);
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _kSlate, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kSlate, width: 2),
        ),
      ),
    );
  }
}
