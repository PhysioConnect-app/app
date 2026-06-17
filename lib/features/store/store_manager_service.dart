import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreManagerService {
  final _db = Supabase.instance.client;
  final _storage = Supabase.instance.client.storage;

  // ── Categories ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final data = await _db
        .from('store_categories')
        .select()
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createCategory({
    required String name,
    String? parentId,
    int sortOrder = 0,
  }) async {
    await _db.from('store_categories').insert({
      'name': name,
      if (parentId != null) 'parent_id': parentId,
      'sort_order': sortOrder,
      'status': 'draft',
    });
  }

  Future<void> updateCategory(String id, Map<String, dynamic> fields) async {
    await _db
        .from('store_categories')
        .update({...fields, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _db.from('store_categories').delete().eq('id', id);
  }

  // ── Products ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final data = await _db
        .from('store_products')
        .select('*, store_categories(name)')
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createProduct(Map<String, dynamic> fields) async {
    await _db.from('store_products').insert(fields);
  }

  Future<void> updateProduct(String id, Map<String, dynamic> fields) async {
    await _db
        .from('store_products')
        .update({...fields, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _db.from('store_products').delete().eq('id', id);
  }

  // ── Image upload ─────────────────────────────────────────────────────────────
  // Mirrors the _uploadProfilePhoto pattern from doctor_dashboard_screen.dart:
  // pick → readAsBytes → uploadBinary with FileOptions(upsert: true) → getPublicUrl.

  Future<String?> pickAndUploadImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final fileName = 'products/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _storage.from('store-products').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return _storage.from('store-products').getPublicUrl(fileName);
  }
}
