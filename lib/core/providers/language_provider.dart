import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  bool _isArabic = false;

  bool get isArabic => _isArabic;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isArabic = prefs.getBool('isArabic') ?? false;
    Intl.defaultLocale = _isArabic ? 'ar' : 'en';
    notifyListeners();
  }

  Future<void> toggle() async {
    _isArabic = !_isArabic;
    Intl.defaultLocale = _isArabic ? 'ar' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isArabic', _isArabic);
    notifyListeners();
  }
}
