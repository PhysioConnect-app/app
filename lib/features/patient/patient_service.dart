import 'package:supabase_flutter/supabase_flutter.dart';

class PatientService {
  final _supabase = Supabase.instance.client;
  String get _uid => _supabase.auth.currentUser!.id;

  Stream<List<Map<String, dynamic>>> getMyClinicalNotes() {
    return _supabase
        .from('clinical_notes')
        .stream(primaryKey: ['id'])
        .eq('patient_id', _uid)
        .map((list) => list..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String)));
  }

  Stream<List<Map<String, dynamic>>> getMyAppointments() {
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('patient_id', _uid)
        .map((list) => list..sort((a, b) => (a['appointment_time'] as String).compareTo(b['appointment_time'] as String)));
  }

  Stream<List<Map<String, dynamic>>> getUpcomingAppointments() {
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('patient_id', _uid)
        .map((list) => list.where((a) {
              final t = a['appointment_time'] as String?;
              if (t == null) return false;
              return DateTime.parse(t).isAfter(DateTime.now().subtract(const Duration(minutes: 1)));
            }).toList()
          ..sort((a, b) => (a['appointment_time'] as String).compareTo(b['appointment_time'] as String)));
  }

  Stream<List<Map<String, dynamic>>> getAllAvailableDoctors() {
    return _supabase.from('users').stream(primaryKey: ['id']).eq('role', 'doctor');
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    return await _supabase.from('users').select().eq('id', _uid).maybeSingle();
  }

  Future<String?> getMyDoctorId() async {
    final data = await _supabase.from('users').select('doctor_id').eq('id', _uid).maybeSingle();
    return data?['doctor_id'] as String?;
  }

  Future<Map<String, dynamic>?> getMyDoctor() async {
    final doctorId = await getMyDoctorId();
    if (doctorId == null) return null;
    return await _supabase.from('users').select().eq('id', doctorId).maybeSingle();
  }

  Future<bool> linkToDoctor(String doctorId) async {
    try {
      final data = await _supabase.from('users').select('doctor_ids').eq('id', _uid).single();
      final ids = List<String>.from((data['doctor_ids'] as List?) ?? []);
      if (!ids.contains(doctorId)) ids.add(doctorId);
      await _supabase.from('users').update({'doctor_id': doctorId, 'doctor_ids': ids}).eq('id', _uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addDoctorToMyList(String doctorId) async {
    try {
      // Fetch names needed for notifications (read-only, before the atomic link)
      final myData  = await _supabase.from('users').select('name').eq('id', _uid).single();
      final docData = await _supabase.from('users').select('name').eq('id', doctorId).single();

      // Atomic double-row update: adds doctor to patient.doctor_ids and
      // patient to doctor.assigned_patient_ids via SECURITY DEFINER RPC.
      await _supabase.rpc('link_patient_to_doctor', params: {'p_doctor_id': doctorId});

      // Notify the doctor
      final patName = (myData['name'] as String?) ?? 'A patient';
      await _supabase.from('notifications').insert({
        'recipient_id': doctorId,
        'recipient_type': 'doctor',
        'type': 'patient_added_you',
        'title': 'New Patient Added You',
        'body': '$patName has added you to their doctor list.',
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Confirm to the patient
      final docName = (docData['name'] as String?) ?? 'your doctor';
      await _supabase.from('notifications').insert({
        'patient_id': _uid,
        'recipient_id': _uid,
        'recipient_type': 'patient',
        'type': 'doctor_added_confirmation',
        'title': 'Doctor Added',
        'body': 'You added Dr. $docName to your doctors list.',
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeDoctorFromMyList(String doctorId) async {
    try {
      // Atomic double-row update: removes doctor from patient.doctor_ids,
      // clears patient.doctor_id if it was the primary, and removes patient
      // from doctor.assigned_patient_ids — all via SECURITY DEFINER RPC.
      await _supabase.rpc('unlink_patient_from_doctor', params: {'p_doctor_id': doctorId});
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getLinkedDoctors() {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', _uid)
        .asyncMap((list) async {
          if (list.isEmpty) return <Map<String, dynamic>>[];
          final data = list.first;
          final ids = (data['doctor_ids'] as List?)?.cast<String>() ?? [];
          if (ids.isEmpty) return <Map<String, dynamic>>[];
          final futures = ids.map((id) => _supabase.from('users').select().eq('id', id).maybeSingle());
          final results = await Future.wait(futures);
          return results.whereType<Map<String, dynamic>>().toList();
        });
  }

  Future<bool> isDoctorLinked(String doctorId) async {
    final data = await _supabase.from('users').select('doctor_ids').eq('id', _uid).maybeSingle();
    if (data == null) return false;
    final ids = (data['doctor_ids'] as List?)?.cast<String>() ?? [];
    return ids.contains(doctorId);
  }

  Stream<List<Map<String, dynamic>>> getMyAppointmentRequests() {
    return _supabase
        .from('appointment_requests')
        .stream(primaryKey: ['id'])
        .eq('patient_id', _uid)
        .map((list) => list..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String)));
  }

  Future<bool> sendAppointmentRequest({
    required String doctorId,
    required String doctorName,
    required DateTime requestedTime,
    required String notes,
  }) async {
    try {
      final patData = await _supabase.from('users').select('name').eq('id', _uid).maybeSingle();
      final patName = (patData?['name'] as String?) ?? '';
      await _supabase.from('appointment_requests').insert({
        'patient_id': _uid,
        'patient_name': patName,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'requested_time': requestedTime.toIso8601String(),
        'notes': notes.trim(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<DateTime>> getDoctorBookedSlots(String doctorId) async {
    final data = await _supabase.from('appointments').select('appointment_time')
        .eq('doctor_id', doctorId)
        .gte('appointment_time', DateTime.now().toIso8601String());
    return (data as List).map((d) => DateTime.parse(d['appointment_time'] as String)).toList();
  }

  Future<Map<String, dynamic>?> getDoctorById(String doctorId) async {
    return await _supabase.from('users').select().eq('id', doctorId).maybeSingle();
  }

  Stream<List<Map<String, dynamic>>> getMyNotifications() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('patient_id', _uid)
        .map((list) => (list..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String))).take(50).toList());
  }

  Future<void> markNotificationRead(String notifId) async {
    await _supabase.from('notifications').update({'read': true}).eq('id', notifId);
  }
}
