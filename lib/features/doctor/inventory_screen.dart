import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/language_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _supabase = Supabase.instance.client;
  final _uid = Supabase.instance.client.auth.currentUser!.id;

  final _categories = ['Equipment', 'Consumable', 'Supply', 'Medication'];
  final _units = ['pieces', 'boxes', 'sets', 'rolls', 'bottles', 'packs'];

  void _showAddItem(AppStrings s, {Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(
        text: existing != null ? (existing['name'] ?? '') : '');
    final qtyCtrl = TextEditingController(
        text: existing != null ? '${existing['quantity'] ?? 0}' : '');
    final minCtrl = TextEditingController(
        text: existing != null ? '${existing['min_quantity'] ?? 5}' : '5');
    final notesCtrl = TextEditingController(
        text: existing != null ? (existing['notes'] ?? '') : '');
    String category = existing != null
        ? (existing['category'] ?? _categories.first)
        : _categories.first;
    String unit =
        existing != null ? (existing['unit'] ?? _units.first) : _units.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing != null ? s.edit : s.addItem,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _sheetField(nameCtrl, s.itemName, Icons.inventory_2_outlined),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: InputDecoration(
                        labelText: s.category,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setLocal(() => category = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: InputDecoration(
                        labelText: s.unit,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _units
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setLocal(() => unit = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _sheetField(qtyCtrl, s.quantity, Icons.numbers,
                          type: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _sheetField(
                          minCtrl, s.minQuantity, Icons.warning_amber_rounded,
                          type: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final data = {
                        'doctor_id': _uid,
                        'name': nameCtrl.text.trim(),
                        'category': category,
                        'unit': unit,
                        'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 0,
                        'min_quantity':
                            int.tryParse(minCtrl.text.trim()) ?? 5,
                        'notes': notesCtrl.text.trim(),
                        'updated_at': DateTime.now().toIso8601String(),
                      };
                      if (existing != null) {
                        await _supabase
                            .from('inventory')
                            .update(data)
                            .eq('id', existing['id'] as String);
                      } else {
                        data['created_at'] = DateTime.now().toIso8601String();
                        await _supabase.from('inventory').insert(data);
                      }
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    },
                    child: Text(s.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _deleteItem(String id) async {
    await _supabase.from('inventory').delete().eq('id', id);
  }

  Future<void> _adjustQty(String id, int current, int delta) async {
    final newQty = (current + delta).clamp(0, 9999);
    await _supabase.from('inventory').update({'quantity': newQty}).eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<LanguageProvider>().isArabic);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s.clinicInventory),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('inventory')
            .stream(primaryKey: ['id'])
            .eq('doctor_id', _uid)
            .order('name'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data ?? [];
          final lowStock = docs.where((data) {
            return (data['quantity'] as int? ?? 0) <
                (data['min_quantity'] as int? ?? 5);
          }).length;

          return Column(
            children: [
              if (lowStock > 0)
                Container(
                  margin: const EdgeInsets.all(12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning),
                    const SizedBox(width: 10),
                    Text(
                      '$lowStock item${lowStock > 1 ? 's' : ''} running ${s.lowStock.toLowerCase()}',
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              if (docs.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(s.noData,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ]),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data = docs[i];
                      final qty = data['quantity'] as int? ?? 0;
                      final minQty = data['min_quantity'] as int? ?? 5;
                      final isLow = qty < minQty;
                      final docId = data['id'] as String;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isLow
                                    ? AppColors.warning.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _categoryIcon(data['category'] ?? ''),
                                color: isLow
                                    ? AppColors.warning
                                    : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  Text(
                                    '${data['category'] ?? ''} · ${data['unit'] ?? ''}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12),
                                  ),
                                  if (isLow)
                                    Text(s.lowStock,
                                        style: const TextStyle(
                                            color: AppColors.warning,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Row(children: [
                              _qtyBtn(Icons.remove, () =>
                                  _adjustQty(docId, qty, -1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Text('$qty',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isLow
                                            ? AppColors.warning
                                            : AppColors.textPrimary)),
                              ),
                              _qtyBtn(Icons.add, () =>
                                  _adjustQty(docId, qty, 1)),
                            ]),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _showAddItem(s, existing: data);
                                } else {
                                  _deleteItem(docId);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'edit', child: Text(s.edit)),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text(s.delete,
                                        style: const TextStyle(
                                            color: AppColors.error))),
                              ],
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_inventory',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(s.addItem),
        onPressed: () => _showAddItem(s),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Equipment':
        return Icons.medical_services_rounded;
      case 'Consumable':
        return Icons.inventory_rounded;
      case 'Medication':
        return Icons.medication_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
