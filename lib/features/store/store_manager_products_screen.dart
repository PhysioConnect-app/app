import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'store_manager_service.dart';

const _kStoreColor = Color(0xFF00838F);

class StoreManagerProductsScreen extends StatefulWidget {
  const StoreManagerProductsScreen({super.key});

  @override
  State<StoreManagerProductsScreen> createState() =>
      _StoreManagerProductsScreenState();
}

class _StoreManagerProductsScreenState
    extends State<StoreManagerProductsScreen> {
  final _svc = StoreManagerService();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  String? _filterCategoryId;
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        _svc.getAllProducts(),
        _svc.getAllCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0];
        _categories = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered => _filterCategoryId == null
      ? _products
      : _products
          .where((p) => p['category_id'] == _filterCategoryId)
          .toList();

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();

    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          Column(
            children: [
              if (_categories.isNotEmpty) _buildCategoryFilter(),
              Expanded(
                child: _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _buildProductCard(_filtered[i]),
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              backgroundColor: _kStoreColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
              onPressed: () => _openForm(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _filterChip('All', null),
            ..._categories.map(
              (c) => _filterChip(c['name'] as String, c['id'] as String),
            ),
          ],
        ),
      );

  Widget _filterChip(String label, String? catId) {
    final selected = _filterCategoryId == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: _kStoreColor.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: selected ? _kStoreColor : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        onSelected: (_) => setState(() => _filterCategoryId = catId),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final published = product['status'] == 'published';
    final imageUrl = product['image_url'] as String? ?? '';
    final catName =
        (product['store_categories'] as Map?)?['name'] as String? ?? '—';
    final price = product['price'];
    final currency = product['currency'] as String? ?? 'USD';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgPlaceholder(),
                )
              : _imgPlaceholder(),
        ),
        title: Text(
          product['title'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              catName,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '$currency $price',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                _statusChip(published),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(
              published
                  ? Icons.visibility_off_rounded
                  : Icons.publish_rounded,
              published ? AppColors.textSecondary : _kStoreColor,
              published ? 'Unpublish' : 'Publish',
              () => _toggleStatus(product),
            ),
            _iconBtn(
              Icons.edit_rounded,
              AppColors.textSecondary,
              'Edit',
              () => _openForm(context, existing: product),
            ),
            _iconBtn(
              Icons.delete_rounded,
              AppColors.error,
              'Delete',
              () => _confirmDelete(product),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image_outlined,
            color: Colors.grey.shade300, size: 28),
      );

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

  Widget _statusChip(bool published) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: published
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFF3E0),
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
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _filterCategoryId != null
                  ? 'No products in this category.\nTap + to add one.'
                  : 'No products yet.\nTap + to add one.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _toggleStatus(Map<String, dynamic> product) async {
    final newStatus =
        product['status'] == 'published' ? 'draft' : 'published';
    try {
      await _svc.updateProduct(product['id'] as String, {'status': newStatus});
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

  Future<void> _confirmDelete(Map<String, dynamic> product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
            'Delete "${product['title']}"? This cannot be undone.'),
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
      await _svc.deleteProduct(product['id'] as String);
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
      barrierDismissible: false,
      builder: (_) => _ProductFormDialog(
        svc: _svc,
        existing: existing,
        categories: _categories,
        onSaved: _load,
      ),
    );
  }
}

