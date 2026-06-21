import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/breakpoints.dart';
import '../models/exercise.dart';
import '../models/hep_item.dart';
import '../models/hep_program.dart';
import '../services/exercise_library_service.dart';
import '../services/hep_service.dart';
import '../widgets/exercise_image.dart';

// ════════════════════════════════════════════════════════════════════════════
// Program-list screen  (entry point from doctor's patient action sheet)
// ════════════════════════════════════════════════════════════════════════════

class HepProgramListScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const HepProgramListScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<HepProgramListScreen> createState() => _HepProgramListScreenState();
}

class _HepProgramListScreenState extends State<HepProgramListScreen> {
  final _service = HepService();
  List<HepProgram>? _programs;
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
      final p = await _service.getProgramsForPatient(widget.patientId);
      if (mounted) setState(() { _programs = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openBuilder({HepProgram? existing}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _HepBuilderView(
          patientId: widget.patientId,
          patientName: widget.patientName,
          existing: existing,
        ),
      ),
    );
    _load();
  }

  Future<void> _archive(HepProgram p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Program'),
        content: Text('Archive "${p.title}"? The patient will no longer see it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.updateProgram(p.id, status: 'archived');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Exercise Programs',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text(widget.patientName,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBuilder(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Program'),
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
              : _programs!.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.fitness_center_rounded,
                            size: 72,
                            color: AppColors.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('No programs yet',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        const Text('Tap + to create the first program.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _programs!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = _programs![i];
                          return _ProgramCard(
                            program: p,
                            onEdit: () => _openBuilder(existing: p),
                            onArchive: () => _archive(p),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final HepProgram program;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  const _ProgramCard({required this.program, required this.onEdit, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  program.title.isNotEmpty ? program.title : 'Untitled Program',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text('Created ${program.createdAt.day}/${program.createdAt.month}/${program.createdAt.year}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'archive') onArchive();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
          ]),
          if (program.notesEn.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(program.notesEn,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Open Builder'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Builder view  (create + edit)
// ════════════════════════════════════════════════════════════════════════════

class _HepBuilderView extends StatefulWidget {
  final String patientId;
  final String patientName;
  final HepProgram? existing;

  const _HepBuilderView({
    required this.patientId,
    required this.patientName,
    this.existing,
  });

  @override
  State<_HepBuilderView> createState() => _HepBuilderViewState();
}

class _DraftItem {
  final String exerciseId;
  final String nameEn;
  final String region;
  final String photoFilename;
  int sets;
  int reps;
  int holdSec;
  int freqPerWeek;
  String customNote;

  _DraftItem.fromExercise(Exercise e)
      : exerciseId = e.id,
        nameEn = e.nameEn,
        region = e.region,
        photoFilename = e.photoFilename,
        sets = e.defaultSets,
        reps = e.defaultReps,
        holdSec = e.defaultHoldSec,
        freqPerWeek = e.defaultFreqPerWeek,
        customNote = '';

  _DraftItem.fromItem(HepItem item, Exercise e)
      : exerciseId = item.exerciseId,
        nameEn = e.nameEn,
        region = e.region,
        photoFilename = e.photoFilename,
        sets = item.sets,
        reps = item.reps,
        holdSec = item.holdSec,
        freqPerWeek = item.freqPerWeek,
        customNote = item.customNoteEn;

  HepItem toHepItem(String hepId, int sortOrder) => HepItem(
        id: '',
        hepId: hepId,
        exerciseId: exerciseId,
        sets: sets,
        reps: reps,
        holdSec: holdSec,
        freqPerWeek: freqPerWeek,
        customNoteEn: customNote,
        sortOrder: sortOrder,
      );
}

class _HepBuilderViewState extends State<_HepBuilderView>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  final _formKey = GlobalKey<FormState>();

  final List<_DraftItem> _items = [];

  List<Exercise>? _allExercises;
  List<Exercise> _filtered = [];
  List<String> _regions = [];
  List<String> _conditions = [];
  String? _selRegion;
  String? _selCategory;
  String? _selCondition;
  final _searchCtrl = TextEditingController();
  List<String> _categoriesForRegion = [];

  late final TabController _tabs;
  bool _saving = false;
  final _service = HepService();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notesEn ?? '');
    _loadLibrary();
    if (_isEdit) _loadExistingItems();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final [all, regions, conditions] = await Future.wait([
      ExerciseLibraryService.all(),
      ExerciseLibraryService.regions(),
      ExerciseLibraryService.conditions(),
    ]);
    if (!mounted) return;
    setState(() {
      _allExercises = all as List<Exercise>;
      _filtered = _allExercises!;
      _regions = regions as List<String>;
      _conditions = conditions as List<String>;
    });
  }

  Future<void> _loadExistingItems() async {
    final items = await _service.getItemsForProgram(widget.existing!.id);
    final drafts = <_DraftItem>[];
    for (final item in items) {
      final ex = await ExerciseLibraryService.byId(item.exerciseId);
      if (ex != null) drafts.add(_DraftItem.fromItem(item, ex));
    }
    if (mounted) setState(() => _items.addAll(drafts));
  }

  Future<void> _applyFilters() async {
    final result = await ExerciseLibraryService.filter(
      region: _selRegion,
      category: _selCategory,
      condition: _selCondition,
      query: _searchCtrl.text,
    );
    if (mounted) setState(() => _filtered = result);
  }

  Future<void> _onRegionChanged(String? v) async {
    _selRegion = v;
    _selCategory = null;
    _categoriesForRegion = await ExerciseLibraryService.categoriesForRegion(v);
    await _applyFilters();
  }

  void _addExercise(Exercise e) {
    if (_items.any((d) => d.exerciseId == e.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${e.nameEn} is already in the program.'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    setState(() => _items.add(_DraftItem.fromExercise(e)));
    if (MediaQuery.sizeOf(context).width < kMobileBreakpoint) {
      _tabs.animateTo(1);
    }
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one exercise.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final String programId;
      if (_isEdit) {
        await _service.updateProgram(widget.existing!.id,
            title: _titleCtrl.text, notesEn: _notesCtrl.text);
        programId = widget.existing!.id;
      } else {
        final p = await _service.createProgram(
          patientId: widget.patientId,
          title: _titleCtrl.text,
          notesEn: _notesCtrl.text,
        );
        programId = p.id;
      }
      await _service.replaceItems(
        programId,
        _items.asMap().entries
            .map((e) => e.value.toHepItem(programId, e.key))
            .toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Program saved.'),
            backgroundColor: AppColors.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kMobileBreakpoint;
    final title = _isEdit
        ? 'Edit Program — ${widget.patientName}'
        : 'New Program — ${widget.patientName}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (!isDesktop)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.save_rounded),
              label: const Text('Save'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          if (!isDesktop) const SizedBox(width: 8),
        ],
        bottom: isDesktop
            ? null
            : TabBar(
                controller: _tabs,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.library_books_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Library'),
                    ]),
                  ),
                  Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fitness_center_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Program'),
                      if (_items.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${_items.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ]),
                  ),
                ],
              ),
      ),
      body: isDesktop ? _buildDesktop() : _buildMobile(),
    );
  }

  Widget _buildDesktop() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 360,
        child: Container(
          color: Colors.white,
          child: Column(children: [
            _buildLibraryFilters(),
            Expanded(child: _buildLibraryList()),
          ]),
        ),
      ),
      const VerticalDivider(width: 1),
      Expanded(
        child: Form(
          key: _formKey,
          child: Column(children: [
            _buildCanvasHeader(isDesktop: true),
            Expanded(child: _buildCanvasList()),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildMobile() {
    return Form(
      key: _formKey,
      child: TabBarView(
        controller: _tabs,
        children: [
          Column(children: [
            _buildLibraryFilters(),
            Expanded(child: _buildLibraryList()),
          ]),
          Column(children: [
            _buildCanvasHeader(isDesktop: false),
            Expanded(child: _buildCanvasList()),
            _buildSaveBar(),
          ]),
        ],
      ),
    );
  }

  Widget _buildLibraryFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => _applyFilters(),
          decoration: InputDecoration(
            hintText: 'Search exercises…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _dropdown('Region', _regions, _selRegion, (v) async {
            await _onRegionChanged(v);
          })),
          const SizedBox(width: 8),
          Expanded(child: _dropdown(
            'Category',
            _categoriesForRegion.isNotEmpty ? _categoriesForRegion : [],
            _selCategory,
            (v) { setState(() => _selCategory = v); _applyFilters(); },
          )),
        ]),
        const SizedBox(height: 8),
        _dropdown('Condition', _conditions, _selCondition, (v) {
          setState(() => _selCondition = v);
          _applyFilters();
        }),
      ]),
    );
  }

  Widget _dropdown(String hint, List<String> items, String? value,
      void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(
            value: null,
            child: Text('All',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13))),
        ...items.map((s) => DropdownMenuItem<String>(
            value: s,
            child: Text(s, style: const TextStyle(fontSize: 13)))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildLibraryList() {
    if (_allExercises == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filtered.isEmpty) {
      return const Center(
          child: Text('No exercises match.',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final e = _filtered[i];
        final added = _items.any((d) => d.exerciseId == e.id);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: added
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.cardBorder),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            leading: ExerciseImage(
              photoFilename: e.photoFilename,
              exerciseName: e.nameEn,
              region: e.region,
              width: 52,
              height: 52,
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(e.nameEn,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('${e.region} · ${e.category}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            trailing: IconButton(
              onPressed: added ? null : () => _addExercise(e),
              icon: Icon(
                added
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: added ? AppColors.success : AppColors.primary,
                size: 26,
              ),
              tooltip: added ? 'Already added' : 'Add to program',
            ),
          ),
        );
      },
    );
  }

  Widget _buildCanvasHeader({required bool isDesktop}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Program Title *',
            hintText: 'e.g. Cervical Rehabilitation Phase 1',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'General Notes (optional)',
            hintText: 'e.g. Perform in the morning. Stop if pain increases.',
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving…' : 'Save Program'),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildCanvasList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.playlist_add_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No exercises added yet.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Browse the library and tap + to add.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _items.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);
        });
      },
      itemBuilder: (_, i) => _ItemCard(
        key: ValueKey(_items[i].exerciseId),
        draft: _items[i],
        index: i,
        onRemove: () => _removeItem(i),
        onChanged: () => setState(() {}),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'Saving…' : 'Save Program'),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Item card
