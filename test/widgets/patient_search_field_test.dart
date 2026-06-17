import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_telehealth_app/core/widgets/patient_search_field.dart';

void main() {
  final patients = [
    {'id': '1', 'name': 'Alice Smith'},
    {'id': '2', 'name': 'Bob Jones'},
    {'id': '3', 'name': 'Alicia Keys'},
  ];

  testWidgets('typing filters the patient list by name', (tester) async {
    String? selectedId;
    String? selectedName;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PatientSearchField(
          patients: patients,
          labelText: 'Select Patient',
          onSelected: (id, name) {
            selectedId = id;
            selectedName = name;
          },
        ),
      ),
    ));

    // Open the menu and confirm all patients are listed.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('Alicia Keys'), findsOneWidget);

    // Type part of a name and confirm the list is filtered.
    await tester.enterText(find.byType(TextField), 'Ali');
    await tester.pumpAndSettle();
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Alicia Keys'), findsOneWidget);
    expect(find.text('Bob Jones'), findsNothing);

    // Selecting an entry reports both id and name.
    await tester.tap(find.text('Alice Smith'));
    await tester.pumpAndSettle();
    expect(selectedId, '1');
    expect(selectedName, 'Alice Smith');
  });
}
