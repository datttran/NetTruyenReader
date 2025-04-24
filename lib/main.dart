import 'package:flutter/material.dart';
import 'package:nettruyen_reader/screens/home_screen.dart';

void main() {
  runApp(NetTruyenReaderApp());
}

class NetTruyenReaderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NetTruyen Reader',
      theme: ThemeData(
        // remove the standalone brightness:
        // brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,   // ← force dark here
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}
