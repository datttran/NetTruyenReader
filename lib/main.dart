import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/loading_screen.dart';
import 'constants/app_constants.dart';
import 'constants/theme_constants.dart';
import 'providers/theme_provider.dart';
import 'providers/font_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize providers
  final themeProvider = ThemeProvider();
  final fontProvider = FontProvider();
  await fontProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: fontProvider),
      ],
      child: const NetTruyenReaderApp(),
    ),
  );
}

class NetTruyenReaderApp extends StatelessWidget {
  const NetTruyenReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, FontProvider>(
      builder: (context, themeProvider, fontProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConstants.APP_NAME,
          theme: ThemeConstants.lightTheme(fontProvider),
          darkTheme: ThemeConstants.darkTheme(fontProvider),
          themeMode: themeProvider.themeMode,
          restorationScopeId: 'nettruyen_reader_app', // Enable restoration scope
          home: const LoadingScreen(),
        );
      },
    );
  }
}
