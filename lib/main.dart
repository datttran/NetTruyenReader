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
        // remove the standalone brightness:
        // brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,   // ← force dark here
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
