import 'dart:convert';
import 'package:flutter/services.dart';
import 'models/assessment_models.dart';

class AssessmentLibraryRepository {
  static AssessmentLibrary? _cached;

  static Future<AssessmentLibrary> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle
        .loadString('assets/data/assessment_library.json');
    _cached = AssessmentLibrary.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    return _cached!;
  }
}
