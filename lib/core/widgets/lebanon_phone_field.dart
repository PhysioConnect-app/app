import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A phone-number field with the Lebanon country code (`+961`) locked as a
/// fixed prefix. The [controller] holds only the local digits (no `+961`).
///
/// Use [LebanonPhoneField.stripCountryCode] when loading a stored number into
/// the controller, and [LebanonPhoneField.toStored] when saving it back.
class LebanonPhoneField extends StatelessWidget {
  const LebanonPhoneField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  /// Strips a leading `+961`, `00961` or `961` country code (and any
  /// remaining leading zero) from a stored number, leaving local digits.
  static String stripCountryCode(String stored) {
    var digits = stored.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('00961')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('961')) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Prepends `+961` to the local digits for storage. Returns an empty
  /// string if [local] has no digits.
  static String toStored(String local) {
    final digits = local.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    return '+961$digits';
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '+961 ',
        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}
