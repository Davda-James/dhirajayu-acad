import 'package:flutter/material.dart';

/// Spacing System
/// Consistent spacing and padding throughout the app
class AppSpacing {
  AppSpacing._();

  // Base Spacing Unit: 4px
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Specific Use Cases
  static const double buttonPaddingVertical = 12.0;
  static const double buttonPaddingHorizontal = 24.0;
  static const double cardPadding = 16.0;
  static const double screenPadding = 16.0;
  static const double sectionSpacing = 24.0;
  static const double listItemSpacing = 12.0;

  // Edge Insets Presets
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);
  static const EdgeInsets paddingLG = EdgeInsets.all(lg);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);

  static const EdgeInsets paddingHorizontalXS = EdgeInsets.symmetric(
    horizontal: xs,
  );
  static const EdgeInsets paddingHorizontalSM = EdgeInsets.symmetric(
    horizontal: sm,
  );
  static const EdgeInsets paddingHorizontalMD = EdgeInsets.symmetric(
    horizontal: md,
  );
  static const EdgeInsets paddingHorizontalLG = EdgeInsets.symmetric(
    horizontal: lg,
  );
  static const EdgeInsets paddingHorizontalXL = EdgeInsets.symmetric(
    horizontal: xl,
  );

  static const EdgeInsets paddingVerticalXS = EdgeInsets.symmetric(
    vertical: xs,
  );
  static const EdgeInsets paddingVerticalSM = EdgeInsets.symmetric(
    vertical: sm,
  );
  static const EdgeInsets paddingVerticalMD = EdgeInsets.symmetric(
    vertical: md,
  );
  static const EdgeInsets paddingVerticalLG = EdgeInsets.symmetric(
    vertical: lg,
  );
  static const EdgeInsets paddingVerticalXL = EdgeInsets.symmetric(
    vertical: xl,
  );

  // Screen Padding
  static const EdgeInsets screenPaddingAll = EdgeInsets.all(screenPadding);
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(
    horizontal: screenPadding,
  );

  // Button Padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    vertical: buttonPaddingVertical,
    horizontal: buttonPaddingHorizontal,
  );

  static const EdgeInsets buttonPaddingSmall = EdgeInsets.symmetric(
    vertical: sm,
    horizontal: md,
  );

  static const EdgeInsets buttonPaddingLarge = EdgeInsets.symmetric(
    vertical: md,
    horizontal: xl,
  );

  // Card Padding
  static const EdgeInsets cardPaddingAll = EdgeInsets.all(cardPadding);

  // List Item Padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: listItemSpacing,
  );

  // Border Radius
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusRound = 999.0;

  static const BorderRadius borderRadiusXS = BorderRadius.all(
    Radius.circular(radiusXS),
  );
  static const BorderRadius borderRadiusSM = BorderRadius.all(
    Radius.circular(radiusSM),
  );
  static const BorderRadius borderRadiusMD = BorderRadius.all(
    Radius.circular(radiusMD),
  );
  static const BorderRadius borderRadiusLG = BorderRadius.all(
    Radius.circular(radiusLG),
  );
  static const BorderRadius borderRadiusXL = BorderRadius.all(
    Radius.circular(radiusXL),
  );
  static const BorderRadius borderRadiusRound = BorderRadius.all(
    Radius.circular(radiusRound),
  );

  // Icon Sizes
  static const double iconXS = 16.0;
  static const double iconSM = 20.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;
  static const double iconXL = 48.0;
  static const double iconXXL = 64.0;

  // Elevation/Shadow Heights
  static const double elevationNone = 0.0;
  static const double elevationXS = 1.0;
  static const double elevationSM = 2.0;
  static const double elevationMD = 4.0;
  static const double elevationLG = 8.0;
  static const double elevationXL = 12.0;
  static const double elevationXXL = 16.0;
}
