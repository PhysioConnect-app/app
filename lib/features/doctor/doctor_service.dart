import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorService {
  final _supabase = Supabase.instance.client;

  String get _uid => _supabase.auth.currentUser!.id;
  String get currentUid => _uid;

  // ── Patients ──────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getAssignedPatients() {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('role', 'patient')
        .map((list) {
          // 1. Only this doctor's patients
          final mine = list.where((u) {
            final ids = (u['doctor_ids'] as List?)?.cast<String>() ?? [];
            return ids.contains(_uid);
          }).toList();

          // 2. Display-level dedup: if the same name exists as both a stub
          //    (no email / has_account=false) and an active account, show only
          //    the active account. This hides the stub even during the brief
          //    window between account creation and server-side cleanup.
          final activeNames = <String>{};
          for (final p in mine) {
            if (_patientHasAccount(p)) {
              activeNames.add(_normName(p));
            }
          }
          return mine.where((p) {
            if (_patientHasAccount(p)) return true;
            return !activeNames.contains(_normName(p));
          }).toList();
        });
  }

  static bool _patientHasAccount(Map<String, dynamic> p) {
    final email  = (p['email'] as String?) ?? '';
    final hasAcc = p['has_account'] as bool? ?? true;
    return email.isNotEmpty && hasAcc;
  }

  static String _normName(Map<String, dynamic> p) =>
      (p['name'] as String? ?? '').toLowerCase().trim();

  Future<List<Map<String, dynamic>>> getAssignedPatientsOnce() async {
    final data = await _supabase
        .from('users')
        .select()
        .eq('role', 'patient')
        .contains('doctor_ids', [_uid]);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> searchAllPatients(String query) async {
    final q = query.toLowerCase().trim();
    final data = await _supabase.from('users').select().eq('role', 'patient');
    return (data as List).cast<Map<String, dynamic>>().where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final diagnosis = (u['primary_diagnosis'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || diagnosis.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<bool> addExistingPatient(String patientId) async {
    try {
      // Atomic double-row update: adds this doctor to patient.doctor_ids and
      // adds the patient to doctor.assigned_patient_ids via SECURITY DEFINER RPC.
      await _supabase.rpc('doctor_add_patient', params: {'p_patient_id': patientId});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removePatient(String patientId) async {
    try {
      // Atomic double-row update: removes this doctor from patient.doctor_ids
      // and removes the patient from doctor.assigned_patient_ids via SECURITY
      // DEFINER RPC.
      await _supabase.rpc('doctor_remove_patient', params: {'p_patient_id': patientId});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePatientInfo(
      String patientId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('users').update(updates).eq('id', patientId);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('updatePatientInfo error: $e');
      return false;
    }
  }

  // ── Appointments ──────────────────────────────────────────────────────────

  Future<bool> bookAppointment(String patientId, String patientName, DateTime dateTime, String notes) async {
    try {
      await _supabase.from('appointments').insert({
        'patient_id': patientId,
        'patient_name': patientName,
        'doctor_id': _uid,
        'appointment_time': dateTime.toIso8601String(),
        'notes': notes.trim().isEmpty ? 'Standard Protocol' : notes.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      final doctorName = await getMyName();
      await _supabase.from('notifications').insert({
        'patient_id': patientId,
        'recipient_id': patientId,
        'recipient_type': 'patient',
        'type': 'appointment_scheduled',
        'title': 'Appointment Scheduled',
        'body': 'Dr. $doctorName scheduled an appointment for you on '
            '${DateFormat('MMM d, yyyy – h:mm a').format(dateTime)}.',
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getUpcomingAppointments() {
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', _uid)
        .map((list) => list.where((a) {
              final t = a['appointment_time'] as String?;
              if (t == null) return false;
              return DateTime.parse(t).isAfter(DateTime.now().subtract(const Duration(minutes: 1)));
            }).toList()
          ..sort((a, b) => (a['appointment_time'] as String).compareTo(b['appointment_time'] as String)));
  }

  Stream<List<Map<String, dynamic>>> getAllDoctorAppointments() {
    return _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', _uid);
  }

  Future<bool> updateAppointment(String id, DateTime dateTime, String notes) async {
    try {
      await _supabase.from('appointments').update({
        'appointment_time': dateTime.toIso8601String(),
        'notes': notes.trim().isEmpty ? 'Standard Protocol' : notes.trim(),
      }).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelAppointment(String id) async {
    try {
      await _supabase.from('appointments').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAppointment(String id) async {
    try {
      await _supabase.from('appointments').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── SOAP Notes ────────────────────────────────────────────────────────────

  Future<bool> submitSoapNote({
    required String patientId,
    required String patientName,
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
  }) async {
    try {
      await _supabase.from('clinical_notes').insert({
        'patient_id': patientId,
        'doctor_id': _uid,
        'patient_name': patientName,
        'subjective': subjective,
        'objective': objective,
        'assessment': assessment,
        'plan': plan,
        'text_note': 'S: $subjective\n\nO: $objective\n\nA: $assessment\n\nP: $plan',
        'reference_link': '',
        'photo_url': '',
        'note_type': 'soap',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitSoapNoteData({
    required String patientId,
    required String patientName,
    required Map<String, dynamic> soapData,
  }) async {
    try {
      await _supabase.from('clinical_notes').insert({
        'patient_id':   patientId,
        'doctor_id':    _uid,
        'patient_name': patientName,
        'note_type':    'soap',
        // legacy summary columns (always exist)
        'subjective':   soapData['subjective'] ?? '',
        'objective':    soapData['objective']  ?? '',
        'assessment':   soapData['assessment'] ?? '',
        'plan':         soapData['plan']        ?? '',
        'text_note':    soapData['subjective'] ?? '',
        // full extended note stored as JSON
        'soap_data':    soapData,
        'created_at':   DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('submitSoapNoteData error: $e');
      return false;
    }
  }

  Future<bool> submitClinicalNote(
    String patientId, String patientName, String textNote,
    String referenceLink, String photoUrl,
  ) async {
    try {
      await _supabase.from('clinical_notes').insert({
        'patient_id': patientId,
        'doctor_id': _uid,
        'patient_name': patientName,
        'text_note': textNote.trim(),
        'reference_link': referenceLink.trim(),
        'photo_url': photoUrl.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getPatientNotes(String patientId) {
    return _supabase
        .from('clinical_notes')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .map((list) => list.where((n) => n['doctor_id'] == _uid).toList()
          ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String)));
  }

  Future<bool> updateSoapNote(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('clinical_notes').update({
        'subjective':  data['subjective'] ?? '',
        'objective':   data['objective']  ?? '',
        'assessment':  data['assessment'] ?? '',
        'plan':        data['plan']        ?? '',
        'text_note':   data['subjective'] ?? '',
        'soap_data':   data,
        'updated_at':  DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('updateSoapNote error: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getAllDoctorNotes() {
    return _supabase
        .from('clinical_notes')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', _uid)
        .map((list) => list..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String)));
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<bool> saveProfile({
    required String bio,
    required String profilePhotoUrl,
    required String specialization,
    required String clinicName,
    required String clinicAddress,
    required bool offersHomeVisit,
    String workingHours = '',
    String phone = '',
  }) async {
    try {
      await _supabase.from('users').update({
        'bio': bio.trim(),
        'profile_photo_url': profilePhotoUrl.trim(),
        'specialization': specialization.trim(),
        'clinic_name': clinicName.trim(),
        'clinic_address': clinicAddress.trim(),
        'offers_home_visit': offersHomeVisit,
        'working_hours': workingHours.trim(),
        'phone': phone.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    return await _supabase.from('users').select().eq('id', _uid).maybeSingle();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<bool> updateMyLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return false;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _supabase.from('users').update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'location_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> notifyPatientAdded(String patientId, String doctorName) async {
    await _supabase.from('notifications').insert({
      'patient_id': patientId,
      'recipient_id': patientId,
      'type': 'doctor_added_you',
      'title': 'Added to Patient List',
      'body': 'Dr. $doctorName has added you to their patient list.',
      'read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> notifySelfPatientAdded(String patientName) async {
    await _supabase.from('notifications').insert({
      'recipient_id': _uid,
      'recipient_type': 'doctor',
      'type': 'patient_added_confirmation',
      'title': 'Patient Added',
      'body': 'You added $patientName to your patient list.',
      'read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> getMyName() async {
    final data = await _supabase.from('users').select('name').eq('id', _uid).maybeSingle();
    return (data?['name'] as String?) ?? '';
  }
}
