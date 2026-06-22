import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  // ── Helper: call an Edge Function and return null on success or an error string ──

  Future<String?> _invoke(String fn, Map<String, dynamic> body) async {
    try {
      final res = await _supabase.functions.invoke(fn, body: body);
      if (res.data is Map && (res.data as Map).containsKey('error')) {
        return (res.data as Map)['error'].toString();
      }
      return null;
    } on FunctionException catch (e) {
      if (kDebugMode) debugPrint('$fn error: ${e.details}');
      final details = e.details;
      if (details is Map && details.containsKey('error')) {
        return details['error'].toString();
      }
      return e.details?.toString() ?? e.toString();
    } catch (e) {
      if (kDebugMode) debugPrint('$fn error: $e');
      return e.toString();
    }
  }

  // ── Create doctor account ────────────────────────────────────────────────────

  Future<String?> createDoctorAccount({
    required String name,
    required String email,
    required String password,
    required String specialty,
  }) async {
    return _invoke('admin-create-user', {
      'email': email,
      'password': password,
      'role': 'doctor',
      'name': name,
      'specialty': specialty,
    });
  }

  // ── Create patient account — returns new patient UUID on success, null on failure ─

  Future<String?> createPatientAccount({
    required String name,
    required String email,
    required String password,
    required String doctorId,
    String? phone,
    String? primaryDiagnosis,
    DateTime? dateOfBirth,
  }) async {
    try {
      final res = await _supabase.functions.invoke('admin-create-user', body: {
        'email': email,
        'password': password,
        'role': 'patient',
        'name': name,
        'doctor_id': doctorId,
        'phone': phone ?? '',
        'primary_diagnosis': primaryDiagnosis ?? '',
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
      });
      if (res.data is Map && (res.data as Map).containsKey('error')) {
        if (kDebugMode) debugPrint('createPatientAccount error: ${res.data}');
        return null;
      }
      return (res.data as Map?)?['id'] as String?;
    } catch (e) {
      if (kDebugMode) debugPrint('createPatientAccount error: $e');
      return null;
    }
  }

  // ── Delete user account (auth + DB row) ─────────────────────────────────────

  Future<String?> deleteUserAccount(String userId) async {
    return _invoke('admin-delete-user', {'userId': userId});
  }

  // ── Merge duplicate patient records into one canonical record ───────────────
  //
  // Re-points appointments/notes/invoices/notifications/appointment requests,
  // chat history and doctor assignments from `duplicateIds` onto `canonicalId`,
  // then removes the duplicate rows (including their auth accounts, if any).

  Future<String?> mergePatients({
    required String canonicalId,
    required List<String> duplicateIds,
  }) async {
    return _invoke('admin-merge-patients', {
      'canonicalId': canonicalId,
      'duplicateIds': duplicateIds,
    });
  }

  // ── Approve a therapist account request ──────────────────────────────────────
  //
  // Creates the doctor account then marks the request row as 'approved'.
  // Returns null on success or an error string on failure.

  Future<String?> approveAccountRequest({
    required String requestId,
    required String name,
    required String email,
    required String password,
    required String specialty,
  }) async {
    final error = await createDoctorAccount(
      name: name,
      email: email,
      password: password,
      specialty: specialty,
    );
    if (error != null) return error;
    try {
      await _supabase
          .from('account_requests')
          .update({'status': 'approved'})
          .eq('id', requestId);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('approveAccountRequest update error: $e');
      return e.toString();
    }
  }

  // ── Decline a therapist account request ──────────────────────────────────────

  Future<String?> declineAccountRequest(String requestId) async {
    try {
      await _supabase
          .from('account_requests')
          .update({'status': 'declined'})
          .eq('id', requestId);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('declineAccountRequest error: $e');
      return e.toString();
    }
  }
}
