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

    try {
      final newId = await AdminService().createPatientAccount(
        name: name,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        doctorId: doctorUid,
        phone: _phoneController.text.trim(),
        dateOfBirth: _dob,
        primaryDiagnosis: _diagnosisController.text.trim(),
      );

      if (!mounted) return;

      if (newId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create patient account.'), backgroundColor: AppColors.error),
        );
        return;
      }

      // ── Replace stub patient with the new auth account ───────────────────
      final stubId = widget.existingPatientId;
      if (stubId != null && stubId != newId) {
        final mergeError = await _mergeStubIntoNewAccount(
          supabase: supabase,
          stubId: stubId,
          newId: newId,
          doctorUid: doctorUid,
        );
        if (!mounted) return;
        if (mergeError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Account created but merge failed: $mergeError'),
            backgroundColor: AppColors.warning,
          ));
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient account created for $name!'),
          backgroundColor: AppColors.success,
        ),
      );
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

      // 4. Update new user record: inherit all doctor links from stub
      await supabase.from('users')
          .update({'doctor_ids': stubDoctorIds}).eq('id', newId);

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
                icon: Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _field(s.patientEmail, _emailController,
                icon: Icons.email_outlined,
                type: TextInputType.emailAddress),
            const SizedBox(height: 14),
            TextField(
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
                type: TextInputType.phone),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickDob,
              child: AbsorbPointer(
                child: TextField(
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
                maxLines: 2),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
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
  }) {
    return TextField(
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
