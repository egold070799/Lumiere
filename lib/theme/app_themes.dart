

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lumiere/services/settings_manager.dart';
import 'package:lumiere/theme/lumiere_tokens.dart';

ThemeMode themeMode = getThemeMode(themeModeSetting);
Brightness brightness = getBrightnessFromThemeMode(themeMode);

Brightness getBrightnessFromThemeMode(ThemeMode themeMode) {
  final themeBrightnessMapping = {
    ThemeMode.light: Brightness.light,
    ThemeMode.dark: Brightness.dark,
    ThemeMode.system:
        SchedulerBinding.instance.platformDispatcher.platformBrightness,
  };

  return themeBrightnessMapping[themeMode] ?? Brightness.dark;
}

ThemeMode getThemeMode(int themeModeIndex) {
  const themeModes = ThemeMode.values;
  if (themeModeIndex >= 0 && themeModeIndex < themeModes.length) {
    return themeModes[themeModeIndex];
  }
  return ThemeMode.system;
}

ColorScheme getAppColorScheme(
  ColorScheme? systemLightColorScheme,
  ColorScheme? systemDarkColorScheme, {
  required Brightness targetBrightness,
}) {
  final isLight = targetBrightness == Brightness.light;
  final selectedScheme = isLight
      ? systemLightColorScheme
      : systemDarkColorScheme;

  if (useSystemColor.value && selectedScheme != null) {
    return selectedScheme;
  } else {
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: primaryColorSetting,
      brightness: targetBrightness,
    );
    if (isLight) {
      return generatedScheme.copyWith(
        secondary: LumierePalette.brass,
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: LumierePalette.brassSurface,
        onSecondaryContainer: LumierePalette.brassInk,
        tertiary: LumierePalette.slate,
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: LumierePalette.slateSurface,
        onTertiaryContainer: LumierePalette.slateInk,
        surface: LumierePalette.canvas,
        surfaceContainerLowest: const Color(0xFFFFFEFB),
        surfaceContainerLow: LumierePalette.raisedSurface,
        surfaceContainer: LumierePalette.surfaceContainer,
        surfaceContainerHigh: LumierePalette.surfaceContainerHigh,
        surfaceContainerHighest: LumierePalette.surfaceContainerHighest,
        outline: LumierePalette.outline,
        outlineVariant: LumierePalette.outlineVariant,
      );
    }
    return generatedScheme.copyWith(
      secondary: LumierePalette.darkBrass,
      onSecondary: const Color(0xFF292315),
      secondaryContainer: LumierePalette.darkBrassSurface,
      onSecondaryContainer: LumierePalette.darkBrassInk,
      tertiary: LumierePalette.darkSlate,
      onTertiary: const Color(0xFF1C272D),
      tertiaryContainer: LumierePalette.darkSlateSurface,
      onTertiaryContainer: LumierePalette.darkSlateInk,
      surface: LumierePalette.darkCanvas,
      surfaceContainerLowest: const Color(0xFF0C100D),
      surfaceContainerLow: LumierePalette.darkSurface,
      surfaceContainer: LumierePalette.darkSurfaceContainer,
      surfaceContainerHigh: LumierePalette.darkSurfaceContainerHigh,
      surfaceContainerHighest: LumierePalette.darkSurfaceContainerHighest,
      outline: LumierePalette.darkOutline,
      outlineVariant: LumierePalette.darkOutlineVariant,
    );
  }
}

ThemeData getAppTheme(ColorScheme colorScheme) {
  final base = colorScheme.brightness == Brightness.light
      ? ThemeData.light()
      : ThemeData.dark();

  final isLight = colorScheme.brightness == Brightness.light;
  final isPureBlack =
      colorScheme.brightness == Brightness.dark && usePureBlackColor.value;

  // Pure black theme colors
  const pureBlack = Color(0xFF000000);
  const pureBlackElevated = Color(0xFF0A0A0A);
  const pureBlackContainer = Color(0xFF121212);
  const pureBlackContainerHigh = Color(0xFF1A1A1A);

  final bgColor = isPureBlack ? pureBlack : colorScheme.surface;

  final cardBgColor = isLight
      ? colorScheme.surfaceContainerLow
      : (isPureBlack ? pureBlackElevated : colorScheme.surfaceContainerLow);

  // modified color scheme for pure black theme
  final effectiveColorScheme = isPureBlack
      ? colorScheme.copyWith(
          surface: pureBlack,
          surfaceContainerLowest: pureBlack,
          surfaceContainerLow: pureBlackElevated,
          surfaceContainer: pureBlackContainer,
          surfaceContainerHigh: pureBlackContainerHigh,
          surfaceContainerHighest: pureBlackContainerHigh,
        )
      : colorScheme;

  return ThemeData(
    scaffoldBackgroundColor: bgColor,
    colorScheme: effectiveColorScheme,
    fontFamily: LumiereTypography.interfaceFamily,
    cardColor: cardBgColor,
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LumiereShape.cardRadius),
        side: BorderSide(color: effectiveColorScheme.outlineVariant),
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bgColor,
      foregroundColor: effectiveColorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        fontFamily: LumiereTypography.displayFamily,
        color: effectiveColorScheme.onSurface,
        letterSpacing: 0.8,
      ),
      toolbarHeight: 64,
      iconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: effectiveColorScheme.onSurface,
      iconColor: effectiveColorScheme.onSurfaceVariant,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      year2023: false,
      trackHeight: 5,
      thumbSize: WidgetStateProperty.all(const Size(8, 22)),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: isPureBlack
          ? pureBlackElevated
          : effectiveColorScheme.surfaceContainerLow,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      isDense: true,
      fillColor: isPureBlack
          ? pureBlackContainerHigh
          : effectiveColorScheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.fromLTRB(18, 14, 20, 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumiereShape.controlRadius),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LumiereShape.controlRadius),
        ),
        side: BorderSide(color: effectiveColorScheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: isPureBlack
          ? pureBlackContainer
          : effectiveColorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      height: 70,
      indicatorColor: effectiveColorScheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LumiereShape.controlRadius),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(
            color: effectiveColorScheme.onPrimaryContainer,
            size: 24,
          );
        }
        return IconThemeData(
          color: effectiveColorScheme.onSurfaceVariant,
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: effectiveColorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: effectiveColorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      indicatorColor: effectiveColorScheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LumiereShape.controlRadius),
      ),
      selectedIconTheme: IconThemeData(
        color: effectiveColorScheme.onPrimaryContainer,
        size: 24,
      ),
      unselectedIconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: effectiveColorScheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: effectiveColorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: isPureBlack
          ? pureBlackContainer
          : effectiveColorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: effectiveColorScheme.outlineVariant,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: effectiveColorScheme.secondaryContainer,
      closeIconColor: effectiveColorScheme.onSecondaryContainer,
      contentTextStyle: TextStyle(
        color: effectiveColorScheme.onSecondaryContainer,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: effectiveColorScheme.outlineVariant,
          width: 0.2,
        ),
      ),
      elevation: 0,
      actionTextColor: effectiveColorScheme.secondary,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    useMaterial3: true,
  );
}
