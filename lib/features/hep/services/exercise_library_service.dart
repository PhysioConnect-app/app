import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';

class ExerciseLibraryService {
  static const _assetPath = 'assets/exercises/exercises.json';
  static List<Exercise>? _cache;

  @visibleForTesting
  static void setTestData(List<Exercise> data) => _cache = data;

  @visibleForTesting
  static void clearCache() => _cache = null;

  static Future<List<Exercise>> _load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_assetPath);
    _cache = (jsonDecode(raw) as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  static Future<List<Exercise>> all() => _load();

  static Future<Exercise?> byId(String id) async {
    final list = await _load();
    for (final e in list) {
      if (e.id == id) return e;
    }
    return null;
  }

  static Future<List<String>> regions() async {
    final list = await _load();
    return (list.map((e) => e.region).toSet().toList())..sort();
  }

  static Future<List<String>> categoriesForRegion(String? region) async {
    final list = await _load();
    final source = region == null ? list : list.where((e) => e.region == region);
    return (source.map((e) => e.category).toSet().toList())..sort();
  }

  static Future<List<String>> conditions() async {
    final list = await _load();
    return (list.expand((e) => e.conditions).toSet().toList())..sort();
  }

  static Future<List<Exercise>> filter({
    String? region,
    String? category,
    String? condition,
    String? query,
  }) async {
    var list = await _load();
    if (region != null && region.isNotEmpty) {
      list = list.where((e) => e.region == region).toList();
    }
    if (category != null && category.isNotEmpty) {
      list = list.where((e) => e.category == category).toList();
    }
    if (condition != null && condition.isNotEmpty) {
      list = list.where((e) => e.conditions.contains(condition)).toList();
    }
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((e) => e.nameEn.toLowerCase().contains(q)).toList();
    }
    return list;
  }
}
