/// Design.md §4 spacing and breakpoints.
///
/// Base spacing unit is 4px; use only values from the scale so paddings stay
/// visually consistent across features. Breakpoints drive the responsive
/// shell (mobile bottom-tabs vs desktop sidebar, Design.md §12).
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
}
