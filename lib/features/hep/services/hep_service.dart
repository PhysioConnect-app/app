import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hep_item.dart';
import '../models/hep_program.dart';

class HepService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // ── Doctor: programs ──────────────────────────────────────────────────────

  Future<List<HepProgram>> getProgramsForPatient(String patientId) async {
    try {
      final rows = await _db
          .from('hep_programs')
          .select()
          .eq('doctor_id', _uid)
          .eq('patient_id', patientId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => HepProgram.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('HepService.getProgramsForPatient: $e');
      rethrow;
    }
  }

  Future<HepProgram> createProgram({
    required String patientId,
    required String title,
    String notesEn = '',
  }) async {
    final row = await _db
        .from('hep_programs')
        .insert({
          'doctor_id': _uid,
          'patient_id': patientId,
          'title': title.trim(),
          'notes_en': notesEn.trim(),
          'status': 'active',
        })
        .select()
        .single();
    return HepProgram.fromJson(row);
  }

  Future<void> updateProgram(
    String id, {
    String? title,
    String? notesEn,
    String? status,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title.trim();
    if (notesEn != null) patch['notes_en'] = notesEn.trim();
    if (status != null) patch['status'] = status;
    if (patch.isEmpty) return;
    await _db
        .from('hep_programs')
        .update(patch)
        .eq('id', id)
        .eq('doctor_id', _uid);
  }

  Future<void> deleteProgram(String id) async {
    await _db
        .from('hep_programs')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('doctor_id', _uid);
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<List<HepItem>> getItemsForProgram(String programId) async {
    try {
      final rows = await _db
          .from('hep_items')
          .select()
          .eq('hep_id', programId)
          .order('sort_order')
          .order('id');
      return (rows as List)
          .map((r) => HepItem.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('HepService.getItemsForProgram: $e');
      rethrow;
    }
  }

  Future<void> replaceItems(String programId, List<HepItem> items) async {
    await _db.from('hep_items').delete().eq('hep_id', programId);
    if (items.isEmpty) return;
    await _db.from('hep_items').insert(
          items
              .asMap()
              .entries
              .map((e) =>
                  e.value.copyWith(sortOrder: e.key).toInsertMap(programId))
              .toList(),
        );
  }

  // ── Patient: read-only ────────────────────────────────────────────────────

  Future<List<HepProgram>> getMyPrograms() async {
    try {
      final rows = await _db
          .from('hep_programs')
          .select()
          .eq('patient_id', _uid)
          .eq('status', 'active')
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => HepProgram.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('HepService.getMyPrograms: $e');
      rethrow;
    }
  }
}
