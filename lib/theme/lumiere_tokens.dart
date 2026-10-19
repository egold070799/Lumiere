import 'package:material_ui/material_ui.dart';

abstract final class LumierePalette {
  static const int defaultAccentValue = 0xFF40564A;
  // Warm, paper-like surfaces for the optional light theme.
  static const Color canvas = Color(0xFFF0EEE7);
  static const Color raisedSurface = Color(0xFFFCFAF6);
  static const Color primary = Color(defaultAccentValue);
  static const Color brass = Color(0xFF84663A);
  static const Color brassSurface = Color(0xFFEDE4D4);
  static const Color brassInk = Color(0xFF3F3424);
  static const Color slate = Color(0xFF687B89);
  static const Color slateSurface = Color(0xFFE0E8ED);
  static const Color slateInk = Color(0xFF263640);
  static const Color surfaceContainer = Color(0xFFF4F1EA);
  static const Color surfaceContainerHigh = Color(0xFFECE9E1);
  static const Color surfaceContainerHighest = Color(0xFFE4E1D8);
  static const Color outline = Color(0xFF8B887E);
  static const Color outlineVariant = Color(0xFFD3CFC5);

  // Deep green-black surfaces keep the default theme dark without using
  // pure black. Brass and sage accents retain the Lumiere identity.
  static const Color darkCanvas = Color(0xFF101411);
  static const Color darkSurface = Color(0xFF151B17);
  static const Color darkSurfaceContainer = Color(0xFF1B231E);
  static const Color darkSurfaceContainerHigh = Color(0xFF242D27);
  static const Color darkSurfaceContainerHighest = Color(0xFF2D3831);
  static const Color darkBrass = Color(0xFFD2B276);
  static const Color darkBrassSurface = Color(0xFF4A402B);
  static const Color darkBrassInk = Color(0xFFF0D9A7);
  static const Color darkSlate = Color(0xFFA8BBC6);
  static const Color darkSlateSurface = Color(0xFF34434B);
  static const Color darkSlateInk = Color(0xFFD4E1E8);
  static const Color darkOutline = Color(0xFF89958C);
  static const Color darkOutlineVariant = Color(0xFF3A463E);
}

abstract final class LumiereTypography {
  static const String interfaceFamily = 'Roboto';
  static const String displayFamily = 'serif';
}

abstract final class LumiereShape {
  static const double cardRadius = 12;
  static const double controlRadius = 10;
}
