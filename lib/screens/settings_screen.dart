// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

import '../services/database_helper.dart';
import '../providers/theme_provider.dart';
import '../providers/font_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _domainController = TextEditingController();
  String _currentDomain = '';
  
  String _dbSize = 'Calculating...';
  bool _isLoading = false;
  
  // Popular Google Fonts list
  static const List<Map<String, String>> _popularFonts = [
    {'name': 'Inconsolata', 'family': 'Inconsolata'},
    {'name': 'Roboto', 'family': 'Roboto'},
    {'name': 'Open Sans', 'family': 'Open Sans'},
    {'name': 'Lato', 'family': 'Lato'},
    {'name': 'Poppins', 'family': 'Poppins'},
    {'name': 'Inter', 'family': 'Inter'},
    {'name': 'Ubuntu', 'family': 'Ubuntu'},
    {'name': 'Nunito', 'family': 'Nunito'},
    {'name': 'Montserrat', 'family': 'Montserrat'},
    {'name': 'Raleway', 'family': 'Raleway'},
    {'name': 'Work Sans', 'family': 'Work Sans'},
    {'name': 'Quicksand', 'family': 'Quicksand'},
    {'name': 'Comfortaa', 'family': 'Comfortaa'},
    {'name': 'Josefin Sans', 'family': 'Josefin Sans'},
    {'name': 'Sono', 'family': 'Sono'},
  ];
  @override
  void initState() {
    super.initState();
    _calculateDatabaseSize();
    _loadCurrentDomain();
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method loads the current custom domain
  /// from SharedPreferences and updates the UI accordingly. It's essential for
  /// displaying the current domain setting to the user.
  Future<void> _loadCurrentDomain() async {
    final prefs = await SharedPreferences.getInstance();
    final customDomain = prefs.getString('custom_domain');
    
    setState(() {
      _currentDomain = customDomain ?? AppConstants.PRIMARY_DOMAIN;
      _domainController.text = _currentDomain.replaceFirst('https://', '');
    });
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method saves the domain entered by the user
  /// to SharedPreferences. It automatically adds the https:// prefix if not provided
  /// and handles clearing the text field (reverting to default). It's essential for
  /// the domain persistence and auto-save functionality.
  Future<void> _saveDomain() async {
    String newDomain = _domainController.text.trim();
    
    if (!newDomain.startsWith('http://') && !newDomain.startsWith('https://')) {
      newDomain = 'https://$newDomain';
    }

    if (newDomain.isNotEmpty && newDomain != _currentDomain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_domain', newDomain);
      
      setState(() {
        _currentDomain = newDomain;
      });
      print('🔍 Domain saved: $newDomain');
    } else if (newDomain.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_domain');
      
      setState(() {
        _currentDomain = AppConstants.PRIMARY_DOMAIN;
      });
      print('🔍 Domain cleared, using default: ${AppConstants.PRIMARY_DOMAIN}');
    }
  }

  /// Get the font style for the selected font family (for dropdown preview)
  TextStyle _getFontStyle(String fontFamily) {
    switch (fontFamily) {
      case 'Inconsolata':
        return GoogleFonts.inconsolata(fontSize: 14);
      case 'Roboto':
        return GoogleFonts.roboto(fontSize: 14);
      case 'Open Sans':
        return GoogleFonts.openSans(fontSize: 14);
      case 'Lato':
        return GoogleFonts.lato(fontSize: 14);
      case 'Poppins':
        return GoogleFonts.poppins(fontSize: 14);
      case 'Inter':
        return GoogleFonts.inter(fontSize: 14);
      case 'Ubuntu':
        return GoogleFonts.ubuntu(fontSize: 14);
      case 'Nunito':
        return GoogleFonts.nunito(fontSize: 14);
      case 'Montserrat':
        return GoogleFonts.montserrat(fontSize: 14);
      case 'Raleway':
        return GoogleFonts.raleway(fontSize: 14);
      case 'Work Sans':
        return GoogleFonts.workSans(fontSize: 14);
      case 'Quicksand':
        return GoogleFonts.quicksand(fontSize: 14);
      case 'Comfortaa':
        return GoogleFonts.comfortaa(fontSize: 14);
      case 'Josefin Sans':
        return GoogleFonts.josefinSans(fontSize: 14);
      case 'Sono':
        return GoogleFonts.sono(fontSize: 14);
      default:
        return GoogleFonts.inconsolata(fontSize: 14);
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method calculates the current database size
  /// for display in the settings UI. It's essential for providing users with information
  /// about their local storage usage.
  Future<void> _calculateDatabaseSize() async {
    try {
      final helper = DatabaseHelper();
      final size = await helper.getDatabaseSize();
      setState(() {
        _dbSize = size;
      });
    } catch (e) {
      setState(() {
        _dbSize = 'Error calculating size';
      });
    }
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method clears all data from the local database
  /// after user confirmation. It's essential for providing users with a way to free up
  /// storage space and reset their local data.
  Future<void> _clearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Database'),
        content: const Text('Are you sure you want to clear all saved data? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final helper = DatabaseHelper();
        await helper.clearAllData();
        await _calculateDatabaseSize();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing database: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ),
        body: ListView(
          children: [
            const ListTile(
              title: Text(
                'Domain Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Source Domain',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _domainController,
                    decoration: InputDecoration(
                      hintText: 'Enter domain URL (e.g., nettruyenvio.com)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _domainController.clear();
                          _saveDomain();
                        },
                        tooltip: 'Clear text',
                      ),
                    ),
                    onChanged: (value) {
                      _saveDomain();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current: $_currentDomain',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: https:// is automatically added if not provided',
                    style: const TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Default: ${AppConstants.PRIMARY_DOMAIN}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const Divider(),
            
            const ListTile(
              title: Text(
                'Appearance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(themeProvider.themeModeDescription),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeProvider.themeMode,
                    onChanged: (ThemeMode? newValue) {
                      if (newValue != null) {
                        themeProvider.setThemeMode(newValue);
                      }
                    },
                    items: ThemeMode.values.map<DropdownMenuItem<ThemeMode>>((ThemeMode themeMode) {
                      return DropdownMenuItem<ThemeMode>(
                        value: themeMode,
                        child: Text(themeMode.name),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            Consumer<FontProvider>(
              builder: (context, fontProvider, child) {
                return ListTile(
                  title: const Text('Font Family'),
                  subtitle: Text(fontProvider.selectedFont),
                  trailing: DropdownButton<String>(
                    value: fontProvider.selectedFont,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        fontProvider.setFont(newValue);
                      }
                    },
                    items: _popularFonts.map<DropdownMenuItem<String>>((font) {
                      return DropdownMenuItem<String>(
                        value: font['name'],
                        child: Text(
                          font['name']!,
                          style: _getFontStyle(font['family']!),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            
            // Font Scale Slider
            Consumer<FontProvider>(
              builder: (context, fontProvider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('Font Size'),
                      subtitle: Text('${fontProvider.fontScalePercentage} (${fontProvider.fontScale.toStringAsFixed(1)}x)'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              final newScale = (fontProvider.fontScale - 0.1).clamp(0.5, 3.0);
                              fontProvider.setFontScale(newScale);
                            },
                            tooltip: 'Decrease font size',
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => fontProvider.resetFontScale(),
                            tooltip: 'Reset to default size',
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              final newScale = (fontProvider.fontScale + 0.1).clamp(0.5, 3.0);
                              fontProvider.setFontScale(newScale);
                            },
                            tooltip: 'Increase font size',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Slider(
                        value: fontProvider.fontScale,
                        min: 0.5,
                        max: 3.0,
                        divisions: 25, // 0.1 increments
                        label: fontProvider.fontScalePercentage,
                        onChanged: (value) {
                          fontProvider.setFontScale(value);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
            const Divider(),
            
            const ListTile(
              title: Text(
                'Database',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              title: const Text('Database Size'),
              subtitle: Text(_dbSize),
              trailing: _isLoading
                  ? const CircularProgressIndicator()
                  : IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _clearDatabase,
                    ),
            ),
            const Divider(),
            
            const ListTile(
              title: Text(
                'About',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              title: const Text('About'),
              subtitle: const Text('NetTruyen Reader v1.0.0'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'NetTruyen Reader',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 