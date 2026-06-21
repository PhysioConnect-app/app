class HepProgram {
  final String id;
  final String doctorId;
  final String patientId;
  final String title;
  final String notesEn;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const HepProgram({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.title,
    required this.notesEn,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory HepProgram.fromJson(Map<String, dynamic> j) => HepProgram(
        id: j['id'] as String,
        doctorId: j['doctor_id'] as String,
        patientId: j['patient_id'] as String,
        title: (j['title'] as String?) ?? '',
        notesEn: (j['notes_en'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'active',
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        deletedAt: j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null,
      );

  bool get isActive => status == 'active' && deletedAt == null;

  HepProgram copyWith({String? title, String? notesEn, String? status}) =>
      HepProgram(
        id: id,
        doctorId: doctorId,
        patientId: patientId,
        title: title ?? this.title,
        notesEn: notesEn ?? this.notesEn,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        deletedAt: deletedAt,
      );
}
