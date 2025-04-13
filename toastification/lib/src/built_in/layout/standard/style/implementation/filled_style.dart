import 'package:flutter/material.dart';
import 'package:toastification/src/built_in/layout/standard/style/style.dart';
import 'package:toastification/src/utils/color_utils.dart';

class FilledStandardToastStyle extends BaseStandardToastStyle {
  const FilledStandardToastStyle({
    required super.type,
    super.providedValues,
    super.flutterTheme,
  });

  @override
  DefaultStyleValues get defaults => DefaultStyleValues(
        primaryColor: type.color.toMaterialColor,
        surfaceLight: Colors.white,
        surfaceDark: Colors.black,
      );

  @override
  Color get backgroundColor => primaryColor;

  @override
  Color get foregroundColor =>
      providedValues?.surfaceLight ?? defaults.surfaceLight;

  @override
  Color blurredBackgroundColor(bool applyBlur, Color color) =>
      applyBlur ? color.withOpacity( 0.8) : color;

  @override
  Color get iconColor => providedValues?.surfaceLight ?? defaults.surfaceLight;

  @override
  ProgressIndicatorThemeData get defaultProgressIndicatorTheme =>
      ProgressIndicatorThemeData(
        color: foregroundColor.withOpacity( .30),
        linearMinHeight: progressIndicatorStrokeWidth,
        linearTrackColor: foregroundColor.withOpacity( .15),
        refreshBackgroundColor: foregroundColor.withOpacity( .15),
      );
}
