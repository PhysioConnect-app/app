import 'exercise.dart';

class HepItem {
  final String id;
  final String hepId;
  final String exerciseId;
  final int sets;
  final int reps;
  final int holdSec;
  final int freqPerWeek;
  final String customNoteEn;
  final int sortOrder;

  const HepItem({
    required this.id,
    required this.hepId,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.holdSec,
    required this.freqPerWeek,
    required this.customNoteEn,
    required this.sortOrder,
  });

  factory HepItem.fromJson(Map<String, dynamic> j) => HepItem(
        id: j['id'] as String,
        hepId: j['hep_id'] as String,
        exerciseId: j['exercise_id'] as String,
        sets: (j['sets'] as int?) ?? 3,
        reps: (j['reps'] as int?) ?? 10,
        holdSec: (j['hold_sec'] as int?) ?? 2,
        freqPerWeek: (j['freq_per_week'] as int?) ?? 7,
        customNoteEn: (j['custom_note_en'] as String?) ?? '',
        sortOrder: (j['sort_order'] as int?) ?? 0,
      );

  Map<String, dynamic> toInsertMap(String hepId) => {
        'hep_id': hepId,
        'exercise_id': exerciseId,
        'sets': sets,
        'reps': reps,
        'hold_sec': holdSec,
        'freq_per_week': freqPerWeek,
        'custom_note_en': customNoteEn,
        'sort_order': sortOrder,
      };

  Map<String, dynamic> toUpdateMap() => {
        'sets': sets,
        'reps': reps,
        'hold_sec': holdSec,
        'freq_per_week': freqPerWeek,
        'custom_note_en': customNoteEn,
        'sort_order': sortOrder,
      };

  HepItem copyWith({
    int? sets,
    int? reps,
    int? holdSec,
    int? freqPerWeek,
    String? customNoteEn,
    int? sortOrder,
  }) =>
      HepItem(
        id: id,
        hepId: hepId,
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        holdSec: holdSec ?? this.holdSec,
        freqPerWeek: freqPerWeek ?? this.freqPerWeek,
        customNoteEn: customNoteEn ?? this.customNoteEn,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  /// Human-readable dose line: "3 sets × 10 reps · hold 2s · 7×/wk"
  String get doseLabel {
    final holdStr = Exercise.formatHoldSec(holdSec);
    return '$sets sets × $reps reps · $holdStr · $freqPerWeek×/wk';
  }
}
