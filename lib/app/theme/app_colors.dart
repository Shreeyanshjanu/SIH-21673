import 'package:flutter/material.dart';

/// Design tokens extracted directly from the Stitch Tactical UI spec (Project: 5419439453024560028).
abstract final class AppColors {
  // --- Dark Tactical Foundations (Default Mission Mode) ---
  static const Color background = Color(0xFF0F131C);
  static const Color surface = Color(0xFF0F131C);
  static const Color surfaceDim = Color(0xFF0A0E16);
  static const Color surfaceContainerLowest = Color(0xFF06090E);
  static const Color surfaceContainerLow = Color(0xFF131B26);
  static const Color surfaceContainer = Color(0xFF181C24);
  static const Color surfaceContainerHigh = Color(0xFF1C2636);
  static const Color surfaceContainerHighest = Color(0xFF262A33);
  static const Color surfaceBright = Color(0xFF353942);

  // Text & Outline
  static const Color onSurface = Color(0xFFDFE2EE);
  static const Color onSurfaceVariant = Color(0xFF94A3B8);
  static const Color outline = Color(0xFF2D3D54);
  static const Color outlineVariant = Color(0xFF475569);

  // Tactical Primary (Signal Amber / Orange)
  static const Color primary = Color(0xFFF97316);
  static const Color onPrimary = Color(0xFF341100);
  static const Color primaryContainer = Color(0xFF783200);
  static const Color onPrimaryContainer = Color(0xFFFFDBCA);
  static const Color primaryDim = Color(0xFFFFB690);

  // Telemetry Secondary (Electric Cyan)
  static const Color secondary = Color(0xFF06B6D4);
  static const Color onSecondary = Color(0xFF003640);
  static const Color secondaryContainer = Color(0xFF004E5C);
  static const Color onSecondaryContainer = Color(0xFFACEDFF);
  static const Color secondaryDim = Color(0xFF4CD7F6);

  // Safe Mission Tertiary (Field Green)
  static const Color tertiary = Color(0xFF10B981);
  static const Color onTertiary = Color(0xFF003824);
  static const Color tertiaryContainer = Color(0xFF005236);
  static const Color onTertiaryContainer = Color(0xFF6FFBBE);
  static const Color tertiaryFixed = Color(0xFF7FFC97);
  static const Color onTertiaryFixed = Color(0xFF002109);

  // Emergency Threat / Alert (Crimson)
  static const Color error = Color(0xFFEF4444);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // --- Daylight High-Contrast Foundations (Field Sunlight Mode) ---
  static const Color lightSurface = Color(0xFFF7F9FB);
  static const Color lightSurfaceContainerLow = Color(0xFFF2F4F6);
  static const Color lightSurfaceContainer = Color(0xFFECEEF0);
  static const Color lightSurfaceContainerHigh = Color(0xFFE0E3E5);
  static const Color lightOnSurface = Color(0xFF191C1E);
  static const Color lightOnSurfaceVariant = Color(0xFF45474B);
  static const Color lightOutline = Color(0xFFC6C6CB);
}