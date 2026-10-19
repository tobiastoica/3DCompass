import 'package:flutter/material.dart';

/// Semantic color palette for 3D Compass navigation and HUD elements.
abstract class AppColors {
  /// Primary neon cyan accent for compass pointers and active paths.
  static const Color cyanAccent = Color(0xFF00E5FF);

  /// Deep slate background for high-contrast indoor HUD visibility.
  static const Color backgroundDark = Color(0xFF0F172A);

  /// Surface card dark blue container.
  static const Color surfaceDark = Color(0xFF1E293B);

  /// Secondary electric cobalt for route highlights.
  static const Color cobaltBlue = Color(0xFF2563EB);

  /// Emerald green for calibrated status and verified entrance doorways.
  static const Color emeraldGreen = Color(0xFF10B981);

  /// Amber warning for faint GPS and weak sensor confidence.
  static const Color amberWarning = Color(0xFFF59E0B);

  /// Coral red for invalid paths or uncalibrated warnings.
  static const Color coralRed = Color(0xFFEF4444);
}
