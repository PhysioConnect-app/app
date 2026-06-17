import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import 'store_manager_service.dart';

const _kStoreColor = Color(0xFF00838F);

class StoreManagerCategoriesScreen extends StatefulWidget {
  const StoreManagerCategoriesScreen({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<StoreManagerCategoriesScreen> createState() =>
      _StoreManagerCategoriesScreenState();
}

class _StoreManagerCategoriesScreenState
    extends State<StoreManagerCategoriesScreen> {
  final _svc = StoreManagerService();
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String? _error;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await _svc.getAllCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _loading = false;
      });
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _roots =>
      _categories.where((c) => c['parent_id'] == null).toList();

  List<Map<String, dynamic>> _childrenOf(String parentId) =>
      _categories.where((c) => c['parent_id'] == parentId).toList();

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();

    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          _roots.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: _roots.length,
                    itemBuilder: (_, i) => _buildRootCard(_roots[i]),
                  ),
                ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              backgroundColor: _kStoreColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Category'),
              onPressed: () => _openForm(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No categories yet\nAdd your first category to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kStoreColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _openForm(context),
            ),
          ],
        ),
      );

  Widget _buildRootCard(Map<String, dynamic> cat) {
    final id = cat['id'] as String;
    final children = _childrenOf(id);
    final isExpanded = _expanded.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: Colors.white,
      child: Column(
        children: [
          _buildCatRow(
            cat: cat,
            depth: 0,
            expandWidget: children.isEmpty
                ? const SizedBox(width: 40)
                : IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                    ),
                    splashRadius: 18,
                    onPressed: () => setState(() {
                      if (isExpanded) {
                        _expanded.remove(id);
                      } else {
                        _expanded.add(id);
                      }
                    }),
                  ),
          ),
          if (children.isNotEmpty && isExpanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...children.map((c) => _buildCatRow(cat: c, depth: 1)),
          ],
        ],
      ),
    );
  }

  Widget _buildCatRow({
    required Map<String, dynamic> cat,
    required int depth,
    Widget? expandWidget,
  }) {
    final published = cat['status'] == 'published';
    final isMobile =
        MediaQuery.sizeOf(context).width < kMobileBreakpoint;

    final Widget actions;
    if (isMobile) {
      // On narrow screens a row of 3–4 buttons overflows; collapse to a menu.
      actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expandWidget != null) expandWidget,
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'toggle') _toggleStatus(cat);
              if (v == 'edit') _openForm(context, existing: cat);
              if (v == 'delete') _confirmDelete(cat);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(
                    published
                        ? Icons.visibility_off_rounded
                        : Icons.publish_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Text(published ? 'Unpublish' : 'Publish'),
                ]),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  const Icon(Icons.edit_rounded,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Text('Edit'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_rounded,
                      size: 18, color: AppColors.error),
                  const SizedBox(width: 12),
                  const Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      );
    } else {
      actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _publishBtn(published, () => _toggleStatus(cat)),
          _iconBtn(
            Icons.edit_rounded,
            AppColors.textSecondary,
            'Edit',
            () => _openForm(context, existing: cat),
          ),
          _iconBtn(
            Icons.delete_rounded,
            AppColors.error,
            'Delete',
            () => _confirmDelete(cat),
          ),
          if (expandWidget != null) expandWidget,
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: depth == 0
              ? _kStoreColor.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          child: Icon(
            depth == 0
                ? Icons.category_rounded
                : Icons.subdirectory_arrow_right_rounded,
            size: 18,
            color: depth == 0 ? _kStoreColor : AppColors.textSecondary,
          ),
        ),
        title: Text(
          cat['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            _statusChip(published),
            const SizedBox(width: 8),
            Text(
              'Sort: ${cat['sort_order']}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: actions,
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onPressed,
  ) =>
      Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 20, color: color),
          splashRadius: 18,
          onPressed: onPressed,
        ),
      );

  Widget _publishBtn(bool published, VoidCallback onTap) {
    if (published) {
      return Tooltip(
        message: 'Tap to unpublish',
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2E7D32),
            backgroundColor: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          onPressed: onTap,
          child: const Text('Published'),
        ),
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _kStoreColor,
        side: const BorderSide(color: _kStoreColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: onTap,
      child: const Text('Publish'),
    );
  }

  Widget _statusChip(bool published) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color:
              published ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          published ? 'Published' : 'Draft',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: published
                ? const Color(0xFF2E7D32)
                : const Color(0xFFE65100),
          ),
        ),
      );

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _toggleStatus(Map<String, dynamic> cat) async {
    final newStatus = cat['status'] == 'published' ? 'draft' : 'published';
    try {
      await _svc.updateCategory(cat['id'] as String, {'status': newStatus});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> cat) async {
    final children = _childrenOf(cat['id'] as String);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          children.isNotEmpty
              ? 'Deleting "${cat['name']}" will also delete '
                  '${children.length} '
                  'subcategor${children.length == 1 ? 'y' : 'ies'} and all '
                  'their products. This cannot be undone.'
              : 'Delete "${cat['name']}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _svc.deleteCategory(cat['id'] as String);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _openForm(BuildContext ctx, {Map<String, dynamic>? existing}) {
    showDialog(
      context: ctx,
      builder: (_) => _CategoryFormDialog(
        svc: _svc,
        existing: existing,
        allRoots: _roots,
        onSaved: _load,
      ),
    );
  }
}

// ── Category form dialog ─────────────────────────────────────────────────────

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.svc,
    this.existing,
    required this.allRoots,
    required this.onSaved,
  });

  final StoreManagerService svc;
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> allRoots;
  final VoidCallback onSaved;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.existing?['name'] as String? ?? '');
  late final _sortCtrl = TextEditingController(
      text: (widget.existing?['sort_order'] ?? 0).toString());
  late String? _parentId =
      widget.existing?['parent_id'] as String?;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;

  // Only root categories can be parents (2-level max).
  // Exclude self to prevent a root from becoming its own parent.
  List<Map<String, dynamic>> get _parentOptions {
    final selfId = widget.existing?['id'] as String?;
    return widget.allRoots.where((c) => c['id'] != selfId).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.svc.updateCategory(widget.existing!['id'] as String, {
          'name': _nameCtrl.text.trim(),
          'parent_id': _parentId,
          'sort_order': int.tryParse(_sortCtrl.text) ?? 0,
        });
      } else {
        await widget.svc.createCategory(
          name: _nameCtrl.text.trim(),
          parentId: _parentId,
          sortOrder: int.tryParse(_sortCtrl.text) ?? 0,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.sizeOf(context).width < kMobileBreakpoint;

    final form = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _parentId,
            decoration: const InputDecoration(
              labelText: 'Parent category',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('None — root category'),
              ),
              ..._parentOptions.map(
                (c) => DropdownMenuItem<String?>(
                  value: c['id'] as String,
                  child: Text(c['name'] as String),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _parentId = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sortCtrl,
            decoration: const InputDecoration(
              labelText: 'Sort order',
              border: OutlineInputBorder(),
              helperText: 'Lower numbers appear first',
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (int.tryParse(v) == null) return 'Must be a whole number';
              return null;
            },
          ),
        ],
      ),
    );

    return AlertDialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      title: Text(_isEditing ? 'Edit Category' : 'Add Category'),
      content: isMobile ? form : SizedBox(width: 380, child: form),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _kStoreColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
