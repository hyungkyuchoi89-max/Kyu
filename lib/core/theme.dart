import 'package:flutter/material.dart';

/// WordWake의 색상 팔레트.
/// 깊은 네이비 배경 + 오프화이트 본문 + 따뜻한 노란색 강조.
class AppColors {
  const AppColors._();

  static const Color background = Color(0xFF121826);
  static const Color surface = Color(0xFF1B2233);
  static const Color surfaceElevated = Color(0xFF232C42);
  static const Color primaryText = Color(0xFFF8FAFC);
  static const Color mutedText = Color(0xFF94A3B8);
  static const Color accent = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF22C55E);
  static const Color border = Color(0xFF2C3650);
}

/// 화면 전체에서 재사용하는 타이포그래피.
/// 영어 스펠링 38pt > 뜻 24pt > 예문 17pt > 발음기호 15pt.
class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle word = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static const TextStyle meaning = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.accent,
    height: 1.3,
  );

  static const TextStyle example = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedText,
    height: 1.45,
  );

  static const TextStyle phonetic = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedText,
    height: 1.3,
  );

  static const TextStyle optionWord = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
    height: 1.2,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
    height: 1.3,
  );

  static const TextStyle section = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.mutedText,
    letterSpacing: 0.6,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedText,
    height: 1.4,
  );

  static const TextStyle counter = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
    letterSpacing: 0.5,
  );
}

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    secondary: AppColors.accent,
    onSecondary: AppColors.background,
    surface: AppColors.surface,
    onSurface: AppColors.primaryText,
    error: AppColors.danger,
    onError: AppColors.primaryText,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.border,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.caption,
      titleMedium: AppTextStyles.title,
      labelLarge: AppTextStyles.body,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.border,
      thumbColor: AppColors.accent,
      overlayColor: Color(0x33FBBF24),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.background;
        }
        return AppColors.mutedText;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accent;
        }
        return AppColors.surfaceElevated;
      }),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceElevated,
      contentTextStyle: AppTextStyles.body,
      behavior: SnackBarBehavior.floating,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.surfaceElevated,
      dialBackgroundColor: AppColors.surface,
      hourMinuteColor: AppColors.surface,
      hourMinuteTextColor: AppColors.primaryText,
      dialHandColor: AppColors.accent,
      dialTextColor: AppColors.primaryText,
      entryModeIconColor: AppColors.accent,
    ),
  );
}
