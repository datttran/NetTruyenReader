// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';
import '../services/database_helper.dart';
import '../providers/theme_provider.dart';

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