// ── Product form dialog ──────────────────────────────────────────────────────

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.svc,
    this.existing,
    required this.categories,
    required this.onSaved,
  });

  final StoreManagerService svc;
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onSaved;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final _titleCtrl =
      TextEditingController(text: widget.existing?['title'] as String? ?? '');
  late final _descCtrl = TextEditingController(
      text: widget.existing?['description'] as String? ?? '');
  late final _priceCtrl = TextEditingController(
      text: (widget.existing?['price'] ?? 0).toString());
  late final _phoneCtrl = TextEditingController(
      text: widget.existing?['phone_number'] as String? ?? '');
  late final _waCtrl = TextEditingController(
      text: widget.existing?['whatsapp_number'] as String? ?? '');
  late final _sortCtrl = TextEditingController(
      text: (widget.existing?['sort_order'] ?? 0).toString());

  late String _currency =
      widget.existing?['currency'] as String? ?? 'USD';
  late String? _categoryId =
      widget.existing?['category_id'] as String?;
  late String _imageUrl =
      widget.existing?['image_url'] as String? ?? '';

  bool _uploadingImage = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _uploadingImage = true);
    try {
      final url = await widget.svc.pickAndUploadImage();
      if (url != null && mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final fields = <String, dynamic>{
        'category_id': _categoryId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'currency': _currency,
        'phone_number': _phoneCtrl.text.trim(),
        'whatsapp_number': _waCtrl.text.trim(),
        'image_url': _imageUrl,
        'sort_order': int.tryParse(_sortCtrl.text) ?? 0,
      };

      if (_isEditing) {
        // Editing a published product goes live immediately — status not touched.
        await widget.svc.updateProduct(
            widget.existing!['id'] as String, fields);
      } else {
        await widget.svc.createProduct({...fields, 'status': 'draft'});
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

  // ── Form UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImagePicker(),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                _buildTextField(_titleCtrl, 'Title *', required: true),
                const SizedBox(height: 16),
                _buildTextField(_descCtrl, 'Description', maxLines: 3),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPriceField()),
                    const SizedBox(width: 12),
                    _buildCurrencyDropdown(),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(_phoneCtrl, 'Phone (with country code)'),
                const SizedBox(height: 16),
                _buildTextField(
                    _waCtrl, 'WhatsApp (digits only, e.g. 9613XXXXXX)'),
                const SizedBox(height: 16),
                _buildTextField(
                  _sortCtrl,
                  'Sort order',
                  keyboardType: TextInputType.number,
                  helperText: 'Lower numbers appear first',
                  validator: (v) => int.tryParse(v ?? '') == null
                      ? 'Must be a whole number'
                      : null,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
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
              : Text(_isEditing ? 'Save Changes' : 'Create Product'),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _imageUrl.isNotEmpty;
    return GestureDetector(
      onTap: _uploadingImage ? null : _pickImage,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasImage
              ? _kStoreColor.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? _kStoreColor.withValues(alpha: 0.4) : Colors.grey.shade300,
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: _uploadingImage
            ? const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator()),
              )
            : Row(
                children: [
                  Icon(
                    hasImage
                        ? Icons.check_circle_rounded
                        : Icons.add_photo_alternate_rounded,
                    size: 28,
                    color: hasImage ? _kStoreColor : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasImage ? 'Image uploaded' : 'Add product image',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: hasImage ? _kStoreColor : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasImage ? 'Tap to replace' : 'Tap to pick from gallery',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasImage)
                    const Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.textSecondary),
                ],
              ),
      ),
    );
  }

  Widget _buildCategoryDropdown() => DropdownButtonFormField<String?>(
        initialValue: _categoryId,
        decoration: const InputDecoration(
          labelText: 'Category *',
          border: OutlineInputBorder(),
        ),
        items: widget.categories
            .map((c) => DropdownMenuItem<String?>(
                  value: c['id'] as String,
                  child: Text(c['name'] as String),
                ))
            .toList(),
        validator: (v) => v == null ? 'Category is required' : null,
        onChanged: (v) => setState(() => _categoryId = v),
      );

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? helperText,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: helperText,
          alignLabelWithHint: maxLines > 1,
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null),
      );

  Widget _buildPriceField() => TextFormField(
        controller: _priceCtrl,
        decoration: const InputDecoration(
          labelText: 'Price *',
          border: OutlineInputBorder(),
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Invalid number';
          return null;
        },
      );

  Widget _buildCurrencyDropdown() => DropdownButtonFormField<String>(
        initialValue: _currency,
        decoration: const InputDecoration(
          labelText: 'Currency',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'USD', child: Text('USD')),
          DropdownMenuItem(value: 'LBP', child: Text('LBP')),
          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
        ],
        onChanged: (v) => setState(() => _currency = v!),
      );
}
