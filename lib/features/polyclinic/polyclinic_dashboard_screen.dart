// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants/app_colors.dart';

// Unified teal brand — all polyclinic UI derives from these two tokens
const _kTeal = AppColors.primary;      // 0xFF00897B
const _kNavy = AppColors.primaryDark;  // 0xFF005B4F
const _kBlue = AppColors.primary;      // same teal, no more competing blue

// ── tiny helpers ─────────────────────────────────────────────────────────────

Color _avatarColor(String name) {
  const pal = [
    Color(0xFF5C6BC0), Color(0xFF26A69A), Color(0xFF42A5F5),
    Color(0xFF66BB6A), Color(0xFFAB47BC), Color(0xFF26C6DA),
  ];
  if (name.isEmpty) return pal[0];
  return pal[name.codeUnits.fold(0, (a, b) => a + b) % pal.length];
}

String _initials(String name) {
  final p = name.trim().split(' ');
  return p.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
}

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════

class PolyclinicDashboardScreen extends StatefulWidget {
  const PolyclinicDashboardScreen({super.key});
  @override
  State<PolyclinicDashboardScreen> createState() =>
      _PolyclinicDashboardScreenState();
}

class _PolyclinicDashboardScreenState
    extends State<PolyclinicDashboardScreen> {
  final _supabase = Supabase.instance.client;
  String get _uid => Supabase.instance.client.auth.currentUser!.id;

  int _tab = 0;

  static const _tabs = [
    (icon: Icons.people_rounded,        label: 'Doctors'),
    (icon: Icons.person_rounded,        label: 'Patients'),
    (icon: Icons.receipt_long_rounded,  label: 'Income'),
    (icon: Icons.bar_chart_rounded,     label: 'Statistics'),
    (icon: Icons.badge_rounded,         label: 'Profile'),
  ];

  // ── Link / unlink doctor ───────────────────────────────────────────────────

  Future<void> _linkDoctor(String doctorUid) async {
    final myData = await _supabase.from('users').select('linked_doctor_ids').eq('id', _uid).single();
    final ids = List<String>.from((myData['linked_doctor_ids'] as List?) ?? []);
    if (!ids.contains(doctorUid)) ids.add(doctorUid);
    await _supabase.from('users').update({'linked_doctor_ids': ids}).eq('id', _uid);
    await _supabase.from('users').update({'polyclinic_id': _uid}).eq('id', doctorUid);
  }

  Future<void> _unlinkDoctor(String doctorUid) async {
    final myData = await _supabase.from('users').select('linked_doctor_ids').eq('id', _uid).single();
    final ids = List<String>.from((myData['linked_doctor_ids'] as List?) ?? []);
    ids.remove(doctorUid);
    await _supabase.from('users').update({'linked_doctor_ids': ids}).eq('id', _uid);
    await _supabase.from('users').update({'polyclinic_id': null}).eq('id', doctorUid);
  }

  // ── Show "add doctor" search sheet ────────────────────────────────────────

  void _showAddDoctorSheet(List<String> alreadyLinked) {
    String query = '';
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
              const Text('Add Doctor to Polyclinic',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (v) => set(() => query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search doctor name…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'doctor'),
                  builder: (_, snap) {
                    final all = snap.data ?? [];
                    final items = all.where((d) {
                      final n  = (d['name'] ?? '').toString().toLowerCase();
                      final e  = (d['email'] ?? '').toString().toLowerCase();
                      final alreadyHere = alreadyLinked.contains(d['id'] as String);
                      if (alreadyHere) return false;
                      if (query.isEmpty) return true;
                      return n.contains(query) || e.contains(query);
                    }).toList();

                    if (items.isEmpty) {
                      return const Center(
                          child: Text('No available doctors found.',
                              style: TextStyle(
                                  color: AppColors.textSecondary)));
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final d    = items[i];
                        final name = (d['name'] ?? d['email'] ?? '') as String;
                        final spec = (d['specialization'] ?? '') as String;
                        final ac   = _avatarColor(name);
                        return ListTile(
                          leading: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                                color: ac.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(11)),
                            child: Center(
                              child: Text(_initials(name),
                                  style: TextStyle(
                                      color: ac,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          title: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: spec.isNotEmpty ? Text(spec) : null,
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await _linkDoctor(items[i]['id'] as String);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('$name added to polyclinic'),
                                    backgroundColor: AppColors.success));
                            },
                            child: const Text('Add'),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase.from('users').stream(primaryKey: ['id']).eq('id', _uid),
        builder: (context, snap) {
          final clinicData = snap.data?.isNotEmpty == true ? snap.data!.first : <String, dynamic>{};
          final linkedIds  = List<String>.from(
              (clinicData['linked_doctor_ids'] as List?) ?? []);
          final clinicName = (clinicData['name'] ?? 'Polyclinic') as String;

          return Column(children: [
            _header(clinicName),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _buildDoctorsTab(linkedIds),
                  _buildPatientsTab(linkedIds),
                  _buildIncomeTab(linkedIds),
                  _buildStatsTab(linkedIds),
                  _buildProfileTab(clinicData),
                ],
              ),
            ),
          ]);
        },
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(String clinicName) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.business_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(clinicName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  Text('Polyclinic Dashboard',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
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

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _bottomNav() {
    return BottomNavigationBar(
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: _kTeal,
      unselectedItemColor: Colors.grey.shade500,
      selectedLabelStyle: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      items: _tabs
          .map((t) => BottomNavigationBarItem(
              icon: Icon(t.icon), label: t.label))
          .toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tab 0 – My Doctors
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDoctorsTab(List<String> linkedIds) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kTeal,
        foregroundColor: Colors.white,
        onPressed: () => _showAddDoctorSheet(linkedIds),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Doctor',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: linkedIds.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline_rounded,
                    size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No doctors linked yet',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 6),
                const Text('Tap "+ Add Doctor" to link a doctor.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ]),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('users').stream(primaryKey: ['id']).eq('polyclinic_id', _uid),
              builder: (context, snap) {
                final docs = snap.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _doctorCard(docs[i]),
                );
              },
            ),
    );
  }

  Widget _doctorCard(Map<String, dynamic> doc) {
    final d    = doc;
    final name = (d['name'] ?? d['email'] ?? 'Doctor') as String;
    final spec = (d['specialization'] ?? '') as String;
    final ac   = _avatarColor(name);

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
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: ac.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13)),
            child: Center(
              child: Text(_initials(name),
                  style: TextStyle(
                      color: ac, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 4),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'patient')
                    .map((list) => list.where((u) {
                          final ids = (u['doctor_ids'] as List?)?.cast<String>() ?? [];
                          return ids.contains(doc['id'] as String);
                        }).toList()),
                builder: (_, ps) {
                  final cnt = ps.data?.length ?? 0;
                  return Text('$cnt patient${cnt != 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary));
                },
              ),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'unlink') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Remove Doctor'),
                    content: Text(
                        'Remove "$name" from this polyclinic?'),
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
                await _unlinkDoctor(doc['id'] as String);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'unlink',
                child: Row(children: [
                  Icon(Icons.link_off_rounded,
                      color: AppColors.error, size: 18),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Tab 1 – My Patients
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPatientsTab(List<String> linkedIds) {
    return _PatientsTab(linkedIds: linkedIds);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tab 2 – Income
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildIncomeTab(List<String> linkedIds) {
    return _IncomeTab(polyclinicUid: _uid, linkedIds: linkedIds);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tab 3 – Statistics
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatsTab(List<String> linkedIds) {
    return _StatsTab(linkedIds: linkedIds);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tab 4 – Profile
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileTab(Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(
        text: (data['name'] ?? '') as String);
    bool saving = false;

    return StatefulBuilder(
      builder: (context, set) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Clinic Profile',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EAED)),
            ),
            child: Column(children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Clinic Name',
                  prefixIcon: const Icon(Icons.business_rounded,
                      color: _kTeal, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: (data['email'] ?? '') as String,
                  prefixIcon: const Icon(Icons.email_rounded,
                      color: _kTeal, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Changes',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          set(() => saving = true);
                          await _supabase.from('users').update(
                              {'name': nameCtrl.text.trim()}).eq('id', _uid);
                          set(() => saving = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Profile updated'),
                                backgroundColor: AppColors.success));
                        },
                      ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Patients Tab Widget
// ═════════════════════════════════════════════════════════════════════════════

class _PatientsTab extends StatefulWidget {
  final List<String> linkedIds;
  const _PatientsTab({required this.linkedIds});
  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  String? _filterDoctorId;
  String  _search = '';

  @override
  Widget build(BuildContext context) {
    if (widget.linkedIds.isEmpty) {
      return const Center(
          child: Text('Link doctors first to see their patients.',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    final queryIds = _filterDoctorId != null
        ? [_filterDoctorId!]
        : widget.linkedIds;

    return Column(children: [
      // ── Doctor filter row ─────────────────────────────────────────────
      Container(
        color: _kNavy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('users')
                  .stream(primaryKey: ['id'])
                  .eq('polyclinic_id', Supabase.instance.client.auth.currentUser!.id),
              builder: (_, snap) {
                final doctors = snap.data ?? [];
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _filterDoctorId,
                    dropdownColor: _kNavy,
                    icon: const Icon(Icons.arrow_drop_down_rounded,
                        color: Colors.white),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Doctors',
                              style: TextStyle(color: Colors.white))),
                      ...doctors.map((d) {
                        final id = d['id'] as String;
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                              (d['name'] ?? id) as String,
                              style: const TextStyle(color: Colors.white)),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _filterDoctorId = v),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.white, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ]),
      ),
      // ── Patient list ──────────────────────────────────────────────────
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('users').stream(primaryKey: ['id']).eq('role', 'patient')
              .map((list) => list.where((u) {
                    final ids = (u['doctor_ids'] as List?)?.cast<String>() ?? [];
                    return queryIds.any((id) => ids.contains(id));
                  }).toList()),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snap.data!;
            final filtered = _search.isEmpty
                ? all
                : all.where((d) {
                    final dd = d;
                    final n  = (dd['name'] ?? '').toString().toLowerCase();
                    final p  = (dd['phone'] ?? '').toString().toLowerCase();
                    return n.contains(_search) || p.contains(_search);
                  }).toList();

            if (filtered.isEmpty) {
              return const Center(
                  child: Text('No patients found.',
                      style: TextStyle(color: AppColors.textSecondary)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final d    = filtered[i];
                final name = (d['name'] ?? d['email'] ?? 'Patient') as String;
                final phone = (d['phone'] ?? '') as String;
                final cond  = (d['primary_diagnosis'] ?? '') as String;
                final doctorId = (d['doctor_ids'] as List?)?.isNotEmpty == true
                    ? (d['doctor_ids'] as List).first as String
                    : null;
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
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                          color: ac.withValues(alpha: 0.12),
                          shape: BoxShape.circle),
                      child: Center(
                        child: Text(_initials(name),
                            style: TextStyle(
                                color: ac, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        if (phone.isNotEmpty)
                          Text(phone,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                        if (cond.isNotEmpty)
                          Text(cond,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                      ]),
                    ),
                    if (doctorId != null)
                      FutureBuilder<Map<String, dynamic>?>(
                        future: Supabase.instance.client
                            .from('users').select().eq('id', doctorId).maybeSingle(),
                        builder: (_, ds) {
                          final dn = ds.data != null
                              ? ds.data!['name']?.toString() ?? 'Dr.'
                              : 'Dr.';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: _kTeal.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(dn,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: _kTeal,
                                    fontWeight: FontWeight.w600)),
                          );
                        },
                      ),
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Income Tab Widget
// ═════════════════════════════════════════════════════════════════════════════

class _IncomeTab extends StatefulWidget {
  final String polyclinicUid;
  final List<String> linkedIds;
  const _IncomeTab({
    required this.polyclinicUid,
    required this.linkedIds,
  });
  @override
  State<_IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<_IncomeTab> {
  String? _filterDoctorId; // null = all
  String  _period  = 'monthly';
  DateTime _refDate = DateTime.now();

  DateTime get _start {
    final r = _refDate;
    return switch (_period) {
      'daily'  => DateTime(r.year, r.month, r.day),
      'weekly' => () {
                    final m = r.subtract(Duration(days: r.weekday - 1));
                    return DateTime(m.year, m.month, m.day);
                  }(),
      'yearly' => DateTime(r.year, 1, 1),
      _        => DateTime(r.year, r.month, 1),
    };
  }

  DateTime get _end {
    final r = _refDate;
    return switch (_period) {
      'daily'  => DateTime(r.year, r.month, r.day, 23, 59, 59),
      'weekly' => () {
                    final m = r.subtract(Duration(days: r.weekday - 1));
                    final s = DateTime(m.year, m.month, m.day);
                    final e = s.add(const Duration(days: 6));
                    return DateTime(e.year, e.month, e.day, 23, 59, 59);
                  }(),
      'yearly' => DateTime(r.year, 12, 31, 23, 59, 59),
      _        => DateTime(r.year, r.month + 1, 0, 23, 59, 59),
    };
  }

  String get _rangeLabel {
    final s = _start;
    final e = _end;
    return switch (_period) {
      'daily'  => DateFormat('MMMM d, yyyy').format(s),
      'yearly' => '${s.year}',
      _        => '${DateFormat('MMM d').format(s)} – ${DateFormat('MMM d, yyyy').format(e)}',
    };
  }

  void _prev() => setState(() {
    _refDate = switch (_period) {
      'daily'  => _refDate.subtract(const Duration(days: 1)),
      'weekly' => _refDate.subtract(const Duration(days: 7)),
      'yearly' => DateTime(_refDate.year - 1),
      _        => DateTime(_refDate.year, _refDate.month - 1),
    };
  });

  void _next() => setState(() {
    _refDate = switch (_period) {
      'daily'  => _refDate.add(const Duration(days: 1)),
      'weekly' => _refDate.add(const Duration(days: 7)),
      'yearly' => DateTime(_refDate.year + 1),
      _        => DateTime(_refDate.year, _refDate.month + 1),
    };
  });

  @override
  Widget build(BuildContext context) {
    if (widget.linkedIds.isEmpty) {
      return const Center(
          child: Text('Link doctors first to view income.',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    final queryIds = _filterDoctorId != null
        ? [_filterDoctorId!]
        : widget.linkedIds;

    return Column(children: [
      // ── Filter bar ─────────────────────────────────────────────────────
      Container(
        color: _kNavy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(children: [
          Row(children: [
            // Period dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _period,
                  dropdownColor: _kNavy,
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: Colors.white),
                  items: ['daily', 'weekly', 'monthly', 'yearly']
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p[0].toUpperCase() + p.substring(1),
                                style: const TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _period = v!),
                ),
              ),
            ),
            const Spacer(),
            // Date nav
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                GestureDetector(
                    onTap: _prev,
                    child: const Icon(Icons.chevron_left_rounded,
                        color: _kNavy, size: 20)),
                const SizedBox(width: 6),
                Text(_rangeLabel,
                    style: const TextStyle(
                        color: _kNavy,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                const SizedBox(width: 6),
                GestureDetector(
                    onTap: _next,
                    child: const Icon(Icons.chevron_right_rounded,
                        color: _kNavy, size: 20)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          // Doctor filter
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('users').stream(primaryKey: ['id'])
                .eq('polyclinic_id', widget.polyclinicUid),
            builder: (_, snap) {
              final doctors = snap.data ?? [];
              return DropdownButtonHideUnderline(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: DropdownButton<String?>(
                    value: _filterDoctorId,
                    dropdownColor: _kNavy,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Doctors (Combined)',
                              style: TextStyle(color: Colors.white))),
                      ...doctors.map((d) {
                        final id = d['id'] as String;
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text((d['name'] ?? id) as String,
                              style: const TextStyle(color: Colors.white)),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _filterDoctorId = v),
                  ),
                ),
              );
            },
          ),
        ]),
      ),
      // ── Income content ─────────────────────────────────────────────────
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('invoices').stream(primaryKey: ['id'])
              .map((list) => list.where((inv) => queryIds.contains(inv['doctor_id'])).toList()),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final s = _start;
            final e = _end;
            final docs = (snap.data ?? []).where((doc) {
              final tsStr = (doc['invoice_date'] ?? doc['created_at']) as String?;
              if (tsStr == null) return false;
              final dt = DateTime.parse(tsStr);
              return !dt.isBefore(s) && !dt.isAfter(e);
            }).toList()
              ..sort((a, b) {
                final ta = DateTime.tryParse((a['invoice_date'] ?? a['created_at'] ?? '') as String) ?? DateTime(2000);
                final tb = DateTime.tryParse((b['invoice_date'] ?? b['created_at'] ?? '') as String) ?? DateTime(2000);
                return tb.compareTo(ta);
              });

            double totalRevenue = 0, pendingTotal = 0;
            int completedCount  = 0;
            for (final doc in docs) {
              final d   = doc;
              final amt = (d['amount'] as num?)?.toDouble() ?? 0;
              final st  = (d['status'] as String?) ?? 'pending';
              if (st == 'paid') {
                totalRevenue += amt;
                completedCount++;
              } else if (st == 'partially_paid') {
                totalRevenue += (d['paid_amount'] as num?)?.toDouble() ?? 0;
              } else if (st == 'pending') {
                pendingTotal += amt;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                // Summary cards
                Row(children: [
                  Expanded(child: _summaryCard(
                      'Revenue', 'USD ${totalRevenue.toStringAsFixed(2)}',
                      'Paid', AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(child: _summaryCard(
                      'Pending', 'USD ${pendingTotal.toStringAsFixed(2)}',
                      'Awaiting', AppColors.warning)),
                ]),
                const SizedBox(height: 10),
                _summaryCard('Completed Transactions', '$completedCount',
                    'This Period', _kNavy),
                const SizedBox(height: 14),
                // Per-doctor breakdown (only when showing all)
                if (_filterDoctorId == null && widget.linkedIds.length > 1)
                  _perDoctorBreakdown(docs),
                // Invoice list
                if (docs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('No income records in this period.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      Container(
                        decoration: const BoxDecoration(
                            color: _kNavy,
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(14))),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: const Row(children: [
                          Expanded(flex: 3,
                              child: Text('Patient',
                                  style: TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Expanded(flex: 2,
                              child: Text('Date',
                                  style: TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Expanded(flex: 2,
                              child: Text('Amount',
                                  style: TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Expanded(flex: 2,
                              child: Text('Doctor',
                                  style: TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                        ]),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFF0F4FA)),
                        itemBuilder: (_, i) {
                          final d  = docs[i];
                          final tsStr = (d['invoice_date'] ?? d['created_at']) as String?;
                          final date = tsStr != null
                              ? DateFormat('MM/dd/yy').format(DateTime.parse(tsStr))
                              : '—';
                          final amt  = (d['amount'] as num?)?.toDouble() ?? 0;
                          final cur  = (d['currency'] as String?) ?? 'USD';
                          final st   = (d['status'] as String?) ?? 'pending';
                          final stColor = st == 'paid'
                              ? AppColors.success
                              : st == 'cancelled'
                                  ? AppColors.error
                                  : AppColors.warning;

                          return Container(
                            color: i.isEven
                                ? Colors.white
                                : const Color(0xFFF8FAFF),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(children: [
                              Expanded(flex: 3,
                                  child: Text(
                                      (d['patient_name'] as String?) ?? '—',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis)),
                              Expanded(flex: 2,
                                  child: Text(date,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary))),
                              Expanded(flex: 2,
                                  child: Text(
                                      '$cur ${amt.toStringAsFixed(2)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: stColor))),
                              Expanded(flex: 2,
                                  child: FutureBuilder<Map<String, dynamic>?>(
                                    future: Supabase.instance.client
                                        .from('users').select().eq('id', (d['doctor_id'] as String?) ?? '').maybeSingle(),
                                    builder: (_, ds) {
                                      final dn = ds.data != null                                          ? (ds.data!['name']
                                                  ?.toString() ??
                                              'Dr.')
                                          : '—';
                                      return Text(dn,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis);
                                    },
                                  )),
                            ]),
                          );
                        },
                      ),
                    ]),
                  ),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _summaryCard(String title, String value, String sub, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(sub,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11)),
          ]),
        ),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
      ]),
    );
  }

  Widget _perDoctorBreakdown(List<Map<String, dynamic>> invoices) {
    // Aggregate per doctor
    final Map<String, double> totals = {};
    for (final doc in invoices) {
      final d   = doc;
      final id  = (d['doctor_id'] as String?) ?? '';
      final amt = (d['amount'] as num?)?.toDouble() ?? 0;
      final st  = (d['status'] as String?) ?? 'pending';
      if (st == 'paid') totals[id] = (totals[id] ?? 0) + amt;
    }
    if (totals.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8EAED))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Per-Doctor Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        ...totals.entries.map((e) => FutureBuilder<Map<String, dynamic>?>(
              future: Supabase.instance.client.from('users').select().eq('id', e.key).maybeSingle(),
              builder: (_, ds) {
                final name = ds.data != null                    ? (ds.data!['name']?.toString() ?? 'Dr.')
                    : e.key;
                final pct = totals.values.fold(0.0, (a, b) => a + b) > 0
                    ? e.value /
                        totals.values.fold(0.0, (a, b) => a + b)
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                      Text('USD ${e.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: _kTeal,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE8EAED),
                        valueColor: const AlwaysStoppedAnimation(_kTeal),
                      ),
                    ),
                  ]),
                );
              },
            )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Statistics Tab Widget
// ═════════════════════════════════════════════════════════════════════════════

class _StatsTab extends StatefulWidget {
  final List<String> linkedIds;
  const _StatsTab({required this.linkedIds});
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  String   _period  = 'monthly';
  DateTime _refDate = DateTime.now();

  DateTime get _start {
    final r = _refDate;
    return switch (_period) {
      'daily'  => DateTime(r.year, r.month, r.day),
      'weekly' => () {
                    final m = r.subtract(Duration(days: r.weekday - 1));
                    return DateTime(m.year, m.month, m.day);
                  }(),
      'yearly' => DateTime(r.year, 1, 1),
      _        => DateTime(r.year, r.month, 1),
    };
  }

  DateTime get _end {
    final r = _refDate;
    return switch (_period) {
      'daily'  => DateTime(r.year, r.month, r.day, 23, 59, 59),
      'weekly' => () {
                    final m = r.subtract(Duration(days: r.weekday - 1));
                    final s = DateTime(m.year, m.month, m.day);
                    final e = s.add(const Duration(days: 6));
                    return DateTime(e.year, e.month, e.day, 23, 59, 59);
                  }(),
      'yearly' => DateTime(r.year, 12, 31, 23, 59, 59),
      _        => DateTime(r.year, r.month + 1, 0, 23, 59, 59),
    };
  }

  String get _rangeLabel {
    final s = _start;
    final e = _end;
    return switch (_period) {
      'daily'  => DateFormat('MMM d, yyyy').format(s),
      'yearly' => '${s.year}',
      _        => '${DateFormat('MMM d').format(s)} – ${DateFormat('MMM d').format(e)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.linkedIds.isEmpty) {
      return const Center(
          child: Text('Link doctors first to view statistics.',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    return Column(children: [
      Container(
        color: _kNavy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _period,
                dropdownColor: _kNavy,
                icon: const Icon(Icons.arrow_drop_down_rounded,
                    color: Colors.white),
                items: ['daily', 'weekly', 'monthly', 'yearly']
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p[0].toUpperCase() + p.substring(1),
                              style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _period = v!),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() {
                  _refDate = switch (_period) {
                    'daily'  => _refDate.subtract(const Duration(days: 1)),
                    'weekly' => _refDate.subtract(const Duration(days: 7)),
                    'yearly' => DateTime(_refDate.year - 1),
                    _        => DateTime(_refDate.year, _refDate.month - 1),
                  };
                }),
                child: const Icon(Icons.chevron_left_rounded,
                    color: _kNavy, size: 20),
              ),
              const SizedBox(width: 6),
              Text(_rangeLabel,
                  style: const TextStyle(
                      color: _kNavy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _refDate = switch (_period) {
                    'daily'  => _refDate.add(const Duration(days: 1)),
                    'weekly' => _refDate.add(const Duration(days: 7)),
                    'yearly' => DateTime(_refDate.year + 1),
                    _        => DateTime(_refDate.year, _refDate.month + 1),
                  };
                }),
                child: const Icon(Icons.chevron_right_rounded,
                    color: _kNavy, size: 20),
              ),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('appointments').stream(primaryKey: ['id'])
              .map((list) => list.where((a) => widget.linkedIds.contains(a['doctor_id'])).toList()),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final s = _start;
            final e = _end;
            final all = (snap.data ?? []).where((doc) {
              final tsStr = doc['appointment_time'] as String?;
              if (tsStr == null) return false;
              final dt = DateTime.parse(tsStr);
              return !dt.isBefore(s) && !dt.isAfter(e);
            }).toList();

            // Per-doctor counts
            final Map<String, int> counts = {};
            for (final doc in all) {
              final did = (doc['doctor_id'] as String?) ?? '';
              counts[did] = (counts[did] ?? 0) + 1;
            }
            final total = all.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Total
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('$total',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1)),
                      const Text('Total Appointments',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                // Per-doctor breakdown
                if (counts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('No appointments in this period.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: const Color(0xFFE8EAED))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Per-Doctor Appointments',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      ...counts.entries.map((entry) =>
                          FutureBuilder<Map<String, dynamic>?>(
                            future: Supabase.instance.client
                                .from('users').select().eq('id', entry.key).maybeSingle(),
                            builder: (_, ds) {
                              final name = ds.data != null                                  ? (ds.data!['name']
                                          ?.toString() ??
                                      'Dr.')
                                  : entry.key;
                              final pct = total > 0
                                  ? entry.value / total
                                  : 0.0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                    ),
                                    Text(
                                        '${entry.value} session${entry.value != 1 ? 's' : ''}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: _kBlue,
                                            fontWeight: FontWeight.bold)),
                                  ]),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 8,
                                      backgroundColor:
                                          const Color(0xFFE8EAED),
                                      valueColor:
                                          const AlwaysStoppedAnimation(
                                              _kBlue),
                                    ),
                                  ),
                                ]),
                              );
                            },
                          )),
                    ]),
                  ),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}
