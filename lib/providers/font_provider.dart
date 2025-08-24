import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class FontProvider extends ChangeNotifier {
  String _selectedFont = 'Inconsolata';
  
  String get selectedFont => _selectedFont;

  /// Initialize the font provider and load saved font preference
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedFont = prefs.getString('selected_font') ?? 'Inconsolata';
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

  /// Get the text theme for the selected font
  TextTheme getTextTheme(ThemeData baseTheme) {
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

  /// Get app bar title style for the selected font
  TextStyle getAppBarTitleStyle() {
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

  /// Get chip label style for the selected font
  TextStyle getChipLabelStyle(Color color) {
    switch (_selectedFont) {
      case 'Inconsolata':
        return GoogleFonts.inconsolata(color: color);
      case 'Roboto':
        return GoogleFonts.roboto(color: color);
      case 'Open Sans':
        return GoogleFonts.openSans(color: color);
      case 'Lato':
        return GoogleFonts.lato(color: color);
      case 'Poppins':
        return GoogleFonts.poppins(color: color);
      case 'Inter':
        return GoogleFonts.inter(color: color);
      case 'Ubuntu':
        return GoogleFonts.ubuntu(color: color);
      case 'Nunito':
        return GoogleFonts.nunito(color: color);
      case 'Montserrat':
        return GoogleFonts.montserrat(color: color);
      case 'Raleway':
        return GoogleFonts.raleway(color: color);
      case 'Work Sans':
        return GoogleFonts.workSans(color: color);
      case 'Quicksand':
        return GoogleFonts.quicksand(color: color);
      case 'Comfortaa':
        return GoogleFonts.comfortaa(color: color);
      case 'Josefin Sans':
        return GoogleFonts.josefinSans(color: color);
      case 'Sono':
        return GoogleFonts.sono(color: color);
      default:
        return GoogleFonts.inconsolata(color: color);
    }
  }
}
