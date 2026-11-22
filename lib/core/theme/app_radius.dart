import 'package:flutter/material.dart';

/// Corner radius tokens specified in THEME.md Section 5.
class AppRadius {
  AppRadius._();

  /// 8 px: Small controls
  static const double small = 8.0;

  /// 12 px: Inputs / cards
  static const double input = 12.0;

  /// 16 px: Large panels
  static const double large = 16.0;

  /// 20 px: Dialogs
  static const double dialog = 20.0;

  /// Fully rounded pills
  static const double pill = 999.0;

  static const BorderRadius smallBorderRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius inputBorderRadius = BorderRadius.all(
    Radius.circular(input),
  );
  static const BorderRadius largeBorderRadius = BorderRadius.all(
    Radius.circular(large),
  );
  static const BorderRadius dialogBorderRadius = BorderRadius.all(
    Radius.circular(dialog),
  );
  static const BorderRadius pillBorderRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
