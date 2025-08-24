import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class FontProvider extends ChangeNotifier {
  String _selectedFont = 'Inconsolata';
  double _fontScale = 1.0;
  
  String get selectedFont => _selectedFont;
  double get fontScale => _fontScale;
  
  /// Get font scale as a percentage string for display
  String get fontScalePercentage => '${(_fontScale * 100).round()}%';

  /// Initialize the font provider and load saved font preference
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedFont = prefs.getString('selected_font') ?? 'Inconsolata';
    _fontScale = prefs.getDouble('font_scale') ?? 1.0;
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
    // Limit scale between 0.5 and 3.0 for usability
    final clampedScale = scale.clamp(0.5, 3.0);
    
    if (_fontScale != clampedScale) {
      _fontScale = clampedScale;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('font_scale', clampedScale);
      
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
    
    // Apply font scaling to all text styles
    return baseTextTheme.apply(
      fontSizeFactor: _fontScale,
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
      fontSize: baseStyle.fontSize! * _fontScale,
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
      fontSize: (baseStyle.fontSize ?? 14) * _fontScale,
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
}
