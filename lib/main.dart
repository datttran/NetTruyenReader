import 'package:flutter/material.dart';
import 'package:nettruyen_reader/screens/home_screen.dart';
import 'package:nettruyen_reader/constants/app_constants.dart';

void main() {
  runApp(const NetTruyenReaderApp());
}

class NetTruyenReaderApp extends StatelessWidget {
  const NetTruyenReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.APP_NAME,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: false, // Disable Material 3 to prevent unwanted color changes
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
