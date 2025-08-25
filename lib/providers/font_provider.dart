import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class FontProvider extends ChangeNotifier {
  String _selectedFont = 'Inconsolata';
  double _fontScale = 1.0;

  String get selectedFont => _selectedFont;
  double get fontScale => _fontScale;

  /// Convert scale value to actual font multiplier
  /// 1.0 = 1.0x, 1.5 = 1.2x, 2.0 = 1.4x
  double get _actualFontMultiplier {
    if (_fontScale == 1.0) {
      return 1.0;  // Normal size
    } else if (_fontScale == 1.5) {
      return 1.2;  // 1.2x the normal size
    } else if (_fontScale == 2.0) {
      return 1.4;  // 1.4x the normal size
    } else {
      return 1.0;  // Fallback to normal size
    }
  }

  /// Get font scale as a percentage string for display
  String get fontScalePercentage => '${(_fontScale * 100).round()}%';

  /// Initialize the font provider and load saved font preference
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedFont = prefs.getString('selected_font') ?? 'Inconsolata';
    _fontScale = prefs.getDouble('font_scale') ?? 1.0;
    
    // Ensure font scale is one of the valid values (1.0, 1.5, 2.0)
    if (_fontScale != 1.0 && _fontScale != 1.5 && _fontScale != 2.0) {
      // Normalize to closest valid value
      if (_fontScale < 1.25) {
        _fontScale = 1.0;
      } else if (_fontScale < 1.75) {
        _fontScale = 1.5;
      } else {
        _fontScale = 2.0;
      }
      await prefs.setDouble('font_scale', _fontScale);
    }
    
    notifyListeners();
  }

  /// Change the selected font and save to preferences
  Future<void> setFont(String fontName) async {
    if (_selectedFont != fontName) {
      _selectedFont = fontName;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_font', fontName);

      notifyListeners();
    }
  }

  /// Change the font scale and save to preferences
  Future<void> setFontScale(double scale) async {
    // Only accept the three valid scale values: 1.0, 1.5, 2.0
    double validScale;
    if (scale == 1.0) {
      validScale = 1.0;
    } else if (scale == 1.5) {
      validScale = 1.5;
    } else if (scale == 2.0) {
      validScale = 2.0;
    } else {
      // If an invalid value is passed, don't change anything
      print('Warning: Invalid font scale value: $scale. Must be 1.0, 1.5, or 2.0');
      return;
    }

    if (_fontScale != validScale) {
      _fontScale = validScale;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('font_scale', validScale);

      notifyListeners();
    }
  }

  /// Reset font scale to default (1.0)
  Future<void> resetFontScale() async {
    if (_fontScale != 1.0) {
      _fontScale = 1.0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('font_scale', 1.0);

      notifyListeners();
    }
  }

  /// Get the text theme for the selected font with scaling applied
  TextTheme getTextTheme(ThemeData baseTheme) {
    final baseTextTheme = _getBaseTextTheme(baseTheme);

    // Apply font scaling to all text styles, but only if scale is not 1.0
    if (_fontScale == 1.0) {
      return baseTextTheme;
    }

    // Manually scale each text style to avoid assertion errors
    return TextTheme(
      displayLarge: _scaleTextStyle(baseTextTheme.displayLarge),
      displayMedium: _scaleTextStyle(baseTextTheme.displayMedium),
      displaySmall: _scaleTextStyle(baseTextTheme.displaySmall),
      headlineLarge: _scaleTextStyle(baseTextTheme.headlineLarge),
      headlineMedium: _scaleTextStyle(baseTextTheme.headlineMedium),
      headlineSmall: _scaleTextStyle(baseTextTheme.headlineSmall),
      titleLarge: _scaleTextStyle(baseTextTheme.titleLarge),
      titleMedium: _scaleTextStyle(baseTextTheme.titleMedium),
      titleSmall: _scaleTextStyle(baseTextTheme.titleSmall),
      bodyLarge: _scaleTextStyle(baseTextTheme.bodyLarge),
      bodyMedium: _scaleTextStyle(baseTextTheme.bodyMedium),
      bodySmall: _scaleTextStyle(baseTextTheme.bodySmall),
      labelLarge: _scaleTextStyle(baseTextTheme.labelLarge),
      labelMedium: _scaleTextStyle(baseTextTheme.labelMedium),
      labelSmall: _scaleTextStyle(baseTextTheme.labelSmall),
    );
  }

  /// Safely scale a text style, handling null cases
  TextStyle? _scaleTextStyle(TextStyle? style) {
    if (style == null) return null;

    // If the style has no fontSize, return it unchanged
    if (style.fontSize == null) return style;

    // Scale the fontSize safely
    return style.copyWith(
      fontSize: style.fontSize! * _actualFontMultiplier,
    );
  }

  /// Get the base text theme without scaling (for internal use)
  TextTheme _getBaseTextTheme(ThemeData baseTheme) {
    switch (_selectedFont) {
      case 'Inconsolata':
        return GoogleFonts.inconsolataTextTheme(baseTheme.textTheme);
      case 'Roboto':
        return GoogleFonts.robotoTextTheme(baseTheme.textTheme);
      case 'Open Sans':
        return GoogleFonts.openSansTextTheme(baseTheme.textTheme);
      case 'Lato':
        return GoogleFonts.latoTextTheme(baseTheme.textTheme);
      case 'Poppins':
        return GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
      case 'Inter':
        return GoogleFonts.interTextTheme(baseTheme.textTheme);
      case 'Ubuntu':
        return GoogleFonts.ubuntuTextTheme(baseTheme.textTheme);
      case 'Nunito':
        return GoogleFonts.nunitoTextTheme(baseTheme.textTheme);
      case 'Montserrat':
        return GoogleFonts.montserratTextTheme(baseTheme.textTheme);
      case 'Raleway':
        return GoogleFonts.ralewayTextTheme(baseTheme.textTheme);
      case 'Work Sans':
        return GoogleFonts.workSansTextTheme(baseTheme.textTheme);
      case 'Quicksand':
        return GoogleFonts.quicksandTextTheme(baseTheme.textTheme);
      case 'Comfortaa':
        return GoogleFonts.comfortaaTextTheme(baseTheme.textTheme);
      case 'Josefin Sans':
        return GoogleFonts.josefinSansTextTheme(baseTheme.textTheme);
      case 'Sono':
        return GoogleFonts.sonoTextTheme(baseTheme.textTheme);
      default:
        return GoogleFonts.inconsolataTextTheme(baseTheme.textTheme);
    }
  }

  /// Get app bar title style for the selected font with scaling applied
  TextStyle getAppBarTitleStyle() {
    final baseStyle = _getBaseAppBarTitleStyle();

    // Apply font scaling only if scale is not 1.0
    if (_fontScale == 1.0) {
      return baseStyle;
    }

    // Apply font scaling
    return baseStyle.copyWith(
      fontSize: baseStyle.fontSize! * _actualFontMultiplier,
    );
  }

  /// Get the base app bar title style without scaling (for internal use)
  TextStyle _getBaseAppBarTitleStyle() {
    switch (_selectedFont) {
      case 'Inconsolata':
        return GoogleFonts.inconsolata(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Roboto':
        return GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Open Sans':
        return GoogleFonts.openSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Lato':
        return GoogleFonts.lato(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Poppins':
        return GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Inter':
        return GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Ubuntu':
        return GoogleFonts.ubuntu(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Nunito':
        return GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Montserrat':
        return GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Raleway':
        return GoogleFonts.raleway(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Work Sans':
        return GoogleFonts.workSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Quicksand':
        return GoogleFonts.quicksand(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Comfortaa':
        return GoogleFonts.comfortaa(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Josefin Sans':
        return GoogleFonts.josefinSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case 'Sono':
        return GoogleFonts.sono(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      default:
        return GoogleFonts.inconsolata(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
    }
  }

  /// Get chip label style for the selected font with scaling applied
  TextStyle getChipLabelStyle(Color color) {
    final baseStyle = _getBaseChipLabelStyle(color);

    // Apply font scaling only if scale is not 1.0
    if (_fontScale == 1.0) {
      return baseStyle;
    }

    // Apply font scaling
    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14) * _actualFontMultiplier,
    );
  }

  /// Get the base chip label style without scaling (for internal use)
  TextStyle _getBaseChipLabelStyle(Color color) {
    switch (_selectedFont) {
      case 'Inconsolata':
        return GoogleFonts.inconsolata(color: color, fontSize: 14);
      case 'Roboto':
        return GoogleFonts.roboto(color: color, fontSize: 14);
      case 'Open Sans':
        return GoogleFonts.openSans(color: color, fontSize: 14);
      case 'Lato':
        return GoogleFonts.lato(color: color, fontSize: 14);
      case 'Poppins':
        return GoogleFonts.poppins(color: color, fontSize: 14);
      case 'Inter':
        return GoogleFonts.inter(color: color, fontSize: 14);
      case 'Ubuntu':
        return GoogleFonts.ubuntu(color: color, fontSize: 14);
      case 'Nunito':
        return GoogleFonts.nunito(color: color, fontSize: 14);
      case 'Montserrat':
        return GoogleFonts.montserrat(color: color, fontSize: 14);
      case 'Raleway':
        return GoogleFonts.raleway(color: color, fontSize: 14);
      case 'Work Sans':
        return GoogleFonts.workSans(color: color, fontSize: 14);
      case 'Quicksand':
        return GoogleFonts.quicksand(color: color, fontSize: 14);
      case 'Comfortaa':
        return GoogleFonts.comfortaa(color: color, fontSize: 14);
      case 'Josefin Sans':
        return GoogleFonts.josefinSans(color: color, fontSize: 14);
      case 'Sono':
        return GoogleFonts.sono(color: color, fontSize: 14);
      default:
        return GoogleFonts.inconsolata(color: color, fontSize: 14);
    }
  }

  /// Scale any TextStyle with the current font scale
  /// This is useful for custom text styles throughout the app
  TextStyle scaleTextStyle(TextStyle style) {
    if (_fontScale == 1.0 || style.fontSize == null) {
      return style;
    }

    return style.copyWith(
      fontSize: style.fontSize! * _actualFontMultiplier,
    );
  }

  /// Scale a font size value with the current font scale
  /// This is useful for inline fontSize values
  double scaleFontSize(double fontSize) {
    return fontSize * _actualFontMultiplier;
  }

  /// Get a scaled text style for common use cases
  TextStyle getScaledTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    final baseFontSize = fontSize ?? 16.0;
    final scaledFontSize = scaleFontSize(baseFontSize);

    return TextStyle(
      fontSize: scaledFontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  /// Debug method to check current font scale state
  void debugFontScale() {
    print('🔍 Current font scale: $_fontScale');
    print('🔍 Valid scale values: [1.0, 1.5, 2.0]');
    print('🔍 Actual font multiplier: ${_actualFontMultiplier}x');
  }
}
