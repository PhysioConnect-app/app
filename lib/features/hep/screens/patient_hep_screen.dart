import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/exercise.dart';
import '../models/hep_item.dart';
import '../models/hep_program.dart';
import '../services/exercise_library_service.dart';
import '../services/hep_service.dart';
import '../widgets/exercise_image.dart';

// ════════════════════════════════════════════════════════════════════════════
// PatientHepScreen — read-only view of the patient's assigned programs.
// ════════════════════════════════════════════════════════════════════════════

class PatientHepScreen extends StatefulWidget {
  const PatientHepScreen({super.key});

  @override
  State<PatientHepScreen> createState() => _PatientHepScreenState();
}

class _PatientHepScreenState extends State<PatientHepScreen> {
  final _service = HepService();

  List<_ProgramWithItems>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final programs = await _service.getMyPrograms();
      final loaded = <_ProgramWithItems>[];
      for (final p in programs) {
        final items = await _service.getItemsForProgram(p.id);
        final entries = <_ItemWithExercise>[];
        for (final item in items) {
          final ex = await ExerciseLibraryService.byId(item.exerciseId);
          if (ex != null) entries.add(_ItemWithExercise(item: item, exercise: ex));
        }
        loaded.add(_ProgramWithItems(program: p, entries: entries));
      }
      if (mounted) setState(() { _data = loaded; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Exercise Programs',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  ),
                )
              : _data!.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: _data!.length + 1,
                        separatorBuilder: (_, i) =>
                            i == 0 ? const SizedBox(height: 12) : const SizedBox(height: 16),
                        itemBuilder: (_, i) => i == 0
                            ? const _MedicalDisclaimer()
                            : _ProgramSection(data: _data![i - 1]),
                      ),
                    ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// One program block
// ════════════════════════════════════════════════════════════════════════════

class _ProgramSection extends StatelessWidget {
  final _ProgramWithItems data;
  const _ProgramSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = data.program;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF004D40)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(children: [
          const Icon(Icons.fitness_center_rounded, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                p.title.isNotEmpty ? p.title : 'Exercise Program',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (p.notesEn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(p.notesEn,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.4)),
                ),
            ]),
          ),
          Text(
            '${data.entries.length} exercise${data.entries.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ]),
      ),
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: data.entries.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No exercises in this program yet.',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            : Column(
                children: data.entries.asMap().entries.map((e) {
                  return _ExerciseItemTile(
                      entry: e.value, isLast: e.key == data.entries.length - 1);
                }).toList(),
              ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// One exercise item tile
// ════════════════════════════════════════════════════════════════════════════

class _ExerciseItemTile extends StatelessWidget {
  final _ItemWithExercise entry;
  final bool isLast;
  const _ExerciseItemTile({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final e = entry.exercise;
    final item = entry.item;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExerciseImage(
              photoFilename: e.photoFilename,
              exerciseName: e.nameEn,
              region: e.region,
              width: 72,
              height: 72,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.nameEn,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  _chip(e.region, AppColors.primary),
                  _chip(e.category, AppColors.textSecondary),
                ]),
                const SizedBox(height: 6),
                _DoseRow(item: item),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text(e.descriptionEn,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Targets: ',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Expanded(
              child: Text(e.muscles.join(', '),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          ]),
          if (item.customNoteEn.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.sticky_note_2_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.customNoteEn,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary, height: 1.4)),
                ),
              ]),
            ),
          ],
        ]),
      ),
      if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
    ]);
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );
}

class _DoseRow extends StatelessWidget {
  final HepItem item;
  const _DoseRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final holdStr = Exercise.formatHoldSec(item.holdSec);
    return Wrap(spacing: 8, runSpacing: 4, children: [
      _pill(Icons.repeat_rounded, '${item.sets} sets'),
      _pill(Icons.fitness_center_rounded, '${item.reps} reps'),
      _pill(Icons.timer_outlined, holdStr),
      _pill(Icons.calendar_today_rounded, '${item.freqPerWeek}×/wk'),
    ]);
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fitness_center_rounded,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('No exercise programs yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          const Text(
            'Your physiotherapist will add a personalised\nexercise program here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ]),
      ),
    );
  }
}

class _ProgramWithItems {
  final HepProgram program;
  final List<_ItemWithExercise> entries;
  const _ProgramWithItems({required this.program, required this.entries});
}

class _ItemWithExercise {
  final HepItem item;
  final Exercise exercise;
  const _ItemWithExercise({required this.item, required this.exercise});
}

class _MedicalDisclaimer extends StatelessWidget {
  const _MedicalDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC02), width: 1),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF57F17)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This content does not replace professional medical advice. '
              'Always follow the guidance of your treating physiotherapist.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6D4C41),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
