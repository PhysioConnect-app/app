import 'package:flutter/material.dart';

/// Brand wordmark for PhysioConnect.
/// Renders the "PhysioConnect" lettermark as styled text — no card,
/// no border, no baked-in asset artifacts. Use everywhere the logo
/// appears in-app (login, app bars, drawers, empty states).
class PhysioLogo extends StatelessWidget {
  const PhysioLogo({
    super.key,
    this.fontSize = 32,
    this.showTagline = false,
    this.alignment = MainAxisAlignment.center,
  });

  /// Height of the wordmark text in logical pixels.
  final double fontSize;

  /// Whether to show "The All-in-One Physical Therapy Platform" beneath.
  final bool showTagline;

  final MainAxisAlignment alignment;

  // Brand palette
  static const Color _blue = Color(0xFF2574D4);
  static const Color _teal = Color(0xFF1FA6A0); // mid blend in the wordmark
  static const Color _green = Color(0xFF4CA64F);
  static const Color _tagline = Color(0xFF7A7A7A);

  @override
  Widget build(BuildContext context) {
    final weight = FontWeight.w800;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gradient applied across the whole wordmark for the blue→green flow.
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_blue, _teal, _green],
            stops: [0.0, 0.5, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'PhysioConnect',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              letterSpacing: -0.5,
              height: 1.0,
              color: Colors.white, // masked by the gradient
            ),
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: fontSize * 0.18),
          Text(
            'The All-in-One Physical Therapy Platform',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize * 0.34,
              fontWeight: FontWeight.w500,
              color: _tagline,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}
