import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography system balancing Space Grotesk, Plus Jakarta Sans, and JetBrains Mono.
abstract final class AppTypography {
  // Display & Headers (Space Grotesk)
  static final TextStyle displayLg = GoogleFonts.spaceGrotesk(
    fontSize: 32,
    height: 1.2,
    letterSpacing: -0.02,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static final TextStyle headlineLg = GoogleFonts.spaceGrotesk(
    fontSize: 24,
    height: 1.3,
    letterSpacing: -0.01,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  static final TextStyle headlineMd = GoogleFonts.spaceGrotesk(
    fontSize: 18,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static final TextStyle headlineSm = GoogleFonts.spaceGrotesk(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  static final TextStyle labelCaps = GoogleFonts.spaceGrotesk(
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.08,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );

  // Body Prose (Plus Jakarta Sans)
  static final TextStyle bodyLg = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );

  static final TextStyle bodyMd = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  static final TextStyle bodySm = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurfaceVariant,
  );

  // Monospace Telemetry (JetBrains Mono)
  static final TextStyle telemetryLg = GoogleFonts.jetBrainsMono(
    fontSize: 15,
    height: 1.3,
    letterSpacing: 0.03,
    fontWeight: FontWeight.w600,
    color: AppColors.secondary,
  );

  static final TextStyle telemetryMd = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    height: 1.3,
    letterSpacing: 0.02,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );

  static final TextStyle telemetrySm = GoogleFonts.jetBrainsMono(
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.05,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurfaceVariant,
  );
}