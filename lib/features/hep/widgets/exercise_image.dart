import 'package:flutter/material.dart';

/// Displays an exercise photo from assets/exercises/images/{photoFilename}.
///
/// Drop-in convention: placing a PNG/JPG named exactly as [photoFilename]
/// into that folder makes it appear automatically — no code changes needed.
/// When the asset is absent the widget renders a region-tinted icon placeholder.
///
/// Used in both the doctor HEP builder and the patient read-only view.
class ExerciseImage extends StatelessWidget {
  final String photoFilename;
  final String exerciseName;
  final String region;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ExerciseImage({
    super.key,
    required this.photoFilename,
    required this.exerciseName,
    required this.region,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  static const _prefix = 'assets/exercises/images/';

  static const _regionTheme = <String, (IconData, Color)>{
    'Cervical':     (Icons.accessibility_new_rounded, Color(0xFF5C6BC0)),
    'Thoracic':     (Icons.spa_rounded,               Color(0xFF26A69A)),
    'Lumbar':       (Icons.self_improvement_rounded,  Color(0xFF8D6E63)),
    'Shoulder':     (Icons.accessibility_rounded,     Color(0xFF42A5F5)),
    'Elbow':        (Icons.sports_handball_rounded,   Color(0xFFEF5350)),
    'Hip':          (Icons.directions_run_rounded,    Color(0xFFAB47BC)),
    'Knee':         (Icons.sports_soccer_rounded,     Color(0xFF66BB6A)),
    'Wrist & Hand': (Icons.pan_tool_rounded,          Color(0xFFFFA726)),
    'Ankle':        (Icons.directions_walk_rounded,   Color(0xFF26C6DA)),
  };

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      '$_prefix$photoFilename',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _Placeholder(
        exerciseName: exerciseName,
        region: region,
        width: width,
        height: height,
      ),
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}

class _Placeholder extends StatelessWidget {
  final String exerciseName;
  final String region;
  final double? width;
  final double? height;

  const _Placeholder({
    required this.exerciseName,
    required this.region,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = ExerciseImage._regionTheme[region] ??
        (Icons.fitness_center_rounded, const Color(0xFF00897B));
    final h = height ?? 80;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: h * 0.38, color: color),
          if (h > 56) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                exerciseName,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