// ════════════════════════════════════════════════════════════════════════════

class _ItemCard extends StatefulWidget {
  final _DraftItem draft;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemCard({
    super.key,
    required this.draft,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.draft.customNote);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.drag_handle_rounded,
                    color: AppColors.textSecondary, size: 22),
              ),
            ),
            ExerciseImage(
              photoFilename: d.photoFilename,
              exerciseName: d.nameEn,
              region: d.region,
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(d.nameEn,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${d.region} · ${Exercise.formatHoldSec(d.holdSec)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.remove_circle_outline_rounded,
                  color: AppColors.error, size: 22),
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 8, children: [
            _counter('Sets', d.sets, 1, 10,
                (v) { d.sets = v; widget.onChanged(); }),
            _counter('Reps', d.reps, 1, 50,
                (v) { d.reps = v; widget.onChanged(); }),
            _counter('Hold (s)', d.holdSec, 0, 600,
                (v) { d.holdSec = v; widget.onChanged(); }),
            _counter('Freq/wk', d.freqPerWeek, 1, 7,
                (v) { d.freqPerWeek = v; widget.onChanged(); }),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            onChanged: (v) { d.customNote = v; widget.onChanged(); },
            decoration: const InputDecoration(
              hintText: 'Custom note for this exercise (optional)',
              hintStyle: TextStyle(fontSize: 12),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
          ),
        ]),
      ),
    );
  }

  Widget _counter(String label, int value, int min, int max,
      ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Container(
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _iconBtn(Icons.remove_rounded,
                () => onChanged((value - 1).clamp(min, max))),
            SizedBox(
              width: 34,
              child: _NumberInput(
                value: value, min: min, max: max, onChanged: onChanged),
            ),
            _iconBtn(Icons.add_rounded,
                () => onChanged((value + 1).clamp(min, max))),
          ]),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 28, height: 32,
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _NumberInput extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberInput({
    required this.value, required this.min,
    required this.max, required this.onChanged,
  });

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_NumberInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _ctrl.text = '${widget.value}';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null) widget.onChanged(n.clamp(widget.min, widget.max));
      },
    );
  }
}
