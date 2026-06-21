// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import 'doctor_service.dart';

/// Standalone notifications tab for the doctor dashboard.
/// Self-contained: owns its own Supabase stream; only needs a [DoctorService]
/// for the "Accept appointment request" action.
class DoctorNotificationsTab extends StatelessWidget {
  final DoctorService service;
  const DoctorNotificationsTab({super.key, required this.service});

  // ── Public helper used by the parent dashboard to style incoming popups ──

  static (IconData, Color) iconFor(String type) => switch (type) {
        'patient_added_you' => (
            Icons.person_add_rounded,
            const Color(0xFF1565C0)
          ),
        'appointment_request' ||
        'appointment_reschedule' => (Icons.event_rounded, Colors.orange),
        'appointment_cancelled' => (
            Icons.event_busy_rounded,
            AppColors.error
          ),
        'admin_note' => (
            Icons.campaign_rounded,
            const Color(0xFF6A1B9A)
          ),
        'patient_added_confirmation' => (
            Icons.person_add_rounded,
            const Color(0xFF2E7D32)
          ),
        'admin' => (Icons.admin_panel_settings_rounded, Colors.teal),
        _ => (Icons.notifications_rounded, const Color(0xFF6A1B9A)),
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
          _NotifHeader(unreadCount: unreadCount, notifs: notifs),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                PendingRequestsCard(service: service),
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
                                color: AppColors.textSecondary, fontSize: 15)),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  ...notifs.map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _NotifCard(notification: n),
                      )),
                ],
              ],
            ),
          ),
        ]);
      },
    );
  }
}

// ── Header row ────────────────────────────────────────────────────────────────

class _NotifHeader extends StatelessWidget {
  final int unreadCount;
  final List<Map<String, dynamic>> notifs;
  const _NotifHeader({required this.unreadCount, required this.notifs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(children: [
        if (unreadCount > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$unreadCount unread',
                style: const TextStyle(
                    color: Color(0xFF6A1B9A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          )
        else
          const Text('All caught up',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
    );
  }
}

// ── Single notification card ──────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _NotifCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final type = (n['type'] as String?) ?? '';
    final title = (n['title'] as String?) ?? 'Notification';
    final body = (n['body'] as String?) ?? '';
    final raw = n['created_at'] as String?;
    final dt = raw != null ? DateTime.tryParse(raw) : null;
    final timeStr =
        dt != null ? DateFormat('MMM d, h:mm a').format(dt.toLocal()) : '';
    final unread = !(n['read'] as bool? ?? false);

    final (IconData icon, Color iconColor) =
        DoctorNotificationsTab.iconFor(type);

    return Material(
      color: unread ? const Color(0xFFF3E5F5) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: unread ? 1 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: unread
            ? () => Supabase.instance.client
                .from('notifications')
                .update({'read': true}).eq('id', n['id'] as String)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF6A1B9A),
                            shape: BoxShape.circle),
                      ),
                  ]),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(body,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(timeStr,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Pending appointment requests card ─────────────────────────────────────────

class PendingRequestsCard extends StatelessWidget {
  final DoctorService service;
  const PendingRequestsCard({super.key, required this.service});

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showPhoneOptions(BuildContext context, String phone) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading:
                const Icon(Icons.phone_rounded, color: Color(0xFF1565C0)),
            title: Text('Call $phone'),
            onTap: () {
              Navigator.pop(context);
              _callPhone(phone);
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_rounded,
                color: Color(0xFF25D366)),
            title: const Text('WhatsApp'),
            onTap: () {
              Navigator.pop(context);
              _whatsApp(phone);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('appointment_requests')
          .stream(primaryKey: ['id'])
          .eq('doctor_id', uid)
          .map((list) => list
              .where(
                  (r) => (r['status'] as String? ?? '') == 'pending')
              .toList()
            ..sort((a, b) => (b['created_at'] as String)
                .compareTo(a['created_at'] as String))),
      builder: (ctx, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
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
                ...requests.map((req) => _RequestTile(
                      req: req,
                      service: service,
                      onPhoneOptions: (phone) =>
                          _showPhoneOptions(context, phone),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Single pending-request tile ───────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> req;
  final DoctorService service;
  final void Function(String phone) onPhoneOptions;
  const _RequestTile(
      {required this.req,
      required this.service,
      required this.onPhoneOptions});

  @override
  Widget build(BuildContext context) {
    final patName = (req['patient_name'] as String?) ?? 'Patient';
    final patId = (req['patient_id'] as String?) ?? '';
    final notes = (req['notes'] as String?) ?? '';
    final reqTime = req['requested_time'] as String?;
    final dt = reqTime != null ? DateTime.parse(reqTime) : null;
    final timeStr =
        dt != null ? DateFormat('EEE, MMM d – h:mm a').format(dt) : '—';

    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('users')
          .select('phone')
          .eq('id', patId)
          .maybeSingle(),
      builder: (_, patSnap) {
        final phone = (patSnap.data?['phone'] as String?) ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(patName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                if (phone.isNotEmpty)
                  GestureDetector(
                    onTap: () => onPhoneOptions(phone),
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                        fontSize: 12, color: AppColors.textSecondary)),
              ]),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(notes,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Supabase.instance.client
                          .from('appointment_requests')
                          .update({'status': 'declined'}).eq(
                              'id', req['id'] as String);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (dt == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await service.bookAppointment(
                          patId, patName, dt, notes);
                      if (!context.mounted) return;
                      if (ok) {
                        await Supabase.instance.client
                            .from('appointment_requests')
                            .update({'status': 'accepted'}).eq(
                                'id', req['id'] as String);
                        messenger.showSnackBar(const SnackBar(
                          content: Text('Appointment confirmed!'),
                          backgroundColor: AppColors.success,
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Accept',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}
