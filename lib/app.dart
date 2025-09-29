import 'package:flutter/material.dart';
import 'screens/auth_wrapper.dart';

class TripApp extends StatelessWidget {
  const TripApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      primarySwatch: Colors.indigo,
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Trip Capture',
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: Colors.indigo,
          secondary: Colors.indigoAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
