import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A "Select Patient" field that lets the doctor filter the patient list
/// by typing part of the patient's name, instead of scrolling a plain
/// dropdown.
class PatientSearchField extends StatelessWidget {
  const PatientSearchField({
    super.key,
    required this.patients,
    required this.labelText,
    required this.onSelected,
    this.controller,
    this.fillColor = Colors.white,
  });

  /// Each entry is expected to have an `id` and a `name` and/or `email`.
  final List<Map<String, dynamic>> patients;
  final String labelText;
  final void Function(String id, String name) onSelected;
  final TextEditingController? controller;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      controller: controller,
      enableFilter: true,
      requestFocusOnTap: true,
      expandedInsets: EdgeInsets.zero,
      label: Text(labelText),
      leadingIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: fillColor,
      ),
      dropdownMenuEntries: patients.map((p) {
        final id   = p['id'] as String;
        final name = (p['name'] as String?) ?? (p['email'] as String?) ?? id;
        return DropdownMenuEntry<String>(value: id, label: name);
      }).toList(),
      onSelected: (id) {
        if (id == null) return;
        Map<String, dynamic>? match;
        for (final p in patients) {
          if (p['id'] == id) {
            match = p;
            break;
          }
        }
        final name = (match?['name'] as String?) ??
            (match?['email'] as String?) ?? id;
        onSelected(id, name);
      },
    );
  }
}
