import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import '../services/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  String _dbSize = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _calculateDatabaseSize();
  }

  Future<void> _calculateDatabaseSize() async {
    final dbPath = await getDatabasesPath();
    final file = File(join(dbPath, 'nettruyen.db'));
    if (await file.exists()) {
      final size = await file.length();
      setState(() {
        _dbSize = '${(size / 1024 / 1024).toStringAsFixed(2)} MB';
      });
    } else {
      setState(() {
        _dbSize = '0 MB';
      });
    }
  }

  Future<void> _clearDatabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseHelper.instance.clearAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database cleared successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing database: $e')),
      );
    } finally {
      await _calculateDatabaseSize();
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
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
          ListTile(
            title: const Text('About'),
            subtitle: const Text('NetTruyen Reader v1.0.0'),
            onTap: () {
              // Show about dialog
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
    );
  }
} 