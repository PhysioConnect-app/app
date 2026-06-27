import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';
import '../admin/admin_service.dart';

class CreatePatientScreen extends StatefulWidget {
  final String? prefillName;
  /// When set, the newly created auth account is merged into this existing
  /// stub-patient row (imported from Excel) instead of creating a duplicate.
  final String? existingPatientId;
  const CreatePatientScreen({super.key, this.prefillName, this.existingPatientId});

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    if (widget.prefillName != null) {
      _nameController.text = widget.prefillName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _diagnosisController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _dob = date;
        _dobController.text =
            '${date.day}/${date.month}/${date.year}';
      });
    }
  }

  Future<void> _createPatient(AppStrings s) async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name, email, and password (min 6 chars).')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final supabase  = Supabase.instance.client;
    final doctorUid = supabase.auth.currentUser!.id;
    final name      = _nameController.text.trim();
    final email     = _emailController.text.trim();

    try {
      // ── Check whether this email already belongs to a patient ────────────
      final existing = await supabase
          .from('users')
          .select('id, name')
          .eq('email', email)
          .eq('role', 'patient')
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        final existingName = (existing['name'] as String?) ?? email;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Patient already exists'),
            content: Text(
              '"$existingName" already has an account with this email.\n\n'
              'Link them to your practice and merge all their data?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Merge & Link'),
              ),
            ],
          ),
        );

        if (confirm != true || !mounted) return;
        setState(() => _isLoading = true);

        final existingId = existing['id'] as String;

        await _linkExistingPatient(
          supabase: supabase,
          existingId: existingId,
          doctorId: doctorUid,
          phone: _phoneController.text.trim(),
          primaryDiagnosis: _diagnosisController.text.trim(),
          dateOfBirth: _dob,
        );

        // Absorb the explicit stub we were opened from (if any) — do this
        // before the name sweep so the sweep doesn't double-process it.
        final explicitStub = widget.existingPatientId;
        if (explicitStub != null && explicitStub != existingId) {
          await _mergeStubIntoNewAccount(
            supabase: supabase,
            stubId: explicitStub,
            newId: existingId,
            doctorUid: doctorUid,
          );
        }

        // Also absorb any stubs for this doctor with the same name
        await _absorbStubs(supabase,
            canonicalId: existingId, doctorUid: doctorUid, name: name);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$existingName linked to your practice!'),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context);
        return;
      }

      // ── Create account ───────────────────────────────────────────────────────
      // stub_id tells the edge function to reuse the stub's UUID so the same
      // row is upgraded in-place — no new row, no deletion needed.
      final newId = await AdminService().createPatientAccount(
        name: name,
        email: email,
        password: _passwordController.text.trim(),
        doctorId: doctorUid,
        phone: _phoneController.text.trim(),
        dateOfBirth: _dob,
        primaryDiagnosis: _diagnosisController.text.trim(),
        stubId: widget.existingPatientId,
      );

      if (!mounted) return;
      if (newId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create patient account.'),
              backgroundColor: AppColors.error),
        );
        return;
      }

      // ── Flutter-side fallback (older edge function or stub_id unsupported) ──
      // New edge function returns stub_id unchanged (same row, no duplicate).
      // If a different ID came back a new row was created — migrate and remove
      // the stub so the list stays clean.
      final explicitStub = widget.existingPatientId;
      if (explicitStub != null && explicitStub != newId) {
        await _mergeStubIntoNewAccount(
          supabase: supabase,
          stubId: explicitStub,
          newId: newId,
          doctorUid: doctorUid,
        );
      }

      // ── Absorb any other same-name stubs (manual-creation path fallback) ────
      await _absorbStubs(supabase,
          canonicalId: newId, doctorUid: doctorUid, name: name);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Patient account created for $name!'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Links an existing patient account to the current doctor.
  /// Adds the doctor to the patient's [doctor_ids] and the patient to the
  /// doctor's [assigned_patient_ids]. Fills profile fields that are empty.
  Future<void> _linkExistingPatient({
    required SupabaseClient supabase,
    required String existingId,
    required String doctorId,
    String? phone,
    String? primaryDiagnosis,
    DateTime? dateOfBirth,
  }) async {
    final existing = await supabase
        .from('users')
        .select('doctor_ids, phone, primary_diagnosis, date_of_birth')
        .eq('id', existingId)
        .maybeSingle();

    // Merge doctor into patient's doctor_ids
    final doctorIds = List<String>.from(
        (existing?['doctor_ids'] as List?) ?? []);
    if (!doctorIds.contains(doctorId)) doctorIds.add(doctorId);

    final updates = <String, dynamic>{'doctor_ids': doctorIds};

    // Fill sparse profile fields only if currently empty on the existing record
    if (phone != null && phone.isNotEmpty &&
        ((existing?['phone'] as String?) ?? '').isEmpty) {
      updates['phone'] = phone;
    }
    if (primaryDiagnosis != null && primaryDiagnosis.isNotEmpty &&
        ((existing?['primary_diagnosis'] as String?) ?? '').isEmpty) {
      updates['primary_diagnosis'] = primaryDiagnosis;
    }
    if (dateOfBirth != null && existing?['date_of_birth'] == null) {
      updates['date_of_birth'] = dateOfBirth.toIso8601String();
    }

    await supabase.from('users').update(updates).eq('id', existingId);

    // Add patient to doctor's assigned_patient_ids
    final docRow = await supabase
        .from('users')
        .select('assigned_patient_ids')
        .eq('id', doctorId)
        .maybeSingle();
    final assignedIds = List<String>.from(
        (docRow?['assigned_patient_ids'] as List?) ?? []);
    if (!assignedIds.contains(existingId)) assignedIds.add(existingId);
    await supabase
        .from('users')
        .update({'assigned_patient_ids': assignedIds})
        .eq('id', doctorId);
  }

  /// Finds every stub patient for [doctorUid] whose name matches [name] and
  /// absorbs them into [canonicalId]. A patient is treated as a stub when they
  /// have no email OR have [has_account] = false (covers old DB rows that still
  /// carry the default true, as long as email is empty). The explicit
  /// [widget.existingPatientId] is always absorbed regardless of those flags.
  Future<void> _absorbStubs(
    SupabaseClient supabase, {
    required String canonicalId,
    required String doctorUid,
    required String name,
  }) async {
    // Note: widget.existingPatientId is already handled by the edge function.
    // This sweep only picks up additional name-matching stubs.
    final toAbsorb = <String>{};

    // Find all patients for this doctor with the same name that look like stubs
    try {
      final rows = await supabase
          .from('users')
          .select('id, email')
          .eq('role', 'patient')
          .contains('doctor_ids', [doctorUid])
          .ilike('name', name)
          .neq('id', canonicalId);

      for (final r in rows as List) {
        final em = (r['email'] as String?) ?? '';
        // Stub: no email means the patient can't log in — absorb them.
        if (em.isEmpty) toAbsorb.add(r['id'] as String);
      }
    } catch (_) {}

    for (final stubId in toAbsorb) {
      await _mergeStubIntoNewAccount(
        supabase: supabase,
        stubId: stubId,
        newId: canonicalId,
        doctorUid: doctorUid,
      );
    }
  }

  /// Transfers appointments, notes, and doctor links from the stub patient
  /// to the newly created auth account, then deletes the stub row.
  /// Returns null on success, or an error string on failure.
  Future<String?> _mergeStubIntoNewAccount({
    required SupabaseClient supabase,
    required String stubId,
    required String newId,
    required String doctorUid,
  }) async {
    try {
      // 1. Get stub's doctor list so we can replicate all relationships
      final stub = await supabase
          .from('users').select('doctor_ids, assigned_patient_ids')
          .eq('id', stubId).maybeSingle();
      final stubDoctorIds = List<String>.from(
          (stub?['doctor_ids'] as List?) ?? [doctorUid]);

      // 2. Move appointments to new ID
      await supabase.from('appointments')
          .update({'patient_id': newId}).eq('patient_id', stubId);

      // 3. Move clinical notes to new ID
      await supabase.from('clinical_notes')
          .update({'patient_id': newId}).eq('patient_id', stubId);

      // 3b. Migrate notifications
      await supabase.from('notifications')
          .update({'patient_id': newId, 'recipient_id': newId})
          .eq('patient_id', stubId);
      // Also migrate any notifications addressed directly to the stub as recipient
      await supabase.from('notifications')
          .update({'recipient_id': newId})
          .eq('recipient_id', stubId);

      // 3c. Migrate invoices (FK blocks deletion if not migrated)
      await supabase.from('invoices')
          .update({'patient_id': newId}).eq('patient_id', stubId);

      // 3d. Migrate appointment requests
      await supabase.from('appointment_requests')
          .update({'patient_id': newId}).eq('patient_id', stubId);

      // 3e. Migrate home exercise programs
      await supabase.from('hep_programs')
          .update({'patient_id': newId}).eq('patient_id', stubId);

      // 4. Merge stub's doctor links into the real account (preserve existing links)
      final newRow = await supabase.from('users')
          .select('doctor_ids').eq('id', newId).maybeSingle();
      final existingDoctorIds = List<String>.from(
          (newRow?['doctor_ids'] as List?) ?? []);
      final mergedDoctorIds =
          {...existingDoctorIds, ...stubDoctorIds}.toList();
      await supabase.from('users')
          .update({'doctor_ids': mergedDoctorIds}).eq('id', newId);

      // 5. For every doctor that had the stub: replace stub ID with new ID
      for (final dId in stubDoctorIds) {
        final doc = await supabase.from('users')
            .select('assigned_patient_ids').eq('id', dId).maybeSingle();
        if (doc == null) continue;
        final ids = List<String>.from(
            (doc['assigned_patient_ids'] as List?) ?? []);
        ids.remove(stubId);
        if (!ids.contains(newId)) ids.add(newId);
        await supabase.from('users')
            .update({'assigned_patient_ids': ids}).eq('id', dId);
      }

      // 6. Delete the stub row
      await supabase.from('users').delete().eq('id', stubId);
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Merge stub error: $e');
      return e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s.addPatient),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field(s.patientName, _nameController,
                icon: Icons.person_outline_rounded,
                key: const Key('create_patient_name')),
            const SizedBox(height: 14),
            _field(s.patientEmail, _emailController,
                icon: Icons.email_outlined,
                type: TextInputType.emailAddress,
                key: const Key('create_patient_email')),
            const SizedBox(height: 14),
            TextField(
              key: const Key('create_patient_password'),
              controller: _passwordController,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: s.patientPassword,
                prefixIcon:
                    const Icon(Icons.lock_outline, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            _field(s.patientPhone, _phoneController,
                icon: Icons.phone_outlined,
                type: TextInputType.phone,
                key: const Key('create_patient_phone')),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickDob,
              child: AbsorbPointer(
                child: TextField(
                  key: const Key('create_patient_dob'),
                  controller: _dobController,
                  decoration: InputDecoration(
                    labelText: s.patientDob,
                    prefixIcon: const Icon(Icons.cake_outlined,
                        color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _field(s.diagnosis, _diagnosisController,
                icon: Icons.medical_information_outlined,
                maxLines: 2,
                key: const Key('create_patient_diagnosis')),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      key: const Key('create_patient_submit_btn'),
                      icon: const Icon(Icons.person_add_rounded),
                      label: Text(s.createAccount,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: () => _createPatient(s),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    Key? key,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.primary) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
