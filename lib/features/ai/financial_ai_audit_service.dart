import 'package:supabase_flutter/supabase_flutter.dart';

/// Logs every AI-initiated financial modification to `ai_financial_audit`.
///
/// Required Supabase SQL (run once in the Supabase SQL editor):
/// ```sql
/// CREATE TABLE IF NOT EXISTS ai_financial_audit (
///   id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
///   doctor_id     UUID NOT NULL,
///   action_type   TEXT NOT NULL,
///   record_id     UUID,
///   previous_value JSONB,
///   new_value      JSONB,
///   created_at    TIMESTAMPTZ DEFAULT NOW()
/// );
/// ALTER TABLE ai_financial_audit ENABLE ROW LEVEL SECURITY;
/// CREATE POLICY "doctors_own_audit" ON ai_financial_audit
///   FOR ALL USING (auth.uid() = doctor_id);
/// ```
class FinancialAiAuditService {
  FinancialAiAuditService._();

  static final _db  = Supabase.instance.client;
  static final _uid = Supabase.instance.client.auth.currentUser?.id ?? '';

  static Future<void> log({
    required String actionType,
    String?  recordId,
    Map<String, dynamic>? previousValue,
    Map<String, dynamic>? newValue,
  }) async {
    try {
      await _db.from('ai_financial_audit').insert({
        'doctor_id':      _uid,
        'action_type':    actionType,
        if (recordId      != null) 'record_id':      recordId,
        if (previousValue != null) 'previous_value': previousValue,
        if (newValue      != null) 'new_value':      newValue,
        'created_at':     DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Non-fatal — audit log failure must never block the main action.
    }
  }
}
