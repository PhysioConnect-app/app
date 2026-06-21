class Exercise {
  final String id;
  final String region;
  final String category;
  final String nameEn;
  final List<String> conditions;
  final List<String> muscles;
  final int defaultSets;
  final int defaultReps;
  final int defaultHoldSec;
  final int defaultFreqPerWeek;
  final String descriptionEn;
  final String photoFilename;

  const Exercise({
    required this.id,
    required this.region,
    required this.category,
    required this.nameEn,
    required this.conditions,
    required this.muscles,
    required this.defaultSets,
    required this.defaultReps,
    required this.defaultHoldSec,
    required this.defaultFreqPerWeek,
    required this.descriptionEn,
    required this.photoFilename,
  });

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as String,
        region: j['region'] as String,
        category: j['category'] as String,
        nameEn: j['name_en'] as String,
        conditions: (j['conditions'] as List).cast<String>(),
        muscles: (j['muscles'] as List).cast<String>(),
        defaultSets: j['default_sets'] as int,
        defaultReps: j['default_reps'] as int,
        defaultHoldSec: j['default_hold_sec'] as int,
        defaultFreqPerWeek: j['default_freq_per_week'] as int,
        descriptionEn: j['description_en'] as String,
        photoFilename: j['photo_filename'] as String,
      );

  /// Formats the hold/duration value for display.
  /// ≥60 s → "X min [Ys]";  <60 s → "hold Xs".
  static String formatHoldSec(int holdSec) {
    if (holdSec >= 60) {
      final mins = holdSec ~/ 60;
      final secs = holdSec % 60;
      return secs == 0 ? '$mins min' : '$mins min ${secs}s';
    }
    return 'hold ${holdSec}s';
  }

  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
