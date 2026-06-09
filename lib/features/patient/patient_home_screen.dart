import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'patient_service.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final _patientService = PatientService();

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content:
            const Text("Are you sure you want to sign out of your portal?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
            },
            child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("My Patient Portal"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _showLogoutDialog,
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.medical_services), text: "My Care Plan"),
              Tab(icon: Icon(Icons.person_search), text: "Browse Doctors"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: CARE PLAN (Notes & Appointments)
            RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Upcoming Scheduled Sessions",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _patientService.getMyAppointments(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Card(
                            color: Colors.red.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                  "Error syncing calendar: ${snapshot.error}"),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: LinearProgressIndicator());
                        }
                        final appointments = snapshot.data!;

                        if (appointments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              "No upcoming appointments blocked out yet.",
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: appointments.length,
                          itemBuilder: (context, index) {
                            final appt = appointments[index];
                            final tsStr = appt['appointment_time'] as String?;
                            final date = tsStr != null
                                ? DateTime.parse(tsStr)
                                : DateTime.now();
                            return Card(
                              child: ListTile(
                                leading:
                                    const Icon(Icons.event, color: Colors.blue),
                                title: Text(
                                    "Session on ${date.day}/${date.month}/${date.year}"),
                                subtitle: Text(
                                    "Time: ${date.hour}:${date.minute.toString().padLeft(2, '0')}\nNotes: ${appt['notes'] ?? ''}"),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text("Clinical Notes & Progress Logs",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _patientService.getMyClinicalNotes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                              "Error pulling notes log: ${snapshot.error}");
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final notes = snapshot.data!;
                        if (notes.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                                "No health summary notes published yet.",
                                style: TextStyle(color: Colors.grey)),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        "From: Dr. ${note['patient_name'] ?? 'Clinic Practitioner'}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue)),
                                    const SizedBox(height: 6),
                                    Text(note['text_note'] ?? '',
                                        style: const TextStyle(fontSize: 15)),
                                    if (note['reference_link'] != null &&
                                        note['reference_link']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                          "🔗 Video Link: ${note['reference_link']}",
                                          style: const TextStyle(
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline))
                                    ],
                                    if (note['photo_url'] != null &&
                                        note['photo_url']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(note['photo_url'],
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                const SizedBox.shrink()),
                                      )
                                    ]
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // TAB 2: BROWSE CLINIC DOCTORS
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Clinic Medical Staff Directory",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text(
                      "Select a practitioner to link them directly to your personal portal care team.",
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _patientService.getAllAvailableDoctors(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final doctors = snapshot.data!;

                        if (doctors.isEmpty) {
                          return const Center(
                              child: Text(
                                  "No registered doctors found in the database."));
                        }

                        return ListView.builder(
                          itemCount: doctors.length,
                          itemBuilder: (context, index) {
                            final doc = doctors[index];
                            final docId = doc['id'] as String;
                            final photoUrl = doc['profile_photo_url'] as String? ?? '';

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blueGrey.shade100,
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                    "Dr. ${doc['name'] ?? 'Professional'}"),
                                subtitle: Text(doc['bio'] != null &&
                                        doc['bio'].toString().isNotEmpty
                                    ? doc['bio']
                                    : "General Care Practitioner"),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    bool success = await _patientService
                                        .linkToDoctor(docId);
                                    if (context.mounted && success) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "Doctor added to your care team successfully!"),
                                              backgroundColor: Colors.green));
                                    }
                                  },
                                  child: const Text("Select"),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
