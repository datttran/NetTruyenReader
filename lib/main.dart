import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nettruyen_reader/screens/home_screen.dart';
import 'package:nettruyen_reader/constants/app_constants.dart';
import 'package:nettruyen_reader/constants/theme_constants.dart';
import 'package:nettruyen_reader/providers/theme_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const NetTruyenReaderApp(),
    ),
  );
}

class NetTruyenReaderApp extends StatelessWidget {
  const NetTruyenReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConstants.APP_NAME,
          theme: ThemeConstants.lightTheme,
          darkTheme: ThemeConstants.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
