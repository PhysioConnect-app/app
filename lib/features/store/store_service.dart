import 'package:supabase_flutter/supabase_flutter.dart';

class StoreService {
  final _db = Supabase.instance.client;

  /// Published root categories (parent_id IS NULL).
  /// RLS already filters to published rows; the client-side null check
  /// isolates root categories without a PostgREST IS NULL query.
  Future<List<Map<String, dynamic>>> getRootCategories() async {
    final data = await _db
        .from('store_categories')
        .select()
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(data)
        .where((c) => c['parent_id'] == null)
        .toList();
  }

  /// Published subcategories of [parentId].
  Future<List<Map<String, dynamic>>> getSubcategories(String parentId) async {
    final data = await _db
        .from('store_categories')
        .select()
        .eq('parent_id', parentId)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Published products in [categoryId].
  Future<List<Map<String, dynamic>>> getProducts(String categoryId) async {
    final data = await _db
        .from('store_products')
        .select()
        .eq('category_id', categoryId)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }
}
