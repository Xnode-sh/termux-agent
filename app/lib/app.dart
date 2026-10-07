import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class RtlApp extends StatelessWidget {
  const RtlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTL Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF58A6FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
