import 'package:flutter/material.dart';

/// App Color Palette
/// A sophisticated, nature-inspired color scheme for the Ayurveda Academy app
/// Avoiding trendy AI gradients, focusing on calming, professional tones
class AppColors {
  AppColors._();

  // Primary Colors - Sage Green (calming, natural, trustworthy)
  static const Color primaryGreen = Color(0xFF6B8E6F);
  static const Color primaryGreenLight = Color(0xFF8FAA92);
  static const Color primaryGreenDark = Color(0xFF4A6B4D);

  // Secondary Colors - Warm Earth Tones
  static const Color secondaryBeige = Color(0xFFF5EFE6);
  static const Color secondaryBrown = Color(0xFF8B7355);
  static const Color terracotta = Color(0xFFB87E6E);

  // Accent Colors
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color accentTeal = Color(0xFF5C9EAD);

  // Neutral Colors
  static const Color backgroundLight = Color(0xFFFAF9F6);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F5F0);
  static const Color surfaceDark = Color(0xFF2C2C2C);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Border Colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFEEEEEE);

  // Shadow Colors
  static const Color shadowLight = Color(0x0F000000);
  static const Color shadowMedium = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreenLight, primaryGreen],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F8F8)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentTeal, Color(0xFF4A8896)],
  );

  // Overlay Colors
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2A2A2A);
}
